X = {}

local IBUtil  = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot  = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

-- Copy items from Abaddon for now (will be edited later)
X["items"] = {
	"item_magic_wand",
	"item_arcane_boots",
	"item_sange_and_yasha",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_heart",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_moon_shard",
};

-- Skill builds for Primal Beast
-- 1 = Onslaught (Q), 2 = Trample (W), 3 = Uproar (E), 4 = Pulverize (R)
-- Strategy: 1 point in Onslaught first, then max Trample and Uproar, ultimate at 6/12/18
X["builds"] = {
	{1,2,3,2,2,4,2,3,3,3,4,1,1,1,4}, -- Max Trample first, then Uproar
	{1,3,2,3,3,4,3,2,2,2,4,1,1,1,4}  -- Max Uproar first, then Trample
}

-- Copy skills pattern from Abaddon (will be edited later)
X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {1,3,6,7,2,4,5,8}, talents
);

return X