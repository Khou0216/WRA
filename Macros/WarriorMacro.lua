-- File: Addon/WRA/Core/Macros_Warrior.lua
-- Description: Standalone script that creates Warrior-specific macros and keybindings on login for external program integration.
-- MODIFIED: Fully synchronized with the final AHK script and color/keybinding specification.

-- Create a frame to handle events. It doesn't need to be visible.
local f = CreateFrame("Frame")

-- Register for the PLAYER_LOGIN event. This ensures the player's character data is fully loaded.
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- IMPORTANT: Only run this code if the player is a Warrior.
        local _, class = UnitClass("player")
        if class ~= "WARRIOR" then
            return -- Exit immediately if the player is not a Warrior.
        end

        print("WRA: Loading Warrior External Keybind Macros...")

        local MacroButton -- Re-usable variable for creating frames

        -- ===================================================================
        -- ==                   CORE ROTATION ABILITIES                     ==
        -- ===================================================================
        -- NUMPAD 1-9, 0
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD1", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 嗜血"); SetBinding("NUMPAD1", "CLICK WRA_ExtBind_NUMPAD1:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD2", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 旋风斩"); SetBinding("NUMPAD2", "CLICK WRA_ExtBind_NUMPAD2:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD3", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 英勇打击"); SetBinding("NUMPAD3", "CLICK WRA_ExtBind_NUMPAD3:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD4", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 顺劈斩"); SetBinding("NUMPAD4", "CLICK WRA_ExtBind_NUMPAD4:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD5", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 斩杀"); SetBinding("NUMPAD5", "CLICK WRA_ExtBind_NUMPAD5:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD6", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 猛击"); SetBinding("NUMPAD6", "CLICK WRA_ExtBind_NUMPAD6:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD7", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 英勇投掷"); SetBinding("NUMPAD7", "CLICK WRA_ExtBind_NUMPAD7:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD8", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 撕裂"); SetBinding("NUMPAD8", "CLICK WRA_ExtBind_NUMPAD8:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD9", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 压制"); SetBinding("NUMPAD9", "CLICK WRA_ExtBind_NUMPAD9:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_NUMPAD0", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 拳击"); SetBinding("NUMPAD0", "CLICK WRA_ExtBind_NUMPAD0:LeftButton")

        -- ===================================================================
        -- ==                  MAJOR COOLDOWNS (CTRL)                       ==
        -- ===================================================================
        -- CTRL + NUMPAD 1-9
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD1", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 鲁莽"); SetBinding("CTRL-NUMPAD1", "CLICK WRA_ExtBind_CTRL_NUMPAD1:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD2", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 死亡之愿"); SetBinding("CTRL-NUMPAD2", "CLICK WRA_ExtBind_CTRL_NUMPAD2:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD3", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 狂暴之怒"); SetBinding("CTRL-NUMPAD3", "CLICK WRA_ExtBind_CTRL_NUMPAD3:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD4", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 碎裂投掷"); SetBinding("CTRL-NUMPAD4", "CLICK WRA_ExtBind_CTRL_NUMPAD4:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD5", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 血性狂暴"); SetBinding("CTRL-NUMPAD5", "CLICK WRA_ExtBind_CTRL_NUMPAD5:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD6", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 盾牌猛击"); SetBinding("CTRL-NUMPAD6", "CLICK WRA_ExtBind_CTRL_NUMPAD6:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD7", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 复仇"); SetBinding("CTRL-NUMPAD7", "CLICK WRA_ExtBind_CTRL_NUMPAD7:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD8", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 毁灭打击"); SetBinding("CTRL-NUMPAD8", "CLICK WRA_ExtBind_CTRL_NUMPAD8:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_NUMPAD9", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 震荡波"); SetBinding("CTRL-NUMPAD9", "CLICK WRA_ExtBind_CTRL_NUMPAD9:LeftButton")

        -- ===================================================================
        -- ==                       STANCES & SHOUTS (ALT)                  ==
        -- ===================================================================
        -- ALT + NUMPAD 1-5
        MacroButton = CreateFrame("Button", "WRA_ExtBind_ALT_NUMPAD1", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 战斗姿态"); SetBinding("ALT-NUMPAD1", "CLICK WRA_ExtBind_ALT_NUMPAD1:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_ALT_NUMPAD2", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 狂暴姿态"); SetBinding("ALT-NUMPAD2", "CLICK WRA_ExtBind_ALT_NUMPAD2:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_ALT_NUMPAD3", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 防御姿态"); SetBinding("ALT-NUMPAD3", "CLICK WRA_ExtBind_ALT_NUMPAD3:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_ALT_NUMPAD4", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 战斗怒吼"); SetBinding("ALT-NUMPAD4", "CLICK WRA_ExtBind_ALT_NUMPAD4:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_ALT_NUMPAD5", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 命令怒吼"); SetBinding("ALT-NUMPAD5", "CLICK WRA_ExtBind_ALT_NUMPAD5:LeftButton")
    
        -- ===================================================================
        -- ==                  SURVIVAL & UTILITY (SHIFT)                   ==
        -- ===================================================================
        -- SHIFT + NUMPAD 1-4
        MacroButton = CreateFrame("Button", "WRA_ExtBind_ALT_NUMPAD6", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 盾墙"); SetBinding("ALT-NUMPAD6", "CLICK WRA_ExtBind_ALT_NUMPAD6:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_ALT_NUMPAD7", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 破釜沉舟"); SetBinding("ALT-NUMPAD7", "CLICK WRA_ExtBind_ALT_NUMPAD7:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_ALT_NUMPAD8", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 盾牌格挡"); SetBinding("ALT-NUMPAD8", "CLICK WRA_ExtBind_ALT_NUMPAD8:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_ALT_NUMPAD9", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 雷霆一击"); SetBinding("ALT-NUMPAD9", "CLICK WRA_ExtBind_ALT_NUMPAD9:LeftButton")

        -- SHIFT + ALT + NUMPAD 1-2
        MacroButton = CreateFrame("Button", "WRA_ExtBind_SHIFT_ALT_NUMPAD1", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 盾击"); SetBinding("SHIFT-ALT-NUMPAD1", "CLICK WRA_ExtBind_SHIFT_ALT_NUMPAD1:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_SHIFT_ALT_NUMPAD2", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 横扫攻击"); SetBinding("SHIFT-ALT-NUMPAD2", "CLICK WRA_ExtBind_SHIFT_ALT_NUMPAD2:LeftButton")
        
        -- ===================================================================
        -- ==                       GENERAL & CONSUMABLES (CTRL+ALT)          ==
        -- ===================================================================
        -- CTRL + ALT + NUMPAD 1-3
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_ALT_NUMPAD1", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 血性狂怒(种族特长)\n/cast 狂暴(种族特长)"); SetBinding("CTRL-ALT-NUMPAD1", "CLICK WRA_ExtBind_CTRL_ALT_NUMPAD1:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_F4", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 反击风暴"); SetBinding("CTRL-F4", "CLICK WRA_ExtBind_CTRL_F4:LeftButton")
        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_F5", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/cast 破甲攻击"); SetBinding("CTRL-F5", "CLICK WRA_ExtBind_CTRL_F5:LeftButton")
        MacroButton = CreateFrame("Button", "CF3", UIParent, "SecureActionButtonTemplate");
        MacroButton:SetAttribute("type", "macro")
        MacroButton:SetAttribute("macrotext", "/use 速度药水")
        SetBinding("CTRL-F3", "CLICK CF3:LeftButton")

        MacroButton = CreateFrame("Button", "WRA_ExtBind_CTRL_ALT_NUMPAD3", UIParent, "SecureActionButtonTemplate"); MacroButton:SetAttribute("type", "macro"); MacroButton:SetAttribute("macrotext", "/startattack"); SetBinding("CTRL-SHIFT-NUMPAD3", "CLICK WRA_ExtBind_CTRL_ALT_NUMPAD3:LeftButton")
        
        print("WRA: Warrior External Macros and Bindings created successfully.")

        -- Unregister the event after it runs to prevent it from running again.
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
