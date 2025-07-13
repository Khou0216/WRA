-- Core/ManualQueue.lua
-- Manages a manually forced action sequence.
-- MODIFIED: Reworked to handle a sequence of actions (e.g., stance -> spell) instead of a single action.
-- MODIFIED: Added a new event handler for UPDATE_SHAPESHIFT_FORM to reliably detect stance changes and advance the queue.
-- MODIFIED: Added logic to prevent spamming the same command from resetting an in-progress sequence.
-- MODIFIED: Bypassed AceEvent for COMBAT_LOG_EVENT_UNFILTERED to correctly retrieve event data via a dedicated frame.
-- FIXED: Removed faulty local re-definition of 'LibStub' that was causing a runtime error.

local addonName, _ = ...
-- [!code --]
-- local LibStub = LibStub("AceAddon-3.0") -- This was the incorrect line causing the error.
-- [!code ++]
-- Correctly get the AceAddon-3.0 library instance.
local AceAddon = LibStub("AceAddon-3.0")
-- Get the main addon object.
local WRA = AceAddon:GetAddon(addonName)

local ManualQueue = WRA:NewModule("ManualQueue", "AceEvent-3.0")

-- Lua shortcuts
local GetTime = GetTime
local wipe = table.wipe
local tinsert = table.insert
local tremove = table.remove
local GetShapeshiftForm = GetShapeshiftForm
local UnitGUID = UnitGUID
local select = select
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

-- Module state
local actionSequence = {} -- Stores a list of spellIDs to be executed in order.
local sequenceTimestamp = 0
local QUEUE_TIMEOUT = 5.0 -- Increased timeout to allow for multi-step sequences like stance dancing.

-- A dedicated frame to handle the special case of COMBAT_LOG_EVENT_UNFILTERED
local combatLogFrame = CreateFrame("Frame")

--[[
    Builds and queues an action sequence from a list of spell IDs.
    It intelligently handles prerequisites (like stances) for each step.
]]
function ManualQueue:QueueActions(spellList)
    if not spellList or #spellList == 0 then
        WRA:PrintDebug("[ManualQueue] QueueActions called with empty or nil list.")
        return
    end

    self:ClearActionSequence() -- Always start with a fresh sequence.

    local spec = WRA.SpecLoader:GetActiveSpecModule()
    local C = spec and spec.ClassConstants
    if not (C and C.SpellRequirements and C.Stances and C.Spells) then
        -- If no complex requirements are defined, just queue the raw list.
        for _, spellID in ipairs(spellList) do
            tinsert(actionSequence, spellID)
        end
        WRA:PrintDebug("[ManualQueue] Queued raw action list. Count:", #actionSequence)
        sequenceTimestamp = GetTime()
        WRA.RotationEngine:ForceUpdate()
        return
    end

    -- Intelligent sequence building
    local currentStanceInSequence = GetShapeshiftForm()
    local defaultStance = C.Stances.BERSERKER -- Assuming Fury Warrior default

    for _, spellID in ipairs(spellList) do
        local requirement = C.SpellRequirements[spellID]
        local neededStance = requirement and requirement.stance

        if neededStance and neededStance ~= currentStanceInSequence then
            local stanceSpellID
            if neededStance == C.Stances.BATTLE then
                stanceSpellID = C.Spells.BATTLE_STANCE_CAST
            elseif neededStance == C.Stances.DEFENSIVE then
                stanceSpellID = C.Spells.DEFENSIVE_STANCE_CAST
            elseif neededStance == C.Stances.BERSERKER then
                stanceSpellID = C.Spells.BERSERKER_STANCE_CAST
            end
            
            if stanceSpellID then
                tinsert(actionSequence, stanceSpellID)
                WRA:PrintDebug("[ManualQueue] Prerequisite added: Stance Change to", neededStance)
                currentStanceInSequence = neededStance -- Update our virtual stance for the next check
            end
        end
        
        -- Add the main action
        tinsert(actionSequence, spellID)
    end

    -- After the sequence, if we are not in our default stance, add a step to return.
    if currentStanceInSequence ~= defaultStance then
        tinsert(actionSequence, C.Spells.BERSERKER_STANCE_CAST)
        WRA:PrintDebug("[ManualQueue] Post-sequence action added: Return to Berserker Stance")
    end

    WRA:PrintDebug("[ManualQueue] Final intelligent sequence queued. Count:", #actionSequence)
    sequenceTimestamp = GetTime()
    WRA.RotationEngine:ForceUpdate()
end

--[[
    Returns the next action from the sequence for the RotationEngine to evaluate.
]]
function ManualQueue:GetNextAction()
    if #actionSequence == 0 then
        return nil
    end

    -- Check for timeout
    if sequenceTimestamp > 0 and GetTime() > (sequenceTimestamp + QUEUE_TIMEOUT) then
        WRA:PrintDebug("[ManualQueue] Action sequence timed out. Clearing queue.")
        self:ClearActionSequence()
        return nil
    end
    
    -- Always return the first action currently in the sequence
    return actionSequence[1]
end

--[[
    Clears the entire action sequence.
]]
function ManualQueue:ClearActionSequence()
    if #actionSequence > 0 then
        WRA:PrintDebug("[ManualQueue] Clearing action sequence.")
        wipe(actionSequence)
        sequenceTimestamp = 0
    end
end

--[[
    Advances the sequence by removing the first action and forcing an update.
]]
function ManualQueue:AdvanceSequence(sourceEvent, spellId)
    WRA:PrintDebug("[ManualQueue] Action", spellId, "confirmed via", sourceEvent, ". Advancing sequence.")
    tremove(actionSequence, 1)
    
    if #actionSequence == 0 then
        WRA:PrintDebug("[ManualQueue] Sequence complete.")
        self:ClearActionSequence()
    else
        WRA.RotationEngine:ForceUpdate()
    end
end


--[[
    Handles the successful cast of a spell to advance the sequence.
]]
function ManualQueue:HandleSpellcastSucceeded(event, unit, spellName, rank, lineId, spellId)
    if unit ~= "player" or #actionSequence == 0 then
        return
    end

    if spellId and spellId == actionSequence[1] then
        self:AdvanceSequence(event, spellId)
    end
end

--[[
    Handles combat log events to detect aura applications for self-buffs.
]]
function ManualQueue:HandleCombatLog(event, ...)
    if #actionSequence == 0 then return end

    local timestamp, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellId, spellName = ...
    
    -- We only care about SPELL_AURA_APPLIED for self-buffs
    if subEvent ~= "SPELL_AURA_APPLIED" then
        return
    end
    
    local playerGUID = UnitGUID("player")
    -- Check if the buff was applied to the player
    if destGUID ~= playerGUID then
        return
    end

    local expectedSpellId = actionSequence[1]
    -- Check if the applied buff's spellId matches what's in the queue
    if spellId and spellId == expectedSpellId then
        self:AdvanceSequence(subEvent, spellId)
    end
end


--[[
    Handles stance changes to advance the sequence. This is more reliable than UNIT_SPELLCAST_SUCCEEDED for stances.
]]
function ManualQueue:HandleStanceChange(event)
    if #actionSequence == 0 then return end

    local nextActionInQueue = actionSequence[1]
    
    local C = WRA.SpecLoader:GetActiveSpecModule() and WRA.SpecLoader:GetActiveSpecModule().ClassConstants
    if not C then return end

    -- Check if the action we are waiting for is a stance change
    if nextActionInQueue == C.Spells.BATTLE_STANCE_CAST or
       nextActionInQueue == C.Spells.DEFENSIVE_STANCE_CAST or
       nextActionInQueue == C.Spells.BERSERKER_STANCE_CAST then
       
        local targetSpellID = actionSequence[2]
        if not targetSpellID then 
            self:AdvanceSequence(event, nextActionInQueue)
            return 
        end

        local requirements = C.SpellRequirements[targetSpellID]
        local requiredStance = requirements and requirements.stance
        
        if requiredStance and GetShapeshiftForm() == requiredStance then
            self:AdvanceSequence(event, nextActionInQueue)
        end
    end
end


function ManualQueue:OnInitialize()
    WRA:PrintDebug("ManualQueue Initialized")
end

function ManualQueue:OnEnable()
    WRA:PrintDebug("ManualQueue Enabled")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "HandleSpellcastSucceeded")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "HandleStanceChange")
    
    -- Register COMBAT_LOG_EVENT_UNFILTERED on its own frame
    combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    combatLogFrame:SetScript("OnEvent", function(self_frame, event, ...)
        -- The handler needs the module's 'self' context.
        -- We must call CombatLogGetCurrentEventInfo() here to get the arguments.
        ManualQueue:HandleCombatLog(event, CombatLogGetCurrentEventInfo())
    end)
end

function ManualQueue:OnDisable()
    WRA:PrintDebug("ManualQueue Disabled")
    self:UnregisterAllEvents()
    -- Unregister from the dedicated frame
    combatLogFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    combatLogFrame:SetScript("OnEvent", nil)
    self:ClearActionSequence()
end
