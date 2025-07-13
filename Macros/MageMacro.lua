-- File: Addon/WRA/Macros/MageMacro.lua
-- Description: Standalone script that creates Mage-specific macros and keybindings on login for external program integration.

-- Create a frame to handle events. It doesn't need to be visible.
local f = CreateFrame("Frame")

-- Register for the PLAYER_LOGIN event. This ensures the player's character data is fully loaded.
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- IMPORTANT: Only run this code if the player is a Mage.
        local _, class = UnitClass("player")
        if class ~= "MAGE" then
            return -- Exit immediately if the player is not a Mage.
        end

        print("WRA: Loading Mage External Keybind Macros...")

        local MacroButton -- Re-usable variable for creating frames

        -- ===================================================================
        -- ==                  GCD ABILITIES (AHK GCDList)                  ==
        -- ===================================================================
        
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Mage_Fireball", UIParent, "SecureActionButtonTemplate"); 
        MacroButton:SetAttribute("type", "macro"); 
        MacroButton:SetAttribute("macrotext", "/cast 火球术"); 
        SetBinding("NUMPAD1", "CLICK WRA_ExtBind_Mage_Fireball:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Mage_Pyroblast", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro"); 
        MacroButton:SetAttribute("macrotext", "/cast 炎爆术")
        SetBinding("NUMPAD2", "CLICK WRA_ExtBind_Mage_Pyroblast:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Mage_LivingBomb", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/cast 活动炸弹");
        SetBinding("NUMPAD5", "CLICK WRA_ExtBind_Mage_LivingBomb:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Mage_FireBlast", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/cast 火焰冲击");
        SetBinding("NUMPAD6", "CLICK WRA_ExtBind_Mage_FireBlast:LeftButton")
        
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Mage_Scorch", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/cast 灼烧");
        SetBinding("NUMPAD8", "CLICK WRA_ExtBind_Mage_Scorch:LeftButton")

        -- Cooldowns
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Mage_Combustion", UIParent, "SecureActionButtonTemplate"); 
        MacroButton:SetAttribute("type", "macro"); 
        MacroButton:SetAttribute("macrotext", "/cast 燃烧"); 
        SetBinding("CTRL-NUMPAD1", "CLICK WRA_ExtBind_Mage_Combustion:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Mage_MirrorImage", UIParent, "SecureActionButtonTemplate"); 
        MacroButton:SetAttribute("type", "macro"); 
        MacroButton:SetAttribute("macrotext", "/cast 镜像"); 
        SetBinding("CTRL-NUMPAD2", "CLICK WRA_ExtBind_Mage_MirrorImage:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Mage_DragonsBreath", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro"); 
        MacroButton:SetAttribute("macrotext", "/cast 龙息术"); 
        SetBinding("CTRL-NUMPAD3", "CLICK WRA_ExtBind_Mage_DragonsBreath:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_Mage_ManaGem", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro");
        MacroButton:SetAttribute("macrotext", "/use 法力宝石");
        SetBinding("CTRL-NUMPAD4", "CLICK WRA_ExtBind_Mage_ManaGem:LeftButton")
        
        print("WRA: Mage External Macros and Bindings created successfully.")

        -- Unregister the event after it runs to prevent it from running again.
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
