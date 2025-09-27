X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_echo_sabre",
	"item_sange",
	"item_sange_and_yasha",
	"item_black_king_bar",
	"item_harpoon",
	"item_assault",
	"item_moon_shard",
	"item_monkey_king_bar",
};			

X["builds"] = {
	{1,3,1,3,1,4,1,3,3,2,4,2,2,2,4},
	{1,3,1,2,3,4,1,3,1,3,4,2,2,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,5,8,1,3,6,7}, talents
);

return X