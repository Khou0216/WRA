-- Core/RotationEngine.lua
-- The main engine that drives rotation decisions.
-- MODIFIED: Major refactoring to support and execute action sequences from spec modules.
-- MODIFIED: Corrected the combat log handler to correctly identify the source and destination of auras, fixing sequence stalls for both self-buffs and target debuffs.
-- MODIFIED (Final): Separated event handling for stances and auras to prevent conflicts. Refined combat log parsing for accuracy.
-- MODIFIED (v3): Final refactoring of EngineUpdate to prioritize sequence generation before the main GCD check, allowing non-GCD actions like stance changes to be recommended during a skill's GCD.
-- MODIFIED V4 (Caster Fix): Removed the simplistic GCD check from the main engine loop. The engine now fully trusts the recommendation from the spec module, which uses the more advanced IsReadyWithQueue check (that accounts for casting state and spell queuing).
-- MODIFIED V5 (Final Caster Fix): Re-implemented the decision logic to correctly check against the maximum of either GCD remaining or Cast Time remaining, inspired by FireMageAssist. This provides the most accurate timing for all classes.
-- MODIFIED V6 (Debug Cleanup): Removed temporary debug messages from the main engine loop.
-- MODIFIED (Nitro Fix): Added call to StateModifier:ApplyOverrides to ensure temporary states are applied before decision making.
-- MODIFIED (Debug v2): Added more granular debug output to trace dependency checks and state application.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local RotationEngine = WRA:NewModule("RotationEngine", "AceEvent-3.0", "AceTimer-3.0")

-- Lua shortcuts
local math_max = math.max
local GetTime = GetTime
local pcall = pcall
local type = type
local tostring = tostring
local wipe = table.wipe
local tinsert = table.insert
local tremove = table.remove
local select = select
local GetShapeshiftForm = GetShapeshiftForm
local UnitGUID = UnitGUID
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

-- Module Variables
local updateTimer = nil
local lastActionsDisplayed = { gcdAction = nil, offGcdAction = nil }
local isEngineRunning = false
local initialTimer = nil

-- *** NEW: Variables for handling rotation sequences ***
local currentRotationSequence = {}
local rotationSequenceTimestamp = 0
local ROTATION_SEQUENCE_TIMEOUT = 5.0
local rotationSequenceCombatLogFrame = CreateFrame("Frame")

-- 从 WRA.Constants 初始化常量
local UPDATE_INTERVAL, FIRE_WINDOW
local ACTION_ID_WAITING, ACTION_ID_IDLE, ACTION_ID_CASTING, ACTION_ID_UNKNOWN

local function InitConstants()
    if WRA.Constants then
        UPDATE_INTERVAL = WRA.Constants.UPDATE_INTERVAL or 0.05
        FIRE_WINDOW = WRA.Constants.FIRE_WINDOW or 0.15
        ACTION_ID_WAITING = WRA.Constants.ACTION_ID_WAITING or 0
        ACTION_ID_IDLE = WRA.Constants.ACTION_ID_IDLE or "IDLE"
        ACTION_ID_CASTING = WRA.Constants.ACTION_ID_CASTING or "CASTING"
        ACTION_ID_UNKNOWN = WRA.Constants.ACTION_ID_UNKNOWN or -1
    end
end

-- *** NEW: Handlers for advancing the rotation sequence ***
function RotationEngine:AdvanceRotationSequence(sourceEvent, spellId)
    WRA:PrintDebug("[RotationEngine] Action", spellId, "confirmed via", sourceEvent, ". Advancing rotation sequence.")
    tremove(currentRotationSequence, 1)
    
    if #currentRotationSequence == 0 then
        WRA:PrintDebug("[RotationEngine] Rotation sequence complete.")
        rotationSequenceTimestamp = 0
    else
        -- Immediately force an update to process the next action in the sequence.
        self:ForceUpdate()
    end
end

function RotationEngine:HandleRotationSequenceSpellcast(event, unit, spellName, rank, lineId, spellId)
    if unit ~= "player" or #currentRotationSequence == 0 then return end
    if spellId and spellId == currentRotationSequence[1] then
        self:AdvanceRotationSequence(event, spellId)
    end
end

function RotationEngine:HandleRotationSequenceAura(event, ...)
    if #currentRotationSequence == 0 then return end

    local expectedAction = currentRotationSequence[1]
    
    -- Unpack combat log event data
    local timestamp, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellId, spellName = ...

    -- We only care about SPELL_AURA_APPLIED for our sequence logic
    if subEvent ~= "SPELL_AURA_APPLIED" then return end
    
    -- Check if the event is for the action we are waiting for
    if spellId and spellId == expectedAction then
        local playerGUID = UnitGUID("player")
        
        -- Check if the source of the aura is the player
        if sourceGUID ~= playerGUID then
            return
        end

        -- Check if the destination is correct. It can be the player (self-buff) or the target (debuff).
        local targetGUID = UnitGUID("target")
        if destGUID == playerGUID or (targetGUID and destGUID == targetGUID) then
             self:AdvanceRotationSequence(subEvent, spellId)
        end
    end
end

function RotationEngine:HandleRotationSequenceStanceChange(event)
    if #currentRotationSequence == 0 then return end
    local C = WRA.SpecLoader and WRA.SpecLoader:GetActiveSpecModule() and WRA.SpecLoader:GetActiveSpecModule().ClassConstants
    if not C then return end

    local nextActionInQueue = currentRotationSequence[1]
    if nextActionInQueue == C.Spells.BATTLE_STANCE_CAST or nextActionInQueue == C.Spells.DEFENSIVE_STANCE_CAST or nextActionInQueue == C.Spells.BERSERKER_STANCE_CAST then
        local targetSpellID = currentRotationSequence[2]
        if not targetSpellID then
            self:AdvanceRotationSequence(event, nextActionInQueue)
            return
        end
        local requirements = C.SpellRequirements and C.SpellRequirements[targetSpellID]
        local requiredStance = requirements and requirements.stance
        if requiredStance and GetShapeshiftForm() == requiredStance then
            self:AdvanceRotationSequence(event, nextActionInQueue)
        end
    end
end

local function EngineUpdate()
    if not isEngineRunning then 
        WRA:PrintDebug("[EngineUpdate] Return: Engine not running.")
        return 
    end

    -- [!code ++]
    -- *** DEBUG: Granular dependency check ***
    if not WRA.StateManager then WRA:PrintDebug("[EngineUpdate] Return: StateManager is nil"); return end
    if not WRA.ActionManager then WRA:PrintDebug("[EngineUpdate] Return: ActionManager is nil"); return end
    if not WRA.DisplayManager then WRA:PrintDebug("[EngineUpdate] Return: DisplayManager is nil"); return end
    if not WRA.SpecLoader then WRA:PrintDebug("[EngineUpdate] Return: SpecLoader is nil"); return end
    if not WRA.db then WRA:PrintDebug("[EngineUpdate] Return: db is nil"); return end
    if not WRA.db.profile then WRA:PrintDebug("[EngineUpdate] Return: db.profile is nil"); return end
    if not WRA.ManualQueue then WRA:PrintDebug("[EngineUpdate] Return: ManualQueue is nil"); return end
    if not WRA.StateModifier then WRA:PrintDebug("[EngineUpdate] Return: StateModifier is nil"); return end
    -- [!code --]

    local activeSpec = WRA.SpecLoader:GetActiveSpecModule()
    local currentState = WRA.StateManager:GetCurrentState()
    
    -- *** FIX: Apply state overrides right after getting the current state and before any decisions are made. ***
    WRA.StateModifier:ApplyOverrides(currentState)

    local playerState = currentState.player
    local currentTime = GetTime()
    
    -- [Gemini] 核心逻辑重构 V2:
    -- 1. 无论玩家是否在施法，我们都应该先检查高优先级的、非GCD的动作。
    --    这确保了像火箭靴这样的战术技能即使在读条时也能被推荐。
    local finalOffGcdAction = WRA.ActionManager:GetHighestPriorityAction(currentState, "GLOBAL", "OffGCD")

    local tolerance = (WRA.db.profile.spellQueueWindow or 100) / 1000
    
    local gcdRemaining = playerState.isGCDActive and (playerState.gcdEndTime - currentTime) or 0
    local castRemaining = 0
    if playerState.isCasting then
        castRemaining = playerState.castEndTime - currentTime
    elseif playerState.isChanneling then
        castRemaining = playerState.channelEndTime - currentTime
    end

    local trueCooldownRemaining = math_max(gcdRemaining, castRemaining)
    
    if trueCooldownRemaining > tolerance then
        local currentAction = ACTION_ID_WAITING
        if castRemaining > gcdRemaining then
            currentAction = ACTION_ID_CASTING
        end
        -- 即使在施法，我们也要更新显示，以包含可能存在的非GCD动作。
        if lastActionsDisplayed.gcdAction ~= currentAction or lastActionsDisplayed.offGcdAction ~= finalOffGcdAction then
             WRA.DisplayManager:UpdateAction({ gcdAction = currentAction, offGcdAction = finalOffGcdAction })
             lastActionsDisplayed = { gcdAction = currentAction, offGcdAction = finalOffGcdAction }
        end
        return
    end
    
    local manualActionID = WRA.ManualQueue:GetNextAction()
    if manualActionID then
        local isOffGCD = WRA.Constants.SpellData[manualActionID] and WRA.Constants.SpellData[manualActionID].isOffGCD
        if activeSpec and activeSpec.IsReady and activeSpec:IsReady(manualActionID, currentState) then
            if isOffGCD then
                WRA.DisplayManager:UpdateAction({ gcdAction = lastActionsDisplayed.gcdAction, offGcdAction = manualActionID })
                lastActionsDisplayed.offGcdAction = manualActionID
            else
                WRA.DisplayManager:UpdateAction({ gcdAction = manualActionID, offGcdAction = nil })
                lastActionsDisplayed = { gcdAction = manualActionID, offGcdAction = nil }
                return
            end
        else
            if not isOffGCD then
                WRA.DisplayManager:UpdateAction({ gcdAction = ACTION_ID_WAITING, offGcdAction = nil })
                lastActionsDisplayed = { gcdAction = ACTION_ID_WAITING, offGcdAction = nil }
                return
            end
        end
    end

    local finalGcdAction = nil
    local amGlobalGcdAction = WRA.ActionManager:GetHighestPriorityAction(currentState, "GLOBAL", "GCD")

    if amGlobalGcdAction then
        -- 如果ActionManager提供了GCD动作，它将覆盖整个专精循环。
        finalGcdAction = amGlobalGcdAction
    else
        -- 2. 如果没有覆盖性的GCD动作，则继续执行常规的、需要目标的专精循环。
        if not activeSpec or not currentState.target or not currentState.target.exists then
            finalGcdAction = ACTION_ID_IDLE
            -- 注意：这里我们不直接返回，因为可能仍然有一个来自ActionManager的OffGCD动作需要显示。
        else
            -- 检查序列是否超时
            if rotationSequenceTimestamp > 0 and GetTime() > (rotationSequenceTimestamp + ROTATION_SEQUENCE_TIMEOUT) then
                WRA:PrintDebug("[RotationEngine] Rotation sequence timed out. Clearing.")
                wipe(currentRotationSequence)
                rotationSequenceTimestamp = 0
            end

            -- A. 处理当前序列
            if #currentRotationSequence > 0 then
                local nextActionInSequence = currentRotationSequence[1]
                if activeSpec:IsReady(nextActionInSequence, currentState) then
                    finalGcdAction = nextActionInSequence
                else
                    finalGcdAction = ACTION_ID_WAITING
                end
            else
                -- B. 从专精模块获取下一个动作
                local specSuggestions = { gcdAction = nil, offGcdAction = nil }
                local success, result = pcall(activeSpec.GetNextAction, activeSpec, currentState)
                
                if success and type(result) == "table" then
                    if result.sequence then
                        wipe(currentRotationSequence)
                        for _, actionId in ipairs(result.sequence) do
                            tinsert(currentRotationSequence, actionId)
                        end
                        rotationSequenceTimestamp = GetTime()
                        WRA:PrintDebug("[RotationEngine] New sequence received from spec. Count:", #currentRotationSequence)
                        
                        if #currentRotationSequence > 0 then
                            local firstAction = currentRotationSequence[1]
                            if activeSpec:IsReady(firstAction, currentState) then
                                finalGcdAction = firstAction
                            else
                                finalGcdAction = ACTION_ID_WAITING
                            end
                        end
                    else
                        specSuggestions = result
                    end
                elseif not success then
                    WRA:PrintError("Error in GetNextAction for spec", WRA.SpecLoader:GetCurrentSpecKey(), ":", result)
                    specSuggestions.gcdAction = ACTION_ID_WAITING
                end
                
                if not finalGcdAction then
                    finalGcdAction = specSuggestions.gcdAction or ACTION_ID_IDLE
                    -- 仅当ActionManager没有提供OffGCD动作时，才采纳专精模块的建议。
                    if not finalOffGcdAction then
                        finalOffGcdAction = specSuggestions.offGcdAction
                    end
                end
            end
        end
    end

    -- 3. 最终更新显示
    if finalGcdAction ~= lastActionsDisplayed.gcdAction or finalOffGcdAction ~= lastActionsDisplayed.offGcdAction then
        WRA.DisplayManager:UpdateAction({ gcdAction = finalGcdAction, offGcdAction = finalOffGcdAction })
        lastActionsDisplayed = { gcdAction = finalGcdAction, offGcdAction = finalOffGcdAction }
    end
end

function RotationEngine:OnInitialize()
    InitConstants()
    lastActionsDisplayed = { gcdAction = nil, offGcdAction = nil }
    isEngineRunning = false
    WRA:PrintDebug("RotationEngine Initialized")
end

function RotationEngine:OnEnable()
    if not WRA.StateManager or not WRA.ActionManager or not WRA.DisplayManager or not WRA.SpecLoader then
        WRA:PrintError("Cannot enable RotationEngine: Critical modules missing.")
        return
    end
    InitConstants()

    WRA:PrintDebug("RotationEngine Enabled, scheduling timer...")
    isEngineRunning = true
    lastActionsDisplayed = { gcdAction = nil, offGcdAction = nil }
    
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "HandleRotationSequenceSpellcast")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "HandleRotationSequenceStanceChange")
    
    rotationSequenceCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    rotationSequenceCombatLogFrame:SetScript("OnEvent", function(_, event, ...)
        self:HandleRotationSequenceAura(event, CombatLogGetCurrentEventInfo())
    end)

    if not updateTimer and not initialTimer then
        initialTimer = self:ScheduleTimer(function()
             initialTimer = nil
             if isEngineRunning and not updateTimer then
                 EngineUpdate()
                 updateTimer = self:ScheduleRepeatingTimer(EngineUpdate, UPDATE_INTERVAL)
                 WRA:PrintDebug("RotationEngine repeating timer started.")
             end
        end, 0.6)
    end
end

function RotationEngine:OnDisable()
    WRA:PrintDebug("RotationEngine Disabled")
    isEngineRunning = false

    if updateTimer then
        self:CancelTimer(updateTimer); updateTimer = nil
    end
    if initialTimer then
        self:CancelTimer(initialTimer); initialTimer = nil
    end

    self:UnregisterAllEvents()
    rotationSequenceCombatLogFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    rotationSequenceCombatLogFrame:SetScript("OnEvent", nil)
    wipe(currentRotationSequence)
    rotationSequenceTimestamp = 0

    if WRA.DisplayManager and WRA.DisplayManager.UpdateAction then
        WRA.DisplayManager:UpdateAction({ gcdAction = nil, offGcdAction = nil })
    end
    lastActionsDisplayed = { gcdAction = nil, offGcdAction = nil }
end

function RotationEngine:ForceUpdate()
    WRA:PrintDebug("ForceUpdate called on RotationEngine")
    EngineUpdate()
end

function RotationEngine:Pause()
    WRA:PrintDebug("RotationEngine Paused")
    isEngineRunning = false
end

function RotationEngine:Resume()
    WRA:PrintDebug("RotationEngine Resumed")
    isEngineRunning = true
end
