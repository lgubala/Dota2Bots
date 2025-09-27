X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(2));

X["items"] = {
	"item_magic_wand",
	"item_arcane_boots",
	"item_vladmir",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_refresher",
	"item_travel_boots",
	"item_sheepstick",
};

X["builds"] = {
	{1,2,1,2,1,4,1,2,2,2,4,2,2,2,4},
	{1,3,1,2,1,4,1,2,2,2,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,5,7,1,3,6,8}, talents
);

return X