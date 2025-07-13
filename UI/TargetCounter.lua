-- WRA/UI/TargetCounter.lua
-- This module creates and manages a movable frame to display the real-time count of nearby enemies.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local TargetCounter = WRA:NewModule("TargetCounter", "AceEvent-3.0")

-- Module scope variables
local counterFrame = nil
local DB = nil

local function CreateCounterFrame()
    if counterFrame and counterFrame:IsObjectType("Frame") then
        return
    end

    counterFrame = CreateFrame("Frame", "WRA_TargetCounterFrame", UIParent, "BackdropTemplate")
    counterFrame:SetSize(120, 30)
    counterFrame:SetFrameStrata("MEDIUM")
    counterFrame:SetMovable(true)
    counterFrame:EnableMouse(true)
    counterFrame:RegisterForDrag("LeftButton")

    counterFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    counterFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
    counterFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    counterFrame.text = counterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    counterFrame.text:SetAllPoints(true)
    counterFrame.text:SetJustifyH("CENTER")
    counterFrame.text:SetText("Targets: 0")

    counterFrame:SetScript("OnDragStart", function(self)
        if DB and not DB.locked then
            self:StartMoving()
        end
    end)

    counterFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if DB then
            DB.position = { self:GetPoint() }
            WRA:PrintDebug("TargetCounter position saved.")
        end
    end)

    WRA:PrintDebug("TargetCounter frame created.")
end

function TargetCounter:ApplySettings()
    if not counterFrame or not DB then return end

    counterFrame:ClearAllPoints()
    if DB.position and DB.position[1] then
        counterFrame:SetPoint(unpack(DB.position))
    else
        -- Default position if none is saved
        counterFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 250)
    end
    
    counterFrame:SetScale(DB.scale or 1.0)
    counterFrame:SetAlpha(DB.alpha or 1.0)
    
    local font, size, flags = counterFrame.text:GetFont()
    counterFrame.text:SetFont(font, DB.fontSize or 14, flags)
    
    if DB.locked then
        counterFrame:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    else
        counterFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
    
    if DB.enabled then
        self:Show()
    else
        self:Hide()
    end
end

function TargetCounter:OnInitialize()
    if WRA.db and WRA.db.profile then
        -- Initialize database table for this module
        WRA.db.profile.targetCounter = WRA.db.profile.targetCounter or {}
        DB = WRA.db.profile.targetCounter
        
        -- Set defaults if they don't exist
        DB.enabled = DB.enabled == nil and true or DB.enabled
        DB.locked = DB.locked == nil and false or DB.locked
        DB.scale = DB.scale or 1.0
        DB.alpha = DB.alpha or 1.0
        DB.fontSize = DB.fontSize or 14
        DB.position = DB.position or { "CENTER", "UIParent", "CENTER", 0, 250 }
    else
        WRA:PrintError("TargetCounter: Database not found on Initialize!")
        return
    end
    
    CreateCounterFrame()
    WRA:PrintDebug("TargetCounter Initialized.")
end

function TargetCounter:OnEnable()
    if not DB or not DB.enabled then 
        self:Hide()
        return 
    end
    self:Show()
    self:RegisterMessage("WRA_NEARBY_ENEMIES_UPDATED")
    self:ApplySettings()
    WRA:PrintDebug("TargetCounter Enabled.")
end

function TargetCounter:OnDisable()
    self:Hide()
    self:UnregisterMessage("WRA_NEARBY_ENEMIES_UPDATED")
    WRA:PrintDebug("TargetCounter Disabled.")
end

function TargetCounter:WRA_NEARBY_ENEMIES_UPDATED(event, count)
    if counterFrame and counterFrame.text then
        counterFrame.text:SetText("Targets: " .. count)
    end
end

function TargetCounter:Show()
    if counterFrame then
        counterFrame:Show()
    end
end

function TargetCounter:Hide()
    if counterFrame then
        counterFrame:Hide()
    end
end

function TargetCounter:ResetPosition()
    if DB then
        DB.position = { "CENTER", "UIParent", "CENTER", 0, 250 }
        self:ApplySettings()
        WRA:Print("Target Counter position reset.")
    end
end

-- Function to provide options to the main options panel
function TargetCounter:GetOptionsTable()
    if not DB then return {} end
    
    return {
        targetCounterHeader = {
            order = 300, type = "header", name = "AOE 目标计数器",
        },
        targetCounterEnable = {
            order = 301, type = "toggle", name = "启用计数器",
            desc = "显示一个实时显示附近敌人数量的框架。",
            get = function() return DB.enabled end,
            set = function(info, val) 
                DB.enabled = val
                if val then TargetCounter:OnEnable() else TargetCounter:OnDisable() end
            end,
        },
        targetCounterLock = {
            order = 302, type = "toggle", name = "锁定位置",
            disabled = function() return not DB.enabled end,
            get = function() return DB.locked end,
            set = function(info, val) DB.locked = val; TargetCounter:ApplySettings() end,
        },
        targetCounterScale = {
            order = 303, type = "range", name = "缩放",
            disabled = function() return not DB.enabled end,
            min = 0.5, max = 2.0, step = 0.05,
            get = function() return DB.scale end,
            set = function(info, val) DB.scale = val; TargetCounter:ApplySettings() end,
        },
        targetCounterAlpha = {
            order = 304, type = "range", name = "透明度",
            disabled = function() return not DB.enabled end,
            min = 0.1, max = 1.0, step = 0.05,
            get = function() return DB.alpha end,
            set = function(info, val) DB.alpha = val; TargetCounter:ApplySettings() end,
        },
        targetCounterFontSize = {
            order = 305, type = "range", name = "字体大小",
            disabled = function() return not DB.enabled end,
            min = 8, max = 24, step = 1,
            get = function() return DB.fontSize end,
            set = function(info, val) DB.fontSize = val; TargetCounter:ApplySettings() end,
        },
        targetCounterReset = {
            order = 310, type = "execute", name = "重置位置",
            disabled = function() return not DB.enabled end,
            func = function() TargetCounter:ResetPosition() end,
        },
    }
end
