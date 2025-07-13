-- WRA/Specs/FeralDruid.lua
-- MODIFIED (Refactor): Now calls the new AOETracker module for enemy counting.
-- MODIFIED (Localization): Replaced hardcoded option names and descriptions with localization keys.
-- MODIFIED (Bugfix): Corrected NotifySettingChange to properly handle 'select' type options and display the correct value text.
-- MODIFIED (Pooling v6): Added Execute Phase (target TTD) as a condition for the Dumping Phase.
-- MODIFIED (Trinket DB): Now uses the new Aura:HasActiveTrinketProc() API for dumping phase logic.
-- MODIFIED (Pooling v7): Fixed a critical bug where the addon would pool energy when Rip has expired instead of dumping.
-- MODIFIED (Mangle Debuff Logic): Updated to check for all equivalent bleed-enhancing debuffs (Mangle Cat/Bear, Trauma), not just self-cast Mangle.
-- FIXED (Shapeshift Logic): Corrected the IsReady function to properly allow shifting into a form when not currently in that form.
-- FIXED (Rake Opener Logic): Re-inserted the secondary opener Rake logic to handle scenarios without Savage Roar active, as per user feedback.
-- FIXED (Formatting): Reverted the inlining of 'berserkRoarRefresh' to respect original code style.
-- FIXED (Boilerplate): Restored the correct library loading boilerplate at the top of the file to fix the 'GetAddon' nil error.
-- MODIFIED (Rake TTD Check): Added a check to prevent refreshing Rake if the target's Time To Die is less than 6 seconds.
-- MODIFIED (Priority Rake TTD Check): Added the same TTD check to the priority opener Rake logic.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local FeralDruid = WRA:NewModule("FeralDruid", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Lua shortcuts
local IsPlayerSpell, GetSpellInfo, UnitPower, GetShapeshiftForm, IsCurrentSpell = IsPlayerSpell, GetSpellInfo, UnitPower, GetShapeshiftForm, IsCurrentSpell
local tinsert = table.insert
local string_format = string.format
local math = math -- Add math library reference

-- Module references
local C, State, CD, Aura, Utils, DB, TTD, AOETracker

-- Helper to get settings from the database with a default value
local function GetDBValue(key, defaultValue)
    local DB = WRA.db and WRA.db.profile and WRA.db.profile.specs and WRA.db.profile.specs.FeralDruid or nil
    if DB and DB[key] ~= nil then return DB[key] end
    return defaultValue
end

-- Helper to notify UI about setting changes
local function NotifySettingChange(key, value)
    WRA:PrintDebug("[FeralDruid Notify] Key:", key, "Value:", tostring(value))

    local specOptions = WRA:GetSpecOptions_FeralDruid()
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

function FeralDruid:OnInitialize() end

function FeralDruid:OnEnable()
    WRA:PrintDebug("FeralDruid Module Enabled.")
    if WRA.db and WRA.db.profile and WRA.db.profile.specs and not WRA.db.profile.specs.FeralDruid then
        WRA.db.profile.specs.FeralDruid = {
            ripLeeway = 1.5,
            roarOffset = 25,
            enableAOE = true,
            aoeThreshold = 3,
            forceAOE = false, 
            useTigersFury = true,
            useBerserk = true,
            preferredStance = "CAT",
            useMangle = true,
            openerRakePriority = true,
            useEnrage = true,
            maulRageThreshold = 60,
            -- Pooling options defaults
            enableEnergyPooling = true,
            poolingThreshold = 85,
            poolingRipThreshold = 3.0,
            poolingRoarThreshold = 3.0,
            executeTimeThreshold = 12.0,
        }
    end
    self.ClassConstants = WRA.Constants
end

function FeralDruid:OnDisable()
    WRA:PrintDebug("FeralDruid Module Disabled.")
end

----------------------------------------------------
-- Core Logic: IsReady & GetNextAction
----------------------------------------------------

function FeralDruid:IsReady(actionID, state)
    local C, Utils, Aura = WRA.Constants, WRA.Utils, WRA.AuraMonitor
    if not (Utils and C and Aura and state and state.player) then return false end

    local currentForm = GetShapeshiftForm()
    
    if actionID == C.Spells.MAUL then
        if IsCurrentSpell(actionID) then
            return false
        end
    end

    -- A table of spells that are exceptions to the form checks
    local formCheckExceptions = {
        [C.Spells.FAERIE_FIRE_FERAL] = true,
        [C.Spells.CAT_FORM] = true,
        [C.Spells.DIRE_BEAR_FORM] = true,
        [C.Spells.BEAR_FORM] = true,
    }

    -- Form-specific checks
    if actionID == C.Spells.MANGLE_BEAR or actionID == C.Spells.LACERATE or actionID == C.Spells.MAUL or actionID == C.Spells.SWIPE_BEAR or actionID == C.Spells.ENRAGE then
        -- These are Bear abilities
        if currentForm ~= C.Forms.BEAR and currentForm ~= C.Forms.DIRE_BEAR then return false end
    elseif not formCheckExceptions[actionID] then 
        -- For any other ability NOT in the exception list, assume it's a Cat ability.
        if currentForm ~= C.Forms.CAT then return false end
    end
    
    if not IsPlayerSpell(actionID) or not Utils:IsReadyWithQueue({id = actionID}) then
        return false
    end
    
    return true
end


function FeralDruid:GetNextAction(currentState)
    C, State, CD, Aura, Utils, TTD, AOETracker = WRA.Constants, WRA.StateManager, WRA.CooldownTracker, WRA.AuraMonitor, WRA.Utils, WRA.TTDTracker, WRA.AOETracker
    local DB = WRA.db and WRA.db.profile and WRA.db.profile.specs and WRA.db.profile.specs.FeralDruid or {}

    if not (C and State and CD and Aura and Utils and TTD and AOETracker and currentState and currentState.player and currentState.target) then
        return { gcdAction = C.ACTION_ID_WAITING or 0 }
    end
    
    local player = currentState.player
    local target = currentState.target
    
    local currentForm = GetShapeshiftForm()    
    if not (target.exists and target.isEnemy and not target.isDead) then return { gcdAction = C.ACTION_ID_IDLE } end
    
    local suggestedOffGcdAction = nil
    
    local preferredStance = GetDBValue("preferredStance", "CAT")

    if preferredStance == "CAT" and currentForm ~= C.Forms.CAT then
        if self:IsReady(C.Spells.CAT_FORM, currentState) then
            return { gcdAction = C.Spells.CAT_FORM }
        end
    elseif preferredStance == "BEAR" and not (currentForm == C.Forms.BEAR or currentForm == C.Forms.DIRE_BEAR) then
        if self:IsReady(C.Spells.DIRE_BEAR_FORM, currentState) then
            return { gcdAction = C.Spells.DIRE_BEAR_FORM }
        end
    end

    -- Bear Form Logic
    if (currentForm == C.Forms.BEAR or currentForm == C.Forms.DIRE_BEAR) and preferredStance == "BEAR" then
        local rage = player.power
        local mangleCd = CD:GetCooldownRemaining(C.Spells.MANGLE_BEAR)
        local ffCd = CD:GetCooldownRemaining(C.Spells.FAERIE_FIRE_FERAL)
        local lacerateStacks = Aura:GetAuraStacks(C.Auras.LACERATE, "target", true)
        
        -- Off-GCD abilities
        if GetDBValue("useEnrage", true) and rage < 80 and self:IsReady(C.Spells.ENRAGE, currentState) then
            suggestedOffGcdAction = C.Spells.ENRAGE
        end
        if not suggestedOffGcdAction and rage > GetDBValue("maulRageThreshold", 60) and self:IsReady(C.Spells.MAUL, currentState) then
            suggestedOffGcdAction = C.Spells.MAUL
        end
        
        -- APL implementation
        
        -- 1. Lacerate (Refresh)
        if lacerateStacks == 5 and (Aura:GetDebuffRemaining(C.Auras.LACERATE, "target", true) or 0) < 1.5 then
            if self:IsReady(C.Spells.LACERATE, currentState) then
                return { gcdAction = C.Spells.LACERATE, offGcdAction = suggestedOffGcdAction }
            end
        end

        -- 2. Mangle
        if self:IsReady(C.Spells.MANGLE_BEAR, currentState) then
             return { gcdAction = C.Spells.MANGLE_BEAR, offGcdAction = suggestedOffGcdAction }
        end
        -- 2a. Wait for Mangle
        if mangleCd > 0 and mangleCd < 1.0 and not self:IsReady(C.Spells.FAERIE_FIRE_FERAL, currentState) then
            return { gcdAction = C.ACTION_ID_WAITING, offGcdAction = suggestedOffGcdAction }
        end

        -- 3. Faerie Fire (now used rotationally)
        if self:IsReady(C.Spells.FAERIE_FIRE_FERAL, currentState) then
            return { gcdAction = C.Spells.FAERIE_FIRE_FERAL, offGcdAction = suggestedOffGcdAction }
        end
        -- 3a. Wait for Mangle before Faerie Fire
        if mangleCd > 0 and mangleCd < 1.5 then
            return { gcdAction = C.ACTION_ID_WAITING, offGcdAction = suggestedOffGcdAction }
        end

        -- 4. Lacerate (Stack or Refresh low duration)
        if lacerateStacks < 5 or (Aura:GetDebuffRemaining(C.Auras.LACERATE, "target", true) or 0) < 8 then
            if self:IsReady(C.Spells.LACERATE, currentState) then
                return { gcdAction = C.Spells.LACERATE, offGcdAction = suggestedOffGcdAction }
            end
        end
        
        -- 5. Swipe (Rage >= 40, used as single target rage dump as well)
        if rage >= 40 and self:IsReady(C.Spells.SWIPE_BEAR, currentState) then
            return { gcdAction = C.Spells.SWIPE_BEAR, offGcdAction = suggestedOffGcdAction }
        end
        
        -- 6. Maul is handled as Off-GCD above.

        -- 7. Wait for Faerie Fire
        if ffCd > 0 and ffCd < 1.5 and mangleCd > ffCd then
            return { gcdAction = C.ACTION_ID_WAITING, offGcdAction = suggestedOffGcdAction }
        end

        -- If nothing else, return current Off-GCD suggestion or Idle
        return { gcdAction = C.ACTION_ID_IDLE, offGcdAction = suggestedOffGcdAction }
    end
    
    -- Cat Form Logic
    if currentForm == C.Forms.CAT or preferredStance == "CAT" then
        local comboPoints = player.comboPoints
        local energy = player.power
        local hasOmen = Aura:HasBuff(C.Auras.OMEN_OF_CLARITY, "player")
        local hasBerserk = Aura:HasBuff(C.Auras.BERSERK, "player")
        local hasTigersFury = Aura:HasBuff(C.Auras.TIGERS_FURY, "player")
        local hasRoar = Aura:HasBuff(C.Auras.SAVAGE_ROAR, "player")
        local ripRemaining = Aura:GetDebuffRemaining(C.Auras.RIP, "target", true) or 0
        local rakeRemaining = Aura:GetDebuffRemaining(C.Auras.RAKE, "target", true) or 0
        
        local mangleRemaining = 0
        if C.Auras.MANGLE_EQUIVALENTS then
            for _, debuffID in ipairs(C.Auras.MANGLE_EQUIVALENTS) do
                local remaining = Aura:GetDebuffRemaining(debuffID, "target") or 0
                if remaining > mangleRemaining then
                    mangleRemaining = remaining
                end
            end
        else
            mangleRemaining = Aura:GetDebuffRemaining(C.Auras.MANGLE, "target") or 0
        end

        local roarRemaining = Aura:GetBuffRemaining(C.Auras.SAVAGE_ROAR, "player") or 0
        local ttd = TTD:GetTTD(target.guid) or 999
    
        local isAoeSituation = GetDBValue("forceAOE", false) or (GetDBValue("enableAOE", true) and AOETracker:GetNearbyEnemyCount(8) >= GetDBValue("aoeThreshold", 3))
        
        if isAoeSituation then
            if GetDBValue("useTigersFury", true) and energy < 30 and not hasOmen and not hasBerserk and self:IsReady(C.Spells.TIGERS_FURY, currentState) then
                suggestedOffGcdAction = C.Spells.TIGERS_FURY
            end
            
            local apl = {}
            if GetDBValue("useBerserk", true) and hasTigersFury then tinsert(apl, C.Spells.BERSERK) end
            local swipeEnergyThreshold = hasBerserk and 23 or 45
            if hasRoar and (hasOmen or energy > swipeEnergyThreshold) then tinsert(apl, C.Spells.SWIPE_CAT) end
            if not hasRoar then
                if comboPoints >= 1 then tinsert(apl, C.Spells.SAVAGE_ROAR)
                elseif GetDBValue("useMangle", true) and mangleRemaining == 0 then tinsert(apl, C.Spells.MANGLE_CAT)
                else tinsert(apl, C.Spells.RAKE) end
            end
            if not hasOmen and energy <= swipeEnergyThreshold then tinsert(apl, C.Spells.FAERIE_FIRE_FERAL) end
            
            for _, spellID in ipairs(apl) do
                if self:IsReady(spellID, currentState) then return { gcdAction = spellID, offGcdAction = suggestedOffGcdAction } end
            end
            
            return { gcdAction = C.ACTION_ID_IDLE, offGcdAction = suggestedOffGcdAction }
        end
    
        -- Single Target Logic
        if GetDBValue("useTigersFury", true) and not hasOmen and not hasBerserk and self:IsReady(C.Spells.TIGERS_FURY, currentState) then
            if ripRemaining > 0 and energy < 30 then suggestedOffGcdAction = C.Spells.TIGERS_FURY
            elseif ripRemaining == 0 and comboPoints == 5 and energy < 25 then suggestedOffGcdAction = C.Spells.TIGERS_FURY end
        end

        -- ### ENERGY POOLING LOGIC ###
        local isDumpingPhase = false
        if GetDBValue("enableEnergyPooling", true) then
            if hasBerserk then isDumpingPhase = true end
            if not isDumpingPhase and ttd < GetDBValue("executeTimeThreshold", 12) then isDumpingPhase = true end
            if not isDumpingPhase and (Aura:HasBuff(C.Auras.DEATHBRINGERS_WILL_AGI, "player") or Aura:HasBuff(C.Auras.DEATHBRINGERS_WILL_STR, "player") or Aura:HasBuff(C.Auras.DEATHBRINGERS_WILL_CRIT, "player") or Aura:HasBuff(C.Auras.DEATHBRINGERS_WILL_AGI_H, "player") or Aura:HasBuff(C.Auras.DEATHBRINGERS_WILL_STR_H, "player") or Aura:HasBuff(C.Auras.DEATHBRINGERS_WILL_CRIT_H, "player") or Aura:HasBuff(C.Auras.SHARPENED_TWILIGHT_SCALE, "player") or Aura:HasBuff(C.Auras.SHARPENED_TWILIGHT_SCALE_H, "player")) then isDumpingPhase = true end
            if not isDumpingPhase and (roarRemaining < GetDBValue("poolingRoarThreshold", 3) or ripRemaining < GetDBValue("poolingRipThreshold", 3)) and comboPoints < 5 then isDumpingPhase = true end
            if not isDumpingPhase and comboPoints == 5 and roarRemaining > GetDBValue("fbMinRoarTime", 8) and ripRemaining > GetDBValue("fbMinRipTime", 10) then isDumpingPhase = true end
            if not isDumpingPhase and CD:GetCooldownRemaining(C.Spells.TIGERS_FURY) < 2 then isDumpingPhase = true end
        else
            isDumpingPhase = true
        end

        -- ### DYNAMIC SINGLE-TARGET APL (Action Priority List) ###
        local apl = {}

        if GetDBValue("useBerserk", true) and hasTigersFury then tinsert(apl, C.Spells.BERSERK) end
        
        local simpleRoarRefresh = (not hasRoar and comboPoints >= 1) or (roarRemaining < 2)
        local advancedRoarRefresh = false
        if hasRoar and ripRemaining > 0 and comboPoints >= 1 then
            local ripLeeway = GetDBValue("ripLeeway", 1.5); local roarOffset = GetDBValue("roarOffset", 25)
            if (roarRemaining - ripRemaining) <= ripLeeway and (9 + (5 * comboPoints)) - ripRemaining >= roarOffset then advancedRoarRefresh = true end
        end
        local berserkRoarRefresh = hasBerserk and comboPoints == 5 and roarRemaining < ripRemaining
        if (simpleRoarRefresh or advancedRoarRefresh or berserkRoarRefresh) then
            tinsert(apl, C.Spells.SAVAGE_ROAR)
        end
        
        if not hasOmen and comboPoints == 0 and mangleRemaining == 0 and rakeRemaining == 0 then tinsert(apl, C.Spells.FAERIE_FIRE_FERAL) end
        
        -- Prio 4: Priority Rake (after Mangle is up)
        if GetDBValue("openerRakePriority", true) and mangleRemaining > 0 and hasRoar and rakeRemaining == 0 and not hasOmen and ttd > 6 then
            tinsert(apl, C.Spells.RAKE)
        end
        
        if not hasOmen and ((hasBerserk and energy < 15) or (not hasBerserk and energy < 87)) then tinsert(apl, C.Spells.FAERIE_FIRE_FERAL) end
        if GetDBValue("useMangle", true) and mangleRemaining == 0 then tinsert(apl, C.Spells.MANGLE_CAT) end
        
        -- Prio 7: Rake (Opener, if Mangle is up but we don't have Roar yet)
        if mangleRemaining > 0 and rakeRemaining == 0 and comboPoints == 0 and not hasRoar then
            tinsert(apl, C.Spells.RAKE)
        end

        if comboPoints == 5 and not hasOmen and ripRemaining == 0 and ttd > 10 then tinsert(apl, C.Spells.RIP) end
        
        -- Prio 9: Rake (Refresh)
        if rakeRemaining == 0 and not hasOmen and ttd > 6 then
            tinsert(apl, C.Spells.RAKE)
        end
        
        if GetDBValue("useMangle", true) and (mangleRemaining < 3) and not hasOmen and energy > 40 then tinsert(apl, C.Spells.MANGLE_CAT) end
        if GetDBValue("useFerociousBite", true) and comboPoints == 5 and not hasOmen and ((ripRemaining > GetDBValue("fbMinRipTime", 10) and roarRemaining > GetDBValue("fbMinRoarTime", 8)) or (ttd < 10)) then tinsert(apl, C.Spells.FEROCIOUS_BITE) end
        
        local shredEnergyThreshold = isDumpingPhase and 42 or GetDBValue("poolingThreshold", 85)
        if hasBerserk then shredEnergyThreshold = 21 end
        if (energy > shredEnergyThreshold or hasOmen) then tinsert(apl, C.Spells.SHRED) end
        
        for _, spellID in ipairs(apl) do
            if self:IsReady(spellID, currentState) then return { gcdAction = spellID, offGcdAction = suggestedOffGcdAction } end
        end
    end

    return { gcdAction = C.ACTION_ID_IDLE, offGcdAction = suggestedOffGcdAction }
end

-- GetSpecOptions_FeralDruid function
function WRA:GetSpecOptions_FeralDruid()
    local function SetSpecDBValue(key, value)
        local DB = WRA.db and WRA.db.profile and WRA.db.profile.specs and WRA.db.profile.specs.FeralDruid or nil
        if DB then DB[key] = value; NotifySettingChange(key, value)
        else WRA:PrintError("Cannot set spec option, FeralDruid DB reference is nil!") end
    end

    return {
        feral_header = { order = 1, type = "header", name = L["feral_header"] },
        stance_header = { order = 1.1, type = "header", name = L["stance_header"] },
        preferredStance = {
            order = 1.2, type = "select", name = L["preferredStance"],
            desc = L["preferredStance_desc"],
            style = "dropdown",
            values = {
                CAT = "猫形态 DPS",
                BEAR = "熊形态 坦克"
            },
            get = function() return GetDBValue("preferredStance", "CAT") end,
            set = function(_, v) SetSpecDBValue("preferredStance", v) end,
        },
        aoe_header = { order = 2, type = "header", name = L["aoe_header"] },
        enableAOE = {
            order = 3, type = "toggle", name = L["enableAOE"],
            desc = L["enableAOE_desc"],
            get = function() return GetDBValue("enableAOE", true) end,
            set = function(_, v) SetSpecDBValue("enableAOE", v) end,
        },
        aoeThreshold = {
            order = 4, type = "range", name = L["aoeThreshold"],
            desc = L["aoeThreshold_desc"],
            min = 2, max = 10, step = 1,
            get = function() return GetDBValue("aoeThreshold", 3) end,
            set = function(_, v) SetSpecDBValue("aoeThreshold", v) end,
            disabled = function() return not GetDBValue("enableAOE", true) end,
        },
        forceAOE = {
            order = 5, type = "toggle", name = L["forceAOE"],
            desc = L["forceAOE_desc"],
            get = function() return GetDBValue("forceAOE", false) end,
            set = function(_,v) SetSpecDBValue("forceAOE", v) end,
        },
        core_abilities_header = {
             order = 5.1, type = "header", name = L["core_abilities_header"]
        },
        useMangle = {
            order = 5.2, type = "toggle", name = L["useMangle"],
            desc = L["useMangle_desc"],
            get = function() return GetDBValue("useMangle", true) end,
            set = function(_,v) SetSpecDBValue("useMangle", v) end,
        },
        openerRakePriority = {
            order = 5.3, type = "toggle", name = L["openerRakePriority"],
            desc = L["openerRakePriority_desc"],
            get = function() return GetDBValue("openerRakePriority", true) end,
            set = function(_,v) SetSpecDBValue("openerRakePriority", v) end,
        },
        roar_header = { order = 6, type = "header", name = L["roar_header"] },
        ripLeeway = {
            order = 7, type = "range", name = L["ripLeeway"],
            desc = L["ripLeeway_desc"],
            min = 0, max = 5, step = 0.1,
            get = function() return GetDBValue("ripLeeway", 1.5) end,
            set = function(_, v) SetSpecDBValue("ripLeeway", v) end,
        },
        roarOffset = {
            order = 8, type = "range", name = L["roarOffset"],
            desc = L["roarOffset_desc"],
            min = 20, max = 30, step = 0.5,
            get = function() return GetDBValue("roarOffset", 25) end,
            set = function(_, v) SetSpecDBValue("roarOffset", v) end,
        },
        bite_header = { order = 9, type = "header", name = L["bite_header"] },
        useFerociousBite = {
            order = 10, type = "toggle", name = L["Use Ferocious Bite"],
            desc = L["Use Ferocious Bite_desc"],
            get = function() return GetDBValue("useFerociousBite", true) end,
            set = function(_, v) SetSpecDBValue("useFerociousBite", v) end,
        },
        fbMinRoarTime = {
            order = 11, type = "range", name = L["FB Min Roar Time"],
            desc = L["FB Min Roar Time_desc"],
            min = 2, max = 15, step = 0.5,
            get = function() return GetDBValue("fbMinRoarTime", 8) end,
            set = function(_, v) SetSpecDBValue("fbMinRoarTime", v) end,
            disabled = function() return not GetDBValue("useFerociousBite", true) end,
        },
        fbMinRipTime = {
            order = 12, type = "range", name = L["FB Min Rip Time"],
            desc = L["FB Min Rip Time_desc"],
            min = 2, max = 15, step = 0.5,
            get = function() return GetDBValue("fbMinRipTime", 10) end,
            set = function(_, v) SetSpecDBValue("fbMinRipTime", v) end,
            disabled = function() return not GetDBValue("useFerociousBite", true) end,
        },
        cooldowns_header = {
            order = 13, type = "header", name = L["cooldowns_header"]
        },
        useTigersFury = {
            order = 14, type = "toggle", name = L["useTigersFury"],
            desc = L["useTigersFury_desc"],
            get = function() return GetDBValue("useTigersFury", true) end,
            set = function(_, v) SetSpecDBValue("useTigersFury", v) end,
        },
        useBerserk = {
            order = 15, type = "toggle", name = L["useBerserk"],
            desc = L["useBerserk_desc"],
            get = function() return GetDBValue("useBerserk", true) end,
            set = function(_, v) SetSpecDBValue("useBerserk", v) end,
        },
        useEnrage = {
            order = 16, type = "toggle", name = L["useEnrage"],
            desc = L["useEnrage_desc"],
            get = function() return GetDBValue("useEnrage", true) end,
            set = function(_,v) SetSpecDBValue("useEnrage", v) end,
        },
        maulRageThreshold = {
            order = 17, type = "range", name = L["maulRageThreshold"],
            desc = L["maulRageThreshold_desc"],
            min = 10, max = 95, step = 5,
            get = function() return GetDBValue("maulRageThreshold", 60) end,
            set = function(_, v) SetSpecDBValue("maulRageThreshold", v) end,
        },
        pooling_header = {
            order = 18, type = "header", name = L["pooling_header"],
        },
        enableEnergyPooling = {
            order = 19, type = "toggle", name = L["enableEnergyPooling"],
            desc = L["enableEnergyPooling_desc"],
            get = function() return GetDBValue("enableEnergyPooling", true) end,
            set = function(_, v) SetSpecDBValue("enableEnergyPooling", v) end,
        },
        poolingThreshold = {
            order = 20, type = "range", name = L["poolingThreshold"],
            desc = L["poolingThreshold_desc"],
            min = 70, max = 95, step = 1,
            get = function() return GetDBValue("poolingThreshold", 85) end,
            set = function(_, v) SetSpecDBValue("poolingThreshold", v) end,
            disabled = function() return not GetDBValue("enableEnergyPooling", true) end,
        },
        poolingRipThreshold = {
            order = 21, type = "range", name = L["poolingRipThreshold"],
            desc = L["poolingRipThreshold_desc"],
            min = 1.5, max = 5.0, step = 0.1,
            get = function() return GetDBValue("poolingRipThreshold", 3.0) end,
            set = function(_, v) SetSpecDBValue("poolingRipThreshold", v) end,
            disabled = function() return not GetDBValue("enableEnergyPooling", true) end,
        },
        poolingRoarThreshold = {
            order = 22, type = "range", name = L["poolingRoarThreshold"],
            desc = L["poolingRoarThreshold_desc"],
            min = 1.5, max = 5.0, step = 0.1,
            get = function() return GetDBValue("poolingRoarThreshold", 3.0) end,
            set = function(_, v) SetSpecDBValue("poolingRoarThreshold", v) end,
            disabled = function() return not GetDBValue("enableEnergyPooling", true) end,
        },
        executeTimeThreshold = {
            order = 23, type = "range", name = L["executeTimeThreshold"],
            desc = L["executeTimeThreshold_desc"],
            min = 5, max = 20, step = 1,
            get = function() return GetDBValue("executeTimeThreshold", 12) end,
            set = function(_, v) SetSpecDBValue("executeTimeThreshold", v) end,
            disabled = function() return not GetDBValue("enableEnergyPooling", true) end,
        },
    }
end
