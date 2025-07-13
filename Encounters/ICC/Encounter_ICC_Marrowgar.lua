-- Encounters/ICC/Encounter_ICC_Marrowgar.lua
-- Tactical module for the Lord Marrowgar encounter in Icecrown Citadel.

local addonName, _ = ...
local LibStub = LibStub
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)

-- Create the module and inherit from EncounterBase
local MarrowgarEncounter = WRA:NewModule("Encounter_ICC_Marrowgar", "AceEvent-3.0")
if WRA.EncounterBase then
    setmetatable(MarrowgarEncounter, { __index = WRA.EncounterBase })
end

-- Module references
local StateModifier = nil

-- DBM Timer/Event names for Marrowgar
local BONE_STORM_EVENT = "骨刺风暴" -- 假设这是DBM在zhCN客户端中对白骨风暴的提示

function MarrowgarEncounter:OnInitialize()
    StateModifier = WRA:GetModule("StateModifier")
end

function MarrowgarEncounter:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
    -- Call base method for logging
    if self.super and self.super.OnEncounterStart then
        self.super:OnEncounterStart(self, encounterID, encounterName, difficultyID, groupSize)
    else
        WRA:PrintDebug(self:GetName(), "started. ID:", encounterID, "Name:", encounterName)
    end
    
    if not StateModifier then
        StateModifier = WRA:GetModule("StateModifier")
        if not StateModifier then
            WRA:PrintError(self:GetName() .. ": StateModifier module not found!")
            return
        end
    end

    -- Register for DBM announcements to detect Bone Storm
    -- We use DBM_Announce as it's a common way DBM signals major abilities.
    self:RegisterMessage("DBM_Announce", "HandleDBMAnnounce")
    WRA:PrintDebug(self:GetName() .. ": Registered for DBM messages.")
end

function MarrowgarEncounter:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    if self.super and self.super.OnEncounterEnd then
        self.super:OnEncounterEnd(self, encounterID, encounterName, difficultyID, groupSize, success)
    else
        WRA:PrintDebug(self:GetName(), "ended. Success:", tostring(success))
    end

    -- Clean up everything we did
    self:UnregisterMessage("DBM_Announce")
    if StateModifier then
        StateModifier:ClearAll()
    end
    WRA:PrintDebug(self:GetName() .. ": Cleaned up all registered events and state modifiers.")
end

-- Handler for DBM announcements
function MarrowgarEncounter:HandleDBMAnnounce(event, msg)
    -- Check if the announcement is for Bone Storm
    if msg and msg:find(BONE_STORM_EVENT) then
        WRA:PrintDebug(self:GetName() .. ": Bone Storm detected!")
        
        -- Apply a state modifier for 10 seconds (duration of Bone Storm)
        -- This tells the RotationEngine that melee should run away.
        if StateModifier then
            StateModifier:Add("player.isMeleeUnsafe", true, 10)
        end
    end
end
