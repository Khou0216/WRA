-- WRA/Utilities/TacticalTrigger_Conditions.lua
-- 在此文件中定义高级的、基于代码的战术触发器。
-- 这是为高级用户准备的，允许您编写复杂的逻辑来激活火箭靴等战术技能。

local addonName, _ = ...
local WRA = LibStub("AceAddon-3.0"):GetAddon(addonName)

-- 这是您的触发器定义表。
-- 您可以在 "triggers" 表中添加任意数量的触发器定义。
local Conditions = {
    -- 每个触发器都是一个表，包含:
    -- name: (字符串) 触发器的描述性名称，用于调试。
    -- events: (表) 一个包含此触发器需要监听的战斗日志子事件的列表。
    -- condition: (函数) 核心逻辑函数。它接收战斗日志事件的参数，并返回true（触发）或false（不触发）。
    triggers = {
        
        -- 这里是您添加自定义触发器的地方。
        
        -- 巫妖王 - 污染 (采用WeakAuras的延迟检查逻辑)
        {
            name = "巫妖王 - 污染",
            events = { "SPELL_CAST_START" }, -- 步骤1：监听法术开始施放事件
            condition = function(...)
                local spellId = select(12, ...)
                
                -- [Gemini] 优化：使用常量替代硬编码的ID，提高可读性。
                if spellId == WRA.Constants.BossAbilities.DEFILE then
                    -- 条件初步满足，但不立即触发。
                    -- 而是安排一个0.2秒后的延迟检查，模仿WA的行为。
                    WRA:ScheduleTimer(function()
                        -- 步骤2：在延迟后，检查Boss的目标是否是玩家。
                        -- 我们遍历boss1到boss4，这是最通用的找到Boss单位的方法。
                        for i = 1, 4 do
                            local bossUnit = "boss" .. i
                            if UnitExists(bossUnit) and UnitCanAttack("player", bossUnit) then
                                -- UnitIsUnit() 是检查两个单位是否是同一个的最可靠方法。
                                if UnitIsUnit(bossUnit .. "target", "player") then
                                    -- 确认玩家是目标！现在发送一个内部消息来最终触发逻辑。
                                    -- [Gemini] 优化：发送一个包含更多信息的表（payload），
                                    -- 而不仅仅是触发器名称。这使得系统更具扩展性，
                                    -- 未来可以轻松地让触发器激活不同的动作（如工程手套）。
                                    local payload = { triggerName = "巫妖王 - 污染", action = "NitroBoots" }
                                    WRA:SendMessage("WRA_EXECUTE_TACTICAL_TRIGGER", payload)
                                    return -- 找到目标，停止检查
                                end
                            end
                        end
                    end, 0.2)
                end
                
                -- 这个初始条件函数总是返回false，因为它只负责安排延迟检查。
                return false
            end
        },
        {
            name = "战斗日志测试 - 治疗之触",
            events = { "SPELL_CAST_START" }, -- 监听法术开始施放事件
            condition = function(...)
                -- [Gemini] 临时测试触发器：用于验证战斗日志监控
                -- 要进行测试，请对自己施放“治疗之触”。
                -- 如果火箭靴被激活，则说明战斗日志监控系统工作正常。
                -- 测试完成后，请务必删除此部分代码。
                WRA:PrintDebug("[TacticalTrigger Condition] '治疗之触' condition function called.")
                local sourceGUID = select(4, ...)
                local spellId = select(12, ...)
                WRA:PrintDebug(string.format("[TacticalTrigger Condition] Args: source=%s, spellId=%s", tostring(sourceGUID), tostring(spellId)))

                -- [Gemini] 修复：SPELL_CAST_START 事件中的 destGUID 可能不可靠或为空。
                -- 我们改为使用 UnitIsUnit("target", "player") 来可靠地检查施法目标是否为玩家自己。
                -- 这也更好地模拟了“污染”触发器的逻辑，即使用可靠的API调用来确认目标。
                if sourceGUID == WRA.playerGUID and spellId == 48378 and UnitIsUnit("target", "player") then
                    WRA:PrintDebug("[TacticalTrigger Condition] Condition MET! Firing trigger.")
                    WRA:PrintDebug("[TacticalTrigger Test] Detected self-cast Healing Touch. Firing trigger.")
                    local payload = { triggerName = "战斗日志测试", action = "NitroBoots" }
                    WRA:SendMessage("WRA_EXECUTE_TACTICAL_TRIGGER", payload)
                    return true -- 明确表示触发成功
                end
                return false
            end,
        },
    }
}

-- 将这个表注册到插件中，以便TacticalTrigger模块可以访问它。
WRA:NewModule("TacticalTrigger_Conditions", Conditions)
