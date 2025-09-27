X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = { 
	"item_magic_wand",
	"item_boots",
	"item_arcane_boots",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_force_staff",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_aeon_disk",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_octarine_core",
	"item_hurricane_pike",
};

X["builds"] = {
	{1,3,3,2,3,4,3,2,2,2,4,1,1,1,4},
	{1,3,1,2,1,4,1,3,3,3,4,2,2,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {1,4,6,7,2,3,5,8}, talents
);

return X