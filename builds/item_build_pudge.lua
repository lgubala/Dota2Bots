X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = { 
	"item_magic_wand",
	"item_tranquil_boots",
	"item_blink",
	"item_pipe",
	"item_lotus_orb",
	"item_ultimate_scepter_2",
	"item_heart",
	"item_overwhelming_blink",
	"item_sheepstick",
};			

X["builds"] = {
	{1,2,1,2,1,4,1,2,2,3,4,3,3,3,4},
	{2,1,1,2,1,4,1,2,2,3,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,6,8,1,3,5,7}, talents
);

return X