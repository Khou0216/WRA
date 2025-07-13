-- WRA/Data/WarriorConstants.lua
-- Contains all constants specific to the Warrior class.
-- MODIFIED: Assigned unique color codes to all abilities to resolve conflicts for AHK script.

local addonName, _ = ...
local WRA = LibStub("AceAddon-3.0"):GetAddon(addonName)

if not WRA then return end

WRA.ClassConstants = WRA.ClassConstants or {}

WRA.ClassConstants.Warrior = {
    Spells = {
        -- Fury
        BLOODTHIRST = 23881, WHIRLWIND = 1680, HEROIC_STRIKE = 47450, SLAM = 47475, EXECUTE = 47471, CLEAVE = 47520, REND = 47465,
        OVERPOWER = 7384, RECKLESSNESS = 1719, DEATH_WISH = 12292, BERSERKER_RAGE = 18499,
        -- Protection
        SHIELD_SLAM = 47488, REVENGE = 57823, DEVASTATE = 47498, SHIELD_BLOCK = 2565, 
        THUNDER_CLAP = 47502, DEMORALIZING_SHOUT = 47437, SHOCKWAVE = 46968,
        LAST_STAND = 12975, SHIELD_WALL = 871, SHIELD_BASH = 72,
        -- Common / Utility
        SWEEPING_STRIKES = 12328,
        SHATTERING_THROW = 64382, BLOODRAGE = 2687, PUMMEL = 6552, BATTLE_SHOUT = 47436, COMMANDING_SHOUT = 47440, 
        SUNDER_ARMOR = 7386, HEROIC_THROW = 57755, INTERCEPT = 20252,
        BATTLE_STANCE_CAST = 2457, DEFENSIVE_STANCE_CAST = 71, BERSERKER_STANCE_CAST = 2458, RETALIATION = 20230,
        -- Racials
        BLOOD_FURY = 20572, BERSERKING = 26297, STONEFORM = 20594, ESCAPE_ARTIST = 20589, GIFT_OF_NAARU = 28880, EVERY_MAN = 59752,
    },
    Auras = {
        -- Fury
        BLOODSURGE = 46916, ENRAGE = 12880, RAMPAGE = 29801, DEATH_WISH_BUFF = 12292, RECKLESSNESS_BUFF = 1719, BERSERKER_RAGE_BUFF = 18499,
        BERSERKING_BUFF = 26297, BLOODLUST = 2825, HEROISM = 32182, OVERPOWER_PROC = 12835, 
        -- Protection
        SHIELD_BLOCK_BUFF = 2565, THUNDER_CLAP_DEBUFF = 6343, DEMORALIZING_SHOUT_DEBUFF = 25203, VIGILANCE_BUFF = 50720,
        SHIELD_WALL_BUFF = 871, LAST_STAND_BUFF = 12975,
        -- Common
        REND_DEBUFF = 47465, SUNDER_ARMOR_DEBUFF = 58567, SHATTERING_THROW_DEBUFF = 64382, 
        BATTLE_SHOUT_BUFF = 47436, COMMANDING_SHOUT_BUFF = 47440,
    },
    Items = { POTION_HASTE = 40211, TRINKET_DBW = 50363, TRINKET_STS = 50343 },
    SpellData = {
        -- Fury
        [23881] = { range = 5, cost = 20, isOffGCD = false, triggersGCD = true }, 
        [1680]  = { range = 5, cost = 25, isOffGCD = false, triggersGCD = true },
        [47450] = { range = 5, cost = 12, isOffGCD = true,  triggersGCD = false }, 
        [47475] = { range = 5, cost = 15, isOffGCD = false, triggersGCD = true },
        [47471] = { range = 5, cost = 15, isOffGCD = false, triggersGCD = true }, 
        [47520] = { range = 5, cost = 20, isOffGCD = true,  triggersGCD = false },
        [6552]  = { range = 5, cost = 10, isOffGCD = true,  triggersGCD = false }, 
        [47465] = { range = 5, cost = 10, isOffGCD = false, triggersGCD = true },
        [7384]  = { range = 5, cost = 5,  isOffGCD = false, triggersGCD = true }, 
        [64382] = { range = 30,cost = 25, isOffGCD = false, triggersGCD = true },
        [57755] = { range = 30,cost = 0,  isOffGCD = false, triggersGCD = true }, 
        [20252] = { range = 25,cost = 10, isOffGCD = false, triggersGCD = true },
        [47436] = { range = 0, cost = 10, isOffGCD = false, triggersGCD = true }, 
        [47440] = { range = 0, cost = 10, isOffGCD = false, triggersGCD = true },
        [1719]  = { range = 0, cost = 0,  isOffGCD = false, triggersGCD = true }, 
        [12292] = { range = 0, cost = 0,  isOffGCD = false, triggersGCD = true },
        [18499] = { range = 0, cost = 0,  isOffGCD = false, triggersGCD = true }, 
        [2687]  = { range = 0, cost = 0,  isOffGCD = true,  triggersGCD = false },
        [20230] = { range = 0, cost = 0,  isOffGCD = false, triggersGCD = true },
        [7386] = { range = 5, cost = 15,  isOffGCD = false, triggersGCD = true },
        -- Protection
        [47488] = { range = 5, cost = 20, isOffGCD = false, triggersGCD = true }, -- Shield Slam
        [57823] = { range = 5, cost = 5,  isOffGCD = false, triggersGCD = true }, -- Revenge
        [47498] = { range = 5, cost = 15, isOffGCD = false, triggersGCD = true }, -- Devastate
        [47502] = { range = 8, cost = 20, isOffGCD = false, triggersGCD = true }, -- Thunder Clap
        [47437] = { range = 0, cost = 10, isOffGCD = false, triggersGCD = true }, -- Demoralizing Shout
        [46968] = { range = 10, cost = 15, isOffGCD = false, triggersGCD = true },-- Shockwave
        [2565]  = { range = 0, cost = 10, isOffGCD = true,  triggersGCD = false },-- Shield Block
        [12975] = { range = 0, cost = 0,  isOffGCD = true,  triggersGCD = false },-- Last Stand
        [871]   = { range = 0, cost = 0,  isOffGCD = true,  triggersGCD = false },-- Shield Wall
        [72]    = { range = 5, cost = 10, isOffGCD = true,  triggersGCD = false },-- Shield Bash
        [12328] = { range = 0, cost = 25, isOffGCD = false, triggersGCD = true }, -- Sweeping Strikes
        -- Stances
        [2457]  = { range = 0, cost = 0, isOffGCD = false, triggersGCD = false },
        [2458]  = { range = 0, cost = 0, isOffGCD = false, triggersGCD = false },
        [71]    = { range = 0, cost = 0, isOffGCD = false, triggersGCD = false },
    },
    ActionColors = {
        -- Fury Colors
        [23881] = {r = 0.8, g = 0.1, b = 0.1, a = 1.0}, -- 0xCC1A1A Bloodthirst
        [1680]  = {r = 0.9, g = 0.6, b = 0.2, a = 1.0}, -- 0xE69933 Whirlwind
        [47450] = {r = 0.1, g = 0.7, b = 0.1, a = 1.0}, -- 0x1AB31A Heroic Strike
        [47520] = {r = 0.1, g = 0.5, b = 0.5, a = 1.0}, -- 0x1A8080 Cleave
        [47471] = {r = 0.4, g = 0.0, b = 0.0, a = 1.0}, -- 0x660000 Execute
        [47475] = {r = 0.6, g = 0.8, b = 0.2, a = 1.0}, -- 0x99CC33 Slam
        [57755] = {r = 0.2, g = 0.7, b = 0.7, a = 1.0}, -- 0x33B3B3 Heroic Throw
        [47465] = {r = 0.7, g = 0.3, b = 0.1, a = 1.0}, -- 0xB34D1A Rend
        [7384]  = {r = 1.0, g = 1.0, b = 0.3, a = 1.0}, -- 0xFFFF4D Overpower
        [6552]  = {r = 0.8, g = 0.8, b = 0.8, a = 1.0}, -- 0xCCCCCC Pummel

        -- Cooldowns
        [1719]  = {r = 1.0, g = 0.0, b = 0.5, a = 1.0}, -- 0xFF0080 Recklessness
        [12292] = {r = 0.6, g = 0.0, b = 0.6, a = 1.0}, -- 0x990099 Death Wish
        [18499] = {r = 1.0, g = 0.3, b = 0.0, a = 1.0}, -- 0xFF4D00 Berserker Rage
        [64382] = {r = 0.5, g = 0.2, b = 0.8, a = 1.0}, -- 0x8033CC Shattering Throw
        [2687]  = {r = 0.9, g = 0.2, b = 0.2, a = 1.0}, -- 0xE63333 Bloodrage
        [47488] = {r = 0.2, g = 0.4, b = 0.9, a = 1.0}, -- 0x3366E6 Shield Slam
        [57823] = {r = 0.9, g = 0.2, b = 0.1, a = 1.0}, -- 0xE6331A Revenge
        [47498] = {r = 0.6, g = 0.4, b = 0.2, a = 1.0}, -- 0x996633 Devastate
        [46968] = {r = 0.8, g = 0.5, b = 0.1, a = 1.0}, -- 0xCC801A Shockwave
        
        -- Stances & Shouts
        [2457]  = {r = 0.1, g = 0.7, b = 0.7, a = 1.0}, -- 0x1AB3B3 Battle Stance
        -- [!code --]
        -- [2458]  = {r = 0.9, g = 0.4, b = 0.1, a = 1.0}, -- 0xE6661A Berserker Stance (Shared with Battle Shout)
        -- [!code ++]
        [2458]  = {r = 0.9, g = 0.3, b = 0.1, a = 1.0}, -- 0xE64D1A Berserker Stance (New Unique Color)
        -- [!code --]
        [71]    = {r = 0.1, g = 0.5, b = 0.7, a = 1.0}, -- 0x1A80B3 Defensive Stance
        [47436] = {r = 0.9, g = 0.4, b = 0.1, a = 1.0}, -- 0xE6661A Battle Shout
        [47440] = {r = 0.8, g = 0.7, b = 0.1, a = 1.0}, -- 0xCCB31A Commanding Shout

        -- Other Defensive & Utility
        [871]   = {r = 0.7, g = 0.7, b = 0.8, a = 1.0}, -- 0xB3B3CC Shield Wall
        [12975] = {r = 0.9, g = 0.9, b = 0.0, a = 1.0}, -- 0xE6E600 Last Stand
        [72]    = {r = 1.0, g = 1.0, b = 1.0, a = 1.0}, -- 0xFFFFFF Shield Bash
        [12328] = {r = 0.4, g = 0.7, b = 0.7, a = 1.0}, -- 0x66B3B3 Sweeping Strikes
        -- [!code ++]
        [2565]  = {r = 0.0, g = 1.0, b = 1.0, a = 1.0}, -- 0x00FFFF Shield Block (now unique)
        [47502] = {r = 1.0, g = 0.8, b = 0.0, a = 1.0}, -- Thunder Clap, unique color
        [20230] = {r = 0.9, g = 0.9, b = 0.95, a = 1.0}, -- #E6E6F2 Retaliation (Silvery White)
        [7386]  = {r = 0.6, g = 0.5, b = 0.4, a = 1.0}, -- #998066 Sunder Armor (破甲攻击)
        -- [!code --]

        -- Racials & Items
        [20572] = {r = 0.9, g = 0.3, b = 0.7, a = 1.0}, -- 0xE64DB3 Blood Fury (Racial)
        [26297] = {r = 0.9, g = 0.3, b = 0.7, a = 1.0}, -- 0xE64DB3 Berserking (Racial)
        [40211] = {r = 0.9, g = 0.72, b = 0.0, a = 1.0},-- 0xE6B800 Haste Potion
    },
    Stances = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3, },
 
    StanceMap = {
        [2457] = true, -- Battle Stance
        [71]   = true, -- Defensive Stance
        [2458] = true, -- Berserker Stance
    },

    SpellRequirements = {
        [20230] = { stance = 1 }, -- 反击风暴 (Retaliation) requires Battle Stance (1)
        [47465] = { stance = 1 }, -- 撕裂 (Rend) requires Battle Stance (1)
        [7384]  = { stance = 1 }, -- 压制 (Overpower) requires Battle Stance (1)
        [12328] = { stance = 1 }, -- 横扫攻击 (Sweeping Strikes) requires Battle Stance (1)
        [871]   = { stance = 2 }, -- 盾墙 (Shield Wall) requires Defensive Stance (2)
        [2565]  = { stance = 2 }, -- 盾牌格挡 (Shield Block) requires Defensive Stance (2)
        [72]    = { stance = 2 }, -- 盾击 (Shield Bash) requires Defensive Stance (2)
        [20252] = { stance = 3 }, -- 拦截 (Intercept) requires Berserker Stance (3)
        [1680]  = { stance = 3 }, -- 旋风斩 (Whirlwind) requires Berserker Stance (3)
    },

    CommandAliases = {
        ["鲁莽"] = 1719, ["reck"] = 1719, ["recklessness"] = 1719, ["死亡之愿"] = 12292, ["死愿"] = 12292, ["dw"] = 12292,
        ["deathwish"] = 12292, ["嗜血"] = 23881, ["bt"] = 23881, ["旋风斩"] = 1680, ["ww"] = 1680, ["斩杀"] = 47471,
    },

    CommandCombos = {
        ["爆发"] = { 1719, 12292 }, -- /wra combo 爆发 -> 鲁莽, 死亡之愿
        ["burst"] = { 1719, 12292 }, -- English alias for the above
        ["大风车"] = { 12328, 1680 }, -- /wra combo 大风车 -> 横扫攻击, 旋风斩
        ["bladestorm"] = { 12328, 1680 }, -- English alias for the above
    }
}
