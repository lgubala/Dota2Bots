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

local castTWDesire = 0;
local castCHDesire = 0;
local castCSDesire = 0;
--local castBFDesire =0;

local abilityTW = nil;
local abilityCH = nil;
local abilityCS = nil;
--local abilityBF = nil;

local npcBot = nil;

local fragmentCastTime = DotaTime();


function AbilityUsageThink()

	if npcBot == nil then npcBot = GetBot(); end
	
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end
	
	if abilityTW == nil then abilityTW = npcBot:GetAbilityByName( "antimage_blink" ); end
	if abilityCH == nil then abilityCH = npcBot:GetAbilityByName( "antimage_mana_void" ); end
	if abilityCS == nil then abilityCS = npcBot:GetAbilityByName( "antimage_counterspell" ); end
	--if abilityBF == nil then abilityBF = npcBot:GetAbilityByName( "antimage_mana_overload" ); end
	-- Consider using each ability
	castTWDesire, castTWLocation = ConsiderTimeWalk();
	castCHDesire, castCHTarget = ConsiderCorrosiveHaze();
	castCSDesire = ConsiderCounterSpell();

	--castBFDesire, castBFTarget, castBFType = ConsiderBlinkFragment();


	-- if ( castBFDesire > 0 ) 
	-- then
	-- 	if(fragmentCastTime + 10) < DotaTime() then
	-- 		fragmentCastTime = DotaTime();
	-- 		if castBFType == "target" then			
	-- 			npcBot:Action_UseAbilityOnEntity( abilityBF, castBFTarget );
	-- 			return;
	-- 		else
	-- 			npcBot:Action_UseAbilityOnLocation( abilityBF, castBFTarget );
	-- 			return;
	-- 		end
	-- 	end
	-- end 

	if ( castTWDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnLocation( abilityTW, castTWLocation );
		return;
	end	
	if ( castCHDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnEntity( abilityCH, castCHTarget );
		return;
	end
	if ( castCSDesire > 0 ) then
		npcBot:Action_UseAbility( abilityCS );
		return;
	end
	
end


function ConsiderTimeWalk()

	-- Make sure it's castable
	if ( abilityTW:IsFullyCastable() == false or npcBot:IsRooted() ) 
	then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end
	
	-- Get some of its values
	local nCastRange = abilityTW:GetSpecialValueInt("AbilityCastRange");
	local nCastPoint = abilityTW:GetCastPoint( );
	local manaCost   = abilityTW:GetManaCost( );

	if mutil.IsStuck(npcBot)
	then
		local loc = mutil.GetEscapeLoc();
		return BOT_ACTION_DESIRE_HIGH, npcBot:GetXUnitsTowardsLocation( loc, nCastRange );
	end
	
	-- if npcBot:GetActiveMode() == BOT_MODE_FARM and mutil.CanSpamSpell(npcBot, manaCost) then
		-- if npcBot.farmLaneLocation ~= nil and GetUnitToLocationDistance(npcBot, npcBot.farmLaneLocation) > 1000 then
			-- if IsLocationPassable(npcBot:GetXUnitsTowardsLocation( npcBot.farmLaneLocation, nCastRange )) then
				-- return BOT_ACTION_DESIRE_HIGH, npcBot:GetXUnitsTowardsLocation( npcBot.farmLaneLocation, nCastRange );
			-- end 
		-- end
	-- end
	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		if mutil.ShouldEscape(npcBot)
		then
			local loc = mutil.GetEscapeLoc();
			local location = npcBot:GetXUnitsTowardsLocation( loc, nCastRange );
			--print("escaping " ..tostring(location));
			--print("loc " .. tostring(loc) .."castR: "..tostring(nCastRange));
			--print("I am " ..tostring(bot:GetUnitName()).."my position is " ..)
			return BOT_ACTION_DESIRE_MODERATE, location;
		end
	end
	
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and not mutil.IsInRange(npcTarget, npcBot, 2*npcBot:GetAttackRange()) and mutil.IsInRange(npcTarget, npcBot, nCastRange+200)  
		then
			local tableNearbyEnemyHeroes = npcTarget:GetNearbyHeroes( 1000, false, BOT_MODE_NONE );
			if tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes < 2 then
				return BOT_ACTION_DESIRE_MODERATE, npcTarget:GetExtrapolatedLocation( 1.5*nCastPoint );
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;
end

function ConsiderCounterSpell()

	-- Make sure it's castable
	if ( abilityCS:IsFullyCastable() == false ) 
	then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end
	
	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		local incProj = npcBot:GetIncomingTrackingProjectiles()
		for _,p in pairs(incProj)
		do
			if GetUnitToLocationDistance(npcBot, p.location) <= 300 and p.is_attack == false then
				return BOT_ACTION_DESIRE_HIGH;
			end
		end
	end
	
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, 600)  
		then
			local incProj = npcBot:GetIncomingTrackingProjectiles()
			for _,p in pairs(incProj)
			do
				if GetUnitToLocationDistance(npcBot, p.location) <= 300 and p.is_attack == false then
					return BOT_ACTION_DESIRE_HIGH;
				end
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;
end

function ConsiderCorrosiveHaze()

	-- Make sure it's castable
	if ( not abilityCH:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	-- Get some of its values
	local nCastRange = abilityCH:GetCastRange();
	local nDamagaPerHealth = abilityCH:GetSpecialValueFloat("mana_void_damage_per_mana");

	-- If we're going after someone
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnTargetAdvanced(npcTarget)
		then
			local EstDamage = nDamagaPerHealth * ( npcTarget:GetMaxMana() - npcTarget:GetMana() )
			local TPerMana = npcTarget:GetMana()/npcTarget:GetMaxMana();
			if mutil.CanKillTarget(npcTarget, EstDamage, DAMAGE_TYPE_MAGICAL) or TPerMana < 0.01
			then
				return BOT_ACTION_DESIRE_HIGH, npcTarget;
			end
		end
	end
	

	-- If we're in a teamfight, use it on the scariest enemy
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local npcToKill = nil;
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			local EstDamage = nDamagaPerHealth * ( npcEnemy:GetMaxMana() - npcEnemy:GetMana() )
			local TPerMana = npcEnemy:GetMana()/npcEnemy:GetMaxMana();
			if mutil.IsValidTarget(npcEnemy) and mutil.CanCastOnTargetAdvanced(npcEnemy) and mutil.IsInRange(npcEnemy, npcBot, nCastRange+200) and
			   ( mutil.CanKillTarget(npcEnemy, EstDamage, DAMAGE_TYPE_MAGICAL) or TPerMana < 0.01 ) 
			then
				npcToKill = npcEnemy;
			end
		end

		if ( npcToKill ~= nil  )
		then
			return BOT_ACTION_DESIRE_HIGH, npcToKill;
		end
	end
	
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
	for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
	do
		local EstDamage = nDamagaPerHealth * ( npcEnemy:GetMaxMana() - npcEnemy:GetMana() )
		local TPerMana = npcEnemy:GetMana()/npcEnemy:GetMaxMana();
		if mutil.IsValidTarget(npcEnemy) and mutil.CanCastOnTargetAdvanced(npcEnemy) and mutil.IsInRange(npcEnemy, npcBot, nCastRange+200) and
		   ( mutil.CanKillTarget(npcEnemy, EstDamage, DAMAGE_TYPE_MAGICAL) or TPerMana < 0.01 or mutil.SafeIsChanneling(npcEnemy) ) 
		then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy;
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0;
end

function ConsiderBlinkFragment()


	-- Make sure it's castable
	if ( not abilityBF:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE, 0, "";
	end

	-- Get some of its values
	local nCastRange  = abilityTW:GetCastRange();
	local nCastPoint  = abilityBF:GetCastPoint( );
	local nManaCost   = abilityBF:GetManaCost( );
	--local nDamage     = abilityBF:GetAbilityDamage();
	
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
	
	--if we can kill any enemies
	for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
	do
		if mutil.CanCastOnNonMagicImmune(npcEnemy) and ( mutil.CanKillTarget(npcEnemy, 50, DAMAGE_TYPE_MAGICAL) or mutil.SafeIsChanneling(npcEnemy) ) then
			return BOT_ACTION_DESIRE_ABSOLUTE , npcEnemy, 'target';
		end
	end
	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( mutil.CanCastOnNonMagicImmune(npcEnemy)) 
			then
				return BOT_ACTION_DESIRE_ABSOLUTE , npcEnemy, 'target';
			end
		end
	end
	
	if ( npcBot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
	then
		local npcTarget = mutil.SafeGetAttackTarget(npcBot);
		if ( mutil.IsRoshan(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) 
            and not mutil.IsDisabled(true, npcTarget) )
		then
			return BOT_ACTION_DESIRE_ABSOLUTE , npcTarget, 'target';
		end
	end

	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local locationAoE = npcBot:FindAoELocation( true, true, npcBot:GetLocation(), nCastRange, nCastRange, nCastPoint, 0 );
		if ( locationAoE.count >= 2 ) 
		then
			return BOT_ACTION_DESIRE_ABSOLUTE , locationAoE.targetloc, 'location';
		end
	end
	
	-- If we're going after someone
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)
		then
			return BOT_ACTION_DESIRE_ABSOLUTE , npcTarget, 'target';
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0, "";

end
