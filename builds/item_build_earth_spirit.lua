X = {}
local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_arcane_boots",
	"item_blade_mail",
	"item_echo_sabre",
	"item_sange",
	"item_harpoon",
	"item_radiance",
	"item_basher",
	"item_ultimate_scepter_2",
	"item_abyssal_blade",
	"item_sphere",
};			

X["builds"] = {
	{2,1,1,3,1,4,1,3,3,3,4,2,2,2,4},
	{2,1,3,1,1,4,1,3,3,3,4,2,2,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,3,6,7,1,4,5,8}, talents
);

return X