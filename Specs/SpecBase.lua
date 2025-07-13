-- Specs/SpecBase.lua
-- Provides a base "class" for all specialization modules to inherit from.
-- This ensures a consistent API and allows for shared default functionality.

local addonName, _ = ...
local WRA = LibStub("AceAddon-3.0"):GetAddon(addonName)

local SpecBase = {}
WRA.SpecBase = SpecBase -- Register the base class to the main addon object

--[[
    Default method to get the resource cost of an action.
    Spec modules can override this to account for talents, set bonuses, etc.
]]
function SpecBase:GetActionCost(actionID)
    if WRA.Constants and WRA.Constants.SpellData and WRA.Constants.SpellData[actionID] then
        return WRA.Constants.SpellData[actionID].cost or 0
    end
    return 0
end

--[[
    Placeholder methods to define the standard API for all spec modules.
]]
function SpecBase:OnInitialize() end
function SpecBase:OnEnable() end
function SpecBase:OnDisable() end

function SpecBase:IsReady(actionID, state, skipGCDCheckOverride)
    -- Default implementation returns true if the common checks pass.
    -- Specs should override this for their unique logic.
    return WRA.Utils:IsActionReady_Common(actionID, state, skipGCDCheckOverride)
end

function SpecBase:GetNextAction(currentState)
    -- Default implementation returns IDLE.
    return { gcdAction = WRA.Constants.ACTION_ID_IDLE, offGcdAction = nil }
end
