-- wow addon/WRA/Specs/FuryWarrior.lua
-- MODIFIED (Refactor): Updated to use the new AOETracker module for enemy counting.
-- MODIFIED (Localization): Replaced hardcoded option names and descriptions with localization keys.
-- MODIFIED (Bugfix): Corrected NotifySettingChange to properly handle 'select' type options and display the correct value text.
-- MODIFIED (Rend Logic Fix v2): Added a check for main hand swing timer (> 1.6s) to prevent delaying auto-attacks.
-- MODIFIED (Priority Toggle Fix): Re-added the 'useWhirlwind' toggle and integrated it with the priority logic.
-- MODIFIED (Slam Logic): Added logic to prioritize Slam if the Bloodsurge buff is about to expire.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local FuryWarrior = WRA:NewModule("FuryWarrior", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Lua shortcuts
local pairs, type, string_format, tostring, tinsert = pairs, type, string.format, tostring, table.insert
local GetShapeshiftForm, pcall, IsCurrentSpell, GetSpellInfo, UnitRace, UnitIsAttacking = 
      GetShapeshiftForm, pcall, IsCurrentSpell, GetSpellInfo, UnitRace, UnitIsAttacking

-- Module references and constants
local C, State, CD, Aura, ActionMgr, Utils, Swing, DB, AOETracker
local ACTION_ID_WAITING, ACTION_ID_IDLE, ACTION_ID_CASTING
local BT_WW_COOLDOWN_THRESHOLD = 1.5
local DRAENEI_HEAL_HEALTH_THRESHOLD = 35
local HEROIC_THROW_POST_SWING_WINDOW_DEFAULT = 0.2

local function NotifySettingChange(key, value)
    WRA:PrintDebug("[FuryWarrior Notify] Key:", key, "Value:", tostring(value))

    -- Get the full options table for the current spec to correctly format the notification
    local specOptions = WRA:GetSpecOptions_FuryWarrior()
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

local function GetSpellIsOffGCD(spellID)
    if C and C.SpellData and C.SpellData[spellID] then
        return C.SpellData[spellID].isOffGCD or false
    end
    return false
end

local function CreateCheckReadyFunction(optionKeyName)
    return function(currentState, actionData)
        if not C or not DB then return false end
        local optionKeyValue = "use" .. optionKeyName
        local spellID = actionData.id
        local success, result = pcall(function()
            if DB[optionKeyValue] == false then return false end
            return FuryWarrior:IsReady(spellID, currentState)
        end)
        return success and result or false
    end
end

local CheckRecklessness = CreateCheckReadyFunction("Recklessness")
local CheckDeathWish = CreateCheckReadyFunction("DeathWish")
local CheckBerserkerRage = function(currentState, actionData)
    if not C or not Aura or not C.Auras or not DB then return false end
    if DB.useBerserkerRage == false then return false end
    local spellID = actionData.id
    local hasEnrage = Aura:HasBuff(C.Auras.ENRAGE, "player") or
                      Aura:HasBuff(C.Auras.BERSERKER_RAGE_BUFF, "player") or
                      (C.Auras.DEATH_WISH_BUFF and Aura:HasBuff(C.Auras.DEATH_WISH_BUFF, "player"))
    return FuryWarrior:IsReady(spellID, currentState) and not hasEnrage
end
local CheckPotion = CreateCheckReadyFunction("Potions")

local function CreateBaseRaceSpecificCheckReady(requiredRaceEnglish)
    return function(currentState, actionData)
        if not C or not DB or not C.Spells then
            return false
        end
        if DB.useRacials == false then
            return false
        end
        local _, playerRaceEnglish = UnitRace("player")
        if playerRaceEnglish ~= requiredRaceEnglish then
            return false
        end
        local spellID = actionData.id
        local success, result = pcall(function()
            return FuryWarrior:IsReady(spellID, currentState)
        end)
        if not success then
            WRA:PrintError("CreateBaseRaceSpecificCheckReady: Error in IsReady for " .. tostring(spellID) .. ": " .. tostring(result))
        end
        return success and result or false
    end
end

local function CheckOffensiveRacialReady(requiredRaceEnglish, currentState, actionData)
    local baseCheckFunc = CreateBaseRaceSpecificCheckReady(requiredRaceEnglish)
    if not baseCheckFunc(currentState, actionData) then
        return false
    end
    if not currentState.player.inCombat then
        return false
    end
    local deathWishActive = C.Auras.DEATH_WISH_BUFF and Aura:HasBuff(C.Auras.DEATH_WISH_BUFF, "player")
    local heroismActive = C.Auras.HEROISM and (Aura:HasBuff(C.Auras.HEROISM, "player") or Aura:HasBuff(C.Auras.BLOODLUST, "player"))
    local recklessnessActive = C.Auras.RECKLESSNESS_BUFF and Aura:HasBuff(C.Auras.RECKLESSNESS_BUFF, "player")
    if deathWishActive or heroismActive or recklessnessActive then
        return true
    end
    return false
end

local function CheckDraeneiHealReady(currentState, actionData)
    local baseCheckFunc = CreateBaseRaceSpecificCheckReady("Draenei")
    if not baseCheckFunc(currentState, actionData) then return false end
    if currentState.player.healthPercent < DRAENEI_HEAL_HEALTH_THRESHOLD then return true end
    return false
end

local function CheckSituationalRacialReady(requiredRaceEnglish, currentState, actionData)
    local baseCheckFunc = CreateBaseRaceSpecificCheckReady(requiredRaceEnglish)
    if not baseCheckFunc(currentState, actionData) then return false end
    return false
end

function FuryWarrior:OnInitialize()
    C = WRA.Constants
    if not C then 
        WRA:PrintDebug("FuryWarrior:OnInitialize - Constants not ready, will be fetched in OnEnable.")
        return 
    end

    ACTION_ID_WAITING, ACTION_ID_IDLE, ACTION_ID_CASTING = C.ACTION_ID_WAITING, C.ACTION_ID_IDLE, C.ACTION_ID_CASTING
    
    ActionMgr = WRA.ActionManager
    if ActionMgr and C.Spells and C.Items and C.Auras then
        local actionsToRegister = {
            { idKey = "RECKLESSNESS", spellID = C.Spells.RECKLESSNESS, prio = 100, checkFunc = CheckRecklessness, scope = "GCD" },
            { idKey = "DEATH_WISH", spellID = C.Spells.DEATH_WISH, prio = 95, checkFunc = CheckDeathWish, scope = "GCD" },
            { idKey = "BERSERKER_RAGE", spellID = C.Spells.BERSERKER_RAGE, prio = 90, checkFunc = CheckBerserkerRage, scope = "GCD" },
            { idKey = "POTION_HASTE", itemID = C.Items.POTION_HASTE, prio = 97, checkFunc = CheckPotion, scope = "GCD", isOffGCD = true },
            { race = "Orc", spellKey = "BLOOD_FURY", prio = 96, scope = "GCD", customCheck = function(cs, ad) return CheckOffensiveRacialReady("Orc", cs, ad) end },
            { race = "Troll", spellKey = "BERSERKING", prio = 96, scope = "GCD", customCheck = function(cs, ad) return CheckOffensiveRacialReady("Troll", cs, ad) end },
            { race = "Draenei", spellKey = "GIFT_OF_NAARU", prio = 10, scope = "GCD", customCheck = CheckDraeneiHealReady },
            { race = "Human", spellKey = "EVERY_MAN", prio = 5, scope = "GCD", customCheck = function(cs, ad) return CheckSituationalRacialReady("Human", cs, ad) end },
            { race = "Dwarf", spellKey = "STONEFORM", prio = 5, scope = "GCD", customCheck = function(cs, ad) return CheckSituationalRacialReady("Dwarf", cs, ad) end },
            { race = "Gnome", spellKey = "ESCAPE_ARTIST", prio = 5, scope = "GCD", customCheck = function(cs, ad) return CheckSituationalRacialReady("Gnome", cs, ad) end },
        }
        for _, action in ipairs(actionsToRegister) do
            local idToRegister = action.spellID or (action.itemID and -action.itemID) or (action.spellKey and C.Spells[action.spellKey])
            if idToRegister then
                local isOffGCD = action.isOffGCD or GetSpellIsOffGCD(idToRegister)
                local checkFunction = action.checkFunc or action.customCheck
                ActionMgr:RegisterAction(idToRegister, { 
                    owner = "FuryWarrior", priority = action.prio, 
                    checkReady = checkFunction, scope = action.scope, 
                    isOffGCD = isOffGCD, id = idToRegister 
                })
            end
        end
    end
end

function FuryWarrior:OnEnable()
    State, CD, Aura, ActionMgr, Utils, Swing, C, AOETracker = WRA.StateManager, WRA.CooldownTracker, WRA.AuraMonitor, WRA.ActionManager, WRA.Utils, WRA.SwingTimer, WRA.Constants, WRA.AOETracker
    if WRA.db and WRA.db.profile and WRA.db.profile.specs then
        DB = WRA.db.profile.specs.FuryWarrior
    end
    self.ClassConstants = C
    WRA:PrintDebug("FuryWarrior Module Enabled.")
end

function FuryWarrior:OnDisable()
    if ActionMgr and ActionMgr.UnregisterActionsByOwner then
        ActionMgr:UnregisterActionsByOwner("FuryWarrior")
    end
    WRA:PrintDebug("FuryWarrior Module Disabled.")
end

function FuryWarrior:IsReady(actionID, state, skipGCDCheckOverride)
    if actionID == C.Spells.WHIRLWIND then
        if not Utils:IsReadyWithQueue({id = actionID}) then return false end
        
        local currentStance = GetShapeshiftForm()
        if currentStance ~= C.Stances.BERSERKER then
            return false
        end
        if not State:IsSpellInRange(actionID, "target") then
            return false
        end

        return true
    end

    local tempAction = { id = actionID }
    if not Utils:IsReadyWithQueue(tempAction) then
        return false
    end
    
    if actionID == C.Spells.HEROIC_STRIKE or actionID == C.Spells.CLEAVE then
        if IsCurrentSpell(actionID) then
            return false
        end
    end

    local currentStance = GetShapeshiftForm()
    if actionID == C.Spells.REND or actionID == C.Spells.OVERPOWER then
        if currentStance ~= C.Stances.BATTLE then
            return false
        end
    elseif actionID == C.Spells.INTERCEPT then
        if currentStance ~= C.Stances.BERSERKER then
            return false
        end
    elseif actionID == C.Spells.BERSERKER_RAGE then
        if currentStance ~= C.Stances.BERSERKER then
            return false
        end
    end

    if actionID == C.Spells.EXECUTE then
        if not state.target or not state.target.exists or not state.target.healthPercent or state.target.healthPercent >= 20 then
            return false
        end
    elseif actionID == C.Spells.SLAM then
        if not Aura:HasBuff(C.Auras.BLOODSURGE, "player") then
            return false
        end
    elseif actionID == C.Spells.REND then
        if not state.target or not state.target.exists or not C.Auras then return false end
        if Aura:HasDebuff(C.Auras.REND_DEBUFF, "target", true) then return false end
    elseif actionID == C.Spells.PUMMEL then
        if not state.target or not state.target.exists or (not state.target.isCasting and not state.target.isChanneling) then
            return false
        end
    elseif actionID == C.Spells.SHATTERING_THROW then
        if not DB.useShatteringThrow then return false end
        local btRem = CD:GetCooldownRemaining(C.Spells.BLOODTHIRST)
        local wwRem = CD:GetCooldownRemaining(C.Spells.WHIRLWIND)
        if btRem <= BT_WW_COOLDOWN_THRESHOLD or wwRem <= BT_WW_COOLDOWN_THRESHOLD then return false end
        if not (Swing and Swing.GetMainHandRemaining and Swing.GetMainHandSpeed) then return false end
        local mainHandRem = Swing:GetMainHandRemaining()
        local mainHandSpeed = Swing:GetMainHandSpeed()
        if not mainHandSpeed or mainHandSpeed == 0 then return false end
        return mainHandRem > (mainHandSpeed - (DB.heroicThrowPostSwingWindow or HEROIC_THROW_POST_SWING_WINDOW_DEFAULT))
    elseif actionID == C.Spells.HEROIC_THROW then
        if not DB.useHeroicThrow then return false end
        local btRem = CD:GetCooldownRemaining(C.Spells.BLOODTHIRST)
        local wwRem = CD:GetCooldownRemaining(C.Spells.WHIRLWIND)
        if btRem <= BT_WW_COOLDOWN_THRESHOLD or wwRem <= BT_WW_COOLDOWN_THRESHOLD then return false end
        if not (Swing and Swing.GetMainHandRemaining and Swing.GetMainHandSpeed) then return false end
        local mainHandRem = Swing:GetMainHandRemaining()
        local mainHandSpeed = Swing:GetMainHandSpeed()
        if not mainHandSpeed or mainHandSpeed == 0 then return false end
        return mainHandRem > (mainHandSpeed - (DB.heroicThrowPostSwingWindow or HEROIC_THROW_POST_SWING_WINDOW_DEFAULT))
    end

    return true
end

function FuryWarrior:GetQueuedOffGCDAction(state)
    if not C or not DB or not state or not state.player or not AOETracker then return nil end

    if state.player.power < C.HS_CLEAVE_MIN_RAGE then
        return nil
    end
	
    local enemiesInCleaveRange = AOETracker:GetNearbyEnemyCount(8) or 0
    
    local isCleaveSituation = DB.enableCleave or (DB.smartAOE and enemiesInCleaveRange >= (DB.cleaveHSTargetThreshold or 2))

    local contextualAction = isCleaveSituation and C.Spells.CLEAVE or C.Spells.HEROIC_STRIKE
    
    if self:IsReady(contextualAction, state, true) then
        return contextualAction
    end

    return nil
end

function FuryWarrior:NeedsShoutRefresh(state)
    if not (Aura and DB and C and C.Spells and C.Auras) then return nil end
    local selectedShout = DB.selectedShoutType or "BATTLE"
    if selectedShout == "NONE" then return nil end
    local preferredShoutSpellID = (selectedShout == "BATTLE" and C.Spells.BATTLE_SHOUT) or C.Spells.COMMANDING_SHOUT
    local preferredShoutBuffID = (selectedShout == "BATTLE" and C.Auras.BATTLE_SHOUT_BUFF) or C.Auras.COMMANDING_SHOUT_BUFF
    if not Aura:HasBuff(preferredShoutBuffID, "player", false) and self:IsReady(preferredShoutSpellID, state) then
        return preferredShoutSpellID
    end
    return nil
end

function FuryWarrior:GetNextAction(currentState)
    local suggestedGcdAction = nil
    local suggestedOffGcdAction = nil
    
    if not (State and ActionMgr and DB and C and Aura and CD and Swing and Utils and AOETracker) then
        WRA:PrintDebug("FuryWarrior:GetNextAction Aborting - Missing core modules or DB or Utils")
        return { gcdAction = C.ACTION_ID_WAITING, offGcdAction = nil }
    end
    if not (currentState and currentState.player) then
        return { gcdAction = C.ACTION_ID_WAITING, offGcdAction = nil }
    end

    local playerState = currentState.player
    local targetState = currentState.target

    if not (playerState.isCasting or playerState.isChanneling) then
        suggestedGcdAction = self:NeedsShoutRefresh(currentState)
        if suggestedGcdAction then return { gcdAction = suggestedGcdAction, offGcdAction = nil } end
    end

    if not (targetState and targetState.exists and targetState.isEnemy and not targetState.isDead) then
        return { gcdAction = C.ACTION_ID_IDLE, offGcdAction = nil }
    end

    if DB.useInterrupts and targetState.isCasting then
        if self:IsReady(C.Spells.PUMMEL, currentState) then
            suggestedOffGcdAction = C.Spells.PUMMEL
        end
    end

    if not suggestedOffGcdAction then
        suggestedOffGcdAction = self:GetQueuedOffGCDAction(currentState)
    end
    
    if not suggestedOffGcdAction and self:IsReady(C.Spells.BLOODRAGE, currentState) then
        suggestedOffGcdAction = C.Spells.BLOODRAGE
    end

    suggestedGcdAction = ActionMgr:GetHighestPriorityAction(currentState, "GCD", "GCD")
    if suggestedGcdAction then return { gcdAction = suggestedGcdAction, offGcdAction = suggestedOffGcdAction } end

    local sunderMode = DB.sunderArmorMode or "NONE"
    local needsSunder = false
    if sunderMode ~= "NONE" and targetState.isBoss then
        local hasExposeArmor = Aura:HasDebuff(C.Auras.EXPOSE_ARMOR_DEBUFF, "target")
        
        if not hasExposeArmor then
            local sunderStacks = Aura:GetAuraStacks(C.Auras.SUNDER_ARMOR_DEBUFF, "target") or 0
            local sunderRemaining = Aura:GetDebuffRemaining(C.Auras.SUNDER_ARMOR_DEBUFF, "target") or 0
            
            if sunderStacks < 5 or (sunderStacks == 5 and sunderRemaining < 3.0) then
                needsSunder = true
            end
        end
    end

    if sunderMode == "PRIORITY" and needsSunder and self:IsReady(C.Spells.SUNDER_ARMOR, currentState) then
        return { gcdAction = C.Spells.SUNDER_ARMOR, offGcdAction = suggestedOffGcdAction }
    end

    local enemiesInCleaveRange = AOETracker:GetNearbyEnemyCount(8) or 0
    local isAoeSituation = DB.enableCleave or (DB.smartAOE and enemiesInCleaveRange >= (DB.cleaveHSTargetThreshold or 2))

    local rendConditionsMet = 
        DB.useRend and
        (not isAoeSituation) and -- Only use Rend in single-target situations
        (not Aura:HasDebuff(C.Auras.REND_DEBUFF, "target", true)) and
        (not Aura:HasBuff(C.Auras.BLOODSURGE, "player")) and
        (CD:GetCooldownRemaining(C.Spells.BLOODTHIRST) > 2.4) and
        (CD:GetCooldownRemaining(C.Spells.WHIRLWIND) > 2.4) and
        (Swing:GetMainHandRemaining() > 1.6)

    if rendConditionsMet then
        local sequence = {}
        local currentStance = GetShapeshiftForm()
        if currentStance ~= C.Stances.BATTLE then
            tinsert(sequence, C.Spells.BATTLE_STANCE_CAST)
        end
        tinsert(sequence, C.Spells.REND)
        tinsert(sequence, C.Spells.BERSERKER_STANCE_CAST)
        return { sequence = sequence, offGcdAction = suggestedOffGcdAction }
    end
    
    local canStanceDance = CD:GetCooldownRemaining(C.Spells.BLOODTHIRST) > BT_WW_COOLDOWN_THRESHOLD and CD:GetCooldownRemaining(C.Spells.WHIRLWIND) > BT_WW_COOLDOWN_THRESHOLD
    
    if DB.useOverpower and canStanceDance and self:IsReady(C.Spells.OVERPOWER, currentState) then
        local sequence = {}
        local currentStance = GetShapeshiftForm()
        if currentStance ~= C.Stances.BATTLE then
            tinsert(sequence, C.Spells.BATTLE_STANCE_CAST)
        end
        tinsert(sequence, C.Spells.OVERPOWER)
        tinsert(sequence, C.Spells.BERSERKER_STANCE_CAST)
        return { sequence = sequence, offGcdAction = suggestedOffGcdAction }
    end
    
    local currentStance = GetShapeshiftForm()
    if not (currentStance == C.Stances.BERSERKER) then
        if self:IsReady(C.Spells.BERSERKER_STANCE_CAST, currentState) then 
            return { gcdAction = C.Spells.BERSERKER_STANCE_CAST, offGcdAction = suggestedOffGcdAction }
        end
    end

    -- [!code ++]
    -- ### NEW: Check for expiring Bloodsurge proc ###
    if Aura:HasBuff(C.Auras.BLOODSURGE, "player") then
        local bloodsurgeRemaining = Aura:GetBuffRemaining(C.Auras.BLOODSURGE, "player")
        -- If the buff will expire before the next GCD is up (approx 1.5s), use Slam immediately.
        if bloodsurgeRemaining < 1.5 and self:IsReady(C.Spells.SLAM, currentState) then
            return { gcdAction = C.Spells.SLAM, offGcdAction = suggestedOffGcdAction }
        end
    end
    -- [!code --]

    -- ### CORE ROTATION WITH PRIORITY TOGGLE ###
    local priority = DB.btWwPriority or "BT_FIRST"

    if priority == "WW_FIRST" then
        -- Whirlwind > Bloodthirst
        if DB.useWhirlwind and self:IsReady(C.Spells.WHIRLWIND, currentState) then
            suggestedGcdAction = C.Spells.WHIRLWIND
        elseif self:IsReady(C.Spells.BLOODTHIRST, currentState) then
            suggestedGcdAction = C.Spells.BLOODTHIRST
        end
    else
        -- Bloodthirst > Whirlwind (Default)
        if self:IsReady(C.Spells.BLOODTHIRST, currentState) then
            suggestedGcdAction = C.Spells.BLOODTHIRST
        elseif DB.useWhirlwind and self:IsReady(C.Spells.WHIRLWIND, currentState) then
            suggestedGcdAction = C.Spells.WHIRLWIND
        end
    end

    -- Continue with the rest of the APL only if BT/WW were not ready
    if not suggestedGcdAction then
        if sunderMode == "FILLER" and needsSunder and self:IsReady(C.Spells.SUNDER_ARMOR, currentState) then
            suggestedGcdAction = C.Spells.SUNDER_ARMOR
        elseif self:IsReady(C.Spells.SLAM, currentState) then
            suggestedGcdAction = C.Spells.SLAM
        elseif self:IsReady(C.Spells.EXECUTE, currentState) then
            suggestedGcdAction = C.Spells.EXECUTE
        elseif self:IsReady(C.Spells.SHATTERING_THROW, currentState) then
            suggestedGcdAction = C.Spells.SHATTERING_THROW
        elseif self:IsReady(C.Spells.HEROIC_THROW, currentState) then
            suggestedGcdAction = C.Spells.HEROIC_THROW
        end
    end

    return {
        gcdAction = suggestedGcdAction or C.ACTION_ID_IDLE,
        offGcdAction = suggestedOffGcdAction
    }
end

function WRA:GetSpecOptions_FuryWarrior()
    local function GetSpecDBValue(key, defaultValue)
        if DB and DB[key] ~= nil then return DB[key] end
        return defaultValue
    end
    local function SetSpecDBValue(key, value)
        if DB then DB[key] = value else WRA:PrintError("Cannot set spec option, DB reference is nil!") end
    end
	
    local shoutTypeValues = { NONE = L["SHOUT_OPTION_NONE"], BATTLE = L["SHOUT_OPTION_BATTLE"], COMMANDING = L["SHOUT_OPTION_COMMANDING"] }

    return {
        rotationHeader = { order = 1, type = "header", name = L["SPEC_OPTIONS_FURYWARRIOR_HEADER_ROTATION"] },
        btWwPriority = {
            order = 5,
            type = "select",
            style = "dropdown",
            name = L["OPTION_BT_WW_PRIORITY_NAME"],
            desc = L["OPTION_BT_WW_PRIORITY_DESC"],
            values = {
                ["BT_FIRST"] = L["BT_FIRST"],
                ["WW_FIRST"] = L["WW_FIRST"],
            },
            get = function() return GetSpecDBValue("btWwPriority", "BT_FIRST") end,
            set = function(info, v) SetSpecDBValue("btWwPriority", v); NotifySettingChange("btWwPriority", v) end,
        },
        useWhirlwind = { 
            order = 10, 
            type = "toggle", 
            name = L["OPTION_USE_WHIRLWIND_NAME"], 
            desc = L["OPTION_USE_WHIRLWIND_DESC"], 
            get = function() return GetSpecDBValue("useWhirlwind", true) end, 
            set = function(info, v) SetSpecDBValue("useWhirlwind", v); NotifySettingChange("useWhirlwind", v) end, 
        },
        useRend = { order = 20, type = "toggle", name = L["OPTION_USE_REND_NAME"], desc = L["OPTION_USE_REND_DESC"], get = function() return GetSpecDBValue("useRend", false) end, set = function(info, v) SetSpecDBValue("useRend", v); NotifySettingChange("useRend", v) end, },
        useOverpower = { order = 30, type = "toggle", name = L["OPTION_USE_OVERPOWER_NAME"], desc = L["OPTION_USE_OVERPOWER_DESC"], get = function() return GetSpecDBValue("useOverpower", false) end, set = function(info, v) SetSpecDBValue("useOverpower", v); NotifySettingChange("useOverpower", v) end, },
        
        throwHeader = { order = 34, type = "header", name = L["throwHeader"] },
        useHeroicThrow = { 
            order = 35, type = "toggle", name = L["useHeroicThrow"], 
            desc = L["useHeroicThrow_desc"], 
            get = function() return GetSpecDBValue("useHeroicThrow", true) end, 
            set = function(info, v) SetSpecDBValue("useHeroicThrow", v); NotifySettingChange("useHeroicThrow", v) end, 
        },
        useShatteringThrow = { 
            order = 36, type = "toggle", name = L["useShatteringThrow"], 
            desc = L["useShatteringThrow_desc"], 
            get = function() return GetSpecDBValue("useShatteringThrow", true) end, 
            set = function(info, v) SetSpecDBValue("useShatteringThrow", v); NotifySettingChange("useShatteringThrow", v) end, 
        },
        heroicThrowPostSwingWindow = { 
            order = 37, type = "range", name = L["heroicThrowPostSwingWindow"], 
            desc = L["heroicThrowPostSwingWindow_desc"], 
            min = 0.05, max = 0.5, step = 0.01, 
            get = function() return GetSpecDBValue("heroicThrowPostSwingWindow", HEROIC_THROW_POST_SWING_WINDOW_DEFAULT) end, 
            set = function(info, v) SetSpecDBValue("heroicThrowPostSwingWindow", v); NotifySettingChange("heroicThrowPostSwingWindow", v) end, 
        },
        sunderArmorMode = {
            order = 38, type = "select", style = "dropdown", name = L["sunderArmorMode"],
            desc = L["sunderArmorMode_desc"],
            values = { ["NONE"] = L["NONE"], ["FILLER"] = L["FILLER"], ["PRIORITY"] = L["PRIORITY"] },
            get = function() return GetSpecDBValue("sunderArmorMode", "NONE") end,
            set = function(info, v) SetSpecDBValue("sunderArmorMode", v); NotifySettingChange("sunderArmorMode", v) end,
        },

        smartAOE = { order = 40, type = "toggle", name = L["OPTION_SMART_AOE_NAME"], desc = L["OPTION_SMART_AOE_DESC"], get = function() return GetSpecDBValue("smartAOE", true) end, set = function(info, v) SetSpecDBValue("smartAOE", v); NotifySettingChange("smartAOE", v) end, },
        cleaveHSTargetThreshold = { order = 45, type = "range", name = L["OPTION_CLEAVE_HS_THRESHOLD_NAME"], desc = L["OPTION_CLEAVE_HS_THRESHOLD_DESC"], min = 1, max = 4, step = 1, get = function() return GetSpecDBValue("cleaveHSTargetThreshold", 2) end, set = function(info, v) SetSpecDBValue("cleaveHSTargetThreshold", v); NotifySettingChange("cleaveHSTargetThreshold", v) end, disabled = function() return not GetSpecDBValue("smartAOE", true) end, },
        enableCleave = { order = 50, type = "toggle", name = L["OPTION_ENABLE_CLEAVE_NAME"], desc = L["OPTION_ENABLE_CLEAVE_DESC"], get = function() return GetSpecDBValue("enableCleave", false) end, set = function(info, v) SetSpecDBValue("enableCleave", v); NotifySettingChange("enableCleave", v) end, },
        
        cooldownHeader = { order = 100, type = "header", name = L["SPEC_OPTIONS_FURYWARRIOR_HEADER_COOLDOWNS"] },
        useRecklessness = { order = 110, type = "toggle", name = L["OPTION_USE_RECKLESSNESS_NAME"], desc = L["OPTION_USE_RECKLESSNESS_DESC"], get = function() return GetSpecDBValue("useRecklessness", true) end, set = function(info, v) SetSpecDBValue("useRecklessness", v); NotifySettingChange("useRecklessness", v) end, },
        useDeathWish = { order = 120, type = "toggle", name = L["OPTION_USE_DEATH_WISH_NAME"], desc = L["OPTION_USE_DEATH_WISH_DESC"], get = function() return GetSpecDBValue("useDeathWish", true) end, set = function(info, v) SetSpecDBValue("useDeathWish", v); NotifySettingChange("useDeathWish", v) end, },
        useBerserkerRage = { order = 130, type = "toggle", name = L["OPTION_USE_BERSERKER_RAGE_NAME"], desc = L["OPTION_USE_BERSERKER_RAGE_DESC"], get = function() return GetSpecDBValue("useBerserkerRage", true) end, set = function(info, v) SetSpecDBValue("useBerserkerRage", v); NotifySettingChange("useBerserkerRage", v) end, },
        
        utilityHeader = { order = 200, type = "header", name = L["SPEC_OPTIONS_FURYWARRIOR_HEADER_UTILITY"] },
        useInterrupts = { order = 220, type = "toggle", name = L["OPTION_USE_INTERRUPTS_NAME"], desc = L["OPTION_USE_INTERRUPTS_DESC"], get = function() return GetSpecDBValue("useInterrupts", true) end, set = function(info, v) SetSpecDBValue("useInterrupts", v); NotifySettingChange("useInterrupts", v) end, },
        selectedShoutType = { order = 230, type = "select", name = L["OPTION_SELECTED_SHOUT_TYPE_NAME"], desc = L["OPTION_SELECTED_SHOUT_TYPE_DESC"], values = shoutTypeValues, get = function() return GetSpecDBValue("selectedShoutType", "BATTLE") end, set = function(info, v) SetSpecDBValue("selectedShoutType", v); NotifySettingChange("selectedShoutType", v) end, style = 'dropdown', },
        
        consumableHeader = { order = 300, type = "header", name = L["SPEC_OPTIONS_FURYWARRIOR_HEADER_CONSUMABLES"] },
        useTrinkets = { order = 310, type = "toggle", name = L["OPTION_USE_TRINKETS_NAME"], desc = L["OPTION_USE_TRINKETS_DESC"], get = function() return GetSpecDBValue("useTrinkets", true) end, set = function(info, v) SetSpecDBValue("useTrinkets", v); NotifySettingChange("useTrinkets", v) end, },
        usePotions = { order = 320, type = "toggle", name = L["OPTION_USE_POTIONS_NAME"], desc = L["OPTION_USE_POTIONS_DESC"], get = function() return GetSpecDBValue("usePotions", true) end, set = function(info, v) SetSpecDBValue("usePotions", v); NotifySettingChange("usePotions", v) end, },
        useRacials = { order = 330, type = "toggle", name = L["OPTION_USE_RACIALS_NAME"], desc = L["OPTION_USE_RACIALS_DESC"], get = function() return GetSpecDBValue("useRacials", true) end, set = function(info, v) SetSpecDBValue("useRacials", v); NotifySettingChange("useRacials", v) end, },
        useEngineeringGloves = {
            order = 305,
            type = "toggle",
            name = L["USE_ENGINEERING_GLOVES_NAME"],
            desc = L["USE_ENGINEERING_GLOVES_DESC"],
            get = function() return GetSpecDBValue("useEngineeringGloves", true) end,
            set = function(info, value) SetSpecDBValue("useEngineeringGloves", value); NotifySettingChange("useEngineeringGloves", value) end,
        },
    }
end
