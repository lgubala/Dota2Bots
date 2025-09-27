--[[
    	"Ability1"		"marci_grapple"
		"Ability2"		"marci_companion_run"
		"Ability3"		"marci_guardian"
		"Ability4"		"generic_hidden"
		"Ability5"		"generic_hidden"
		"Ability6"		"marci_unleash"
--]]

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

local npcBot = GetBot();

local abilityQ = nil;
local abilityW = nil;
local abilityE = nil;
local abilityR = nil;

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;

local qTarget = nil;
local wTarget = nil;
local eTarget = nil;

local castWLoc = nil;

function AbilityUsageThink()
	
	-- Check if we're already using an ability - SAME PATTERN AS WORKING PRIMAL BEAST
	if mutil.CanNotUseAbility(npcBot) then return end
	
	if abilityQ == nil then abilityQ = npcBot:GetAbilityByName( "marci_grapple" ) end
	if abilityW == nil then abilityW = npcBot:GetAbilityByName( "marci_companion_run" ) end
	if abilityE == nil then abilityE = npcBot:GetAbilityByName( "marci_guardian" ) end
	if abilityR == nil then abilityR = npcBot:GetAbilityByName( "marci_unleash" ) end

	castQDesire, qTarget            = ConsiderQ();
	castWDesire, castWLoc, wTarget	= ConsiderW();
	castEDesire, eTarget   			= ConsiderE();
	castRDesire    					= ConsiderR();

	-- PRIORITY SYSTEM LIKE WORKING PRIMAL BEAST
	-- Priority 1: Guardian (save allies)
	if ( castEDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnEntity( abilityE, eTarget );
		return;
	end

	-- Priority 2: Grapple (disable/interrupt)
	if ( castQDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnEntity( abilityQ, qTarget );
		return;
	end

	-- Priority 3: Unleash (combat buff)
	if ( castRDesire > 0 ) 
	then
		npcBot:Action_UseAbility( abilityR );
		return;
	end
	
	-- Priority 4: Companion Run (mobility)
	if ( castWDesire > 0  and mutil.IsValidTarget(wTarget)) 
	then
		npcBot:Action_UseAbilityOnEntity(abilityW, wTarget);
		npcBot:Action_UseAbilityOnLocation(abilityW, castWLoc);
		return;
	end
end

function ConsiderQ()
	-- Make sure it's castable - SAME PATTERN AS WORKING CODE
	if not mutil.CanBeCast(abilityQ) then 
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- Get some of its values
	local nCastRange = abilityQ:GetCastRange( );
	local nDamage    = abilityQ:GetAbilityDamage( );
			
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange + 200, true, BOT_MODE_NONE );
	
	-- INTERRUPT: Channeling enemies (HIGHEST PRIORITY LIKE PRIMAL BEAST)
	for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
	do
		if mutil.SafeIsChanneling(npcEnemy) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
			return BOT_ACTION_DESIRE_VERYHIGH, npcEnemy;
		end
	end
	
	--if we can kill any enemies
	for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
	do
		if mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.CanKillTarget(npcEnemy, nDamage, DAMAGE_TYPE_MAGICAL) then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy;
		end
	end
	
	-- GOING ON SOMEONE: When engaging (LIKE WORKING PRIMAL BEAST PATTERN)
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange+200) 
            and not mutil.IsDisabled(true, npcTarget) 		
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget;
		end
	end
	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		if tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 1 then
			return BOT_ACTION_DESIRE_LOW, tableNearbyEnemyHeroes[1];
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderW()
	-- Make sure it's castable - SAME PATTERN AS WORKING CODE
	if not mutil.CanBeCast(abilityW) then 
		return BOT_ACTION_DESIRE_NONE, 0, nil;
	end

	-- Get some of its values
	local nCastRange = abilityW:GetCastRange();
	local nMinDistance = 450;
	local nMaxDistance = 800;
	local nDamage    = abilityW:GetSpecialValueInt('impact_damage');
	
	-- Get allies that are valid jump targets
	local tableNearbyAlliedHeroes = npcBot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
	for _,npcAlly in pairs(tableNearbyAlliedHeroes)
	do
		local tableNearbyEnemyHeroes = npcAlly:GetNearbyHeroes(nMaxDistance, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
		do
			-- check if enemy is in castable distance
			local allyDistanceToEnemy = GetUnitToUnitDistance(npcAlly, npcEnemy)
			if allyDistanceToEnemy >= nMinDistance then
				-- if we can kill the enemy
				if mutil.CanCastOnMagicImmune(npcEnemy) and mutil.CanKillTarget(npcEnemy, nDamage, DAMAGE_TYPE_MAGICAL) then
					return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation(), npcAlly;
				end
				
				-- GOING ON SOMEONE: When engaging (LIKE WORKING PRIMAL BEAST PATTERN)
				if mutil.IsGoingOnSomeone(npcBot)
				then
					local npcTarget = npcBot:GetTarget();
					if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget)
					then
						return BOT_ACTION_DESIRE_HIGH, npcTarget:GetLocation(), npcAlly;
					end
				end
			end
		end
		
		-- If we're seriously retreating, see if we can use ally as escape
		if mutil.IsRetreating(npcBot)
		then
			-- check if ally is closer to fountain and jump towards fountain
			if npcBot:DistanceFromFountain() > npcAlly:DistanceFromFountain() then
				return BOT_ACTION_DESIRE_HIGH, GetShopLocation(GetTeam(), SHOP_HOME), npcAlly;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0, nil;
end

function ConsiderE()
	-- Make sure it's castable - SAME PATTERN AS WORKING CODE
	if not mutil.CanBeCast(abilityE) then 
		return BOT_ACTION_DESIRE_NONE, nil;
	end

	-- Get some of its values
	local nCastRange = abilityE:GetCastRange();
	
	-- FARMING: Use on self when farming (LIKE WORKING PRIMAL BEAST PATTERN)
	if  npcBot:GetActiveMode() == BOT_MODE_FARM 
	    and not npcBot:HasModifier('modifier_marci_guardian')
	then
		local tableNearbyCreeps  = npcBot:GetNearbyCreeps( 400, true );
		if tableNearbyCreeps ~= nil and #tableNearbyCreeps >= 2 then
			return BOT_ACTION_DESIRE_MODERATE, npcBot;
		end		
	end	
	
	-- ROSHAN: Use when fighting Roshan
	if ( npcBot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
		and not npcBot:HasModifier('modifier_marci_guardian')
	then
		local npcTarget = mutil.SafeGetAttackTarget(npcBot);
		if ( mutil.IsRoshan(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, 325) )
		then
			return BOT_ACTION_DESIRE_MODERATE, npcBot;
		end
	end

	-- TEAMFIGHT/COMBAT: Use on highest damage ally (LIKE WORKING PRIMAL BEAST PATTERN)
	if mutil.IsInTeamFight(npcBot, 1200) or  mutil.IsPushing(npcBot) or mutil.IsDefending(npcBot)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
	    
		if tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 1 then
			local tableNearbyAllyHeroes = npcBot:GetNearbyHeroes( nCastRange + 200, false, BOT_MODE_NONE );
			local highesAD = 0;
			local highesADUnit = nil;
			
			for _,npcAlly in pairs( tableNearbyAllyHeroes )
			do
				local AllyAD = npcAlly:GetAttackDamage();
				if ( mutil.CanCastOnNonMagicImmune(npcAlly) 
					and not npcAlly:HasModifier('modifier_marci_guardian') 
					and AllyAD > highesAD ) 
				then
					highesAD = AllyAD;
					highesADUnit = npcAlly;
				end
			end
			
			if highesADUnit ~= nil then
				return BOT_ACTION_DESIRE_HIGH, highesADUnit;
			end
		end	
	end
	
	-- GOING ON SOMEONE: Use on self when engaging (LIKE WORKING PRIMAL BEAST PATTERN)
	if mutil.IsGoingOnSomeone(npcBot)
		and not npcBot:HasModifier('modifier_marci_guardian')
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, 350) 
		then
			return BOT_ACTION_DESIRE_HIGH, npcBot;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderR()	
	-- Make sure it's castable - SAME PATTERN AS WORKING CODE
	if not mutil.CanBeCast(abilityR) then 
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- GOING ON SOMEONE: Use when engaging (LIKE WORKING PRIMAL BEAST PATTERN)
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local target = npcBot:GetTarget();
		if mutil.IsValidTarget(target) 
			and mutil.CanCastOnMagicImmune(target) 
			and mutil.IsInRange(target, npcBot, 500)  
		then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end
	
	-- TEAMFIGHT: Use in team fights
	if mutil.IsInTeamFight(npcBot, 1200) then
		return BOT_ACTION_DESIRE_HIGH;
	end
	
	return BOT_ACTION_DESIRE_NONE;
end