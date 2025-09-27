X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_arcane_boots",
	"item_force_staff",
	"item_aghanims_shard",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_octarine_core",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_moon_shard",
};			

X["builds"] = {
	{1,2,1,2,1,4,1,2,2,3,4,3,3,3,4},
	{1,2,3,2,3,4,2,3,2,3,4,1,1,1,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,3,5,7,1,4,6,8}, talents
);

return X;