X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);

-- DEBUG: Let's manually force Berserker's Rage into the build
X["items"] = { 
	"item_quelling_blade",
	"item_magic_wand",
	"item_power_treads_agi",
	"item_sange_and_yasha",
	"item_black_king_bar",
	"item_basher",
	"item_abyssal_blade",
	"item_butterfly",
	"item_monkey_king_bar",
};			

-- MANUAL BUILD: Force every ability to get at least 1 point to see what happens
X["skills"] = {
    "troll_warlord_whirling_axes_ranged",    -- Level 1
    "troll_warlord_fervor",                  -- Level 2  
    "troll_warlord_berserkers_rage",         -- Level 3 - FORCE THIS
    "troll_warlord_fervor",                  -- Level 4
    "troll_warlord_fervor",                  -- Level 5
    "troll_warlord_battle_trance",           -- Level 6
    "troll_warlord_fervor",                  -- Level 7
    "troll_warlord_whirling_axes_ranged",    -- Level 8
    "troll_warlord_whirling_axes_ranged",    -- Level 9
    talents[2],                              -- Level 10 talent
    "troll_warlord_whirling_axes_ranged",    -- Level 11
    "troll_warlord_battle_trance",           -- Level 12
    "troll_warlord_berserkers_rage",         -- Level 13 - FORCE THIS
    "troll_warlord_berserkers_rage",         -- Level 14 - FORCE THIS  
    talents[4],                              -- Level 15 talent
    "troll_warlord_berserkers_rage",         -- Level 16 - FORCE THIS
    "troll_warlord_battle_trance",           -- Level 17
    "troll_warlord_whirling_axes_melee",     -- Level 18 - Test if this works
    "troll_warlord_whirling_axes_melee",     -- Level 19
    talents[5],                              -- Level 20 talent
    "troll_warlord_whirling_axes_melee",     -- Level 21
    "troll_warlord_whirling_axes_melee",     -- Level 22
    "-1",                                    -- Level 23
    "-1",                                    -- Level 24  
    talents[7],                              -- Level 25 talent
    talents[1],                              -- Level 26
    talents[3],                              -- Level 27
    talents[6],                              -- Level 28
    talents[8]                               -- Level 29
};

return X