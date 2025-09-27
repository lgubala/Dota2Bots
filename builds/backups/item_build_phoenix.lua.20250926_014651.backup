X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_tranquil_boots",
	"item_boots_of_bearing",
	"item_radiance",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_heart",
	"item_moon_shard",
};			

X["builds"] = {
	{1,2,2,1,2,4,2,1,1,3,4,3,3,3,4},
	{2,1,2,1,2,4,2,1,1,3,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,7,1,3,5,8}, talents
);

return X