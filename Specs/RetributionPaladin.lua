-- WRA/Specs/RetributionPaladin.lua
-- Rotation logic for Retribution Paladin specialization, based on Plan V6.
-- Implements conditional APL for Execute/Normal phases, Sustainability Mode, and adjustable Consecration priority.
-- MODIFIED: Reworked Divine Plea logic to be a high-priority skill in Sustainability Mode, and a low-priority filler otherwise.
-- MODIFIED: Simplified Divine Storm option to a single enable/disable toggle.
-- MODIFIED: Added selectable Seals and Judgements, and integrated the logic into the APL.
-- MODIFIED: Fixed main rotation stall when a Seal is required but cannot be cast (e.g., low mana).
-- MODIFIED: Removed the Judgement debuff check from IsReady to ensure Judgement is cast on cooldown, regardless of other Paladins' debuffs.
-- MODIFIED (Localization): Replaced hardcoded option names and descriptions with localization keys.
-- MODIFIED (Bugfix): Corrected NotifySettingChange to properly handle 'select' type options and display the correct value text.
-- MODIFIED (Consecration): Added a "Never" option for Consecration priority.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local RetributionPaladin = WRA:NewModule("RetributionPaladin", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Lua shortcuts
local IsPlayerSpell, GetSpellInfo, UnitPower, UnitFactionGroup = IsPlayerSpell, GetSpellInfo, UnitPower, UnitFactionGroup
local tinsert = table.insert -- performance optimization

-- Module references
local C, State, CD, Aura, Utils, DB, ActionMgr, TTD

-- Helper to get settings from the database with a default value
local function GetDBValue(key, defaultValue)
    if DB and DB[key] ~= nil then return DB[key] end
    return defaultValue
end

-- Helper to notify UI about setting changes for real-time updates
local function NotifySettingChange(key, value)
    WRA:PrintDebug("[RetPala Notify] Key:", key, "Value:", tostring(value))

    local specOptions = WRA:GetSpecOptions_RetributionPaladin()
    if not specOptions or not specOptions[key] then
        WRA:PrintDebug("NotifySettingChange: Could not find option definition for key:", key)
        local message = (L[key] or key) .. ": " .. tostring(value)
        WRA:SendMessage("WRA_NOTIFICATION_SHOW", message)
        WRA:SendMessage("WRA_SPEC_SETTING_CHANGED", key, value)
        return
    end

    local optionInfo = specOptions[key]
    local optionName = (type(optionInfo.name) == "function" and optionInfo.name()) or optionInfo.name or L[key] or key
    local message

    if optionInfo.type == "toggle" then
        message = optionName .. ": " .. (value and (L["NOTIFICATION_ENABLED"] or "开启") or (L["NOTIFICATION_DISABLED"] or "关闭"))
    elseif optionInfo.type == "select" then
        local selectedText = (optionInfo.values and optionInfo.values[value]) or tostring(value)
        message = optionName .. ": " .. selectedText
    else
        message = optionName .. ": " .. tostring(value)
    end
    
    WRA:SendMessage("WRA_NOTIFICATION_SHOW", message)
    WRA:SendMessage("WRA_SPEC_SETTING_CHANGED", key, value)
end

----------------------------------------------------
-- Module Lifecycle
----------------------------------------------------

function RetributionPaladin:OnInitialize()
    WRA:PrintDebug("RetributionPaladin Module Initializing.")
end

function RetributionPaladin:OnEnable()
    WRA:PrintDebug("RetributionPaladin Module Enabling...")
    -- Safely get module references
    C, State, CD, Aura, Utils, ActionMgr, TTD = WRA.Constants, WRA.StateManager, WRA.CooldownTracker, WRA.AuraMonitor, WRA.Utils, WRA.ActionManager, WRA.TTDTracker
    
    -- Initialize database reference
    if WRA.db and WRA.db.profile and WRA.db.profile.specs then
        if not WRA.db.profile.specs.RetributionPaladin then
            WRA.db.profile.specs.RetributionPaladin = {}
        end
        DB = WRA.db.profile.specs.RetributionPaladin
    else
        WRA:PrintError("RetributionPaladin: Database not found!")
        DB = {} -- Fallback
    end
    
    self.ClassConstants = C

    -- Register Avenging Wrath with ActionManager
    if ActionMgr and C and C.Spells then
        ActionMgr:RegisterAction(C.Spells.AVENGING_WRATH, {
            owner = "RetributionPaladin",
            priority = 90,
            checkReady = function(currentState, actionData)
                if not GetDBValue("useAvengingWrath", true) then return false end
                return self:IsReady(actionData.id, currentState)
            end,
            scope = "GCD",
            isOffGCD = true, -- Corrected to Off-GCD
            id = C.Spells.AVENGING_WRATH
        })
    end
end

function RetributionPaladin:OnDisable()
    WRA:PrintDebug("RetributionPaladin Module Disabled.")
    if ActionMgr and C and C.Spells then
        ActionMgr:UnregisterAction(C.Spells.AVENGING_WRATH)
    end
end

----------------------------------------------------
-- Core Logic: IsReady & GetNextAction
----------------------------------------------------

function RetributionPaladin:IsReady(actionID, state)
    if not (Utils and C and DB) then return false end

    -- Basic check: Is it a known spell and does the player have enough mana?
    if not IsPlayerSpell(actionID) or not Utils:IsReadyWithQueue({id = actionID}) then
        return false
    end
    
    -- Check specific conditions for each ability
    if actionID == C.Spells.DIVINE_PLEA then
        if Aura:HasBuff(C.Auras.DIVINE_PLEA_BUFF, "player", true) then return false end
    
    elseif actionID == C.Spells.HAMMER_OF_WRATH then
        if not state.target or not state.target.healthPercent or state.target.healthPercent > 20 then
            return false
        end

    elseif actionID == C.Spells.DIVINE_STORM then
        if not GetDBValue("useDivineStorm", true) then return false end
        
    elseif actionID == C.Spells.EXORCISM then
        if not Aura:HasBuff(C.Auras.ART_OF_WAR_PROC, "player") then
            return false
        end

    elseif actionID == C.Spells.CONSECRATION then
        if not TTD then return false end
        if TTD:GetTTD(state.target.guid) <= 4 then return false end
    end

    return true
end

function RetributionPaladin:GetNextAction(currentState)
    -- Ensure all required modules and state are available
    if not (C and State and CD and Aura and Utils and currentState and currentState.player and currentState.target) then
        return { gcdAction = C.ACTION_ID_WAITING or 0 }
    end
    
    local player = currentState.player
    local target = currentState.target

    -- Basic checks before entering rotation logic    
    if not (target.exists and target.isEnemy and not target.isDead) then return { gcdAction = C.ACTION_ID_IDLE } end
    
    -- 1. Handle Off-GCD abilities first
    local suggestedOffGcdAction = nil
    if self:IsReady(C.Spells.HAND_OF_RECKONING, currentState) then
        suggestedOffGcdAction = C.Spells.HAND_OF_RECKONING
    end
    
    local amOffGcdAction = ActionMgr:GetHighestPriorityAction(currentState, "GCD", "OffGCD")
    if amOffGcdAction then
        suggestedOffGcdAction = amOffGcdAction
    end
    
    -- 2. Seal Maintenance Logic
    local _, playerFaction = UnitFactionGroup("player")
    local defaultSealKey = playerFaction == "Horde" and "CORRUPTION" or "VENGEANCE"
    local selectedSealKey = GetDBValue("selectedSeal_Ret", defaultSealKey)
    
    local sealSpellID, sealAuraID
    if selectedSealKey == "COMMAND" then
        sealSpellID = C.Spells.SEAL_OF_COMMAND; sealAuraID = C.Auras.SEAL_OF_COMMAND_BUFF
    else 
        sealSpellID = (playerFaction == "Horde" and C.Spells.SEAL_OF_CORRUPTION or C.Spells.SEAL_OF_VENGEANCE)
        sealAuraID = (playerFaction == "Horde" and C.Auras.SEAL_OF_CORRUPTION_BUFF or C.Auras.SEAL_OF_VENGEANCE_BUFF)
    end

    if sealAuraID and not Aura:HasBuff(sealAuraID, "player", true) then
        if self:IsReady(sealSpellID, currentState) then
            return { gcdAction = sealSpellID, offGcdAction = suggestedOffGcdAction }
        else
            return { gcdAction = C.ACTION_ID_WAITING, offGcdAction = suggestedOffGcdAction }
        end
    end

    -- 3. Build Action Priority List (APL)
    local apl = {}
    local isExecutePhase = target.healthPercent and target.healthPercent <= 20
    local selectedJudgementKey = GetDBValue("selectedJudgement_Ret", "WISDOM")
    local judgementToUse = (selectedJudgementKey == "LIGHT" and C.Spells.JUDGEMENT_OF_LIGHT or C.Spells.JUDGEMENT_OF_WISDOM)
    
    -- High priority Divine Plea in Sustainability Mode
    if GetDBValue("useSustainabilityMode", false) and player.powerPercent < 70 then
        tinsert(apl, C.Spells.DIVINE_PLEA)
    end
    
    if isExecutePhase then
        -- ###斩杀阶段 优先级###
        tinsert(apl, C.Spells.HAMMER_OF_WRATH)
        tinsert(apl, C.Spells.DIVINE_STORM)
        tinsert(apl, judgementToUse)
        tinsert(apl, C.Spells.CRUSADER_STRIKE)
    else
        -- ###常规阶段 优先级###
        tinsert(apl, C.Spells.CRUSADER_STRIKE)
        tinsert(apl, judgementToUse)
        tinsert(apl, C.Spells.DIVINE_STORM)
    end
    
    -- [!code ++]
    -- Consecration and Exorcism logic
    local consecrationPrio = GetDBValue("consecrationPriority", "High")
    if consecrationPrio == "High" then
        tinsert(apl, C.Spells.CONSECRATION)
    end
    tinsert(apl, C.Spells.EXORCISM)
    if consecrationPrio == "Low" then
        tinsert(apl, C.Spells.CONSECRATION)
    end
    -- If "Never", it's simply not added to the APL.
    -- [!code --]
    
    -- Low priority Divine Plea filler
    if not GetDBValue("useSustainabilityMode", false) and player.powerPercent < 95 then
        tinsert(apl, C.Spells.DIVINE_PLEA)
    end

    -- Iterate through the APL and find the first ready ability
    for _, spellID in ipairs(apl) do
        if self:IsReady(spellID, currentState) then
            return { gcdAction = spellID, offGcdAction = suggestedOffGcdAction }
        end
    end

    -- If no action is ready, return IDLE
    return { gcdAction = C.ACTION_ID_IDLE, offGcdAction = suggestedOffGcdAction }
end


----------------------------------------------------
-- Options Panel Definition
----------------------------------------------------

function WRA:GetSpecOptions_RetributionPaladin()
    local function SetSpecDBValue(key, value)
        if DB then 
            DB[key] = value 
            NotifySettingChange(key, value)
        else 
            WRA:PrintError("Cannot set spec option, RetributionPaladin DB reference is nil!") 
        end
    end

    -- Dynamically create seal options based on player faction
    local sealTypeValues = {
        COMMAND = L["SEAL_OPTION_COMMAND"]
    }
    local _, playerFaction = UnitFactionGroup("player")
    if playerFaction == "Horde" then
        sealTypeValues["CORRUPTION"] = L["SEAL_OPTION_CORRUPTION"]
    else
        sealTypeValues["VENGEANCE"] = L["SEAL_OPTION_VENGEANCE"]
    end
    
    local judgementTypeValues = {
        WISDOM = L["JUDGEMENT_OPTION_WISDOM"],
        LIGHT = L["JUDGEMENT_OPTION_LIGHT"]
    }
    
    -- [!code ++]
    -- Consecration priority values
    local consecrationValues = {
        High = L["High"],
        Low = L["Low"],
        Never = L["Never"] -- New option
    }
    -- [!code --]

    return {
        ret_header = {
            order = 1, type = "header", name = L["ret_header"],
        },
        useAvengingWrath = {
            order = 10, type = "toggle", name = L["useAvengingWrath"],
            desc = L["useAvengingWrath_desc"],
            get = function() return GetDBValue("useAvengingWrath", true) end,
            set = function(_, v) SetSpecDBValue("useAvengingWrath", v) end,
        },
        useDivineStorm = {
            order = 20, type = "toggle", name = L["useDivineStorm"],
            desc = L["useDivineStorm_desc"],
            get = function() return GetDBValue("useDivineStorm", true) end,
            set = function(_, v) SetSpecDBValue("useDivineStorm", v) end,
        },
        sustainability_header = {
            order = 30, type = "header", name = L["sustainability_header"],
        },
        useSustainabilityMode = {
            order = 31, type = "toggle", name = L["useSustainabilityMode"],
            desc = L["useSustainabilityMode_desc"],
            get = function() return GetDBValue("useSustainabilityMode", false) end,
            set = function(_, v) SetSpecDBValue("useSustainabilityMode", v) end,
        },
        consecrationPriority = {
            order = 32, type = "select", name = L["consecrationPriority"],
            desc = L["consecrationPriority_desc"],
            values = consecrationValues, -- [!code ++]
            get = function() return GetDBValue("consecrationPriority", "High") end,
            set = function(_, v) SetSpecDBValue("consecrationPriority", v) end,
        },
        seal_judgement_header = {
            order = 40, type = "header", name = L["seal_judgement_header"],
        },
        selectedSeal_Ret = {
            order = 41, type = "select", name = L["selectedSeal_Ret"],
            desc = L["selectedSeal_Ret_desc"],
            values = sealTypeValues,
            get = function() 
                local defaultSeal = (playerFaction == "Horde" and "CORRUPTION" or "VENGEANCE")
                return GetDBValue("selectedSeal_Ret", defaultSeal) 
            end,
            set = function(_, v) SetSpecDBValue("selectedSeal_Ret", v) end,
        },
        selectedJudgement_Ret = {
            order = 42, type = "select", name = L["selectedJudgement_Ret"],
            desc = L["selectedJudgement_Ret_desc"],
            values = judgementTypeValues,
            get = function() return GetDBValue("selectedJudgement_Ret", "WISDOM") end,
            set = function(_, v) SetSpecDBValue("selectedJudgement_Ret", v) end,
        },
    }
end
