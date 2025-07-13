-- File: Addon/WRA/Common/Utils.lua
-- Common utility functions for the WRA addon.
-- MODIFIED: Added IsActionReady_Common to centralize generic readiness checks.
-- MODIFIED V2: Fixed a bug in IsReadyWithQueue where it would incorrectly fail off-GCD abilities during a GCD.
-- MODIFIED V3 (Stance Fix): IsReadyWithQueue now intelligently ignores the main skill GCD when checking a stance-change ability.
-- MODIFIED V4 (Caster Fix): IsReadyWithQueue now correctly checks for the player's casting state, preventing suggestions during a cast.
-- MODIFIED V5 (Caster Leeway): IsReadyWithQueue now intelligently checks the player's casting state against the spell queue window, allowing for smoother spell chaining.
-- MODIFIED (Nitro Fix): Updated IsReadyWithQueue to correctly check SpellData for item properties like isOffGCD.

local addonName, _ = ... -- Get addon name, don't rely on WRA from here
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")

-- Get the main addon object instance (must be created in WRA.lua first)
local WRA = AceAddon:GetAddon(addonName)

-- Lua function shortcuts
local string_match = string.match
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local pairs = pairs
local type = type
local tonumber = tonumber -- Added tonumber shortcut

-- Create the Utils module *on the main addon object*
local Utils = WRA:NewModule("Utils")
WRA.Utils = Utils -- Make accessible via WRA.Utils

-- WoW API localization
local GetSpellCooldown = _G.GetSpellCooldown
local GetItemCooldown = _G.GetItemCooldown
local GetTime = _G.GetTime
local UnitCanAttack = _G.UnitCanAttack
local IsCurrentSpell = _G.IsCurrentSpell
local IsUsableSpell = _G.IsUsableSpell
local IsUsableItem = _G.IsUsableItem

-- Constants (Fetch from main addon object - ensure Constants loaded first)
-- Get Constants reference safely after WRA object is retrieved
local Constants = WRA.Constants
-- Use a default if Constants module isn't ready during init phase
local GCD_THRESHOLD = (Constants and Constants.GCD_THRESHOLD) or 0.1

-- --- Utility Functions ---

-- Get the remaining global cooldown (using a reference spell)
function Utils:GetGCDRemaining(refSpellID)
    refSpellID = refSpellID or 61304 -- Default reference: Spell Reflection (Warrior)

    local start, duration, enabled = GetSpellCooldown(refSpellID)

    if not start or start == 0 or enabled == 0 then return 0 end
    if duration == 0 then return 0 end
    if duration > 1.6 then return 0 end

    local elapsed = GetTime() - start
    local remaining = duration - elapsed

    return remaining < 0 and 0 or remaining
end

function Utils:IsReadyWithQueue(action)
    if not action or not action.id then
        return false
    end

    local tolerance = (WRA.db.profile.spellQueueWindow or 100) / 1000
    local actionID = action.id
    local isItem = actionID < 0

    -- 1. Check if the action is Off-GCD
    local isOffGCD = false
    -- [!code ++]
    -- *** FIX: Check SpellData for item properties as well ***
    if WRA.Constants and WRA.Constants.SpellData and WRA.Constants.SpellData[actionID] then
        isOffGCD = WRA.Constants.SpellData[actionID].isOffGCD
    end
    -- [!code --]

    -- 2. Check if player is currently casting/channeling, considering the spell queue window
    local playerState = WRA.StateManager:GetCurrentState().player
    if not isOffGCD then
        if playerState.isCasting then
            local castRemaining = playerState.castEndTime - GetTime()
            -- If the remaining cast time is greater than the tolerance, we are not ready.
            if castRemaining > tolerance then
                return false 
            end
        elseif playerState.isChanneling then
            local channelRemaining = playerState.channelEndTime - GetTime()
            -- If the remaining channel time is greater than the tolerance, we are not ready.
            if channelRemaining > tolerance then
                return false
            end
        end
    end

    -- 3. Check the action's own cooldown
    local start, duration
    if isItem then
        start, duration = GetItemCooldown(math.abs(actionID))
    else
        start, duration = GetSpellCooldown(actionID)
    end

    if start and start > 0 and duration and duration > 0 then
        local remaining = duration - (GetTime() - start)
        if remaining > tolerance then
            return false
        end
    end
    
    -- 4. Check the main skill GCD
    if not isOffGCD then
        local isStanceChange = WRA.Constants.StanceMap and WRA.Constants.StanceMap[actionID]
        if not isStanceChange then
            local gcdRemaining = self:GetGCDRemaining() 
            if gcdRemaining > tolerance then
                return false
            end
        end
    end

    -- 5. Final usability check (mana, range, etc.)
    local isUsable
    if isItem then
        isUsable = IsUsableItem(math.abs(actionID))
    else
        isUsable, _ = IsUsableSpell(actionID)
    end
    
    if not isUsable then
        return false
    end

    return true
end


-- Checks if the GCD is ready (less than threshold remaining)
function Utils:IsGCDReady(refSpellID)
    return (WRA.StateManager and WRA.StateManager:GetCurrentState().player.isGCDActive == false) or (self:GetGCDRemaining(refSpellID) < GCD_THRESHOLD)
end

-- Get the remaining cooldown for a given spell by its SpellID
function Utils:GetTimeToSpell(spellId)
    if not spellId then return 999 end 
    local start, duration, enabled = GetSpellCooldown(spellId)

    if not start or start == 0 or enabled == 0 then return 0 end 
    if duration == 0 then return 0 end 

    local elapsed = GetTime() - start
    local remaining = duration - elapsed

    return remaining < 0 and 0 or remaining
end

-- Check if a spell is ready (cooldown finished) using the ad-hoc check.
function Utils:IsSpellReady(spellId)
    return (WRA.CooldownTracker and WRA.CooldownTracker:IsReady(spellId)) or (self:GetTimeToSpell(spellId) < GCD_THRESHOLD)
end

-- Clamp number between min/max
function Utils:Clamp(value, minVal, maxVal)
    return math_max(minVal, math_min(value, maxVal))
end

-- Round number to specified decimals
function Utils:Round(value, decimals)
    if not decimals then decimals = 0 end
    local mult = 10^decimals
    return math_floor(value * mult + 0.5) / mult
end

-- Extract Spell ID from a Spell GUID (Combat Log Event format)
function Utils:GetSpellIdFromGUID(guidString)
    if not guidString or type(guidString) ~= "string" then return nil end
    local spellId = string_match(guidString, ":Spell:(%d+):")
    if spellId then return tonumber(spellId) or 0 end
    spellId = string_match(guidString, "Spell_*(%d+)")
    if spellId then return tonumber(spellId) or 0 end
    spellId = string_match(guidString, "(%d%d%d+)")
    if spellId then return tonumber(spellId) or 0 end
    return 0
end

-- Count the number of key-value pairs in a table
function Utils:CountTable(tbl)
    if type(tbl) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function Utils:GetTableCopy(originalTable)
    if type(originalTable) ~= "table" then return originalTable end
    local copy = {}
    for k, v in pairs(originalTable) do
        copy[k] = self:GetTableCopy(v)
    end
    return copy
end

function Utils:IsActionReady_Common(actionID, state, skipGCDCheck)
    local C = WRA.Constants
    local CD = WRA.CooldownTracker
    local State = WRA.StateManager

    if not (C and CD and State and state and state.player) then return false end
    if not actionID then return false end

    local player = state.player
    if player.isDead or player.isFeigning then return false end

    local spellData = C.SpellData and C.SpellData[actionID]
    local isItem = actionID < 0
    
    local isOffGCDAction = spellData and spellData.isOffGCD

    if not skipGCDCheck then
        if not isOffGCDAction and player.isGCDActive then return false end
        if not isOffGCDAction and (player.isCasting or player.isChanneling) then return false end
    end

    if isItem then
        if not CD:IsItemReady(actionID) then return false end
    else
        if not CD:IsSpellReady(actionID) then return false end
    end
    
    local activeSpec = WRA.SpecLoader:GetActiveSpecModule()
    local cost = 0
    if activeSpec and activeSpec.GetActionCost then
        cost = activeSpec:GetActionCost(actionID)
    else
        cost = (spellData and spellData.cost) or 0
    end
    
    if WRA.AuraMonitor and actionID == C.Spells.SLAM and WRA.AuraMonitor:HasBuff(C.Auras.OMEN_OF_CLARITY, "player") then
        cost = 0
    end

    if not isOffGCDAction and player.power < cost then return false end
    if isOffGCDAction and player.power < cost then return false end

    return true
end


-- --- Module Lifecycle ---
function Utils:OnInitialize()
    if not Constants and WRA.Constants then Constants = WRA.Constants end
    if Constants and Constants.GCD_THRESHOLD then GCD_THRESHOLD = Constants.GCD_THRESHOLD end
    WRA:PrintDebug("Utils Initialized")
end

function Utils:OnEnable()
    WRA:PrintDebug("Utils Enabled")
end

function Utils:OnDisable()
    WRA:PrintDebug("Utils Disabled")
end
