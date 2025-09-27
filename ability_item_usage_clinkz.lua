if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion()  then
	return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

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

local castSTDesire = 0; -- Strafe
local castTBDesire = 0; -- Tar Bomb
local castDPDesire = 0; -- Death Pact
local castWWDesire = 0; -- Wind Walk
local castBBDesire = 0; -- Burning Barrage (Shard)
local castBADesire = 0; -- Burning Army (Scepter)

local abilityST = nil; -- Strafe
local abilityTB = nil; -- Tar Bomb
local abilityDP = nil; -- Death Pact
local abilityWW = nil; -- Wind Walk
local abilityBB = nil; -- Burning Barrage
local abilityBA = nil; -- Burning Army

local npcBot = nil;

function AbilityUsageThink()

	if npcBot == nil then npcBot = GetBot(); end
	
	-- Check if we're already using an ability or channeling
	if mutil.CanNotUseAbility(npcBot) then return end

	-- Initialize abilities by name
	if abilityST == nil then abilityST = npcBot:GetAbilityByName("clinkz_strafe") end
	if abilityTB == nil then abilityTB = npcBot:GetAbilityByName("clinkz_tar_bomb") end
	if abilityDP == nil then abilityDP = npcBot:GetAbilityByName("clinkz_death_pact") end
	if abilityWW == nil then abilityWW = npcBot:GetAbilityByName("clinkz_wind_walk") end
	if abilityBB == nil then abilityBB = npcBot:GetAbilityByName("clinkz_burning_barrage") end
	if abilityBA == nil then abilityBA = npcBot:GetAbilityByName("clinkz_burning_army") end

	-- Consider using each ability
	castSTDesire = ConsiderStrafe();
	castTBDesire, castTBTarget = ConsiderTarBomb();
	castDPDesire, castDPTarget = ConsiderDeathPact();
	castWWDesire = ConsiderWindWalk();
	castBBDesire, castBBLocation = ConsiderBurningBarrage();
	castBADesire, castBALocation = ConsiderBurningArmy();

	-- Priority: Death Pact for healing, then combat abilities, then utility
	if (castDPDesire > 0) then
		npcBot:Action_UseAbilityOnEntity(abilityDP, castDPTarget);
		return;
	end

	if (castBBDesire > 0) then
		npcBot:Action_UseAbilityOnLocation(abilityBB, castBBLocation);
		return;
	end

	if (castBADesire > 0) then
		npcBot:Action_UseAbilityOnLocation(abilityBA, castBALocation);
		return;
	end

	if (castSTDesire > 0) then
		npcBot:Action_UseAbility(abilityST);
		return;
	end
	
	if (castTBDesire > 0) then
		npcBot:Action_UseAbilityOnEntity(abilityTB, castTBTarget);
		return;
	end
	
	if (castWWDesire > 0) then
		npcBot:Action_UseAbility(abilityWW);
		return;
	end
end

function ConsiderStrafe()
	-- Make sure it's castable
	if not mutil.CanBeCast(abilityST) then 
		return BOT_ACTION_DESIRE_NONE;
	end

	-- PUSHING: Use when pushing towers/lanes
	if mutil.IsPushing(npcBot) then
		local attackTarget = mutil.SafeGetAttackTarget(npcBot);
		if attackTarget ~= nil and attackTarget:IsTower() then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- TEAMFIGHT: Use in team fights for DPS
	if mutil.IsInTeamFight(npcBot, 1200) then
		local nearbyEnemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
		if #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- GOING ON SOMEONE: Use when attacking heroes
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, 800) then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- ROSHAN: Use on Roshan
	if npcBot:GetActiveMode() == BOT_MODE_ROSHAN then
		local attackTarget = mutil.SafeGetAttackTarget(npcBot);
		if mutil.IsRoshan(attackTarget) and mutil.IsInRange(attackTarget, npcBot, 600) then
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderTarBomb()
	-- Make sure it's castable
	if not mutil.CanBeCast(abilityTB) then 
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nCastRange = abilityTB:GetCastRange();

	-- GOING ON SOMEONE: Use to slow target
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) then
			return BOT_ACTION_DESIRE_HIGH, npcTarget;
		end
	end

	-- TEAMFIGHT: Use on enemies in fight
	if mutil.IsInTeamFight(npcBot, 1200) then
		local nearbyEnemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		for _, enemy in pairs(nearbyEnemies) do
			if mutil.CanCastOnNonMagicImmune(enemy) then
				return BOT_ACTION_DESIRE_HIGH, enemy;
			end
		end
	end

	-- FARMING: Use on creeps when farming
	if npcBot:GetActiveMode() == BOT_MODE_FARM then
		local nearbyCreeps = npcBot:GetNearbyCreeps(nCastRange, true);
		for _, creep in pairs(nearbyCreeps) do
			if creep:GetHealth() > 200 then
				return BOT_ACTION_DESIRE_LOW, creep;
			end
		end
	end

	-- ROSHAN: Use on Roshan
	if npcBot:GetActiveMode() == BOT_MODE_ROSHAN then
		local attackTarget = mutil.SafeGetAttackTarget(npcBot);
		if mutil.IsRoshan(attackTarget) and mutil.IsInRange(attackTarget, npcBot, nCastRange) then
			return BOT_ACTION_DESIRE_MODERATE, attackTarget;
		end
	end

	-- PUSHING: Use on towers
	if mutil.IsPushing(npcBot) then
		local nearbyTowers = npcBot:GetNearbyTowers(nCastRange, true);
		if #nearbyTowers > 0 then
			return BOT_ACTION_DESIRE_LOW, nearbyTowers[1];
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function GetBestCreepForDeathPact()
	local nCastRange = abilityDP:GetCastRange();
	local bestCreep = nil;
	local bestHealth = 0;

	-- Check neutral creeps first (higher health usually)
	local neutralCreeps = npcBot:GetNearbyNeutralCreeps(nCastRange);
	for _, creep in pairs(neutralCreeps) do
		if creep:GetHealth() > bestHealth and not creep:IsAncientCreep() and creep:IsAlive() then
			bestHealth = creep:GetHealth();
			bestCreep = creep;
		end
	end

	-- Check lane creeps
	local laneCreeps = npcBot:GetNearbyLaneCreeps(nCastRange, true);
	for _, creep in pairs(laneCreeps) do
		if creep:GetHealth() > bestHealth and creep:IsAlive() then
			bestHealth = creep:GetHealth();
			bestCreep = creep;
		end
	end

	-- Check for own skeleton archers - prioritize them for cleanup
	local nearbyUnits = npcBot:GetNearbyCreeps(nCastRange, false);
	for _, unit in pairs(nearbyUnits) do
		if string.find(unit:GetUnitName(), "clinkz_skeleton_archer") and unit:IsAlive() then
			-- Always prefer skeleton archers regardless of health
			return unit;
		end
	end

	-- FIXED: Remove minimum health requirement entirely
	return bestCreep;
end

function ConsiderDeathPact()
	if not mutil.CanBeCast(abilityDP) then 
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
	local bestCreep = GetBestCreepForDeathPact();

	if bestCreep == nil then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- FIXED: More generous health thresholds
	if healthPercent < 0.5 then
		return BOT_ACTION_DESIRE_VERYHIGH, bestCreep;
	end

	if healthPercent < 0.8 then
		local nearbyEnemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
		if #nearbyEnemies > 0 or mutil.IsInTeamFight(npcBot, 1200) then
			return BOT_ACTION_DESIRE_HIGH, bestCreep;
		end
	end

	-- Use more often when not at full health
	if healthPercent < 0.95 then
		if mutil.IsGoingOnSomeone(npcBot) or npcBot:GetActiveMode() == BOT_MODE_ROSHAN or npcBot:GetActiveMode() == BOT_MODE_LANING then
			return BOT_ACTION_DESIRE_MODERATE, bestCreep;
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderWindWalk()
	-- Make sure it's castable
	if not mutil.CanBeCast(abilityWW) then 
		return BOT_ACTION_DESIRE_NONE;
	end

	-- Don't use if already invisible
	if npcBot:IsInvisible() then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- RETREATING: Use when running away
	if mutil.IsRetreating(npcBot) then
		local nearbyEnemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
		if #nearbyEnemies > 0 then
			return BOT_ACTION_DESIRE_VERYHIGH;
		end
	end

	-- GOING ON SOMEONE: Use to get in position
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) then
			local distance = GetUnitToUnitDistance(npcBot, npcTarget);
			-- Use if target is far away
			if distance > npcBot:GetAttackRange() + 200 then
				return BOT_ACTION_DESIRE_HIGH;
			end
		end
	end

	-- ROAMING: Use when roaming to gank
	if npcBot:GetActiveMode() == BOT_MODE_GANK then
		return BOT_ACTION_DESIRE_MODERATE;
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderBurningBarrage()
	-- Check if ability exists (shard check) and we're not already channeling
	if abilityBB == nil or not abilityBB:IsFullyCastable() or abilityBB:IsHidden() or mutil.SafeIsChanneling(npcBot) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nRange = abilityBB:GetSpecialValueInt("range");
	local nWidth = abilityBB:GetSpecialValueInt("projectile_width");

	-- TEAMFIGHT: Use in team fights
	if mutil.IsInTeamFight(npcBot, 1200) then
		local nearbyEnemies = npcBot:GetNearbyHeroes(nRange, true, BOT_MODE_NONE);
		if #nearbyEnemies >= 2 then
			-- Find best position to hit multiple enemies
			local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nRange, nWidth/2, 0, 0);
			if locationAoE.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
			end
		end
	end

	-- GOING ON SOMEONE: Use on single target
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nRange) then
			return BOT_ACTION_DESIRE_HIGH, npcTarget:GetLocation();
		end
	end

	-- FARMING: Use on creep waves
	if npcBot:GetActiveMode() == BOT_MODE_FARM then
		local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), nRange, nWidth/2, 0, 0);
		if locationAoE.count >= 3 then
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderBurningArmy()
	-- Check if we have scepter and ability is available
	if abilityBA == nil or not abilityBA:IsFullyCastable() or abilityBA:IsHidden() or not npcBot:HasScepter() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nCastRange = abilityBA:GetCastRange();

	-- TEAMFIGHT: Use in team fights
	if mutil.IsInTeamFight(npcBot, 1200) then
		local nearbyEnemies = npcBot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
		if #nearbyEnemies >= 2 then
			-- Place where enemies are fighting
			local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, 400, 0, 0);
			if locationAoE.count >= 1 then
				return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
			end
		end
	end

	-- GOING ON SOMEONE: Use when attacking
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) then
			return BOT_ACTION_DESIRE_HIGH, npcTarget:GetLocation();
		end
	end

	-- DEFENDING: Use when defending towers
	if mutil.IsDefending(npcBot) then
		local nearbyTowers = npcBot:GetNearbyTowers(800, false);
		if #nearbyTowers > 0 then
			local nearbyEnemies = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
			if #nearbyEnemies >= 1 then
				return BOT_ACTION_DESIRE_MODERATE, nearbyTowers[1]:GetLocation();
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end


