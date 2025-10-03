X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_power_treads_agi",
	"item_diffusal_blade",
	"item_aghanims_shard",
	"item_dragon_lance",
	"item_desolator",
	"item_sphere",
	"item_disperser",
	"item_greater_crit",
	"item_ultimate_scepter_2",
	"item_hurricane_pike",
};			

X["builds"] = {
	{2,3,2,1,2,4,2,1,1,1,4,3,3,3,4},
	{2,3,1,2,2,4,2,3,3,3,4,1,1,1,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,5,7,1,3,6,8}, talents
);

return X