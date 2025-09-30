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


local castMFDesire = 0;
local castBHDesire = 0;
--local castDCDesire = 0;
local castMPDesire = 0;

local abilityMF = nil;
local abilityBH = nil;
--local abilityDC = nil;
local abilityMP = nil;


local npcBot = nil;

local bot = GetBot();
local abilities = {};
local lastBlackHoleTime = 0;
local lastActionLog = {};
local isChannelingBlackHole = false;
local blackHoleStartTime = 0;

local function LogAction(actionType, details)
	if isChannelingBlackHole then
		--print("[ENIGMA_ACTION_LOG] " .. actionType .. " called while channeling Black Hole: " .. (details or ""));
		table.insert(lastActionLog, {time = DotaTime(), action = actionType, details = details});
		
		-- Keep only last 10 actions
		if #lastActionLog > 10 then
			table.remove(lastActionLog, 1);
		end
	end
end

function AbilityUsageThink()
	if GetGameState() ~= GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
		return;
	end

	-- DETAILED CHANNELING PROTECTION AND LOGGING
	if mutil.SafeIsChanneling(bot) then
		-- Set the flag when we ACTUALLY detect channeling
		if not isChannelingBlackHole then
			--print("[ENIGMA] DETECTED Black Hole channeling started!");
			isChannelingBlackHole = true;
			blackHoleStartTime = DotaTime();
		end
		
		local channelingAbility = nil;
		for i = 0, 5 do
			local ability = bot:GetAbilityInSlot(i);
			if ability ~= nil and mutil.SafeIsChanneling(ability) then
				channelingAbility = ability:GetName();
				break;
			end
		end
		
		if channelingAbility then
			--print("[CHANNELING_PROTECTION] " .. bot:GetUnitName() .. " is channeling " .. channelingAbility .. " - BLOCKING AbilityLevelUpThink");
			return;
		end
	end

	if isChannelingBlackHole then
		local queuedActions = npcBot:NumQueuedActions();
		local currentAction = npcBot:GetCurrentActionType();
		local isChanneling = mutil.SafeIsChanneling(npcBot);
		
		--print("[ENIGMA_CHANNEL_STATUS] Time: " .. DotaTime() .. " Channeling: " .. tostring(isChanneling) .. " QueuedActions: " .. queuedActions .. " CurrentAction: " .. currentAction);
		
		if not isChanneling then
			--print("[ENIGMA_INTERRUPTION] Black Hole was interrupted! Last actions:");
			for _, action in pairs(lastActionLog) do
				--print("  " .. action.time .. ": " .. action.action .. " - " .. (action.details or ""));
			end
			isChannelingBlackHole = false;
		end
		
		-- Log any new actions being queued
		if queuedActions > 0 then
			LogAction("QUEUED_ACTION", "Count: " .. queuedActions);
		end
	end

	if isChannelingBlackHole and not mutil.SafeIsChanneling(npcBot) then
		--print("[ENIGMA] Black Hole channeling ended");
		isChannelingBlackHole = false;
	end

	-- Track what threatens channeling
	if bot:GetUnitName() == "npc_dota_hero_enigma" then
		--print("[ENIGMA_DEBUG] AbilityLevelUpThink - Channeling: " .. tostring(mutil.SafeIsChanneling(bot)) .. " UsingAbility: " .. tostring(bot:IsUsingAbility()));
	end

	if npcBot == nil then npcBot = GetBot(); end
	
	-- Use the new ability system
	if #abilities == 0 then abilities = mutil.InitiateAbilities(npcBot, {0,1,2,5}) end
	    
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end
	
	-- CRITICAL: Don't interrupt channeling abilities like Black Hole
	if mutil.SafeIsChanneling(npcBot) then 
		--print("[ENIGMA] Currently channeling - not casting other abilities");
		return 
	end

	-- Consider using each ability
	castBHDesire, castBHLocation = ConsiderBlackHole();
	castMPDesire, castMPLocation = ConsiderMidnightPulse();
	castMFDesire, castMFTarget = ConsiderMalefice();
	castDCDesire = ConsiderDemonicConversion();
	
	local desires = "Desires - MF: " .. castMFDesire .. " DC: " .. castDCDesire .. " MP: " .. castMPDesire .. " BH: " .. castBHDesire;
	--print("[ENIGMA] " .. desires);
	
	-- COMBO: Midnight Pulse + Black Hole combo
	if castBHDesire > 0 and castMPDesire > 0 and mutil.CanBeCast(abilities[3]) then
		--print("[ENIGMA] Using COMBO: Midnight Pulse + Black Hole!");
		-- DON'T set isChannelingBlackHole = true here - wait for confirmation
		lastBlackHoleTime = DotaTime();
		npcBot:Action_ClearActions(false);
		npcBot:ActionQueue_UseAbilityOnLocation(abilities[3], castBHLocation);
		npcBot:ActionQueue_UseAbilityOnLocation(abilities[4], castBHLocation);
		return;
	end
	
	if ( castMFDesire > 0 ) 
	then
		--print("[ENIGMA] Using Malefice on " .. castMFTarget:GetUnitName());
		npcBot:Action_UseAbilityOnEntity( abilities[1], castMFTarget );
		return;
	end
	
	if ( castDCDesire > 0 ) 
	then
		--print("[ENIGMA] Using Demonic Conversion!");
		-- Use on a nearby neutral creep location or our own location
		local nearbyCreeps = npcBot:GetNearbyNeutralCreeps(400);
		local castLocation = npcBot:GetLocation();
		
		if #nearbyCreeps > 0 then
			castLocation = nearbyCreeps[1]:GetLocation();
		end
		
		npcBot:Action_UseAbilityOnLocation(abilities[2], castLocation);
		return;
	end
	
	if ( castMPDesire > 0 ) 
	then
		--print("[ENIGMA] Using Midnight Pulse!");
		npcBot:Action_UseAbilityOnLocation( abilities[3], castMPLocation );
		return;
	end
	
	if (castBHDesire > 0 )
	then
		--print("[ENIGMA] Using Black Hole!");
		-- DON'T set isChannelingBlackHole = true here - wait for confirmation
		lastBlackHoleTime = DotaTime();
		npcBot:Action_UseAbilityOnLocation(abilities[4], castBHLocation)
		return
	end
end


function ConsiderMalefice()

	if not mutil.CanBeCast(abilities[1]) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = abilities[1]:GetCastRange();
	local nDamage = 4 * abilities[1]:GetSpecialValueInt("damage");
	local nManaCost = abilities[1]:GetManaCost();
	
	--print("[ENIGMA] Malefice check - Range: " .. nCastRange .. " Damage: " .. nDamage);
	
	-- INTERRUPT: Channeling heroes (highest priority)
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange + 200, true, BOT_MODE_NONE );
	for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
	do
		if ( mutil.SafeIsChanneling(npcEnemy) and mutil.CanCastOnNonMagicImmune(npcEnemy) ) 
		then
			--print("[ENIGMA] INTERRUPT Malefice on " .. npcEnemy:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, npcEnemy;
		end
	end
	
	-- HARASSMENT: Use during laning
	if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, nManaCost)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #tableNearbyEnemyHeroes >= 1 then
			--print("[ENIGMA] HARASSMENT Malefice on " .. tableNearbyEnemyHeroes[1]:GetUnitName());
			return BOT_ACTION_DESIRE_MODERATE, tableNearbyEnemyHeroes[1];
		end
	end

	-- TEAMFIGHT: Use in teamfights
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #enemies >= 1 then
			--print("[ENIGMA] TEAMFIGHT Malefice on " .. enemies[1]:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, enemies[1];
		end
	end
	
	-- ROSHAN
	if ( npcBot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
	then
		local npcTarget = mutil.SafeGetAttackTarget(npcBot);
		if ( mutil.IsRoshan(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)  )
		then
			--print("[ENIGMA] ROSHAN Malefice");
			return BOT_ACTION_DESIRE_LOW, npcTarget;
		end
	end
	
	-- RETREAT: If seriously retreating
	if mutil.IsRetreating(npcBot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy) ) 
			then
				--print("[ENIGMA] RETREAT Malefice on " .. npcEnemy:GetUnitName());
				return BOT_ACTION_DESIRE_HIGH, npcEnemy;
			end
		end
	end
	
	-- GOING ON SOMEONE
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange+200)
		then
			--print("[ENIGMA] OFFENSIVE Malefice on " .. npcTarget:GetUnitName());
			return BOT_ACTION_DESIRE_MODERATE, npcTarget;
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderDemonicConversion()

	if not mutil.CanBeCast(abilities[2]) then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local nManaCost = abilities[2]:GetManaCost();
	local nHealthCost = 75 + (abilities[2]:GetLevel() - 1) * 25; -- Manual calculation: 75/100/125/150
	
	--print("[ENIGMA] Demonic Conversion check - ManaCost: " .. nManaCost .. " HealthCost: " .. nHealthCost);

	-- Don't use if too low on health (accounting for health cost)
	if npcBot:GetHealth() < nHealthCost + (npcBot:GetMaxHealth() * 0.2) then
		--print("[ENIGMA] Demonic Conversion - Not enough health");
		return BOT_ACTION_DESIRE_NONE;
	end

	-- LANING: Use for farming and harassment
	if npcBot:GetActiveMode() == BOT_MODE_LANING then
		if npcBot:GetMana()/npcBot:GetMaxMana() > 0.4 then -- Reduced from 0.65
			--print("[ENIGMA] LANING Demonic Conversion");
			return BOT_ACTION_DESIRE_MODERATE;
		end
	end 
	
	-- PUSHING/DEFENDING: Use for map control
	if mutil.IsDefending(npcBot) or mutil.IsPushing(npcBot)
	then
		if npcBot:GetMana()/npcBot:GetMaxMana() > 0.3 then -- Reduced from 0.45
			--print("[ENIGMA] PUSH/DEFEND Demonic Conversion");
			return BOT_ACTION_DESIRE_HIGH;
		end		
	end
	
	-- TEAMFIGHT: Use for additional units
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		if npcBot:GetMana()/npcBot:GetMaxMana() > 0.4 then
			--print("[ENIGMA] TEAMFIGHT Demonic Conversion");
			return BOT_ACTION_DESIRE_HIGH;
		end		
	end
	
	-- GOING ON SOMEONE: Use for pressure
	if mutil.IsGoingOnSomeone(npcBot)
	then
		if npcBot:GetMana()/npcBot:GetMaxMana() > 0.5 then -- Reduced from 0.65
			--print("[ENIGMA] OFFENSIVE Demonic Conversion");
			return BOT_ACTION_DESIRE_HIGH;
		end		
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderMidnightPulse()

	if not mutil.CanBeCast(abilities[3]) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nRadius = abilities[3]:GetSpecialValueInt( "radius" );
	local nCastRange = abilities[3]:GetCastRange();
	local nCastPoint = abilities[3]:GetCastPoint();
	local nManaCost = abilities[3]:GetManaCost();

	--print("[ENIGMA] Midnight Pulse check - Range: " .. nCastRange .. " Radius: " .. nRadius);

	-- HARASSMENT: Use during laning
	if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, nManaCost)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #tableNearbyEnemyHeroes >= 1 then
			--print("[ENIGMA] HARASSMENT Midnight Pulse on " .. tableNearbyEnemyHeroes[1]:GetUnitName());
			return BOT_ACTION_DESIRE_MODERATE, tableNearbyEnemyHeroes[1]:GetExtrapolatedLocation(nCastPoint);
		end
	end

	-- FARMING: Use for farming creeps
	if (npcBot:GetActiveMode() == BOT_MODE_LANING or mutil.IsPushing(npcBot) or mutil.IsDefending(npcBot)) 
	   and mutil.AllowedToSpam(npcBot, nManaCost)
	then
		local tableNearbyCreeps = npcBot:GetNearbyLaneCreeps(nRadius, true);
		if #tableNearbyCreeps >= 3 then
			--print("[ENIGMA] FARMING Midnight Pulse - " .. #tableNearbyCreeps .. " creeps");
			return BOT_ACTION_DESIRE_LOW, tableNearbyCreeps[1]:GetLocation();
		end
	end

	if mutil.IsStuck(npcBot)
	then
		--print("[ENIGMA] STUCK Midnight Pulse");
		return BOT_ACTION_DESIRE_HIGH, npcBot:GetLocation();
	end
	
	-- RETREAT: If retreating
	if mutil.IsRetreating(npcBot)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) ) 
			then
				--print("[ENIGMA] RETREAT Midnight Pulse");
				return BOT_ACTION_DESIRE_MODERATE, npcBot:GetLocation();
			end
		end
	end
	
	-- TEAMFIGHT: Use in teamfights
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local locationAoE = npcBot:FindAoELocation( true, true, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0 );
		if ( locationAoE.count >= 2 ) then
			--print("[ENIGMA] TEAMFIGHT Midnight Pulse - " .. locationAoE.count .. " enemies");
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
		elseif ( locationAoE.count >= 1 ) then -- Single target acceptable
			--print("[ENIGMA] TEAMFIGHT Midnight Pulse (single) - " .. locationAoE.count .. " enemy");
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
		end
	end
	
	-- GOING ON SOMEONE
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange+(nRadius/2))
		then
			--print("[ENIGMA] OFFENSIVE Midnight Pulse on " .. npcTarget:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, npcTarget:GetExtrapolatedLocation(nCastPoint);
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end




function ConsiderBlackHole()

	if DotaTime() - lastBlackHoleTime < 2.0 then  -- REDUCED from 5.0 to 2.0
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	if not mutil.CanBeCast(abilities[4]) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	if mutil.SafeIsChanneling(npcBot) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	local nRadius = abilities[4]:GetSpecialValueInt( "radius" );
	local nCastRange = abilities[4]:GetCastRange();
	local nCastPoint = abilities[4]:GetCastPoint();

	--print("[ENIGMA] Black Hole check - Range: " .. nCastRange .. " Radius: " .. nRadius);
	
	-- -- AGGRESSIVE: Use on any nearby enemy (NEW)
	-- local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange+nRadius, true, BOT_MODE_NONE );
	-- if #tableNearbyEnemyHeroes >= 1 and not mutil.IsRetreating(npcBot) then
	-- 	--print("[ENIGMA] AGGRESSIVE Black Hole - " .. #tableNearbyEnemyHeroes .. " enemies nearby");
	-- 	return BOT_ACTION_DESIRE_MODERATE, tableNearbyEnemyHeroes[1]:GetLocation();
	-- end
	
	-- EMERGENCY: If retreating and low HP
	if mutil.IsRetreating(npcBot) and npcBot:GetHealth() < 0.4 * npcBot:GetMaxHealth()
	then
		-- DEFINE the variable first!
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(math.min(nRadius + 200, 1600), true, BOT_MODE_NONE);
		
		if #tableNearbyEnemyHeroes >= 2 then
			--print("[ENIGMA] EMERGENCY Black Hole - " .. #tableNearbyEnemyHeroes .. " enemies while retreating");
			return BOT_ACTION_DESIRE_VERYHIGH, tableNearbyEnemyHeroes[1]:GetLocation();
		elseif #tableNearbyEnemyHeroes >= 1 then -- Single target when desperate
			--print("[ENIGMA] EMERGENCY Black Hole (single) - retreating");
			return BOT_ACTION_DESIRE_HIGH, tableNearbyEnemyHeroes[1]:GetLocation();
		end
	end
	
	-- TEAMFIGHT: Very liberal ultimate usage
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local locationAoE = npcBot:FindAoELocation( true, true, npcBot:GetLocation(), nCastRange, nRadius, 0, 0 );
		if ( locationAoE.count >= 3 ) then -- Ideal scenario
			--print("[ENIGMA] TEAMFIGHT Black Hole - " .. locationAoE.count .. " enemies");
			return BOT_ACTION_DESIRE_VERYHIGH, locationAoE.targetloc;
		elseif ( locationAoE.count >= 2 ) then -- Reduced from higher requirement
			--print("[ENIGMA] TEAMFIGHT Black Hole - " .. locationAoE.count .. " enemies");
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
		end
	end
	
	-- GOING ON SOMEONE: Use ultimate offensively
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange+(nRadius/2))
		then
			local EnemyHeroes = npcTarget:GetNearbyHeroes( nRadius, false, BOT_MODE_NONE );
			if ( EnemyHeroes ~= nil and #EnemyHeroes >= 2 )
			then
				--print("[ENIGMA] OFFENSIVE Black Hole - " .. #EnemyHeroes .. " enemies near target");
				return BOT_ACTION_DESIRE_HIGH, npcTarget:GetExtrapolatedLocation( nCastPoint );
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end