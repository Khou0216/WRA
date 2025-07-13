-- WRA/Specs/FireMage.lua
-- Rotation logic for Fire Mage specialization.
-- MODIFIED (V3): Fixed a critical bug where the TTDTracker module was not being correctly referenced, causing the rotation to fail.
-- MODIFIED V4 (Hot Streak Rework): Completely refactored the logic to use AuraMonitor for tracking the "Heating Up" (48107)
-- and "Hot Streak" (48108) buffs directly, instead of relying on fragile combat log parsing. This is a more robust and reliable implementation.
-- MODIFIED V5 (Final Logic Restoration): Reverted the "Heating Up" tracking to the user's original, correct combat log parsing method.
-- Fixed the core issue by using the now-available WRA.playerGUID to correctly identify player actions in the combat log.
-- MODIFIED V6 (Combat Log Fix): Implemented a dedicated frame to handle COMBAT_LOG_EVENT_UNFILTERED correctly, bypassing AceEvent's limitations.
-- MODIFIED V7 (Debug): Added extensive debug messages to trace the entire Heating Up and Hot Streak logic flow.
-- MODIFIED V8 (Final Fix): Implemented robust combat log parsing by capturing all arguments into a table and using select() to correctly parse event-specific parameters, fixing the critical flag detection.
-- MODIFIED V9 (Cleanup): Removed temporary debug messages. Retained essential "Heating Up" status change messages.
-- MODIFIED V10 (Consumption Fix): Consolidated all Heating Up/Hot Streak logic into a single CombatLogHandler to reliably track consumption when the Hot Streak aura is applied.
-- MODIFIED V11 (Pyroblast Fix): Corrected the Heating Up logic to exclude Pyroblast crits from granting a new Heating Up proc, as per user feedback.
-- MODIFIED V12 (Living Bomb Fix): Added Living Bomb's initial damage to the list of spells that can grant the Heating Up proc.
-- MODIFIED V13 (Fire Blast Logic): Corrected Fire Blast usage to be for mobility/filler only, not for consuming the Heating Up proc.
-- MODIFIED V14 (Final Logic): Reverted to monitoring spell names for crits as per user feedback and best practices, removing the need for separate explosion IDs.
-- MODIFIED V15 (Munching Fix): Corrected the logic to allow Heating Up to be gained even when Hot Streak is already active, enabling proper munching protection.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)
local FireMage = WRA:NewModule("FireMage", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Lua shortcuts
local IsPlayerSpell, GetSpellInfo = IsPlayerSpell, GetSpellInfo
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local string_format = string.format
local select, unpack, tostring = select, unpack, tostring

-- Module references
local C, State, CD, Aura, Utils, DB, TTD

-- Internal state for tracking Heating Up ("小括号")
local hasHeatingUp = false

-- A dedicated frame to handle the special case of COMBAT_LOG_EVENT_UNFILTERED
local fireMageCombatLogFrame = CreateFrame("Frame")

-- Helper to get settings from the database
local function GetDBValue(key, defaultValue)
    if DB and DB[key] ~= nil then return DB[key] end
    return defaultValue
end

-- [!code ++]
-- *** NEW: Helper function for detailed state debugging ***
local function PrintDebugState(message, expectedHotStreak)
    -- This function provides a consistent format for debugging the state of both "Heating Up" and "Hot Streak".
    -- It's called after any state change to give a clear snapshot.
    local hasHotStreakNow = Aura:HasBuff(C.Auras.HOT_STREAK, "player")
    local hotStreakStatusForLog = (expectedHotStreak ~= nil) and tostring(expectedHotStreak) or tostring(hasHotStreakNow)
    local debugString = string_format(
        "%s | 状态 -> [小括号: %s] [大括号: %s]",
        message,
        tostring(hasHeatingUp),
        hotStreakStatusForLog
    )
    WRA:PrintDebug(debugString)
end
-- [!code --]
-- Combat Log event handler for tracking crits and Hot Streak applications.
local function CombatLogHandler()
    local combatEventArgs = { CombatLogGetCurrentEventInfo() }
    
    local event = combatEventArgs[2]
    local sourceGUID = combatEventArgs[4]
    local destGUID = combatEventArgs[8]

    if sourceGUID ~= WRA.playerGUID and destGUID ~= WRA.playerGUID then return end

    if event == "SPELL_DAMAGE" and sourceGUID == WRA.playerGUID then
        local spellId, spellName, _, _, _, _, _, _, _, critical = select(12, unpack(combatEventArgs))
        
        local fireballName, fireblastName, scorchName, livingBombName = GetSpellInfo(C.Spells.FIREBALL), GetSpellInfo(C.Spells.FIRE_BLAST), GetSpellInfo(C.Spells.SCORCH), GetSpellInfo(C.Spells.LIVING_BOMB)
        
        if (spellName == fireballName or spellName == fireblastName or spellName == scorchName or spellName == livingBombName) then
            if critical then
                -- This is the core logic for munching protection.
                if hasHeatingUp then
                    -- We already had "Heating Up", so this crit should convert it to "Hot Streak".
                    -- We log that we EXPECT a Hot Streak, even if the aura hasn't been applied by the client yet.
                    PrintDebugState("暴击 (已有小括号)", true)
                    -- [!code ++]
                else
                    -- [!code --]
                    -- We did not have "Heating Up", so this crit grants it.
                    hasHeatingUp = true
                    PrintDebugState("暴击 (获得小括号)", nil)
                    -- [!code ++]
                end
            else 
                if hasHeatingUp then
                    hasHeatingUp = false
                    PrintDebugState("非暴击 (失去小括号)", nil)
                end
            end
        end

    elseif event == "SPELL_AURA_APPLIED" and destGUID == WRA.playerGUID then
        local spellId = combatEventArgs[12]
        if spellId == C.Auras.HOT_STREAK then
            if hasHeatingUp then
                hasHeatingUp = false
                PrintDebugState("获得大括号 (消耗小括号)", true)
            end
        end
    end
end

----------------------------------------------------
-- Module Lifecycle
----------------------------------------------------

function FireMage:OnInitialize()
    WRA:PrintDebug("FireMage Module Initializing.")
end

function FireMage:OnEnable()
    WRA:PrintDebug("FireMage Module Enabling...")
    C, State, CD, Aura, Utils, TTD = WRA.Constants, WRA.StateManager, WRA.CooldownTracker, WRA.AuraMonitor, WRA.Utils, WRA.TTDTracker
    
    if WRA.db and WRA.db.profile and WRA.db.profile.specs then
        if not WRA.db.profile.specs.FireMage then
            WRA.db.profile.specs.FireMage = { maintainScorch = false }
        end
        DB = WRA.db.profile.specs.FireMage
    else
        WRA:PrintError("FireMage: Database not found!")
        DB = { maintainScorch = false } -- Fallback
    end
    
    fireMageCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    fireMageCombatLogFrame:SetScript("OnEvent", CombatLogHandler)
    hasHeatingUp = false -- Reset on enable
end

function FireMage:OnDisable()
    WRA:PrintDebug("FireMage Module Disabled.")
    fireMageCombatLogFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    fireMageCombatLogFrame:SetScript("OnEvent", nil)
end

----------------------------------------------------
-- Core Logic: IsReady & GetNextAction
----------------------------------------------------

function FireMage:IsReady(actionID, state)
    if not (Utils and C and Aura and state and state.player) then return false end
    
    if not IsPlayerSpell(actionID) or not Utils:IsReadyWithQueue({id = actionID}) then
        return false
    end
    
    return true
end

function FireMage:GetNextAction(currentState)
    if not (C and State and CD and Aura and Utils and TTD and currentState and currentState.player and currentState.target) then
        return { gcdAction = C.ACTION_ID_IDLE }
    end
    
    local player = currentState.player
    local target = currentState.target
    
    if not (target.exists and target.isEnemy and not target.isDead) then
        return { gcdAction = C.ACTION_ID_IDLE }
    end

    local hasHotStreak = Aura:HasBuff(C.Auras.HOT_STREAK, "player")
    local hasFirepower = Aura:HasBuff(C.Auras.FIREPOWER, "player")
    local firepowerRemaining = Aura:GetBuffRemaining(C.Auras.FIREPOWER, "player") or 0

    -- APL (Action Priority List) for Single Target - 技能优先级列表

    -- 1. 防吞噬逻辑 (Munching Protection)
    -- 当我们同时拥有“大括号”和“小括号”时，最优先打出炎爆术来消耗掉“大括号”。
    -- 这可以防止后续飞行途中的法术暴击时，新的“小括号”被“吞噬”。
    if hasHotStreak and hasHeatingUp then
        if self:IsReady(C.Spells.PYROBLAST, currentState) then
            return { gcdAction = C.Spells.PYROBLAST }
        end
    end
    
    -- 2. 活体炸弹 (高优先级刷新)
    -- 保持目标身上的活体炸弹debuff是最高伤害循环的一部分。
    -- 我们在这里检查它，确保它的优先级高于为了T10 Buff而打火球。
    local ttd = TTD:GetTTD(target.guid) or 999
    local livingBombRemaining = Aura:GetDebuffRemaining(C.Auras.LIVING_BOMB_DEBUFF, "target", true) or 0
    if ttd > 12 and livingBombRemaining < 1.5 then -- 如果活体炸弹即将结束或已消失，则刷新
        if self:IsReady(C.Spells.LIVING_BOMB, currentState) then
            return { gcdAction = C.Spells.LIVING_BOMB }
        end
    end

    -- 3. T10急速Buff优化 (“炎爆剪裁” Haste Weaving)
    -- 如果我们有“大括号”且身上有T10急速Buff，我们优先打一个火球术。
    -- 这是因为火球术的施法时间会“快照”我们开始施法时的急速，即使T10 Buff在施法过程中就结束了。
    -- 这使得我们可以多打出一个受急速加成的技能，从而最大化T10套装的收益。
    if hasHotStreak and hasFirepower then
        if self:IsReady(C.Spells.FIREBALL, currentState) then
            return { gcdAction = C.Spells.FIREBALL }
        end
    end

    -- 4. 法术连击 (常规)
    -- 如果有“大括号”但没有进入T10优化逻辑，正常打出炎爆术。
    if hasHotStreak then
        if self:IsReady(C.Spells.PYROBLAST, currentState) then
            return { gcdAction = C.Spells.PYROBLAST }
        end
    end

    -- 5. 火焰冲击 (移动时填充)
    if self:IsReady(C.Spells.FIRE_BLAST, currentState) then
        if player.isMoving then
            return { gcdAction = C.Spells.FIRE_BLAST }
        end
    end

    -- 6. 灼烧 (维持Debuff)
    if GetDBValue("maintainScorch", false) then
        local improvedScorchRemaining = Aura:GetDebuffRemaining(C.Auras.IMPROVED_SCORCH, "target") or 0
        if improvedScorchRemaining < 4 then
            if self:IsReady(C.Spells.SCORCH, currentState) then
                return { gcdAction = C.Spells.SCORCH }
            end
        end
    end

    -- 7. 火球术 (主要填充)
    if self:IsReady(C.Spells.FIREBALL, currentState) then
        return { gcdAction = C.Spells.FIREBALL }
    end

    return { gcdAction = C.ACTION_ID_IDLE }
end

----------------------------------------------------
-- Options Panel Definition
----------------------------------------------------
function WRA:GetSpecOptions_FireMage()
    return {
        fire_mage_header = {
            order = 1,
            type = "header",
            name = "火法设置",
        },
        maintainScorch = {
            order = 2,
            type = "toggle",
            name = "自动维持强化灼烧",
            desc = "开启后，如果目标身上没有强化灼烧debuff，插件会自动推荐你施放灼烧来补充。",
            get = function() return GetDBValue("maintainScorch", false) end,
            set = function(info, value) 
                local db = WRA.db.profile.specs.FireMage
                if db then db.maintainScorch = value end
            end,
        },
    }
end
