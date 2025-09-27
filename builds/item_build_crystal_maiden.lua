X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_tranquil_boots",
	"item_glimmer_cape",
	"item_force_staff",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_aeon_disk",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_refresher",
};			

X["builds"] = {
	{1,3,2,3,3,4,3,1,1,1,4,2,2,2,4},
	{2,3,1,3,3,4,3,1,1,1,4,2,2,2,4},
	{2,3,1,3,3,4,3,1,2,1,4,2,1,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,5,7,1,3,6,8}, talents
);

return X