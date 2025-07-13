-- wow addon/WRA/Core/WRA.lua
-- MODIFIED (Refactor): Added AOETracker to the module loading list.
-- MODIFIED (GUID Fix): Added WRA.playerGUID initialization in OnInitialize to be used by other modules.
-- MODIFIED (Combo Command): Added handling for the new '/wra combo' command.
-- [Gemini Edit] MODIFIED: Added StateModifier, NitroBoots, and TacticalTrigger to the module loading list to fix initialization errors.
-- [Gemini Edit] MODIFIED: Added tacticalTriggers to the default database.

local addonName, addonTable = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- (Default database values remain unchanged)
local defaults = {
    profile = {
        enabled = true,
        debugMode = false,
        enableOOCSuggestions = false,
        spellQueueWindow = 100,
        useEngineeringGloves = true,
        useNitroBoots = true,
        tacticalTriggers = "", -- [Gemini Edit] ADDED THIS LINE
        selectedDisplay = "Icons",
        specs = {
            FuryWarrior = {
                 useRecklessness = true,
                 useDeathWish = true,
                 useBerserkerRage = true,
                 useShatteringThrow = true,
                 useInterrupts = false,
                 selectedShoutType = "BATTLE",
                 useTrinkets = true,
                 usePotions = true,
                 useRacials = true,
                 smartAOE = true,
                 enableCleave = false,
                 useRend = true,
                 useOverpower = true,
                 useHeroicThrow = true,
                 heroicThrowPostSwingWindow = 0.2,
            },
            FeralDruid = {
                ripLeeway = 1.5,
                roarOffset = 25,
                has4T8 = false,
                useFerociousBite = true,
                fbConstant = 10,
            },
            ProtectionWarrior = {
                useThunderClap = true,
                useDemoShout = true,
                useShockwave = true,
                aoeThreshold = 2,
                useShieldBlock = true,
                shieldBlockHealthThreshold = 60,
            },
            RetributionPaladin = {
                useAvengingWrath = true,
                useDivineStorm = true,
                useSustainabilityMode = false,
                consecrationPriority = "High",
                selectedSeal_Ret = "VENGEANCE",
                selectedJudgement_Ret = "WISDOM",
            }
        },
        encounters = {
            enabled = true
        },
        targetCounter = {
            enabled = true,
            position = { "CENTER", "UIParent", "CENTER", 0, 250 },
            locked = false,
            scale = 1.0,
            alpha = 1.0,
            fontSize = 14
        },
        displayIcons = {
            displayPoint = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 150 },
            locked = false,
            displayScale = 1.0,
            displayAlpha = 1.0,
            showOffGCDSlot = true,
            iconSize = 40,
            showColorBlockGroup = true,
            colorBlockContainerPosition = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", x = 0, y = 0 },
            colorBlockContainerLocked = false,
            colorBlockIndividualWidth = 20,
            colorBlockIndividualHeight = 20,
            colorBlockSpacing = 2,
            showGcdColorBlock = true,
            showOffGcdColorBlock = true,
        }
    }
}

function WRA:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("WRADB", defaults, true)
    
    self.playerGUID = UnitGUID("player")

    self.ClassConstants = self.ClassConstants or {}

    -- Ensure spec tables exist
    self.db.profile.specs = self.db.profile.specs or {}
    self.db.profile.specs.FuryWarrior = self.db.profile.specs.FuryWarrior or {}
    self.db.profile.specs.FeralDruid = self.db.profile.specs.FeralDruid or {}
    self.db.profile.specs.ProtectionWarrior = self.db.profile.specs.ProtectionWarrior or {}
    self.db.profile.specs.RetributionPaladin = self.db.profile.specs.RetributionPaladin or {}
    
    -- Ensure targetCounter table exists
    self.db.profile.targetCounter = self.db.profile.targetCounter or {}
    
    self.db.profile.displayIcons = self.db.profile.displayIcons or {}

    self.Utils = self:GetModule("Utils", true)
    
    if not self.Utils or not self.Utils.GetTableCopy then
        self.Utils = self.Utils or {}
        function self.Utils:GetTableCopy(originalTable)
            if type(originalTable) ~= "table" then return originalTable end
            local copy = {}
            for k, v in pairs(originalTable) do
                copy[k] = self:GetTableCopy(v)
            end
            return copy
        end
    end

    local diDefaults = defaults.profile.displayIcons
    local currentDIProfile = self.db.profile.displayIcons

    if currentDIProfile.displayPoint == nil then currentDIProfile.displayPoint = self.Utils:GetTableCopy(diDefaults.displayPoint) end
    if type(currentDIProfile.displayPoint.x) ~= "number" then currentDIProfile.displayPoint = self.Utils:GetTableCopy(diDefaults.displayPoint) end

    if currentDIProfile.locked == nil then currentDIProfile.locked = diDefaults.locked end
    if currentDIProfile.displayScale == nil then currentDIProfile.displayScale = diDefaults.displayScale end
    if currentDIProfile.displayAlpha == nil then currentDIProfile.displayAlpha = diDefaults.displayAlpha end
    if currentDIProfile.showOffGCDSlot == nil then currentDIProfile.showOffGCDSlot = diDefaults.showOffGCDSlot end
    if currentDIProfile.iconSize == nil then currentDIProfile.iconSize = diDefaults.iconSize end
    if currentDIProfile.showColorBlockGroup == nil then currentDIProfile.showColorBlockGroup = diDefaults.showColorBlockGroup end
    
    if currentDIProfile.colorBlockContainerPosition == nil then currentDIProfile.colorBlockContainerPosition = self.Utils:GetTableCopy(diDefaults.colorBlockContainerPosition) end
    if type(currentDIProfile.colorBlockContainerPosition.x) ~= "number" then currentDIProfile.colorBlockContainerPosition = self.Utils:GetTableCopy(diDefaults.colorBlockContainerPosition) end

    if currentDIProfile.colorBlockContainerLocked == nil then currentDIProfile.colorBlockContainerLocked = diDefaults.colorBlockContainerLocked end
    if currentDIProfile.colorBlockIndividualWidth == nil then currentDIProfile.colorBlockIndividualWidth = diDefaults.colorBlockIndividualWidth end
    if currentDIProfile.colorBlockIndividualHeight == nil then currentDIProfile.colorBlockIndividualHeight = diDefaults.colorBlockIndividualHeight end
    if currentDIProfile.colorBlockSpacing == nil then currentDIProfile.colorBlockSpacing = diDefaults.colorBlockSpacing end
    if currentDIProfile.showGcdColorBlock == nil then currentDIProfile.showGcdColorBlock = diDefaults.showGcdColorBlock end
    if currentDIProfile.showOffGcdColorBlock == nil then currentDIProfile.showOffGcdColorBlock = diDefaults.showOffGcdColorBlock end

    self.AceGUI = LibStub("AceGUI-3.0", true)
    self.AceConfig = LibStub("AceConfig-3.0", true)
    self.AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    self.AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
    
    -- Load all modules
    self.Constants = self:GetModule("Constants", true)
    self.SpecLoader = self:GetModule("SpecLoader", true)
    self.StateManager = self:GetModule("StateManager", true)
    self.StateModifier = self:GetModule("StateModifier", true) -- [Gemini Edit] ADDED THIS LINE
    self.AuraMonitor = self:GetModule("AuraMonitor", true)
    self.CooldownTracker = self:GetModule("CooldownTracker", true)
    self.TTDTracker = self:GetModule("TTDTracker", true)
    self.SwingTimer = self:GetModule("SwingTimer", true)
    self.NameplateTracker = self:GetModule("NameplateTracker", true)
    self.AOETracker = self:GetModule("AOETracker", true)
    self.ActionManager = self:GetModule("ActionManager", true)
    self.RotationEngine = self:GetModule("RotationEngine", true)
    self.DisplayManager = self:GetModule("DisplayManager", true)
    self.Display_Icons = self:GetModule("Display_Icons", true)
    self.NotificationManager = self:GetModule("NotificationManager", true)
    self.OptionsPanel = self:GetModule("OptionsPanel", true)
    self.QuickConfig = self:GetModule("QuickConfig", true)
    self.CommandHandler = self:GetModule("CommandHandler", true)
    self.ManualQueue = self:GetModule("ManualQueue", true)
    self.EncounterManager = self:GetModule("EncounterManager", true)
    self.NitroBoots = self:GetModule("NitroBoots", true) -- [Gemini Edit] ADDED THIS LINE
    self.TacticalTrigger = self:GetModule("TacticalTrigger", true) -- [Gemini Edit] ADDED THIS LINE
    
    self.TargetCounter = self:GetModule("TargetCounter", true)

    if not self.CommandHandler then self:PrintError("CommandHandler module failed to load!") end
    if not self.ManualQueue then self:PrintError("ManualQueue module failed to load!") end
    
    local allSpecModules = {
        "FuryWarrior", "ProtectionWarrior",
        "FeralDruid",
        "ProtectionPaladin", "RetributionPaladin",
        "FireMage"
    }
    self:PrintDebug("[WRA] Forcibly disabling all spec modules to give control to SpecLoader.")
    for _, moduleName in ipairs(allSpecModules) do
        local module = self:GetModule(moduleName, true) 
        if module then
            module.enabledState = false
        end
    end

    self:RegisterChatCommand("wra", "ChatCommand")
    self:Print(L["Addon Loaded"])
end

function WRA:OnEnable()
    if not self.db or not self.db.profile then
         self:PrintError("Cannot enable WRA: Database not initialized.")
         return
    end
    if not self.db.profile.enabled then
        self:PrintDebug("[WRA:OnEnable] Aborting enable because db.profile.enabled is false.")
        return
    end

    self:PrintDebug("[WRA:OnEnable] Enabling addon components...")
    
    -- [Gemini Edit] Fire a message to signal that all core modules have been initialized and enabled.
    -- Other modules can listen for this to safely access their dependencies.
    self:SendMessage("WRA_CORE_MODULES_ENABLED")
    self:PrintDebug("[WRA:OnEnable] Fired WRA_CORE_MODULES_ENABLED message.")
end

function WRA:OnDisable()
    self:PrintDebug("[WRA:OnDisable] Disabling addon components...")
end

function WRA:EnableAddonFeatures()
    self:PrintDebug("[WRA] EnableAddonFeatures called. Calling WRA:Enable().")
    self:Enable()
end

function WRA:DisableAddonFeatures()
    self:PrintDebug("[WRA] DisableAddonFeatures called. Calling WRA:Disable().")
    self:Disable()
end

function WRA:ChatCommand(input)
    local command, args = input:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""
    args = args or ""

    if command == "" or command == "config" or command == L["config"] then
        if self.AceConfigDialog then self.AceConfigDialog:Open(addonName) end
    elseif command == "set" then
        if self.CommandHandler then self.CommandHandler:HandleSetCommand(args) end
    elseif command == "insert" then
        if self.CommandHandler then self.CommandHandler:HandleInsertCommand(args) end
    -- [!code ++]
    -- *** NEW: Add handling for the 'combo' command ***
    elseif command == "combo" then
        if self.CommandHandler then self.CommandHandler:HandleComboCommand(args) end
    -- [!code --]
    elseif command == "quick" or command == L["quick"] then
        if self.QuickConfig then self.QuickConfig:ToggleFrame() end
    elseif command == "reset" or command == L["reset"] then
        if self.DisplayManager then self.DisplayManager:ResetDisplayPosition() end
    elseif command == "toggle" or command == L["toggle"] then
        if not self.db or not self.db.profile then return end
        self.db.profile.enabled = not self.db.profile.enabled
        self:Print("Addon toggled via command. State:", tostring(self.db.profile.enabled))
        if self.db.profile.enabled then
            self:EnableAddonFeatures()
        else
            self:DisableAddonFeatures()
        end
    else
        WRA:Print("Usage: /wra [config|quick|reset|toggle|set|insert|combo]")
    end
end

function WRA:PrintDebug(...)
    if self.db and self.db.profile and self.db.profile.debugMode then
        print("|cff1784d1" .. addonName .. "|r [Debug]:", ...)
    end
end

function WRA:PrintError(...)
    print("|cffFF0000" .. addonName .. "|r [Error]:", ...)
end
