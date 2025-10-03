X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_power_treads_str",
	"item_radiance",
	"item_aghanims_shard",
	"item_sange",
	"item_basher",
	"item_butterfly",
	"item_ultimate_scepter",
	"item_heart",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_satanic",
};			

X["builds"] = {
	{1,2,1,3,1,4,1,2,2,2,4,3,3,3,4},
	{1,2,1,3,1,4,1,3,2,3,4,2,3,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,8,1,3,5,7}, talents
);

return X