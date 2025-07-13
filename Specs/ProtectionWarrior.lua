-- Specs/ProtectionWarrior.lua
-- Rotation logic for Protection Warrior specialization.
-- MODIFIED (Refactor): Updated to use the new AOETracker module for enemy counting.
-- MODIFIED (Localization): Replaced hardcoded option names and descriptions with localization keys.
-- MODIFIED (Bugfix): Corrected NotifySettingChange to properly handle 'select' type options and display the correct value text.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local ProtectionWarrior = WRA:NewModule("ProtectionWarrior", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Lua shortcuts
local pairs, type, string_format, tostring = pairs, type, string.format, tostring
local GetShapeshiftForm, pcall, GetSpellInfo, IsPlayerSpell, IsCurrentSpell = GetShapeshiftForm, pcall, GetSpellInfo, IsPlayerSpell, IsCurrentSpell

-- Module references and constants
local C, State, CD, Aura, ActionMgr, Utils, DB, AOETracker

local function NotifySettingChange(key, value)
    WRA:PrintDebug("[ProtWarrior Notify] Key:", key, "Value:", tostring(value))

    -- Get the full options table for the current spec to correctly format the notification
    local specOptions = WRA:GetSpecOptions_ProtectionWarrior()
    if not specOptions or not specOptions[key] then
        WRA:PrintDebug("NotifySettingChange: Could not find option definition for key:", key)
        -- Fallback for safety
        local message = (L[key] or key) .. ": " .. tostring(value)
        WRA:SendMessage("WRA_NOTIFICATION_SHOW", message)
        WRA:SendMessage("WRA_SPEC_SETTING_CHANGED", key, value)
        return
    end

    local optionInfo = specOptions[key]
    -- Try to get the localized name from the option definition first
    local optionName = (type(optionInfo.name) == "function" and optionInfo.name()) or optionInfo.name or L[key] or key
    local message

    if optionInfo.type == "toggle" then
        local stateText = value and (L["NOTIFICATION_ENABLED"] or "开启") or (L["NOTIFICATION_DISABLED"] or "关闭")
        message = optionName .. " " .. stateText
    elseif optionInfo.type == "select" then
        -- This handles all select types generically by looking up the display text from the values table
        local selectedText = (optionInfo.values and optionInfo.values[value]) or tostring(value)
        message = optionName .. ": " .. selectedText
    else
        -- Fallback for other types like range sliders
        message = optionName .. ": " .. tostring(value)
    end
    
    WRA:SendMessage("WRA_NOTIFICATION_SHOW", message)
    WRA:SendMessage("WRA_SPEC_SETTING_CHANGED", key, value)
end

function ProtectionWarrior:OnInitialize()
    C = WRA.Constants
    ActionMgr = WRA.ActionManager
    WRA:PrintDebug("ProtectionWarrior Module Initializing.")
end

function ProtectionWarrior:OnEnable()
    WRA:PrintDebug("ProtectionWarrior Module Enabling...")

    State = WRA.StateManager
    CD = WRA.CooldownTracker
    Aura = WRA.AuraMonitor
    Utils = WRA.Utils
    AOETracker = WRA.AOETracker -- Get the new module

    if not State then WRA:PrintError("ProtectionWarrior: StateManager module not found!") end
    if not CD then WRA:PrintError("ProtectionWarrior: CooldownTracker module not found!") end
    if not Aura then WRA:PrintError("ProtectionWarrior: AuraMonitor module not found!") end
    if not Utils then WRA:PrintError("ProtectionWarrior: Utils module not found!") end
    if not AOETracker then WRA:PrintError("ProtectionWarrior: AOETracker module not found!") end

    if WRA.db and WRA.db.profile and WRA.db.profile.specs then
        DB = WRA.db.profile.specs.ProtectionWarrior
    end
    if not DB then
        WRA:PrintError("ProtectionWarrior DB profile not found! Creating a new one.")
        if not WRA.db.profile.specs then WRA.db.profile.specs = {} end
        WRA.db.profile.specs.ProtectionWarrior = {}
        DB = WRA.db.profile.specs.ProtectionWarrior
    end
    self.ClassConstants = C
    WRA:PrintDebug("ProtectionWarrior Module Enabled.")
end

function ProtectionWarrior:OnDisable()
    if ActionMgr and ActionMgr.UnregisterActionsByOwner then
        ActionMgr:UnregisterActionsByOwner("ProtectionWarrior")
    end
    WRA:PrintDebug("ProtectionWarrior Module Disabled.")
end

function ProtectionWarrior:IsReady(actionID, state, skipGCDCheckOverride)
    if not Utils then return false end
	
    if not IsPlayerSpell(actionID) and actionID ~= C.Spells.CLEAVE and actionID ~= C.Spells.HEROIC_STRIKE then
        return false
    end

    if actionID == C.Spells.HEROIC_STRIKE or actionID == C.Spells.CLEAVE then
        if IsCurrentSpell(actionID) then
            return false
        end
    end

    if not Utils:IsReadyWithQueue({id = actionID}) then
        return false
    end

    if actionID ~= C.Spells.DEFENSIVE_STANCE_CAST then
        local currentStance = GetShapeshiftForm()
        if currentStance ~= C.Stances.DEFENSIVE then
            if actionID ~= C.Spells.BATTLE_SHOUT and actionID ~= C.Spells.COMMANDING_SHOUT then
                return false
            end
        end
    end

    local spellName = GetSpellInfo(actionID)
    if not spellName then
        return false
    end

    if actionID == C.Spells.THUNDER_CLAP then
        if Aura:HasDebuff(C.Auras.THUNDER_CLAP_DEBUFF, "target") then return false end
    elseif actionID == C.Spells.DEMORALIZING_SHOUT then
        if Aura:HasDebuff(C.Auras.DEMORALIZING_SHOUT_DEBUFF, "target") then return false end
    elseif actionID == C.Spells.SHIELD_BLOCK then
        if Aura:HasBuff(C.Auras.SHIELD_BLOCK_BUFF, "player") then return false end
    end

    return true
end

function ProtectionWarrior:NeedsShoutRefresh(state)
    if not (Aura and DB and C and C.Spells and C.Auras) then return nil end
    local selectedShout = DB.selectedShoutType_Prot or "BATTLE" 
    if selectedShout == "NONE" then return nil end
    
    local preferredShoutSpellID = (selectedShout == "BATTLE" and C.Spells.BATTLE_SHOUT) or C.Spells.COMMANDING_SHOUT
    local preferredShoutBuffID = (selectedShout == "BATTLE" and C.Auras.BATTLE_SHOUT_BUFF) or C.Auras.COMMANDING_SHOUT_BUFF
    
    if not Aura:HasBuff(preferredShoutBuffID, "player", false) and self:IsReady(preferredShoutSpellID, state) then
        return preferredShoutSpellID
    end
    return nil
end

function ProtectionWarrior:GetNextAction(currentState)
    if not (State and DB and C and Aura and CD and Utils and AOETracker) then
        return { gcdAction = C.ACTION_ID_WAITING }
    end

    local playerState = currentState.player
    local targetState = currentState.target

    local shoutAction = self:NeedsShoutRefresh(currentState)
    if shoutAction then
        return { gcdAction = shoutAction }
    end

    if not (targetState and targetState.exists and targetState.isEnemy and not targetState.isDead) then
        return { gcdAction = C.ACTION_ID_IDLE }
    end

    if GetShapeshiftForm() ~= C.Stances.DEFENSIVE then
        if self:IsReady(C.Spells.DEFENSIVE_STANCE_CAST, currentState) then
            return { gcdAction = C.Spells.DEFENSIVE_STANCE_CAST }
        end
        return { gcdAction = C.ACTION_ID_WAITING }
    end

    local suggestedOffGcdAction = nil
    if playerState.power > 20 then
        -- *** REFACTOR: Use the new AOETracker module ***
        local numTargets_Melee = AOETracker:GetNearbyEnemyCount(8) or 0
        if numTargets_Melee >= (DB.aoeThreshold or 2) then
            if self:IsReady(C.Spells.CLEAVE, currentState, true) then
                suggestedOffGcdAction = C.Spells.CLEAVE
            end
        else
            if self:IsReady(C.Spells.HEROIC_STRIKE, currentState, true) then
                suggestedOffGcdAction = C.Spells.HEROIC_STRIKE
            end
        end
    end

    -- *** REFACTOR: Use the new AOETracker module ***
    local numTargets_AOE = AOETracker:GetNearbyEnemyCount(8) or 0

    if DB.useShieldBlock and playerState.healthPercent < (DB.shieldBlockHealthThreshold or 60) then
        if self:IsReady(C.Spells.SHIELD_BLOCK, currentState) then
            return { gcdAction = C.Spells.SHIELD_BLOCK, offGcdAction = suggestedOffGcdAction }
        end
    end

    if numTargets_AOE >= (DB.aoeThreshold or 2) then
        if DB.useThunderClap and self:IsReady(C.Spells.THUNDER_CLAP, currentState) then
            return { gcdAction = C.Spells.THUNDER_CLAP, offGcdAction = suggestedOffGcdAction }
        end
        if self:IsReady(C.Spells.REVENGE, currentState) then
            return { gcdAction = C.Spells.REVENGE, offGcdAction = suggestedOffGcdAction }
        end
        if DB.useShockwave and self:IsReady(C.Spells.SHOCKWAVE, currentState) then
            return { gcdAction = C.Spells.SHOCKWAVE, offGcdAction = suggestedOffGcdAction }
        end
        if self:IsReady(C.Spells.SHIELD_SLAM, currentState) then
            return { gcdAction = C.Spells.SHIELD_SLAM, offGcdAction = suggestedOffGcdAction }
        end
        if self:IsReady(C.Spells.DEVASTATE, currentState) then
            return { gcdAction = C.Spells.DEVASTATE, offGcdAction = suggestedOffGcdAction }
        end
    else
        if self:IsReady(C.Spells.SHIELD_SLAM, currentState) then
            return { gcdAction = C.Spells.SHIELD_SLAM, offGcdAction = suggestedOffGcdAction }
        end
        if self:IsReady(C.Spells.REVENGE, currentState) then
            return { gcdAction = C.Spells.REVENGE, offGcdAction = suggestedOffGcdAction }
        end
        if DB.useDemoShout and self:IsReady(C.Spells.DEMORALIZING_SHOUT, currentState) then
            return { gcdAction = C.Spells.DEMORALIZING_SHOUT, offGcdAction = suggestedOffGcdAction }
        end
        if DB.useShockwave and self:IsReady(C.Spells.SHOCKWAVE, currentState) then
            return { gcdAction = C.Spells.SHOCKWAVE, offGcdAction = suggestedOffGcdAction }
        end
        if self:IsReady(C.Spells.DEVASTATE, currentState) then
            return { gcdAction = C.Spells.DEVASTATE, offGcdAction = suggestedOffGcdAction }
        end
    end

    return { gcdAction = C.ACTION_ID_IDLE, offGcdAction = suggestedOffGcdAction }
end

function WRA:GetSpecOptions_ProtectionWarrior()
    local function GetSpecDBValue(key, defaultValue)
        if DB and DB[key] ~= nil then return DB[key] end
        return defaultValue
    end
    local function SetSpecDBValue(key, value)
        if DB then DB[key] = value else WRA:PrintError("Cannot set spec option, DB reference is nil!") end
    end
	
    local shoutTypeValues = { NONE = L["SHOUT_OPTION_NONE"], BATTLE = L["SHOUT_OPTION_BATTLE"], COMMANDING = L["SHOUT_OPTION_COMMANDING"] }

    return {
        threatHeader = { order = 3, type = "header", name = L["Threat & Damage"] },
        useThunderClap = {
            order = 10, type = "toggle", name = L["Use Thunder Clap"],
            desc = L["Use Thunder Clap_desc"],
            get = function() return GetSpecDBValue("useThunderClap", true) end,
            set = function(_, v) SetSpecDBValue("useThunderClap", v); NotifySettingChange("useThunderClap", v) end,
        },
        useDemoShout = {
            order = 20, type = "toggle", name = L["Use Demoralizing Shout"],
            desc = L["Use Demoralizing Shout_desc"],
            get = function() return GetSpecDBValue("useDemoShout", true) end,
            set = function(_, v) SetSpecDBValue("useDemoShout", v); NotifySettingChange("useDemoShout", v) end,
        },
        selectedShoutType_Prot = {
            order = 25, 
            type = "select", 
            name = L["OPTION_PROT_SELECTED_SHOUT_TYPE_NAME"],
            desc = L["OPTION_PROT_SELECTED_SHOUT_TYPE_DESC"],
            values = shoutTypeValues,
            get = function() return GetSpecDBValue("selectedShoutType_Prot", "BATTLE") end,
            set = function(_, v) SetSpecDBValue("selectedShoutType_Prot", v); NotifySettingChange("selectedShoutType_Prot", v) end,
            style = 'dropdown',
        },
        aoeHeader = { order = 30, type = "header", name = L["AOE"] },
        useShockwave = {
            order = 40, type = "toggle", name = L["Use Shockwave"],
            desc = L["Use Shockwave_desc"],
            get = function() return GetSpecDBValue("useShockwave", true) end,
            set = function(_, v) SetSpecDBValue("useShockwave", v); NotifySettingChange("useShockwave", v) end,
        },
        aoeThreshold = {
            order = 50, type = "range", name = L["AOE Target Threshold"],
            desc = L["AOE Target Threshold_desc"],
            min = 2, max = 10, step = 1,
            get = function() return GetSpecDBValue("aoeThreshold", 2) end,
            set = function(_, v) SetSpecDBValue("aoeThreshold", v) end,
        },
        survivalHeader = { order = 60, type = "header", name = L["Survival"] },
        useShieldBlock = {
            order = 70, type = "toggle", name = L["Use Shield Block"],
            desc = L["Use Shield Block_desc"],
            get = function() return GetSpecDBValue("useShieldBlock", true) end,
            set = function(_, v) SetSpecDBValue("useShieldBlock", v); NotifySettingChange("useShieldBlock", v) end,
        },
        shieldBlockHealthThreshold = {
            order = 80, type = "range", name = L["Shield Block Health %"],
            desc = L["Shield Block Health %_desc"],
            min = 20, max = 95, step = 5,
            get = function() return GetSpecDBValue("shieldBlockHealthThreshold", 60) end,
            set = function(_, v) SetSpecDBValue("shieldBlockHealthThreshold", v) end,
            disabled = function() return not GetSpecDBValue("useShieldBlock", true) end,
        },
    }
end
