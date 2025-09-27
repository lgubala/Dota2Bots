X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_phase_boots",
	"item_lifesteal",
	"item_sange",
	"item_aghanims_shard",
	"item_sange_and_yasha",
	"item_basher",
	"item_lesser_crit",
	"item_abyssal_blade",
	"item_greater_crit",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_satanic",
};			

X["builds"] = {
	{1,2,2,1,2,4,2,3,3,3,3,4,1,1,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,3,5,7,1,4,6,8}, talents
);

return X