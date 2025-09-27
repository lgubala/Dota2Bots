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

local Combo1Time = 0; 
local Combo2Time = 0; 
local Combo3Time = 0; 

local C1Delay = 2.2; 
local C2Delay = 1.8; 
local C3Delay = 3.2; 
local Combo1 = 0;
local Combo2 = 0;
local Combo3 = 0;

local castTODesire = 0;
local castXSDesire = 0;
local castGSDesire = 0;
local castTSDesire = 0;

local abilityTO = "";
local abilityXS = "";
local abilityRT = "";
local abilityGS = "";
local abilityTS = "";
local npcBot = nil;

function AbilityUsageThink()

	if npcBot == nil then npcBot = GetBot(); end
	
	if not npcBot:IsAlive() then
		Combo1Time = 0;
		Combo2Time = 0;
		Combo3Time = 0;
	end
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end

	if abilityTO == "" then abilityTO = npcBot:GetAbilityByName( "kunkka_torrent" ); end
	if abilityXS == "" then abilityXS = npcBot:GetAbilityByName( "kunkka_x_marks_the_spot" ); end
	if abilityRT == "" then abilityRT = npcBot:GetAbilityByName( "kunkka_return" ); end
	if abilityGS == "" then abilityGS = npcBot:GetAbilityByName( "kunkka_ghostship" ); end
	--if abilityTS == "" then abilityTS = npcBot:GetAbilityByName( "kunkka_torrent_storm" ); end
	

	
	Combo1, Combo1Target, Combo1Loc = ConsiderCombo1();
	Combo2, Combo2Target, Combo2Loc = ConsiderCombo2();
	Combo3, Combo3Target, Combo3Loc = ConsiderCombo3();
	castTODesire, castTOLoc = ConsiderTorrent()
	castXSDesire, castXSTarget = ConsiderXMark()
	castGSDesire, castGSLoc = ConsiderGhostShip()
	--castTSDesire = ConsiderTorrentStorm()
	
	
	
	-- Handle X Marks return
	if abilityRT ~= nil and not abilityRT:IsHidden() and 
		( 
		  ( Combo3Time ~= 0 and DotaTime() >= Combo3Time + C3Delay ) or 
		  ( Combo1Time ~= 0 and DotaTime() >= Combo1Time + C1Delay ) or
		  ( Combo2Time ~= 0 and DotaTime() >= Combo2Time + C2Delay ) 
		)
	then
		--print("[KUNKKA] Using X Marks Return");
		npcBot:Action_UseAbility(abilityRT);
		Combo1Time = 0;
		Combo2Time = 0;
		Combo3Time = 0;
		return
	end
	
	-- Combo priority
	if Combo1 > 0 then
		--print("[KUNKKA] Executing Combo1 (X + Ghost Ship + Torrent)");
		Combo1Time = DotaTime();
		npcBot:Action_ClearActions(false);
		npcBot:ActionQueue_UseAbilityOnEntity(abilityXS, Combo1Target);
		npcBot:ActionQueue_UseAbilityOnLocation(abilityGS,  Combo1Loc);
		npcBot:ActionQueue_UseAbilityOnLocation(abilityTO, Combo1Loc);
		return;
	end
	
	if Combo2 > 0 then
		--print("[KUNKKA] Executing Combo2 (X + Torrent)");
		Combo2Time = DotaTime();
		npcBot:Action_ClearActions(false);
		npcBot:ActionQueue_UseAbilityOnEntity(abilityXS, Combo2Target);
		npcBot:ActionQueue_UseAbilityOnLocation(abilityTO, Combo2Loc);
		return;
	end
	
	if Combo3 > 0 then
		--print("[KUNKKA] Executing Combo3 (X + Ghost Ship)");
		Combo3Time = DotaTime();
		npcBot:Action_ClearActions(false);
		npcBot:ActionQueue_UseAbilityOnEntity(abilityXS, Combo3Target);
		npcBot:ActionQueue_UseAbilityOnLocation(abilityGS,  Combo3Loc);
		return;
	end
	
	-- Individual ability usage (more aggressive)
	if castGSDesire > 0 then
		--print("[KUNKKA] Using Ghost Ship");
		npcBot:Action_UseAbilityOnLocation(abilityGS,  castGSLoc);
		return;
	end
	
	-- if castTSDesire > 0 then
	-- 	print("[KUNKKA] Using Torrent Storm");
	-- 	npcBot:Action_UseAbility(abilityTS);
	-- 	return;
	-- end
	
	if castTODesire > 0 then 
		--print("[KUNKKA] Using Torrent");
		npcBot:Action_UseAbilityOnLocation(abilityTO,  castTOLoc);
		return;
	end
	
	if castXSDesire > 0 then
		--print("[KUNKKA] Using X Marks (solo)");
		Combo1Time = DotaTime() + C2Delay;
		npcBot:Action_UseAbilityOnEntity(abilityXS,  castXSTarget);
		return;
	end
	
end

function CanCastXMarkOnTarget( npcTarget )
	return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable();
end

function GetTowardsFountainLocation( unitLoc, distance )
	local destination = {};
	if ( GetTeam() == TEAM_RADIANT ) then
		destination[1] = unitLoc[1] - distance / math.sqrt(2);
		destination[2] = unitLoc[2] - distance / math.sqrt(2);
	end

	if ( GetTeam() == TEAM_DIRE ) then
		destination[1] = unitLoc[1] + distance / math.sqrt(2);
		destination[2] = unitLoc[2] + distance / math.sqrt(2);
	end
	return Vector(destination[1], destination[2]);
end

function ConsiderCombo1()
	
	if abilityTO == nil or abilityXS == nil or abilityGS == nil then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	if not abilityTO:IsFullyCastable() or not abilityXS:IsFullyCastable() or not abilityGS:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local CurrMana = npcBot:GetMana();
	local ComboMana = abilityTO:GetManaCost() + abilityXS:GetManaCost() + abilityGS:GetManaCost();
	
	if ComboMana > CurrMana then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	
	local nCastRange = abilityXS:GetCastRange();
	
	-- TEAMFIGHT: Use combo in teamfights (more liberal)
	if mutil.IsInTeamFight(npcBot, 1200) then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #enemies >= 1 then -- Reduced from higher requirement
			--print("[KUNKKA] TEAMFIGHT Combo1 opportunity");
			return BOT_ACTION_DESIRE_HIGH, enemies[1], enemies[1]:GetXUnitsInFront( 75 );
		end
	end
	
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if ( mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and 
			GetUnitToUnitDistance(npcTarget, npcBot) > nCastRange/3 and GetUnitToUnitDistance(npcTarget, npcBot) < nCastRange ) -- Made less restrictive
		then
			--print("[KUNKKA] OFFENSIVE Combo1 on " .. npcTarget:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, npcTarget, npcTarget:GetXUnitsInFront( 75 )
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil
end

function ConsiderCombo2()
	if abilityTO == nil or abilityXS == nil then
		return BOT_ACTION_DESIRE_NONE, nil, {};
	end
	
	if not abilityTO:IsFullyCastable() or not abilityXS:IsFullyCastable() or abilityGS:IsFullyCastable() -- Note: We want GS NOT castable for combo2
	then
		return BOT_ACTION_DESIRE_NONE, nil, {};
	end
	
	local CurrMana = npcBot:GetMana();
	local ComboMana = abilityTO:GetManaCost() + abilityXS:GetManaCost() 
	
	if ComboMana > CurrMana then
		return BOT_ACTION_DESIRE_NONE, nil, {};
	end
	
	local nCastRange = abilityXS:GetCastRange();
	
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if ( mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and GetUnitToUnitDistance(npcTarget, npcBot) < nCastRange ) 
		then
			--print("[KUNKKA] OFFENSIVE Combo2 on " .. npcTarget:GetUnitName());
			return BOT_ACTION_DESIRE_MODERATE, npcTarget, npcTarget:GetXUnitsInFront( 75 ) -- Reduced desire to allow other abilities
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil, {};
end

function ConsiderCombo3()
	
	if abilityGS == nil or abilityXS == nil then
		return BOT_ACTION_DESIRE_NONE, nil, {};
	end
	
	if not abilityGS:IsFullyCastable() or not abilityXS:IsFullyCastable() or abilityTO:IsFullyCastable() -- Note: We want TO NOT castable for combo3
	then
		return BOT_ACTION_DESIRE_NONE, nil, {};
	end
	
	local CurrMana = npcBot:GetMana();
	local ComboMana = abilityGS:GetManaCost() + abilityXS:GetManaCost() 
	
	if ComboMana > CurrMana then
		return BOT_ACTION_DESIRE_NONE, nil, {};
	end
	
	local nCastRange = abilityXS:GetCastRange();
	
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if ( mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget)  and 
			GetUnitToUnitDistance(npcTarget, npcBot) > nCastRange/3 and GetUnitToUnitDistance(npcTarget, npcBot) < nCastRange ) -- Made less restrictive
		then
			--print("[KUNKKA] OFFENSIVE Combo3 on " .. npcTarget:GetUnitName());
			return BOT_ACTION_DESIRE_MODERATE, npcTarget, npcTarget:GetLocation(); -- Reduced desire
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil, {};
end

function ConsiderTorrent()
	
	if abilityTO == nil then
		return BOT_ACTION_DESIRE_NONE, {};
	end
	
	if not abilityTO:IsFullyCastable() or Combo1 > 0 or Combo2 > 0 or Combo3 > 0
	then
		return BOT_ACTION_DESIRE_NONE, {};
	end
	
	local nCastRange = abilityTO:GetCastRange();
	local nRadius = abilityTO:GetSpecialValueInt("radius");
	local nCastPoint = abilityTO:GetCastPoint();
	local nDelay = abilityTO:GetSpecialValueFloat("delay");
	local nManaCost = abilityTO:GetManaCost();
	local nDamage = abilityTO:GetAbilityDamage();
	
	--print("[KUNKKA] Torrent check - Range: " .. nCastRange .. " Radius: " .. nRadius .. " Damage: " .. nDamage);
	
	-- HARASSMENT: Use during laning
	if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, nManaCost)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #tableNearbyEnemyHeroes >= 1 then
			--print("[KUNKKA] HARASSMENT Torrent on " .. tableNearbyEnemyHeroes[1]:GetUnitName());
			return BOT_ACTION_DESIRE_MODERATE, tableNearbyEnemyHeroes[1]:GetExtrapolatedLocation(nDelay + nCastPoint);
		end
	end

	-- FARMING: Use for farming creeps
	if (npcBot:GetActiveMode() == BOT_MODE_LANING or mutil.IsPushing(npcBot) or mutil.IsDefending(npcBot)) 
	   and mutil.AllowedToSpam(npcBot, nManaCost)
	then
		local tableNearbyCreeps = npcBot:GetNearbyLaneCreeps(nCastRange, true);
		if #tableNearbyCreeps >= 3 then -- Reduced from higher number
			--print("[KUNKKA] FARMING Torrent - " .. #tableNearbyCreeps .. " creeps");
			return BOT_ACTION_DESIRE_LOW, tableNearbyCreeps[1]:GetLocation();
		end
	end

	-- TEAMFIGHT: Use in teamfights
	if mutil.IsInTeamFight(npcBot, 1200) 
	then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if ( #enemies >= 1 ) 
		then
			--print("[KUNKKA] TEAMFIGHT Torrent on " .. enemies[1]:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, enemies[1]:GetExtrapolatedLocation(nDelay + nCastPoint);
		end
	end
	
	-- ROSHAN
	if ( npcBot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
	then
		local npcTarget = mutil.SafeGetAttackTarget(npcBot);
		if ( mutil.IsRoshan(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)  )
		then
			--print("[KUNKKA] ROSHAN Torrent");
			return BOT_ACTION_DESIRE_LOW, npcTarget:GetLocation();
		end
	end
	
	-- INTERRUPT: Interrupt channeling
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
	for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
	do
		if ( mutil.SafeIsChanneling(npcEnemy) ) 
		then
			--print("[KUNKKA] INTERRUPT Torrent on " .. npcEnemy:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
		end
	end
	
	-- RETREAT: If we're seriously retreating
	if mutil.IsRetreating(npcBot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if (npcBot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) ) 
			then
				--print("[KUNKKA] RETREAT Torrent on " .. npcEnemy:GetUnitName());
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetExtrapolatedLocation(nDelay + nCastPoint);
			end
		end
	end
	
	-- GOING ON SOMEONE
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if ( mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and GetUnitToUnitDistance(npcTarget, npcBot) < nCastRange ) 
		then
			--print("[KUNKKA] OFFENSIVE Torrent on " .. npcTarget:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, npcTarget:GetExtrapolatedLocation(nDelay + nCastPoint);
		end
	end
	
	local skThere, skLoc = mutil.IsSandKingThere(npcBot, nCastRange, 2.0);
	if skThere then
		--print("[KUNKKA] SANDKING Torrent");
		return BOT_ACTION_DESIRE_HIGH, skLoc;
	end	
	
	return BOT_ACTION_DESIRE_NONE, {};
end

function ConsiderXMark()
	
	if abilityXS == nil then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	if not abilityXS:IsFullyCastable() or Combo1 > 0 or Combo2 > 0 or Combo3 > 0
	then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = abilityXS:GetCastRange();
	local nManaCost = abilityXS:GetManaCost();
	
	--print("[KUNKKA] X Marks check - Range: " .. nCastRange);
	
	-- HARASSMENT: Use during laning
	if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, nManaCost)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #tableNearbyEnemyHeroes >= 1 then
			--print("[KUNKKA] HARASSMENT X Marks on " .. tableNearbyEnemyHeroes[1]:GetUnitName());
			return BOT_ACTION_DESIRE_MODERATE, tableNearbyEnemyHeroes[1];
		end
	end

	-- TEAMFIGHT: Use in teamfights
	if mutil.IsInTeamFight(npcBot, 1200) 
	then
		local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if ( #enemies >= 1 ) 
		then
			--print("[KUNKKA] TEAMFIGHT X Marks on " .. enemies[1]:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, enemies[1];
		end
	end
	
	-- INTERRUPT: Interrupt channeling or retreating enemies
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
	for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
	do
		if ( mutil.SafeIsChanneling(npcEnemy) or ( npcEnemy:GetActiveMode() == BOT_MODE_RETREAT and npcEnemy:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH ) ) 
		then
			--print("[KUNKKA] INTERRUPT/RETREAT X Marks on " .. npcEnemy:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, npcEnemy;
		end
	end
	
	-- RETREAT: If we're retreating
	if mutil.IsRetreating(npcBot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if (npcBot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) ) 
			then
				--print("[KUNKKA] RETREAT X Marks on " .. npcEnemy:GetUnitName());
				return BOT_ACTION_DESIRE_HIGH, npcEnemy;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderGhostShip()
	
	if abilityGS == nil then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	if not abilityGS:IsFullyCastable() or Combo1 > 0 or Combo2 > 0 or Combo3 > 0
	then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = abilityGS:GetCastRange();
	local nRadius = abilityGS:GetSpecialValueInt("ghostship_width");
	local nDamage = abilityGS:GetAbilityDamage();
	
	--print("[KUNKKA] Ghost Ship check - Range: " .. nCastRange .. " Width: " .. nRadius .. " Damage: " .. nDamage);
	
	-- TEAMFIGHT: Very liberal ultimate usage
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local locationAoE = npcBot:FindAoELocation( true, true, npcBot:GetLocation(), nCastRange, nRadius, 0, 0 );
		if ( locationAoE.count >= 2 ) -- Reduced from 3
		then
			--print("[KUNKKA] TEAMFIGHT Ghost Ship - " .. locationAoE.count .. " enemies");
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
		elseif ( locationAoE.count >= 1 ) then -- Single target acceptable
			--print("[KUNKKA] TEAMFIGHT Ghost Ship (single) - " .. locationAoE.count .. " enemy");
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
		end
	end

	-- GOING ON SOMEONE: Use ultimate offensively
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)
		then
			--print("[KUNKKA] OFFENSIVE Ghost Ship on " .. npcTarget:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, npcTarget:GetLocation();
		end
	end
	
	-- INTERRUPT: Interrupt channeling
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
	for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
	do
		if ( mutil.SafeIsChanneling(npcEnemy) ) 
		then
			--print("[KUNKKA] INTERRUPT Ghost Ship on " .. npcEnemy:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
		end
	end
	
	-- RETREAT: If we're seriously retreating
	if mutil.IsRetreating(npcBot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if (npcBot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) ) 
			then
				--print("[KUNKKA] RETREAT Ghost Ship");
				return BOT_ACTION_DESIRE_HIGH, GetTowardsFountainLocation(npcBot:GetLocation(), nCastRange - 200)
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTorrentStorm()

	if abilityTS == nil then
		return BOT_ACTION_DESIRE_NONE;
	end

	-- Make sure it's castable
	if ( abilityTS:IsFullyCastable() == false or npcBot:HasScepter() == false ) then 
		return BOT_ACTION_DESIRE_NONE;
	end

	-- Get some of its values
	local nRadius    = abilityTS:GetSpecialValueInt( "torrent_max_distance" );
	local nCastPoint = abilityTS:GetCastPoint( );
	local nManaCost  = abilityTS:GetManaCost( );

	--print("[KUNKKA] Torrent Storm check - Range: " .. nRadius);

	-- TEAMFIGHT: Very liberal scepter ultimate usage
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nRadius - 200, true, BOT_MODE_NONE );
		if ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 1 ) -- Reduced from 2
		then
			--print("[KUNKKA] TEAMFIGHT Torrent Storm - " .. #tableNearbyEnemyHeroes .. " enemies");
			return BOT_ACTION_DESIRE_HIGH;
		end
	end

	-- If we're seriously retreating
	if mutil.IsRetreating(npcBot) 
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nRadius, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy)  ) 
			then
				--print("[KUNKKA] RETREAT Torrent Storm");
				return BOT_ACTION_DESIRE_HIGH;
			end
		end
	end
	
	-- If we're going after someone
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nRadius-200)
		then
			--print("[KUNKKA] OFFENSIVE Torrent Storm on " .. npcTarget:GetUnitName());
			return BOT_ACTION_DESIRE_HIGH; -- Increased from MODERATE
		end
	end

	return BOT_ACTION_DESIRE_NONE;
end

