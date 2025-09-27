if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion()  then
	return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutils = require(GetScriptDirectory() ..  "/MyUtility")
local abUtils = require(GetScriptDirectory() ..  "/AbilityItemUsageUtility")

function AbilityLevelUpThink()  
	ability_item_usage_generic.AbilityLevelUpThink(); 
end
function BuybackUsageThink()
	ability_item_usage_generic.BuybackUsageThink();
end
function CourierUsageThink()
	ability_item_usage_generic.CourierUsageThink();
end
function ItemUsageThink()
	ability_item_usage_generic.ItemUsageThink();
end

local bot = GetBot();

local abilities = {};

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;



function AbilityUsageThink()
	
	-- Initialize abilities by name like Morphling does
	if #abilities == 0 then 
		abilities[1] = bot:GetAbilityByName("beastmaster_wild_axes");
		abilities[2] = bot:GetAbilityByName("beastmaster_call_of_the_wild_boar");
		abilities[3] = bot:GetAbilityByName("beastmaster_call_of_the_wild_hawk");
		abilities[4] = bot:GetAbilityByName("beastmaster_primal_roar");		
	end
	
	if mutils.CantUseAbility(bot) then return end
	
	castQDesire, targetQ = ConsiderQ();
	castWDesire = ConsiderW(); -- Boar
	castEDesire = ConsiderE(); -- Hawk  
	castRDesire, targetR = ConsiderR();
	
	
	if castRDesire > 0 then
		--print("[BM] Using Primal Roar on " .. targetR:GetUnitName());
		bot:Action_UseAbilityOnEntity(abilities[4], targetR);		
		return
	end
	
	if castQDesire > 0 then
		--print("[BM] Using Wild Axes");
		bot:Action_UseAbilityOnLocation(abilities[1], targetQ);		
		return
	end
	
	if castWDesire > 0 then
		--print("[BM] Summoning Boar");
		bot:Action_UseAbility(abilities[2]);		
		return
	end
	
	if castEDesire > 0 then
		--print("[BM] Summoning Hawk");
		bot:Action_UseAbility(abilities[3]);		
		return
	end
	
end

function ConsiderQ()
	if not mutils.CanBeCast(abilities[1]) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = abilities[1]:GetCastRange();
	local nRadius = abilities[1]:GetSpecialValueInt("radius");
	
	-- INTERRUPT: Channeling enemies (highest priority)
	local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
	for _, enemy in pairs(enemies) do
		if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
			return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
		end
	end
	
	-- TEAMFIGHT: Multi-target scenarios
	if mutils.IsInTeamFight(bot, 1000) then
		local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0);
		if locationAoE.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
		end
	end
	
	-- AGGRESSIVE: Going on someone
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
			return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
		end
	end
	
	-- FARMING: Clear creep waves
	if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and mutils.CanSpamSpell(bot, abilities[1]:GetManaCost()) then
		local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0);
		if locationAoE.count >= 3 then
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
		end
	end
	
	-- HARASSMENT: Attack nearby enemies
	local nearbyEnemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
	local manaPercent = bot:GetMana() / bot:GetMaxMana();
	if #nearbyEnemies > 0 and manaPercent > 0.4 then
		return BOT_ACTION_DESIRE_MODERATE, nearbyEnemies[1]:GetLocation();
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderW()
	if not mutils.CanBeCast(abilities[2]) then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- AGGRESSIVE: Always summon boar when going on someone
	if mutils.IsGoingOnSomeone(bot) then
		return BOT_ACTION_DESIRE_HIGH;
	end
	
	-- TEAMFIGHT: Summon for extra damage/tank
	if mutils.IsInTeamFight(bot, 1200) then
		return BOT_ACTION_DESIRE_HIGH;
	end
	
	-- RETREATING: Summon for protection
	if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		return BOT_ACTION_DESIRE_HIGH;
	end
	
	-- FARMING: Summon when pushing/farming
	if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and mutils.CanSpamSpell(bot, abilities[2]:GetManaCost()) then
		return BOT_ACTION_DESIRE_MODERATE;
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderE()
	if not mutils.CanBeCast(abilities[3]) then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- SCOUTING: Always keep hawk up for vision
	local manaPercent = bot:GetMana() / bot:GetMaxMana();
	if manaPercent > 0.3 then
		return BOT_ACTION_DESIRE_MODERATE;
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderR()
	if not mutils.CanBeCast(abilities[4]) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = abilities[4]:GetCastRange();
	
	-- INTERRUPT: Stop channeling abilities (highest priority)
	local enemies = bot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);
	for _, enemy in pairs(enemies) do
		if mutils.SafeIsChanneling(enemy) then
			return BOT_ACTION_DESIRE_VERYHIGH, enemy;
		end
	end
	
	-- TEAMFIGHT: Initiate on strongest enemy
	if mutils.IsInTeamFight(bot, 1200) then
		local target = mutils.GetStrongestUnit(nCastRange, bot, true, false, 5.0);
		if target ~= nil then
			return BOT_ACTION_DESIRE_HIGH, target;
		end
	end
	
	-- AGGRESSIVE: Always use on primary target
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) and mutils.IsInRange(target, bot, nCastRange + 100) then
			return BOT_ACTION_DESIRE_HIGH, target;
		end
	end
	
	-- DEFENSIVE: Use when low health and enemies nearby
	local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
	if healthPercent < 0.4 and #enemies > 0 then
		return BOT_ACTION_DESIRE_HIGH, enemies[1];
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end
	
