if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
	return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

function AbilityLevelUpThink()  
	if isRecoveringFromDeath then
		return;
	end
	ability_item_usage_generic.AbilityLevelUpThink(); 
end

function BuybackUsageThink()
	if isRecoveringFromDeath then
		return;
	end
	ability_item_usage_generic.BuybackUsageThink();
end

function CourierUsageThink()
	if isRecoveringFromDeath then
		return;
	end
	ability_item_usage_generic.CourierUsageThink();
end

function ItemUsageThink()
	if isRecoveringFromDeath then
		return;
	end
	ability_item_usage_generic.ItemUsageThink();
end

-- Global variables for abilities
local abilityTW = nil; -- Time Walk (Q)
local abilityTD = nil; -- Time Dilation (W)
local abilityTL = nil; -- Time Lock (E) - Passive
local abilityCS = nil; -- Chronosphere (R)
local abilityTWR = nil; -- Time Walk Reverse (Shard)

local npcBot = nil;

-- State management variables
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Time Walk mechanics tracking
local timeWalkUsedTime = 0;
local timeWalkStartLocation = nil;
local shardComboWindow = 1.5; -- Time window to use reverse after Time Walk
local lastDamageTime = 0;
local recentDamageThreshold = 150; -- Minimum damage to consider using Time Walk for heal

function AbilityUsageThink()
	if npcBot == nil then npcBot = GetBot(); end
	
	-- FOUNTAIN STUCK FIX
	local distanceFromFountain = npcBot:DistanceFromFountain();
	local botLevel = npcBot:GetLevel();
	local currentMode = npcBot:GetActiveMode();
	
	if distanceFromFountain <= 50 and botLevel >= 6 and DotaTime() > 60 then
		npcBot:Action_ClearActions(false);
		local escapeLocation = nil;
		if GetTeam() == TEAM_RADIANT then
			escapeLocation = Vector(-6000, -6000, 0);
		else
			escapeLocation = Vector(6000, 6000, 0);
		end
		if escapeLocation ~= nil then
			npcBot:Action_MoveToLocation(escapeLocation);
			return;
		end
	end
	
	if distanceFromFountain < 500 and currentMode == BOT_MODE_RETREAT and 
	   botLevel >= 6 and npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.8 then
		npcBot:Action_ClearActions(false);
		local laneLocation = GetLaneFrontLocation(GetTeam(), LANE_MID, 0.5);
		if laneLocation ~= nil then
			npcBot:Action_MoveToLocation(laneLocation);
			return;
		end
	end
	
	-- Handle death/respawn state management
	if not npcBot:IsAlive() then
		lastDeathTime = DotaTime();
		isRecoveringFromDeath = true;
		timeWalkUsedTime = 0;
		timeWalkStartLocation = nil;
		return;
	end
	
	if isRecoveringFromDeath and DotaTime() - lastDeathTime < postDeathCooldown then
		return;
	elseif isRecoveringFromDeath then
		isRecoveringFromDeath = false;
	end
	
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end

	-- Initialize abilities by name
	if abilityTW == nil then abilityTW = npcBot:GetAbilityByName("faceless_void_time_walk"); end
	if abilityTD == nil then abilityTD = npcBot:GetAbilityByName("faceless_void_time_dilation"); end
	if abilityTL == nil then abilityTL = npcBot:GetAbilityByName("faceless_void_time_lock"); end
	if abilityCS == nil then abilityCS = npcBot:GetAbilityByName("faceless_void_chronosphere"); end
	if abilityTWR == nil then abilityTWR = npcBot:GetAbilityByName("faceless_void_time_walk_reverse"); end

	-- Track recent damage for Time Walk healing
	if npcBot:WasRecentlyDamagedByAnyHero(2.0) then
		lastDamageTime = DotaTime();
	end

	-- Consider using each ability
	local castTWRDesire = ConsiderTimeWalkReverse();
	local castCSDesire, castCSLocation = ConsiderChronosphere();
	local castTWDesire, castTWLocation = ConsiderTimeWalk();
	local castTDDesire = ConsiderTimeDilation();

	-- PRIORITY 1: Time Walk Reverse (must be used within window)
	if castTWRDesire > 0 then
		if abilityTWR ~= nil then
			npcBot:Action_UseAbility(abilityTWR);
			timeWalkUsedTime = 0; -- Reset tracking
			timeWalkStartLocation = nil;
			return;
		end
	end

	-- PRIORITY 2: Chronosphere (Ultimate)
	if castCSDesire > 0 and castCSLocation ~= nil then
		if abilityCS ~= nil then
			npcBot:Action_UseAbilityOnLocation(abilityCS, castCSLocation);
			return;
		end
	end

	-- PRIORITY 3: SHARD COMBO (Time Walk + Time Dilation + Time Walk Reverse)
	local shardComboDesire, shardComboLocation = ConsiderShardCombo();
	if shardComboDesire > 0 and shardComboLocation ~= nil then
		-- Execute shard combo sequence
		timeWalkUsedTime = DotaTime();
		timeWalkStartLocation = npcBot:GetLocation();
		npcBot:Action_ClearActions(false);
		npcBot:ActionQueue_UseAbilityOnLocation(abilityTW, shardComboLocation);
		npcBot:ActionQueue_UseAbility(abilityTD);
		return;
	end

	-- PRIORITY 4: Time Walk (individual use)
	if castTWDesire > 0 and castTWLocation ~= nil then
		if abilityTW ~= nil then
			timeWalkUsedTime = DotaTime();
			timeWalkStartLocation = npcBot:GetLocation();
			npcBot:Action_UseAbilityOnLocation(abilityTW, castTWLocation);
			return;
		end
	end

	-- PRIORITY 5: Time Dilation
	if castTDDesire > 0 then
		if abilityTD ~= nil then
			npcBot:Action_UseAbility(abilityTD);
			return;
		end
	end
end

function ConsiderTimeWalkReverse()
	-- Check if shard ability exists and is castable
	if abilityTWR == nil or not abilityTWR:IsFullyCastable() or abilityTWR:IsHidden() then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- Must be used within window after Time Walk
	if timeWalkUsedTime == 0 or DotaTime() - timeWalkUsedTime > shardComboWindow then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- EMERGENCY: Low health escape
	local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
	if healthPercent < 0.3 then
		return BOT_ACTION_DESIRE_VERYHIGH;
	end

	-- RETREAT: Being chased by multiple enemies
	if mutil.IsRetreating(npcBot) then
		local enemies = mutil.SafeGetNearbyHeroes(npcBot, 600, true, BOT_MODE_NONE);
		if #enemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- TACTICAL: After using Time Dilation, escape back
	if npcBot:HasModifier("modifier_faceless_void_time_dilation") then
		return BOT_ACTION_DESIRE_MODERATE;
	end

	-- AUTO: Near end of window, use it or lose it
	if DotaTime() - timeWalkUsedTime > 1.0 then
		return BOT_ACTION_DESIRE_LOW;
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderShardCombo()
	-- Check if we have shard and all abilities are ready
	if abilityTWR == nil or abilityTWR:IsHidden() or 
	   not abilityTW:IsFullyCastable() or not abilityTD:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nCastRange = abilityTW:GetSpecialValueInt("range");
	local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();

	-- Don't use combo if too low health (risky)
	if healthPercent < 0.4 then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- TEAMFIGHT: Jump in, slow enemies, jump out
	if mutil.IsInTeamFight(npcBot, 1200) then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #enemies >= 2 then
			-- Find best location to hit multiple enemies with Time Dilation
			local nRadius = abilityTD:GetSpecialValueInt("radius");
			local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
			if locationAoE.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
			end
		end
	end

	-- HARASSMENT: Safe poke in lane
	if npcBot:GetActiveMode() == BOT_MODE_LANING and healthPercent > 0.6 then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #enemies >= 1 and #enemies <= 2 then
			return BOT_ACTION_DESIRE_MODERATE, enemies[1]:GetLocation();
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTimeWalk()
	-- Check if ability is castable
	if abilityTW == nil or not abilityTW:IsFullyCastable() or npcBot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- Don't use if in Chronosphere (already has speed boost)
	if npcBot:HasModifier("modifier_faceless_void_chronosphere_speed") then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nCastRange = abilityTW:GetSpecialValueInt("range");
	local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();

	-- EMERGENCY HEAL: Use for health recovery after taking damage
	if DotaTime() - lastDamageTime < 2.0 and healthPercent < 0.5 then
		-- Time Walk to a safe location to heal
		if mutil.IsRetreating(npcBot) then
			local escapeLocation = mutil.GetEscapeLoc();
			local safeLocation = npcBot:GetXUnitsTowardsLocation(escapeLocation, nCastRange);
			return BOT_ACTION_DESIRE_VERYHIGH, safeLocation;
		else
			-- Walk backwards to safety
			local backLocation = npcBot:GetXUnitsInFront(-nCastRange);
			return BOT_ACTION_DESIRE_HIGH, backLocation;
		end
	end

	-- ESCAPE: Retreating from danger
	if mutil.IsRetreating(npcBot) then
		local enemies = mutil.SafeGetNearbyHeroes(npcBot, 1000, true, BOT_MODE_NONE);
		if npcBot:WasRecentlyDamagedByAnyHero(2.0) or #enemies > 1 then
			local escapeLocation = mutil.GetEscapeLoc();
			return BOT_ACTION_DESIRE_HIGH, npcBot:GetXUnitsTowardsLocation(escapeLocation, nCastRange);
		end
	end

	-- INITIATION: Jump to enemy
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) and 
		   not mutil.IsInRange(npcTarget, npcBot, 200) then
			
			-- Check if it's safe to jump (not outnumbered badly)
			local nearbyEnemies = mutil.SafeGetNearbyHeroes(npcTarget, 800, false, BOT_MODE_NONE);
			local nearbyAllies = mutil.SafeGetNearbyHeroes(npcBot, 1200, false, BOT_MODE_NONE);
			if #nearbyEnemies <= #nearbyAllies + 1 then
				return BOT_ACTION_DESIRE_MODERATE, npcTarget:GetExtrapolatedLocation(0.3);
			end
		end
	end

	-- POSITIONING: Get unstuck
	if mutil.IsStuck(npcBot) then
		local escapeLocation = mutil.GetEscapeLoc();
		return BOT_ACTION_DESIRE_HIGH, npcBot:GetXUnitsTowardsLocation(escapeLocation, nCastRange);
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTimeDilation()
	-- Check if ability is castable
	if abilityTD == nil or not abilityTD:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- Don't use if Time Walk is planned (save for combo)
	local twDesire, _ = ConsiderTimeWalk();
	if twDesire > 0 and abilityTWR ~= nil and not abilityTWR:IsHidden() then
		return BOT_ACTION_DESIRE_NONE;
	end

	local nRadius = abilityTD:GetSpecialValueInt("radius");

	-- INTERRUPT: Slow channeling enemies
	local enemies = mutil.SafeGetNearbyHeroes(npcBot, nRadius, true, BOT_MODE_NONE);
	for _, enemy in pairs(enemies) do
		if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- TEAMFIGHT: Slow multiple enemies
	if mutil.IsInTeamFight(npcBot, 1200) then
		if #enemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH;
		elseif #enemies >= 1 then
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end

	-- RETREAT: Slow pursuing enemies
	if mutil.IsRetreating(npcBot) then
		for _, enemy in pairs(enemies) do
			if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) then
				return BOT_ACTION_DESIRE_HIGH;
			end
		end
	end

	-- OFFENSIVE: Slow target when going on someone
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and 
		   mutil.IsInRange(npcTarget, npcBot, nRadius) then
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderChronosphere()
	-- Check if ability is castable
	if abilityCS == nil or not abilityCS:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nRadius = abilityCS:GetSpecialValueInt("radius");
	local nCastRange = abilityCS:GetCastRange();

	-- TEAMFIGHT: Catch multiple enemies
	if mutil.IsInTeamFight(npcBot, 1200) then
		local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
		if locationAoE.count >= 2 then
			-- Check we won't catch too many allies
			local alliesInChrono = mutil.GetAlliesNearLoc(locationAoE.targetloc, nRadius);
			if #alliesInChrono <= 1 then -- Allow catching 1 ally if we get 2+ enemies
				return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
			end
		end
	end

	-- GOING ON SOMEONE: Catch high-value target
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and 
		   mutil.IsInRange(npcTarget, npcBot, nCastRange + nRadius/2) then
			
			-- Check how many enemies we'll catch
			local enemiesNearTarget = mutil.SafeGetNearbyHeroes(npcTarget, nRadius/2, false, BOT_MODE_NONE);
			local validEnemies = 0;
			for _, enemy in pairs(enemiesNearTarget) do
				if mutil.CanCastOnMagicImmune(enemy) then
					validEnemies = validEnemies + 1;
				end
			end
			
			if validEnemies >= 1 then
				-- Check allies won't be caught
				local alliesInChrono = mutil.GetAlliesNearLoc(npcTarget:GetLocation(), nRadius);
				if #alliesInChrono <= 1 then
					return BOT_ACTION_DESIRE_MODERATE, npcTarget:GetLocation();
				end
			end
		end
	end

	-- ESCAPE: Defensive Chronosphere
	if mutil.IsRetreating(npcBot) then
		local enemies = mutil.SafeGetNearbyHeroes(npcBot, nCastRange + nRadius/2, true, BOT_MODE_NONE);
		local nearbyAllies = mutil.SafeGetNearbyHeroes(npcBot, 1000, false, BOT_MODE_NONE);
		
		if #nearbyAllies >= 2 then -- Have backup
			for _, enemy in pairs(enemies) do
				if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) then
					local alliesInChrono = mutil.GetAlliesNearLoc(enemy:GetLocation(), nRadius);
					if #alliesInChrono <= 1 then
						return BOT_ACTION_DESIRE_LOW, enemy:GetLocation();
					end
				end
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

-- ANTI-STUCK MODE OVERRIDE FUNCTIONS
function GetDesire()
	if npcBot == nil then npcBot = GetBot(); end
	
	local distanceFromFountain = npcBot:DistanceFromFountain();
	local botLevel = npcBot:GetLevel();
	
	if distanceFromFountain < 2000 and botLevel >= 6 and DotaTime() > 180 then
		return BOT_MODE_DESIRE_ABSOLUTE;
	end
	
	if distanceFromFountain < 1500 and DotaTime() > 120 and 
	   npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.6 and
	   not npcBot:WasRecentlyDamagedByAnyHero(5.0) then
		return BOT_MODE_DESIRE_VERYHIGH;
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

function ModeDesire()
	if npcBot == nil then npcBot = GetBot(); end
	
	local distanceFromFountain = npcBot:DistanceFromFountain();
	local botLevel = npcBot:GetLevel();
	
	if distanceFromFountain < 1800 and botLevel >= 6 and 
	   npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.5 and
	   DotaTime() > 180 then
		return BOT_MODE_DESIRE_ABSOLUTE;
	end
	
	return BOT_MODE_DESIRE_NONE;
end


