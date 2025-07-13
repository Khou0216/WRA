-- Common/CooldownTracker.lua
-- Tracks cooldowns for registered spells and items.
-- MODIFIED: Refactored GetCooldownRemaining and IsReady to be more robust against cache misses by adding a fallback to the live WoW API.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")

local WRA = AceAddon:GetAddon(addonName)

local AceEvent = LibStub("AceEvent-3.0", true)
if not AceEvent then
    WRA:PrintError("CooldownTracker: Missing AceEvent!")
    return
end

local CooldownTracker = WRA:NewModule("CooldownTracker", "AceEvent-3.0")
WRA.CooldownTracker = CooldownTracker

-- WoW API & Lua shortcuts
local GetSpellCooldown = _G.GetSpellCooldown
local GetItemCooldownFunc = _G.GetItemCooldown or (_G.C_Container and _G.C_Container.GetItemCooldown) or function() return 0, 0, 0 end
local GetTime = _G.GetTime
local pairs = pairs
local wipe = wipe
local type = type

-- Module Variables
local trackedSpells = {} -- { [spellId] = true }
local trackedItems = {}  -- { [itemId] = true }
local cooldowns = {}     -- { [id] = { startTime, duration, isItem } }
local GCD_MAX_DURATION = 1.51
local READY_THRESHOLD = 0.1

-- Internal function to update the cooldown cache from game events
local function UpdateCooldownCache(id, isItem)
    local startTime, duration, enabled
    if isItem then
        startTime, duration, enabled = GetItemCooldownFunc(id)
    else
        startTime, duration, enabled = GetSpellCooldown(id)
    end
    
    local cache = cooldowns[id]

    if enabled == 0 or not startTime or startTime == 0 or not duration or duration <= 0 then
        -- Cooldown is not active or has finished
        if cache then
            cooldowns[id] = nil
        end
        return
    end

    -- Cooldown is active, update or create cache entry
    if not cache or cache.startTime ~= startTime or cache.duration ~= duration then
        cooldowns[id] = cache or {}
        cooldowns[id].startTime = startTime
        cooldowns[id].duration = duration
        cooldowns[id].isItem = isItem
    end
end

function CooldownTracker:OnInitialize()
    trackedSpells = {}
    trackedItems = {}
    wipe(cooldowns)
    WRA:PrintDebug("CooldownTracker Initialized")
end

function CooldownTracker:OnEnable()
    WRA:PrintDebug("CooldownTracker Enabled")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "EventHandler")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN", "EventHandler")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "EventHandler")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "FullCooldownScan")
    self:FullCooldownScan()
end

function CooldownTracker:OnDisable()
    WRA:PrintDebug("CooldownTracker Disabled")
    self:UnregisterAllEvents()
    wipe(trackedSpells)
    wipe(trackedItems)
    wipe(cooldowns)
end

function CooldownTracker:EventHandler(event, ...)
    if event == "SPELL_UPDATE_COOLDOWN" then
        for spellId in pairs(trackedSpells) do UpdateCooldownCache(spellId, false) end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        for itemId in pairs(trackedItems) do UpdateCooldownCache(itemId, true) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitId, _, spellId = ...
        if unitId == "player" and spellId and trackedSpells[spellId] then
            UpdateCooldownCache(spellId, false)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:FullCooldownScan()
    end
end

function CooldownTracker:FullCooldownScan()
    WRA:PrintDebug("Performing full cooldown scan...")
    for spellId in pairs(trackedSpells) do UpdateCooldownCache(spellId, false) end
    for itemId in pairs(trackedItems) do UpdateCooldownCache(itemId, true) end
end

function CooldownTracker:TrackSpell(spellId)
    if not spellId or type(spellId) ~= "number" or spellId == 0 then return end
    if not trackedSpells[spellId] then
        WRA:PrintDebug("Now tracking spell ID:", spellId)
        trackedSpells[spellId] = true
        UpdateCooldownCache(spellId, false)
    end
end

function CooldownTracker:UntrackSpell(spellId)
     if not spellId or type(spellId) ~= "number" then return end
     if trackedSpells[spellId] then
        WRA:PrintDebug("Stopped tracking spell ID:", spellId)
        trackedSpells[spellId] = nil
        cooldowns[spellId] = nil
     end
end

function CooldownTracker:TrackItem(itemId)
    if not itemId or type(itemId) ~= "number" or itemId == 0 then return end
    if not trackedItems[itemId] then
        WRA:PrintDebug("Now tracking item ID:", itemId)
        trackedItems[itemId] = true
        UpdateCooldownCache(itemId, true)
    end
end

function CooldownTracker:UntrackItem(itemId)
    if not itemId or type(itemId) ~= "number" then return end
    if trackedItems[itemId] then
        WRA:PrintDebug("Stopped tracking item ID:", itemId)
        trackedItems[itemId] = nil
        cooldowns[itemId] = nil
    end
end

-- *** NEW ROBUST GetCooldownRemaining FUNCTION ***
function CooldownTracker:GetCooldownRemaining(id)
    if not id then return 0 end

    -- Check cache first
    local cd = cooldowns[id]
    if cd and cd.startTime and cd.duration then
        local elapsed = GetTime() - cd.startTime
        local remaining = cd.duration - elapsed
        return remaining > 0 and remaining or 0
    end

    -- If not in cache, query the API directly as a fallback.
    -- We need to know if it's a spell or item. Check our tracking lists.
    local startTime, duration
    if trackedSpells[id] then
        startTime, duration = GetSpellCooldown(id)
    elseif trackedItems[id] then
        startTime, duration = GetItemCooldownFunc(id)
    else
        -- It's an untracked ability. We assume it's a spell for the API call.
        startTime, duration = GetSpellCooldown(id)
    end

    if startTime and startTime > 0 and duration and duration > 0 then
        local elapsed = GetTime() - startTime
        local remaining = duration - elapsed
        return remaining > 0 and remaining or 0
    end

    return 0 -- Not on cooldown
end

-- *** NEW SIMPLIFIED IsReady FUNCTION ***
function CooldownTracker:IsReady(id)
    if not id then return true end
    -- A spell/item is ready if its remaining cooldown is less than a small threshold.
    -- This now implicitly uses the robust GetCooldownRemaining function.
    return self:GetCooldownRemaining(id) < READY_THRESHOLD
end

function CooldownTracker:IsSpellReady(spellId)
    return self:IsReady(spellId)
end

function CooldownTracker:IsItemReady(itemId)
    return self:IsReady(itemId)
end

function CooldownTracker:GetCooldownDuration(id)
     if not id then return 0 end
     local cd = cooldowns[id]
     return (cd and cd.duration and cd.duration > GCD_MAX_DURATION) and cd.duration or 0
end
