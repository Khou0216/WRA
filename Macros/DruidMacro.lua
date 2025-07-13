-- File: Addon/WRA/Macros/DruidMacro.lua
-- Description: Standalone script that creates Feral Druid-specific macros and keybindings on login for external program integration.
-- MODIFIED: Corrected all instances of "毁灭" to the proper term "撕碎 (Shred)".

-- Create a frame to handle events. It doesn't need to be visible.
local f = CreateFrame("Frame")

-- Register for the PLAYER_LOGIN event. This ensures the player's character data is fully loaded.
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- IMPORTANT: Only run this code if the player is a Druid.
        local _, class = UnitClass("player")
        if class ~= "DRUID" then
            return -- Exit immediately if the player is not a Druid.
        end

        print("WRA: Loading Feral Druid External Keybind Macros...")

        local MacroButton -- Re-usable variable for creating frames

        -- ===================================================================
        -- ==                  Off-GCD ABILITIES (AHK OffGCDList)           ==
        -- ===================================================================
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_TigersFury", UIParent, "SecureActionButtonTemplate"); 
        MacroButton:SetAttribute("type", "macro"); 
        MacroButton:SetAttribute("macrotext", "/cast 猛虎之怒"); 
        SetBinding("NUMPAD3", "CLICK WRA_ExtBind_Druid_TigersFury:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_Enrage", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro"); 
        MacroButton:SetAttribute("macrotext", "/cast 激怒"); 
        SetBinding("NUMPAD0", "CLICK WRA_ExtBind_Druid_Enrage:LeftButton")
        

        -- ===================================================================
        -- ==                  GCD ABILITIES (AHK GCDList)                  ==
        -- ===================================================================
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_Shred", UIParent, "SecureActionButtonTemplate"); 
        MacroButton:SetAttribute("type", "macro"); 
        MacroButton:SetAttribute("macrotext", "/cast 撕碎"); 
        SetBinding("NUMPAD1", "CLICK WRA_ExtBind_Druid_Shred:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_Mangle", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro"); 
        MacroButton:SetAttribute("macrotext", "/cast 裂伤（豹）")
        SetBinding("NUMPAD2", "CLICK WRA_ExtBind_Druid_Mangle:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_Rip", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/cast 割裂");
        SetBinding("NUMPAD5", "CLICK WRA_ExtBind_Druid_Rip:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_SavageRoar", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/cast 野蛮咆哮");
        SetBinding("NUMPAD6", "CLICK WRA_ExtBind_Druid_SavageRoar:LeftButton")
        
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_Rake", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/cast 斜掠");
        SetBinding("NUMPAD8", "CLICK WRA_ExtBind_Druid_Rake:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_FaerieFire", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/cast 精灵之火（野性）");
        SetBinding("NUMPAD7", "CLICK WRA_ExtBind_Druid_FaerieFire:LeftButton")
        
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_Berserk", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/cast 狂暴");
        SetBinding("CTRL-NUMPAD1", "CLICK WRA_ExtBind_Druid_Berserk:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Druid_FerociousBite", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/cast 凶猛撕咬");
        SetBinding("CTRL-NUMPAD3", "CLICK WRA_ExtBind_Druid_FerociousBite:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD4", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/CAST 横扫（豹）"); SetBinding("CTRL-NUMPAD4", "CLICK WRA_ExtBind_CTRL_NUMPAD4:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD2", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 割伤"); SetBinding("CTRL-NUMPAD2", "CLICK WRA_ExtBind_CTRL_NUMPAD2:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD6", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 裂伤（熊）"); SetBinding("CTRL-NUMPAD6", "CLICK WRA_ExtBind_CTRL_NUMPAD6:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD7", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast [nostance:3]!猎豹形态(变形)"); SetBinding("CTRL-NUMPAD7", "CLICK WRA_ExtBind_CTRL_NUMPAD7:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD8", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast [nostance:1]!巨熊形态(变形)"); SetBinding("CTRL-NUMPAD8", "CLICK WRA_ExtBind_CTRL_NUMPAD8:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD9", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 横扫（熊） "); SetBinding("CTRL-NUMPAD9", "CLICK WRA_ExtBind_CTRL_NUMPAD9:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD5", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 重殴"); SetBinding("CTRL-NUMPAD5", "CLICK WRA_ExtBind_CTRL_NUMPAD5:LeftButton")
        
        print("WRA: Feral Druid External Macros and Bindings created successfully.")
        -- Unregister the event after it runs to prevent it from running again.
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
