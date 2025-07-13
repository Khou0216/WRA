-- WRA/Locales/zhCN.lua
-- 简体中文本地化文件 (最终完整版)
-- MODIFIED: Added Retribution Paladin options.
-- MODIFIED: Added Feral Druid options.
-- MODIFIED: Added Fire Mage options.
-- MODIFIED: Added more specific options for all Warrior specs.

local L = LibStub("AceLocale-3.0"):NewLocale("WRA", "zhCN", false) -- 设置为非默认语言
if not L then return end

-- ===================================================================
-- ==                          通用 & 核心                           ==
-- ===================================================================
L["WRA_ADDON_NAME"] = "WRA 助手"
L["WRA_ADDON_DESCRIPTION"] = "一个强大的技能循环和战斗辅助插件。"
L["CONFIGURATION_FOR_WRA"] = "WRA 设置"
L["SETTINGS_PANEL_TITLE"] = "设置"
L["PROFILES_PANEL_TITLE"] = "配置文件"
L["Addon Loaded"] = "插件已加载"
L["Addon Enabled"] = "插件已启用"
L["Addon Disabled"] = "插件已禁用"
L["Usage: /wra [config|quick|reset|toggle|insert]"] = "用法: /wra [config|quick|reset|toggle|insert]"
L["Profiles"] = "配置文件"
L["config"] = "设置"
L["quick"] = "快捷"
L["reset"] = "重置"
L["toggle"] = "开关"

-- ===================================================================
-- ==                        主设置面板 & 标签                         ==
-- ===================================================================
L["TAB_GENERAL"] = "通用"
L["TAB_FURY_WARRIOR"] = "狂暴战"
L["TAB_DISPLAY"] = "显示"
L["FireMage"] = "火焰法师"
L["FuryWarrior"] = "狂暴战"
L["ProtectionWarrior"] = "防护战"
L["FeralDruid"] = "野性德鲁伊"
L["ProtectionPaladin"] = "防护圣骑士"
L["RetributionPaladin"] = "惩戒骑"
L["SPEC_SETTINGS_HEADER"] = "专精设置"
L["SPEC_SETTINGS_UNKNOWN_SPEC"] = "未知专精"

-- ===================================================================
-- ==                        通用设置 (General)                      ==
-- ===================================================================
L["GENERAL_SETTINGS_HEADER"] = "通用设置"
L["ENABLE_ADDON_NAME"] = "启用 WRA 助手"
L["ENABLE_ADDON_DESC"] = "完全启用或禁用此插件。"
L["ENABLE_OOC_SUGGESTIONS_NAME"] = "启用非战斗状态提示"
L["ENABLE_OOC_SUGGESTIONS_DESC"] = "如果启用，即使不在战斗中，只要选中了有效的敌对目标，就会显示技能建议。"
L["DEBUG_MODE_NAME"] = "调试模式"
L["DEBUG_MODE_DESC"] = "启用详细的调试信息输出到聊天框（主要供开发者使用）。"
L["spellQueueWindow"] = "施法容限 (ms)"
L["spellQueueWindow_desc"] = "设置一个时间（毫秒），提前进入可施法状态以利用服务器的施法队列机制。建议值在50到200之间，具体取决于您的网络延迟。"
L["USE_ENGINEERING_GLOVES_NAME"] = "使用工程手套"
L["USE_ENGINEERING_GLOVES_DESC"] = "在爆发阶段自动使用超级加速器。"
L["USE_NITRO_BOOTS_NAME"] = "自动使用火箭靴"
L["USE_NITRO_BOOTS_DESC"] = "当你在战斗中移动时，自动使用硝化甘油推进器。"
L["NITRO_BOOTS_ON_COOLDOWN"] = "火箭靴正在冷却中。"

-- ===================================================================
-- ==                          显示设置 (Display)                    ==
-- ===================================================================
L["DISPLAY_SETTINGS_HEADER"] = "显示设置"
L["DISPLAY_SETTINGS_HEADER_DESC"] = "配置建议显示的出现和行为。"
L["DISPLAY_MANAGER_SETTINGS_HEADER"] = "显示管理器设置"
L["SELECT_DISPLAY_MODE_NAME"] = "显示模式"
L["SELECT_DISPLAY_MODE_DESC"] = "选择技能建议的视觉样式。"
L["NO_DISPLAY_MODULES_REGISTERED"] = "没有已注册的显示模块"
L["Icons"] = "图标"

-- Display_Icons Settings
L["ICON_DISPLAY_SETTINGS_HEADER"] = "图标显示设置"
L["MAIN_ICON_SETTINGS_HEADER"] = "主提示图标"
L["LOCK_MAIN_ICONS_NAME"] = "锁定主图标位置"
L["LOCK_MAIN_ICONS_DESC"] = "锁定主技能提示图标的位置。"
L["MAIN_ICONS_SCALE_NAME"] = "主图标缩放"
L["MAIN_ICONS_SCALE_DESC"] = "调整主技能提示图标的大小。"
L["MAIN_ICONS_ALPHA_NAME"] = "主图标透明度"
L["MAIN_ICONS_ALPHA_DESC"] = "调整主技能提示图标的透明度。"
L["GCD_ICON_SIZE_NAME"] = "主技能图标尺寸"
L["GCD_ICON_SIZE_DESC"] = "主GCD提示图标的大小（副GCD图标会相对缩放）。"
L["SHOW_OFFGCD_ICON_SLOT_NAME"] = "显示副技能图标槽"
L["SHOW_OFFGCD_ICON_SLOT_DESC"] = "为不占公共冷却时间的技能建议显示一个独立的图标槽。"
L["RESET_MAIN_ICONS_POS_NAME"] = "重置主图标位置"

L["COLOR_BLOCK_GROUP_SETTINGS_HEADER"] = "颜色块设置"
L["SHOW_COLOR_BLOCK_GROUP_NAME"] = "显示颜色块组"
L["SHOW_COLOR_BLOCK_GROUP_DESC"] = "显示由主技能和副技能颜色块组成的指示器。"
L["LOCK_COLOR_BLOCK_CONTAINER_NAME"] = "锁定颜色块位置"
L["LOCK_COLOR_BLOCK_CONTAINER_DESC"] = "锁定颜色块容器的位置。"
L["COLOR_BLOCK_WIDTH_NAME"] = "颜色块宽度"
L["COLOR_BLOCK_WIDTH_DESC"] = "每个独立颜色块的宽度。"
L["COLOR_BLOCK_HEIGHT_NAME"] = "颜色块高度"
L["COLOR_BLOCK_HEIGHT_DESC"] = "每个独立颜色块的高度。"
L["COLOR_BLOCK_SPACING_NAME"] = "颜色块间距"
L["COLOR_BLOCK_SPACING_DESC"] = "主技能和副技能颜色块之间的间距。"
L["SHOW_GCD_BLOCK_INDIV_NAME"] = "显示主技能颜色块"
L["SHOW_GCD_BLOCK_INDIV_DESC"] = "（当颜色块组显示时）特别显示主技能的颜色块。"
L["SHOW_OFFGCD_BLOCK_INDIV_NAME"] = "显示副技能颜色块"
L["SHOW_OFFGCD_BLOCK_INDIV_DESC"] = "（当颜色块组显示时）特别显示副技能的颜色块。"
L["RESET_COLOR_BLOCKS_POS_NAME"] = "重置颜色块位置"
L["DISPLAY_POSITION_RESET"] = "显示位置已重置。"

-- TargetCounter 目标计数器
L["targetCounterHeader"] = "AOE 目标计数器"
L["targetCounterEnable"] = "启用计数器"
L["targetCounterEnable_desc"] = "显示一个实时显示附近敌人数量的框架。"
L["targetCounterLock"] = "锁定位置"
L["targetCounterScale"] = "缩放"
L["targetCounterAlpha"] = "透明度"
L["targetCounterFontSize"] = "字体大小"
L["targetCounterReset"] = "重置位置"

-- ===================================================================
-- ==                        狂暴战士 (Fury)                          ==
-- ===================================================================
L["SPEC_OPTIONS_FURYWARRIOR_HEADER_ROTATION"] = "循环选项"
L["OPTION_USE_WHIRLWIND_NAME"] = "旋风斩"
L["OPTION_USE_WHIRLWIND_DESC"] = "在循环中启用/禁用旋风斩。"
L["OPTION_BT_WW_PRIORITY_NAME"] = "核心技能优先级"
L["OPTION_BT_WW_PRIORITY_DESC"] = "选择嗜血和旋风斩的优先级。在某些战斗中，优先旋风斩可能带来更高收益。"
L["BT_FIRST"] = "嗜血 > 旋风斩 (标准)"
L["WW_FIRST"] = "旋风斩 > 嗜血 (AOE/顺劈)"
L["OPTION_USE_REND_NAME"] = "撕裂"
L["OPTION_USE_REND_DESC"] = "启用/禁用撕裂（需要切换姿态）。"
L["OPTION_USE_OVERPOWER_NAME"] = "压制"
L["OPTION_USE_OVERPOWER_DESC"] = "启用/禁用压制（需要切换姿态和触发）。"
L["OPTION_SMART_AOE_NAME"] = "智能AOE"
L["OPTION_SMART_AOE_DESC"] = "当“强制顺劈斩”关闭时，根据8码内敌人数量自动在英勇打击和顺劈斩之间切换。"
L["OPTION_ENABLE_CLEAVE_NAME"] = "强制顺劈斩"
L["OPTION_ENABLE_CLEAVE_DESC"] = "强制使用顺劈斩替代英勇打击，无论目标数量或智能AOE设置如何。"
L["OPTION_CLEAVE_HS_THRESHOLD_NAME"] = "顺劈斩目标阈值"
L["OPTION_CLEAVE_HS_THRESHOLD_DESC"] = "触发顺劈斩所需的最低目标数量。"
L["throwHeader"] = "投掷技能"
L["useHeroicThrow"] = "英勇投掷"
L["useHeroicThrow_desc"] = "当核心技能冷却时，作为填充技能使用英勇投掷。"
L["useShatteringThrow"] = "碎裂投掷"
L["useShatteringThrow_desc"] = "当核心技能冷却时，作为填充技能使用碎裂投掷 (需要目标是首领)。"
L["heroicThrowPostSwingWindow"] = "投掷技能施法窗口 (秒)"
L["heroicThrowPostSwingWindow_desc"] = "设置一个时间值。所有投掷技能（英勇投掷、碎裂投掷）将仅在主手平砍命中后的这段时间内被推荐。此设置可防止投掷技能延迟平砍。"
L["sunderArmorMode"] = "破甲模式"
L["sunderArmorMode_desc"] = "选择插件如何处理破甲攻击。仅当目标为首领且身上没有5层破甲时生效。"
L["NONE"] = "禁用"
L["FILLER"] = "填充破甲"
L["PRIORITY"] = "优先破甲"

L["SPEC_OPTIONS_FURYWARRIOR_HEADER_COOLDOWNS"] = "爆发技能"
L["OPTION_USE_RECKLESSNESS_NAME"] = "鲁莽"
L["OPTION_USE_RECKLESSNESS_DESC"] = "自动鲁莽。"
L["OPTION_USE_DEATH_WISH_NAME"] = "自动死愿"
L["OPTION_USE_DEATH_WISH_DESC"] = "允许自动使用死亡之愿。"
L["OPTION_USE_BERSERKER_RAGE_NAME"] = "狂暴之怒"
L["OPTION_USE_BERSERKER_RAGE_DESC"] = "允许自动使用狂暴之怒（主要用于保持激怒效果）。"

L["SPEC_OPTIONS_FURYWARRIOR_HEADER_UTILITY"] = "辅助技能"
L["OPTION_USE_INTERRUPTS_NAME"] = "打断"
L["OPTION_USE_INTERRUPTS_DESC"] = "允许自动使用拳击打断目标施法。"
L["OPTION_SELECTED_SHOUT_TYPE_NAME"] = "怒吼类型"
L["OPTION_SELECTED_SHOUT_TYPE_DESC"] = "选择插件应为你保持的怒吼类型，或选择“无”以禁用插件自动补怒吼。"
L["SHOUT_OPTION_NONE"] = "无"
L["SHOUT_OPTION_BATTLE"] = "战斗怒吼"
L["SHOUT_OPTION_COMMANDING"] = "命令怒吼"

L["SPEC_OPTIONS_FURYWARRIOR_HEADER_CONSUMABLES"] = "消耗品与种族技能"
L["OPTION_USE_TRINKETS_NAME"] = "饰品"
L["OPTION_USE_TRINKETS_DESC"] = "允许自动使用已追踪的主动使用型饰品。"
L["OPTION_USE_POTIONS_NAME"] = "药水"
L["OPTION_USE_POTIONS_DESC"] = "允许自动使用加速药水（配合死亡之愿）。"
L["OPTION_USE_RACIALS_NAME"] = "种族技能"
L["OPTION_USE_RACIALS_DESC"] = "允许自动使用进攻型种族技能（例如：血性狂怒、狂暴）。"

-- ===================================================================
-- ==                       防护战士 (Protection)                      ==
-- ===================================================================
L["Threat & Damage"] = "仇恨与伤害"
L["Use Thunder Clap"] = "雷霆"
L["Use Thunder Clap_desc"] = "在主目标身上保持雷霆一击的debuff。"
L["useThunderClap"] = "雷霆一击" -- 用于通知
L["Use Demoralizing Shout"] = "挫志怒吼"
L["Use Demoralizing Shout_desc"] = "在主目标身上保持挫志怒吼的debuff。"
L["useDemoShout"] = "挫志怒吼" -- 用于通知
L["OPTION_PROT_SELECTED_SHOUT_TYPE_NAME"] = "怒吼类型"
L["OPTION_PROT_SELECTED_SHOUT_TYPE_DESC"] = "选择作为防护战士时，插件应为你保持的怒吼类型。"
L["selectedShoutType_Prot"] = "防战怒吼类型" -- 用于通知
L["AOE"] = "群体控制"
L["Use Shockwave"] = "冲击波"
L["Use Shockwave_desc"] = "在AOE循环中使用冲击波。如果未点出此天赋则跳过。"
L["useShockwave"] = "冲击波" -- 用于通知
L["AOE Target Threshold"] = "AOE目标阈值"
L["AOE Target Threshold_desc"] = "当附近有这么多敌人时，切换到AOE循环。"
L["Survival"] = "生存"
L["Use Shield Block"] = "盾牌格挡"
L["Use Shield Block_desc"] = "当生命值低于特定阈值时，自动使用盾牌格挡。"
L["useShieldBlock"] = "盾牌格挡" -- 用于通知
L["Shield Block Health %"] = "盾牌格挡生命值 %"
L["Shield Block Health %_desc"] = "当生命值百分比低于此值时，会推荐使用盾牌格挡。"

-- ===================================================================
-- ==                     防护圣骑士 (Protection Paladin)              ==
-- ===================================================================
L["Seals & Judgements"] = "圣印与审判"
L["OPTION_PROT_SELECTED_SEAL_NAME"] = "圣印类型"
L["OPTION_PROT_SELECTED_SEAL_DESC"] = "选择需要插件为你保持的圣印。"
L["SEAL_OPTION_VENGEANCE"] = "复仇圣印"
L["SEAL_OPTION_CORRUPTION"] = "腐蚀圣印"
L["SEAL_OPTION_COMMAND"] = "命令圣印"
L["OPTION_PROT_SELECTED_JUDGEMENT_NAME"] = "审判类型"
L["OPTION_PROT_SELECTED_JUDGEMENT_DESC"] = "选择在循环中使用的审判类型。"
L["JUDGEMENT_OPTION_WISDOM"] = "智慧审判"
L["JUDGEMENT_OPTION_LIGHT"] = "圣光审判"
L["Utility"] = "辅助技能"
L["useHolyShield"] = "神圣之盾"
L["useHolyShield_desc"] = "当神圣之盾Buff断档时自动提示施放。"
L["useRighteousFury"] = "正义之怒"
L["useRighteousFury_desc"] = "自动检测并提示开启正义之怒，这是坦克制造仇恨的基础。"
L["useDivinePlea"] = "神圣恳求"
L["useDivinePlea_desc"] = "在法力值低于设定的阈值时，提示使用神圣恳求。"
L["divinePleaManaThreshold"] = "神圣恳求法力阈值 (%)"
L["divinePleaManaThreshold_desc"] = "当法力值百分比低于此值时，会推荐使用神圣恳求。"

-- ===================================================================
-- ==                     惩戒圣骑士 (Retribution Paladin)             ==
-- ===================================================================
L["ret_header"] = "惩戒骑循环设置"
L["useAvengingWrath"] = "复仇之怒"
L["useAvengingWrath_desc"] = "当满足条件时，自动在循环中推荐复仇之怒。"
L["useDivineStorm"] = "神圣风暴"
L["useDivineStorm_desc"] = "在循环中启用或禁用神圣风暴。惩戒骑在单体和AOE循环中都会使用此技能。"
L["sustainability_header"] = "续航与优先级"
L["useSustainabilityMode"] = "续航模式"
L["useSustainabilityMode_desc"] = "开启后，当法力值低于70%时，将优先使用神圣恳求。关闭后，仅在没有其他技能可用时作为填充技能使用。"
L["consecrationPriority"] = "奉献优先级"
L["consecrationPriority_desc"] = "调整奉献在输出循环中的优先级。"
L["seal_judgement_header"] = "圣印与审判"
L["selectedSeal_Ret"] = "圣印选择"
L["selectedSeal_Ret_desc"] = "选择希望插件为你保持的圣印。"
L["selectedJudgement_Ret"] = "审判选择"
L["selectedJudgement_Ret_desc"] = "选择在循环中使用的审判类型。"
L["High"] = "高"
L["Low"] = "低"
L["Never"] = "不释放" -- [!code ++]


-- ===================================================================
-- ==                       野性德鲁伊 (Feral)                        ==
-- ===================================================================
L["Feral (Cat) Druid"] = "野性德鲁伊"
L["feral_header"] = "野性德鲁伊设置"
L["stance_header"] = "形态设置"
L["preferredStance"] = "主循环模式"
L["preferredStance_desc"] = "选择你希望插件主要执行的循环。如果你只是临时切熊保命，请保持“猫形态DPS”。"
L["aoe_header"] = "AOE 设置"
L["enableAOE"] = "启用 AOE 循环"
L["enableAOE_desc"] = "当附近敌人数量达到阈值时，自动切换到以横扫为核心的AOE输出模式。"
L["aoeThreshold"] = "AOE 目标阈值"
L["aoeThreshold_desc"] = "触发 AOE 循环所需的最低敌人数量。"
L["forceAOE"] = "强制 AOE 循环"
L["forceAOE_desc"] = "开启后，无论附近敌人数量多少，都强制使用AOE输出模式。"
L["core_abilities_header"] = "核心技能"
L["useMangle"] = "裂伤"
L["useMangle_desc"] = "在循环中自动使用裂伤（豹）和裂伤（熊）。关闭此项后，插件将不会推荐任何形式的裂伤。"
L["openerRakePriority"] = "斜掠优先"
L["openerRakePriority_desc"] = "启用后，在起手阶段，当目标已有裂伤且自身已有咆哮时，优先使用斜掠。"
L["roar_header"] = "咆哮/割裂 时间轴优化"
L["ripLeeway"] = "割裂延迟 (Leeway)"
L["ripLeeway_desc"] = "设置一个常数来为能量回复提供缓冲空间，确保在刷新咆哮后有足够的时间打出下一个技能。推荐值: 1.5"
L["roarOffset"] = "咆哮割裂差值 (Offset)"
L["roarOffset_desc"] = "设置一个基于模拟的最佳常数，用于优化提前覆盖咆哮的时机。T9阶段推荐25, T10阶段推荐26。"
L["bite_header"] = "凶猛撕咬"
L["Use Ferocious Bite"] = "使用凶猛撕咬"
L["Use Ferocious Bite_desc"] = "在循环中加入凶猛撕咬作为填充终结技。"
L["FB Min Roar Time"] = "最低咆哮剩余时间"
L["FB Min Roar Time_desc"] = "施放凶猛撕咬前，野性咆哮需要的最少剩余时间（秒）。"
L["FB Min Rip Time"] = "最低割裂剩余时间"
L["FB Min Rip Time_desc"] = "施放凶猛撕咬前，割裂需要的最少剩余时间（秒）。"
L["cooldowns_header"] = "爆发技能"
L["useTigersFury"] = "猛虎之怒"
L["useTigersFury_desc"] = "在循环中自动使用猛虎之怒。"
L["useBerserk"] = "狂暴"
L["useBerserk_desc"] = "在循环中自动使用狂暴。"
L["useEnrage"] = "激怒 (熊)"
L["useEnrage_desc"] = "在熊形态下，当怒气值不高时自动使用激怒。"
L["maulRageThreshold"] = "重殴怒气阈值"
L["maulRageThreshold_desc"] = "当怒气值高于此值时，插件会推荐使用重殴作为泄怒技能。"
L["pooling_header"] = "能量池优化"
L["enableEnergyPooling"] = "启用能量池机制"
L["enableEnergyPooling_desc"] = "启用后，插件会在非爆发期积攒能量，在爆发期或需要刷新重要DoT/Buff时集中使用，以最大化伤害。"
L["poolingThreshold"] = "能量池阈值"
L["poolingThreshold_desc"] = "在非爆发期，能量值高于此阈值时才会推荐使用能量填充技能（如撕碎）。"
L["poolingRipThreshold"] = "割裂刷新阈值"
L["poolingRipThreshold_desc"] = "当割裂剩余时间低于此值时，进入能量倾泻阶段以尽快打出5星割裂。"
L["poolingRoarThreshold"] = "咆哮刷新阈值"
L["poolingRoarThreshold_desc"] = "当野性咆哮剩余时间低于此值时，进入能量倾泻阶段以尽快打出终结技刷新咆哮。"
L["executeTimeThreshold"] = "斩杀阶段时间阈值"
L["executeTimeThreshold_desc"] = "当目标预估死亡时间（TTD）低于此值时，将强制进入能量倾泻阶段进行斩杀。"

-- ===================================================================
-- ==                        火焰法师 (Fire Mage)                      ==
-- ===================================================================
L["fire_mage_header"] = "火法设置"
L["maintainScorch"] = "自动维持强化灼烧"
L["maintainScorch_desc"] = "开启后，如果目标身上没有强化灼烧debuff，插件会自动推荐你施放灼烧来补充。"

-- ===================================================================
-- ==                        快捷设置 & 通知                         ==
-- ===================================================================
L["QUICK_CONFIG_TITLE"] = "WRA 快捷设置"
L["Quick Settings"] = "快捷设置"
L["Config"] = "设置"
L["Quick"] = "快捷"
L["CONFIG_BUTTON_TEXT"] = "设置"
L["QUICK_BUTTON_TEXT"] = "快捷"
L["NO_QUICK_OPTIONS_AVAILABLE"] = "没有可用的快捷选项。"
L["NOTIFICATION_ENABLED"] = "开启"
L["NOTIFICATION_DISABLED"] = "关闭"
