-- WRA/Specs/ProtectionPaladin.lua
-- Rotation logic for Protection Paladin specialization.
-- MODIFIED (Gemini): Re-implemented the full WowSims APL logic (interleaving, smart waiting)
-- while correctly integrating all previously added features like Divine Plea, Judgement priority, and Seal/Fury checks.
-- MODIFIED: Added NotifySettingChange to provide real-time UI updates for the QuickConfig panel.
-- FIXED: Corrected the module name from "ProtectionWarrior" to "ProtectionPaladin".
-- MODIFIED (Localization): Replaced hardcoded option names and descriptions with localization keys.
-- MODIFIED (Bugfix): Corrected NotifySettingChange to properly handle 'select' type options and display the correct value text.
-- FIXED (Divine Plea): Corrected the IsReady logic for Divine Plea to properly respect the user's toggle setting.

local addonName, _ = ...
local WRA = LibStub("AceAddon-3.0"):GetAddon(addonName)
-- *** FIX: The module name must match the file's purpose. ***
local ProtectionPaladin = WRA:NewModule("ProtectionPaladin", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Lua shortcuts
local pairs, type, tostring = pairs, type, tostring
local IsPlayerSpell, GetSpellInfo, GetSpellPowerCost, UnitFactionGroup = IsPlayerSpell, GetSpellInfo, GetSpellPowerCost, UnitFactionGroup

-- Module references and constants
local C, State, CD, Aura, Utils, DB

-- This helper function is now defined at the module level
-- to be accessible by all other functions within this file.
local function GetSpecDBValue(key, defaultValue)
    if DB and DB[key] ~= nil then return DB[key] end
    return defaultValue
end

-- Function to notify the UI of setting changes
local function NotifySettingChange(key, value)
    WRA:PrintDebug("[ProtPala Notify] Key:", key, "Value:", tostring(value))
    
    local specOptions = WRA:GetSpecOptions_ProtectionPaladin()
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
        local stateText = value and (L["NOTIFICATION_ENABLED"] or "开启") or (L["NOTIFICATION_DISABLED"] or "关闭")
        message = optionName .. " " .. stateText
    elseif optionInfo.type == "select" then
        local selectedText = (optionInfo.values and optionInfo.values[value]) or tostring(value)
        message = optionName .. ": " .. selectedText
    else
        message = optionName .. ": " .. tostring(value)
    end
    
    WRA:SendMessage("WRA_NOTIFICATION_SHOW", message)
    WRA:SendMessage("WRA_SPEC_SETTING_CHANGED", key, value)
end

function ProtectionPaladin:OnInitialize()
    WRA:PrintDebug("ProtectionPaladin Module Initializing.")
end

function ProtectionPaladin:OnEnable()
    WRA:PrintDebug("ProtectionPaladin Module Enabling...")
    C, State, CD, Aura, Utils = WRA.Constants, WRA.StateManager, WRA.CooldownTracker, WRA.AuraMonitor, WRA.Utils
    
    if WRA.db and WRA.db.profile and WRA.db.profile.specs then
        if not WRA.db.profile.specs.ProtectionPaladin then
            WRA.db.profile.specs.ProtectionPaladin = {}
        end
        DB = WRA.db.profile.specs.ProtectionPaladin
    else
        WRA:PrintError("ProtectionPaladin: Database not found!")
        DB = {} -- Fallback
    end
    
    self.ClassConstants = C
end

function ProtectionPaladin:OnDisable()
    WRA:PrintDebug("ProtectionPaladin Module Disabled.")
end

function ProtectionPaladin:IsReady(actionID, state)
    if not IsPlayerSpell(actionID) then
        return false
    end

    local manaCostInfo = GetSpellPowerCost(actionID)
    if manaCostInfo and manaCostInfo[1] and manaCostInfo[1].cost > state.player.power then
        return false
    end

    if not Utils:IsReadyWithQueue({id = actionID}) then
        return false
    end

    if actionID == C.Spells.HOLY_SHIELD then
        if Aura:HasBuff(C.Auras.HOLY_SHIELD_BUFF, "player", true) then
            return false
        end
    elseif actionID == C.Spells.EXORCISM then
        if not Aura:HasBuff(C.Auras.ART_OF_WAR_PROC, "player") then
            return false
        end
    elseif actionID == C.Spells.DIVINE_PLEA then
        -- [!code ++]
        -- *** BUGFIX START ***
        -- 1. If the user has toggled it off in the options, it's never ready.
        if not GetSpecDBValue("useDivinePlea", true) then
            return false
        end
        
        -- 2. If the buff is already active, it's not ready.
        if Aura:HasBuff(C.Auras.DIVINE_PLEA_BUFF, "player", true) then
            return false
        end

        -- 3. If mana is above the threshold, it's not ready.
        if state.player.powerPercent >= GetSpecDBValue("divinePleaManaThreshold", 50) then
            return false
        end
        -- *** BUGFIX END ***
        -- [!code --]
    elseif C.Spells.HAMMER_OF_WRATH and actionID == C.Spells.HAMMER_OF_WRATH then
        if not state.target or not state.target.healthPercent or state.target.healthPercent > 20 then
            return false
        end
    end

    return true
end

function ProtectionPaladin:GetNextAction(currentState)
    if not (C and State and CD and Aura and Utils and currentState and currentState.player) then
        return { gcdAction = C.ACTION_ID_WAITING or 0, offGcdAction = nil }
    end

    local player = currentState.player
    local target = currentState.target
    local suggestedOffGcdAction = nil -- Kept for future use with Off-GCD abilities

    -- Highest Priority: Maintain Righteous Fury if toggled on
    if GetSpecDBValue("useRighteousFury", true) and not Aura:HasBuff(C.Auras.RIGHTEOUS_FURY_BUFF, "player") then
        if self:IsReady(C.Spells.RIGHTEOUS_FURY, currentState) then
            return { gcdAction = C.Spells.RIGHTEOUS_FURY, offGcdAction = suggestedOffGcdAction }
        end
    end
    
    -- Needs a valid target for the rest of the rotation
    if not (target and target.exists and target.isEnemy and not target.isDead) then
        return { gcdAction = C.ACTION_ID_IDLE or "IDLE", offGcdAction = suggestedOffGcdAction }
    end
    
    -- Seal Maintenance Logic
    local _, playerFaction = UnitFactionGroup("player")
    local defaultSealKey = playerFaction == "Horde" and "CORRUPTION" or "VENGEANCE"
    local selectedSealKey = GetSpecDBValue("selectedSeal_Prot", defaultSealKey)
    
    local sealSpellID, sealAuraID
    if selectedSealKey == "COMMAND" then
        sealSpellID = C.Spells.SEAL_OF_COMMAND
        sealAuraID = C.Auras.SEAL_OF_COMMAND_BUFF
    else 
        sealSpellID = (playerFaction == "Horde" and C.Spells.SEAL_OF_CORRUPTION or C.Spells.SEAL_OF_VENGEANCE)
        sealAuraID = (playerFaction == "Horde" and C.Auras.SEAL_OF_CORRUPTION_BUFF or C.Auras.SEAL_OF_VENGEANCE_BUFF)
    end

    if sealAuraID and not Aura:HasBuff(sealAuraID, "player", true) then
        if self:IsReady(sealSpellID, currentState) then
            return { gcdAction = sealSpellID, offGcdAction = suggestedOffGcdAction }
        end
    end

    -- Dynamic Judgement Selection
    local selectedJudgementKey = GetSpecDBValue("selectedJudgement_Prot", "WISDOM")
    local judgementToUse = (selectedJudgementKey == "LIGHT" and C.Spells.JUDGEMENT_OF_LIGHT or C.Spells.JUDGEMENT_OF_WISDOM)

    -- == WowSims APL with Integrated Enhancements ==

    local hammerOfTheRighteousCD = CD:GetCooldownRemaining(C.Spells.HAMMER_OF_THE_RIGHTEOUS)
    local shieldOfRighteousnessCD = CD:GetCooldownRemaining(C.Spells.SHIELD_OF_RIGHTEOUSNESS)

    -- 1. Divine Plea for Mana Management
    if self:IsReady(C.Spells.DIVINE_PLEA, currentState) then
        return { gcdAction = C.Spells.DIVINE_PLEA, offGcdAction = suggestedOffGcdAction }
    end

    -- 2. Forced Interleaving Logic from WowSims
    if hammerOfTheRighteousCD < 3 and self:IsReady(C.Spells.SHIELD_OF_RIGHTEOUSNESS, currentState) then
        return { gcdAction = C.Spells.SHIELD_OF_RIGHTEOUSNESS, offGcdAction = suggestedOffGcdAction }
    end
    
    if shieldOfRighteousnessCD < 3 and self:IsReady(C.Spells.HAMMER_OF_THE_RIGHTEOUS, currentState) then
        return { gcdAction = C.Spells.HAMMER_OF_THE_RIGHTEOUS, offGcdAction = suggestedOffGcdAction }
    end

    -- 3. Hammer of Wrath (Execute)
    if C.Spells.HAMMER_OF_WRATH and self:IsReady(C.Spells.HAMMER_OF_WRATH, currentState) then
        return { gcdAction = C.Spells.HAMMER_OF_WRATH, offGcdAction = suggestedOffGcdAction }
    end

    -- 4. Smart Wait for core abilities
    local isHotRReady = hammerOfTheRighteousCD <= 0
    local isSoRReady = shieldOfRighteousnessCD <= 0
    if not isHotRReady and not isSoRReady and (hammerOfTheRighteousCD < 0.36 or shieldOfRighteousnessCD < 0.36) then
        return { gcdAction = C.ACTION_ID_WAITING or 0, offGcdAction = suggestedOffGcdAction }
    end
    
    -- 5. Judgement (Elevated Priority to ensure it's used)
    if self:IsReady(judgementToUse, currentState) then
        return { gcdAction = judgementToUse, offGcdAction = suggestedOffGcdAction }
    end

    -- 6. Consecration
    if self:IsReady(C.Spells.CONSECRATION, currentState) then
        return { gcdAction = C.Spells.CONSECRATION, offGcdAction = suggestedOffGcdAction }
    end

    -- 7. Holy Shield
    if GetSpecDBValue("useHolyShield", true) and self:IsReady(C.Spells.HOLY_SHIELD, currentState) then
        return { gcdAction = C.Spells.HOLY_SHIELD, offGcdAction = suggestedOffGcdAction }
    end

    -- 8. Exorcism (On Art of War proc)
    if self:IsReady(C.Spells.EXORCISM, currentState) then
        return { gcdAction = C.Spells.EXORCISM, offGcdAction = suggestedOffGcdAction }
    end
    
    -- Fallback/Idle
    return { gcdAction = C.ACTION_ID_IDLE or "IDLE", offGcdAction = suggestedOffGcdAction }
end

function WRA:GetSpecOptions_ProtectionPaladin()
    local function SetSpecDBValue(key, value)
        if DB then 
            DB[key] = value 
            NotifySettingChange(key, value)
        else 
            WRA:PrintError("Cannot set spec option, ProtectionPaladin DB reference is nil!") 
        end
    end

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

    return {
        prot_paladin_header = {
            order = 1,
            type = "header",
            name = L["ProtectionPaladin"],
        },
        seal_judgement_header = {
            order = 5,
            type = "header",
            name = L["Seals & Judgements"]
        },
        selectedSeal_Prot = {
            order = 10,
            type = "select",
            name = L["OPTION_PROT_SELECTED_SEAL_NAME"],
            desc = L["OPTION_PROT_SELECTED_SEAL_DESC"],
            values = sealTypeValues,
            get = function() 
                local defaultSeal = (playerFaction == "Horde" and "CORRUPTION" or "VENGEANCE")
                return GetSpecDBValue("selectedSeal_Prot", defaultSeal) 
            end,
            set = function(_, v) SetSpecDBValue("selectedSeal_Prot", v) end,
        },
        selectedJudgement_Prot = {
            order = 15,
            type = "select",
            name = L["OPTION_PROT_SELECTED_JUDGEMENT_NAME"],
            desc = L["OPTION_PROT_SELECTED_JUDGEMENT_DESC"],
            values = judgementTypeValues,
            get = function() return GetSpecDBValue("selectedJudgement_Prot", "WISDOM") end,
            set = function(_, v) SetSpecDBValue("selectedJudgement_Prot", v) end,
        },
        utility_header = {
            order = 20,
            type = "header",
            name = L["Utility"]
        },
        useHolyShield = {
            order = 25,
            type = "toggle",
            name = L["useHolyShield"],
            desc = L["useHolyShield_desc"],
            get = function() return GetSpecDBValue("useHolyShield", true) end,
            set = function(_,v) SetSpecDBValue("useHolyShield", v) end,
        },
        useRighteousFury = {
            order = 26,
            type = "toggle",
            name = L["useRighteousFury"],
            desc = L["useRighteousFury_desc"],
            get = function() return GetSpecDBValue("useRighteousFury", true) end,
            set = function(_,v) SetSpecDBValue("useRighteousFury", v) end,
        },
        useDivinePlea = {
            order = 27,
            type = "toggle",
            name = L["useDivinePlea"],
            desc = L["useDivinePlea_desc"],
            get = function() return GetSpecDBValue("useDivinePlea", true) end,
            set = function(_,v) SetSpecDBValue("useDivinePlea", v) end,
        },
        divinePleaManaThreshold = {
            order = 28,
            type = "range",
            name = L["divinePleaManaThreshold"],
            desc = L["divinePleaManaThreshold_desc"],
            min = 10, max = 90, step = 5,
            get = function() return GetSpecDBValue("divinePleaManaThreshold", 50) end,
            set = function(_,v) SetSpecDBValue("divinePleaManaThreshold", v) end,
            disabled = function() return not GetSpecDBValue("useDivinePlea", true) end,
        },
    }
end
