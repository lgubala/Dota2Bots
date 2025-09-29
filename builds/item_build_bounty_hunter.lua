X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_phase_boots",
	"item_orchid",
	"item_moon_shard",
	"item_aghanims_shard",
	"item_basher",
	"item_black_king_bar",
	"item_bloodthorn",
	"item_ultimate_scepter",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_abyssal_blade",
	"item_dagon_5",
};

X["builds"] = {
	{3,2,1,1,1,4,1,3,3,3,4,2,2,2,4},
	{3,2,2,1,2,4,2,1,1,1,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {1,3,6,7,2,5,4,8}, talents
);

return X