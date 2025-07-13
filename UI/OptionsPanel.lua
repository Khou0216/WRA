-- wow addon/WRA/UI/OptionsPanel.lua
-- MODIFIED: Integrated the TargetCounter module options into the Display tab.
-- [Gemini Edit] MODIFIED: Added options for the new user-configurable TacticalTrigger system.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)

local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)
local AceTimer = LibStub("AceTimer-3.0", true)

local string_format = string.format 

if not AceConfigDialog or not AceDBOptions or not AceTimer or not AceConfigRegistry then
    WRA:PrintError("OptionsPanel: 缺少核心 Ace 库 (AceConfigDialog, AceDBOptions, AceTimer, AceConfigRegistry)！")
    return
end

local OptionsPanel = WRA:NewModule("OptionsPanel", "AceTimer-3.0", "AceEvent-3.0")

local PROFILE_OPTIONS_KEY = addonName .. "_Profiles"
OptionsPanel.profilePanelAdded = false
local mainOptionsRegistered = false
OptionsPanel.mainPanelDisplayNameForParenting = nil

local options = {
    name = addonName .. " " .. (L["SETTINGS_PANEL_TITLE"] or "Settings"),
    handler = WRA,
    type = "group",
    childGroups = "tab",
    args = {
        general = {
            order = 1, type = "group", name = L["TAB_GENERAL"] or "General",
            args = {
                header_general = {
                    order = 0, type = "header", name = L["GENERAL_SETTINGS_HEADER"] or "General Settings"
                },
                enabled = {
                    order = 1, type = "toggle", name = L["ENABLE_ADDON_NAME"] or "Enable Addon", desc = L["ENABLE_ADDON_DESC"] or "Enable/Disable the addon.",
                    get = function(info) return WRA.db.profile.enabled end,
                    set = function(info, value)
                        WRA.db.profile.enabled = value
                        if value then
                            if WRA.EnableAddonFeatures then WRA:EnableAddonFeatures() else WRA:PrintDebug("WRA:EnableAddonFeatures not defined") WRA:Enable() end
                        else
                            if WRA.DisableAddonFeatures then WRA:DisableAddonFeatures() else WRA:PrintDebug("WRA:DisableAddonFeatures not defined") WRA:Disable() end
                        end
                        if WRA.AceConfigRegistry then WRA.AceConfigRegistry:NotifyChange(addonName) end
                    end,
                },
                enableOOCSuggestions = {
                    order = 5, type = "toggle", 
                    name = L["ENABLE_OOC_SUGGESTIONS_NAME"] or "Enable Out-of-Combat Suggestions", 
                    desc = L["ENABLE_OOC_SUGGESTIONS_DESC"] or "If enabled, suggestions will appear when a valid enemy target is selected, even if not in combat.",
                    get = function(info) return WRA.db.profile.enableOOCSuggestions end,
                    set = function(info, value)
                        WRA.db.profile.enableOOCSuggestions = value
                        WRA:PrintDebug("Out-of-Combat Suggestions set to:", tostring(value))
                        if WRA.RotationEngine and WRA.RotationEngine.ForceUpdate then
                            WRA.RotationEngine:ForceUpdate()
                        end
                    end,
                },
                debugMode = {
                    order = 10, type = "toggle", name = L["DEBUG_MODE_NAME"] or "Debug Mode", desc = L["DEBUG_MODE_DESC"] or "Enable debug messages.",
                    get = function(info) return WRA.db.profile.debugMode end,
                    set = function(info, value)
                        WRA.db.profile.debugMode = value
                        WRA:PrintDebug("调试模式已设置为:", tostring(value))
                    end,
                },
                spellQueueWindow = {
                    order = 10,
                    type = 'range', -- 使用滑块控件
                    name = "施法容限 (ms)",
                    desc = "设置一个时间（毫秒），提前进入可施法状态以利用服务器的施法队列机制。建议值在50到200之间，具体取决于您的网络延迟。",
                    min = 0,      -- 最小值 0ms
                    max = 400,    -- 最大值 400ms (WOW的默认最大容限)
                    step = 10,    -- 每次调整 10ms
                    get = function(info)
                        return WRA.db.profile.spellQueueWindow
                    end,
                    set = function(info, value)
                        WRA.db.profile.spellQueueWindow = value
                    end,
                },
                -- [Gemini Edit] START: Added Tactical Trigger options
                tactical_header = {
                    order = 20,
                    type = "header",
                    name = "战术触发器设置"
                },
                useNitroBoots = {
                    order = 25,
                    type = "toggle",
                    name = L["USE_NITRO_BOOTS_NAME"] or "自动使用火箭靴",
                    desc = L["USE_NITRO_BOOTS_DESC"] or "当战术触发器被激活时，允许插件自动推荐使用火箭靴。",
                    get = function() return WRA.db.profile.useNitroBoots end,
                    set = function(info, value) WRA.db.profile.useNitroBoots = value end,
                },
                tacticalTriggers = {
                    order = 30,
                    type = "input",
                    multiline = 5,
                    width = "full",
                    name = "战术触发规则",
                    desc = "定义触发战术性技能（如火箭靴）的规则。每行一条规则，格式为：法术ID:目标:持续时间。例如：72683:player:5 (当玩家获得“冰霜道标”时，触发5秒加速)。目标可以是 'player' 或 'target'。",
                    get = function(info) return WRA.db.profile.tacticalTriggers or "" end,
                    set = function(info, value)
                        WRA.db.profile.tacticalTriggers = value
                        -- Notify the TacticalTrigger module to reload its rules
                        if WRA.TacticalTrigger and WRA.TacticalTrigger.UpdateTriggerList then
                            WRA.TacticalTrigger:UpdateTriggerList()
                        end
                    end,
                },
                -- [Gemini Edit] END
            },
        },
        display = {
            order = 2, type = "group", name = L["TAB_DISPLAY"] or "Display",
            args = {},
        },
        specs = {
            order = 10, type = "group", name = L["SPEC_SETTINGS_HEADER"] or "Specialization",
            args = {},
        },
    },
}

function OptionsPanel:RefreshDisplayOptionsAndPanel()
    WRA:PrintDebug("[OptionsPanel:RefreshDisplayOptionsAndPanel] Rebuilding display options...")
    if not options.args.display then options.args.display = { args = {} } end
    options.args.display.args = {}

    if WRA.DisplayManager and WRA.DisplayManager.GetOptionsTable then
        local dmOptions = WRA.DisplayManager:GetOptionsTable()
        if dmOptions then
             WRA:PrintDebug("[OptionsPanel] Merging DisplayManager's own options.")
             local optsToMergeDM = dmOptions.args or dmOptions
             for k,v in pairs(optsToMergeDM) do
                options.args.display.args[k] = v
             end
        end
    else
        WRA:PrintDebug("[OptionsPanel:RefreshDisplayOptionsAndPanel] DisplayManager or GetOptionsTable not found.")
    end

    local currentDisplayModule = WRA.DisplayManager and WRA.DisplayManager:GetCurrentDisplay()
    if currentDisplayModule and currentDisplayModule.GetOptionsTable then
        local currentDisplayName = WRA.DisplayManager:GetCurrentDisplayName() or "currentDisplay"
        WRA:PrintDebug("[OptionsPanel] Current display module: " .. currentDisplayName)
        local currentDisplayOptions = currentDisplayModule:GetOptionsTable()
        if currentDisplayOptions then
            local prefix = currentDisplayName .. "_"
            WRA:PrintDebug("[OptionsPanel] Merging options from: " .. prefix)
            local optsToMergeCurrent = currentDisplayOptions.args or currentDisplayOptions
            for k,v in pairs(optsToMergeCurrent) do
                options.args.display.args[prefix .. k] = v
                v.order = (v.order or 0) + 100 
                WRA:PrintDebug(string.format("  Merging %s%s, order %s", prefix, k, tostring(v.order))) 
            end
        end
    else
        WRA:PrintDebug("[OptionsPanel] No current display module or GetOptionsTable not found for current display.")
    end

    -- [[ MODIFICATION START ]]
    -- Merge options from the TargetCounter module
    if WRA.TargetCounter and WRA.TargetCounter.GetOptionsTable then
        local counterOptions = WRA.TargetCounter:GetOptionsTable()
        if counterOptions and next(counterOptions) then
            WRA:PrintDebug("[OptionsPanel] Merging TargetCounter options.")
            for k, v in pairs(counterOptions) do
                options.args.display.args[k] = v
            end
        end
    end
    -- [[ MODIFICATION END ]]

    if mainOptionsRegistered and WRA.AceConfigRegistry then
        WRA.AceConfigRegistry:NotifyChange(addonName)
        WRA:PrintDebug("[OptionsPanel:RefreshDisplayOptionsAndPanel] Notified AceConfigRegistry of main options change.")
    else
         WRA:PrintDebug("[OptionsPanel:RefreshDisplayOptionsAndPanel] Main options not yet registered or AceConfigRegistry missing, NotifyChange skipped.")
    end
end


function OptionsPanel:OnInitialize()
    if not AceConfig then
        WRA:PrintError("[OptionsPanel:OnInitialize] AceConfig-3.0 库未加载！")
        return
    end
    if not WRA.AceConfigRegistry then
         WRA:PrintError("[OptionsPanel:OnInitialize] WRA.AceConfigRegistry is nil! Attempting to assign it now.")
         WRA.AceConfigRegistry = AceConfigRegistry
         if not WRA.AceConfigRegistry then
             WRA:PrintError("[OptionsPanel:OnInitialize] Failed to assign WRA.AceConfigRegistry. Options panel might not work correctly.")
             return
         end
    end

    self:RefreshDisplayOptionsAndPanel()

    if WRA.AceConfigRegistry then
        WRA.AceConfigRegistry:RegisterOptionsTable(addonName, options, true)
        mainOptionsRegistered = true
        WRA:PrintDebug("[OptionsPanel:OnInitialize] 已注册主选项表。")
    else
        WRA:PrintError("[OptionsPanel:OnInitialize] WRA.AceConfigRegistry is still nil after attempt to assign. Cannot register main options table.")
    end

    if AceConfigDialog then
        local panelDisplayName = addonName .. " " .. (L["SETTINGS_PANEL_TITLE"] or "Settings")
        self.optionsFrame = AceConfigDialog:AddToBlizOptions(addonName, panelDisplayName, nil)
        WRA.optionsFrame = self.optionsFrame
        if self.optionsFrame then
            self.mainPanelDisplayNameForParenting = panelDisplayName
            WRA:PrintDebug("[OptionsPanel:OnInitialize] Blizzard Panel created. Display name for parenting: " .. self.mainPanelDisplayNameForParenting)
        else
            WRA:PrintError("[OptionsPanel:OnInitialize] Failed to create main Blizzard options frame.")
            self.mainPanelDisplayNameForParenting = panelDisplayName 
        end
    else
        WRA:PrintError("[OptionsPanel:OnInitialize] AceConfigDialog 库未找到！无法创建 Blizzard 面板。")
    end

    self:RegisterMessage("WRA_DISPLAY_MODULE_CHANGED", "HandleDisplayModuleChanged")
    WRA:PrintDebug("[OptionsPanel:OnInitialize] Registered for WRA_DISPLAY_MODULE_CHANGED message.")
end

function OptionsPanel:HandleDisplayModuleChanged(event, displayModuleName)
    WRA:PrintDebug(string.format("[OptionsPanel] Received %s event. New display module: %s. Refreshing display options.", event, displayModuleName))
    self:RefreshDisplayOptionsAndPanel()
end

-- NEW: Function to handle setting changes
function OptionsPanel:HandleSettingChanged(event, key, value)
    if WRA.AceConfigRegistry and WRA.AceConfigRegistry.NotifyChange then
        WRA:PrintDebug("[OptionsPanel] Received setting change, notifying AceConfigRegistry.")
        WRA.AceConfigRegistry:NotifyChange(addonName)
    end
end

function OptionsPanel:OnEnable()
    WRA:PrintDebug("[OptionsPanel:OnEnable] 已启用。计划注册和添加配置档案选项面板。")
    self:RegisterMessage("WRA_SPEC_SETTING_CHANGED", "HandleSettingChanged")

    if AceConfigDialog and WRA.db and AceDBOptions and AceDBOptions.GetOptionsTable then
        if not self.profilePanelAdded then
            self:ScheduleTimer(function()
                if self.profilePanelAdded then return end

                WRA:PrintDebug("[OptionsPanel Timer - OnEnable] 正在注册和添加 AceDBOptions 配置档案面板...")
                local profileOptions = AceDBOptions:GetOptionsTable(WRA.db)

                if type(profileOptions) == "table" then
                    if not WRA.AceConfigRegistry then
                        WRA:PrintError("[OptionsPanel Timer - OnEnable] WRA.AceConfigRegistry 未找到！无法注册配置档案选项。")
                        return
                    end
                    WRA.AceConfigRegistry:RegisterOptionsTable(PROFILE_OPTIONS_KEY, profileOptions, true)
                    WRA:PrintDebug("[OptionsPanel Timer - OnEnable] 已注册配置档案选项表，键为:", PROFILE_OPTIONS_KEY)

                    local profilePanelName = addonName .. " " .. (L["PROFILES_PANEL_TITLE"] or "Profiles")
                    local parentCategoryNameToUse = self.mainPanelDisplayNameForParenting

                    if not parentCategoryNameToUse then
                        WRA:PrintError("[OptionsPanel Timer - OnEnable] Main panel display name for parenting not found. Attempting to add Profiles panel as top-level or it might fail.")
                    end
                    
                    WRA:PrintDebug(string.format("[OptionsPanel Timer - OnEnable] Attempting to add Profiles panel. Profile Key: %s, Display Name: %s, Parent: %s",
                        PROFILE_OPTIONS_KEY, profilePanelName, tostring(parentCategoryNameToUse)))

                    local success, resultOrError = pcall(function()
                        AceConfigDialog:AddToBlizOptions(PROFILE_OPTIONS_KEY, profilePanelName, parentCategoryNameToUse)
                    end)

                    if success then
                         WRA:PrintDebug("[OptionsPanel Timer - OnEnable] 已添加配置档案面板:", profilePanelName, "父级为:", tostring(parentCategoryNameToUse))
                         self.profilePanelAdded = true
                    else
                         WRA:PrintError("[OptionsPanel Timer - OnEnable] 添加配置档案选项面板时出错:", resultOrError or "未知错误 (pcall itself failed)")
                    end
                else
                    WRA:PrintError("[OptionsPanel Timer - OnEnable] AceDBOptions:GetOptionsTable 未返回表！")
                end
            end, 0.45)
        else
            WRA:PrintDebug("[OptionsPanel:OnEnable] 配置档案面板已添加，跳过计划。")
        end
    else
         WRA:PrintError("[OptionsPanel:OnEnable] AceConfigDialog、WRA.db 或 AceDBOptions (或其GetOptionsTable方法) 未找到！无法计划添加配置档案选项。")
    end
end

function OptionsPanel:OnDisable()
    WRA:PrintDebug("[OptionsPanel:OnDisable] 模块已禁用。")
    self:UnregisterMessage("WRA_DISPLAY_MODULE_CHANGED")
    self:UnregisterMessage("WRA_SPEC_SETTING_CHANGED")
end

function OptionsPanel:AddSpecOptions(specKey, specOptionsTable)
    if not WRA.AceConfigRegistry then
        WRA:PrintError("[OptionsPanel:AddSpecOptions] WRA.AceConfigRegistry 引用缺失！")
        return
    end

    if not options or not options.args or not options.args.specs or not options.args.specs.args then
        WRA:PrintError(string.format("错误：无法为 %s 添加专精选项。主选项结构未就绪。", specKey))
        return
    end
    if not specKey or type(specOptionsTable) ~= "table" then
        WRA:PrintError("错误：传递给 AddSpecOptions 的参数无效。SpecKey:", tostring(specKey))
        return
    end

    local specOrder = 10
    if WRA.Constants and WRA.Constants.SPEC_ORDER and WRA.Constants.SPEC_ORDER[specKey] then
        specOrder = WRA.Constants.SPEC_ORDER[specKey]
    end

    WRA:PrintDebug("[OptionsPanel:AddSpecOptions] 正在为专精添加选项组:", specKey)

    options.args.specs.args[specKey] = {
        type = "group",
        name = L[specKey] or (L["SPEC_SETTINGS_UNKNOWN_SPEC"] or specKey),
        order = specOrder,
        args = specOptionsTable,
        hidden = function()
           local currentSpecKey = WRA.SpecLoader and WRA.SpecLoader:GetCurrentSpecKey() or "nil"
           local shouldHide = not (currentSpecKey == specKey)
           return shouldHide
        end,
    }

    if WRA.AceConfigRegistry and WRA.AceConfigRegistry.NotifyChange then
        WRA.AceConfigRegistry:NotifyChange(addonName)
        WRA:PrintDebug("[OptionsPanel:AddSpecOptions] 已通知 AceConfig 关于 ", addonName, " 的更改")
    else
         WRA:PrintError("[OptionsPanel:AddSpecOptions] 无法通知 AceConfig 更改。UI 可能不会更新。")
    end
end

function OptionsPanel:RefreshOptions()
    WRA:PrintDebug("[OptionsPanel:RefreshOptions] Refreshing all options...")
    self:RefreshDisplayOptionsAndPanel()
end

function OptionsPanel:Open(groupPath)
    if not WRA.AceConfigRegistry or not AceConfigDialog then
        WRA:PrintError("无法打开选项面板，WRA.AceConfigRegistry 或 AceConfigDialog 未加载。")
        return
    end
    if not mainOptionsRegistered then
        WRA:PrintDebug("主选项表尚未注册，尝试注册...")
        self:OnInitialize()
        if not mainOptionsRegistered then
            WRA:PrintError("注册主选项表失败，无法打开选项面板。")
            return
        end
    end

    self:RefreshDisplayOptionsAndPanel()

    if WRA.db and AceDBOptions and not self.profilePanelAdded and WRA.AceConfigRegistry and not WRA.AceConfigRegistry:IsRegistered(PROFILE_OPTIONS_KEY) then
        WRA:PrintDebug("档案面板可能尚未注册，尝试启用流程...")
        self:OnEnable()
    end

    AceConfigDialog:Open(addonName, groupPath)
    WRA:PrintDebug("尝试打开选项面板到路径: ", groupPath or " (根)")
end
