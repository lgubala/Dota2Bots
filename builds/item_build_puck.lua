X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_power_treads_int",
	"item_witch_blade",
	"item_blink",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_arcane_blink",
	"item_devastator",
	"item_dagon_5",
	"item_ultimate_scepter_2",
	"item_sphere",
};			

X["builds"] = {
	{1,3,1,2,1,4,1,2,2,2,4,3,3,3,4},
	{1,3,1,2,2,4,1,2,1,2,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,7,1,3,5,8}, talents
);

return X