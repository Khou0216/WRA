-- wow addon/WRA/Common/AuraMonitor.lua
-- MODIFIED (V2): Added specific GetBuffRemaining and GetDebuffRemaining functions to provide a clearer and more robust API, fixing the nil method call from FeralDruid spec.
-- MODIFIED (V3): Fixed a critical bug where auras from other players could overwrite the player's own aura in the tracker.
-- MODIFIED (V4): Implemented a definitive two-pass scan logic to robustly handle multiple same-class auras and the UnitAura API's limitations.
-- MODIFIED (V5): Corrected the UnitAura API return value index for WotLK, now correctly using the 14th return value (isFromPlayerOrPlayerPet).
-- MODIFIED (V6): Reworked the scan logic again to be more robust against the UnitAura API only returning the most dominant aura.
-- MODIFIED (V7): Final fix. Changed aura source detection from the boolean 'isFromPlayer' to the more reliable 'unitCaster' token returned by UnitAura. This should definitively solve issues with identifying player-cast auras in multi-class environments.

local addonName, _ = ... -- Get addon name, don't rely on addonTable
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")

-- Get the main addon object instance (must be created in WRA.lua first)
local WRA = AceAddon:GetAddon(addonName)

-- Create the AuraMonitor module *on the main addon object*
local AuraMonitor = WRA:NewModule("AuraMonitor", "AceEvent-3.0", "AceTimer-3.0")
-- Get Locale safely after WRA object is confirmed
local L = LibStub("AceLocale-3.0"):GetLocale(addonName) -- Localization

-- Lua shortcuts
local GetTime = GetTime
local UnitAura = UnitAura
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit -- Important for comparing event unit vs monitored unit
local pairs = pairs
local wipe = wipe
local type = type -- Added type shortcut

-- Internal storage for tracked auras
-- Structure: trackedAuras[unitToken][spellID] = { expirationTime, count, casterIsPlayer, isBuff }
local trackedAuras = {
    player = {},
    target = {},
}

-- Units to monitor
local unitsToMonitor = { "player", "target" } 

-- Throttling for UNIT_AURA updates
local auraUpdateThrottle = 0.1 
local auraUpdateScheduled = {} 

function AuraMonitor:OnInitialize()
    WRA:PrintDebug("AuraMonitor Initialized.")
    for _, unit in pairs(unitsToMonitor) do
        trackedAuras[unit] = {}
        auraUpdateScheduled[unit] = nil
    end
end

function AuraMonitor:OnEnable()
    WRA:PrintDebug("AuraMonitor Enabled.")
    self:RegisterEvent("UNIT_AURA", "HandleUnitAuraUpdate")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "ScheduleUnitUpdate")
    for _, unit in pairs(unitsToMonitor) do
        self:ScheduleUnitUpdate(nil, unit) 
    end
end

function AuraMonitor:OnDisable()
    WRA:PrintDebug("AuraMonitor Disabled.")
    self:UnregisterAllEvents()
    for unit, timerHandle in pairs(auraUpdateScheduled) do
        if timerHandle then
            self:CancelTimer(timerHandle, true) 
            auraUpdateScheduled[unit] = nil
        end
    end
    for unit, _ in pairs(trackedAuras) do
        wipe(trackedAuras[unit])
    end
end

function AuraMonitor:HandleUnitAuraUpdate(event, unit)
    local monitoredUnitToken = nil
    for _, token in pairs(unitsToMonitor) do
        if UnitIsUnit(unit, token) then
            monitoredUnitToken = token
            break
        end
    end

    if monitoredUnitToken then
        self:ScheduleUnitUpdate(event, monitoredUnitToken)
    end
end

function AuraMonitor:ScheduleUnitUpdate(event, unit)
     if not unit or not trackedAuras[unit] then return end
     if auraUpdateScheduled[unit] then
         return
     end
     auraUpdateScheduled[unit] = self:ScheduleTimer("UpdateAurasForUnit", auraUpdateThrottle, unit)
end

function AuraMonitor:UpdateAurasForUnit(unit)
    auraUpdateScheduled[unit] = nil

    if not unit or not trackedAuras[unit] or not UnitExists(unit) then
        if trackedAuras[unit] then wipe(trackedAuras[unit]) end
        return
    end

    wipe(trackedAuras[unit])
    local unitAuras = trackedAuras[unit]

    -- *** PERFORMANCE OPTIMIZATION: Replaced the two-pass scan with a more efficient single-pass scan. ***
    -- This reduces the number of calls to the UnitAura API by half, improving performance in aura-heavy environments like raids.
    local function scanAurasSinglePass(auraType, isBuff)
        local index = 1
        while true do
            -- WotLK UnitAura returns: name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, ...
            local name, _, count, _, _, expirationTime, unitCaster, _, _, spellID = UnitAura(unit, index, auraType)
            if not name then break end

            if spellID and spellID ~= 0 then
                local isPlayerCast = (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle")
                local existingAura = unitAuras[spellID]

                -- If we don't have this aura yet, or if the new one is ours and the old one wasn't, we add/overwrite it.
                -- This correctly prioritizes the player's own auras without needing a second scan.
                if not existingAura or (isPlayerCast and not existingAura.casterIsPlayer) then
                     unitAuras[spellID] = {
                        expirationTime = expirationTime or 0,
                        count = count or 1,
                        casterIsPlayer = isPlayerCast,
                        isBuff = isBuff,
                    }
                end
            end
            index = index + 1
        end
    end

    scanAurasSinglePass("HELPFUL", true) -- Scan buffs
    scanAurasSinglePass("HARMFUL", false) -- Scan debuffs
end


--[[-----------------------------------------------------------------------------
    Public API Functions
-------------------------------------------------------------------------------]]

local function GetValidAuraData(spellID, unit)
    if not spellID or not unit or not trackedAuras[unit] then return nil end
    local auraData = trackedAuras[unit][spellID]
    if not auraData then return nil end

    if auraData.expirationTime ~= 0 and auraData.expirationTime <= GetTime() then
        return nil
    end
    return auraData
end

function AuraMonitor:HasAura(spellID, unit, checkCasterPlayer)
    local auraData = GetValidAuraData(spellID, unit)
    if not auraData then return false end 
    if checkCasterPlayer then
        return auraData.casterIsPlayer 
    else
        return true 
    end
end

function AuraMonitor:HasBuff(spellID, unit, checkCasterPlayer)
    local auraData = GetValidAuraData(spellID, unit)
    -- The `not not` idiom ensures the return value is always a boolean (true/false), never nil.
    return not not (auraData and auraData.isBuff and self:HasAura(spellID, unit, checkCasterPlayer))
end

function AuraMonitor:HasDebuff(spellID, unit, checkCasterPlayer)
     local auraData = GetValidAuraData(spellID, unit)
     -- The `not not` idiom ensures the return value is always a boolean (true/false), never nil.
     return not not (auraData and not auraData.isBuff and self:HasAura(spellID, unit, checkCasterPlayer))
end

function AuraMonitor:GetAuraRemaining(spellID, unit, checkCasterPlayer)
    local auraData = GetValidAuraData(spellID, unit)
    if not auraData then return 0 end 
    if checkCasterPlayer and not auraData.casterIsPlayer then return 0 end
    if auraData.expirationTime == 0 then return 0 end
    local remaining = auraData.expirationTime - GetTime()
    return remaining > 0 and remaining or 0
end

function AuraMonitor:GetBuffRemaining(spellID, unit, checkCasterPlayer)
    local auraData = GetValidAuraData(spellID, unit)
    if not auraData or not auraData.isBuff then return 0 end 

    if checkCasterPlayer and not auraData.casterIsPlayer then
        return 0
    end

    if auraData.expirationTime == 0 then return 0 end

    local remaining = auraData.expirationTime - GetTime()
    return remaining > 0 and remaining or 0
end

function AuraMonitor:GetDebuffRemaining(spellID, unit, checkCasterPlayer)
    local auraData = GetValidAuraData(spellID, unit)
    if not auraData or auraData.isBuff then return 0 end 

    if checkCasterPlayer and not auraData.casterIsPlayer then
        return 0
    end

    if auraData.expirationTime == 0 then return 0 end

    local remaining = auraData.expirationTime - GetTime()
    return remaining > 0 and remaining or 0
end

function AuraMonitor:GetAuraStacks(spellID, unit, checkCasterPlayer)
    local auraData = GetValidAuraData(spellID, unit)
    if not auraData then return 0 end 
    if checkCasterPlayer and not auraData.casterIsPlayer then
        return 0 
    end
    return auraData.count
end

function AuraMonitor:GetAuraData(spellID, unit)
    if not spellID or not unit or not trackedAuras[unit] then return nil end
    return trackedAuras[unit][spellID]
end
