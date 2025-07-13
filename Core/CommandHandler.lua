-- File: Addon/WRA/Core/CommandHandler.lua
-- [Gemini Edit] MODIFIED: Added special handling for "nitro" or "火箭靴" to the insert command, allowing manual activation of Nitro Boosts.

local addonName, _ = ...
local AceAddon = LibStub("AceAddon-3.0")
local WRA = AceAddon:GetAddon(addonName)

local CommandHandler = WRA:NewModule("CommandHandler")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local string_lower = string.lower
local string_match = string.match
local tonumber = tonumber

-- Function to find a spell ID from a name or ID string.
local function FindActionID(nameOrID)
    if not nameOrID then return nil end
    local lookup = string_lower(nameOrID)

    local activeSpec = WRA.SpecLoader:GetActiveSpecModule()
    if not activeSpec or not activeSpec.ClassConstants then
        return tonumber(lookup)
    end
    local CC = activeSpec.ClassConstants
    
    if CC.CommandAliases and CC.CommandAliases[lookup] then
        local id = CC.CommandAliases[lookup]
        if type(id) == "number" then return id end
    end

    if tonumber(lookup) then
        return tonumber(lookup)
    end
    
    if CC.Spells then
        for spellName, spellId in pairs(CC.Spells) do
            if string_lower(spellName) == lookup then
                return spellId
            end
        end
    end

    return nil
end


function CommandHandler:HandleSetCommand(input)
    if not input or input == "" then
        WRA:Print("Usage: /wra set <option> [value]")
        return
    end

    local key, value = string_match(input, "^(%S+)%s*(.*)$")
    key = key and string_lower(key)
    value = value and string_lower(value)

    if not key then
        WRA:Print("Invalid command format. Usage: /wra set <option> [value]")
        return
    end

    local specKey = WRA.SpecLoader:GetCurrentSpecKey()
    if not specKey then
        WRA:Print("No active specialization found.")
        return
    end

    local activeSpec = WRA.SpecLoader:GetActiveSpecModule()
    if activeSpec and activeSpec.ClassConstants and activeSpec.ClassConstants.CommandAliases then
        local CC = activeSpec.ClassConstants
        if CC.CommandAliases[key] then
            key = string_lower(CC.CommandAliases[key])
        end
    end

    local getOptionsFunc = WRA["GetSpecOptions_" .. specKey]
    if not getOptionsFunc then
        WRA:Print("Could not find options for current spec:", specKey)
        return
    end

    local optionsTable = getOptionsFunc(WRA)
    local optionInfo = nil
    local originalKey = nil

    for optionKey, optionData in pairs(optionsTable) do
        if string_lower(optionKey) == key then
            optionInfo = optionData
            originalKey = optionKey
            break
        end
    end

    if not optionInfo then
        WRA:Print("WRA: Option not found: " .. key)
        return
    end

    if not optionInfo.set or type(optionInfo.set) ~= "function" then
        WRA:Print("Option", originalKey, "cannot be set via command.")
        return
    end

    local info = { [1] = "specs", [2] = specKey, [3] = originalKey }
    local finalValue

    if optionInfo.type == "toggle" then
        if value == "on" or value == "1" or value == "true" then
            finalValue = true
        elseif value == "off" or value == "0" or value == "false" then
            finalValue = false
        else 
            local currentValue = optionInfo.get()
            finalValue = not currentValue
        end
        optionInfo.set(info, finalValue)

    elseif optionInfo.type == "select" then
        local foundValue = false
        if optionInfo.values then
            for v_key, v_text in pairs(optionInfo.values) do
                if string_lower(tostring(v_key)) == value then
                    finalValue = v_key
                    foundValue = true
                    break
                end
            end
        end

        if foundValue then
            optionInfo.set(info, finalValue)
        else
            WRA:Print("Invalid value for option '" .. originalKey .. "'. Possible values are:")
            for v_key, v_text in pairs(optionInfo.values) do
                WRA:Print("- " .. tostring(v_key))
            end
        end

    elseif optionInfo.type == "range" then
        finalValue = tonumber(value)
        if finalValue then
            optionInfo.set(info, finalValue)
        else
            WRA:Print("Invalid numeric value for option '" .. originalKey .. "'.")
        end
        
    else
        WRA:Print("Unsupported option type for command line:", optionInfo.type)
    end
end


function CommandHandler:HandleInsertCommand(input)
    if not input or input == "" then
        WRA:Print("Usage: /wra insert <spell_name_or_id_or_alias>")
        return
    end

    -- [Gemini Edit] Add special handling for Nitro Boosts
    local lookup = string_lower(input)
    if lookup == "nitro" or lookup == "火箭靴" then
        if WRA.NitroBoots and WRA.NitroBoots.Activate then
            -- [Gemini] 改进：检查Activate的返回值以提供用户反馈。
            local success = WRA.NitroBoots:Activate()
            if success then
                WRA:Print("WRA: 手动激活火箭靴...")
            else
                -- 如果激活失败（很可能因为正在冷却），通知用户。
                WRA:Print(L["NITRO_BOOTS_ON_COOLDOWN"] or "火箭靴正在冷却中。")
            end
        else
            WRA:PrintError("NitroBoots 模块不可用。")
        end
        return -- Exit after handling the special case
    end

    local actionID = FindActionID(input)

    if actionID then
        if WRA.ManualQueue and WRA.ManualQueue.QueueActions then
            WRA.ManualQueue:QueueActions({actionID})
            local spellName = GetSpellInfo(actionID) or "Unknown Action"
            WRA:SendMessage("WRA_NOTIFICATION_SHOW", "手动插入: " .. spellName)
        else
            WRA:PrintError("ManualQueue module not available or outdated.")
        end
    else
        WRA:Print("无法识别的技能或别名:", input)
    end
end

function CommandHandler:HandleComboCommand(input)
    if not input or input == "" then
        WRA:Print("Usage: /wra combo <combo_alias>")
        return
    end

    local lookup = string_lower(input)
    local activeSpec = WRA.SpecLoader:GetActiveSpecModule()
    
    if not activeSpec or not activeSpec.ClassConstants or not activeSpec.ClassConstants.CommandCombos then
        WRA:Print("当前专精没有定义组合技能。")
        return
    end

    local CC = activeSpec.ClassConstants
    local spellList = CC.CommandCombos[lookup]

    if spellList and type(spellList) == "table" then
        if WRA.ManualQueue and WRA.ManualQueue.QueueActions then
            WRA.ManualQueue:QueueActions(spellList)
            WRA:SendMessage("WRA_NOTIFICATION_SHOW", "手动插入组合技能: " .. input)
        else
            WRA:PrintError("ManualQueue module not available or outdated.")
        end
    else
        WRA:Print("未找到组合技能别名:", input)
    end
end

function CommandHandler:OnInitialize()
    WRA:PrintDebug("CommandHandler Initialized")
end
