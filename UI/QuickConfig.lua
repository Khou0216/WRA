-- UI/QuickConfig.lua
-- Creates the top-left buttons for Configuration and Quick Settings panel.
-- MODIFIED (V2): Implemented dynamic display of quick options based on the selected Feral stance (Cat/Bear).

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CurrentWRA = AceAddon:GetAddon(addonName) 

local AceGUI = LibStub("AceGUI-3.0", true)
local AceTimer = LibStub("AceTimer-3.0", true)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName) 

if not AceGUI or not AceTimer then
    print(addonName .. " QuickConfig: Missing AceGUI or AceTimer!")
    return
end
if not CurrentWRA then
    print(addonName .. " QuickConfig: Could not get WRA Addon instance!")
    return
end

local QuickConfig = CurrentWRA:NewModule("QuickConfig", "AceTimer-3.0", "AceEvent-3.0")

local configLauncherButton = nil
local quickPanelButton = nil
local quickPanelFrame = nil 

local function CreateLauncherButtons()
    local WRA = AceAddon:GetAddon(addonName)
    if not WRA then print(addonName .. " QuickConfig: Cannot create buttons, WRA instance not found."); return end
    local QCModule = WRA:GetModule("QuickConfig")
    if not QCModule then WRA:PrintError("QuickConfig: Cannot create buttons, QuickConfig module instance not found."); return end

    if not configLauncherButton then
        WRA:PrintDebug("Creating Config Launcher Button...")
        configLauncherButton = CreateFrame("Button", "WRA_ConfigLauncher", UIParent, "UIPanelButtonTemplate")
        configLauncherButton:SetSize(60, 22); configLauncherButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -1)
        configLauncherButton:SetText(L["Config"]); configLauncherButton:SetFrameStrata("HIGH")
        configLauncherButton:SetScript("OnClick", function()
            local OnClickWRA = AceAddon:GetAddon(addonName); if not OnClickWRA then return end
            if OnClickWRA.AceConfigDialog then
                 if type(OnClickWRA.AceConfigDialog.Open) == "function" then
                     OnClickWRA.AceConfigDialog:Open(addonName)
                     OnClickWRA:PrintDebug("Opening main options panel:", addonName)
                 else
                      OnClickWRA:PrintError("Cannot open main options: WRA.AceConfigDialog library is invalid or missing Open method.")
                 end
            else
                OnClickWRA:PrintError("Cannot open main options: WRA.AceConfigDialog reference not found.")
            end
        end)
    end

    if not quickPanelButton then
         WRA:PrintDebug("Creating Quick Launcher Button...")
         quickPanelButton = CreateFrame("Button", "WRA_QuickLauncher", UIParent, "UIPanelButtonTemplate")
         quickPanelButton:SetSize(60, 22); quickPanelButton:SetPoint("TOPLEFT", configLauncherButton, "BOTTOMLEFT", 0, -4)
         quickPanelButton:SetText(L["Quick"]); quickPanelButton:SetFrameStrata("HIGH")
         quickPanelButton:SetScript("OnClick", function()
            local ClickWRA = AceAddon:GetAddon(addonName); if not ClickWRA then print("WRA instance not found on click!"); return end
            local ClickQCModule = ClickWRA:GetModule("QuickConfig")
            if ClickQCModule then
                 if type(ClickQCModule.ToggleFrame) == "function" then
                     ClickQCModule:ToggleFrame()
                 else
                     ClickWRA:PrintError("QuickConfig: ToggleFrame function not found on module!")
                 end
            else ClickWRA:PrintError("QuickConfig: QuickConfig module instance not found!") end
         end)
    end
end

function QuickConfig:RefreshPanel()
    local WRA = AceAddon:GetAddon(addonName)
    if not WRA then return end

    if not quickPanelFrame then
        return
    end

    if not WRA.AceGUI then
        WRA:PrintError("[RefreshPanel] Error: WRA.AceGUI reference is missing!")
        return
    end

    if not WRA.db or not WRA.db.profile or not WRA.db.profile.specs then
        WRA:PrintError("[RefreshPanel] Database not initialized (WRA.db.profile.specs missing), cannot build quick options.")
        return
    end

    WRA:PrintDebug("[RefreshPanel] Refreshing panel content (Dynamic approach)...")

    quickPanelFrame:ReleaseChildren()
    WRA:PrintDebug("[RefreshPanel] Released existing children.") 

    local currentSpecKey = nil
    if WRA.SpecLoader and WRA.SpecLoader.GetCurrentSpecKey then
        currentSpecKey = WRA.SpecLoader:GetCurrentSpecKey() 
    end

    if not currentSpecKey then
        WRA:PrintError("[RefreshPanel] Could not determine current spec key via SpecLoader.")
        local label = WRA.AceGUI:Create("Label")
        label:SetText(L["No quick options available."] .. " (No spec)") 
        label:SetFullWidth(true)
        quickPanelFrame:AddChild(label)
        quickPanelFrame:DoLayout()
        return
    end
    local specDB = WRA.db.profile.specs[currentSpecKey]
    if not specDB then
        WRA:PrintError("[RefreshPanel] Could not find specDB for key:", currentSpecKey, "- creating empty one.")
        WRA.db.profile.specs[currentSpecKey] = {} 
        specDB = WRA.db.profile.specs[currentSpecKey]
    end
    WRA:PrintDebug("[RefreshPanel] Using specDB for:", currentSpecKey)

    local quickOptionKeys = {}
    if currentSpecKey == "FuryWarrior" then
        quickOptionKeys = {
            "useWhirlwind", "useRend", "useOverpower", "useHeroicThrow",
            "selectedShoutType", "smartAOE", "enableCleave", "useRecklessness",
            "useDeathWish", "useBerserkerRage", "useShatteringThrow", "useInterrupts",
            "useTrinkets", "usePotions", "useRacials", "sunderArmorMode"
        }
    elseif currentSpecKey == "ProtectionPaladin" then
        quickOptionKeys = {
            "selectedSeal_Prot", 
            "selectedJudgement_Prot", 
            "useHolyShield", 
            "useRighteousFury", 
            "useDivinePlea"
        }
    elseif currentSpecKey == "ProtectionWarrior" then
        quickOptionKeys = {
            "useThunderClap",
            "useDemoShout",
            "selectedShoutType_Prot",
            "useShockwave",
            "useShieldBlock"
        }
    elseif currentSpecKey == "RetributionPaladin" then
        quickOptionKeys = {
            "useAvengingWrath",
            "useDivineStorm",
            "useSustainabilityMode",
            "consecrationPriority",
            "selectedSeal_Ret",
            "selectedJudgement_Ret"
        }
    -- [!code ++]
    elseif currentSpecKey == "FeralDruid" then
        -- Define common keys first
        local commonKeys = {"preferredStance", "enableAOE", "forceAOE", "useMangle"}
        quickOptionKeys = commonKeys
        
        -- Get the preferred stance to decide which other keys to show
        local preferredStance = specDB.preferredStance or "CAT"
        WRA:PrintDebug("[RefreshPanel] Feral Preferred Stance for Quick Options:", preferredStance)

        if preferredStance == "CAT" then
            local catKeys = {"useTigersFury", "useBerserk", "useFerociousBite", "openerRakePriority"}
            for _, key in ipairs(catKeys) do table.insert(quickOptionKeys, key) end
        elseif preferredStance == "BEAR" then
            local bearKeys = {"useEnrage", "maulRageThreshold"}
            for _, key in ipairs(bearKeys) do table.insert(quickOptionKeys, key) end
        end
    -- [!code --]
    end

    local fullSpecOptions = nil
    local getOptionsFuncName = "GetSpecOptions_" .. currentSpecKey
    if WRA[getOptionsFuncName] and type(WRA[getOptionsFuncName]) == "function" then
        fullSpecOptions = WRA[getOptionsFuncName](WRA)
    end

    if not fullSpecOptions then
        WRA:PrintError("[RefreshPanel] Could not retrieve full spec options table from", getOptionsFuncName)
        local label = WRA.AceGUI:Create("Label")
        label:SetText(L["No quick options available."]) 
        label:SetFullWidth(true)
        quickPanelFrame:AddChild(label)
        quickPanelFrame:DoLayout()
        return
    end

    WRA:PrintDebug("[RefreshPanel] Adding widgets based on dynamic definition...")
    local widgetCount = 0
    if #quickOptionKeys > 0 then
        for _, dbKey in ipairs(quickOptionKeys) do
            local optionDef = fullSpecOptions[dbKey] 

            if optionDef then
                WRA:PrintDebug("[RefreshPanel] Creating widget for:", dbKey, "Type:", optionDef.type)
                
                local displayLabel = optionDef.name or dbKey
                local widget = nil

                local function universalSetCallback(selfWidget, event, value)
                    local key = selfWidget:GetUserData("key")
                    local originalOptionDef = fullSpecOptions and fullSpecOptions[key]

                    if originalOptionDef and type(originalOptionDef.set) == "function" then
                        local info = { [1] = "specs", [2] = currentSpecKey, [3] = key }
                        WRA:PrintDebug("[QuickPanel Callback] Calling original 'set' function for", key)
                        originalOptionDef.set(info, value)
                    else
                        WRA:PrintError("[QuickPanel Callback] No 'set' function found for key:", key, ". Setting DB directly as fallback.")
                        specDB[key] = value
                    end
                end
                
                if optionDef.type == "toggle" then
                    widget = WRA.AceGUI:Create("CheckBox")
                    widget:SetLabel(displayLabel)
                    widget:SetValue(specDB[dbKey] or false) 
                    widget:SetUserData("key", dbKey) 
                    widget:SetCallback("OnValueChanged", universalSetCallback)

                elseif optionDef.type == "select" then
                    widget = WRA.AceGUI:Create("Dropdown")
                    widget:SetLabel(displayLabel)
                    widget:SetList(optionDef.values or {})
                    widget:SetValue(specDB[dbKey] or (optionDef.get and optionDef:get() ) or "NONE")
                    widget:SetUserData("key", dbKey)
                    widget:SetCallback("OnValueChanged", function(selfWidget, event, valueKey)
                        universalSetCallback(selfWidget, event, valueKey)
                    end)
                end

                if widget then
                    quickPanelFrame:AddChild(widget) 
                    widgetCount = widgetCount + 1
                else
                    WRA:PrintDebug("[RefreshPanel] Widget not created for key:", dbKey, "(Unsupported type or error)")
                end
            else
                WRA:PrintDebug("[RefreshPanel] Skipping key:", dbKey, "- Definition not found.")
            end
        end
    end

    if widgetCount == 0 then
         local label = WRA.AceGUI:Create("Label")
         label:SetText(L["No quick options available."]) 
         label:SetFullWidth(true)
         quickPanelFrame:AddChild(label)
         widgetCount = 1
    end

    WRA:PrintDebug("[RefreshPanel] Finished adding widgets. Count:", widgetCount)
    quickPanelFrame:DoLayout()
    WRA:PrintDebug("Quick Panel Refreshed.")
end

function QuickConfig:ToggleFrame()
    local WRA = AceAddon:GetAddon(addonName)
    if not WRA then
        print(addonName .. " QuickConfig: Cannot toggle panel, WRA instance not found.")
        return
    end
    WRA:PrintDebug("[QuickConfig:ToggleFrame] Function called.") 

    if not WRA.AceGUI or type(WRA.AceGUI.Create) ~= "function" then
        WRA:PrintError("[QuickConfig:ToggleFrame] Cannot create frame, WRA.AceGUI reference is invalid!")
        return
    end

    if not quickPanelFrame then
        WRA:PrintDebug("[QuickConfig:ToggleFrame] Creating quick panel frame...")
        quickPanelFrame = WRA.AceGUI:Create("Window") 
        quickPanelFrame:SetTitle(addonName .. " " .. (L["Quick Settings"] or "Quick Settings")) 
        quickPanelFrame:SetLayout("Flow") 
        quickPanelFrame:SetWidth(230)
        quickPanelFrame:SetHeight(450)
        quickPanelFrame:EnableResize(true) 

        quickPanelFrame.frame:SetFrameStrata("HIGH") 
        quickPanelFrame.frame:SetMovable(true) 
        quickPanelFrame.frame:EnableMouse(true) 
        quickPanelFrame.frame:ClearAllPoints()
        
        if configLauncherButton then
            quickPanelFrame.frame:SetPoint("TOPLEFT", configLauncherButton, "TOPRIGHT", 10, 0) 
        else
            quickPanelFrame.frame:SetPoint("LEFT", UIParent, "LEFT", 80, -150) 
        end

        quickPanelFrame:Hide() 
        WRA:RegisterAsContainer(quickPanelFrame) 
        WRA:PrintDebug("[QuickConfig:ToggleFrame] Calling RefreshPanel after frame creation...") 
        self:RefreshPanel()
    end

    if quickPanelFrame.frame:IsShown() then
        WRA:PrintDebug("[QuickConfig:ToggleFrame] Hiding frame.")
        quickPanelFrame:Hide()
    else
        WRA:PrintDebug("[QuickConfig:ToggleFrame] Showing frame.")
        WRA:PrintDebug("[QuickConfig:ToggleFrame] Calling RefreshPanel before Show()...")
        self:RefreshPanel()
        quickPanelFrame:Show()
    end
end
function QuickConfig:GetQuickPanelFrame() return quickPanelFrame end


function QuickConfig:ShowLauncherButtons()
    CurrentWRA:PrintDebug("[QuickConfig:ShowLauncherButtons] Attempting to show buttons...") 
    if not configLauncherButton or not quickPanelButton then
        CreateLauncherButtons() 
    end
    if configLauncherButton and configLauncherButton.Show then
        configLauncherButton:Show()
        CurrentWRA:PrintDebug("[QuickConfig:ShowLauncherButtons] Config button shown.") 
    else
         CurrentWRA:PrintError("[QuickConfig:ShowLauncherButtons] Config button is nil or invalid after creation attempt!") 
    end
    if quickPanelButton and quickPanelButton.Show then
        quickPanelButton:Show()
        CurrentWRA:PrintDebug("[QuickConfig:ShowLauncherButtons] Quick button shown.") 
    else
        CurrentWRA:PrintError("[QuickConfig:ShowLauncherButtons] Quick button is nil or invalid after creation attempt!") 
    end
end

function QuickConfig:HideLauncherButtons()
    CurrentWRA:PrintDebug("[QuickConfig:HideLauncherButtons] Attempting to hide buttons...") 
    if configLauncherButton and configLauncherButton.Hide then configLauncherButton:Hide() end
    if quickPanelButton and quickPanelButton.Hide then quickPanelButton:Hide() end
    CurrentWRA:PrintDebug("[QuickConfig:HideLauncherButtons] Buttons hidden.")
end

function QuickConfig:HideQuickPanel()
    if quickPanelFrame and quickPanelFrame.Hide then 
        if quickPanelFrame.frame and quickPanelFrame.frame:IsShown() then
            quickPanelFrame:Hide()
            CurrentWRA:PrintDebug("[QuickConfig:HideQuickPanel] Panel hidden.")
        end
    end
end

function QuickConfig:HandleSettingChanged(event, key, value)
    if quickPanelFrame and quickPanelFrame.frame:IsShown() then
        CurrentWRA:PrintDebug("[QuickConfig] Received setting change, refreshing panel.")
        self:RefreshPanel()
    end
end

function QuickConfig:OnInitialize()
    CurrentWRA:PrintDebug("[QuickConfig:OnInitialize] Module Initialized.")
    self:ScheduleTimer(CreateLauncherButtons, 0.1)
end
function QuickConfig:OnEnable()
    CurrentWRA:PrintDebug("[QuickConfig:OnEnable] Module Enabled.")
    self:ShowLauncherButtons()
    self:RegisterMessage("WRA_SPEC_SETTING_CHANGED", "HandleSettingChanged")
end
function QuickConfig:OnDisable()
    CurrentWRA:PrintDebug("[QuickConfig:OnDisable] Module Disabled.")
    self:HideLauncherButtons()
    self:HideQuickPanel()
    CurrentWRA:PrintDebug("QuickConfig UI elements hidden for disable.")
    self:UnregisterMessage("WRA_SPEC_SETTING_CHANGED")
end

local eventFrame = CreateFrame("Frame", "WRA_QuickConfigEventFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local EventWRA = AceAddon:GetAddon(addonName); if not EventWRA then return end
        EventWRA:PrintDebug("PLAYER_LOGIN detected by QuickConfig.")
        local QCModule = EventWRA:GetModule("QuickConfig")
        if QCModule then
            if QCModule.ScheduleTimer then
                 QCModule:ScheduleTimer(CreateLauncherButtons, 0.8) 
                 EventWRA:PrintDebug("QuickConfig: Scheduled CreateLauncherButtons.") 
            else
                 EventWRA:PrintError("QuickConfig: ScheduleTimer method not found on QCModule! Cannot schedule button creation.")
            end
        else
            EventWRA:PrintError("QuickConfig: QuickConfig module not found, cannot schedule button creation.")
        end
        self:UnregisterEvent("PLAYER_LOGIN") 
    end
end)
