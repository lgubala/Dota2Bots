X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = { 
	"item_magic_wand",
	"item_power_treads_agi",
	"item_gungir",
	"item_dragon_lance",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_monkey_king_bar",
	"item_sheepstick",
};

X["builds"] = {
	{1,2,1,3,1,4,1,2,2,2,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,5,8,1,3,6,7}, talents
);

return X