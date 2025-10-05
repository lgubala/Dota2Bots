X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_phase_boots",
	"item_echo_sabre",
	"item_aghanims_shard",
	"item_sange_and_yasha",
	"item_basher",
	"item_harpoon",
	"item_assault",
	"item_abyssal_blade",
	"item_heart",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
};			

X["builds"] = {
	{2,3,1,1,1,4,1,3,3,3,4,2,2,2,4},
	{2,3,1,1,1,4,1,2,2,2,4,3,3,3,4},
	{2,3,2,1,2,4,2,1,1,1,4,3,3,3,4},
	{2,3,2,1,1,4,1,1,3,3,4,3,2,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,5,8,1,3,6,7}, talents
);

return X