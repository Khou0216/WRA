-- wow addon/WRA/Common/StateManager.lua
-- MODIFIED (Refactor): Removed all AOE counting logic, which is now handled by the AOETracker module.
-- MODIFIED V2 (Caster Fix): Reworked casting state management to be more robust, inspired by FireMageAssist.lua.
-- It now uses CastingInfo() for accurate timing and only resets the casting state on interrupt/failure or natural expiration,
-- preventing state flickering between engine updates.
-- MODIFIED V3 (Final Caster Fix): Corrected HandleCastStart and HandleChannelStart to trust the CastingInfo()/ChannelInfo() APIs directly,
-- removing the fragile name comparison that was causing the state to not be set correctly.
-- MODIFIED V4 (Signature Fix): Corrected the function signatures for all UNIT_SPELLCAST_* event handlers to correctly parse arguments like castGuid and spellId.
-- MODIFIED V5 (API Usage Fix): Correctly implemented the full return signature of CastingInfo() and ChannelInfo() as per user feedback, ensuring the most reliable state updates.
-- MODIFIED V6 (Cleanup): Removed all temporary debug messages from event handlers.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local StateManager = WRA:NewModule("StateManager", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Lua shortcuts
local GetTime, UnitExists, UnitIsUnit, GetSpellInfo = GetTime, UnitExists, UnitIsUnit, GetSpellInfo
local pairs, ipairs, type, string_format, pcall, rawget, wipe = pairs, ipairs, type, string.format, pcall, rawget, table.wipe
local UnitIsDeadOrGhost, IsFeigningDeath, UnitHealth, UnitHealthMax = UnitIsDeadOrGhost, IsFeigningDeath, UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax, UnitGUID, GetUnitSpeed, GetSpellCooldown = UnitPower, UnitPowerMax, UnitGUID, GetUnitSpeed, GetSpellCooldown
local UnitAffectingCombat, UnitPowerType, UnitClassification, UnitLevel = UnitAffectingCombat, UnitPowerType, UnitClassification, UnitLevel
local UnitIsPlayer, GetInstanceInfo, UnitThreatSituation, GetShapeshiftForm = UnitIsPlayer, GetInstanceInfo, UnitThreatSituation, GetShapeshiftForm
local GetSpellPowerCost, GetComboPoints, UnitClass, CastingInfo, ChannelInfo = GetSpellPowerCost, GetComboPoints, UnitClass, CastingInfo, ChannelInfo

-- Module Forward Declarations
local Aura, CD, Swing, TTD, Utils, SpecLoader, LibRange = nil, nil, nil, nil, nil, nil, nil

-- Module-level variable to store player's class
local playerClass = nil

-- currentState table structure
local currentState = {
    player = { guid = nil, inCombat = false, isDead = false, isMoving = false, isCasting = false, isChanneling = false, castSpellID = nil, castStartTime = 0, castEndTime = 0, channelEndTime = 0, gcdEndTime = 0, isGCDActive = false, health = 0, healthMax = 0, healthPercent = 100, power = 0, powerMax = 0, powerPercent = 100, powerType = "RAGE", comboPoints = 0, isFeigning = false, threatSituation = 0, auras = {}, cooldowns = {}, swingTimer = { mainHand = 0, offHand = 0, ranged = 0 } },
    target = { guid = nil, exists = false, isEnemy = false, isFriend = false, isPlayer = false, isBoss = false, isDead = false, health = 0, healthMax = 0, healthPercent = 100, timeToDie = 0, inRange = {}, isCasting = false, castSpellID = nil, castStartTime = 0, castEndTime = 0, isChanneling = false, channelEndTime = 0, classification = "unknown", auras = {} },
    targettarget = { guid = nil, exists = false, isPlayer = false, isEnemy = false, isFriendly = false, healthPercent = 0, auras = {} },
    focus = { guid = nil, exists = false, healthPercent = 0, auras = {} },
    pet = { guid = nil, exists = false, healthPercent = 0, auras = {} },
    environment = { zoneID = 0, instanceType = "none", difficultyID = 0, isPvP = false },
    lastUpdateTime = 0,
}

local updateInterval = 0.08
local rangeCheckInterval = 0.25 
local lastRangeCheckTime = 0

function StateManager:OnInitialize()
    Aura = WRA:GetModule("AuraMonitor")
    CD = WRA:GetModule("CooldownTracker")
    Swing = WRA:GetModule("SwingTimer")
    TTD = WRA:GetModule("TTDTracker")
    Utils = WRA:GetModule("Utils")
    SpecLoader = WRA:GetModule("SpecLoader")
    LibRange = LibStub("LibRangeCheck-3.0", true)
    if not LibRange then WRA:PrintDebug("Warning: LibRangeCheck-3.0 not found or failed to load. Radius-based AOE checks will be unavailable.") end
    if not SpecLoader then WRA:PrintError("StateManager Initialize: SpecLoader module not found!") end
    self.spellCostsCache = {}
    _, playerClass = UnitClass("player")
    self:UpdateState()
    WRA:PrintDebug("StateManager Initialized.")
end

function StateManager:OnEnable()
    if not SpecLoader then SpecLoader = WRA:GetModule("SpecLoader") end
    if not TTD then TTD = WRA:GetModule("TTDTracker") end

    self.updateTimer = self:ScheduleRepeatingTimer("UpdateState", updateInterval)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "HandleCombatChange")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "HandleCombatChange")
    self:RegisterEvent("UNIT_HEALTH", "HandleUnitEvent")
    self:RegisterEvent("UNIT_MAXHEALTH", "HandleUnitEvent")
    self:RegisterEvent("UNIT_POWER_UPDATE", "HandleUnitEvent")
    self:RegisterEvent("UNIT_MAXPOWER", "HandleUnitEvent")
    self:RegisterEvent("UNIT_DISPLAYPOWER", "HandleUnitEvent")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "HandleTargetChange")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "HandleUnitEvent")
    self:RegisterEvent("UNIT_SPELLCAST_START", "HandleCastStart")
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "HandleCastStop")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "HandleCastStop")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "HandleCastStop")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "HandleCastStop")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "HandleChannelStart")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "HandleChannelStop")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateEnvironment")
    self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UpdateEnvironment")
    self:RegisterEvent("PLAYER_UNGHOST", "HandlePlayerAlive")
    self:RegisterEvent("PLAYER_ALIVE", "HandlePlayerAlive")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "HandleCooldownUpdate")
    self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", "HandleThreatUpdate")
    self:RegisterEvent("UNIT_AURA", "HandleUnitAura")
    if playerClass == "ROGUE" or playerClass == "DRUID" then self:RegisterEvent("PLAYER_COMBO_POINTS", "HandleUnitEvent") end
    
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "ClearSpellCostCache")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "ClearSpellCostCache")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "ClearSpellCostCache")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "ClearSpellCostCache")

    WRA:PrintDebug("StateManager Enabled.")
    self:HandleCombatChange()
    self:HandleTargetChange()
    self:UpdateEnvironment()
    self:HandlePlayerAlive()
end

function StateManager:OnDisable()
    if self.updateTimer then self:CancelTimer(self.updateTimer); self.updateTimer = nil end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    WRA:PrintDebug("StateManager Disabled.")
end

function StateManager:UpdateState()
    local now = GetTime()
    currentState.lastUpdateTime = now
    local player = currentState.player
    player.isDead = UnitIsDeadOrGhost("player")
    player.isFeigning = IsFeigningDeath and IsFeigningDeath() or false

    if not player.isDead and not player.isFeigning then
        player.health = UnitHealth("player")
        player.healthMax = UnitHealthMax("player")
        player.healthPercent = player.healthMax > 0 and (player.health / player.healthMax * 100) or 0
        player.power = UnitPower("player")
        player.powerMax = UnitPowerMax("player")
        player.powerPercent = player.powerMax > 0 and (player.power / player.powerMax * 100) or 0
        player.guid = player.guid or UnitGUID("player")
        player.isMoving = GetUnitSpeed("player") > 0
        
        if playerClass == "ROGUE" or playerClass == "DRUID" then
            player.comboPoints = GetComboPoints("player", "target") or 0
        else
            player.comboPoints = 0
        end

    else
        player.health, player.healthPercent, player.power, player.powerPercent, player.isMoving = 0, 0, 0, 0, false
        player.comboPoints = 0
    end

    local gcdStart, gcdDuration = GetSpellCooldown(0)
    if gcdStart and gcdDuration and gcdDuration > 0 then
        player.gcdEndTime = gcdStart + gcdDuration
        player.isGCDActive = player.gcdEndTime > now
    else
        player.isGCDActive, player.gcdEndTime = false, 0
    end

    if player.isCasting and now >= player.castEndTime then 
        player.isCasting, player.castSpellID = false, nil 
    end
    if player.isChanneling and now >= player.channelEndTime then 
        player.isChanneling, player.castSpellID = false, nil 
    end

    local target = currentState.target
    if UnitExists("target") then
        local targetGUID = UnitGUID("target")
        if target.guid ~= targetGUID then
            self:HandleTargetChange() 
        else
            self:UpdateUnitState("target", target)
        end
    else
        if target.exists then 
             wipe(target)
             target.exists, target.healthPercent, target.timeToDie, target.guid = false, 0, 0, nil
             target.inRange = {}
             target.auras = {}
        end
    end
end

function StateManager:HandleCombatChange()
    currentState.player.inCombat = UnitAffectingCombat("player")
    if not currentState.player.inCombat then
        if TTD and TTD.ResetAllTTD then TTD:ResetAllTTD() end
        currentState.player.isCasting, currentState.player.isChanneling, currentState.player.castSpellID = false, false, nil
        if currentState.target then currentState.target.isCasting, currentState.target.isChanneling, currentState.target.castSpellID = false, false, nil end
    end
    self:UpdateState() 
end

function StateManager:HandleUnitEvent(event, unit)
    if unit == "player" or (unit == "target" and currentState.target.exists and UnitIsUnit(unit, "target")) or event == "PLAYER_COMBO_POINTS" then
        self:UpdateState()
    end
    if event == "UNIT_DISPLAYPOWER" and unit == "player" then
        local _, powerToken = UnitPowerType("player")
        currentState.player.powerType = powerToken or "UNKNOWN"
    end
end

function StateManager:HandleTargetChange()
    local target = currentState.target
    local oldGuid = target.guid
    local newGuid = UnitExists("target") and UnitGUID("target") or nil

    if oldGuid ~= newGuid then
        wipe(target)
        target.exists = UnitExists("target")
        target.guid = newGuid
        target.inRange = {}
        target.auras = {} 

        if target.exists then
            self:UpdateUnitState("target", target) 
        else
            target.timeToDie = 0
            target.healthPercent = 0
            target.isCasting = false
            target.isChanneling = false
            target.castSpellID = nil
        end
    end
end

function StateManager:HandleCastStart(event, unit, castGuid, spellIdFromEvent)
    if unit ~= "player" then return end

    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellIDFromAPI = CastingInfo()
    
    if not endTime or endTime == 0 then
        return
    end

    local castEndTimeSeconds = endTime / 1000

    local p = currentState.player
    p.isCasting, p.isChanneling, p.castSpellID, p.castStartTime, p.castEndTime = true, false, spellIDFromAPI, GetTime(), castEndTimeSeconds
end

function StateManager:HandleCastStop(event, unit, castGuid, spellId)
    if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if unit == "player" and currentState.player.isCasting then
            currentState.player.isCasting, currentState.player.castSpellID, currentState.player.castEndTime = false, nil, 0
        end
    end
end

function StateManager:HandleChannelStart(event, unit, castGuid, spellIdFromEvent)
    if unit ~= "player" then return end

    local name, text, texture, startTime, endTime, isTradeSkill, spellIDFromAPI = ChannelInfo()

    if not endTime or endTime == 0 then
        return
    end

    local channelEndTimeSeconds = endTime / 1000

    local p = currentState.player
    p.isChanneling, p.isCasting, p.castSpellID, p.castStartTime, p.channelEndTime = true, false, spellIDFromAPI, GetTime(), channelEndTimeSeconds
end

function StateManager:HandleChannelStop(event, unit, castGuid, spellId)
     if unit ~= "player" then return end

     if currentState.player.isChanneling then
         currentState.player.isChanneling, currentState.player.castSpellID, currentState.player.channelEndTime = false, nil, 0
     end
end

function StateManager:HandlePlayerAlive()
    if currentState.player.isDead then
        currentState.player.isDead = false
        self:UpdateState()
    end
end

function StateManager:HandleCooldownUpdate()
    -- This event is frequent. Cooldowns are actively polled by CooldownTracker.
end

function StateManager:UpdateEnvironment()
    local _, type, difficultyIndex = GetInstanceInfo()
    currentState.environment.instanceType = type or "none"
    currentState.environment.difficultyID = difficultyIndex or 0
end

function StateManager:IsUnitBoss(unit)
    if not UnitExists(unit) then return false end
    local classification = UnitClassification(unit)
    if classification == "worldboss" or classification == "rareelite" or classification == "elite" then
        if UnitLevel(unit) == -1 then return true end
    end
    if WRA.EncounterManager and WRA.EncounterManager.IsKnownBossName then
        return WRA.EncounterManager:IsKnownBossName(UnitName(unit))
    end
    return false
end

function StateManager:UpdateUnitState(unit, unitStateTable)
    if UnitExists(unit) then
        unitStateTable.exists = true
        unitStateTable.guid = UnitGUID(unit)
        unitStateTable.health = UnitHealth(unit)
        unitStateTable.healthMax = UnitHealthMax(unit)
        unitStateTable.healthPercent = (unitStateTable.healthMax > 0) and (unitStateTable.health / unitStateTable.healthMax * 100) or 0
        unitStateTable.isPlayer = UnitIsPlayer(unit)

        if UnitExists(unit) then
            local canAttackSuccess, canAttackResult = pcall(UnitCanAttack, "player", unit)
            local isFriendSuccess, isFriendResult = pcall(UnitIsFriend, "player", unit)
            local canAttack = canAttackSuccess and canAttackResult or false
            local isFriend = isFriendSuccess and isFriendResult or false
            if not canAttackSuccess then WRA:PrintError("Error calling UnitCanAttack for unit", unit, ":", canAttackResult) end
            if not isFriendSuccess then WRA:PrintError("Error calling UnitIsFriend for unit", unit, ":", isFriendResult) end
            unitStateTable.isEnemy = canAttack and not isFriend
            unitStateTable.isFriendly = isFriend
        else
             unitStateTable.isEnemy = false
             unitStateTable.isFriendly = false
        end

        unitStateTable.classification = UnitClassification(unit) or "unknown"
        unitStateTable.isDead = UnitIsDeadOrGhost(unit)
        unitStateTable.isBoss = self:IsUnitBoss(unit)

        if unit == "target" then
            if not unitStateTable.inRange then unitStateTable.inRange = {} end

            if TTD and TTD.GetTTD then
                if unitStateTable.guid then
                    unitStateTable.timeToDie = TTD:GetTTD(unitStateTable.guid) or -1
                else
                    unitStateTable.timeToDie = -1
                end
            else
                unitStateTable.timeToDie = -1
            end

            local now = GetTime()
            if unitStateTable.isCasting and now >= unitStateTable.castEndTime then unitStateTable.isCasting, unitStateTable.castSpellID = false, nil end
            if unitStateTable.isChanneling and now >= unitStateTable.channelEndTime then unitStateTable.isChanneling, unitStateTable.castSpellID = false, nil end
        end
    else
        if unitStateTable.exists then
            wipe(unitStateTable)
            unitStateTable.exists = false
            unitStateTable.guid = nil
            unitStateTable.auras = {}
            if unit == "target" then
                unitStateTable.timeToDie = -1
                unitStateTable.inRange = {}
            end
        end
    end
end

function StateManager:HandleThreatUpdate(event, unit)
    if unit == "player" and currentState.player and UnitExists("target") then
        currentState.player.threatSituation = UnitThreatSituation("player", "target") or 0
    end
end

local lastAuraUpdateTime = {}
local AURA_UPDATE_THROTTLE = 0.05

function StateManager:HandleUnitAura(event, unit)
    if not UnitExists(unit) or not Aura or not Aura.GetUnitAuras then return end
    local now = GetTime()
    lastAuraUpdateTime[unit] = lastAuraUpdateTime[unit] or 0
    if now - lastAuraUpdateTime[unit] < AURA_UPDATE_THROTTLE then return end

    local unitTable = nil
    if unit == "player" then unitTable = currentState.player
    elseif unit == "target" then unitTable = currentState.target
    elseif unit == "focus" then unitTable = currentState.focus
    elseif unit == "pet" then unitTable = currentState.pet
    elseif unit == "targettarget" then unitTable = currentState.targettarget
    end

    if unitTable then
         unitTable.auras = Aura:GetUnitAuras(unit)
         lastAuraUpdateTime[unit] = now
    end
end

function StateManager:GetCurrentState()
    local now = GetTime()
    local player = currentState.player
    local gcdStart, gcdDuration = GetSpellCooldown(0)
    if gcdStart and gcdDuration and gcdDuration > 0 then
        player.gcdEndTime = gcdStart + gcdDuration
        player.isGCDActive = player.gcdEndTime > now
    else
        player.isGCDActive, player.gcdEndTime = false, 0
    end
    return currentState
end

StateManager.rangeCache = {}
StateManager.rangeCacheClearTimer = nil

local function ClearRangeCache()
    wipe(StateManager.rangeCache)
    StateManager.rangeCacheClearTimer = nil
end

function StateManager:IsSpellInRange(spellID, unit)
    unit = unit or "target"
    if not spellID then return false end
    if unit == "target" and (not currentState.target or not currentState.target.exists) then return false end
    if not UnitExists(unit) then return false end

    local now = GetTime()
    local cacheKey = tostring(spellID) .. ":" .. unit
    local cachedEntry = rawget(self.rangeCache, cacheKey)
    if cachedEntry and (now - cachedEntry.timestamp < rangeCheckInterval) then
        return cachedEntry.value
    end

    if not self.rangeCacheClearTimer then
        self.rangeCacheClearTimer = WRA:ScheduleTimer(ClearRangeCache, 5)
    end

    local C = WRA.Constants
    local result = false
    local libRangeSucceeded = false

    if LibRange and type(LibRange.GetRange) == "function" and C and C.SpellData then
        local spellDataEntry = C.SpellData[spellID]
        local spellRequiredYards = spellDataEntry and spellDataEntry.range

        if type(spellRequiredYards) == "number" and spellRequiredYards > 0 then
            local targetMinYards, targetMaxYards = LibRange:GetRange(unit, true)
            if targetMinYards ~= nil then
                result = targetMinYards <= spellRequiredYards
                libRangeSucceeded = true
            end
        end
    end

    if not libRangeSucceeded then
        local name = GetSpellInfo(spellID)
        if name then
            if UnitExists(unit) then
                local success, apiReturn = pcall(_G.IsSpellInRange, name, unit)
                if success then
                    result = apiReturn == 1
                else
                    result = false
                    WRA:PrintError(string_format("Fallback Path: pcall to Blizzard API FAILED for IsSpellInRange('%s', '%s'): %s.", name, unit, tostring(apiReturn)))
                end
            else
                 result = false
            end
        else
            result = false
        end
    end

    self.rangeCache[cacheKey] = { value = result, timestamp = now }
    return result
end

function StateManager:IsItemReady(itemID)
    if not itemID then return false end
    if CD and CD.IsItemReady then return CD:IsItemReady(itemID) end
    local start = _G.GetItemCooldown(itemID)
    return start == 0
end

function StateManager:GetItemCooldown(itemID)
     if not itemID then return 0, 0 end
     if CD and CD.GetCooldownRemaining then
         local remaining = CD:GetCooldownRemaining(itemID)
         local duration = CD:GetCooldownDuration(itemID) or 0
         local startTime = (remaining > 0 and duration > 0) and (GetTime() - (duration - remaining)) or 0
         return startTime, duration
     end
     return _G.GetItemCooldown(itemID)
end

function StateManager:ClearSpellCostCache()
    if self.spellCostsCache then
        wipe(self.spellCostsCache)
    end
end

function StateManager:GetActionCost(spellId)
    if not spellId then return 0 end
    local cachedCost = self.spellCostsCache[spellId]
    if cachedCost ~= nil then
        return cachedCost
    end

    local costs = GetSpellPowerCost(spellId)
    local finalCost = 0

    if costs then
        local _, powerToken = UnitPowerType("player")
        for _, costInfo in ipairs(costs) do
            if costInfo.token == powerToken then
                finalCost = costInfo.cost
                break
            end
        end
    end

    self.spellCostsCache[spellId] = finalCost
    return finalCost
end

function StateManager:GetShapeshiftForm()
    return GetShapeshiftForm()
end
