X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_arcane_boots",
	"item_mekansm",
	"item_guardian_greaves",
	"item_blink",
	"item_lotus_orb",
	"item_overwhelming_blink",
	"item_refresher",
	"item_sheepstick",
	"item_heart",
	"item_octarine_core",
};			

X["builds"] = {
	{1,2,1,3,3,4,3,3,2,2,4,2,1,1,4},
	{1,3,3,2,2,4,2,2,3,3,4,1,1,1,4}
}


X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,7,1,3,5,8}, talents
);

return X