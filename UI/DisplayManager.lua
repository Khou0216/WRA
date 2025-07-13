-- UI/DisplayManager.lua
-- Manages the visual display of rotation suggestions.
-- v7: Removed direct call to UpdateFrameAppearanceAndLayout from ShowDisplay.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local DisplayManager = WRA:NewModule("DisplayManager", "AceEvent-3.0", "AceTimer-3.0")

local pairs = pairs
local type = type
local wipe = table.wipe
local string_format = string.format
local next = next

local activeDisplayModule = nil
local activeDisplayName = nil
local availableDisplays = {} -- Correctly initialize here
local DB = nil

local DEFAULT_DISPLAY_NAME = "Icons" -- Default display type
local INITIAL_DISPLAY_ATTEMPT_DELAY = 0.25 -- Delay for first attempt
local INITIAL_DISPLAY_RETRY_DELAY = 0.75  -- Delay for retry if no displays found

function DisplayManager:OnInitialize()
    if WRA.db and WRA.db.profile then
        if not WRA.db.profile.displayManager then
            WRA.db.profile.displayManager = {}
        end
        DB = WRA.db.profile.displayManager
        if DB.selectedDisplay == nil or DB.selectedDisplay == "NONE_REGISTERED" then -- Ensure invalid value isn't kept
            DB.selectedDisplay = DEFAULT_DISPLAY_NAME
        end
    else
        WRA:PrintError("[DisplayManager:OnInitialize] 错误：无法获取数据库引用！")
        DB = { selectedDisplay = DEFAULT_DISPLAY_NAME }
    end
    activeDisplayModule = nil
    activeDisplayName = nil
    wipe(availableDisplays) -- Ensure it's wiped on initialize
end

function DisplayManager:OnEnable()
    if not DB then
        if WRA.db and WRA.db.profile and WRA.db.profile.displayManager then
            DB = WRA.db.profile.displayManager
            if DB.selectedDisplay == "NONE_REGISTERED" then DB.selectedDisplay = DEFAULT_DISPLAY_NAME end
        else
            WRA:PrintError("[DisplayManager:OnEnable] 错误：无法启用，缺少数据库引用！")
            return
        end
    end

    if self.initialDisplayAttemptTimer then
        self:CancelTimer(self.initialDisplayAttemptTimer, true)
        self.initialDisplayAttemptTimer = nil
    end
    self.initialDisplayAttemptTimer = self:ScheduleTimer("AttemptInitialDisplaySelection", INITIAL_DISPLAY_ATTEMPT_DELAY)
end

function DisplayManager:AttemptInitialDisplaySelection()
    self.initialDisplayAttemptTimer = nil

    if not activeDisplayModule then
        local targetDisplay = DB.selectedDisplay or DEFAULT_DISPLAY_NAME

        if self:GetAvailableDisplayNamesCount() == 0 then
            if not self.initialDisplayRetryTimer then
                self.initialDisplayRetryTimer = self:ScheduleTimer(function()
                    self.initialDisplayRetryTimer = nil
                    self:AttemptInitialDisplaySelection()
                end, INITIAL_DISPLAY_RETRY_DELAY)
            end
            return
        end

        if self.initialDisplayRetryTimer then
            self:CancelTimer(self.initialDisplayRetryTimer, true)
            self.initialDisplayRetryTimer = nil
        end

        -- Validate targetDisplay before attempting to select
        if not availableDisplays[targetDisplay] then
            targetDisplay = DEFAULT_DISPLAY_NAME
        end

        if availableDisplays[targetDisplay] then
            self:SelectDisplay(targetDisplay)
        elseif next(availableDisplays) then -- Fallback to the first available if default also fails
            for name, _ in pairs(availableDisplays) do
                self:SelectDisplay(name)
                return -- Important: return after selecting the first available
            end
        else
            WRA:PrintError("[DisplayManager:AttemptInitialDisplaySelection] 错误：没有可用的显示模块！")
        end
    end
end


function DisplayManager:OnDisable()
    if self.initialDisplayAttemptTimer then
        self:CancelTimer(self.initialDisplayAttemptTimer, true)
        self.initialDisplayAttemptTimer = nil
    end
    if self.initialDisplayRetryTimer then
        self:CancelTimer(self.initialDisplayRetryTimer, true)
        self.initialDisplayRetryTimer = nil
    end
    self:HideDisplay()
end

function DisplayManager:RegisterDisplay(name, moduleInstance)
    if not name or not moduleInstance then
        WRA:PrintError("[DisplayManager:RegisterDisplay] 错误：需要提供名称和模块实例。")
        return
    end
    if type(moduleInstance.UpdateDisplay) ~= "function" then
         WRA:PrintError(string_format("[DisplayManager:RegisterDisplay] 错误：显示模块 [%s] 缺少必需的 UpdateDisplay 函数。", name))
         return
    end
    if not availableDisplays[name] then
        availableDisplays[name] = moduleInstance

        if not activeDisplayModule and ((DB and DB.selectedDisplay == name) or (not DB or not DB.selectedDisplay and name == DEFAULT_DISPLAY_NAME)) then
            self:SelectDisplay(name)
        elseif not activeDisplayModule and self:GetAvailableDisplayNamesCount() == 1 then
            self:SelectDisplay(name)
        end
    end
end

function DisplayManager:SelectDisplay(name)
    if not DB then
        if WRA.db and WRA.db.profile and WRA.db.profile.displayManager then DB = WRA.db.profile.displayManager
        else WRA:PrintError("[DisplayManager:SelectDisplay] 错误：无法选择显示模块 - 数据库引用缺失。"); return
        end
    end

    if self:GetAvailableDisplayNamesCount() == 0 then
        WRA:PrintError(string_format("[DisplayManager:SelectDisplay] 错误：availableDisplays 表为空！无法选择 '%s'。", name))
        return
    end

    local newDisplayModule = availableDisplays[name]
    if not newDisplayModule then
        WRA:PrintError(string_format("[DisplayManager:SelectDisplay] 错误：在选择期间未找到显示后端: %s", name))
        local fallbackName = DEFAULT_DISPLAY_NAME
        if name ~= fallbackName and availableDisplays[fallbackName] then
             name = fallbackName
             newDisplayModule = availableDisplays[name]
        elseif next(availableDisplays) then -- If default also not found, pick first available
            for firstAvailableName, _module in pairs(availableDisplays) do -- Iterate to get the first module
                name = firstAvailableName
                newDisplayModule = _module -- Use the module instance
                break
            end
        end

        if not newDisplayModule then
            WRA:PrintError(string_format("[DisplayManager:SelectDisplay] 错误：回退显示模块 '%s' 在选择期间也未找到或注册。", name))
            return
        end
    end

    if activeDisplayModule == newDisplayModule and activeDisplayName == name then
         if WRA.db.profile.enabled and newDisplayModule.Show then
             if newDisplayModule.CreateDisplayElements then newDisplayModule:CreateDisplayElements() end
             newDisplayModule:Show()
         end
        return
    end

    if activeDisplayModule and activeDisplayModule.Hide then
        activeDisplayModule:Hide()
    end

    activeDisplayModule = newDisplayModule
    activeDisplayName = name

    if activeDisplayModule.OnModuleSelected then
        activeDisplayModule:OnModuleSelected()
    end

    DB.selectedDisplay = name -- Save the valid selection

    if WRA.db.profile.enabled then
        self:ShowDisplay()
    end
    WRA:SendMessage("WRA_DISPLAY_MODULE_CHANGED", name)
end

function DisplayManager:UpdateAction(actionsTable)
    if activeDisplayModule and activeDisplayModule.UpdateDisplay then
        activeDisplayModule:UpdateDisplay(actionsTable)
    end
end

function DisplayManager:ShowDisplay()
    if activeDisplayModule then
        if activeDisplayModule.CreateDisplayElements then activeDisplayModule:CreateDisplayElements() end
        if activeDisplayModule.Show then
            activeDisplayModule:Show()
        end
    end
end

function DisplayManager:HideDisplay()
     if activeDisplayModule and activeDisplayModule.Hide then
         activeDisplayModule:Hide()
     end
end

function DisplayManager:ResetDisplayPosition()
    if activeDisplayModule and activeDisplayModule.ResetPosition then
        activeDisplayModule:ResetPosition()
        WRA:Print(L["DISPLAY_POSITION_RESET"])
    elseif activeDisplayModule then
        WRA:Print(string.format("警告：活动显示模块 [%s] 不支持 ResetPosition。", activeDisplayName or "?"))
    else
        WRA:Print("没有活动的显示模块来重置位置。")
    end
end

function DisplayManager:GetAvailableDisplayTypes()
    local types = {}
    for name, _ in pairs(availableDisplays) do types[name] = name end
    return types
end

function DisplayManager:GetAvailableDisplayNamesCount()
    local count = 0
    for _ in pairs(availableDisplays) do
        count = count + 1
    end
    return count
end

function DisplayManager:GetCurrentDisplay() return activeDisplayModule end
function DisplayManager:GetCurrentDisplayName() return activeDisplayName end

function DisplayManager:OpenConfiguration()
    if activeDisplayModule and activeDisplayModule.OpenConfiguration then
        activeDisplayModule:OpenConfiguration()
    else
        WRA:Print("活动显示模块没有特定的配置界面。")
    end
end

function DisplayManager:GetOptionsTable()
    local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
    if not L then L = setmetatable({}, {__index=function(t,k) return k end}) end

    local displayValuesFunc = function()
        local values = {}
        local displayNames = self:GetAvailableDisplayTypes()
        if next(displayNames) == nil then
            values[DEFAULT_DISPLAY_NAME] = L[DEFAULT_DISPLAY_NAME] or DEFAULT_DISPLAY_NAME
        else
            for key, val in pairs(displayNames) do
                values[key] = L[val] or val
            end
        end
        return values
    end

    return {
        type = "group",
        name = L["DISPLAY_MANAGER_SETTINGS_HEADER"] or "Display Manager Settings",
        order = 1,
        args = {
            selectedDisplay = {
                order = 1,
                type = "select",
                name = L["SELECT_DISPLAY_MODE_NAME"] or "Display Mode",
                desc = L["SELECT_DISPLAY_MODE_DESC"] or "Choose the visual style for rotation suggestions.",
                get = function(info)
                    if not DB then return DEFAULT_DISPLAY_NAME end
                    if availableDisplays[DB.selectedDisplay] then
                        return DB.selectedDisplay
                    elseif availableDisplays[DEFAULT_DISPLAY_NAME] then
                        return DEFAULT_DISPLAY_NAME
                    elseif next(availableDisplays) then
                        for k, _ in pairs(availableDisplays) do return k end
                    end
                    return DEFAULT_DISPLAY_NAME
                end,
                set = function(info, value)
                    if not DB then WRA:PrintError("[DisplayManager:SetSelectedDisplay] DB is nil!"); return end

                    if availableDisplays[value] then
                        DB.selectedDisplay = value
                        self:SelectDisplay(value)
                        WRA:SendMessage("WRA_DISPLAY_MODULE_CHANGED", value)
                    else
                        WRA:PrintError(string.format("[DisplayManager:SetSelectedDisplay] Attempted to set invalid display '%s'. Reverting to default or first available.", value))
                        if availableDisplays[DEFAULT_DISPLAY_NAME] then
                            DB.selectedDisplay = DEFAULT_DISPLAY_NAME
                            self:SelectDisplay(DEFAULT_DISPLAY_NAME)
                        elseif next(availableDisplays) then
                            for k, _ in pairs(availableDisplays) do
                                DB.selectedDisplay = k
                                self:SelectDisplay(k)
                                break
                            end
                        end
                        WRA:SendMessage("WRA_DISPLAY_MODULE_CHANGED", DB.selectedDisplay)
                    end
                end,
                values = displayValuesFunc,
            },
        }
    }
end
