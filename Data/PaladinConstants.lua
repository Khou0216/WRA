-- WRA/Data/PaladinConstants.lua
-- Contains all constants specific to the Paladin class for WotLK.
-- MODIFIED: Fully corrected to ensure a 1-to-1 mapping between a skill, a color, a keybind, and a macro, removing all multi-skill macros to prevent conflicts and ambiguity.
-- This version aligns with the corrected PaladinMacro.lua where each skill has a unique keybind.

local addonName, _ = ...
local WRA = LibStub("AceAddon-3.0"):GetAddon(addonName)
if not WRA then return end

WRA.ClassConstants = WRA.ClassConstants or {}

WRA.ClassConstants.Paladin = {
    Spells = {
        -- Protection Core
        HAMMER_OF_THE_RIGHTEOUS = 53595, -- 正义之锤
        SHIELD_OF_RIGHTEOUSNESS = 61411, -- 正义盾击
        HOLY_SHIELD = 48952,             -- 神圣之盾
        AVENGERS_SHIELD = 48827,         -- 复仇者之盾
        
        -- Retribution Core
        CRUSADER_STRIKE = 35395,         -- 十字军打击
        DIVINE_STORM = 53385,            -- 神圣风暴
        CONSECRATION = 48819,            -- 奉献
        EXORCISM = 48801,                -- 驱邪术
        HAMMER_OF_WRATH = 48806,         -- 愤怒之锤
        
        -- Judgements
        JUDGEMENT_OF_WISDOM = 53408,     -- 智慧审判
        JUDGEMENT_OF_LIGHT = 20271,      -- 圣光审判

        -- Utility & Survival
        DIVINE_PROTECTION = 498,         -- 圣佑术
        DIVINE_PLEA = 54428,             -- 神圣恳求
        AVENGING_WRATH = 31884,          -- 复仇之怒
        HAND_OF_RECKONING = 62124,       -- 清算之手 (嘲讽)
        HAMMER_OF_JUSTICE = 10308,       -- 制裁之锤
        
        -- Auras & Seals
        RIGHTEOUS_FURY = 25780,          -- 正义之怒
        SEAL_OF_VENGEANCE = 31801,       -- 复仇圣印 (联盟)
        SEAL_OF_CORRUPTION = 53736,      -- 腐蚀圣印 (部落)
        SEAL_OF_COMMAND = 20375,         -- 命令圣印
    },
    Auras = {
        -- Buffs
        HOLY_SHIELD_BUFF = 48952,
        ART_OF_WAR_PROC = 59578,         -- 战争艺术
        RIGHTEOUS_FURY_BUFF = 25780,
        AVENGING_WRATH_BUFF = 31884,
        DIVINE_PLEA_BUFF = 54428,
        SEAL_OF_VENGEANCE_BUFF = 31801,
        SEAL_OF_CORRUPTION_BUFF = 53736,
        SEAL_OF_COMMAND_BUFF = 20375,
        -- Debuffs
        JUDGEMENT_OF_WISDOM_DEBUFF = 20186,
        JUDGEMENT_OF_LIGHT_DEBUFF = 20185,
        SEAL_OF_VENGEANCE_DEBUFF = 31803,
    },
    
    SpellData = {
        -- Off-GCD Abilities
        [31884] = { isOffGCD = true }, -- 复仇之怒
        [62124] = { isOffGCD = true }, -- 清算之手
        [498]   = { isOffGCD = true }, -- 圣佑术
        
        -- Retribution spells are on GCD
        [35395] = { isOffGCD = false }, -- 十字军打击
        [53385] = { isOffGCD = false }, -- 神圣风暴
        [48806] = { isOffGCD = false }, -- 愤怒之锤
        
    },

    ActionColors = {
        -- == Off-GCD Mappings (matches AHK OffGCDList) ==
        [31884] = {r = 0.1, g = 0.7, b = 0.1, a = 1.0},   -- 复仇之怒 -> NUMPAD3 (Heroic Strike color)
        [62124] = {r = 0.1, g = 0.5, b = 0.5, a = 1.0},   -- 清算之手 -> NUMPAD4 (Cleave color)
        [498]   = {r = 0.8, g = 0.8, b = 0.8, a = 1.0},   -- 圣佑术 -> NUMPAD0 (Pummel color)

        -- == GCD Mappings (matches AHK GCDList) ==
        -- Protection Skills
        [61411] = {r = 0.8, g = 0.1, b = 0.1, a = 1.0},   -- 正义盾击 -> NUMPAD1 (Bloodthirst color)
        [53595] = {r = 0.9, g = 0.6, b = 0.2, a = 1.0},   -- 正义之锤 -> NUMPAD2 (Whirlwind color)
        [48827] = {r = 0.4, g = 0.0, b = 0.0, a = 1.0},   -- 复仇者之盾 -> NUMPAD5 (Execute color)
        [48952] = {r = 0.6, g = 0.8, b = 0.2, a = 1.0},   -- 神圣之盾 -> NUMPAD6 (Slam color)
        [10308] = {r = 0.8, g = 0.5, b = 0.2, a = 1.0},   -- 制裁之锤 -> CTRL-NUMPAD9 (Shockwave color)
        
        -- Retribution Skills (Using new keybinds from the corrected macro file)
        [35395] = {r = 1.0, g = 0.0, b = 0.5, a = 1.0},   -- 十字军打击 -> CTRL-NUMPAD1 (Recklessness color)
        [53385] = {r = 0.6, g = 0.0, b = 0.6, a = 1.0},   -- 神圣风暴 -> CTRL-NUMPAD2 (Death Wish color)
        [48806] = {r = 1.0, g = 0.3, b = 0.0, a = 1.0},   -- 愤怒之锤 -> CTRL-NUMPAD3 (Berserker Rage color)
        
        -- Shared Paladin Skills
        [53408] = {r = 1.0, g = 1.0, b = 0.3, a = 1.0},   -- 智慧审判 -> NUMPAD9 (Overpower color)
        [20271] = {r = 0.2, g = 0.4, b = 0.9, a = 1.0},   -- 圣光审判 -> CTRL-NUMPAD5 (Bloodrage color)
        [48801] = {r = 0.7, g = 0.3, b = 0.1, a = 1.0},   -- 驱邪术 -> NUMPAD8 (Rend color)
        [48819] = {r = 0.1, g = 0.7, b = 0.7, a = 1.0},   -- 奉献 -> ALT-NUMPAD1 (Battle Stance color)
        [54428] = {r = 0.5, g = 0.2, b = 0.8, a = 1.0},   -- 神圣恳求 -> CTRL-NUMPAD4 (Shattering Throw color)

        -- Auras, Seals (GCD)
        [31801] = {r = 0.9, g = 0.3, b = 0.1, a = 1.0},   -- 复仇圣印 -> ALT-NUMPAD2 (Berserker Stance color)
        [53736] = {r = 0.9, g = 0.3, b = 0.1, a = 1.0},   -- 腐蚀圣印 -> ALT-NUMPAD2
        [20375] = {r = 0.1, g = 0.5, b = 0.7, a = 1.0},   -- 命令圣印 -> ALT-NUMPAD3 (Defensive Stance color)
        [25780] = {r = 0.9, g = 0.4, b = 0.1, a = 1.0},   -- 正义之怒 -> ALT-NUMPAD4 (Battle Shout color)
    },

    CommandAliases = {
        -- Retribution Paladin aliases
        ["wings"] = "useAvengingWrath", ["开翅膀"] = "useAvengingWrath",
        ["storm"] = "useDivineStorm", ["风暴"] = "useDivineStorm",
        ["sustain"] = "useSustainabilityMode", ["续航"] = "useSustainabilityMode",
        ["consec"] = "consecrationPriority", ["奉献"] = "consecrationPriority",
        ["seal"] = "selectedSeal_Ret", ["圣印"] = "selectedSeal_Ret", ["sy"] = "selectedSeal_Ret",
        ["judge"] = "selectedJudgement_Ret", ["审判"] = "selectedJudgement_Ret",
        ["翅膀"] = 31884,
    }
}
