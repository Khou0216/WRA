-- Common/AOETracker.lua
-- A new, dedicated module for tracking nearby enemies for AOE logic.
-- This module decouples AOE counting from the main StateManager.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)

local AOETracker = WRA:NewModule("AOETracker")

-- Lua shortcuts
local ipairs = ipairs
local wipe = table.wipe
local UnitExists = _G.UnitExists

-- Module references
local LibRange = nil

-- Internal state
local enemiesWithRange = {}

-- --- Module Lifecycle ---

function AOETracker:OnInitialize()
    LibRange = LibStub("LibRangeCheck-3.0", true)
    if not LibRange then
        WRA:PrintError("AOETracker: LibRangeCheck-3.0 is not available. AOE counting will not function.")
    end
    wipe(enemiesWithRange)
    WRA:PrintDebug("AOETracker Initialized.")
end

function AOETracker:OnEnable()
    WRA:PrintDebug("AOETracker Enabled.")
    -- This module is passive and updated by NameplateTracker, so no events needed here.
end

function AOETracker:OnDisable()
    WRA:PrintDebug("AOETracker Disabled.")
    wipe(enemiesWithRange)
end

-- --- Public API ---

-- This function is called directly by NameplateTracker with a list of visible plates.
function AOETracker:UpdateFromPlates(plates)
    if not LibRange then return end

    wipe(enemiesWithRange)
    if plates and #plates > 0 then
        for i = 1, #plates do
            local unitId = plates[i]
            if UnitExists(unitId) then
                local minRange, maxRange = LibRange:GetRange(unitId, true)
                if minRange then
                    enemiesWithRange[#enemiesWithRange + 1] = {
                        unitId = unitId,
                        range = minRange
                    }
                end
            end
        end
    end
end

-- This is the new, clean API for spec modules to call.
function AOETracker:GetNearbyEnemyCount(radius)
    if not radius then
        return #enemiesWithRange
    end
    
    local count = 0
    for _, enemyInfo in ipairs(enemiesWithRange) do
        if enemyInfo.range <= radius then
            count = count + 1
        end
    end
    return count
end
