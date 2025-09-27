local bot = GetBot();

if bot:IsInvulnerable() or bot:IsHero() == false or  bot:IsIllusion()  then return; end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutils = require(GetScriptDirectory() ..  "/MyUtility")

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

local abilities = mutils.InitiateAbilities(bot, {0,1,2,5,6});
local abilityAcornShot = nil;
local abilityBushwhack = nil;
local abilityScurry = nil;
local abilityDecoy = nil;
local abilityBumerang = nil;
local abilitySharpshooter = nil;
local abilitySharpshooterRelease = nil;

local castAcornShotDesire = 0;
local castBushwhackDesire = 0;
local castScurryDesire = 0;
local castDecoyDesire = 0;
local castBumerangDesire = 0;
local castSharpshooterDesire = 0;
local castSharpshooterReleaseDesire = 0;

local lastQTargetType = nil;
local sharpshooterCastTime = -10000;
local shapshooterCasted = false;

local function CanCastOnCreep(unit)
	return unit:CanBeSeen() and unit:IsMagicImmune() == false and unit:IsInvulnerable() == false; 
end

local function GetNumEnemyCreepsAroundTarget(target, bEnemy, nRadius)
	local locationAoE = bot:FindAoELocation( true, false, target:GetLocation(), 0, nRadius, 0, 0 );
	if ( locationAoE.count >= 3 ) then
		return 3;
	end
	return 0;
end

local function ConsiderAcornShot()
	if  mutils.CanBeCast(abilityAcornShot) == false then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local nCastPoint = abilityAcornShot:GetCastPoint();
	local manaCost   = abilityAcornShot:GetManaCost();
	local nRadius    = abilityAcornShot:GetSpecialValueInt('bounce_range');
	local nBounce    = abilityAcornShot:GetSpecialValueInt('bounce_count');
	local nCastRange    = mutils.GetProperCastRange(false, bot, abilityAcornShot:GetCastRange());
	local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( nCastRange + 200, true, BOT_MODE_NONE );

	if bot:GetActiveMode() == BOT_MODE_LANING and bot:GetMana() / bot:GetMaxMana() >= 0.7 then
   		local tableNearbyEnemyCreeps = bot:GetNearbyLaneCreeps(nCastRange, true);
    	for _, npcECreep in pairs(tableNearbyEnemyCreeps) do
        	if mutils.CanCastOnNonMagicImmune(npcECreep) then
        		print("whaaat");
            	return BOT_ACTION_DESIRE_HIGH, npcECreep:GetLocation(), 'point';
        	end
    	end
	end


	if ( mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) )
	then
		local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		for i=1,#enemies do
			if mutils.IsValidTarget(enemies[i]) 
				and mutils.CanCastOnNonMagicImmune(enemies[i]) 
				and mutils.IsDisabled(true, enemies[i]) == false
			then
				print("whaaat");
				return BOT_ACTION_DESIRE_HIGH, enemies[i]:GetLocation(), 'point';
			end
		end
	end

	if ( mutils.IsPushing(bot) or mutils.IsDefending(bot) ) and  mutils.CanSpamSpell(bot, manaCost) 
	then
		local creeps = bot:GetNearbyLaneCreeps(nCastRange, true);
		if #creeps >= nBounce and mutils.CanCastOnNonMagicImmune(creeps[1]) then
			print("whaaat");
			return BOT_ACTION_DESIRE_HIGH, creeps[1]:GetLocation(), 'point';
		end
	end

	if mutils.IsGoingOnSomeone(bot) 
	then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) 
			and mutils.CanCastOnNonMagicImmune(target) 
			and mutils.IsInRange(bot, target, nCastRange) 
			and mutils.IsDisabled(true, target) == false
		then
			local enemies = target:GetNearbyHeroes(0.75*nRadius, false, BOT_MODE_NONE);
			if #enemies > 1 then
				print("whaaat");
				return BOT_ACTION_DESIRE_HIGH, target:GetLocation(), 'point';
			end
			local creeps = target:GetNearbyLaneCreeps(0.75*nRadius, false);
			if #creeps > 0 then
				print("whaaat");
				return BOT_ACTION_DESIRE_HIGH, target:GetLocation(), 'point';	
			end
		end
	end

	if mutils.IsInTeamFight(bot, 1200)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcEnemy:IsHero() and mutils.CanCastOnNonMagicImmune(npcEnemy) and not mutils.IsDisabled(true, npcEnemy) ) 
			then
				print("whaaat");
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation(), 'point';
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE;
end	

local function ConsiderBushwhack()
	if  mutils.CanBeCast(abilityBushwhack) == false then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastPoint = abilityBushwhack:GetCastPoint();
	local manaCost   = abilityBushwhack:GetManaCost();
	local nRadius    = abilityBushwhack:GetSpecialValueInt('trap_radius');
	local nCastRange    = mutils.GetProperCastRange(false, bot, abilityBushwhack:GetCastRange());
	local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( nCastRange + 200, true, BOT_MODE_NONE );


	if bot:GetLevel() >= 25 then
        nRadius = nRadius + 135;
    end

    if bot:GetActiveMode() == BOT_MODE_LANING and bot:GetMana() / bot:GetMaxMana() >= 0.7 then
   		local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)
		for i=1, #enemies do
			if mutils.IsValidTarget(enemies[i]) 
				and mutils.CanCastOnNonMagicImmune(enemies[i]) 
				and mutils.IsDisabled(true, enemies[i]) == false
			then	
				local trees = enemies[i]:GetNearbyTrees(nRadius-50);
				if #trees > 0 then
					print("BUSH");
					return BOT_ACTION_DESIRE_HIGH, enemies[i]:GetLocation();
				end
			end	
		end
	end

	if ( mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) )
	then
		local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)
		for i=1, #enemies do
			if mutils.IsValidTarget(enemies[i]) 
				and mutils.CanCastOnNonMagicImmune(enemies[i]) 
				and mutils.IsDisabled(true, enemies[i]) == false
			then	
				local trees = enemies[i]:GetNearbyTrees(nRadius-50);
				if #trees > 0 then
					print("BUSH");
					return BOT_ACTION_DESIRE_HIGH, enemies[i]:GetLocation();
				end
			end	
		end
	end
	
	if mutils.IsGoingOnSomeone(bot) 
	then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) 
			and mutils.CanCastOnNonMagicImmune(target) 
			and mutils.IsInRange(target, bot, nCastRange+nRadius)
			and mutils.IsDisabled(true, target) == false
		then
			local trees = target:GetNearbyTrees(nRadius-50);
			if #trees > 0 then
				print("BUSH");
				return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
			end
		end
	end
	
	local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
	for i=1, #enemies do
		if mutils.IsValidTarget(enemies[i]) == true 
			and mutils.CanCastOnNonMagicImmune(enemies[i]) == true 
			and ( mutils.SafeIsChanneling(enemies[i])
			or enemies[i]:HasModifier('modifier_teleporting') )
		then
			local trees = enemies[i]:GetNearbyTrees(nRadius-50);
			if #trees > 0 then
				print("BUSH");
				return BOT_ACTION_DESIRE_HIGH, enemies[i]:GetLocation();
			end
		end
	end

	if mutils.IsInTeamFight(bot, 1200)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcEnemy:IsHero() and mutils.CanCastOnNonMagicImmune(npcEnemy) and not mutils.IsDisabled(true, npcEnemy) ) 
			then
				print("BUSH");
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE;
end	

local function ConsiderScurry()
	if  mutils.CanBeCast(abilityScurry) == false or bot:HasModifier('modifier_hoodwink_scurry_active') == true then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = bot:GetAttackRange();
	
	if ( mutils.IsRetreating(bot) and ( bot:WasRecentlyDamagedByAnyHero(3.0) or bot:WasRecentlyDamagedByTower(3.0) ) )
	then
		local enemies = bot:GetNearbyHeroes(1300, true, BOT_MODE_NONE);
		if #enemies > 0 then
			print("SCURRY");
			return BOT_ACTION_DESIRE_HIGH;
		end
	end
	
	if mutils.IsGoingOnSomeone(bot) 
	then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) 
			and mutils.CanCastOnMagicImmune(target) 
		then
			local enemies = target:GetNearbyHeroes(800, false, BOT_MODE_NONE);
			local allies = target:GetNearbyHeroes(800, true, BOT_MODE_NONE);
			for i=1, #enemies do
				if mutils.IsValidTarget(enemies[i])
					and mutils.CanCastOnMagicImmune(enemies[i])
					and mutils.IsInRange(bot, enemies[i], 600)
					and ( mutils.SafeGetAttackTarget(enemies[i]) == bot or enemies[i]:GetTarget() == bot )
					and enemies[i]:IsFacingLocation(bot:GetLocation(), 10) 
				then
					print("SCURRY");
					return BOT_ACTION_DESIRE_HIGH;
				end	
			end
			
			if  mutils.IsInRange(target, bot, 1.25*nCastRange) == false
				and mutils.IsInRange(target, bot, 2*nCastRange) == true
				and enemies ~= nil and allies ~= nil and  #enemies < #allies 
			then
				print("SCURRY");
				return BOT_ACTION_DESIRE_HIGH;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end	

local function ConsiderSharpshooter()
	if  mutils.CanBeCast(abilitySharpshooter) == false then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local nCastPoint = abilitySharpshooter:GetCastPoint();
	local manaCost   = abilitySharpshooter:GetManaCost();
	local nRadius    = abilitySharpshooter:GetSpecialValueInt('arrow_width');
	local speed    = abilitySharpshooter:GetSpecialValueInt('arrow_speed');
	local nCastRange    = 1600;
	local nCastRange2    = abilitySharpshooter:GetSpecialValueInt('arrow_range');
	local nAttackRange    = bot:GetAttackRange();
	
	if ( mutils.IsDefending(bot) ) and  mutils.CanSpamSpell(bot, manaCost) 
	then
		local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		for i=1, #enemies do
			if mutils.IsValidTarget(enemies[i]) 
				and mutils.CanCastOnNonMagicImmune(enemies[i]) == true
				and mutils.IsInRange(bot, enemies[i], 0.5*nCastRange) == false 
				and mutils.IsInRange(bot, enemies[i], nCastRange) == true 
			then
				print("SHARPA");
				return BOT_ACTION_DESIRE_MODERATE, enemies[i]:GetLocation();
			end
		end
	end
	
	if mutils.IsInTeamFight(bot, 1300)
	then
		local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0 );
		if ( locationAoE.count >= 2 and GetUnitToLocationDistance(bot,  locationAoE.targetloc) > 0.5*nAttackRange ) then
			print("SHARPA");
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
		end
	end
	
	if mutils.IsGoingOnSomeone(bot) 
	then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) 
			and mutils.CanCastOnNonMagicImmune(target) 
			and mutils.IsInRange(bot, target, nAttackRange) == false
			and mutils.IsInRange(bot, target, nCastRange2) == true
		then
			local distance = GetUnitToUnitDistance(target, bot)
			local moveCon = target:GetMovementDirectionStability();
			local pLoc = target:GetExtrapolatedLocation( nCastPoint + ( distance / speed ) );
			if moveCon < 0.95 then
				pLoc = target:GetLocation();
			end
			print("SHARPA");
			return BOT_ACTION_DESIRE_MODERATE, pLoc;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end	


local function ConsiderDecoy()
	if not abilityDecoy:IsFullyCastable() or abilityDecoy:IsHidden() then
		return BOT_ACTION_DESIRE_NONE, 0;
	end
			
	if ( mutils.IsRetreating(bot) and ( bot:WasRecentlyDamagedByAnyHero(3.0) or bot:WasRecentlyDamagedByTower(3.0) ) )
	then
		print("DECOU");
		return BOT_ACTION_DESIRE_HIGH;
	end
	
	if mutils.IsInTeamFight(bot, 1200)
	then
		print("DECOU");
		return BOT_ACTION_DESIRE_MODERATE;
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end	

local function ConsiderBumerang()
	if not abilityBumerang:IsFullyCastable() or abilityBumerang:IsHidden() then
		return BOT_ACTION_DESIRE_NONE, 0;
	end
	
	-- Get some of its values
	local nCastRange = abilityBumerang:GetCastRange();
	local nCastPoint = abilityBumerang:GetCastPoint( );
	local nManaCost  = abilityBumerang:GetManaCost( );
	local nDamage    = 280;
	
	local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( nCastRange + 200, true, BOT_MODE_NONE );
	
	--if we can kill any enemies
	for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
	do
		if mutils.CanCastOnNonMagicImmune(npcEnemy) and mutils.CanKillTarget(npcEnemy, nDamage, DAMAGE_TYPE_MAGICAL) then
			print("BUMBUBN");
			return BOT_ACTION_DESIRE_HIGH, npcEnemy;
		end
	end
	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutils.IsRetreating(bot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( bot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutils.CanCastOnNonMagicImmune(npcEnemy) and not mutils.IsDisabled(true, npcEnemy) ) 
			then
				print("BUMBUBN");
				return BOT_ACTION_DESIRE_HIGH, npcEnemy;
			end
		end
	end
	
	if ( bot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
	then
		local npcTarget = mutils.SafeGetAttackTarget(bot);
		if ( mutils.IsRoshan(npcTarget) and mutils.CanCastOnMagicImmune(npcTarget) and mutils.IsInRange(npcTarget, bot, nCastRange)  )
		then
			print("BUMBUBN");
			return BOT_ACTION_DESIRE_LOW, npcTarget;
		end
	end
	

	
	if mutils.IsInTeamFight(bot, 1200)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcEnemy:IsHero() and mutils.CanCastOnNonMagicImmune(npcEnemy) and not mutils.IsDisabled(true, npcEnemy) ) 
			then
				print("BUMBUBN");
				return BOT_ACTION_DESIRE_HIGH, npcEnemy;
			end
		end
	end

	-- If we're going after someone
	if mutils.IsGoingOnSomeone(bot)
	then
		local npcTarget = bot:GetTarget();
		if mutils.IsValidTarget(npcTarget) and mutils.CanCastOnNonMagicImmune(npcTarget) and mutils.IsInRange(npcTarget, bot, nCastRange + 200) 
		   and not mutils.IsDisabled(true, npcTarget)
		then
			print("BUMBUBN");
			return BOT_ACTION_DESIRE_HIGH, npcTarget;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;
end	

function AbilityUsageThink()
	
	
	if mutils.CanNotUseAbility(bot) then return end
	
	if abilityAcornShot == nil then abilityAcornShot = bot:GetAbilityByName("hoodwink_acorn_shot") end
	if abilityBushwhack == nil then abilityBushwhack = bot:GetAbilityByName("hoodwink_bushwhack") end
	if abilityScurry == nil then abilityScurry = bot:GetAbilityByName("hoodwink_scurry") end
	if abilitySharpshooter == nil then abilitySharpshooter = bot:GetAbilityByName("hoodwink_sharpshooter") end
	if abilitySharpshooterRelease == nil then abilitySharpshooterRelease = bot:GetAbilityByName("hoodwink_sharpshooter_release") end
	if abilityDecoy == nil then abilityDecoy = bot:GetAbilityByName("hoodwink_decoy") end	
	if abilityBumerang == nil then abilityBumerang = bot:GetAbilityByName("hoodwink_hunters_boomerang") end

	
	castAcornShotDesire, qTarget, tType = ConsiderAcornShot();
	castBushwhackDesire, wTarget = ConsiderBushwhack();
	castScurryDesire          = ConsiderScurry();
	castSharpshooterDesire, rTarget = ConsiderSharpshooter();
	castDecoyDesire = ConsiderDecoy();
	castBumerangDesire, bTarget = ConsiderBumerang();

	local sharpshooterCooldown = 3 
    if bot:GetLevel() >= 20 then
        sharpshooterCooldown = sharpshooterCooldown * 0.75 -- 25% faster charging time
    end

    if castBumerangDesire > 0 then
    	bot:Action_UseAbilityOnEntity(abilityBumerang, bTarget);
    end

    if castDecoyDesire > 0 then
    	bot:Action_UseAbility(abilityDecoy);
    end

	if castAcornShotDesire > 0 then
		if tType == 'unit' then
			bot:Action_UseAbilityOnEntity(abilityAcornShot, qTarget);
		else 
			bot:Action_UseAbilityOnLocation(abilityAcornShot, qTarget);
		end	
		return
	end
	
	if castBushwhackDesire > 0 then
		bot:Action_UseAbilityOnLocation(abilityBushwhack, wTarget);		
		return
	end
	
	if castScurryDesire > 0 then
		bot:Action_UseAbility(abilityScurry);		
		return
	end
	
	if castSharpshooterDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilitySharpshooter, rTarget);
        sharpshooterCastTime = DotaTime();
        shapshooterCasted = true;
        return
    end

    -- Check if abilitySharpshooter is learned before using abilitySharpshooterRelease
    if abilitySharpshooter and abilitySharpshooter:GetLevel() > 0 and DotaTime() - sharpshooterCastTime >= sharpshooterCooldown and shapshooterCasted then
        print("UNSHOOT");
        bot:Action_UseAbility(abilitySharpshooterRelease);
        shapshooterCasted = false;
        return
    end
	
end


