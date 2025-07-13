-- Core/Constants.lua
-- Holds constants used by the WRA addon for WotLK Classic (3.3.5a / 3.4.x)
-- MODIFIED: Added functions to backup and restore original constants for spec switching.
-- MODIFIED (Nitro Fix): Corrected the item ID for Nitro Boosts in ActionColors and added it to SpellData.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local Constants = WRA:NewModule("Constants")
WRA.Constants = Constants

--[[-----------------------------------------------------------------------------
    Engine & Timing Constants
-------------------------------------------------------------------------------]]
Constants.UPDATE_INTERVAL = 0.05
Constants.FIRE_WINDOW = 0.15
Constants.GCD_THRESHOLD = 0.05 
Constants.ACTION_ID_WAITING = 0 
Constants.ACTION_ID_IDLE = "IDLE"
Constants.ACTION_ID_CASTING = "CASTING"
Constants.ACTION_ID_UNKNOWN = -1 
Constants.HS_CLEAVE_MIN_RAGE = 12 

--[[-----------------------------------------------------------------------------
    Special Action IDs (Used across multiple specs)
-------------------------------------------------------------------------------]]
-- We define START_ATTACK here as it's a generic action, not tied to one class.
Constants.Spells = {
    START_ATTACK = -2
}

Constants.Items = {
    NITRO_BOOTS = 55016, -- Engineering Tinker ID for Nitro Boosts
}

-- [Gemini] 新增：装备槽位ID常量
Constants.EquipmentSlots = {
    HEAD = 1,
    NECK = 2,
    SHOULDER = 3,
    SHIRT = 4,
    CHEST = 5,
    WAIST = 6,
    LEGS = 7,
    FEET = 8,
    WRIST = 9,
    HANDS = 10,
    FINGER1 = 11,
    FINGER2 = 12,
    TRINKET1 = 13,
    TRINKET2 = 14,
    BACK = 15,
    MAINHAND = 16,
    OFFHAND = 17,
    RANGED = 18,
    TABARD = 19,
}

Constants.Auras = {
    SUNDER_ARMOR_DEBUFF = 58567, -- 破甲 (战士)
    EXPOSE_ARMOR_DEBUFF = 8647,  -- 破甲 (盗贼)
    DEATHBRINGERS_WILL_AGI = 71485,      -- 死神意志 (敏捷)
    DEATHBRINGERS_WILL_STR = 71486,      -- 死亡的使者意志 (力量)
    DEATHBRINGERS_WILL_CRIT = 71491,     -- 死亡的使者意志 (暴击)
    DEATHBRINGERS_WILL_AGI_H = 71556,    -- 死亡的使者意志 (英雄-敏捷)
    DEATHBRINGERS_WILL_STR_H = 71558,    -- 死亡的使者意志 (英雄-力量)
    DEATHBRINGERS_WILL_CRIT_H = 71559,   -- 死亡的使者意志 (英雄-暴击)
    SHARPENED_TWILIGHT_SCALE = 71403,   -- 锐利的暮光龙鳞
    SHARPENED_TWILIGHT_SCALE_H = 71543, -- 锐利的暮光龙鳞 (英雄)
    DEATH_VERDICT_N = 67703,
    SKULL = 71401,
    NITRO_BOOTS_BUFF = 54861, -- Nitro Boosts speed buff
}

-- [Gemini] 新增：Boss技能ID常量
Constants.BossAbilities = {
    DEFILE = 72762, -- 巫妖王 - 污染
}


Constants.Trinkets = {
    -- 意志 / Deathbringer's Will
    [50363] = { -- 普通
        auraIDs = { 71485, 71486, 71491 } -- 敏捷, 力量, 暴击
    },
    [50362] = { -- 英雄
        auraIDs = { 71556, 71558, 71559 } -- 敏捷, 力量, 暴击
    },
    -- 锐利的暮光龙鳞 / Sharpened Twilight Scale
    [50343] = { -- 普通
        auraID = 71403 
    },
    [50342] = { -- 英雄
        auraID = 71543
    },
    [47115] = {
        auraID = 67703
    },
    [50342] = {
        auraID = 71401
    }
    -- 可以在这里添加更多饰品...
}
--[[-----------------------------------------------------------------------------
    Generic Action Colors for UI Display
-------------------------------------------------------------------------------]]
Constants.ActionColors = {
    [Constants.ACTION_ID_IDLE]      = {r = 0.5, g = 0.5, b = 0.5, a = 0.8}, -- Grey (Idle)
    [Constants.ACTION_ID_WAITING]   = {r = 0.3, g = 0.3, b = 0.3, a = 0.8}, -- Dark Grey (Waiting/GCD)
    [Constants.ACTION_ID_CASTING]   = {r = 0.2, g = 0.2, b = 0.6, a = 0.8}, -- Dark Blue (Casting)
    [Constants.ACTION_ID_UNKNOWN]   = {r = 0.1, g = 0.1, b = 0.1, a = 0.8}, -- Nearly Black (Unknown)
    [Constants.Spells.START_ATTACK] = {r = 0.9, g = 0.9, b = 0.2, a = 1.0}, -- Yellow for Start Attack
    -- [!code --]
    -- [-36898] = {r = 0.0, g = 1.0, b = 0.5, a = 1.0}, -- 亮绿色 (0x00FF80) for Nitro Boosts
    -- [!code ++]
    -- *** FIX: Use the constant for the item ID to ensure it matches the rest of the addon ***
    [-Constants.Items.NITRO_BOOTS] = {r = 0.0, g = 1.0, b = 0.5, a = 1.0}, -- 亮绿色 (0x00FF80) for Nitro Boosts
    -- [!code --]
}

-- [!code ++]
-- *** NEW: Added a SpellData table to centrally define action properties ***
Constants.SpellData = {
    [-Constants.Items.NITRO_BOOTS] = { isOffGCD = true }, -- Define Nitro Boosts as an Off-GCD action
}
-- [!code --]

-- [!code ++]
-- *** 新增：用于存储原始常量的备份表 ***
local originalConstants = {}
local backupDone = false

-- *** 新增：备份原始常量表的函数 ***
local function BackupOriginalConstants()
    if backupDone then return end
    originalConstants.Spells = WRA.Utils:GetTableCopy(Constants.Spells)
    originalConstants.ActionColors = WRA.Utils:GetTableCopy(Constants.ActionColors)
    -- [!code ++]
    originalConstants.SpellData = WRA.Utils:GetTableCopy(Constants.SpellData) -- Also backup SpellData
    -- [!code --]
    backupDone = true
    WRA:PrintDebug("Original constants backed up.")
end

-- *** 新增：从备份中恢复原始常量表的函数 ***
function Constants:RestoreOriginals()
    if not backupDone then BackupOriginalConstants() end
    
    self.Spells = WRA.Utils:GetTableCopy(originalConstants.Spells)
    self.ActionColors = WRA.Utils:GetTableCopy(originalConstants.ActionColors)
    -- [!code ++]
    self.SpellData = WRA.Utils:GetTableCopy(originalConstants.SpellData) -- Also restore SpellData
    -- [!code --]
    -- 清空其他可能被专精填充的表
    self.Auras = {}
    self.Items = {}
    self.Stances = {}
    -- [!code --]
    -- self.SpellData = {} -- 确保 SpellData 也被清空
    -- [!code --]
    WRA:PrintDebug("Original constants restored.")
end

-- *** 新增：深度合并两个表的函数 ***
local function DeepMerge(destination, source)
    if type(source) ~= "table" then return end
    for k, v in pairs(source) do
        if type(v) == "table" and type(destination[k]) == "table" then
            DeepMerge(destination[k], v)
        else
            destination[k] = v
        end
    end
end

-- *** 新增：合并专精常量到主常量表的函数 ***
function Constants:MergeSpecConstants(specConstants)
    if type(specConstants) ~= "table" then
        WRA:PrintDebug("MergeSpecConstants: specConstants is not a table, skipping merge.")
        return
    end
    WRA:PrintDebug("Merging spec constants...")
    DeepMerge(self, specConstants)
end
-- [!code --]

function Constants:OnInitialize()
    -- [!code ++]
    -- *** 修改：在初始化时进行备份 ***
    BackupOriginalConstants()
    -- [!code --]
    WRA:PrintDebug("Constants Module Initialized (Global).")
end
