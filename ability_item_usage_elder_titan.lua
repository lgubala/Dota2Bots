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

local castASDesire = 0;
local castSCDesire = 0;
local castSPDesire = 0;
local castMoveDesire = 0;

local abilitySC = nil;  -- Echo Stomp
local abilityAS = nil;  -- Ancestral Spirit
local abilitySP = nil;  -- Earth Splitter
local abilityMove = nil; -- Move Spirit

local npcBot = nil;

-- Spirit state tracking for combo system
local spiritCastTime = 0;
local spiritMoveTime = 0;
local spiritDuration = 8.0; -- Approximate spirit duration
local comboState = "none"; -- "spirit_cast", "spirit_moving", "ready_for_stomp"

function AbilityUsageThink()

	if npcBot == nil then npcBot = GetBot(); end
	
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end

	if abilitySC == nil then abilitySC = npcBot:GetAbilityByName( "elder_titan_echo_stomp" ) end
	if abilityAS == nil then abilityAS = npcBot:GetAbilityByName( "elder_titan_ancestral_spirit" ) end
	if abilitySP == nil then abilitySP = npcBot:GetAbilityByName( "elder_titan_earth_splitter" ) end
	if abilityMove == nil then abilityMove = npcBot:GetAbilityByName( "elder_titan_move_spirit" ) end

	-- Update combo state
	UpdateComboState();

	-- Consider using each ability
	castSCDesire = ConsiderEchoStomp();
	castASDesire, castASLocation = ConsiderAncestralSpirit();
	castSPDesire, castSPLocation = ConsiderEarthSplitter();
	castMoveDesire, castMoveLocation = ConsiderMoveSpirit();
	
	-- Priority: Ultimate > Spirit Movement (for positioning) > Echo Stomp > Ancestral Spirit
	if ( castSPDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnLocation( abilitySP, castSPLocation );
		return;
	end
	
	if ( castMoveDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnLocation( abilityMove, castMoveLocation );
		spiritMoveTime = DotaTime();
		return;
	end
	
	if ( castSCDesire > 0 ) 
	then
		npcBot:Action_UseAbility( abilitySC );
		comboState = "ready_for_stomp"; -- Reset after stomp
		return;
	end
	
	if ( castASDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnLocation( abilityAS, castASLocation );
		spiritCastTime = DotaTime();
		comboState = "spirit_cast";
		return;
	end
	
end

function UpdateComboState()
	local currentTime = DotaTime();
	
	-- Check if spirit expired
	if comboState ~= "none" and currentTime - spiritCastTime > spiritDuration then
		comboState = "none";
		spiritCastTime = 0;
		spiritMoveTime = 0;
	end
	
	-- Update combo progression
	if comboState == "spirit_cast" and currentTime - spiritCastTime > 1.0 then
		comboState = "spirit_moving";
	end
end

function ConsiderMoveSpirit()
	-- Only consider if we have an active spirit and move ability is available
	if not mutil.CanBeCast(abilityMove) or comboState ~= "spirit_moving" then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = abilityMove:GetCastRange();
	
	-- Find best position to move spirit for maximum enemy contact
	local bestLocation = nil;
	local maxEnemyCount = 0;
	local spiritRadius = 275; -- Approximate spirit effect radius
	
	-- TEAMFIGHT: Position spirit to affect most enemies
	if mutil.IsInTeamFight(npcBot, 1200) then
		local enemies = npcBot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
		if #enemies >= 2 then
			-- Find center of enemy group
			local totalX, totalY = 0, 0;
			for _, enemy in pairs(enemies) do
				local loc = enemy:GetLocation();
				totalX = totalX + loc.x;
				totalY = totalY + loc.y;
			end
			local centerX = totalX / #enemies;
			local centerY = totalY / #enemies;
			local centerLoc = Vector(centerX, centerY, 0);
			
			-- Check if this position is within move range
			if GetUnitToLocationDistance(npcBot, centerLoc) <= nCastRange then
				return BOT_ACTION_DESIRE_HIGH, centerLoc;
			end
		end
	end
	
	-- OFFENSIVE: Move spirit toward target
	if mutil.IsGoingOnSomeone(npcBot) then
		local target = npcBot:GetTarget();
		if mutil.IsValidTarget(target) and mutil.IsInRange(target, npcBot, nCastRange) then
			-- Move spirit slightly ahead of target to account for movement
			local targetLoc = target:GetExtrapolatedLocation(1.5);
			return BOT_ACTION_DESIRE_HIGH, targetLoc;
		end
	end
	
	-- DEFENSIVE: Move spirit between bot and enemies when retreating
	if mutil.IsRetreating(npcBot) then
		local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
		if #enemies > 0 then
			-- Position spirit between bot and closest enemy
			local closestEnemy = enemies[1];
			local minDist = GetUnitToUnitDistance(npcBot, closestEnemy);
			for _, enemy in pairs(enemies) do
				local dist = GetUnitToUnitDistance(npcBot, enemy);
				if dist < minDist then
					minDist = dist;
					closestEnemy = enemy;
				end
			end
			
			local botLoc = npcBot:GetLocation();
			local enemyLoc = closestEnemy:GetLocation();
			local midPoint = Vector((botLoc.x + enemyLoc.x) / 2, (botLoc.y + enemyLoc.y) / 2, 0);
			
			if GetUnitToLocationDistance(npcBot, midPoint) <= nCastRange then
				return BOT_ACTION_DESIRE_MODERATE, midPoint;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderEchoStomp()

	-- Make sure it's castable
	if ( not abilitySC:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE;
	end

	local nRadius = abilitySC:GetSpecialValueInt( "radius" );
	local nCastRange = 0;
	local nDamage = abilitySC:GetSpecialValueInt( "stomp_damage" );

	-- COMBO TIMING: Wait for spirit to be positioned if in combo
	if comboState == "spirit_cast" or comboState == "spirit_moving" then
		local timeSinceSpirit = DotaTime() - spiritCastTime;
		local timeSinceMove = DotaTime() - spiritMoveTime;
		
		-- Wait at least 2 seconds after spirit cast, and 1 second after movement
		if timeSinceSpirit < 2.0 or (spiritMoveTime > 0 and timeSinceMove < 1.0) then
			return BOT_ACTION_DESIRE_NONE;
		end
	end

	-- INTERRUPT: Channeling enemies (highest priority)
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nRadius, true, BOT_MODE_NONE );
	for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
	do
		if ( mutil.SafeIsChanneling(npcEnemy) and mutil.CanCastOnNonMagicImmune(npcEnemy) ) 
		then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end
	
	-- TEAMFIGHT: Use after spirit positioning
	if mutil.IsInTeamFight(npcBot, 1200) then
		if #tableNearbyEnemyHeroes >= 2 then
			return BOT_ACTION_DESIRE_HIGH;
		elseif #tableNearbyEnemyHeroes >= 1 and comboState ~= "none" then
			-- Use if we have spirit active for bonus damage
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end
	
	-- RETREATING: Escape stun
	if mutil.IsRetreating(npcBot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy)  ) 
			then
				return BOT_ACTION_DESIRE_HIGH;
			end
		end
	end

	-- FARMING: Clear creeps when pushing
	if mutil.IsPushing(npcBot)
	then
		local tableNearbyEnemyCreeps = npcBot:GetNearbyLaneCreeps( nRadius, true );
		if ( tableNearbyEnemyCreeps ~= nil and #tableNearbyEnemyCreeps >= 3 and  npcBot:GetMana()/npcBot:GetMaxMana() > 0.6 ) then
			return BOT_ACTION_DESIRE_LOW;
		end
	end
	
	-- OFFENSIVE: Going on someone
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nRadius)
		then
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderAncestralSpirit()

	-- Make sure it's castable
	if ( not abilityAS:IsFullyCastable() ) 
	then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	-- Don't cast if spirit is already active (avoid wasting)
	if comboState ~= "none" then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local nRadius = abilityAS:GetSpecialValueInt( "radius" );
	local nCastRange = math.min(abilityAS:GetCastRange(), 1600);
	local nCastPoint = abilityAS:GetCastPoint( );
	local nDamage = abilityAS:GetSpecialValueInt("pass_damage");

	-- INTERRUPT: Channeling enemies
	local enemies = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
	for _, enemy in pairs(enemies) do
		if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
			return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
		end
	end

	-- RETREATING: Slow pursuers
	if mutil.IsRetreating(npcBot)
	then
		for _,npcEnemy in pairs( enemies )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) ) 
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
			end
		end
	end
	
	-- TEAMFIGHT: Initiate combo
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local locationAoE = npcBot:FindAoELocation( true, true, npcBot:GetLocation(), nCastRange, nRadius, 0, 0 );
		if ( locationAoE.count >= 2 ) then
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
		end
	end
	
	-- FARMING: Clear creeps
	if ( mutil.IsDefending(npcBot) or mutil.IsPushing(npcBot) ) and npcBot:GetMana() / npcBot:GetMaxMana() > 0.6
	then
		local lanecreeps = npcBot:GetNearbyLaneCreeps(nCastRange+200, true);
		local locationCAoE = npcBot:FindAoELocation( true, false, npcBot:GetLocation(), nCastRange, nRadius, 0, 0 );
		if ( locationCAoE.count >= 3 and #lanecreeps >= 3  ) 
		then
			return BOT_ACTION_DESIRE_MODERATE, locationCAoE.targetloc;
		end
	end
	
	-- OFFENSIVE: Going on someone - start combo
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange-200)
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget:GetExtrapolatedLocation( 2*nCastPoint );
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;
end

function ConsiderEarthSplitter()

	-- Make sure it's castable
	if ( not abilitySP:IsFullyCastable() ) 
	then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	local nRadius = abilitySP:GetSpecialValueInt("crack_width");
	local nCastRange = math.min(abilitySP:GetCastRange(), 1600);
	local nCastPoint = abilitySP:GetCastPoint();
	local nPercentageHP = abilitySP:GetSpecialValueInt("damage_pct");
	local nCrackTime = abilitySP:GetSpecialValueInt("crack_time");

	-- COMBO TIMING: Use after echo stomp for guaranteed hit
	if comboState == "ready_for_stomp" then
		local enemies = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
		if #enemies >= 1 then
			-- Find best target for Earth Splitter after stomp
			local bestTarget = enemies[1];
			for _, enemy in pairs(enemies) do
				if enemy:HasModifier("modifier_elder_titan_echo_stomp") then
					bestTarget = enemy;
					break;
				end
			end
			return BOT_ACTION_DESIRE_VERYHIGH, bestTarget:GetExtrapolatedLocation( nCastPoint + nCrackTime - 1.0 );
		end
	end

	-- RETREATING: Hit pursuers
	if mutil.IsRetreating(npcBot)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) ) 
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetExtrapolatedLocation( nCastPoint + nCrackTime - 1.5 );
			end
		end
	end
	
	-- TEAMFIGHT: High damage percentage-based ultimate
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local locationAoE = npcBot:FindAoELocation( true, true, npcBot:GetLocation(), 1000, nRadius, 0, 0 );
		if ( locationAoE.count >= 2 ) then
			local nInvUnit = mutil.FindNumInvUnitInLoc(false, npcBot, 1200, nRadius, locationAoE.targetloc);
			if nInvUnit >= locationAoE.count then
				return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
			end
		end
	end
	
	-- OFFENSIVE: Going on someone
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, 1000)
		then
			local tableNearbyEnemyHeroes = npcTarget:GetNearbyHeroes( 1000, false, BOT_MODE_NONE );
			local nInvUnit = mutil.CountInvUnits(true, tableNearbyEnemyHeroes);
			if nInvUnit >= 1 then
				return BOT_ACTION_DESIRE_HIGH, npcTarget:GetExtrapolatedLocation( nCastPoint + nCrackTime - 1.5 );
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;
end