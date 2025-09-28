X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_null_talisman",
	"item_power_treads_int",
	"item_kaya",
	"item_orchid",
	"item_aghanims_shard",
	"item_kaya_and_sange",
	"item_bloodstone",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_sheepstick",
};			

X["builds"] = {
	{1,3,1,3,1,4,1,3,3,2,4,2,2,2,4},
	{1,3,1,2,2,4,2,2,1,1,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills,  
	  {1,4,6,8,1,3,5,7}, talents
);

return X