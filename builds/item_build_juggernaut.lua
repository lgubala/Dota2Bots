X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_boots",
	"item_maelstrom",
	"item_ultimate_scepter",
	"item_lesser_crit",
	"item_mjollnir",
	"item_greater_crit",
	"item_bloodthorn",
	"item_butterfly",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_skadi",
	"item_aghanims_shard",
};			

X["builds"] = {
	{1,3,1,2,1,4,1,3,3,3,4,2,2,2,4},
	{1,3,1,2,1,4,1,2,2,2,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,8,1,3,5,7}, talents
);

return X