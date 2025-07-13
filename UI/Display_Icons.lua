-- wow addon/WRA/UI/Display_Icons.lua
-- Implements the icon-based display with a unified color block container.
-- MODIFIED: GetActionDisplayInfo now dynamically retrieves info from WRA.Constants instead of a pre-populated map.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")

if not AceAddon then print("WRA FATAL ERROR in Display_Icons.lua: AceAddon is nil!") return end
local WRA = AceAddon:GetAddon(addonName)
if not WRA then print("WRA FATAL ERROR in Display_Icons.lua: WRA (addon instance) is nil! addonName was: " .. tostring(addonName)) return end

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local Display_Icons = WRA:NewModule("Display_Icons", "AceEvent-3.0", "AceTimer-3.0")
if not Display_Icons then print("WRA FATAL ERROR in Display_Icons.lua: WRA:NewModule('Display_Icons') returned nil!") return end

-- Lua shortcuts
local GetSpellInfo = GetSpellInfo
local GetItemInfo = GetItemInfo
local GetTime = GetTime
local pairs = pairs
local type = type
local math_abs = math.abs
local wipe = table.wipe
local string_format = string.format
local CreateFrame = CreateFrame
local UIParent = UIParent
local CooldownFrame_Set = CooldownFrame_Set
local GetSpellCooldown = GetSpellCooldown

-- Module scope variables
local C = nil -- WRA.Constants
local DB = nil -- WRA.db.profile.displayIcons

local ACTION_ID_IDLE, ACTION_ID_WAITING, ACTION_ID_CASTING, ACTION_ID_UNKNOWN

-- UI Frames
local mainIconFrame = nil 
local gcdIconSlot = {}   
local offGcdIconSlot = {} 

local colorBlockContainer = nil 
local gcdColorBlock = nil
local offGcdColorBlock = nil

-- [!code --]
-- local actionMap = {} 
-- [!code --]

local DEFAULT_ICON_SIZE = 40
local DEFAULT_QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local SLOT_SPACING = 4 
local DEFAULT_BACKDROP_INSET = 0 

-- [!code --]
-- local function GetActionDisplayInfo(actionID)
--     local displayInfo = {
--         texture = DEFAULT_QUESTION_MARK_ICON,
--         color = (C and C.ActionColors and C.ActionColors[ACTION_ID_UNKNOWN]) or {r=0.1,g=0.1,b=0.1,a=0.8} 
--     }
--     if not actionID then actionID = ACTION_ID_IDLE end

--     if actionMap[actionID] and actionMap[actionID].texture then
--         displayInfo.texture = actionMap[actionID].texture
--     elseif type(actionID) == "number" and actionID ~= 0 then
--         if actionID > 0 then 
--             local name, _, spellTex = GetSpellInfo(actionID)
--             if spellTex then
--                 displayInfo.texture = spellTex
--                 actionMap[actionID] = { texture = spellTex, isSpell = true, name = name or "Unknown Spell" }
--             end
--         elseif actionID < 0 then 
--             local itemName, _, _, _, _, _, _, _, _, itemTex = GetItemInfo(math_abs(actionID))
--             if itemTex then
--                 displayInfo.texture = itemTex
--                 actionMap[actionID] = { texture = itemTex, isItem = true, name = itemName or "Unknown Item" }
--             end
--         end
--     end

--     if C and C.ActionColors and C.ActionColors[actionID] then
--         displayInfo.color = C.ActionColors[actionID]
--     elseif C and C.ActionColors and (actionID == ACTION_ID_IDLE or actionID == ACTION_ID_WAITING) and C.ActionColors[ACTION_ID_IDLE] then
--          displayInfo.color = C.ActionColors[ACTION_ID_IDLE]
--     end

--     if type(displayInfo.color) ~= "table" then
--         displayInfo.color = (C and C.ActionColors and C.ActionColors[ACTION_ID_UNKNOWN]) or {r=0.1,g=0.1,b=0.1,a=0.8}
--     end
--     if displayInfo.color.a == nil then displayInfo.color.a = 1 end 
--     return displayInfo
-- end
-- [!code ++]
-- *** 修改：实时动态获取显示信息，不再依赖预填充的actionMap ***
local function GetActionDisplayInfo(actionID)
    local displayInfo = {
        texture = DEFAULT_QUESTION_MARK_ICON,
        color = (C and C.ActionColors and C.ActionColors[ACTION_ID_UNKNOWN]) or {r=0.1,g=0.1,b=0.1,a=0.8} 
    }
    if not actionID then actionID = ACTION_ID_IDLE end

    local name, texture, isItem

    -- 1. 检查是不是特殊的字符串动作ID
    if type(actionID) == "string" then
        if C and C.ActionColors[actionID] then
            displayInfo.color = C.ActionColors[actionID]
        end
        if actionID == ACTION_ID_IDLE then
            texture = DEFAULT_QUESTION_MARK_ICON
        elseif actionID == ACTION_ID_WAITING then
            texture = "Interface\\Icons\\INV_Misc_PocketWatch_01"
        elseif actionID == ACTION_ID_CASTING then
             texture = "Interface\\Icons\\INV_Misc_PocketWatch_02"
        end
    -- 2. 检查是不是数字ID (技能或物品)
    elseif type(actionID) == "number" and actionID ~= 0 then
        if actionID > 0 then -- Spell
            _, _, texture = GetSpellInfo(actionID)
        elseif actionID < 0 then -- Item
            _, _, _, _, _, _, _, _, _, texture = GetItemInfo(math_abs(actionID))
            isItem = true
        end
        -- 尝试从合并后的常量表中获取颜色
        if C and C.ActionColors and C.ActionColors[actionID] then
            displayInfo.color = C.ActionColors[actionID]
        end
    -- 3. 检查是不是 START_ATTACK 这样的特殊数字ID
    elseif actionID == C.Spells.START_ATTACK then
        texture = "Interface\\ICONS\\Ability_Attack"
        if C and C.ActionColors and C.ActionColors[actionID] then
            displayInfo.color = C.ActionColors[actionID]
        end
    end
    
    displayInfo.texture = texture or DEFAULT_QUESTION_MARK_ICON
    
    -- 确保颜色是有效的表
    if type(displayInfo.color) ~= "table" then
        displayInfo.color = (C and C.ActionColors and C.ActionColors[ACTION_ID_UNKNOWN]) or {r=0.1,g=0.1,b=0.1,a=0.8}
    end
    if displayInfo.color.a == nil then displayInfo.color.a = 1 end 

    return displayInfo
end
-- [!code --]


function Display_Icons:OnInitialize()
    WRA:PrintDebug("Display_Icons:OnInitialize() START")
    C = WRA.Constants
    if WRA.db and WRA.db.profile and WRA.db.profile.displayIcons then
        DB = WRA.db.profile.displayIcons
    else
        WRA:PrintError("Display_Icons: Database not available on initialize! Using fallback DB structure.")
        DB = { 
            displayPoint = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 150 },
            locked = false, displayScale = 1.0, displayAlpha = 1.0, showOffGCDSlot = true, iconSize = 40,
            showColorBlockGroup = true,
            colorBlockContainerPosition = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 120 }, -- Default relative to UIParent center
            colorBlockContainerLocked = false, colorBlockIndividualWidth = 38, colorBlockIndividualHeight = 8,
            colorBlockSpacing = 2, showGcdColorBlock = true, showOffGcdColorBlock = true,
        }
    end

    mainIconFrame = nil
    wipe(gcdIconSlot)
    wipe(offGcdIconSlot)
    colorBlockContainer = nil
    gcdColorBlock = nil
    offGcdColorBlock = nil
    -- [!code --]
    -- wipe(actionMap)
    -- [!code --]

    if C then
        ACTION_ID_IDLE = C.ACTION_ID_IDLE or "IDLE"
        ACTION_ID_WAITING = C.ACTION_ID_WAITING or 0
        ACTION_ID_CASTING = C.ACTION_ID_CASTING or "CASTING"
        ACTION_ID_UNKNOWN = C.ACTION_ID_UNKNOWN or -1
    else
        WRA:PrintError("Display_Icons: WRA.Constants not found! Cannot load constants.")
        ACTION_ID_IDLE = "IDLE"; ACTION_ID_WAITING = 0; ACTION_ID_CASTING = "CASTING"; ACTION_ID_UNKNOWN = -1;
    end

    WRA:PrintDebug("Display_Icons:OnInitialize() COMPLETE")
end

-- ... The rest of the file remains the same ...
-- The functions CreateMainIconElements, CreateColorBlockElements, CreateDisplayElements,
-- ApplySettings, OnEnable, OnDisable, Show, Hide, ResetPosition, OnModuleSelected,
-- UpdateDisplay, OnProfileChanged, RefreshConfig, and GetOptionsTable
-- do not need changes, as they rely on the corrected data flow from above.

function Display_Icons:CreateMainIconElements()
    if mainIconFrame and mainIconFrame:IsObjectType("Frame") then return end 
    WRA:PrintDebug("Display_Icons: Creating main suggestion icon frames...")

    mainIconFrame = CreateFrame("Frame", "WRA_MultiIconDisplayFrame", UIParent, "BackdropTemplate")
    if not mainIconFrame then
        WRA:PrintError("Display_Icons: CRITICAL - Failed to create mainIconFrame! Suggestion icons will not work.")
        return
    end
    mainIconFrame:SetMovable(true)
    mainIconFrame:EnableMouse(true)
    mainIconFrame:RegisterForDrag("LeftButton")
    mainIconFrame:SetScript("OnDragStart", function(frame) if DB and not DB.locked then frame:StartMoving() end end)
    mainIconFrame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        if DB then
            local frameCenterX, frameCenterY = frame:GetCenter()
            local parentCenterX, parentCenterY = UIParent:GetCenter()
            local uiScale = UIParent:GetEffectiveScale()

            DB.displayPoint = {
                point = "CENTER",
                relativeTo = "UIParent",
                relativePoint = "CENTER",
                x = (frameCenterX - parentCenterX) / uiScale,
                y = (frameCenterY - parentCenterY) / uiScale
            }
            WRA:PrintDebug("Main icon frame position saved relative to UIParent center.")
        end
    end)
    mainIconFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16, 
        insets = { left = 3, right = 3, top = 3, bottom = 3 } 
    })
    mainIconFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
    mainIconFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

    gcdIconSlot.frame = CreateFrame("Frame", "WRA_MultiIconDisplayFrame_GCDIcon", mainIconFrame)
    gcdIconSlot.icon = gcdIconSlot.frame:CreateTexture(nil, "ARTWORK")
    gcdIconSlot.icon:SetAllPoints(true)
    gcdIconSlot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    gcdIconSlot.cooldown = CreateFrame("Cooldown", "WRA_MultiIconDisplayFrame_GCDIconCooldown", gcdIconSlot.frame, "CooldownFrameTemplate")
    gcdIconSlot.cooldown:SetAllPoints(true)
    gcdIconSlot.cooldownText = gcdIconSlot.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gcdIconSlot.cooldownText:SetPoint("CENTER", 0, 0)

    offGcdIconSlot.frame = CreateFrame("Frame", "WRA_MultiIconDisplayFrame_OffGCDIcon", mainIconFrame)
    offGcdIconSlot.icon = offGcdIconSlot.frame:CreateTexture(nil, "ARTWORK")
    offGcdIconSlot.icon:SetAllPoints(true)
    offGcdIconSlot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    offGcdIconSlot.cooldown = CreateFrame("Cooldown", "WRA_MultiIconDisplayFrame_OffGCDIconCooldown", offGcdIconSlot.frame, "CooldownFrameTemplate")
    offGcdIconSlot.cooldown:SetAllPoints(true)
    offGcdIconSlot.cooldownText = offGcdIconSlot.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    offGcdIconSlot.cooldownText:SetPoint("CENTER", 0, 0)

    WRA:PrintDebug("Display_Icons: Main suggestion icon frames created.")
end

function Display_Icons:CreateColorBlockElements()
    if colorBlockContainer and colorBlockContainer:IsObjectType("Frame") then return end 
    WRA:PrintDebug("Display_Icons: Creating color block container and elements...")

    colorBlockContainer = CreateFrame("Frame", "WRA_ColorBlockContainerFrame", UIParent, "BackdropTemplate")
    if not colorBlockContainer then
        WRA:PrintError("Display_Icons: CRITICAL - Failed to create colorBlockContainer! Color blocks will not work.")
        return
    end
    colorBlockContainer:SetMovable(true)
    colorBlockContainer:EnableMouse(true)
    colorBlockContainer:RegisterForDrag("LeftButton")
    colorBlockContainer:SetScript("OnDragStart", function(frame) if DB and not DB.colorBlockContainerLocked then frame:StartMoving() end end)
    colorBlockContainer:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        if DB then
            local frameCenterX, frameCenterY = frame:GetCenter()
            local parentCenterX, parentCenterY = UIParent:GetCenter()
            local uiScale = UIParent:GetEffectiveScale()

            DB.colorBlockContainerPosition = {
                point = "CENTER",
                relativeTo = "UIParent",
                relativePoint = "CENTER",
                x = (frameCenterX - parentCenterX) / uiScale,
                y = (frameCenterY - parentCenterY) / uiScale
            }
            WRA:PrintDebug("Color block container position saved relative to UIParent center.")
        end
    end)
    colorBlockContainer:SetBackdrop({
        bgFile = nil, 
        edgeFile = nil, 
        tile = true, tileSize = 32, edgeSize = 0, 
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    colorBlockContainer:SetBackdropColor(0, 0, 0, 0) 
    colorBlockContainer:SetBackdropBorderColor(0, 0, 0, 0)

    gcdColorBlock = colorBlockContainer:CreateTexture("WRA_ColorBlockContainer_GcdBlock", "BACKGROUND")
    if gcdColorBlock then gcdColorBlock:SetColorTexture(0.3,0.3,0.3,1) else WRA:PrintError("Failed to create gcdColorBlock texture") end

    offGcdColorBlock = colorBlockContainer:CreateTexture("WRA_ColorBlockContainer_OffGcdBlock", "BACKGROUND")
    if offGcdColorBlock then offGcdColorBlock:SetColorTexture(0.3,0.3,0.3,1) else WRA:PrintError("Failed to create offGcdColorBlock texture") end

    WRA:PrintDebug("Display_Icons: Color block container and elements created.")
end

function Display_Icons:CreateDisplayElements() 
    self:CreateMainIconElements()
    self:CreateColorBlockElements()
    self:ApplySettings() 
end

function Display_Icons:ApplySettings()
    if not DB then WRA:PrintError("Display_Icons:ApplySettings - DB is nil!"); return end

    if mainIconFrame and mainIconFrame:IsObjectType("Frame") then
        mainIconFrame:ClearAllPoints()
        local mip = DB.displayPoint
        local uiScale = UIParent:GetEffectiveScale()

        if mip and mip.point == "CENTER" and mip.relativeTo == "UIParent" and mip.relativePoint == "CENTER" then
            mainIconFrame:SetPoint(mip.point, UIParent, mip.relativePoint, mip.x * uiScale, mip.y * uiScale)
        else
            WRA:PrintDebug("ApplySettings: mainIconFrame using fallback positioning due to old DB format or missing data.")
            local relObj = (mip and mip.relativeTo and _G[mip.relativeTo]) or UIParent
            if not (relObj and relObj:IsObjectType("Frame")) then relObj = UIParent end
            mainIconFrame:SetPoint( (mip and mip.point) or "CENTER", relObj, (mip and mip.relativePoint) or "CENTER", (mip and mip.x) or 0, (mip and mip.y) or 150)
        end
        
        mainIconFrame:SetScale(DB.displayScale or 1.0)
        mainIconFrame:SetAlpha(DB.displayAlpha or 1.0)
        mainIconFrame:SetMovable(not DB.locked)
        mainIconFrame:SetBackdropBorderColor(DB.locked and 0.8 or 0.5, DB.locked and 0.2 or 0.5, DB.locked and 0.2 or 0.5, 1)

        local gcdIconSize = DB.iconSize or DEFAULT_ICON_SIZE
        local offGcdIconSize = gcdIconSize * 0.8
        local mainIconFrameInset = 3 

        if gcdIconSlot.frame then gcdIconSlot.frame:SetSize(gcdIconSize, gcdIconSize) end
        if offGcdIconSlot.frame then offGcdIconSlot.frame:SetSize(offGcdIconSize, offGcdIconSize) end

        if DB.showOffGCDSlot then
            if gcdIconSlot.frame then 
                gcdIconSlot.frame:SetPoint("RIGHT", mainIconFrame, "CENTER", -(SLOT_SPACING / 2), 0) 
            end
            if offGcdIconSlot.frame then
                offGcdIconSlot.frame:SetPoint("LEFT", mainIconFrame, "CENTER", (SLOT_SPACING / 2), 0)
                offGcdIconSlot.frame:Show()
            end
            mainIconFrame:SetSize(gcdIconSize + offGcdIconSize + SLOT_SPACING + (mainIconFrameInset*2), gcdIconSize + (mainIconFrameInset*2))
        else
            if gcdIconSlot.frame then gcdIconSlot.frame:SetPoint("CENTER", mainIconFrame, "CENTER", 0, 0) end
            if offGcdIconSlot.frame then offGcdIconSlot.frame:Hide() end
            mainIconFrame:SetSize(gcdIconSize + (mainIconFrameInset*2), gcdIconSize + (mainIconFrameInset*2))
        end
    else
        WRA:PrintDebug("ApplySettings: mainIconFrame not valid.")
    end

    if colorBlockContainer and colorBlockContainer:IsObjectType("Frame") then
        colorBlockContainer:ClearAllPoints()
        local cbcPos = DB.colorBlockContainerPosition
        local uiScale = UIParent:GetEffectiveScale()

        if cbcPos and cbcPos.point == "CENTER" and cbcPos.relativeTo == "UIParent" and cbcPos.relativePoint == "CENTER" then
             colorBlockContainer:SetPoint(cbcPos.point, UIParent, cbcPos.relativePoint, cbcPos.x * uiScale, cbcPos.y * uiScale)
        else
            WRA:PrintDebug("ApplySettings: colorBlockContainer using fallback positioning due to old DB format or missing data.")
            local relObjName = (cbcPos and cbcPos.relativeTo) or "WRA_MultiIconDisplayFrame_GCDIcon"
            local relObj = _G[relObjName]
            if not (relObj and relObj:IsObjectType("Frame")) then relObj = gcdIconSlot.frame or UIParent end
            if not (relObj and relObj:IsObjectType("Frame")) then relObj = UIParent end

            colorBlockContainer:SetPoint( (cbcPos and cbcPos.point) or "TOP", relObj, (cbcPos and cbcPos.relativePoint) or "BOTTOM", (cbcPos and cbcPos.x) or 0, (cbcPos and cbcPos.y) or -5)
        end

        colorBlockContainer:SetMovable(not DB.colorBlockContainerLocked)
        colorBlockContainer:SetBackdropBorderColor(DB.colorBlockContainerLocked and 0.8 or 0.2, DB.colorBlockContainerLocked and 0.2 or 0.2, DB.colorBlockContainerLocked and 0.2 or 0.2, 0)

        local blockW = DB.colorBlockIndividualWidth
        local blockH = DB.colorBlockIndividualHeight
        local spacing = DB.colorBlockSpacing

        if gcdColorBlock then
            gcdColorBlock:SetSize(blockW, blockH)
            gcdColorBlock:ClearAllPoints()
            gcdColorBlock:SetPoint("TOPLEFT", colorBlockContainer, "TOPLEFT", DEFAULT_BACKDROP_INSET, -DEFAULT_BACKDROP_INSET)
        end

        if offGcdColorBlock then
            offGcdColorBlock:SetSize(blockW, blockH)
            offGcdColorBlock:ClearAllPoints()
            if gcdColorBlock then
                offGcdColorBlock:SetPoint("TOPLEFT", gcdColorBlock, "TOPRIGHT", spacing, 0)
            else 
                offGcdColorBlock:SetPoint("TOPLEFT", colorBlockContainer, "TOPLEFT", DEFAULT_BACKDROP_INSET + blockW + spacing, -DEFAULT_BACKDROP_INSET)
            end
        end
        
        colorBlockContainer:SetSize(blockW * 2 + spacing + DEFAULT_BACKDROP_INSET * 2, blockH + DEFAULT_BACKDROP_INSET * 2)

        if DB.showColorBlockGroup then
            colorBlockContainer:Show()
            if gcdColorBlock then if DB.showGcdColorBlock then gcdColorBlock:Show() else gcdColorBlock:Hide() end end
            if offGcdColorBlock then if DB.showOffGcdColorBlock then offGcdColorBlock:Show() else offGcdColorBlock:Hide() end end
        else
            colorBlockContainer:Hide()
        end
    else
        WRA:PrintDebug("ApplySettings: colorBlockContainer not valid.")
    end
    WRA:PrintDebug("Display_Icons: Settings applied.")
end


function Display_Icons:OnEnable()
    WRA:PrintDebug("Display_Icons:OnEnable() START")
    if not C then C = WRA.Constants end
    if not DB then
        if WRA.db and WRA.db.profile and WRA.db.profile.displayIcons then
            DB = WRA.db.profile.displayIcons
        else WRA:PrintError("Display_Icons: Cannot enable, DB is nil!"); return end
    end

    self:CreateDisplayElements()
    
    if WRA.DisplayManager then
        WRA.DisplayManager:RegisterDisplay("Icons", self)
    end
    self:RegisterMessage("AceDB_ProfileChanged", "OnProfileChanged")
    self:Show()
    WRA:PrintDebug("Display_Icons:OnEnable() COMPLETE")
end

function Display_Icons:OnDisable()
    WRA:PrintDebug("Display_Icons:OnDisable()")
    self:Hide()
    self:UnregisterMessage("AceDB_ProfileChanged")
end

function Display_Icons:Show()
    WRA:PrintDebug("Display_Icons:Show()")
    if not mainIconFrame or not mainIconFrame:IsObjectType("Frame") then
        self:CreateDisplayElements() 
    end
    
    if mainIconFrame and mainIconFrame.Show then mainIconFrame:Show() end
    
    if colorBlockContainer and colorBlockContainer.Show then
        if DB and DB.showColorBlockGroup then
            colorBlockContainer:Show()
            if gcdColorBlock then if DB.showGcdColorBlock then gcdColorBlock:Show() else gcdColorBlock:Hide() end end
            if offGcdColorBlock then if DB.showOffGcdColorBlock then offGcdColorBlock:Show() else offGcdColorBlock:Hide() end end
        else
            colorBlockContainer:Hide()
        end
    end
end

function Display_Icons:Hide()
    WRA:PrintDebug("Display_Icons:Hide()")
    if mainIconFrame and mainIconFrame.Hide then mainIconFrame:Hide() end
    if colorBlockContainer and colorBlockContainer.Hide then colorBlockContainer:Hide() end
end

function Display_Icons:ResetPosition()
    WRA:PrintDebug("Display_Icons:ResetPosition()")
    if not DB or not WRA.Utils or not WRA.Utils.GetTableCopy then
        WRA:PrintError("Display_Icons: Cannot ResetPosition - DB or Utils.GetTableCopy missing.")
        return
    end
    local wraDefaults = WRA.db.defaults.profile.displayIcons
    if not wraDefaults then
        WRA:PrintError("Display_Icons: Default settings not found in WRA.db for reset.")
        return
    end

    DB.displayPoint = WRA.Utils:GetTableCopy(wraDefaults.displayPoint)
    DB.colorBlockContainerPosition = WRA.Utils:GetTableCopy(wraDefaults.colorBlockContainerPosition)
    
    self:ApplySettings()
    WRA:Print(L["DISPLAY_POSITION_RESET"] or "Display positions reset.")
end

function Display_Icons:OnModuleSelected() 
    WRA:PrintDebug("Display_Icons:OnModuleSelected()")
    self:ApplySettings()
    if WRA.db and WRA.db.profile and WRA.db.profile.enabled then
        self:Show()
    end
end

function Display_Icons:UpdateDisplay(actionsTable)
    if not C or not DB then return end
    if not mainIconFrame or not (mainIconFrame:IsShown() or (colorBlockContainer and colorBlockContainer:IsShown())) then return end

    actionsTable = actionsTable or {}
    local gcdActionID = actionsTable.gcdAction
    local offGcdActionID = actionsTable.offGcdAction

    local gcdDisplayInfo = GetActionDisplayInfo(gcdActionID)
    if gcdIconSlot.frame and gcdIconSlot.icon then
        gcdIconSlot.icon:SetTexture(gcdDisplayInfo.texture)
        local start, duration = GetSpellCooldown(gcdActionID)
        if duration and duration > 0 and gcdIconSlot.cooldown then
            CooldownFrame_Set(gcdIconSlot.cooldown, start, duration, 1, true)
            if gcdIconSlot.cooldownText then 
                gcdIconSlot.cooldownText:SetText(string_format("%.1f", duration - (GetTime() - start)))
                gcdIconSlot.cooldownText:Show()
            end
        elseif gcdIconSlot.cooldown then
            gcdIconSlot.cooldown:Hide()
            if gcdIconSlot.cooldownText then gcdIconSlot.cooldownText:Hide() end
        end
    end

    if offGcdIconSlot.frame and offGcdIconSlot.icon then
        if DB.showOffGCDSlot and offGcdActionID and offGcdActionID ~= ACTION_ID_IDLE then
            local offGcdDisplayInfo = GetActionDisplayInfo(offGcdActionID)
            offGcdIconSlot.icon:SetTexture(offGcdDisplayInfo.texture)
            local start, duration = GetSpellCooldown(offGcdActionID)
            if duration and duration > 0 and offGcdIconSlot.cooldown then
                CooldownFrame_Set(offGcdIconSlot.cooldown, start, duration, 1, true)
                 if offGcdIconSlot.cooldownText then 
                    offGcdIconSlot.cooldownText:SetText(string_format("%.1f", duration - (GetTime() - start)))
                    offGcdIconSlot.cooldownText:Show()
                end
            elseif offGcdIconSlot.cooldown then
                offGcdIconSlot.cooldown:Hide()
                if offGcdIconSlot.cooldownText then offGcdIconSlot.cooldownText:Hide() end
            end
            offGcdIconSlot.frame:Show()
        else
            offGcdIconSlot.frame:Hide()
        end
    end

    if colorBlockContainer and colorBlockContainer:IsShown() then
        local defaultColor = {r=0.2,g=0.2,b=0.2,a=1} 

        if gcdColorBlock and gcdColorBlock:IsShown() then
            local color = gcdDisplayInfo.color
            gcdColorBlock:SetColorTexture(color.r, color.g, color.b, 1)
        end
        if offGcdColorBlock and offGcdColorBlock:IsShown() then
            local offGcdDisplayInfo = GetActionDisplayInfo(offGcdActionID)
            local color = offGcdDisplayInfo.color
            offGcdColorBlock:SetColorTexture(color.r, color.g, color.b, 1)
        end
    end
end

function Display_Icons:OnProfileChanged(message, dbObject, newProfileKey)
    WRA:PrintDebug("Display_Icons:OnProfileChanged - Message: " .. message .. ", Profile changed to: " .. tostring(newProfileKey))
    if message == "AceDB_ProfileChanged" and dbObject == WRA.db then
        if WRA.db.profile and WRA.db.profile.displayIcons then
            DB = WRA.db.profile.displayIcons 
            
            local diDefaults = WRA.db.defaults.profile.displayIcons
            if not diDefaults then WRA:PrintError("Display_Icons:OnProfileChanged - Cannot find WRA default DB settings!"); return end

            if DB.displayPoint == nil then DB.displayPoint = WRA.Utils:GetTableCopy(diDefaults.displayPoint) end
            if type(DB.displayPoint.x) ~= "number" then DB.displayPoint = WRA.Utils:GetTableCopy(diDefaults.displayPoint) end

            if DB.locked == nil then DB.locked = diDefaults.locked end
            if DB.displayScale == nil then DB.displayScale = diDefaults.displayScale end
            if DB.displayAlpha == nil then DB.displayAlpha = diDefaults.displayAlpha end
            if DB.showOffGCDSlot == nil then DB.showOffGCDSlot = diDefaults.showOffGCDSlot end
            if DB.iconSize == nil then DB.iconSize = diDefaults.iconSize end
            if DB.showColorBlockGroup == nil then DB.showColorBlockGroup = diDefaults.showColorBlockGroup end
            
            if DB.colorBlockContainerPosition == nil then DB.colorBlockContainerPosition = WRA.Utils:GetTableCopy(diDefaults.colorBlockContainerPosition) end
            if type(DB.colorBlockContainerPosition.x) ~= "number" then DB.colorBlockContainerPosition = WRA.Utils:GetTableCopy(diDefaults.colorBlockContainerPosition) end

            if DB.colorBlockContainerLocked == nil then DB.colorBlockContainerLocked = diDefaults.colorBlockContainerLocked end
            if DB.colorBlockIndividualWidth == nil then DB.colorBlockIndividualWidth = diDefaults.colorBlockIndividualWidth end
            if DB.colorBlockIndividualHeight == nil then DB.colorBlockIndividualHeight = diDefaults.colorBlockIndividualHeight end
            if DB.colorBlockSpacing == nil then DB.colorBlockSpacing = diDefaults.colorBlockSpacing end
            if DB.showGcdColorBlock == nil then DB.showGcdColorBlock = diDefaults.showGcdColorBlock end
            if DB.showOffGcdColorBlock == nil then DB.showOffGcdColorBlock = diDefaults.showOffGcdColorBlock end

            self:ApplySettings()
            WRA:PrintDebug("Display_Icons: Profile settings re-applied after AceDB_ProfileChanged.")
        else
            WRA:PrintError("Display_Icons:OnProfileChanged - Invalid database structure after profile change.")
        end
    end
end

function Display_Icons:RefreshConfig() 
    WRA:PrintDebug("Display_Icons:RefreshConfig()")
    if WRA.db and WRA.db.profile and WRA.db.profile.displayIcons then
        DB = WRA.db.profile.displayIcons
        self:ApplySettings()
    else
        WRA:PrintError("Display_Icons:RefreshConfig - DB not available.")
    end
end

function Display_Icons:GetOptionsTable()
    if not L then L = LibStub("AceLocale-3.0"):GetLocale(addonName, true) end
    if not DB then
        WRA:PrintDebug("Display_Icons:GetOptionsTable - DB is nil, attempting to re-fetch.")
        if WRA.db and WRA.db.profile and WRA.db.profile.displayIcons then
            DB = WRA.db.profile.displayIcons
        else
            WRA:PrintError("Display_Icons:GetOptionsTable - DB still nil, returning empty options.")
            return {}
        end
    end

    return {
        type = "group",
        name = L["ICON_DISPLAY_SETTINGS_HEADER"] or "Icon Display Settings",
        args = {
            generalIconSettings = {
                order = 1, type = "group", inline = true, name = L["MAIN_ICON_SETTINGS_HEADER"] or "Main Suggestion Icons",
                args = {
                    locked = {
                        order = 1, type = "toggle", name = L["LOCK_MAIN_ICONS_NAME"] or "Lock Main Icons Position",
                        desc = L["LOCK_MAIN_ICONS_DESC"] or "Lock the position of the main suggestion icons.",
                        get = function() return DB.locked end,
                        set = function(info, val) DB.locked = val; self:ApplySettings() end,
                    },
                    displayScale = {
                        order = 2, type = "range", name = L["MAIN_ICONS_SCALE_NAME"] or "Main Icons Scale",
                        desc = L["MAIN_ICONS_SCALE_DESC"] or "Adjust the size of the main suggestion icons.",
                        min = 0.5, max = 2, step = 0.05,
                        get = function() return DB.displayScale end,
                        set = function(info, val) DB.displayScale = val; self:ApplySettings() end,
                    },
                    displayAlpha = {
                        order = 3, type = "range", name = L["MAIN_ICONS_ALPHA_NAME"] or "Main Icons Alpha",
                        desc = L["MAIN_ICONS_ALPHA_DESC"] or "Adjust the transparency of the main suggestion icons.",
                        min = 0.1, max = 1, step = 0.05,
                        get = function() return DB.displayAlpha end,
                        set = function(info, val) DB.displayAlpha = val; self:ApplySettings() end,
                    },
                    iconSize = {
                        order = 4, type = "range", name = L["GCD_ICON_SIZE_NAME"] or "GCD Icon Size",
                        desc = L["GCD_ICON_SIZE_DESC"] or "Size of the main GCD suggestion icon (OffGCD icon scales relatively).",
                        min = 20, max = 80, step = 1,
                        get = function() return DB.iconSize end,
                        set = function(info, val) DB.iconSize = val; self:ApplySettings() end,
                    },
                    showOffGCDSlot = {
                        order = 5, type = "toggle", name = L["SHOW_OFFGCD_ICON_SLOT_NAME"] or "Show Off-GCD Icon Slot",
                        desc = L["SHOW_OFFGCD_ICON_SLOT_DESC"] or "Show a separate icon slot for Off-GCD suggestions.",
                        get = function() return DB.showOffGCDSlot end,
                        set = function(info, val) DB.showOffGCDSlot = val; self:ApplySettings() end,
                    },
                     resetMainIconsPos = {
                        order = 10, type = "execute", name = L["RESET_MAIN_ICONS_POS_NAME"] or "Reset Main Icons Position",
                        func = function() self:ResetPosition() end,
                    },
                }
            },
            colorBlockSettings = {
                order = 2, type = "group", inline = true, name = L["COLOR_BLOCK_GROUP_SETTINGS_HEADER"] or "Color Block Group",
                args = {
                    showColorBlockGroup = {
                        order = 1, type = "toggle", name = L["SHOW_COLOR_BLOCK_GROUP_NAME"] or "Show Color Block Group",
                        desc = L["SHOW_COLOR_BLOCK_GROUP_DESC"] or "Show the pair of color blocks.",
                        get = function() return DB.showColorBlockGroup end,
                        set = function(info, val) DB.showColorBlockGroup = val; self:ApplySettings() end,
                    },
                    colorBlockContainerLocked = {
                        order = 2, type = "toggle", name = L["LOCK_COLOR_BLOCK_CONTAINER_NAME"] or "Lock Color Blocks Position",
                        desc = L["LOCK_COLOR_BLOCK_CONTAINER_DESC"] or "Lock the position of the color block container.",
                        get = function() return DB.colorBlockContainerLocked end,
                        set = function(info, val) DB.colorBlockContainerLocked = val; self:ApplySettings() end,
                        disabled = function() return not DB.showColorBlockGroup end,
                    },
                    colorBlockIndividualWidth = {
                        order = 3, type = "range", name = L["COLOR_BLOCK_WIDTH_NAME"] or "Color Block Width",
                        desc = L["COLOR_BLOCK_WIDTH_DESC"] or "Width of each individual color block.",
                        min = 10, max = 100, step = 1,
                        get = function() return DB.colorBlockIndividualWidth end,
                        set = function(info, val) DB.colorBlockIndividualWidth = val; self:ApplySettings() end,
                        disabled = function() return not DB.showColorBlockGroup end,
                    },
                    colorBlockIndividualHeight = {
                        order = 4, type = "range", name = L["COLOR_BLOCK_HEIGHT_NAME"] or "Color Block Height",
                        desc = L["COLOR_BLOCK_HEIGHT_DESC"] or "Height of each individual color block.",
                        min = 2, max = 50, step = 1,
                        get = function() return DB.colorBlockIndividualHeight end,
                        set = function(info, val) DB.colorBlockIndividualHeight = val; self:ApplySettings() end,
                        disabled = function() return not DB.showColorBlockGroup end,
                    },
                    colorBlockSpacing = {
                        order = 5, type = "range", name = L["COLOR_BLOCK_SPACING_NAME"] or "Spacing Between Blocks",
                        desc = L["COLOR_BLOCK_SPACING_DESC"] or "Spacing between the GCD and Off-GCD color blocks.",
                        min = 0, max = 20, step = 1,
                        get = function() return DB.colorBlockSpacing end,
                        set = function(info, val) DB.colorBlockSpacing = val; self:ApplySettings() end,
                        disabled = function() return not DB.showColorBlockGroup end,
                    },
                    showGcdColorBlockIndividual = {
                        order = 6, type = "toggle", name = L["SHOW_GCD_BLOCK_INDIV_NAME"] or "Show GCD Block",
                        desc = L["SHOW_GCD_BLOCK_INDIV_DESC"] or "Specifically show the GCD color block (if group is shown).",
                        get = function() return DB.showGcdColorBlock end,
                        set = function(info, val) DB.showGcdColorBlock = val; self:ApplySettings() end,
                        disabled = function() return not DB.showColorBlockGroup end,
                    },
                    showOffGcdColorBlockIndividual = {
                        order = 7, type = "toggle", name = L["SHOW_OFFGCD_BLOCK_INDIV_NAME"] or "Show Off-GCD Block",
                        desc = L["SHOW_OFFGCD_BLOCK_INDIV_DESC"] or "Specifically show the Off-GCD color block (if group is shown).",
                        get = function() return DB.showOffGcdColorBlock end,
                        set = function(info, val) DB.showOffGcdColorBlock = val; self:ApplySettings() end,
                        disabled = function() return not DB.showColorBlockGroup end,
                    },
                    resetColorBlocksPos = {
                        order = 10, type = "execute", name = L["RESET_COLOR_BLOCKS_POS_NAME"] or "Reset Color Blocks Position",
                        func = function() self:ResetPosition() end,
                        disabled = function() return not DB.showColorBlockGroup end,
                    },
                }
            }
        }
    }
end
