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

local castHMDesire = 0;
local castFCDesire = 0;
local castGGDesire = 0;

local abilitySS = nil;
local abilityHM = nil;
local abilityGG = nil;
local abilityFC = nil;

local npcBot = nil;

function AbilityUsageThink()

	if npcBot == nil then npcBot = GetBot(); end
	
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end

	if abilitySS == nil then abilitySS = npcBot:GetAbilityByName( "medusa_split_shot" ) end
	if abilityHM == nil then abilityHM = npcBot:GetAbilityByName( "medusa_mystic_snake" ) end
	if abilityGG == nil then abilityGG = npcBot:GetAbilityByName( "medusa_gorgon_grasp" ) end
	if abilityFC == nil then abilityFC = npcBot:GetAbilityByName( "medusa_stone_gaze" ) end

	-- Consider using each ability
	castHMDesire, castHMTarget = ConsiderHomingMissile();
	castFCDesire  = ConsiderFlakCannon();
	castGGDesire, castGGTarget = ConsiderGG();

	
	if abilitySS:IsTrained() and abilitySS:GetToggleState() == false then
		npcBot:Action_UseAbility ( abilitySS );
		return;
	end
	
	if castGGDesire > 0 then
		npcBot:Action_UseAbilityOnLocation(abilityGG, castGGTarget);		
		return
	end
	
	if ( castFCDesire > 0 ) 
	then
		npcBot:Action_UseAbility ( abilityFC );
		return;
	end
	
	if ( castHMDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnEntity( abilityHM, castHMTarget );
		return;
	end

end

function CanCastHomingMissileOnTarget( npcTarget )
	return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable();
end

function ConsiderHomingMissile()

	-- Make sure it's castable
	if ( not abilityHM:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	-- Get some of its values
	local nCastRange = abilityHM:GetCastRange();
	local nDamage = 2*abilityHM:GetSpecialValueInt('snake_damage');
	--------------------------------------
	-- Mode based usage
	--------------------------------------	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy) ) 
			then
				return BOT_ACTION_DESIRE_MODERATE, npcEnemy;
			end
		end
	end
	
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		
		local npcMostDangerousEnemy = nil;
		local nMostDangerousDamage = 100000;

		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( mutil.CanCastOnNonMagicImmune(npcEnemy ) )
			then
				local nDamage = GetUnitToUnitDistance(npcEnemy, npcBot);
				if ( nDamage < nMostDangerousDamage )
				then
					nMostDangerousDamage = nDamage;
					npcMostDangerousEnemy = npcEnemy;
				end
			end
		end

		if ( npcMostDangerousEnemy ~= nil )
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy;
		end
		
	end
	
	-- If we're going after someone
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange + 200)
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;

end



function ConsiderGG()

	-- Make sure it's castable
	if ( not abilityGG:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	-- Get some of its values
	local nRadius    = abilityGG:GetSpecialValueInt('radius');
	local nCastRange = abilityGG:GetCastRange();
	local nCastPoint = abilityGG:GetCastPoint( );
	local nManaCost  = abilityGG:GetManaCost( );
	local nDamage    = 100;
	
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange + nRadius/2, true, BOT_MODE_NONE );
	
	--if we can kill any enemies
	for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
	do
		if mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.CanKillTarget(npcEnemy, nDamage, DAMAGE_TYPE_MAGICAL) then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetExtrapolatedLocation(nCastPoint);
		end
	end
	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy) ) 
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
			end
		end
	end
	
	if ( npcBot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
	then
		local npcTarget = mutil.SafeGetAttackTarget(npcBot);
		if ( mutil.IsRoshan(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)  )
		then
			return BOT_ACTION_DESIRE_LOW, npcTarget:GetExtrapolatedLocation(nCastPoint);
		end
	end
	
	if ( mutil.IsPushing(npcBot) or mutil.IsDefending(npcBot) ) and mutil.AllowedToSpam(npcBot, nManaCost)
	then
		local lanecreeps = npcBot:GetNearbyLaneCreeps(nCastRange+200, true);
		local locationAoE = npcBot:FindAoELocation( true, false, npcBot:GetLocation(), nCastRange, nRadius/2, nCastPoint, 0 );
		if ( locationAoE.count >= 4 and #lanecreeps >= 4  ) 
		then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
		end
	end
	
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local locationAoE = npcBot:FindAoELocation( true, true, npcBot:GetLocation(), nCastRange, nRadius/2, nCastPoint, 0 );
		if ( locationAoE.count >= 2 ) 
		then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
		end
	end

	-- If we're going after someone
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange + 200) 
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget:GetExtrapolatedLocation(nCastPoint);
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;

end


function ConsiderFlakCannon()

	-- Make sure it's castable
	if ( not abilityFC:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE;
	end

	-- Get some of its values
	local nCastRange = abilityFC:GetSpecialValueInt("radius");
	local nAttackRange = npcBot:GetAttackRange();
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	if mutil.IsRetreating(npcBot)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) ) 
			then
				return BOT_ACTION_DESIRE_MODERATE;
			end
		end
	end
	
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local locationAoE = npcBot:FindAoELocation( true, true, npcBot:GetLocation(), nAttackRange, 400, 0, 0 );
		if ( locationAoE.count >= 2 ) 
		then
			local nInvUnit = mutil.FindNumInvUnitInLoc(true, npcBot, nAttackRange+200, 400, locationAoE.targetloc);
			if nInvUnit >= locationAoE.count then
				return BOT_ACTION_DESIRE_MODERATE;
			end
		end
		
	end
	
	return BOT_ACTION_DESIRE_NONE;

end
