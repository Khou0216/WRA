-- WRA/Data/DruidConstants.lua
-- Contains all constants specific to the Druid class for WotLK.
-- MODIFIED: Corrected form IDs for Cat and Bear to match WotLK API.

local addonName, _ = ...
local WRA = LibStub("AceAddon-3.0"):GetAddon(addonName)
if not WRA then return end

WRA.ClassConstants = WRA.ClassConstants or {}

WRA.ClassConstants.Druid = {
    Forms = {
        CAT = 3,  -- 猫形态 (WotLK API returns 3 for Cat Form)
        BEAR = 1, -- 熊形态 (WotLK API returns 1 for Bear Form)
        DIRE_BEAR = 5, -- 巨熊形态 (WotLK API returns 5 for Dire Bear Form)
    },
    Spells = {

        -- Form Shifting
        CAT_FORM = 768,             -- 猎豹形态
        BEAR_FORM = 5487,           -- 熊形态
        DIRE_BEAR_FORM = 9634,      -- 巨熊形态

        -- Feral Core
        SHRED = 48572,              -- 撕碎
        MANGLE_CAT = 48566,         -- 裂伤(猫)
        RAKE = 48574,               -- 斜掠
        RIP = 49800,                -- 割裂
        SAVAGE_ROAR = 52610,        -- 野性咆哮
        FEROCIOUS_BITE = 48577,     -- 凶猛撕咬
        TIGERS_FURY = 50213,         -- 猛虎之怒
        BERSERK = 50334,            -- 狂暴
        FAERIE_FIRE_FERAL = 16857,  -- 精灵之火(野性)
        SWIPE_CAT = 62078,

        -- BEAR
        SWIPE_BEAR = 48562,
        MANGLE_BEAR = 48564,
        MAUL = 48480,
        LACERATE = 48568,
        SURVIVAL_INSTINCTS = 61336,
        ENRAGE = 5229,

    },
    Auras = {
        -- Buffs
        SAVAGE_ROAR = 52610,
        OMEN_OF_CLARITY = 16870,    -- 清晰预兆
        BERSERK = 50334,
        TIGERS_FURY = 50213,
        
        -- Debuffs
        RIP = 49800,
        RAKE = 48574,
        MANGLE = 48566,
        FAERIE_FIRE_FERAL = 16857,
        LACERATE = 33745,

        MANGLE_EQUIVALENTS = {
            48566, -- Mangle (Cat)
            48564, -- Mangle (Bear)
            46857, -- Trauma (Warrior Arms)
        }

    },
    
    SpellData = {
        -- Off-GCD Abilities
        [50213] = { isOffGCD = true }, -- 猛虎之怒
        [48480] = { isOffGCD = true }, -- 槌击 (Maul)
        [61336] = { isOffGCD = true }, -- 生存本能
        [5229] = { isOffGCD = true },
        
        -- GCD Abilities
        [50334] = { isOffGCD = false }, -- 狂暴
        [48572] = { isOffGCD = false }, -- 撕碎
        [48566] = { isOffGCD = false }, -- 裂伤(猫)
        [48574] = { isOffGCD = false }, -- 斜掠
        [49800] = { isOffGCD = false }, -- 割裂
        [52610] = { isOffGCD = false }, -- 野性咆哮
        [48577] = { isOffGCD = false }, -- 凶猛撕咬
        [16857] = { isOffGCD = false }, -- 精灵之火(野性)
        [62078] = { isOffGCD = false }, -- 横扫
        [48562] = { isOffGCD = false }, -- 横扫(熊)
        [48564] = { isOffGCD = false }, -- 裂伤(熊)
        [48568] = { isOffGCD = false }, -- 割伤
    },

    ActionColors = {
        -- == Off-GCD Mappings (matches AHK OffGCDList) ==
        [50213] = {r = 0.1, g = 0.7, b = 0.1, a = 1.0},   -- 猛虎之怒 -> NUMPAD3 (Heroic Strike color)
        [48480] = {r = 0.9, g = 0.2, b = 0.2, a = 1.0},   -- 槌击 -> NUMPAD4
        [5229] = {r = 0.8, g = 0.8, b = 0.8, a = 1.0},
        -- == GCD Mappings (matches AHK GCDList) ==
        [48572] = {r = 0.8, g = 0.1, b = 0.1, a = 1.0},   -- 撕碎 -> NUMPAD1 (Bloodthirst color)
        [48566] = {r = 0.9, g = 0.6, b = 0.2, a = 1.0},   -- 裂伤 -> NUMPAD2 (Whirlwind color)
        [49800] = {r = 0.4, g = 0.0, b = 0.0, a = 1.0},   -- 割裂 -> NUMPAD5 (Execute color)
        [52610] = {r = 0.6, g = 0.8, b = 0.2, a = 1.0},   -- 野性咆哮 -> NUMPAD6 (Slam color)
        [48574] = {r = 0.7, g = 0.3, b = 0.1, a = 1.0},   -- 斜掠 -> NUMPAD8 (Rend color)
        [16857] = {r = 0.2, g = 0.7, b = 0.7, a = 1.0},   -- 精灵之火 -> NUMPAD7 (Heroic Throw color)
        [50334] = {r = 1.0, g = 0.0, b = 0.5, a = 1.0},   -- 狂暴 -> CTRL-NUMPAD1 (Recklessness color)
        [48577] = {r = 1.0, g = 0.3, b = 0.0, a = 1.0},   -- 凶猛撕咬 -> CTRL-NUMPAD3 (Berserker Rage color)
        [62078] = {r = 0.5, g = 0.2, b = 0.8, a = 1.0},
        [48568] = {r = 0.6, g = 0.0, b = 0.6, a = 1.0},   -- 割伤 -> CTRL-NUMPAD2
        [48564] = {r = 0.2, g = 0.4, b = 0.9, a = 1.0},   -- C6 裂伤熊
        [48562] = {r = 0.8, g = 0.5, b = 0.1, a = 1.0},   -- 横扫(熊) -> CTRL-NUMPAD9
        [768] = {r = 0.9, g = 0.2, b = 0.1, a = 1.0},
        [9634] = {r = 0.6, g = 0.4, b = 0.2, a = 1.0},
    }
}
