X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_tranquil_boots",
	"item_urn_of_shadows",
	"item_holy_locket",
	"item_ancient_janggo",
	"item_spirit_vessel",
	"item_boots_of_bearing",
	"item_solar_crest",
	"item_pipe",
	"item_vanguard",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_crimson_guard",
};			

X["builds"] = {
	{1,2,2,3,2,4,2,3,3,3,4,1,1,1,4},
	{1,2,2,3,3,4,2,3,2,3,4,1,1,1,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,7,1,3,5,8}, talents
);

return X