-- Common/NameplateTracker.lua
-- MODIFIED (Refactor): Now calls the new AOETracker module directly instead of StateManager.

local addonName, _ = ... 
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")

local WRA = AceAddon:GetAddon(addonName)

local AceTimer = LibStub("AceTimer-3.0", true)
local AceEvent = LibStub("AceEvent-3.0", true)
if not AceTimer or not AceEvent then 
    WRA:PrintError("NameplateTracker: Missing AceTimer or AceEvent!")
end

local NameplateTracker = WRA:NewModule("NameplateTracker", "AceTimer-3.0", "AceEvent-3.0")
WRA.NameplateTracker = NameplateTracker 

-- WoW API localization
local C_NamePlate = _G.C_NamePlate
local UnitCanAttack = _G.UnitCanAttack
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitPlayerControlled = _G.UnitPlayerControlled
local UnitExists = _G.UnitExists
local GetCVarBool = _G.GetCVarBool
local UnitName = _G.UnitName 
local pairs = pairs 
local table = table 

local aoeCountBlacklist = {
    ["血兽"] = true, 
}

local updateTimer = nil
local UPDATE_INTERVAL = 0.25 

-- --- Internal Functions ---

local function GetVisibleEnemyPlates()
    local enemyList = {}
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates() or {}
        for i = 1, #plates do
            local plate = plates[i]
            if plate and plate.namePlateUnitToken then
                local unit = plate.namePlateUnitToken
                if UnitExists(unit) and
                   UnitCanAttack("player", unit) and
                   not UnitIsDeadOrGhost(unit) and
                   not UnitPlayerControlled(unit) and
                   not aoeCountBlacklist[UnitName(unit)] then
                    table.insert(enemyList, unit)
                end
            end
        end
    else
        WRA:PrintDebug("NameplateTracker: C_NamePlate.GetNamePlates() not found!")
    end
    return enemyList
end

local function PeriodicNameplateUpdate()
    local plates
    if GetCVarBool("nameplateShowEnemies") then
        plates = GetVisibleEnemyPlates()
    else
        plates = {}
    end

    -- [!code ++]
    -- *** REFACTOR: Directly call AOETracker instead of StateManager ***
    if WRA.AOETracker and WRA.AOETracker.UpdateFromPlates then
        WRA.AOETracker:UpdateFromPlates(plates)
    else
        WRA:PrintDebug("NameplateTracker: AOETracker or its UpdateFromPlates function not ready.")
    end
    -- [!code --]

    -- Keep this for the simple TargetCounter UI
    NameplateTracker:SendMessage("WRA_NEARBY_ENEMIES_UPDATED", #plates)
end


-- --- Module Lifecycle ---
function NameplateTracker:OnInitialize()
    WRA:PrintDebug("NameplateTracker Initialized")
end

function NameplateTracker:OnEnable()
    WRA:PrintDebug("NameplateTracker Enabled")
    if not updateTimer then
        PeriodicNameplateUpdate() 
        updateTimer = self:ScheduleRepeatingTimer(PeriodicNameplateUpdate, UPDATE_INTERVAL)
    end
    self:RegisterEvent("CVAR_UPDATE", "HandleCVarUpdate")
end

function NameplateTracker:OnDisable()
    WRA:PrintDebug("NameplateTracker Disabled")
    if updateTimer then
        self:CancelTimer(updateTimer)
        updateTimer = nil
    end
    self:UnregisterEvent("CVAR_UPDATE")
end

-- --- Event Handlers ---
function NameplateTracker:HandleCVarUpdate(event, cvarName)
    if cvarName == "nameplateShowEnemies" then
        WRA:PrintDebug("Enemy Nameplate CVar changed, forcing recount.")
        PeriodicNameplateUpdate()
    end
end

-- --- Public API Functions ---
function NameplateTracker:GetNearbyEnemyCount()
    return #GetVisibleEnemyPlates()
end

function NameplateTracker:RecountNow()
    WRA:PrintDebug("Forcing nameplate recount.")
    PeriodicNameplateUpdate()
    return #GetVisibleEnemyPlates()
end
