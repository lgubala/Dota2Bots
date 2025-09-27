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

local castASDesire = 0; -- Acid Spray
local castUCDesire = 0; -- Unstable Concoction
local castCRDesire = 0; -- Chemical Rage
local castBPDesire = 0; -- Berserk Potion

local castUCTDesire = 0; -- Unstable Concoction Throw
local castUCTTarget = nil;

local concoctionStartTime = 0;
local maxBrewTime = 5.0;

local abilityAS = nil; -- Acid Spray
local abilityUC = nil; -- Unstable Concoction 
local abilityUCT = nil; -- Unstable Concoction Throw
local abilityCR = nil; -- Chemical Rage
local abilityBP = nil; -- Berserk Potion

local npcBot = nil;

function AbilityUsageThink()

	if npcBot == nil then npcBot = GetBot(); end
	
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end

	-- Initialize abilities by name to be safe
	if abilityAS == nil then abilityAS = npcBot:GetAbilityByName("alchemist_acid_spray") end
	if abilityUC == nil then abilityUC = npcBot:GetAbilityByName("alchemist_unstable_concoction") end
	if abilityUCT == nil then abilityUCT = npcBot:GetAbilityByName("alchemist_unstable_concoction_throw") end
	if abilityCR == nil then abilityCR = npcBot:GetAbilityByName("alchemist_chemical_rage") end
	if abilityBP == nil then abilityBP = npcBot:GetAbilityByName("alchemist_berserk_potion") end

	-- Consider using each ability
	castASDesire, castASLocation = ConsiderAcidSpray();
	castUCDesire = ConsiderUnstableConcoction();
	castUCTDesire, castUCTTarget = ConsiderUnstableConcoctionThrow();
	castCRDesire = ConsiderChemicalRage();
	castBPDesire, castBPTarget = ConsiderBerserkPotion();

	-- Priority: Throw concoction first if ready, then other abilities
	if (castUCTDesire > 0) then
		npcBot:Action_UseAbilityOnEntity(abilityUCT, castUCTTarget);
		return;
	end

	if (castBPDesire > 0) then
		npcBot:Action_UseAbilityOnEntity(abilityBP, castBPTarget);
		return;
	end

	if (castCRDesire > 0) then
		npcBot:Action_UseAbility(abilityCR);
		return;
	end

	if (castASDesire > 0) then
		npcBot:Action_UseAbilityOnLocation(abilityAS, castASLocation);
		return;
	end
	
	if (castUCDesire > 0) then
		npcBot:Action_UseAbility(abilityUC);
		concoctionStartTime = DotaTime();
		return;
	end
end

function ConsiderAcidSpray()
	-- Make sure it's castable
	if not mutil.CanBeCast(abilityAS) then 
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nRadius = abilityAS:GetSpecialValueInt("radius");
	local nCastRange = abilityAS:GetCastRange();
	local nManaCost = abilityAS:GetManaCost();

	-- Don't use if low mana unless in danger
	if npcBot:GetMana() < nManaCost * 2 and not mutil.IsRetreating(npcBot) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- FARMING: Use on lane creeps when laning/farming
	if npcBot:GetActiveMode() == BOT_MODE_LANING or npcBot:GetActiveMode() == BOT_MODE_FARM then
		local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
		if locationAoE.count >= 3 then
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
		end
	end

	-- PUSHING: Use when pushing towers/lanes
	if mutil.IsPushing(npcBot) then
		local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
		if locationAoE.count >= 2 then
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
		end
	end

	-- DEFENDING: Use when defending towers
	if mutil.IsDefending(npcBot) then
		local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
		if locationAoE.count >= 2 then
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
		end
	end

	-- TEAMFIGHT: Use in team fights
	if mutil.IsInTeamFight(npcBot, 1200) then
		local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
		if locationAoE.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
		end
	end

	-- GOING ON SOMEONE: Use on target area
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) then
			return BOT_ACTION_DESIRE_MODERATE, npcTarget:GetLocation();
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderUnstableConcoction()
	-- Make sure it's castable and not already brewing
	if not mutil.CanBeCast(abilityUC) or npcBot:HasModifier("modifier_alchemist_unstable_concoction") then 
		return BOT_ACTION_DESIRE_NONE;
	end

	-- RETREATING: Start brewing when retreating
	if mutil.IsRetreating(npcBot) then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
		if #tableNearbyEnemyHeroes > 0 then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- GOING ON SOMEONE: Start brewing when engaging
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, 1200) then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- TEAMFIGHT: Start brewing in team fights
	if mutil.IsInTeamFight(npcBot, 1200) then
		return BOT_ACTION_DESIRE_HIGH;
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderUnstableConcoctionThrow()
	-- Make sure we're brewing and throw ability is available
	if not npcBot:HasModifier("modifier_alchemist_unstable_concoction") or not mutil.CanBeCast(abilityUCT) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nCastRange = abilityUCT:GetCastRange();
	local brewTime = DotaTime() - concoctionStartTime;
	
	-- Get nearby enemies
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);
	
	-- EMERGENCY: Throw before self-stun (at 4.5 seconds to be safe)
	if brewTime >= 4.5 then
		for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
			if mutil.CanCastOnNonMagicImmune(npcEnemy) then
				return BOT_ACTION_DESIRE_VERYHIGH, npcEnemy;
			end
		end
		-- If no valid targets, throw at closest enemy position to avoid self-stun
		if #tableNearbyEnemyHeroes > 0 then
			return BOT_ACTION_DESIRE_VERYHIGH, tableNearbyEnemyHeroes[1];
		end
	end

	-- INTERRUPT: Throw at channeling enemies immediately
	for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
		if mutil.SafeIsChanneling(npcEnemy) and mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.IsInRange(npcEnemy, npcBot, nCastRange) then
			return BOT_ACTION_DESIRE_VERYHIGH, npcEnemy;
		end
	end

	-- OPTIMAL TIMING: Throw after 2+ seconds for good stun duration
	if brewTime >= 2.0 then
		-- RETREATING: Throw at closest pursuer
		if mutil.IsRetreating(npcBot) then
			for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
				if npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0) and mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.IsInRange(npcEnemy, npcBot, nCastRange) then
					return BOT_ACTION_DESIRE_HIGH, npcEnemy;
				end
			end
		end

		-- GOING ON SOMEONE: Throw at target
		if mutil.IsGoingOnSomeone(npcBot) then
			local npcTarget = npcBot:GetTarget();
			if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) then
				return BOT_ACTION_DESIRE_HIGH, npcTarget;
			end
		end

		-- TEAMFIGHT: Throw at best target
		if mutil.IsInTeamFight(npcBot, 1200) then
			for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
				if mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.IsInRange(npcEnemy, npcBot, nCastRange) then
					return BOT_ACTION_DESIRE_HIGH, npcEnemy;
				end
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderChemicalRage()
	-- Make sure it's castable
	if not mutil.CanBeCast(abilityCR) then 
		return BOT_ACTION_DESIRE_NONE;
	end

	-- FIGHTING: Use when in combat
	if mutil.IsInTeamFight(npcBot, 1200) then
		return BOT_ACTION_DESIRE_HIGH;
	end

	-- GOING ON SOMEONE: Use when engaging
	if mutil.IsGoingOnSomeone(npcBot) then
		return BOT_ACTION_DESIRE_HIGH;
	end

	-- TOWER HITTING: Use when attacking towers
	local attackTarget = mutil.SafeGetAttackTarget(npcBot);
	if attackTarget ~= nil and attackTarget:IsTower() and mutil.IsInRange(attackTarget, npcBot, 200) then
		return BOT_ACTION_DESIRE_MODERATE;
	end

	-- LOW HEALTH: Use for regen when low on health and farming
	if (npcBot:GetHealth() / npcBot:GetMaxHealth() < 0.4) and npcBot:GetActiveMode() == BOT_MODE_FARM then
		return BOT_ACTION_DESIRE_MODERATE;
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderBerserkPotion()
	-- Check if ability exists (shard check)
	if abilityBP == nil or not abilityBP:IsFullyCastable() or abilityBP:IsHidden() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nCastRange = abilityBP:GetCastRange();

	-- SELF: Use on self when low health and in danger
	if npcBot:GetHealth() / npcBot:GetMaxHealth() < 0.3 then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
		if #tableNearbyEnemyHeroes > 0 then
			return BOT_ACTION_DESIRE_HIGH, npcBot;
		end
	end

	-- ALLIES: Use on low health allies
	local tableNearbyFriendlyHeroes = npcBot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
	for _, ally in pairs(tableNearbyFriendlyHeroes) do
		if ally:GetHealth() / ally:GetMaxHealth() < 0.25 and ally:WasRecentlyDamagedByAnyHero(2.0) then
			return BOT_ACTION_DESIRE_HIGH, ally;
		end
	end

	-- RETREATING ALLIES: Help retreating allies
	for _, ally in pairs(tableNearbyFriendlyHeroes) do
		if mutil.IsRetreating(ally) and ally:WasRecentlyDamagedByAnyHero(2.0) then
			return BOT_ACTION_DESIRE_MODERATE, ally;
		end
	end

	-- COMBAT BUFF: Use on self or closest ally when going on someone
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) then
			-- Find closest ally to target (including self)
			local closestDist = GetUnitToUnitDistance(npcTarget, npcBot);
			local closestBot = npcBot;
			
			for _, ally in pairs(tableNearbyFriendlyHeroes) do
				local dist = GetUnitToUnitDistance(npcTarget, ally);
				if dist < closestDist then
					closestDist = dist;
					closestBot = ally;
				end
			end
			
			if closestDist < 800 then
				return BOT_ACTION_DESIRE_MODERATE, closestBot;
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

