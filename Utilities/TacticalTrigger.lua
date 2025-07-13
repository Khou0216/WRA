-- Utilities/TacticalTrigger.lua
-- A generic module that monitors for user-defined auras (buffs/debuffs)
-- and activates tactical abilities like Nitro Boosts when those auras are present.
-- [Gemini Edit] Reworked to handle delayed checks inspired by the user's WA logic.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)

local TacticalTrigger = WRA:NewModule("TacticalTrigger", "AceEvent-3.0", "AceTimer-3.0")

-- Module references
local AuraMonitor, NitroBoots, ConditionsModule, RotationEngine, CooldownTracker, Constants = nil, nil, nil, nil, nil, nil

-- Internal state
local triggerAuras = {}
local activeTriggers = {}
local isInitialized = false
local combatLogFrame = CreateFrame("Frame")

function TacticalTrigger:OnInitialize() end

function TacticalTrigger:InitializeDependencies()
    if isInitialized then return end
    AuraMonitor = WRA.AuraMonitor
    NitroBoots = WRA.NitroBoots
    ConditionsModule = WRA:GetModule("TacticalTrigger_Conditions", true)
    RotationEngine = WRA.RotationEngine
    CooldownTracker = WRA.CooldownTracker
    Constants = WRA.Constants
    
    if not (AuraMonitor and NitroBoots and RotationEngine and CooldownTracker and Constants) then
        return
    end

    self:UpdateTriggerList()
    self:RegisterEvent("UNIT_AURA")
    if ConditionsModule and ConditionsModule.triggers then
        combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        WRA:PrintDebug("[TacticalTrigger] Registered for COMBAT_LOG_EVENT_UNFILTERED.")
        -- [Gemini] 核心修复：采用更直接、更可靠的方式处理战斗日志事件。
        -- 我们现在直接在OnEvent脚本中调用CombatLogGetCurrentEventInfo()，
        -- 并将其返回的参数直接传递给HandleCombatLog函数。
        -- 这避免了在嵌套函数中调用API可能出现的时序问题，确保了参数的正确传递。
        combatLogFrame:SetScript("OnEvent", function() 
            WRA:PrintDebug("[TacticalTrigger] OnEvent fired for COMBAT_LOG_EVENT_UNFILTERED.")
            self:HandleCombatLog(CombatLogGetCurrentEventInfo()) 
        end)
    end
    isInitialized = true
end

function TacticalTrigger:OnEnable()
    self:RegisterMessage("WRA_CORE_MODULES_ENABLED", "InitializeDependencies")
    self:RegisterMessage("WRA_NITRO_BOOTS_DEACTIVATED", "OnNitroDeactivated")
    self:RegisterMessage("WRA_EXECUTE_TACTICAL_TRIGGER", "HandleDelayedTrigger") -- [Gemini Edit] Listen for the delayed trigger message
    if WRA.AuraMonitor and WRA.NitroBoots and WRA.RotationEngine and WRA.CooldownTracker and WRA.Constants then
        self:InitializeDependencies()
    end
end

function TacticalTrigger:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    combatLogFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    combatLogFrame:SetScript("OnEvent", nil)
    wipe(activeTriggers)
    isInitialized = false
end

function TacticalTrigger:OnNitroDeactivated()
    wipe(activeTriggers)
end

-- [Gemini Edit] New handler for the delayed trigger message
function TacticalTrigger:HandleDelayedTrigger(eventName, payload)
    if not isInitialized or type(payload) ~= "table" or not payload.triggerName or not payload.action then return end
    WRA:PrintDebug("[TacticalTrigger] Received delayed execution for:", payload.triggerName, "with action:", payload.action)
    ActivateTrigger(self, payload)
end

local function ActivateTrigger(self, payload)
    if not activeTriggers[payload.triggerName] then
        local success = false
        
        -- [Gemini] 优化：根据payload中的action来决定执行哪个动作。
        -- 这使得触发器系统可以灵活地激活不同的技能，而不仅仅是火箭靴。
        if payload.action == "NitroBoots" then
            -- 火箭靴的特定检查和激活逻辑
            local slotCooldownStart, _, _ = GetInventoryItemCooldown("player", Constants.EquipmentSlots.FEET)
            if slotCooldownStart > 0 then
                return -- 如果脚部装备槽正在冷却中，则直接阻止触发。
            end
            success = NitroBoots:Activate()
        --[[
        elseif payload.action == "EngineeringGloves" then
            -- 未来可以添加工程手套或其他技能的逻辑
            success = EngineeringGloves:Activate()
        ]]
        end

        if success then
            activeTriggers[payload.triggerName] = true
        end
    end
end

function TacticalTrigger:HandleCombatLog(...)
    WRA:PrintDebug("[TacticalTrigger] HandleCombatLog called.")
    if not isInitialized or not ConditionsModule or not ConditionsModule.triggers then return end
    -- [Gemini] 修复：现在直接使用传递进来的参数。
    local subEvent = select(2, ...)
    WRA:PrintDebug(string.format("[TacticalTrigger] Detected subEvent: %s", tostring(subEvent)))
    for _, trigger in ipairs(ConditionsModule.triggers) do
        for _, eventName in ipairs(trigger.events) do
            if eventName == subEvent then
                WRA:PrintDebug(string.format("[TacticalTrigger] Match found for trigger '%s'. Calling condition function.", trigger.name))
                -- 将所有战斗日志参数传递给条件函数，并检查其返回值。
                local pcallSuccess, conditionResultOrError = pcall(trigger.condition, ...)
                if not pcallSuccess then
                    -- 如果条件函数本身出错，打印错误信息。
                    WRA:PrintError(string.format("[TacticalTrigger] Error in condition for trigger '%s': %s", trigger.name, tostring(conditionResultOrError)))
                elseif conditionResultOrError == true then
                    -- 如果条件函数返回true，表示它已成功处理此事件。
                    -- 我们应立即返回，以防止其他触发器再次处理同一个事件。
                    return
                end
                break -- 即使条件不满足（返回false），我们仍然需要跳出内层循环，继续检查下一个触发器。
            end
        end
    end
end

function TacticalTrigger:UpdateTriggerList()
    wipe(triggerAuras)
    local configString = WRA.db and WRA.db.profile.tacticalTriggers
    if configString and configString ~= "" then
        for entry in string.gmatch(configString, "[^,\n\r]+") do
            local id, target, duration = string.match(entry, "^%s*(%d+)%s*:%s*([a-zA-Z]+)%s*:%s*(%d+)%s*$")
            if id and target and duration then
                id, duration = tonumber(id), tonumber(duration)
                target = string.lower(target)
                if id and duration and (target == "player" or target == "target") then
                    triggerAuras[id] = { target = target, duration = duration }
                end
            end
        end
    end
end

function TacticalTrigger:UNIT_AURA(event, unit)
    if not isInitialized or not (unit == "player" or unit == "target") then return end
    if not next(triggerAuras) then return end
    for spellId, config in pairs(triggerAuras) do
        if config.target == unit and AuraMonitor:HasAura(spellId, unit) then
            local payload = { triggerName = tostring(spellId), action = "NitroBoots" }
            ActivateTrigger(self, payload)
        end
    end
end
