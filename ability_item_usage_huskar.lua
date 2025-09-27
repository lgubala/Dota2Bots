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
local abilityIF = nil; -- Inner Fire (Q)
local abilityBS = nil; -- Burning Spear (W)  
local abilityBB = nil; -- Berserker's Blood (E)
local abilityLB = nil; -- Life Break (R)

local npcBot = nil;

-- State management variables
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Huskar-specific constants
local SAFE_HP_THRESHOLD = 0.15;
local OPTIMAL_HP_RANGE = 0.4;
local BERSERKER_HP_THRESHOLD = 0.7;

function AbilityUsageThink()
	if npcBot == nil then npcBot = GetBot(); end
	
	-- IMMEDIATE FOUNTAIN STUCK FIX
	local distanceFromFountain = npcBot:DistanceFromFountain();
	local botLevel = npcBot:GetLevel();
	local currentMode = npcBot:GetActiveMode();
	
	-- Nuclear fix: If at fountain and level 6+, force immediate movement
	if distanceFromFountain <= 50 and botLevel >= 1 and DotaTime() > 60 then
		npcBot:Action_ClearActions(false);
		
		-- Use safe lane location instead of hardcoded coordinates
		local escapeLocation = GetLaneFrontLocation(GetTeam(), npcBot:GetAssignedLane(), 0.3);
		if escapeLocation == nil then
			-- Fallback to mid lane if assigned lane fails
			escapeLocation = GetLaneFrontLocation(GetTeam(), LANE_MID, 0.3);
		end
		
		if escapeLocation ~= nil then
			npcBot:Action_MoveToLocation(escapeLocation);
			return;
		end
	end
	
	-- Secondary fix: Override retreat mode when healthy  
	if distanceFromFountain < 500 and currentMode == BOT_MODE_RETREAT and 
	   botLevel >= 1 and npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.8 then
		
		npcBot:Action_ClearActions(false);
		
		-- Use assigned lane or fallback to mid
		local laneLocation = GetLaneFrontLocation(GetTeam(), npcBot:GetAssignedLane(), 0.4);
		if laneLocation == nil then
			laneLocation = GetLaneFrontLocation(GetTeam(), LANE_MID, 0.4);
		end
		
		if laneLocation ~= nil then
			npcBot:Action_MoveToLocation(laneLocation);
			return;
		end
	end
	
	-- Handle death/respawn state management
	if not npcBot:IsAlive() then
		lastDeathTime = DotaTime();
		isRecoveringFromDeath = true;
		return;
	end
	
	-- Post-death recovery period with immediate movement fix
	if isRecoveringFromDeath and DotaTime() - lastDeathTime < postDeathCooldown then
		-- Force movement immediately after respawn if stuck
		if distanceFromFountain < 300 then
			npcBot:Action_ClearActions(false);
			local escapeLocation = nil;
			if GetTeam() == TEAM_RADIANT then
				escapeLocation = Vector(-6000, -6000, 0);
			else
				escapeLocation = Vector(6000, 6000, 0);
			end
			if escapeLocation ~= nil then
				npcBot:Action_MoveToLocation(escapeLocation);
			end
		end
		return;
	elseif isRecoveringFromDeath then
		isRecoveringFromDeath = false;
	end
	
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end

	-- Initialize abilities by name
	if abilityIF == nil then abilityIF = npcBot:GetAbilityByName("huskar_inner_fire"); end
	if abilityBS == nil then abilityBS = npcBot:GetAbilityByName("huskar_burning_spear"); end
	if abilityBB == nil then abilityBB = npcBot:GetAbilityByName("huskar_berserkers_blood"); end
	if abilityLB == nil then abilityLB = npcBot:GetAbilityByName("huskar_life_break"); end

	-- Get current health percentage
	local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
	
	-- Consider using each ability
	local castLBDesire, castLBTarget = ConsiderLifeBreak();
	local castIFDesire = ConsiderInnerFire();
	local castBSDesire, castBSTarget = ConsiderBurningSpear();
	local castBBDesire = ConsiderBerserkersBlood();

	-- COMBO: Life Break + Inner Fire (highest priority)
	if castLBDesire > 0 and castIFDesire > 0 and castLBTarget ~= nil and 
	   abilityLB ~= nil and abilityIF ~= nil and
	   abilityLB:IsFullyCastable() and abilityIF:IsFullyCastable() then
		npcBot:Action_ClearActions(false);
		npcBot:ActionQueue_UseAbilityOnEntity(abilityLB, castLBTarget);
		npcBot:ActionQueue_UseAbility(abilityIF);
		return;
	end

	-- Priority order: Ultimate > Self-buff > Offensive > Defensive
	if castLBDesire > 0 and castLBTarget ~= nil then
		if abilityLB ~= nil then
			npcBot:Action_UseAbilityOnEntity(abilityLB, castLBTarget);
			return;
		end
	end

	if castBBDesire > 0 then
		if abilityBB ~= nil then
			npcBot:Action_UseAbility(abilityBB);
			return;
		end
	end

	if castBSDesire > 0 and castBSTarget ~= nil then
		if abilityBS ~= nil then
			npcBot:Action_UseAbilityOnEntity(abilityBS, castBSTarget);
			return;
		end
	end

	if castIFDesire > 0 then
		if abilityIF ~= nil then
			npcBot:Action_UseAbility(abilityIF);
			return;
		end
	end
end

function ConsiderLifeBreak()
	if abilityLB == nil or not abilityLB:IsFullyCastable() or npcBot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = abilityLB:GetCastRange();
	local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
	
	-- Don't use if we're too low on health
	if healthPercent < 0.25 then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- TEAMFIGHT: Very aggressive ultimate usage
	if mutil.IsInTeamFight(npcBot, 1200) then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		for _, enemy in pairs(enemies) do
			if mutil.CanCastOnMagicImmune(enemy) and mutil.IsValidTarget(enemy) then
				return BOT_ACTION_DESIRE_VERYHIGH, enemy;
			end
		end
	end

	-- GOING ON SOMEONE: Primary initiation tool
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and 
		   mutil.IsInRange(npcTarget, npcBot, nCastRange) then
			return BOT_ACTION_DESIRE_VERYHIGH, npcTarget;
		end
	end

	-- ESCAPE: Life Break can be used to escape by jumping to a far enemy
	if mutil.IsRetreating(npcBot) and healthPercent < 0.3 then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		local escapeLocation = mutil.GetEscapeLoc();
		local bestEscapeTarget = nil;
		local bestDistance = 0;
		
		for _, enemy in pairs(enemies) do
			if mutil.CanCastOnMagicImmune(enemy) then
				local distanceToEscape = GetUnitToLocationDistance(enemy, escapeLocation);
				if distanceToEscape > bestDistance then
					bestDistance = distanceToEscape;
					bestEscapeTarget = enemy;
				end
			end
		end
		
		if bestEscapeTarget ~= nil and bestDistance > 400 then
			return BOT_ACTION_DESIRE_HIGH, bestEscapeTarget;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderInnerFire()
	if abilityIF == nil or not abilityIF:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local nRadius = abilityIF:GetSpecialValueInt("radius");
	local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();

	-- INTERRUPT: Interrupt channeling
	local enemies = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
	for _, enemy in pairs(enemies) do
		if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
			return BOT_ACTION_DESIRE_VERYHIGH;
		end
	end

	-- DEFENSIVE: Use when being attacked
	if mutil.IsRetreating(npcBot) or npcBot:WasRecentlyDamagedByAnyHero(2.0) then
		if #enemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- TEAMFIGHT: Use in teamfights
	if mutil.IsInTeamFight(npcBot, 1200) then
		if #enemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH;
		elseif #enemies >= 1 then
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end

	-- OFFENSIVE: After Life Break or when going on someone
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and 
		   mutil.IsInRange(npcTarget, npcBot, nRadius) then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- HARASSMENT: Use during laning
	if npcBot:GetActiveMode() == BOT_MODE_LANING and healthPercent > 0.3 then
		if #enemies >= 1 then
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end

	-- FARMING: Clear creep waves
	if (npcBot:GetActiveMode() == BOT_MODE_LANING or mutil.IsPushing(npcBot)) and healthPercent > 0.4 then
		local creeps = npcBot:GetNearbyLaneCreeps(nRadius, true);
		if #creeps >= 3 then
			return BOT_ACTION_DESIRE_LOW;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderBurningSpear()
	if abilityBS == nil or not abilityBS:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = abilityBS:GetCastRange();
	local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();

	-- Don't use if we're too low on health
	if healthPercent < SAFE_HP_THRESHOLD then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- TEAMFIGHT: Use on priority targets
	if mutil.IsInTeamFight(npcBot, 1200) then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #enemies >= 1 then
			-- Prioritize low-health enemies
			for _, enemy in pairs(enemies) do
				if mutil.CanCastOnNonMagicImmune(enemy) and enemy:GetHealth() < enemy:GetMaxHealth() * 0.4 then
					return BOT_ACTION_DESIRE_HIGH, enemy;
				end
			end
			-- Any enemy if no low-health targets
			for _, enemy in pairs(enemies) do
				if mutil.CanCastOnNonMagicImmune(enemy) then
					return BOT_ACTION_DESIRE_MODERATE, enemy;
				end
			end
		end
	end

	-- GOING ON SOMEONE: Primary damage ability
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and 
		   mutil.IsInRange(npcTarget, npcBot, nCastRange) then
			return BOT_ACTION_DESIRE_HIGH, npcTarget;
		end
	end

	-- HARASSMENT: Use during laning
	if npcBot:GetActiveMode() == BOT_MODE_LANING and healthPercent > 0.4 then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #enemies >= 1 then
			return BOT_ACTION_DESIRE_MODERATE, enemies[1];
		end
	end

	-- LAST HITTING: Use to secure kills
	if healthPercent > 0.3 then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		for _, enemy in pairs(enemies) do
			if mutil.CanCastOnNonMagicImmune(enemy) and enemy:GetHealth() < 200 then
				return BOT_ACTION_DESIRE_VERYHIGH, enemy;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderBerserkersBlood()
	if abilityBB == nil or not abilityBB:IsFullyCastable() or abilityBB:IsHidden() then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();

	-- Don't use if we're already low
	if healthPercent < 0.5 then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- AGGRESSIVE: Use when going on someone and we're too healthy
	if mutil.IsGoingOnSomeone(npcBot) and healthPercent > BERSERKER_HP_THRESHOLD then
		return BOT_ACTION_DESIRE_HIGH;
	end

	-- TEAMFIGHT: Use at start of teamfight to get damage bonus
	if mutil.IsInTeamFight(npcBot, 1200) and healthPercent > BERSERKER_HP_THRESHOLD then
		local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
		if #enemies >= 2 then
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end

	-- FARMING: Use when farming and full health
	if (npcBot:GetActiveMode() == BOT_MODE_LANING or mutil.IsPushing(npcBot)) and 
	   healthPercent > 0.8 then
		return BOT_ACTION_DESIRE_LOW;
	end
	
	return BOT_ACTION_DESIRE_NONE;
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


