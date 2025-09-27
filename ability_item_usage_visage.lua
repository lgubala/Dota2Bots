if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
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

-- Ability variables
local abilityGC = nil;  -- Grave Chill (Q)
local abilitySA = nil;  -- Soul Assumption (W)
local abilityGK = nil;  -- Gravekeeper's Cloak (E) - passive, becomes active with shard
local abilitySF = nil;  -- Summon Familiars (R)
local abilitySSC = nil; -- Stone Form Self Cast (D)
local abilitySG = nil;  -- Silent as the Grave (Scepter ability)

-- Cooldown tracking to prevent spam
local lastSummonAttempt = 0;
local SUMMON_COOLDOWN = 5.0;  -- Increased cooldown to prevent spam
local lastFamiliarCheck = 0;
local FAMILIAR_CHECK_INTERVAL = 1.0;  -- Only check familiars once per second
local cachedFamiliarCount = 0;

local npcBot = nil;

-- Desire variables
local castGCDesire = 0;
local castSADesire = 0;
local castGKDesire = 0;
local castSFDesire = 0;
local castSSCDesire = 0;
local castSGDesire = 0;

function AbilityUsageThink()
	if npcBot == nil then npcBot = GetBot(); end
	
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end

	-- Initialize abilities by name (more reliable for complex heroes)
	if abilityGC == nil then abilityGC = npcBot:GetAbilityByName("visage_grave_chill"); end
	if abilitySA == nil then abilitySA = npcBot:GetAbilityByName("visage_soul_assumption"); end
	if abilityGK == nil then abilityGK = npcBot:GetAbilityByName("visage_gravekeepers_cloak"); end
	if abilitySF == nil then abilitySF = npcBot:GetAbilityByName("visage_summon_familiars"); end
	if abilitySSC == nil then abilitySSC = npcBot:GetAbilityByName("visage_stone_form_self_cast"); end
	if abilitySG == nil then abilitySG = npcBot:GetAbilityByName("visage_silent_as_the_grave"); end
	
	-- Fallback: Try slot-based initialization for ultimate if name-based fails
	if abilitySF == nil then
		--print("[VISAGE] Name-based initialization failed, trying slot-based for ultimate");
		abilitySF = npcBot:GetAbilityInSlot(5); -- Ultimate is typically in slot 5
		if abilitySF ~= nil then
			--print("[VISAGE] Slot-based ultimate found: " .. abilitySF:GetName());
		end
	end
	
	-- Consider using each ability
	castGCDesire, castGCTarget = ConsiderGraveChill();
	castSADesire, castSATarget = ConsiderSoulAssumption();
	castGKDesire = ConsiderGravekeepersCloakActive();
	castSFDesire = ConsiderSummonFamiliars();
	castSSCDesire = ConsiderStoneFormSelfCast();
	castSGDesire = ConsiderSilentAsTheGrave();

	-- Debug output for testing (reduced frequency)
	if npcBot:GetUnitName() == "npc_dota_hero_visage" and math.fmod(GameTime(), 2.0) < 0.1 then
		local saStacks = GetSoulAssumptionStacks();
		local familiarCount = GetFamiliarCountSafe();
		--print("[VISAGE] Debug - GC:" .. castGCDesire .. " SA:" .. castSADesire .. " (stacks:" .. saStacks .. ") SF:" .. castSFDesire .. " familiars:" .. familiarCount);
	end

	-- Priority order: Emergency abilities > Ultimate > Offensive > Utility
	
	-- EMERGENCY: Gravekeeper's Cloak active (shard) when about to die
	if castGKDesire > 0 then
		--print("[VISAGE] Using Gravekeeper's Cloak (Emergency Save)!");
		npcBot:Action_UseAbility(abilityGK);
		return;
	end
	
	-- EMERGENCY: Silent as the Grave for escape
	if castSGDesire > BOT_ACTION_DESIRE_MODERATE then
		--print("[VISAGE] Using Silent as the Grave (Escape)!");
		npcBot:Action_UseAbility(abilitySG);
		return;
	end
	
	-- ULTIMATE: Summon Familiars (with enhanced protection and multiple methods)
	if castSFDesire > 0 then
		--print("[VISAGE] Attempting to summon familiars...");
		lastSummonAttempt = DotaTime();
		
		-- Clear actions first
		npcBot:Action_ClearActions(false);
		
		-- CRITICAL: Try to force the correct facet/mode before casting
		-- Based on research, Visage has facet issues with familiar control
		
		-- Method 1: Standard cast (most likely to work)
		--print("[VISAGE] Method 1: Standard Action_UseAbility");
		npcBot:Action_UseAbility(abilitySF);
		
		-- Method 2: Try immediate command - some abilities need instant execution
		--print("[VISAGE] Method 2: Action_Immediate");
		npcBot:Action_UseAbility(abilitySF);
		npcBot:Action_UseAbility(abilitySF); -- Double cast sometimes works for bugged abilities
		
		-- Method 3: Use the generic ability system as fallback
		--print("[VISAGE] Method 3: Calling generic ability system");
		if ability_item_usage_generic and ability_item_usage_generic.AbilityUsageThink then
			-- Let the generic system try to handle it
			ability_item_usage_generic.AbilityUsageThink();
		end
		
		return;
	end
	
	-- OFFENSIVE: Soul Assumption (high damage nuke)
	if castSADesire > 0 then
		npcBot:Action_UseAbilityOnEntity(abilitySA, castSATarget);
		return;
	end
	
	-- UTILITY: Stone Form Self Cast (familiar control)
	if castSSCDesire > 0 then
		npcBot:Action_UseAbility(abilitySSC);
		return;
	end
	
	-- UTILITY: Grave Chill (slow)
	if castGCDesire > 0 then
		npcBot:Action_UseAbilityOnEntity(abilityGC, castGCTarget);
		return;
	end
	
	-- ROAMING: Silent as the Grave for positioning
	if castSGDesire > 0 then
		npcBot:Action_UseAbility(abilitySG);
		return;
	end
end

function GetSoulAssumptionStacks()
	local npcModifier = npcBot:NumModifiers();
	
	for i = 0, npcModifier do
		if npcBot:GetModifierName(i) == "modifier_visage_soul_assumption" then
			return npcBot:GetModifierStackCount(i);
		end
	end
	
	return 0;
end

-- Enhanced familiar detection - try multiple approaches
function GetFamiliarCountSafe()
	local currentTime = DotaTime();
	
	-- Use cached value if checked recently
	if currentTime - lastFamiliarCheck < FAMILIAR_CHECK_INTERVAL then
		return cachedFamiliarCount;
	end
	
	lastFamiliarCheck = currentTime;
	local familiarCount = 0;
	
	--print("[VISAGE] === COMPREHENSIVE UNIT SEARCH ===");
	
	-- Method 1: Standard approach - check all allies
	local listAllies = GetUnitList(UNIT_LIST_ALLIES);
	
	if listAllies ~= nil then
		--print("[VISAGE] Checking " .. #listAllies .. " allied units:");
		for i, unit in pairs(listAllies) do
			-- Add safety checks for unit validity
			if unit ~= nil and unit:IsAlive() then
				local unitName = unit:GetUnitName();
				if unitName ~= nil then
					--print("[VISAGE] Allied unit " .. i .. ": " .. unitName .. " at " .. unit:GetLocation().x .. "," .. unit:GetLocation().y);
					
					-- Check for multiple possible familiar unit names
					if string.find(unitName, "npc_dota_visage_familiar") or 
					   string.find(unitName, "visage_familiar") or
					   string.find(unitName, "familiar") then
						familiarCount = familiarCount + 1;
						--print("[VISAGE] *** FOUND FAMILIAR: " .. unitName .. " ***");
					end
				end
			end
		end
	end
	
	-- Method 2: Check all units (not just allies) in case of team assignment issues
	if familiarCount == 0 then
		--print("[VISAGE] No familiars in allies, checking ALL units...");
		local allUnits = GetUnitList(UNIT_LIST_ALL);
		if allUnits ~= nil then
			for i, unit in pairs(allUnits) do
				if unit ~= nil and unit:IsAlive() then
					local unitName = unit:GetUnitName();
					if unitName ~= nil then
						-- Look for familiar-specific names, but exclude the hero himself
						if (string.find(unitName, "visage_familiar") or string.find(unitName, "familiar")) and not string.find(unitName, "npc_dota_hero_visage") then
							--print("[VISAGE] All units - Found visage familiar: " .. unitName .. " Team:" .. unit:GetTeam() .. " vs Bot Team:" .. npcBot:GetTeam());
							if unit:GetTeam() == npcBot:GetTeam() then
								familiarCount = familiarCount + 1;
								--print("[VISAGE] *** FOUND FAMILIAR IN ALL UNITS: " .. unitName .. " ***");
							end
						end
					end
				end
			end
		end
	end
	
	-- Method 3: Check for summoned units using a different API
	if familiarCount == 0 then
		--print("[VISAGE] No familiars found anywhere. Checking if ability actually works...");
		
		-- Try to find units by proximity (familiars spawn near Visage)
		local nearbyUnits = npcBot:GetNearbyCreeps(800, false); -- Check friendly creeps in 800 range
		if nearbyUnits ~= nil then
			--print("[VISAGE] Found " .. #nearbyUnits .. " nearby friendly creeps:");
			for i, unit in pairs(nearbyUnits) do
				if unit ~= nil and unit:IsAlive() then
					local unitName = unit:GetUnitName();
					--print("[VISAGE] Nearby creep " .. i .. ": " .. unitName);
					if string.find(unitName, "visage") or string.find(unitName, "familiar") then
						familiarCount = familiarCount + 1;
						--print("[VISAGE] *** FOUND FAMILIAR VIA PROXIMITY: " .. unitName .. " ***");
					end
				end
			end
		end
	end
	
	--print("[VISAGE] === END UNIT SEARCH - Total familiar count: " .. familiarCount .. " ===");
	cachedFamiliarCount = familiarCount;
	return familiarCount;
end

-- Alternative method using unit enumeration
function GetFamiliarCountAlternative()
	local familiarCount = 0;
	
	-- Check for specific familiar unit names
	local familiarNames = {
		"npc_dota_visage_familiar1",
		"npc_dota_visage_familiar2", 
		"npc_dota_visage_familiar3"
	};
	
	for _, familiarName in pairs(familiarNames) do
		local units = Entities:FindAllByName(familiarName);
		if units ~= nil then
			for _, unit in pairs(units) do
				if unit ~= nil and unit:IsAlive() and unit:GetTeam() == npcBot:GetTeam() then
					familiarCount = familiarCount + 1;
				end
			end
		end
	end
	
	return familiarCount;
end

function GetClosestFamiliarSafe()
	local closestFamiliar = nil;
	local closestDistance = 9999;
	local listAllies = GetUnitList(UNIT_LIST_ALLIES);
	
	if listAllies ~= nil then
		for _, unit in pairs(listAllies) do
			if unit ~= nil and unit:IsAlive() then
				local unitName = unit:GetUnitName();
				if unitName ~= nil and string.find(unitName, "npc_dota_visage_familiar") then
					-- Safety check before distance calculation
					if npcBot ~= nil and npcBot:IsAlive() then
						local distance = GetUnitToUnitDistance(npcBot, unit);
						if distance < closestDistance then
							closestDistance = distance;
							closestFamiliar = unit;
						end
					end
				end
			end
		end
	end
	
	return closestFamiliar;
end

function GetLowestHPFamiliarSafe()
	local lowestFamiliar = nil;
	local lowestHPPercent = 1.0;
	local listAllies = GetUnitList(UNIT_LIST_ALLIES);
	
	if listAllies ~= nil then
		for _, unit in pairs(listAllies) do
			if unit ~= nil and unit:IsAlive() then
				local unitName = unit:GetUnitName();
				if unitName ~= nil and string.find(unitName, "npc_dota_visage_familiar") then
					local hpPercent = mutil.SafeGetHealthPercent(unit);
					if hpPercent < lowestHPPercent then
						lowestHPPercent = hpPercent;
						lowestFamiliar = unit;
					end
				end
			end
		end
	end
	
	return lowestFamiliar, lowestHPPercent;
end

function ConsiderGraveChill()
	-- Make sure it's castable
	if not mutil.CanBeCast(abilityGC) then 
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nCastRange = abilityGC:GetCastRange();
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);

	-- INTERRUPT: Channeling enemies (highest priority)
	for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
		if mutil.SafeIsChanneling(npcEnemy) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy;
		end
	end

	-- TEAMFIGHT: Use on priority targets
	if mutil.IsInTeamFight(npcBot, 1200) then
		for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
			if mutil.CanCastOnNonMagicImmune(npcEnemy) then
				return BOT_ACTION_DESIRE_MODERATE, npcEnemy;
			end
		end
	end
	
	-- OFFENSIVE: When hunting someone
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange + 200) then
			return BOT_ACTION_DESIRE_HIGH, npcTarget;
		end
	end
	
	-- DEFENSIVE: When retreating
	if mutil.IsRetreating(npcBot) then
		for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
			if npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
				return BOT_ACTION_DESIRE_MODERATE, npcEnemy;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderSoulAssumption()
	-- Make sure it's castable
	if not mutil.CanBeCast(abilitySA) then 
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nCastRange = abilitySA:GetCastRange();
	local saStacks = GetSoulAssumptionStacks();
	local nStackLimit = abilitySA:GetSpecialValueInt("stack_limit");
	local nBaseDamage = abilitySA:GetSpecialValueInt("soul_base_damage");
	local nChargeDamage = abilitySA:GetSpecialValueInt("soul_charge_damage");
	local nTotalDamage = nBaseDamage + (saStacks * nChargeDamage);
	
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);

	-- KILL: Use if we can kill someone
	for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
		if mutil.CanKillTarget(npcEnemy, nTotalDamage, DAMAGE_TYPE_MAGICAL) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
			return BOT_ACTION_DESIRE_VERYHIGH, npcEnemy;
		end
	end
	
	-- INTERRUPT: Channeling enemies with max stacks
	for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
		if mutil.SafeIsChanneling(npcEnemy) and mutil.CanCastOnNonMagicImmune(npcEnemy) and saStacks >= nStackLimit - 1 then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy;
		end
	end

	-- TEAMFIGHT: Use with max stacks
	if mutil.IsInTeamFight(npcBot, 1200) and saStacks >= nStackLimit then
		for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
			if mutil.IsValidTarget(npcEnemy) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy;
			end
		end
	end
	
	-- OFFENSIVE: When going on someone with max stacks
	if mutil.IsGoingOnSomeone(npcBot) and saStacks >= nStackLimit then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange + 200) then
			return BOT_ACTION_DESIRE_HIGH, npcTarget;
		end
	end
	
	-- DEFENSIVE: When retreating with max stacks
	if mutil.IsRetreating(npcBot) and saStacks >= nStackLimit then
		for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
			if npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
				return BOT_ACTION_DESIRE_MODERATE, npcEnemy;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderGravekeepersCloakActive()
	-- Only consider if we have shard (ability becomes active)
	if abilityGK == nil or not abilityGK:IsFullyCastable() or abilityGK:IsHidden() then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local healthPercent = mutil.SafeGetHealthPercent(npcBot);
	
	-- EMERGENCY: Use when about to die
	if healthPercent < 0.2 then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
		if #tableNearbyEnemyHeroes > 0 then
			return BOT_ACTION_DESIRE_VERYHIGH;
		end
	end
	
	-- DEFENSIVE: Use when low HP and being focused
	if healthPercent < 0.35 and npcBot:WasRecentlyDamagedByAnyHero(1.0) then
		return BOT_ACTION_DESIRE_HIGH;
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderSummonFamiliars()
	-- Check if the ability exists but isn't skilled yet
	if abilitySF ~= nil and abilitySF:GetLevel() == 0 then
		if npcBot:GetAbilityPoints() > 0 and npcBot:GetLevel() >= 6 then
			--print("[VISAGE] Ultimate not skilled yet but we have points - trying to skill it");
			--print("[VISAGE] Bot Level: " .. npcBot:GetLevel() .. " Ability Points: " .. npcBot:GetAbilityPoints());
			npcBot:Action_LevelAbility(abilitySF:GetName());
			return BOT_ACTION_DESIRE_NONE;
		else
			--print("[VISAGE] Ultimate not skilled - Level:" .. npcBot:GetLevel() .. " Points:" .. npcBot:GetAbilityPoints() .. " Need level 6+");
			return BOT_ACTION_DESIRE_NONE;
		end
	end
	
	-- Make sure it's castable
	if not mutil.CanBeCast(abilitySF) then 
		--print("[VISAGE] Summon Familiars not castable - Cooldown:" .. abilitySF:GetCooldownTimeRemaining() .. " Mana:" .. abilitySF:GetManaCost() .. "/" .. npcBot:GetMana() .. " Level:" .. abilitySF:GetLevel());
		
		-- Additional debug for mana cost issues
		if abilitySF:GetManaCost() == 0 then
			--print("[VISAGE] WARNING: Ability shows 0 mana cost - this might be a bug");
		end
		
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- Check if bot is busy
	if mutil.SafeIsChanneling(npcBot) or npcBot:IsUsingAbility() then
		--print("[VISAGE] Bot is busy - channeling:" .. tostring(npcBot:IsChanneling()) .. " using ability:" .. tostring(npcBot:IsUsingAbility()));
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- Check if we recently attempted to summon (prevent spam)
	if DotaTime() - lastSummonAttempt < SUMMON_COOLDOWN then
		--print("[VISAGE] Summon on cooldown - " .. (SUMMON_COOLDOWN - (DotaTime() - lastSummonAttempt)) .. " seconds remaining");
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- Use safe familiar counting
	local familiarCount = GetFamiliarCountSafe();
	local maxFamiliars = 2; -- Base value, could be 3 with talent
	
	-- Debug ability state
	--print("[VISAGE] Ability state - Name:" .. abilitySF:GetName() .. " Level:" .. abilitySF:GetLevel() .. " Hidden:" .. tostring(abilitySF:IsHidden()) .. " Toggle:" .. tostring(abilitySF:IsToggle()));
	--print("[VISAGE] Ability IsFullyCastable:" .. tostring(abilitySF:IsFullyCastable()) .. " IsActivated:" .. tostring(abilitySF:IsActivated()));
	
	-- Only summon if we actually need familiars (adjust count since our search incorrectly counts Visage himself)
	local actualFamiliarCount = familiarCount - 1; -- Subtract 1 because we're counting Visage as a familiar
	if actualFamiliarCount >= maxFamiliars then
		--print("[VISAGE] Already have enough familiars: " .. actualFamiliarCount .. "/" .. maxFamiliars);
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- Don't summon if lots of enemies nearby (they'll kill familiars instantly)
	local nearbyEnemies = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
	if #nearbyEnemies >= 3 then
		--print("[VISAGE] Too many enemies nearby: " .. #nearbyEnemies);
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- Don't summon if very low on mana - but ignore if mana cost shows as 0 (bug)
	local manaCost = abilitySF:GetManaCost();
	if manaCost > 0 and npcBot:GetMana() < manaCost + 100 then -- Save some mana for other spells
		--print("[VISAGE] Not enough mana: " .. npcBot:GetMana() .. "/" .. (manaCost + 100));
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- HIGH priority if we have no familiars
	if actualFamiliarCount <= 0 then
		--print("[VISAGE] HIGH priority summon - no familiars (actual count: " .. actualFamiliarCount .. ")");
		return BOT_ACTION_DESIRE_HIGH;
	end
	
	-- MODERATE priority if we're missing some
	--print("[VISAGE] MODERATE priority summon - missing familiars (actual count: " .. actualFamiliarCount .. ")");
	return BOT_ACTION_DESIRE_MODERATE;
end

function ConsiderStoneFormSelfCast()
	-- Make sure it's castable and we have familiars
	if not mutil.CanBeCast(abilitySSC) then 
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local familiarCount = GetFamiliarCountSafe();
	if familiarCount == 0 then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local lowestFamiliar, lowestHPPercent = GetLowestHPFamiliarSafe();
	
	-- EMERGENCY: Save low HP familiar
	if lowestHPPercent < 0.3 then
		return BOT_ACTION_DESIRE_HIGH;
	end
	
	-- OFFENSIVE: Use when going on someone to stun
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) then
			local closestFamiliar = GetClosestFamiliarSafe();
			if closestFamiliar ~= nil then
				-- Use if familiar is close to target for stun
				local familiarToTargetDist = GetUnitToUnitDistance(closestFamiliar, npcTarget);
				if familiarToTargetDist < 400 then
					return BOT_ACTION_DESIRE_MODERATE;
				end
			end
		end
	end
	
	-- TEAMFIGHT: Use for AoE stun
	if mutil.IsInTeamFight(npcBot, 1200) then
		local closestFamiliar = GetClosestFamiliarSafe();
		if closestFamiliar ~= nil then
			local nearbyEnemies = closestFamiliar:GetNearbyHeroes(375, true, BOT_MODE_NONE);
			if #nearbyEnemies >= 2 then
				return BOT_ACTION_DESIRE_MODERATE;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderSilentAsTheGrave()
	-- Check if we have scepter first
	if not npcBot:HasScepter() then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- Make sure it's castable
	if not mutil.CanBeCast(abilitySG) then 
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- EMERGENCY: When retreating and in danger
	if mutil.IsRetreating(npcBot) then
		local healthPercent = mutil.SafeGetHealthPercent(npcBot);
		if healthPercent < 0.4 then
			local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
			if #tableNearbyEnemyHeroes > 0 then
				return BOT_ACTION_DESIRE_VERYHIGH;
			end
		end
	end
	
	-- ROAMING: When moving around the map
	if npcBot:GetActiveMode() == BOT_MODE_ROAM then
		return BOT_ACTION_DESIRE_LOW;
	end
	
	-- POSITIONING: When going to hunt someone
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) then
			local distance = GetUnitToUnitDistance(npcBot, npcTarget);
			-- Use invis to get closer if target is far
			if distance > 800 then
				return BOT_ACTION_DESIRE_LOW;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE;
end


