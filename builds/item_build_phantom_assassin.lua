X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills = IBUtil.FillSkillTable(npcBot, {0,1,4,5});

X["items"] = {
	"item_quelling_blade",
	"item_magic_wand",
	"item_power_treads_agi",
	"item_bfury",
	"item_aghanims_shard",
	"item_angels_demise",
	"item_basher",
	"item_black_king_bar",
	"item_octarine_core",
	"item_abyssal_blade",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_ultimate_scepter_2",
};			

X["builds"] = {
	{1,2,1,3,1,4,1,2,2,2,4,3,3,3,4},
	{1,3,1,2,1,4,1,3,3,3,4,2,2,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,8,1,3,5,7}, talents
);

return X