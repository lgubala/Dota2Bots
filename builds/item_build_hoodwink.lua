X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);

X["items"] = {
	"item_magic_wand",
	"item_power_treads_agi",
	"item_gungir",
	"item_dragon_lance",
	"item_aghanims_shard",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_monkey_king_bar",
	"item_sheepstick",
};

-- Use explicit ability names like Troll
X["skills"] = {
    "hoodwink_acorn_shot",           -- Level 1
    "hoodwink_bushwhack",            -- Level 2
    "hoodwink_acorn_shot",           -- Level 3
    "hoodwink_scurry",               -- Level 4
    "hoodwink_acorn_shot",           -- Level 5
    "hoodwink_sharpshooter",         -- Level 6 (Ultimate!)
    "hoodwink_acorn_shot",           -- Level 7
    "hoodwink_bushwhack",            -- Level 8
    "hoodwink_bushwhack",            -- Level 9
    talents[2],                       -- Level 10 talent
    "hoodwink_bushwhack",            -- Level 11
    "hoodwink_sharpshooter",         -- Level 12 (Ultimate!)
    "hoodwink_scurry",               -- Level 13
    "hoodwink_scurry",               -- Level 14
    talents[4],                       -- Level 15 talent
    "hoodwink_scurry",               -- Level 16
    "hoodwink_sharpshooter",         -- Level 17 (Ultimate!)
    "hoodwink_mistwoods_wayfarer",   -- Level 18 (Innate)
    "hoodwink_mistwoods_wayfarer",   -- Level 19
    talents[5],                       -- Level 20 talent
    "hoodwink_mistwoods_wayfarer",   -- Level 21
    "hoodwink_mistwoods_wayfarer",   -- Level 22
    "-1",                             -- Level 23
    "-1",                             -- Level 24  
    talents[7],                       -- Level 25 talent
    talents[1],                       -- Level 26
    talents[3],                       -- Level 27
    talents[6],                       -- Level 28
    talents[8]                        -- Level 29
};

return X