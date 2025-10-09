if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
	return;
end

local ability_item_usage_generic = dofile(GetScriptDirectory().."/ability_item_usage_generic")
local utils = require(GetScriptDirectory() .. "/util")
local mutils = require(GetScriptDirectory() .. "/MyUtility")

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

-- Abilities
local abilityRefraction = nil;
local abilityMeld = nil;
local abilityPsiBlades = nil;
local abilityPsionicTrap = nil;
local abilityTrapActivate = nil;
local abilityTrapTeleport = nil;

-- State tracking
local lastRefractionTime = 0;
local refractionCooldown = 14.0;
local lastMeldTime = 0;
local meldComboTime = 0;
local meldComboWindow = 1.5;
local lastTrapPlaceTime = 0;
local trapPlaceCooldown = 2.0;

-- Trap management
local trapLocations = {};
local maxTrapsToTrack = 11;

function AbilityUsageThink()
	
	if mutils.CanNotUseAbility(bot) then return end
	
	-- CHANNELING PROTECTION - Don't interrupt trap teleport
	if mutils.SafeIsChanneling(bot) then
		return;
	end

	-- Initialize abilities by name
	if abilityRefraction == nil then abilityRefraction = bot:GetAbilityByName("templar_assassin_refraction"); end
	if abilityMeld == nil then abilityMeld = bot:GetAbilityByName("templar_assassin_meld"); end
	if abilityPsiBlades == nil then abilityPsiBlades = bot:GetAbilityByName("templar_assassin_psi_blades"); end
	if abilityPsionicTrap == nil then abilityPsionicTrap = bot:GetAbilityByName("templar_assassin_psionic_trap"); end
	if abilityTrapActivate == nil then abilityTrapActivate = bot:GetAbilityByName("templar_assassin_trap"); end
	if abilityTrapTeleport == nil then abilityTrapTeleport = bot:GetAbilityByName("templar_assassin_trap_teleport"); end

	-- Consider abilities in priority order
	local castTeleportDesire, castTeleportLocation = ConsiderTrapTeleport();
	local castRefractionDesire = ConsiderRefraction();
	local castMeldDesire = ConsiderMeld();
	local castTrapActivateDesire = ConsiderTrapActivate();
	local castTrapPlaceDesire, castTrapPlaceLocation = ConsiderPsionicTrap();

	-- Priority: Teleport > Refraction > Trap Activation > Meld > Trap Placement
	
	-- Trap Teleport (Scepter ability) - highest priority for strategic movement
	if castTeleportDesire > 0 then
		bot:Action_UseAbilityOnLocation(abilityTrapTeleport, castTeleportLocation);
		return;
	end

	-- Refraction - keep it up constantly
	if castRefractionDesire > 0 then
		bot:Action_UseAbility(abilityRefraction);
		lastRefractionTime = DotaTime();
		return;
	end

	-- Activate traps to slow/silence enemies
	if castTrapActivateDesire > 0 then
		bot:Action_UseAbility(abilityTrapActivate);
		return;
	end

	-- Meld for burst damage or escape
	if castMeldDesire > 0 then
		bot:Action_UseAbility(abilityMeld);
		lastMeldTime = DotaTime();
		return;
	end

	-- Place traps strategically
	if castTrapPlaceDesire > 0 then
		bot:Action_UseAbilityOnLocation(abilityPsionicTrap, castTrapPlaceLocation);
		lastTrapPlaceTime = DotaTime();
		table.insert(trapLocations, {loc = castTrapPlaceLocation, time = DotaTime()});
		-- Keep only recent traps
		if #trapLocations > maxTrapsToTrack then
			table.remove(trapLocations, 1);
		end
		return;
	end
end

function ConsiderRefraction()
	-- Keep Refraction up all the time for damage and protection
	if not mutils.CanBeCast(abilityRefraction) then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- Check if we already have the buff
	if bot:HasModifier("modifier_templar_assassin_refraction_damage") or 
	   bot:HasModifier("modifier_templar_assassin_refraction_absorb") then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- Always want Refraction up
	local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
	local manaPercent = bot:GetMana() / bot:GetMaxMana();

	-- Ultra high priority when taking damage or low health
	if bot:WasRecentlyDamagedByAnyHero(2.0) or healthPercent < 0.6 then
		return BOT_ACTION_DESIRE_VERYHIGH;
	end

	-- High priority in combat
	if mutils.IsInTeamFight(bot, 1200) or mutils.IsGoingOnSomeone(bot) then
		return BOT_ACTION_DESIRE_HIGH;
	end

	-- Always keep it up if we have mana
	if manaPercent > 0.3 then
		return BOT_ACTION_DESIRE_MODERATE;
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderMeld()
	if not mutils.CanBeCast(abilityMeld) then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- Don't use if already in Meld
	if bot:HasModifier("modifier_templar_assassin_meld") then
		return BOT_ACTION_DESIRE_NONE;
	end

	local attackRange = bot:GetAttackRange();
	local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
	local manaPercent = bot:GetMana() / bot:GetMaxMana();
	local enemies = bot:GetNearbyHeroes(math.min(attackRange + 400, 1600), true, BOT_MODE_NONE);

	-- Don't waste mana if very low
	if manaPercent < 0.1 then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- OFFENSIVE: Use Meld when enemy is in attack range for bonus damage
	-- This is the PRIMARY use case - hit them with Meld strike!
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) then
			local distanceToTarget = GetUnitToUnitDistance(bot, target);
			-- Use Meld when enemy is very close (within attack range or slightly outside)
			if distanceToTarget <= attackRange + 150 then
				return BOT_ACTION_DESIRE_VERYHIGH;
			end
		end
	end

	-- TEAMFIGHT: Use Meld for burst damage on nearby enemies
	if mutils.IsInTeamFight(bot, 1200) then
		for _, enemy in pairs(enemies) do
			if mutils.IsValidTarget(enemy) then
				local distanceToEnemy = GetUnitToUnitDistance(bot, enemy);
				-- Use Meld when enemy is in attack range
				if distanceToEnemy <= attackRange + 100 then
					return BOT_ACTION_DESIRE_VERYHIGH;
				end
			end
		end
	end

	-- FARMING: Use Meld on creeps for bonus damage (only if we have good mana)
	if mutils.IsPushing(bot) and manaPercent > 0.5 then
		local creeps = bot:GetNearbyLaneCreeps(attackRange + 100, true);
		if #creeps > 0 then
			return BOT_ACTION_DESIRE_LOW;
		end
	end

	-- DEFENSIVE: Use Meld to hide when low HP and retreating
	if mutils.IsRetreating(bot) and healthPercent < 0.35 then
		-- Only hide if enemies are nearby but not too close (they might have AOE)
		if #enemies > 0 and #enemies <= 2 then
			local closestEnemy = enemies[1];
			local distanceToEnemy = GetUnitToUnitDistance(bot, closestEnemy);
			-- Hide when enemy is not too close (avoid AOE detection)
			if distanceToEnemy > 300 and distanceToEnemy < 900 then
				return BOT_ACTION_DESIRE_VERYHIGH;
			end
		end
	end

	-- ESCAPE SETUP: Use Meld when low and blink is almost ready
	local blinkSlot = bot:FindItemSlot("item_blink");
	if healthPercent < 0.4 and #enemies > 0 and blinkSlot >= 0 then
		local blinkItem = bot:GetItemInSlot(blinkSlot);
		if blinkItem ~= nil and not blinkItem:IsFullyCastable() then
			local cooldown = blinkItem:GetCooldownTimeRemaining();
			-- Hide when blink is coming off cooldown soon
			if cooldown < 2.5 and cooldown > 0.5 then
				return BOT_ACTION_DESIRE_VERYHIGH;
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderPsionicTrap()
	if not mutils.CanBeCast(abilityPsionicTrap) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- Don't spam traps too quickly
	if DotaTime() - lastTrapPlaceTime < trapPlaceCooldown then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nCastRange = math.min(abilityPsionicTrap:GetCastRange(), 1600);
	local nManaCost = abilityPsionicTrap:GetManaCost();
	local manaPercent = bot:GetMana() / bot:GetMaxMana();

	-- Don't waste mana on traps if low
	if manaPercent < 0.2 then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- CHASE: Place traps ahead of fleeing enemies
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) then
			local targetLoc = target:GetExtrapolatedLocation(1.0);
			if GetUnitToLocationDistance(bot, targetLoc) < nCastRange then
				return BOT_ACTION_DESIRE_HIGH, targetLoc;
			end
		end
	end

	-- RETREAT: Place traps behind us when fleeing
	if mutils.IsRetreating(bot) then
		local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
		if #enemies > 0 then
			-- Place trap between us and enemies
			local botLoc = bot:GetLocation();
			local enemyLoc = enemies[1]:GetLocation();
			local dx = botLoc.x - enemyLoc.x;
			local dy = botLoc.y - enemyLoc.y;
			local length = math.sqrt(dx * dx + dy * dy);
			if length > 0 then
				dx = dx / length;
				dy = dy / length;
				local retreatLoc = Vector(botLoc.x - dx * 200, botLoc.y - dy * 200);
				return BOT_ACTION_DESIRE_HIGH, retreatLoc;
			end
		end
	end

	-- TEAMFIGHT: Place traps on enemy positions
	if mutils.IsInTeamFight(bot, 1200) then
		local enemies = bot:GetNearbyHeroes(math.min(nCastRange, 1600), true, BOT_MODE_NONE);
		if #enemies >= 2 then
			-- Find clustered enemies
			local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, 400, 0, 0);
			if locationAoE.count >= 2 then
				return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
			end
		end
	end

	-- STRATEGIC: Place traps at key map locations
	local strategicLocations = {
		Vector(-2400, 1600), -- Radiant jungle
		Vector(2400, -1600), -- Dire jungle
		Vector(-1800, -1800), -- Radiant secret shop
		Vector(1800, 1800),   -- Dire secret shop
	};

	-- Place traps at strategic locations when safe and have mana
	if not mutils.IsRetreating(bot) and not mutils.IsInTeamFight(bot, 1600) and manaPercent > 0.5 then
		for _, loc in pairs(strategicLocations) do
			local distance = GetUnitToLocationDistance(bot, loc);
			if distance < nCastRange and distance > 200 then
				-- Check if we already have a trap nearby
				local hasTrapNearby = false;
				for _, trapInfo in pairs(trapLocations) do
					local dx = trapInfo.loc.x - loc.x;
					local dy = trapInfo.loc.y - loc.y;
					local distSq = dx * dx + dy * dy;
					if distSq < 300 * 300 then
						hasTrapNearby = true;
						break;
					end
				end
				if not hasTrapNearby then
					return BOT_ACTION_DESIRE_LOW, loc;
				end
			end
		end
	end

	-- LANE CONTROL: Place traps in lane when pushing/farming
	if mutils.IsPushing(bot) then
		if manaPercent > 0.4 then
			-- Place trap ahead in lane direction
			local frontLoc = bot:GetXUnitsInFront(800);
			if frontLoc ~= nil then
				return BOT_ACTION_DESIRE_LOW, frontLoc;
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTrapActivate()
	if abilityTrapActivate == nil or not abilityTrapActivate:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE;
	end

	local nTrapRadius = 400;
	
	-- Detect if we have Aghanim's Shard (traps get +125 vision)
	local hasShard = false;
	if abilityPsionicTrap ~= nil then
		local trapVision = abilityPsionicTrap:GetSpecialValueInt("bonus_vision");
		if trapVision > 0 then
			hasShard = true;
		end
	end

	-- Get all enemy heroes
	local enemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
	
	for _, enemy in pairs(enemies) do
		if enemy ~= nil and not enemy:IsNull() and enemy:CanBeSeen() then
			local enemyHealth = mutils.SafeGetHealth(enemy);
			
			-- Find traps near this enemy
			for _, trapInfo in pairs(trapLocations) do
				local distanceToEnemy = GetUnitToLocationDistance(enemy, trapInfo.loc);
				
				if distanceToEnemy < nTrapRadius then
					-- INTERRUPT CHANNELING (if we have shard for silence)
					if hasShard and mutils.SafeIsChanneling(enemy) then
						return BOT_ACTION_DESIRE_VERYHIGH;
					end
					
					-- CATCH FLEEING LOW HP ENEMIES
					if enemyHealth > 0 and enemyHealth < enemy:GetMaxHealth() * 0.3 then
						return BOT_ACTION_DESIRE_VERYHIGH;
					end
					
					-- SLOW ENEMIES IN TEAMFIGHT
					if mutils.IsInTeamFight(bot, 1200) then
						return BOT_ACTION_DESIRE_HIGH;
					end
					
					-- CATCH ENEMIES WHEN GOING ON SOMEONE
					if mutils.IsGoingOnSomeone(bot) then
						local target = bot:GetTarget();
						if target == enemy then
							return BOT_ACTION_DESIRE_HIGH;
						end
					end
					
					-- SLOW CHASERS WHEN RETREATING
					if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByHero(enemy, 2.0) then
						return BOT_ACTION_DESIRE_HIGH;
					end
				end
			end
		end
	end

	-- Also check nearby enemies even without trap tracking
	local nearbyEnemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
	if #nearbyEnemies > 0 then
		for _, enemy in pairs(nearbyEnemies) do
			-- Interrupt channeling with shard
			if hasShard and mutils.SafeIsChanneling(enemy) then
				return BOT_ACTION_DESIRE_VERYHIGH;
			end
			
			-- Catch low HP enemies
			local healthPercent = mutils.SafeGetHealthPercent(enemy);
			if healthPercent > 0 and healthPercent < 0.3 then
				return BOT_ACTION_DESIRE_HIGH;
			end
		end
		
		-- Use in teamfights
		if mutils.IsInTeamFight(bot, 1200) and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderTrapTeleport()
	-- Scepter ability - requires checking if scepter is owned
	if abilityTrapTeleport == nil or not abilityTrapTeleport:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	if not bot:HasScepter() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
	local manaPercent = bot:GetMana() / bot:GetMaxMana();
	local botLoc = bot:GetLocation();
	
	-- CRITICAL: Check if it's safe to channel (2 second channel time!)
	-- Don't teleport if enemies are very close - we'll get interrupted
	local nearbyEnemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
	local hasCloseEnemies = false;
	for _, enemy in pairs(nearbyEnemies) do
		local distance = GetUnitToUnitDistance(bot, enemy);
		if distance < 600 then
			hasCloseEnemies = true;
			break;
		end
	end
	
	-- Don't teleport if enemies can interrupt us
	if hasCloseEnemies then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- HEAL: Teleport to fountain trap when low resources (LONG DISTANCE only)
	if (healthPercent < 0.3 or manaPercent < 0.15) and not mutils.IsInTeamFight(bot, 2000) then
		-- Check if we have a trap near fountain
		local fountainLoc = GetAncient(GetTeam()):GetLocation();
		for _, trapInfo in pairs(trapLocations) do
			-- Calculate distance to trap
			local dx = trapInfo.loc.x - botLoc.x;
			local dy = trapInfo.loc.y - botLoc.y;
			local distanceToTrap = math.sqrt(dx * dx + dy * dy);
			
			-- Only teleport if trap is FAR from us (minimum 2000 units)
			if distanceToTrap > 2000 then
				-- Check if trap is near fountain
				local dx2 = trapInfo.loc.x - fountainLoc.x;
				local dy2 = trapInfo.loc.y - fountainLoc.y;
				local distSq = dx2 * dx2 + dy2 * dy2;
				if distSq < 2000 * 2000 then
					return BOT_ACTION_DESIRE_VERYHIGH, trapInfo.loc;
				end
			end
		end
	end

	-- ESCAPE: Teleport to safe trap when low HP (LONG DISTANCE only)
	if healthPercent < 0.25 and bot:WasRecentlyDamagedByAnyHero(3.0) then
		-- Find trap far from enemies AND far from our current position
		for _, trapInfo in pairs(trapLocations) do
			-- Calculate distance to trap
			local dx = trapInfo.loc.x - botLoc.x;
			local dy = trapInfo.loc.y - botLoc.y;
			local distanceToTrap = math.sqrt(dx * dx + dy * dy);
			
			-- Only teleport if trap is FAR from us (minimum 2500 units)
			if distanceToTrap > 2500 then
				local allEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
				local isSafe = true;
				for _, enemy in pairs(allEnemies) do
					if enemy ~= nil and not enemy:IsNull() and enemy:CanBeSeen() then
						if GetUnitToLocationDistance(enemy, trapInfo.loc) < 1200 then
							isSafe = false;
							break;
						end
					end
				end
				if isSafe then
					return BOT_ACTION_DESIRE_VERYHIGH, trapInfo.loc;
				end
			end
		end
	end

	-- STRATEGIC: Jump between lanes for ganks (LONG DISTANCE only)
	if healthPercent > 0.7 and manaPercent > 0.6 and not mutils.IsInTeamFight(bot, 2000) then
		-- Find trap near low HP enemies
		local enemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
		for _, enemy in pairs(enemies) do
			if enemy ~= nil and not enemy:IsNull() and enemy:CanBeSeen() then
				local enemyHealthPercent = mutils.SafeGetHealthPercent(enemy);
				if enemyHealthPercent > 0 and enemyHealthPercent < 0.4 then
					-- Find trap near this enemy
					for _, trapInfo in pairs(trapLocations) do
						-- Calculate distance to trap from bot
						local dx = trapInfo.loc.x - botLoc.x;
						local dy = trapInfo.loc.y - botLoc.y;
						local distanceToTrap = math.sqrt(dx * dx + dy * dy);
						
						-- Only teleport if trap is FAR from us (minimum 3000 units)
						if distanceToTrap > 3000 then
							local distanceToEnemy = GetUnitToLocationDistance(enemy, trapInfo.loc);
							-- Trap should be close to enemy
							if distanceToEnemy < 700 and distanceToEnemy > 200 then
								return BOT_ACTION_DESIRE_MODERATE, trapInfo.loc;
							end
						end
					end
				end
			end
		end
	end

	-- LANE SWITCH: Teleport to defend towers under attack (LONG DISTANCE only)
	local towers = bot:GetNearbyTowers(math.min(4000, 1600), false);
	for _, tower in pairs(towers) do
		if tower:GetHealth() / tower:GetMaxHealth() < 0.5 then
			local towerLoc = tower:GetLocation();
			-- Find trap near this tower
			for _, trapInfo in pairs(trapLocations) do
				-- Calculate distance to trap from bot
				local dx = trapInfo.loc.x - botLoc.x;
				local dy = trapInfo.loc.y - botLoc.y;
				local distanceToTrap = math.sqrt(dx * dx + dy * dy);
				
				-- Only teleport if trap is FAR from us (minimum 3500 units)
				if distanceToTrap > 3500 then
					local dx2 = trapInfo.loc.x - towerLoc.x;
					local dy2 = trapInfo.loc.y - towerLoc.y;
					local distToTower = math.sqrt(dx2 * dx2 + dy2 * dy2);
					if distToTower < 1200 then
						return BOT_ACTION_DESIRE_HIGH, trapInfo.loc;
					end
				end
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end