-- Core/StateModifier.lua
-- New module to temporarily override values in the state table.
-- This allows encounter modules to dynamically alter the perceived state
-- without changing the core logic of the StateManager or spec modules.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)

local StateModifier = WRA:NewModule("StateModifier", "AceTimer-3.0")

-- Lua shortcuts
local GetTime = GetTime
local wipe = table.wipe
local pairs = pairs
local string_gmatch = string.gmatch

-- Internal table to store active modifiers
-- Structure: { ["player.isMeleeUnsafe"] = { value = true, expiration = 12345.67 } }
local activeModifiers = {}
local cleanupTimer = nil
local CLEANUP_INTERVAL = 2 -- seconds

-- Safely sets a value in a nested table based on a string key like "player.healthPercent"
local function SetNestedValue(tbl, key, value)
    local keys = {}
    for k in string_gmatch(key, "[^%.]+") do
        table.insert(keys, k)
    end

    local current = tbl
    for i = 1, #keys - 1 do
        local k = keys[i]
        if not current[k] then
            current[k] = {}
        end
        current = current[k]
    end
    current[keys[#keys]] = value
end

-- --- Internal Functions ---

local function CleanupExpiredModifiers()


    local now = GetTime()
    for key, data in pairs(activeModifiers) do
        if data.expiration and data.expiration <= now then
            -- [Gemini] 核心修复：当一个状态因超时而过期时，不仅要从activeModifiers中移除，
            -- 还要从StateManager的实际状态表中移除该值，以防止状态被“卡住”。
            local state = WRA.StateManager:GetCurrentState()
            SetNestedValue(state, key, nil)
            activeModifiers[key] = nil
        end
    end
end

-- --- Module Lifecycle ---

function StateModifier:OnInitialize()
    wipe(activeModifiers)
    WRA:PrintDebug("StateModifier Initialized.")
end

function StateModifier:OnEnable()
    if not cleanupTimer then
        cleanupTimer = self:ScheduleRepeatingTimer(CleanupExpiredModifiers, CLEANUP_INTERVAL)
    end
    WRA:PrintDebug("StateModifier Enabled.")
end

function StateModifier:OnDisable()
    if cleanupTimer then
        self:CancelTimer(cleanupTimer)
        cleanupTimer = nil
    end
    self:ClearAll()
    WRA:PrintDebug("StateModifier Disabled.")
end

-- --- Public API ---

-- Add or update a state modifier.
-- @param key (string) The nested key in the state table (e.g., "player.isMeleeUnsafe").
-- @param value (any) The value to override with.
-- @param duration (number) How long the override should last, in seconds. Use a large number for permanent overrides within an encounter.
function StateModifier:Add(key, value, duration)

    if not key or duration <= 0 then return end
    
    activeModifiers[key] = {
        value = value,
        expiration = GetTime() + duration
    }
end

-- Remove a specific state modifier.
function StateModifier:Remove(key)

    if activeModifiers[key] then
        activeModifiers[key] = nil
        -- [Gemini] 核心修复：在移除一个状态时，必须同时从StateManager的实际状态表中移除该值。
        -- 这可以防止状态被“卡住”，确保状态的生命周期是可控的。
        local state = WRA.StateManager:GetCurrentState()
        SetNestedValue(state, key, nil)
    end
end

-- Clear all active modifiers. Typically called at the end of an encounter.
function StateModifier:ClearAll()
    -- [Gemini] 核心修复：在清除所有状态时，也必须遍历并从StateManager的实际状态表中移除它们。
    local state = WRA.StateManager:GetCurrentState()
    for key, _ in pairs(activeModifiers) do
        SetNestedValue(state, key, nil)
    end
    wipe(activeModifiers)
end

-- Applies all active overrides to a given state table.
-- This is called by the RotationEngine each tick.
function StateModifier:ApplyOverrides(stateTable)
    if not stateTable then return end
    

    local now = GetTime()
    for key, data in pairs(activeModifiers) do
        if not data.expiration or data.expiration > now then
            SetNestedValue(stateTable, key, data.value)
        end
    end
end
