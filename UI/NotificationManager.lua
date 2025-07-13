-- UI/NotificationManager.lua
-- Manages on-screen notifications for setting changes.
-- MODIFIED: Decoupled fade-out logic from UIFrameFadeIn's callback by using a standalone AceTimer to ensure reliability.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)

local NotificationManager = WRA:NewModule("NotificationManager", "AceEvent-3.0", "AceTimer-3.0")

-- Module variables
local notificationFrame = nil
local fadeOutTimer = nil
local FADE_IN_TIME = 0.2 -- seconds
local NOTIFICATION_DURATION = 1.5 -- seconds

-- Internal function to create the UI frames if they don't exist
local function CreateFrames()
    if notificationFrame and notificationFrame:IsObjectType("Frame") then
        return
    end

    notificationFrame = CreateFrame("Frame", "WRA_NotificationFrame", UIParent)
    notificationFrame:SetFrameStrata("HIGH")
    notificationFrame:SetSize(300, 50) -- Initial size, will adjust to text
    notificationFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    notificationFrame:SetAlpha(0)

    local bg = notificationFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.6)
    notificationFrame.background = bg
    
    local text = notificationFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 0.82, 0)
    notificationFrame.text = text
end

-- Public method to show a notification
function NotificationManager:ShowNotification(message)
    if not message then return end
    
    CreateFrames()
    
    WRA:PrintDebug("[NotificationManager] ShowNotification called with message:", message)
    
    notificationFrame.text:SetText(message)
    notificationFrame:SetWidth(notificationFrame.text:GetStringWidth() + 40)
    
    -- Always cancel any previously scheduled fade-out timer. 
    -- This handles cases where notifications appear in rapid succession.
    if fadeOutTimer then
        WRA:PrintDebug("[NotificationManager] Cancelling previous fadeOutTimer.")
        self:CancelTimer(fadeOutTimer)
        fadeOutTimer = nil
    end

    notificationFrame:Show()
    
    -- Start the fade-in animation. We don't use the finishedFunc callback anymore.
    UIFrameFadeIn(notificationFrame, FADE_IN_TIME, notificationFrame:GetAlpha(), 1)
    WRA:PrintDebug("[NotificationManager] Fading in frame.")
    
    -- *** THE FIX ***: Schedule the fade-out to happen independently of the fade-in animation's callback.
    -- The total delay is the fade-in time plus how long the notification should stay visible.
    local timeUntilFadeOut = FADE_IN_TIME + NOTIFICATION_DURATION
    WRA:PrintDebug("[NotificationManager] Scheduling HideNotification in", timeUntilFadeOut, "seconds.")
    fadeOutTimer = self:ScheduleTimer("HideNotification", timeUntilFadeOut)
end

-- Public method to hide the notification, called by our reliable AceTimer.
function NotificationManager:HideNotification()
    fadeOutTimer = nil
    if not notificationFrame or not notificationFrame:IsShown() then return end
    
    WRA:PrintDebug("[NotificationManager] Fading out frame.")
    UIFrameFadeOut(notificationFrame, 0.5, notificationFrame:GetAlpha(), 0)
end

-- Event handler for the notification message
function NotificationManager:OnNotificationShow(event, message)
    WRA:PrintDebug("[NotificationManager] Received message 'WRA_NOTIFICATION_SHOW' with text:", message)
    self:ShowNotification(message)
end

-- Module lifecycle
function NotificationManager:OnInitialize()
    WRA:PrintDebug("NotificationManager Initialized")
    CreateFrames()
end

function NotificationManager:OnEnable()
    WRA:PrintDebug("NotificationManager Enabled")
    self:RegisterMessage("WRA_NOTIFICATION_SHOW", "OnNotificationShow")
end

function NotificationManager:OnDisable()
    WRA:PrintDebug("NotificationManager Disabled")
    self:UnregisterAllMessages()
    if fadeOutTimer then
        self:CancelTimer(fadeOutTimer)
        fadeOutTimer = nil
    end
    if notificationFrame then
        notificationFrame:Hide()
    end
end
