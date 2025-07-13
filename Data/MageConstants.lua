-- WRA/Data/MageConstants.lua
-- Contains all constants specific to the Mage class for WotLK.

local addonName, _ = ...
local WRA = LibStub("AceAddon-3.0"):GetAddon(addonName)

if not WRA then return end

WRA.ClassConstants = WRA.ClassConstants or {}

WRA.ClassConstants.Mage = {
    Spells = {
        -- Core Fire
        FIREBALL = 42833,           -- 火球术 (Rank 15)
        PYROBLAST = 42891,          -- 炎爆术 (Rank 11)
        FIRE_BLAST = 42873,         -- 火焰冲击 (Rank 9)
        SCORCH = 42859,             -- 灼烧 (Rank 9)
        LIVING_BOMB = 55360,        -- 活体炸弹 (Rank 3)

        -- AOE
        FLAMESTRIKE = 42926,        -- 烈焰风暴 (Rank 8)
        BLIZZARD = 42940,           -- 暴风雪 (Rank 7)
        DRAGONS_BREATH = 42950,     -- 龙息术 (Rank 5)

        -- Cooldowns & Utility
        COMBUSTION = 11129,         -- 燃烧
        MIRROR_IMAGE = 55342,       -- 镜像
        EVOCATION = 12051,          -- 唤醒
        MANA_GEM = 36032,           -- 法力宝石
        FLASH = 1953,
    },
    Auras = {
        -- Procs & Buffs
        HOT_STREAK = 48108,         -- 法术连击 (大括号)
        FIREPOWER = 70753,          -- 冲破极限 (T10 2件套效果)
        COMBUSTION_BUFF = 11129,    -- 燃烧
        
        -- Debuffs
        LIVING_BOMB_DEBUFF = 55360, -- 活体炸弹 DoT (Rank 3)
        PYROBLAST_DEBUFF = 42891,   -- 炎爆术 DoT
        IMPROVED_SCORCH = 22959,    -- 强化灼烧 (debuff from any source)
        IGNITE = 413841,             -- 点燃
    },
    
    SpellData = {
        -- All listed spells are on the GCD
        [42833] = { isOffGCD = false }, -- 火球术
        [42891] = { isOffGCD = false }, -- 炎爆术
        [42873] = { isOffGCD = false }, -- 火焰冲击 (Instant)
        [42859] = { isOffGCD = false }, -- 灼烧
        [55360] = { isOffGCD = false }, -- 活体炸弹
        [42926] = { isOffGCD = false }, -- 烈焰风暴
        [42940] = { isOffGCD = false }, -- 暴风雪 (Channeled)
        [42950] = { isOffGCD = false }, -- 龙息术 (Instant, but on GCD)
        [11129] = { isOffGCD = false }, -- 燃烧 (Instant, but on GCD)
        [55342] = { isOffGCD = false }, -- 镜像 (Instant, but on GCD)
        [12051] = { isOffGCD = false }, -- 唤醒 (Channeled)
        [36032] = { isOffGCD = false }, -- 法力宝石
    },

    ActionColors = {
        -- == GCD Mappings ==
        [42833] = {r = 0.8, g = 0.1, b = 0.1, a = 1.0}, -- 火球术 -> NUMPAD1
        [42891] = {r = 0.9, g = 0.6, b = 0.2, a = 1.0}, -- 炎爆术 -> NUMPAD2
        [55360] = {r = 0.4, g = 0.0, b = 0.0, a = 1.0}, -- 活体炸弹 -> NUMPAD5
        [42873] = {r = 0.6, g = 0.8, b = 0.2, a = 1.0}, -- 火焰冲击 -> NUMPAD6
        [42859] = {r = 0.7, g = 0.3, b = 0.1, a = 1.0}, -- 灼烧 -> NUMPAD8
        
        [11129] = {r = 1.0, g = 0.0, b = 0.5, a = 1.0}, -- 燃烧 -> CTRL-NUMPAD1
        [55342] = {r = 0.6, g = 0.0, b = 0.6, a = 1.0}, -- 镜像 -> CTRL-NUMPAD2
        [42950] = {r = 1.0, g = 0.3, b = 0.0, a = 1.0}, -- 龙息术 -> CTRL-NUMPAD3
        [36032] = {r = 0.5, g = 0.2, b = 0.8, a = 1.0}, -- 法力宝石 -> CTRL-NUMPAD4
    }
}
