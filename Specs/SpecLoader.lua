-- Specs/SpecLoader.lua
-- MODIFIED: Added logic to detect and load the Feral Druid specialization.
-- MODIFIED V2 (Mage Activation): Added full logic to detect and load the Fire Mage specialization.
-- MODIFIED V3 (Mage Detection): Simplified Fire Mage detection logic based on user feedback.
-- MODIFIED V4 (Bugfix): Expanded spec detection to be exhaustive for all supported classes, preventing nil returns for unsupported specs.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local AceEvent = LibStub("AceEvent-3.0", true)
if not AceEvent then WRA:PrintError("SpecLoader: Missing AceEvent!") return end

local SpecLoader = WRA:NewModule("SpecLoader", "AceEvent-3.0", "AceTimer-3.0")
WRA.SpecLoader = SpecLoader

-- WoW API functions used in this module
local UnitClass = UnitClass
local GetNumTalentTabs = GetNumTalentTabs
local GetTalentTabInfo = GetTalentTabInfo
local GetNumTalents = GetNumTalents
local GetTalentInfo = GetTalentInfo
local IsLoggedIn = IsLoggedIn

-- Module-level variables
local activeSpecModule, activeSpecKey, playerClass, C = nil, nil, nil, nil

-- Maps spec identifiers to their module names for loading
-- Note: We only have modules for a subset of these specs, but we identify all of them.
local specToModuleName = {
    ["WARRIOR_ARMS"] = "ArmsWarrior", -- Not implemented, but identified
    ["WARRIOR_FURY"] = "FuryWarrior",
    ["WARRIOR_PROTECTION"] = "ProtectionWarrior",
    ["PALADIN_HOLY"] = "HolyPaladin", -- Not implemented, but identified
    ["PALADIN_PROTECTION"] = "ProtectionPaladin",
    ["PALADIN_RETRIBUTION"] = "RetributionPaladin", 
    ["DRUID_BALANCE"] = "BalanceDruid", -- Not implemented, but identified
    ["DRUID_FERAL"] = "FeralDruid",
    ["DRUID_RESTORATION"] = "RestorationDruid", -- Not implemented, but identified
    ["MAGE_ARCANE"] = "ArcaneMage", -- Not implemented, but identified
    ["MAGE_FIRE"] = "FireMage",
    ["MAGE_FROST"] = "FrostMage", -- Not implemented, but identified
}

-- Returns the class-specific constants table
local function GetClassConstants(pClass, pSpecIdentifier)
    if pClass == "WARRIOR" then
        return WRA.ClassConstants and WRA.ClassConstants.Warrior
    elseif pClass == "PALADIN" then
        return WRA.ClassConstants and WRA.ClassConstants.Paladin
    elseif pClass == "DRUID" then
        return WRA.ClassConstants and WRA.ClassConstants.Druid
    elseif pClass == "MAGE" then
        return WRA.ClassConstants and WRA.ClassConstants.Mage
    end
    return nil
end

-- Determines the player's primary spec identifier based on talents
local function GetPrimarySpecIdentifier()
    if not playerClass then return nil end

    -- Generic logic to find the primary talent tab index
    local highestPoints = -1
    local primaryTabIndex = 0
    local numTabs = GetNumTalentTabs()
    if numTabs == 0 then return nil end
    for i = 1, numTabs do
        local _, _, _, _, pointsSpent = GetTalentTabInfo(i)
        if pointsSpent > highestPoints then
            highestPoints = pointsSpent
            primaryTabIndex = i
        end
    end
    if highestPoints <= 0 then return nil end

    -- Class-specific logic based on the primary tab index
    if playerClass == "WARRIOR" then
        -- 天赋顺序: 1=武器, 2=狂怒, 3=防护
        -- Special check for Protection Warriors first due to talent placement
        local talentNameForProtCheck = "强化防御姿态"
        local numTalentsInProt = GetNumTalents(3)
        if numTalentsInProt > 0 then
            for i = 1, numTalentsInProt do
                local name, _, _, _, currRank = GetTalentInfo(3, i)
                if name and name == talentNameForProtCheck and currRank >= 2 then
                    return "PROTECTION"
                end
            end
        end
        -- Fallback to primary tab for other specs
        if primaryTabIndex == 1 then
            return "ARMS"
        elseif primaryTabIndex == 2 then
            return "FURY"
        elseif primaryTabIndex == 3 then
            -- This case is for Prot warriors who don't meet the specific talent check above
            return "PROTECTION" 
        end
        
    elseif playerClass == "PALADIN" then
        -- 天赋顺序: 1=神圣, 2=防护, 3=惩戒
        if primaryTabIndex == 1 then
            return "HOLY"
        elseif primaryTabIndex == 2 then
            return "PROTECTION"
        elseif primaryTabIndex == 3 then
            return "RETRIBUTION"
        end

    elseif playerClass == "DRUID" then
        -- 天赋顺序: 1=平衡, 2=野性, 3=恢复
        if primaryTabIndex == 1 then
            return "BALANCE"
        elseif primaryTabIndex == 2 then
            return "FERAL"
        elseif primaryTabIndex == 3 then
            return "RESTORATION"
        end
    
    elseif playerClass == "MAGE" then
        -- 天赋顺序: 1=奥术, 2=火焰, 3=冰霜
        if primaryTabIndex == 1 then
            return "ARCANE"
        elseif primaryTabIndex == 2 then
            return "FIRE"
        elseif primaryTabIndex == 3 then
            return "FROST"
        end
    end

    return nil -- Should now be unreachable for supported classes
end

-- Loads the module corresponding to the detected spec
function SpecLoader:LoadSpecModule()
    self.loadTimer = nil
    local specIdentifier = GetPrimarySpecIdentifier()

    if C and C.RestoreOriginals then
        C:RestoreOriginals()
    else
        WRA:PrintError("SpecLoader: C.RestoreOriginals is not available!")
    end

    if not specIdentifier then
        if activeSpecModule then
             if activeSpecModule.Disable then activeSpecModule:Disable() end
             activeSpecModule, activeSpecKey = nil, nil
        end
        return
    end

    local moduleKey = playerClass .. "_" .. specIdentifier
    local moduleName = specToModuleName[moduleKey]
    if not moduleName then
        WRA:PrintDebug("SpecLoader: No module implemented for spec", moduleKey)
        if activeSpecModule then
             if activeSpecModule.Disable then activeSpecModule:Disable() end
             activeSpecModule, activeSpecKey = nil, nil
        end
        return
    end

    if activeSpecKey == moduleName then
        local classConstants = GetClassConstants(playerClass, specIdentifier)
        if C and classConstants and C.MergeSpecConstants then
            C:MergeSpecConstants(classConstants)
        end
        return
    end

    if activeSpecModule then
        if activeSpecModule.Disable then activeSpecModule:Disable() end
        activeSpecModule, activeSpecKey = nil, nil
    end

    local newModule = WRA:GetModule(moduleName, true)
    if newModule then
        setmetatable(newModule, { __index = WRA.SpecBase })

        local classConstants = GetClassConstants(playerClass, specIdentifier)
        if C and classConstants and C.MergeSpecConstants then
            C:MergeSpecConstants(classConstants)
            newModule.ClassConstants = C -- Assign merged constants
        else
            WRA:PrintError("SpecLoader: Failed to merge constants for " .. moduleName)
        end

        activeSpecModule = newModule
        activeSpecKey = moduleName
        if activeSpecModule.Enable then
            activeSpecModule:Enable()
            self:AddSpecOptionsToPanel()
        end
        self:SendMessage("WRA_SPEC_CHANGED", activeSpecModule, activeSpecKey)
    end
end

-- Standard module lifecycle methods
function SpecLoader:OnInitialize()
    _, playerClass = UnitClass("player")
    C = WRA.Constants
end

function SpecLoader:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN", "LoadSpecModule")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ScheduleLoadSpecModule")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "LoadSpecModule")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "LoadSpecModule")
    if IsLoggedIn() then self:ScheduleLoadSpecModule() end
end

-- Schedules the spec loading to avoid running it too frequently during login
function SpecLoader:ScheduleLoadSpecModule()
    if self.loadTimer then self:CancelTimer(self.loadTimer, true) end
    self.loadTimer = self:ScheduleTimer("LoadSpecModule", 0.5)
end

-- Dynamically adds spec-specific options to the main options panel
function SpecLoader:AddSpecOptionsToPanel()
    if not activeSpecKey or not WRA.OptionsPanel then return end
    local getOptionsFuncName = "GetSpecOptions_" .. activeSpecKey
    local getOptionsFunc = WRA[getOptionsFuncName]
    if type(getOptionsFunc) ~= "function" then return end
    local specOptionsTable = getOptionsFunc(WRA)
    if type(specOptionsTable) ~= "table" then return end
    WRA.OptionsPanel:AddSpecOptions(activeSpecKey, specOptionsTable)
end

-- Public accessors
function SpecLoader:GetActiveSpecModule() return activeSpecModule end
function SpecLoader:GetCurrentSpecKey() return activeSpecKey end
