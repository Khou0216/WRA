-- File: Addon/WRA/Macros/PaladinMacro.lua
-- Description: Standalone script that creates Paladin-specific macros and keybindings on login for external program integration.
-- MODIFIED: Fully corrected to ensure a 1-to-1 mapping between a skill, a color, a keybind, and a macro, removing all multi-skill macros to prevent conflicts and ambiguity.

-- Create a frame to handle events. It doesn't need to be visible.
local f = CreateFrame("Frame")

-- Register for the PLAYER_LOGIN event. This ensures the player's character data is fully loaded.
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- IMPORTANT: Only run this code if the player is a Paladin.
        local _, class = UnitClass("player")
        if class ~= "PALADIN" then
            return -- Exit immediately if the player is not a Paladin.
        end

        print("WRA: Loading Paladin External Keybind Macros...")

        local MacroButton -- Re-usable variable for creating frames


        -- ===================================================================
        -- ==                  Off-GCD ABILITIES (AHK OffGCDList)           ==
        -- ===================================================================
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_AvengingWrath", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 复仇之怒"); SetBinding("NUMPAD3", "CLICK WRA_ExtBind_Pala_AvengingWrath:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_HandOfReckoning", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 清算之手"); SetBinding("NUMPAD4", "CLICK WRA_ExtBind_Pala_HandOfReckoning:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_DivineProtection", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 圣佑术"); SetBinding("NUMPAD0", "CLICK WRA_ExtBind_Pala_DivineProtection:LeftButton")

        -- ===================================================================
        -- ==                  GCD ABILITIES (AHK GCDList)                  ==
        -- ===================================================================
        
        -- Protection Skills
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_ShieldOfRighteousness", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 正义盾击"); SetBinding("NUMPAD1", "CLICK WRA_ExtBind_Pala_ShieldOfRighteousness:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_HammerOfTheRighteous", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 正义之锤"); SetBinding("NUMPAD2", "CLICK WRA_ExtBind_Pala_HammerOfTheRighteous:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_AvengersShield", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 复仇者之盾"); SetBinding("NUMPAD5", "CLICK WRA_ExtBind_Pala_AvengersShield:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_HolyShield", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 神圣之盾"); SetBinding("NUMPAD6", "CLICK WRA_ExtBind_Pala_HolyShield:LeftButton")
        
        -- Retribution Skills
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_CrusaderStrike", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 十字军打击"); SetBinding("CTRL-NUMPAD1", "CLICK WRA_ExtBind_Pala_CrusaderStrike:LeftButton") -- Using a new keybind to avoid conflict
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_DivineStorm", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 神圣风暴"); SetBinding("CTRL-NUMPAD2", "CLICK WRA_ExtBind_Pala_DivineStorm:LeftButton") -- Using a new keybind
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_HammerOfWrath", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 愤怒之锤"); SetBinding("CTRL-NUMPAD3", "CLICK WRA_ExtBind_Pala_HammerOfWrath:LeftButton") -- Using a new keybind
        
        -- Shared Paladin Skills
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_Exorcism", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 驱邪术"); SetBinding("NUMPAD8", "CLICK WRA_ExtBind_Pala_Exorcism:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_JudgementOfWisdom", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 智慧审判"); SetBinding("NUMPAD9", "CLICK WRA_ExtBind_Pala_JudgementOfWisdom:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_JudgementOfLight", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 圣光审判"); SetBinding("CTRL-NUMPAD6", "CLICK WRA_ExtBind_Pala_JudgementOfLight:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD4", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 神圣恳求"); SetBinding("CTRL-NUMPAD4", "CLICK WRA_ExtBind_CTRL_NUMPAD4:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_HammerOfJustice", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 制裁之锤"); SetBinding("CTRL-NUMPAD9", "CLICK WRA_ExtBind_Pala_HammerOfJustice:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_Consecration", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 奉献"); SetBinding("ALT-NUMPAD1", "CLICK WRA_ExtBind_Pala_Consecration:LeftButton") -- Assigning a new keybind

        -- Auras, Seals
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_SealVengeance", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 复仇圣印\n/cast 腐蚀圣印"); SetBinding("ALT-NUMPAD2", "CLICK WRA_ExtBind_Pala_SealVengeance:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_SealCommand", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 命令圣印"); SetBinding("ALT-NUMPAD3", "CLICK WRA_ExtBind_Pala_SealCommand:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_Pala_RighteousFury", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 正义之怒"); SetBinding("ALT-NUMPAD4", "CLICK WRA_ExtBind_Pala_RighteousFury:LeftButton")
        
        print("WRA: Paladin External Macros and Bindings created successfully.")

        -- Unregister the event after it runs to prevent it from running again.
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
