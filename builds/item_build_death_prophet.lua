X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = { 
	"item_magic_wand",
	"item_boots",
	"item_arcane_boots",
	"item_cyclone",
	"item_black_king_bar",
	"item_guardian_greaves",
	"item_bloodstone",
	"item_heart",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_sheepstick",
};			

X["builds"] = {
	{1,3,3,1,3,4,3,1,1,2,4,2,2,2,4},
	{1,3,1,3,1,4,1,3,3,2,4,2,2,2,4},
	{1,3,1,2,1,4,1,3,3,3,4,2,2,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {1,4,6,8,2,3,5,7}, talents
);

return X