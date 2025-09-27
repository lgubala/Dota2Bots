X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_power_treads_str",
	"item_echo_sabre",
	"item_blink",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_harpoon",
	"item_ultimate_scepter_2",
	"item_refresher",
	"item_arcane_blink",
	"item_greater_crit",
	"item_sheepstick",
};			

X["builds"] = {
	{3,2,1,1,1,4,1,2,2,2,4,3,3,3,4},
	{3,1,1,2,1,4,1,2,2,2,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,8,1,3,5,7}, talents
);

return X