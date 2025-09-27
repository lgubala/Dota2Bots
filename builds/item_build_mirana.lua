X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_wraith_band",
	"item_boots",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_maelstrom",
	"item_aghanims_shard",
	"item_desolator",
	"item_ultimate_scepter",
	"item_mjollnir",
	"item_hurricane_pike",
	"item_monkey_king_bar",
	"item_ultimate_scepter_2",
	"item_butterfly",
};			

X["builds"] = {
	{2,3,1,1,1,4,1,3,3,3,4,2,2,2,4},
	{3,2,1,1,1,4,1,3,3,3,4,2,2,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,8,1,3,5,7}, talents
);

return X