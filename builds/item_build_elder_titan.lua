X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_arcane_boots",
	"item_echo_sabre",
	"item_harpoon",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_satanic",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_refresher",
};			

X["builds"] = {
	{2,1,2,1,1,4,1,3,3,3,4,3,2,2,4},
	{1,2,1,3,1,4,1,3,3,3,4,2,2,2,4},
	{2,1,3,1,2,4,1,2,1,2,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,5,7,1,3,6,8}, talents
);

return X;