-- Utilities/NitroBoots.lua
-- A dedicated module to handle the logic for Nitro Boosts.
-- [Gemini Edit] FINAL: This version uses the user-preferred SecureActionButtonTemplate for macro creation AND correctly removes the redundant cooldown check.
-- MODIFIED (Debug): Added detailed debug output to the checkReady function.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)

local NitroBoots = WRA:NewModule("NitroBoots", "AceEvent-3.0", "AceTimer-3.0")

-- Module references
local ActionMgr, StateModifier, CooldownTracker, AuraMonitor, Constants = nil, nil, nil, nil, nil
local nitroBootsItemId = nil
local isActivated = false
local isInitialized = false

-- [Gemini] 核心修复：使用专用的战斗日志框架来可靠地检测光环应用，
-- 避免依赖于有延迟的 AuraMonitor 或不精确的 UNIT_AURA 事件。
local combatLogFrame = CreateFrame("Frame")

-- Function to create the macro and keybinding using a secure button
local function CreateMacroAndBinding()
    local engineeringSpellID = 51306 
    local hasEngineering = IsPlayerSpell(engineeringSpellID)

    if not hasEngineering then
        return
    end

    WRA:Print("WRA: Engineering detected. Creating secure binding for Nitro Boosts...")

    local buttonName = "WRA_ExtBind_NitroBoots"
    local macroText = "/use 8" -- Use item in Feet slot
    local bindingKey = "CTRL-F6"

    -- Create a secure action button. This button is not visible.
    local secureButton = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate")
    
    -- Set the button's attribute to "macro" and define its text
    secureButton:SetAttribute("type", "macro")
    secureButton:SetAttribute("macrotext", macroText)
    
    -- Bind the key to a click on our secure button
    SetBinding(bindingKey, "CLICK " .. buttonName .. ":LeftButton")
    
    -- Save the bindings to make them permanent for the current character set.
    SaveBindings(GetCurrentBindingSet())
    WRA:Print("WRA: Nitro Boosts secure binding set to " .. bindingKey)
end

function NitroBoots:OnInitialize()
    -- OnInitialize is a good place to set up things that don't depend on other modules.
end

function NitroBoots:InitializeDependencies()
    if isInitialized then return end

    ActionMgr = WRA.ActionManager
    StateModifier = WRA.StateModifier
    CooldownTracker = WRA.CooldownTracker
    AuraMonitor = WRA.AuraMonitor
    Constants = WRA.Constants
    
    if not (ActionMgr and StateModifier and CooldownTracker and AuraMonitor and Constants) then
        return
    end
    
    if Constants and Constants.Items then
        nitroBootsItemId = -Constants.Items.NITRO_BOOTS
    end

    -- Call the macro creation here, which is a much safer point in the loading process.
    CreateMacroAndBinding()

    isInitialized = true
end

function NitroBoots:OnEnable()
    self:RegisterMessage("WRA_CORE_MODULES_ENABLED", "InitializeDependencies")
    
    if WRA.StateModifier then
        self:InitializeDependencies()
    end

    -- [Gemini] 注册战斗日志事件
    combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    combatLogFrame:SetScript("OnEvent", function(self_frame, event, ...)
        self:HandleCombatLog(event, CombatLogGetCurrentEventInfo())
    end)
end

function NitroBoots:OnDisable()
    self:Deactivate()
    isInitialized = false
    self:UnregisterMessage("WRA_CORE_MODULES_ENABLED")

    -- [Gemini] 注销战斗日志事件
    combatLogFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    combatLogFrame:SetScript("OnEvent", nil)
end

-- [Gemini] 新的战斗日志处理器，用于在使用后立即停用系统
function NitroBoots:HandleCombatLog(event, ...)
    if not isInitialized or not isActivated then return end

    local timestamp, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = ...
    
    -- 检查玩家是否获得了火箭靴的增益效果
    if subEvent == "SPELL_AURA_APPLIED" and destGUID == WRA.playerGUID and spellId == Constants.Auras.NITRO_BOOTS_BUFF then
        WRA:PrintDebug("[NitroBoots] Detected Nitro Boots buff via combat log. Deactivating.")
        self:Deactivate()
    end
end

function NitroBoots:Activate()
    if not isInitialized or not nitroBootsItemId or isActivated then return false end

    -- [Gemini] 核心改进：将冷却检查移至此处，使其成为激活的唯一入口点。
    -- 这样可以确保无论是自动触发还是手动命令，都会执行此检查。
    if not CooldownTracker:IsReady(nitroBootsItemId) then
        WRA:PrintDebug("[NitroBoots] Activate failed: on cooldown.")
        return false
    end

    isActivated = true
    StateModifier:Add("player.needsSpeedBoost", true, 5)
    WRA:PrintDebug("[NitroBoots] Activated. StateModifier 'player.needsSpeedBoost' set to true for 5s.")

    ActionMgr:RegisterEncounterAction(nitroBootsItemId, {
        priority = 200,
        scope = "GLOBAL",
        isOffGCD = true,
        id = nitroBootsItemId,
        checkReady = function(currentState, actionData)
            -- Initial checks
            if not WRA.db.profile.useNitroBoots then return false end
            if not currentState.player.needsSpeedBoost then return false end

            -- [Gemini] 核心修复：添加一个“保险丝”逻辑。
            -- 如果我们已经获得了加速Buff，或者火箭靴本身已经进入冷却，
            -- 这都意味着“需要加速”的状态已经满足或正在被满足。
            -- 在这种情况下，我们应该立即停用系统以清理状态，并返回false来停止推荐。
            -- 这可以防止在任何情况下（包括战斗日志事件延迟）推荐被卡住。
            local hasBuff = AuraMonitor:HasBuff(Constants.Auras.NITRO_BOOTS_BUFF, "player")
            -- [Gemini] BUGFIX: CooldownTracker expects a positive item ID, not the negative action ID.
            local isReady = CooldownTracker:IsReady(Constants.Items.NITRO_BOOTS)
            local isOnCooldown = not isReady

            if hasBuff or isOnCooldown then
                -- This is the critical failsafe. If the buff is up or the item is on CD, deactivate the system.
                WRA:PrintDebug("[NitroBoots:checkReady] Failsafe triggered. Deactivating.")
                -- Calling Deactivate() will remove the 'needsSpeedBoost' state and unregister this action.
                NitroBoots:Deactivate()
                return false
            end

            -- If all checks pass, it's ready to be recommended.
            return true
        end
    })

    -- 激活后，立即强制RotationEngine重新评估，以便能够立刻推荐火箭靴。
    if WRA.RotationEngine and WRA.RotationEngine.ForceUpdate then
        WRA.RotationEngine:ForceUpdate()
    end

    return true
end

function NitroBoots:Deactivate()
    if not isInitialized or not isActivated then return end

    -- [Gemini] 核心修复：
    -- 立即将状态设置为非活动，这样在同一帧内的后续检查就不会再次触发Deactivate。
    isActivated = false
    
    -- 立即移除状态修改器，以确保RotationEngine在下一刻就能看到正确的状态。
    if StateModifier then 
        StateModifier:Remove("player.needsSpeedBoost") 
    end

    -- 使用0秒延迟的计时器来推迟注销操作。
    -- 这可以防止在ActionManager遍历其动作列表时，我们尝试修改该列表（通过UnregisterAction），
    -- 从而解决了导致插件卡死的执行时序冲突。
    if ActionMgr and nitroBootsItemId then
        self:ScheduleTimer(function() 
            ActionMgr:UnregisterAction(nitroBootsItemId) 
        end, 0)
    end

    self:SendMessage("WRA_NITRO_BOOTS_DEACTIVATED")
end
