local U = {};

local RB = Vector(-7174.000000, -6671.00000,  0.000000)
local DB = Vector(7023.000000, 6450.000000, 0.000000)
local maxGetRange = 1600;
local maxAddedRange = 200;

local fSpamThreshold = 0.55;

U.towers = { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3,
                   TOWER_MID_1, TOWER_MID_2, TOWER_MID_3,
                   TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3,
                   TOWER_BASE_1, TOWER_BASE_2
				   }
U.barracks = { BARRACKS_TOP_MELEE, BARRACKS_TOP_RANGED, 
					 BARRACKS_MID_MELEE, BARRACKS_MID_RANGED, 
					 BARRACKS_BOT_MELEE, BARRACKS_BOT_RANGED
					}				   

local listBoots = {
	['item_boots'] = 45, 
	['item_tranquil_boots'] = 90, 
	['item_power_treads'] = 45, 
	['item_phase_boots'] = 45, 
	['item_arcane_boots'] = 50, 
	['item_guardian_greaves'] = 55,
	['item_travel_boots'] = 100,
	['item_travel_boots_2'] = 100
}

local modifier = {
	"modifier_winter_wyvern_winters_curse",
	"modifier_winter_wyvern_winters_curse_aura"
	--"modifier_modifier_dazzle_shallow_grave",
	--"modifier_modifier_oracle_false_promise",
	--"modifier_oracle_fates_edict"
}


-- Universal visibility checker
function U.CanSafelyCheck(unit)
    if not unit or unit == nil then return false end
    if not unit.GetTeam then return false end
    
    local success, unitTeam = pcall(function() return unit:GetTeam() end)
    if not success then return false end
    
    if unitTeam == GetTeam() then return true end
    
    if unit.CanBeSeen then
        local canSeeSuccess, canSeeResult = pcall(function() return unit:CanBeSeen() end)
        if canSeeSuccess then return canSeeResult end
    end
    
    return false
end

-- Safe wrappers for all problematic functions
function U.SafeGetHealth(unit)
    if not U.CanSafelyCheck(unit) then return 0 end
    return unit:GetHealth()
end

function U.SafeGetMaxHealth(unit)
    if not U.CanSafelyCheck(unit) then return 1 end -- Avoid division by zero
    return unit:GetMaxHealth()
end

function U.SafeIsChanneling(unit)
    if not U.CanSafelyCheck(unit) then return false end
    return unit:IsChanneling()
end

function U.SafeGetHealthPercent(unit)
    if not U.CanSafelyCheck(unit) then return 0 end
    return unit:GetHealth() / unit:GetMaxHealth()
end

function U.SafeWasRecentlyDamaged(unit, timeWindow)
    if not unit then return false end
    if unit:GetTeam() ~= GetTeam() then return false end  -- Only check our team
    return unit:WasRecentlyDamagedByAnyHero(timeWindow)  -- FIXED: Correct API call
end

function U.SafeGetHealthForBuilding(building)
    if not building then return 0 end
    return building:GetHealth()
end

function U.SafeGetHealthPercentForBuilding(building)
    if not building then return 0 end
    return building:GetHealth() / building:GetMaxHealth()
end

function U.SafeGetEstimatedDamageToTarget(unit, includeAbilities, target, duration, damageType)
    if not U.CanSafelyCheck(unit) then return 0 end
    if not target then return 0 end
    
    local success, damage = pcall(function() 
        return unit:GetEstimatedDamageToTarget(includeAbilities, target, duration, damageType) 
    end)
    
    if success then
        return damage
    else
        return 0
    end
end

function U.SafeGetAttackTarget(unit)
    if not U.CanSafelyCheck(unit) then return nil end
    
    local success, target = pcall(function() 
        return unit:GetAttackTarget() 
    end)
    
    if success then
        return target
    else
        return nil
    end
end

-- Add these to your existing safe wrapper functions in MyUtility.lua

function U.SafeGetNearbyHeroes(unit, radius, enemy, mode)
    if not U.CanSafelyCheck(unit) then 
        return {} -- Return empty table instead of nil
    end
    
    local success, result = pcall(function() 
        return unit:GetNearbyHeroes(radius, enemy, mode) 
    end)
    
    if success and result then
        return result
    else
        return {} -- Return empty table on failure
    end
end

function U.SafeGetNearbyCreeps(unit, radius, enemy)
    if not U.CanSafelyCheck(unit) then 
        return {} -- Return empty table instead of nil
    end
    
    local success, result = pcall(function() 
        return unit:GetNearbyCreeps(radius, enemy) 
    end)
    
    if success and result then
        return result
    else
        return {} -- Return empty table on failure
    end
end

function U.SafeGetNearbyLaneCreeps(unit, radius, enemy)
    if not U.CanSafelyCheck(unit) then 
        return {} -- Return empty table instead of nil
    end
    
    local success, result = pcall(function() 
        return unit:GetNearbyLaneCreeps(radius, enemy) 
    end)
    
    if success and result then
        return result
    else
        return {} -- Return empty table on failure
    end
end

function U.SafeGetTarget(unit)
    if not U.CanSafelyCheck(unit) then 
        return nil 
    end
    
    local success, target = pcall(function() 
        return unit:GetTarget() 
    end)
    
    if success then
        return target
    else
        return nil
    end
end


local SafeGetTarget = U.SafeGetTarget
local SafeGetNearbyHeroes = U.SafeGetNearbyHeroes
local SafeGetNearbyCreeps = U.SafeGetNearbyCreeps
local SafeGetNearbyLaneCreeps = U.SafeGetNearbyLaneCreeps
local SafeGetEstimatedDamageToTarget = U.SafeGetEstimatedDamageToTarget
local SafeGetAttackTarget = U.SafeGetAttackTarget
local SafeGetHealth = U.SafeGetHealth
local SafeGetMaxHealth = U.SafeGetMaxHealth
local SafeIsChanneling = U.SafeIsChanneling
local SafeGetHealthPercent = U.SafeGetHealthPercent
local SafeWasRecentlyDamaged = U.SafeWasRecentlyDamaged
local SafeGetHealthForBuilding = U.SafeGetHealthForBuilding
local SafeGetHealthPercentForBuilding = U.SafeGetHealthPercentForBuilding
local CanSafelyCheck = U.CanSafelyCheck


function U.InitiateAbilities(hUnit, tSlots)
	local abilities = {};
	for i = 1, #tSlots do
		abilities[i] = hUnit:GetAbilityInSlot(tSlots[i]);
	end
	return abilities;
end

function U.CantUseAbility(bot)
	return bot:NumQueuedActions() > 0 
		   or bot:IsAlive() == false or bot:IsInvulnerable() or bot:IsCastingAbility() or bot:IsUsingAbility() or SafeIsChanneling(bot)  
	       or bot:IsSilenced() or bot:IsStunned() or bot:IsHexed()  
		   or bot:HasModifier("modifier_doom_bringer_doom")
		   or bot:HasModifier('modifier_item_forcestaff_active')
end

function U.CanBeCast(ability)
	return ability:IsTrained() and ability:IsFullyCastable() and ability:IsHidden() == false;
end

function U.GetProperCastRange(bIgnore, hUnit, abilityCR)
	local attackRng = hUnit:GetAttackRange();
	if bIgnore then
		return abilityCR;
	elseif abilityCR <= attackRng then
		return attackRng + maxAddedRange;
	elseif abilityCR + maxAddedRange <= maxGetRange then
		return abilityCR + maxAddedRange;
	elseif abilityCR > maxGetRange then
		return maxGetRange;
	else
		return abilityCR;
	end
end

function U.GetVulnerableWeakestUnit(bHero, bEnemy, nRadius, bot)
	local units = {};
	local weakest = nil;
	local weakestHP = 10000;
	if bHero then
		units = bot:GetNearbyHeroes(nRadius, bEnemy, BOT_MODE_NONE);
	else
		units = bot:GetNearbyLaneCreeps(nRadius, bEnemy);
	end
	for _,u in pairs(units) do
		if SafeGetHealth(u) < weakestHP and U.CanCastOnNonMagicImmune(u) then
			weakest = u;
			weakestHP = SafeGetHealth(u);
		end
	end
	return weakest;
end

function U.GetUnitCountAroundEnemyTarget(target, nRadius)
	local heroes = target:GetNearbyHeroes(nRadius, false, BOT_MODE_NONE);	
	local creeps = target:GetNearbyLaneCreeps(nRadius, false);	
	return #heroes + #creeps;
end

function U.GetNumEnemyAroundMe(npcBot)
	local heroes = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);	
	return #heroes;
end

function U.GetVulnerableUnitNearLoc(bHero, bEnemy, nCastRange, nRadius, vLoc, bot)
	local units = {};
	local weakest = nil;
	if bHero then
		units = bot:GetNearbyHeroes(nCastRange, bEnemy, BOT_MODE_NONE);
	else
		units = bot:GetNearbyLaneCreeps(nCastRange, bEnemy);
	end
	for _,u in pairs(units) do
		if GetUnitToLocationDistance(u, vLoc) < nRadius and U.CanCastOnNonMagicImmune(u) then
			weakest = u;
			break;
		end
	end
	return weakest;
end

function U.CanSpamSpell(bot, manaCost)
	local initialRatio = 1.0;
	if manaCost < 100 then
		initialRatio = 0.6;
	end
	return ( bot:GetMana() - manaCost ) / bot:GetMaxMana() >= ( initialRatio - bot:GetLevel()/(3*30) );
end


function U.GetAllyWithNoBuff(nCastRange, sModifier, bot)
	local target = nil;
	local allies = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
	for _,u in pairs(allies) do
		if not u:HasModifier(sModifier) and U.CanCastOnNonMagicImmune(u) then
			target = u;
			break;
		end
	end
	return target;
end

function U.GetBuildingWithNoBuff(nCastRange, sModifier, bot)
	local ancient = GetAncient(GetTeam());
	if not ancient:IsInvulnerable() and GetUnitToUnitDistance(ancient, bot) < nCastRange then
		return ancient;
	end
	local barracks = bot:GetNearbyBarracks(nCastRange, false);
	for _,u in pairs(barracks) do
		if not u:HasModifier(sModifier) and not u:IsInvulnerable() then
			return u;
		end
	end
	local towers = bot:GetNearbyTowers(nCastRange, false);
	for _,u in pairs(towers) do
		if not u:HasModifier(sModifier) and not u:IsInvulnerable() then
			return u;
		end
	end
	return nil;
end

function U.GetSpellKillTarget(bot, bHero, nRadius, nDamage, nDamageType)
	local units = {};
	if bHero then
		units = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
	else
		units = bot:GetNearbyLaneCreeps(nRadius, true);
	end
	for _,unit in pairs(units) do
		if unit ~= nil and SafeGetHealth(unit) <= unit:GetActualIncomingDamage(nDamage, nDamageType) then
			return unit;
		end
	end
	return nil;
end

function U.IsEnemyTargetMyTarget(bot, hTarget)
	local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
	for _,enemy in pairs(enemies) do
		local eaTarget = SafeGetAttackTarget(enemy); 
		if eaTarget ~= nil and eaTarget == hTarget then
			return true;
		end	
	end
	return false;
end

function U.GetProperTarget(bot)
	local target = bot:GetTarget();
	if target == nil then
		target = SafeGetAttackTarget(bot);
	end
	return target;
end

function U.GetHumanPlayers()
	local listHumanPlayer = {};
	for i,id in pairs(GetTeamPlayers(GetTeam())) do
		if not IsPlayerBot(id) then
			local humanPlayer = GetTeamMember(i);
			if humanPlayer ~=  nil then
				table.insert(listHumanPlayer, humanPlayer);
			end
		end
	end
	return listHumanPlayer;
end

function U.IsHumanPlayerCanKill(target)
	local bot = GetBot();
	if target:GetTeam() ~= bot:GetTeam() and target:IsHero() then
		local humanPlayers = U.GetHumanPlayers();
		if U.IsHumanPingNotToKill(target, humanPlayers) then
			--print("Human Pinging! You're not Allowed to Kill The Target!");
			return true;
		elseif U.IsHumanCanKillTheTarget(target, humanPlayers) then
			--print("Human Can Kill The Target! You're not Allowed to Kill The Target!");	
			return true;
		end
	end
	return false;
end

function U.IsHumanPingNotToKill(target, listHumanPlayer)
	for _,human in pairs(listHumanPlayer) do
		if human ~= nil and not human:IsNull() and SafeGetAttackTarget(human) == target then
			local ping = human:GetMostRecentPing();
			if ping ~= nil and not ping.normal_ping and GetUnitToLocationDistance(target, ping.location) <= 1200 and GameTime() - ping.time < 3.0 then
				return true;
			end	
		end	
	end
	return false;
end

function U.IsHumanCanKillTheTarget(target, listHumanPlayer)
	local total_damage = 0;
	for _,human in pairs(listHumanPlayer) do
		if human ~= nil and not human:IsNull() and SafeGetAttackTarget(human) == target then
			local damage = SafeGetEstimatedDamageToTarget(human,true, target, 2.0, DAMAGE_TYPE_ALL);
			total_damage = total_damage + damage;
		end	
	end
	if total_damage > SafeGetHealth(target) then
		--print("Total Damage:"..tostring(total_damage))
		return true;
	end
	return false;
end

function U.GetAlliesNearLoc(vLoc, nRadius)
	local allies = {};
	for i,id in pairs(GetTeamPlayers(GetTeam())) do
		local member = GetTeamMember(i);
		if member ~= nil and member:IsAlive() and GetUnitToLocationDistance(member, vLoc) <= nRadius then
			table.insert(allies, member);
		end
	end
	return allies;
end

function U.GetShackleCreepTarget(hSource, hTarget, nRadius)
	local vStart = hSource:GetLocation();
	local vEnd = hTarget:GetLocation();
	local creeps = hTarget:GetNearbyCreeps(nRadius, false);
	for i=1, #creeps do
		local dist1 = GetUnitToUnitDistance(creeps[i], hTarget);
		local dist2 = GetUnitToUnitDistance(creeps[i], hSource);
		local dist3 = GetUnitToUnitDistance(hTarget, hSource);
		if  dist2 < dist3 and dist1 > 125  then
			local tResult = PointToLineDistance(vStart, vEnd, creeps[i]:GetLocation());
			if tResult ~= nil 
				and tResult.within == true 
				and tResult.distance < 75
			then
				-- print('to creep in front')
				return creeps[i];
			end
		end
	end
	return nil;
end

function U.GetShackleHeroTarget(hSource, hTarget, nRadius)
	local vStart = hSource:GetLocation();
	local vEnd = hTarget:GetLocation();
	local heroes = hTarget:GetNearbyHeroes(nRadius, false, BOT_MODE_NONE);
	for i=1, #heroes do
		if heroes[i] ~= hTarget and U.CanCastOnNonMagicImmune(heroes[i]) then
			local dist1 = GetUnitToUnitDistance(heroes[i], hTarget);
			local dist2 = GetUnitToUnitDistance(heroes[i], hSource);
			local dist3 = GetUnitToUnitDistance(hTarget, hSource);
			if  dist2 < dist3 and dist1 > 125  then
				local tResult = PointToLineDistance(vStart, vEnd, heroes[i]:GetLocation());
				if tResult ~= nil 
					and tResult.within == true 
					and tResult.distance < 75	
				then
					-- print('to hero in front')
					return heroes[i];
				end
			end
		end
	end
	return nil;
end

function U.CanShackleToCreep(hSource, hTarget, nRadius)
	local vStart = hSource:GetLocation();
	local creeps = hTarget:GetNearbyCreeps(nRadius, false);
	for i=1, #creeps do
		local vEnd = creeps[i]:GetLocation()
		local tResult = PointToLineDistance(vStart, vEnd, hTarget:GetLocation());
		if GetUnitToUnitDistance(creeps[i], hTarget) > 125 and tResult ~= nil 
			and tResult.within == true  			
			and tResult.distance < 75  			
		then
			-- print('to creep behind')
			return true;
		end
	end
	return false;
end

function U.CanShackleToHero(hSource, hTarget, nRadius)
	local vStart = hSource:GetLocation();
	local heroes = hTarget:GetNearbyHeroes(nRadius, false, BOT_MODE_NONE);
	for i=1, #heroes do
		local vEnd = heroes[i]:GetLocation()
		local tResult = PointToLineDistance(vStart, vEnd, hTarget:GetLocation());
		if heroes[i] ~= hTarget and GetUnitToUnitDistance(heroes[i], hTarget) > 125 and tResult ~= nil 
			and tResult.within == true  
			and tResult.distance < 75 			
		then
			-- print('to hero behind')
			return true;
		end
	end
	return false;
end

function U.CanShackleToTree(hSource, hTarget, nRadius)
	local vStart = hSource:GetLocation();
	local trees = hTarget:GetNearbyTrees(nRadius);
	for i=1, #trees do
		local vEnd = GetTreeLocation(trees[i]);
		local tResult = PointToLineDistance(vStart, vEnd, hTarget:GetLocation());
		if tResult ~= nil 
			and tResult.within == true 
			and tResult.distance < 75 			
		then
			-- print('to tree behind')
			return true;
		end
	end
	return false;
end

function U.GetShackleTarget(hero, target, nRadius, nRange)
	local sTarget = nil;
	local dist = GetUnitToUnitDistance(hero, target);
	if dist < nRange and U.CanShackleToCreep(hero, target, nRadius) 
		or U.CanShackleToHero(hero, target, nRadius)
		or U.CanShackleToTree(hero, target, nRadius)
	then
		sTarget = target;
	elseif dist < nRange or dist < nRange+nRadius then
		sTarget = U.GetShackleCreepTarget(hero, target, nRadius);
		if sTarget == nil then
			sTarget = U.GetShackleHeroTarget(hero, target, nRadius);
		end
	end
	return sTarget;
end

function U.IsEnemyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation();
	local vEnd = vLoc;
	local creeps = hSource:GetNearbyLaneCreeps(1600, true);
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
			return true;
		end
	end
	creeps = hTarget:GetNearbyLaneCreeps(1600, false);
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
			return true;
		end
	end
	return false;
end

function U.IsAllyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation();
	local vEnd = vLoc;
	local creeps = hSource:GetNearbyLaneCreeps(1600, false);
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
			return true;
		end
	end
	creeps = hTarget:GetNearbyLaneCreeps(1600, true);
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
			return true;
		end
	end
	return false;
end

function U.IsCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	if not U.IsAllyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius) then
		return U.IsEnemyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius);
	end
	return true;
end

function U.IsEnemyHeroBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation();
	local vEnd = vLoc;
	local heroes = hSource:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
	for i,hero in pairs(heroes) do
		if hero ~= hTarget  then
			local tResult = PointToLineDistance(vStart, vEnd, hero:GetLocation());
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
				return true;
			end
		end
	end
	heroes = hTarget:GetNearbyHeroes(1600, false, BOT_MODE_NONE);
	for i,hero in pairs(heroes) do
		if hero ~= hTarget  then
			local tResult = PointToLineDistance(vStart, vEnd, hero:GetLocation());
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
				return true;
			end
		end
	end
	return false;
end

function U.IsAllyHeroBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation();
	local vEnd = vLoc;
	local heroes = hSource:GetNearbyHeroes(1600, false, BOT_MODE_NONE);
	for i,hero in pairs(heroes) do
		if hero ~= hSource then
			local tResult = PointToLineDistance(vStart, vEnd, hero:GetLocation());
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
				return true;
			end
		end
	end
	heroes = hTarget:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
	for i,hero in pairs(heroes) do
		if hero ~= hSource then
			local tResult = PointToLineDistance(vStart, vEnd, hero:GetLocation());
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
				return true;
			end
		end
	end
	return false;
end

function U.IsHeroBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	if not U.IsAllyHeroBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius) then
		return U.IsEnemyHeroBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius);
	end
	return true;
end

function U.IsSandKingThere(bot, nCastRange, fTime)
	local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
	for _,enemy in pairs(enemies) do
		if enemy:GetUnitName() == "npc_dota_hero_sand_king" and enemy:HasModifier('modifier_sandking_sand_storm_invis') then
			return true,  enemy:GetLocation();
		end
	end
	return false, nil;
end

function U.GetUltimateAbility(bot)
	--print(tostring(bot:GetAbilityInSlot(5):GetName()))
	return bot:GetAbilityInSlot(5);
end

function U.CanUseRefresherShard(bot)
	local ult = U.GetUltimateAbility(bot);
	if ult ~= nil and ult:IsPassive() == false then
		local ultCD = ult:GetCooldown();
		local manaCost = ult:GetManaCost();
		if bot:GetMana() >= manaCost and ult:GetCooldownTimeRemaining() >= ultCD/2 then
			return true;
		end
	end
	return false;
end

function U.GetMostUltimateCDUnit()
	local unit = nil;
	local maxCD = 0;
	for i,id in pairs(GetTeamPlayers(GetTeam())) do
		if IsHeroAlive(id) then
			local member = GetTeamMember(i);
			if member ~= nil then
				local ult = U.GetUltimateAbility(member);
				--print(member:GetUnitName()..tostring(ult:GetName())..tostring(ult:GetCooldown()))
				if ult ~= nil and ult:IsPassive() == false and ult:GetCooldown() >= maxCD then
					unit = member;
					maxCD = ult:GetCooldown();
				end
			end
		end
	end
	return unit;
end

function U.CanUseRefresherOrb(bot)
	local ult = U.GetUltimateAbility(bot);
	if ult ~= nil and ult:IsPassive() == false then
		local ultCD = ult:GetCooldown();
		local manaCost = ult:GetManaCost();
		if bot:GetMana() >= manaCost+375 and ult:GetCooldownTimeRemaining() >= ultCD/2 then
			return true;
		end
	end
	return false;
end
--============== ^^^^^^^^^^ NEW FUNCTION ABOVE ^^^^^^^^^ ================--

function U.IsRetreating(npcBot)
	return ( npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE and 
	      ( npcBot:DistanceFromFountain() > 0 or ( npcBot:DistanceFromFountain() < 300 and U.GetNumEnemyAroundMe(npcBot) > 0 ))) or
		  ( npcBot:GetActiveMode() == BOT_MODE_EVASIVE_MANEUVERS and SafeWasRecentlyDamaged(npcBot,3.0)) or
		  ( npcBot:HasModifier('modifier_bloodseeker_rupture') and SafeWasRecentlyDamaged(npcBot,3.0) )
end

function U.IsValidTarget(npcTarget)
	return npcTarget ~= nil and npcTarget:IsAlive() and npcTarget:IsHero(); 
end

function U.IsSuspiciousIllusion(npcTarget)
	--TO DO Need to detect enemy hero's illusions better
	local bot = GetBot();


	--Detect allies's illusions
	if npcTarget:HasModifier('modifier_illusion') 
	   or npcTarget:HasModifier('modifier_phantom_lancer_doppelwalk_illusion') or npcTarget:HasModifier('modifier_phantom_lancer_juxtapose_illusion')
       or npcTarget:HasModifier('modifier_darkseer_wallofreplica_illusion') or npcTarget:HasModifier('modifier_terrorblade_conjureimage')	   
	then
		return true;
	else
	   --Detect replicate and wall of replica illusions
	    if GetGameMode() ~= GAMEMODE_MO then
			if npcTarget:GetTeam() ~= bot:GetTeam() then
				local TeamMember = GetTeamPlayers(GetTeam());
				for i = 1, #TeamMember
				do
					local ally = GetTeamMember(i);
					if ally ~= nil and ally:GetUnitName() == npcTarget:GetUnitName() then
						return true;
					end
				end
			end
		end
		return false;
	end
end

function U.CanCastOnMagicImmune(npcTarget)
	return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable() and not U.IsSuspiciousIllusion(npcTarget) and not U.HasForbiddenModifier(npcTarget) and not U.IsHumanPlayerCanKill(npcTarget);
end

function U.CanCastOnNonMagicImmune(npcTarget)
	return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable() and not U.IsSuspiciousIllusion(npcTarget) and not U.HasForbiddenModifier(npcTarget) and not U.IsHumanPlayerCanKill(npcTarget);
end

function U.CanCastOnTargetAdvanced( npcTarget )
	return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable() and not U.HasForbiddenModifier(npcTarget)
end

function U.CanKillTarget(npcTarget, dmg, dmgType)
	return npcTarget:GetActualIncomingDamage( dmg, dmgType ) >= SafeGetHealth(npcTarget); 
end

function U.HasForbiddenModifier(npcTarget)
	for _,mod in pairs(modifier)
	do
		if npcTarget:HasModifier(mod) then
			return true
		end	
	end
	return false;
end

function U.ShouldEscape(npcBot)
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
	if ( SafeWasRecentlyDamaged(npcBot, 2.0) or npcBot:WasRecentlyDamagedByTower(2.0) or ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 1  ) )
	then
		return true;
	end
end

function U.IsRoshan(npcTarget)
	return npcTarget ~= nil and npcTarget:IsAlive() and string.find(npcTarget:GetUnitName(), "roshan");
end

function U.IsDisabled(enemy, npcTarget)
	if enemy then
		return npcTarget:IsRooted( ) or npcTarget:IsStunned( ) or npcTarget:IsHexed( ) or npcTarget:IsNightmared() or U.IsTaunted(npcTarget); 
	else
		return npcTarget:IsRooted( ) or npcTarget:IsStunned( ) or npcTarget:IsHexed( ) or npcTarget:IsNightmared() or npcTarget:IsSilenced( ) or U.IsTaunted(npcTarget);
	end
end

function U.IsSlowed(bot)
	local speedPlusBoots =  U.GetUpgradedSpeed(bot);
	return bot:GetCurrentMovementSpeed() < speedPlusBoots;
end

function U.GetUpgradedSpeed(bot)
	for i=0,5 do
		local item = bot:GetItemInSlot(i);
		if item ~= nil and listBoots[item:GetName()] ~= nil then
			return bot:GetBaseMovementSpeed()+listBoots[item:GetName()];
		end
	end
	return bot:GetBaseMovementSpeed();
end

function U.IsTaunted(npcTarget)
	return npcTarget:HasModifier("modifier_axe_berserkers_call") 
	    or npcTarget:HasModifier("modifier_legion_commander_duel") 
	    or npcTarget:HasModifier("modifier_winter_wyvern_winters_curse") 
		or npcTarget:HasModifier(" modifier_winter_wyvern_winters_curse_aura");
end

function U.IsInRange(npcTarget, npcBot, nCastRange)
	return GetUnitToUnitDistance( npcTarget, npcBot ) <= nCastRange;
end

function U.IsInTeamFight(npcBot, range)
	local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes( range, false, BOT_MODE_ATTACK );
	return tableNearbyAttackingAlliedHeroes ~= nil and #tableNearbyAttackingAlliedHeroes >= 2;
end

function U.CanNotUseAbility(npcBot)
	return npcBot:IsCastingAbility() or npcBot:IsUsingAbility() or npcBot:IsInvulnerable() 
	or SafeIsChanneling(npcBot) or npcBot:IsSilenced() or npcBot:HasModifier("modifier_doom_bringer_doom");
end

function U.IsGoingOnSomeone(npcBot)
	local mode = npcBot:GetActiveMode();
	return mode == BOT_MODE_ROAM or
		   mode == BOT_MODE_TEAM_ROAM or
		   mode == BOT_MODE_GANK or
		   mode == BOT_MODE_ATTACK or
		   mode == BOT_MODE_DEFEND_ALLY
end

function U.IsDefending(npcBot)
	local mode = npcBot:GetActiveMode();
	return mode == BOT_MODE_DEFEND_TOWER_TOP or
		   mode == BOT_MODE_DEFEND_TOWER_MID or
		   mode == BOT_MODE_DEFEND_TOWER_BOT 
end

function U.IsPushing(npcBot)
	local mode = npcBot:GetActiveMode();
	return mode == BOT_MODE_PUSH_TOWER_TOP or
		   mode == BOT_MODE_PUSH_TOWER_MID or
		   mode == BOT_MODE_PUSH_TOWER_BOT 
end

function U.GetTeamFountain()
	local Team = GetTeam();
	if Team == TEAM_DIRE then
		return DB;
	else
		return RB;
	end
end

function U.GetComboItem(npcBot, item_name)
	local Slot = npcBot:FindItemSlot(item_name);
	if Slot >= 0 and Slot <= 5 then
		return npcBot:GetItemInSlot(Slot);
	else
		return nil;
	end
end

function U.GetMostHpUnit(ListUnit)
	local mostHpUnit = nil;
	local maxHP = 0;
	for _,unit in pairs(ListUnit)
	do
		local uHp = SafeGetHealth(unit);
		if  uHp > maxHP then
			mostHpUnit = unit;
			maxHP = uHp;
		end
	end
	return mostHpUnit
end

function U.StillHasModifier(npcTarget, modifier)
	return npcTarget:HasModifier(modifier);
end

function U.AllowedToSpam(npcBot, nManaCost)
	return ( npcBot:GetMana() - nManaCost ) / npcBot:GetMaxMana() >= fSpamThreshold;
end

function U.IsProjectileIncoming(npcBot, range)
	local incProj = npcBot:GetIncomingTrackingProjectiles()
	for _,p in pairs(incProj)
	do
		if GetUnitToLocationDistance(npcBot, p.location) < range and not p.is_attack and p.is_dodgeable then
			return true;
		end
	end
	return false;
end

function U.GetMostHPPercent(listUnits, magicImmune)
	local mostPHP = 0;
	local mostPHPUnit = nil;
	for _,unit in pairs(listUnits)
	do
		local uPHP = SafeGetHealthPercent(unit)
		if ( ( magicImmune and U.CanCastOnMagicImmune(unit) ) or ( not magicImmune and U.CanCastOnNonMagicImmune(unit) ) ) 
			and uPHP > mostPHP  
		then
			mostPHPUnit = unit;
			mostPHP = uPHP;
		end
	end
	return mostPHPUnit;
end

function U.GetCanBeKilledUnit(units, nDamage, nDmgType, magicImmune)
	local target = nil;
	for _,unit in pairs(units)
	do
		if ( ( magicImmune and U.CanCastOnMagicImmune(unit) ) or ( not magicImmune and U.CanCastOnNonMagicImmune(unit) ) ) 
			   and U.CanKillTarget(unit, nDamage, nDmgType) 
		then
			unitKO = target;	
		end
	end
	return target;
end

function U.GetCorrectLoc(target, delay)
	if target:GetMovementDirectionStability() < 1.0 then
		return target:GetLocation();
	else
		return target:GetExtrapolatedLocation(delay);	
	end
end

function U.GetClosestUnit(units)
	local target = nil;
	if units ~= nil and #units >= 1 then
		return units[1];
	end
	return target;
end

function U.GetEnemyFountain()
	local Team = GetTeam();
	if Team == TEAM_DIRE then
		return RB;
	else
		return DB;
	end
end

function U.GetEscapeLoc()
	local bot = GetBot();
	local team = GetTeam();
	if bot:DistanceFromFountain() > 2500 then
		return GetAncient(team):GetLocation();
	else
		if team == TEAM_DIRE then
			return DB;
		else
			return RB;
		end
	end
end

function U.GetEscapeLoc2(unit)
	local team = unit:GetTeam();
	if unit:DistanceFromFountain() > 2500 then
		return GetAncient(team):GetLocation();
	else
		if team == TEAM_DIRE then
			return DB;
		else
			return RB;
		end
	end
end

function U.IsStuck2(npcBot)
	if npcBot.stuckLoc ~= nil and npcBot.stuckTime ~= nil then 
		local EAd = GetUnitToUnitDistance(npcBot, GetAncient(GetOpposingTeam()));
		if DotaTime() > npcBot.stuckTime + 5.0 and GetUnitToLocationDistance(npcBot, npcBot.stuckLoc) < 25  
           and npcBot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and EAd > 2200		
		then
			--print(npcBot:GetUnitName().." is stuck")
			--DebugPause();
			return true;
		end
	end
	return false
end

function U.IsStuck(npcBot)
	if npcBot.stuckLoc ~= nil and npcBot.stuckTime ~= nil then 
		local attackTarget = SafeGetAttackTarget(npcBot);
		local EAd = GetUnitToUnitDistance(npcBot, GetAncient(GetOpposingTeam()));
		local TAd = GetUnitToUnitDistance(npcBot, GetAncient(GetTeam()));
		local Et = npcBot:GetNearbyTowers(450, true);
		local At = npcBot:GetNearbyTowers(450, false);
		if npcBot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and attackTarget == nil and EAd > 2200 and TAd > 2200 and #Et == 0 and #At == 0  
		   and DotaTime() > npcBot.stuckTime + 5.0 and GetUnitToLocationDistance(npcBot, npcBot.stuckLoc) < 25    
		then
			--print(npcBot:GetUnitName().." is stuck")
			return true;
		end
	end
	return false
end

function U.IsExistInTable(u, tUnit)
	for _,t in pairs(tUnit) do
		if u:GetUnitName() == t:GetUnitName() then
			return true;
		end
	end
	return false;
end 

function U.FindNumInvUnitInLoc(pierceImmune, bot, nRange, nRadius, loc)
	local nUnits = 0;
	if nRange > 1600 then nRange = 1600 end
	local units = bot:GetNearbyHeroes(nRange, true, BOT_MODE_NONE);
	for _,u in pairs(units) do
		if ( ( pierceImmune and U.CanCastOnMagicImmune(u) ) or ( not pierceImmune and U.CanCastOnNonMagicImmune(u) ) ) and GetUnitToLocationDistance(u, loc) <= nRadius then
			nUnits = nUnits + 1;
		end
	end
	return nUnits;
end

function U.CountInvUnits(pierceImmune, units)
	local nUnits = 0;
	if units ~= nil then
		for _,u in pairs(units) do
			if ( pierceImmune and U.CanCastOnMagicImmune(u) ) or ( not pierceImmune and U.CanCastOnNonMagicImmune(u) )  then
				nUnits = nUnits + 1;
			end
		end
	end
	return nUnits;
end

function U.CountUnitsNearLocation(pierceImmune, hUnits, vLoc, nRadius)
	local nUnits = 0;
	if hUnits ~= nil then
		for i=1, #hUnits do
			if	GetUnitToLocationDistance(hUnits[i], vLoc) <= nRadius 
				and ( ( pierceImmune and U.CanCastOnMagicImmune(hUnits[i]) ) or ( not pierceImmune and U.CanCastOnNonMagicImmune(hUnits[i]) ) ) 
			then
				nUnits = nUnits + 1;
			end
		end
	end
	return nUnits;
end

function U.CanBeDominatedCreeps(name)
	return name == "npc_dota_neutral_centaur_khan"
		 or name == "npc_dota_neutral_polar_furbolg_ursa_warrior"	
		 or name == "npc_dota_neutral_satyr_hellcaller"	
		 or name == "npc_dota_neutral_dark_troll_warlord"	
		 or name == "npc_dota_neutral_mud_golem"	
		 or name == "npc_dota_neutral_harpy_storm"	
		 or name == "npc_dota_neutral_ogre_magi"	
		 or name == "npc_dota_neutral_alpha_wolf"	
		 or name == "npc_dota_neutral_enraged_wildkin"	
		 or name == "npc_dota_neutral_satyr_trickster"	
end

function U.CheckFlag(bitfield, flag)
    return ((bitfield/flag) % 2) >= 1;
end

function U.GetStrongestUnit(nRange, hUnit, bEnemy, bMagicImune, fTime)
	local units = hUnit:GetNearbyHeroes(nRange, bEnemy, BOT_MODE_NONE)
	local strongest_unit = nil;
	local maxPower = 0;
	for i=1, #units do
		if U.IsValidTarget(units[i]) and
		   ( ( bMagicImune == true and U.CanCastOnMagicImmune(units[i]) == true ) or ( bMagicImune == false and U.CanCastOnNonMagicImmune(units[i]) == true ) )
		then
			local power = SafeGetEstimatedDamageToTarget( units[i],  true, hUnit, fTime, DAMAGE_TYPE_ALL );
			if power > maxPower then
				maxPower = power;
				strongest_unit = units[i];
			end
		end
	end
	return strongest_unit;
end

function U.GetUnitWithMinDistanceToLoc(hUnit, hUnits, cUnits, fMinDist, vLoc)
	local minUnit = cUnits;
	local minVal = fMinDist;
	
	for i=1, #hUnits do
		if hUnits[i] ~= nil and hUnits[i] ~= hUnit and U.CanCastOnNonMagicImmune(hUnits[i]) 
		then
			local dist = GetUnitToLocationDistance(hUnits[i], vLoc);
			if dist < minVal then
				minVal = dist;
				minUnit = hUnits[i];	
			end
		end	
	end
	
	return minVal, minUnit;
end

function U.GetUnitWithMaxDistanceToLoc(hUnit, hUnits, cUnits, fMinDist, vLoc)
	local maxUnit = cUnits;
	local maxVal = fMinDist;
	
	for i=1, #hUnits do
		if hUnits[i] ~= nil and hUnits[i] ~= hUnit and U.CanCastOnNonMagicImmune(hUnits[i]) 
		then
			local dist = GetUnitToLocationDistance(hUnits[i], vLoc);
			if dist > maxVal then
				maxVal = dist;
				maxUnit = hUnits[i];	
			end
		end	
	end
	
	return maxVal, maxUnit;
end

function U.GetFurthestUnitToLocationFrommAll(hUnit, nRange, vLoc)
	local aHeroes = hUnit:GetNearbyHeroes(nRange, false, BOT_MODE_NONE);
	local eHeroes = hUnit:GetNearbyHeroes(nRange, true, BOT_MODE_NONE);
	local aCreeps = hUnit:GetNearbyLaneCreeps(nRange, false);
	local eCreeps = hUnit:GetNearbyLaneCreeps(nRange, true);
		
	local botDist = GetUnitToLocationDistance(hUnit, vLoc);
	local furthestUnit = hUnit;
	botDist, furthestUnit = U.GetUnitWithMaxDistanceToLoc(hUnit, aHeroes, furthestUnit, botDist, vLoc);
	botDist, furthestUnit = U.GetUnitWithMaxDistanceToLoc(hUnit, eHeroes, furthestUnit, botDist, vLoc);
	botDist, furthestUnit = U.GetUnitWithMaxDistanceToLoc(hUnit, aCreeps, furthestUnit, botDist, vLoc);
	botDist, furthestUnit = U.GetUnitWithMaxDistanceToLoc(hUnit, eCreeps, furthestUnit, botDist, vLoc);
	
	if furthestUnit ~= nil then
		return furthestUnit;
	end
	
	return nil;
	
end

function U.GetClosestUnitToLocationFrommAll(hUnit, nRange, vLoc)
	local aHeroes = hUnit:GetNearbyHeroes(nRange, false, BOT_MODE_NONE);
	local eHeroes = hUnit:GetNearbyHeroes(nRange, true, BOT_MODE_NONE);
	local aCreeps = hUnit:GetNearbyLaneCreeps(nRange, false);
	local eCreeps = hUnit:GetNearbyLaneCreeps(nRange, true);
		
	local botDist = GetUnitToLocationDistance(hUnit, vLoc);
	local closestUnit = hUnit;
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, aHeroes, closestUnit, botDist, vLoc);
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, eHeroes, closestUnit, botDist, vLoc);
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, aCreeps, closestUnit, botDist, vLoc);
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, eCreeps, closestUnit, botDist, vLoc);
	
	if closestUnit ~= nil then
		return closestUnit;
	end
	
	return nil;
	
end

function U.GetClosestUnitToLocationFrommAll2(hUnit, nRange, vLoc)
	local aHeroes = hUnit:GetNearbyHeroes(nRange, false, BOT_MODE_NONE);
	local eHeroes = hUnit:GetNearbyHeroes(nRange, true, BOT_MODE_NONE);
	local aCreeps = hUnit:GetNearbyLaneCreeps(nRange, false);
	local eCreeps = hUnit:GetNearbyLaneCreeps(nRange, true);
		
	local botDist = 10000;
	local closestUnit = nil;
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, aHeroes, closestUnit, botDist, vLoc);
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, eHeroes, closestUnit, botDist, vLoc);
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, aCreeps, closestUnit, botDist, vLoc);
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, eCreeps, closestUnit, botDist, vLoc);
	
	if closestUnit ~= nil then
		return closestUnit;
	end
	
	return nil;
	
end

function U.GetClosestEnemyUnitToLocation(hUnit, nRange, vLoc)
	local eHeroes = hUnit:GetNearbyHeroes(nRange, true, BOT_MODE_NONE);
	local eCreeps = hUnit:GetNearbyLaneCreeps(nRange, true);
		
	local botDist = GetUnitToLocationDistance(hUnit, vLoc);
	local closestUnit = hUnit;
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, eHeroes, closestUnit, botDist, vLoc);
	botDist, closestUnit = U.GetUnitWithMinDistanceToLoc(hUnit, eCreeps, closestUnit, botDist, vLoc);
	
	if closestUnit ~= nil then
		return closestUnit;
	end
	
	return nil;
	
end


-- ========================================
-- COMPREHENSIVE THREAT DETECTION SYSTEM
-- ========================================

-- Main threat detection function that replaces the old priority target system
function U.GetComprehensiveThreat(bot, range)
    if range == nil then range = 1200 end
    
    --print("[COMPREHENSIVE_THREAT] " .. bot:GetUnitName() .. " - Analyzing all threats in range " .. range)
    
    -- Priority 1: Finishable heroes (existing logic)
    local lowHpHero = U.GetFinishableEnemyHero(bot, range)
    if lowHpHero ~= nil then
        --print("[COMPREHENSIVE_THREAT] Found finishable enemy hero: " .. lowHpHero:GetUnitName())
        return lowHpHero, "finishable_hero", nil
    end
    
    -- Priority 2: Channeling threats (interrupt or evacuate)
    local channelingThreat, channelingAbility = U.GetChannelingThreat(bot, range)
    if channelingThreat ~= nil then
        ----print(("[COMPREHENSIVE_THREAT] Found channeling threat: " .. channelingThreat:GetUnitName() .. " casting " .. channelingAbility)
        return channelingThreat, "channeling_threat", channelingAbility
    end

	-- Priority 2.5: Chain Frost dispersion (urgent)
    local chainFrostThreat, chainFrostType, bounceRange = U.GetChainFrostThreat(bot, range)
    if chainFrostThreat ~= nil then
        --print(("[COMPREHENSIVE_THREAT] Found Chain Frost threat - Type: " .. chainFrostType)
        return chainFrostThreat, chainFrostType, bounceRange
    end
    
    -- Priority 3: Hit-based destructible threats
    local hitBasedThreat = U.GetHitBasedThreat(bot, range)
    if hitBasedThreat ~= nil then
        --print("[COMPREHENSIVE_THREAT] Found hit-based threat: " .. hitBasedThreat:GetUnitName())
        return hitBasedThreat, "hit_based_threat", nil
    end
    
    -- Priority 4: Danger zones (evacuate)
	local dangerZone = U.GetDangerZone(bot, range)
	if dangerZone ~= nil then
		if dangerZone == "modifier_phoenix_sun_debuff" then
			-- For Phoenix supernova, FORCE attack the bot's current location area
			-- This will make bots attack-move towards where the egg should be
			--print("[COMPREHENSIVE_THREAT] Phoenix supernova detected - attacking current area")
			return bot, "phoenix_egg_attack", nil  -- Use bot as target to attack current location
		else
			--print("[COMPREHENSIVE_THREAT] Found other danger zone: " .. dangerZone)
			return nil, "danger_zone", dangerZone
		end
	end
    
    -- Priority 5: HP-based destructible threats (existing wards)
    local priorityTarget = U.GetHPBasedThreat(bot, range)
    if priorityTarget ~= nil then
        --print("[COMPREHENSIVE_THREAT] Found HP-based summon: " .. priorityTarget:GetUnitName())
        return priorityTarget, "hp_based_threat", nil
    end
    
    --print("[COMPREHENSIVE_THREAT] No threats detected")
    return nil, "none", nil
end

-- Finishable heroes (low HP enemies)
function U.GetFinishableEnemyHero(bot, range)
    local nearbyEnemies = bot:GetNearbyHeroes(range, true, BOT_MODE_NONE)
    
    for _, enemy in pairs(nearbyEnemies) do
        if U.IsValidTarget(enemy) then
            local hpPercent = SafeGetHealthPercent(enemy)
            --print("[FINISHABLE_CHECK] Enemy " .. enemy:GetUnitName() .. " HP: " .. math.floor(hpPercent * 100) .. "%")
            
            if hpPercent <= 0.15 and U.CanCastOnNonMagicImmune(enemy) then
                --print("[FINISHABLE_CHECK] FOUND finishable enemy: " .. enemy:GetUnitName())
                return enemy
            end
        end
    end
    
    return nil
end

-- Channeling threat detection
function U.GetChannelingAbility(enemy)
    -- First check if the enemy unit is channeling
    if not U.SafeIsChanneling(enemy) then
        return nil
    end
    
    -- Then find which ability is being channeled
    for i = 0, 5 do
        local ability = enemy:GetAbilityInSlot(i)
        if ability ~= nil then
            -- Use pcall for extra safety since abilities can be tricky
            local success, isChanneling = pcall(function() return ability:IsChanneling() end)
            if success and isChanneling then
                local success2, abilityName = pcall(function() return ability:GetName() end)
                if success2 then
                    return abilityName
                end
            end
        end
    end
    return nil
end

function U.GetChannelingThreat(bot, range)
    local nearbyEnemies = bot:GetNearbyHeroes(range, true, BOT_MODE_NONE)
    
    for _, enemy in pairs(nearbyEnemies) do
        if U.IsValidTarget(enemy) and SafeIsChanneling(enemy) then
            local channelingAbility = U.GetChannelingAbility(enemy)
            --print("[CHANNELING_THREAT] Enemy " .. enemy:GetUnitName() .. " is channeling: " .. (channelingAbility or "unknown"))
            
            if U.IsDangerousChanneling(channelingAbility) then
                --print("[CHANNELING_THREAT] DANGEROUS channeling detected!")
                return enemy, channelingAbility
            else
                --print("[CHANNELING_THREAT] Non-dangerous channeling, ignoring")
            end
        end
    end
    
    return nil, nil
end


function U.IsDangerousChanneling(abilityName)
    if abilityName == nil then return false end
    
    local dangerousChanneling = {
        "crystal_maiden_freezing_field",
        "warlock_rain_of_chaos", 
        "witch_doctor_death_ward",
        "pudge_dismember",
        "enigma_black_hole",
        "bane_fiends_grip",
        "legion_commander_duel"
    }
    
    for _, dangerous in pairs(dangerousChanneling) do
        if abilityName == dangerous then
            --print("[DANGEROUS_CHANNELING] " .. abilityName .. " is dangerous!")
            return true
        end
    end
    
    return false
end

-- Hit-based threats (Tombstone, Phoenix Supernova)
function U.GetHitBasedThreat(bot, range)
    local allUnits = bot:GetNearbyNeutralCreeps(range)
    local enemyCreeps = bot:GetNearbyLaneCreeps(range, true)
    
    for _, creep in pairs(enemyCreeps) do
        table.insert(allUnits, creep)
    end
    
    --print("[HIT_BASED_THREAT] Checking " .. #allUnits .. " units for hit-based threats")
    
    for _, unit in pairs(allUnits) do
        if U.IsValidTarget(unit) and unit:GetTeam() ~= bot:GetTeam() then
            local unitName = unit:GetUnitName()
            --print("[HIT_BASED_THREAT] Checking: " .. unitName)
            
            if U.IsHitBasedThreat(unitName) then
                --print("[HIT_BASED_THREAT] Found hit-based threat: " .. unitName)
                
                if U.ShouldAttackHitBasedThreat(bot, unit) then
                    --print("[HIT_BASED_THREAT] Should attack: " .. unitName)
                    return unit
                else
                    --print("[HIT_BASED_THREAT] Should evacuate from: " .. unitName)
                end
            end
        end
    end
    
    return nil
end

function U.IsHitBasedThreat(unitName)
    local hitBasedThreats = {
        "npc_dota_phoenix_sun",
        "npc_dota_unit_tombstone1",
        "npc_dota_unit_tombstone2", 
        "npc_dota_unit_tombstone3",
        "npc_dota_unit_tombstone4",
        "npc_dota_templar_assassin_psionic_trap",
		"npc_dota_gyrocopter_homing_missile",
		"npc_dota_juggernaut_healing_ward",
		"npc_dota_grimstroke_ink_creature",
		"npc_dota_weaver_swarm"
    }
    
    for _, threat in pairs(hitBasedThreats) do
        if unitName == threat then
            return true
        end
    end
    
    return false
end

function U.ShouldAttackHitBasedThreat(bot, threat)
    local threatName = threat:GetUnitName()
    local nearbyAllies = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE)
    local alliesInRange = 1
    
    for _, ally in pairs(nearbyAllies) do
        if ally:IsAlive() and GetUnitToUnitDistance(ally, threat) <= ally:GetAttackRange() + 200 then
            alliesInRange = alliesInRange + 1
        end
    end
    
    --print("[HIT_BASED_EVALUATION] " .. threatName .. " - Allies in range: " .. alliesInRange)
    
    local requiredHits = U.GetRequiredHits(threat)
    --print("[HIT_BASED_EVALUATION] Required hits: " .. requiredHits)
    
    if alliesInRange >= requiredHits then
        --print("[HIT_BASED_EVALUATION] Enough allies to destroy quickly - ATTACK")
        return true
    elseif alliesInRange >= math.ceil(requiredHits / 2) then
        local nearbyEnemies = bot:GetNearbyHeroes(600, true, BOT_MODE_NONE)
        if #nearbyEnemies <= 1 then
            --print("[HIT_BASED_EVALUATION] Moderate allied force, low danger - ATTACK")
            return true
        end
    end
    
    --print("[HIT_BASED_EVALUATION] Not enough force or too dangerous - EVACUATE")
    return false
end

function U.GetRequiredHits(threat)
    local threatName = threat:GetUnitName()
    
    if string.find(threatName, "tombstone") then
        return 4
    elseif threatName == "npc_dota_phoenix_sun" then
        return 5
    elseif threatName == "npc_dota_templar_assassin_psionic_trap" then
        return 1
    end
    
    return 3
end

-- Danger zones (ground effects to evacuate from)
function U.GetDangerZone(bot, range)
    local botLocation = bot:GetLocation()
    
    --print("[DANGER_ZONE] Checking for ground-based dangers at bot location")
    
    local dangerModifiers = {
        "modifier_jakiro_macropyre_burn",
        "modifier_invoker_chaos_meteor_burn",
        "modifier_phoenix_sun_debuff",
        "modifier_enigma_midnight_pulse_thinker"
    }
    
    for _, modifier in pairs(dangerModifiers) do
        if bot:HasModifier(modifier) then
            --print("[DANGER_ZONE] Bot has danger modifier: " .. modifier)
            return modifier
        end
    end
    
    return nil
end

-- HP-based threats (wards and similar)
function U.GetHPBasedThreat(bot, range)
    local allUnits = bot:GetNearbyNeutralCreeps(range)
    local enemyCreeps = bot:GetNearbyLaneCreeps(range, true)
    
    for _, creep in pairs(enemyCreeps) do
        table.insert(allUnits, creep)
    end
    
    --print("[HP_BASED_THREAT] Checking " .. #allUnits .. " units for HP-based threats")
    
    for _, unit in pairs(allUnits) do
        if U.IsValidTarget(unit) and unit:GetTeam() ~= bot:GetTeam() then
            local unitName = unit:GetUnitName()
            
            if U.IsHPBasedThreat(unitName) then
                --print("[HP_BASED_THREAT] Found HP-based threat: " .. unitName)
                return unit
            end
        end
    end
    
    return nil
end

function U.IsHPBasedThreat(unitName)
    local hpBasedThreats = {
        "npc_dota_shadow_shaman_ward_1",
        "npc_dota_shadow_shaman_ward_2", 
        "npc_dota_shadow_shaman_ward_3",
        "npc_dota_venomancer_plague_ward_1",
        "npc_dota_venomancer_plague_ward_2",
        "npc_dota_venomancer_plague_ward_3", 
        "npc_dota_venomancer_plague_ward_4",
        --"npc_dota_witch_doctor_death_ward",
        "npc_dota_pugna_nether_ward_1",
        "npc_dota_pugna_nether_ward_2",
        "npc_dota_pugna_nether_ward_3",
        "npc_dota_pugna_nether_ward_4"
		--"npc_dota_juggernaut_healing_ward"
    }
    
    for _, threat in pairs(hpBasedThreats) do
        if unitName == threat then
            return true
        end
    end
    
    return false
end

-- ========================================
-- INTERRUPT SYSTEM
-- ========================================

function U.GetHeroInterruptAbilities()
    return {
        "centaur_hoof_stomp",
        "lion_impale", 
        "lion_voodoo",
        "shadow_shaman_voodoo",
        "sven_storm_bolt",
        "vengefulspirit_magic_missile",
        "dragon_knight_dragon_tail",
        "chaos_knight_chaos_bolt",
        "crystal_maiden_frostbite",
        "bane_nightmare",
        "pudge_dismember",
        "rubick_telekinesis",
        "sand_king_burrowstrike",
        "nyx_assassin_impale",
        "ogre_magi_fireblast",
        "tidehunter_ravage",
        "earthshaker_fissure",
        "witch_doctor_paralyzing_cask"
    }
end

function U.GetHeroInterruptAbilitiesPiercing()
    return {
        "beastmaster_primal_roar",
        "batrider_flaming_lasso", 
        "doom_bringer_doom",
        "enigma_black_hole",
        "faceless_void_chronosphere",
        "legion_commander_duel",
        "magnataur_reverse_polarity",
        "pudge_dismember",
        "tidehunter_ravage",
        "treant_overgrowth"
    }
end

function U.GetItemInterrupts()
    return {
        "item_sheepstick",
        "item_orchid",
        "item_bloodthorn",
        "item_rod_of_atos",
        "item_cyclone",
        "item_abyssal_blade",
        "item_nullifier"
    }
end

function U.GetItemInterruptsPiercing()
    return {
        "item_abyssal_blade"
    }
end

function U.CanInterruptChanneling(bot, enemy)
    --print("[INTERRUPT_CHANNELING] Checking if " .. bot:GetUnitName() .. " can interrupt " .. enemy:GetUnitName())
    
    local targetIsMagicImmune = enemy:IsMagicImmune()
    --print("[INTERRUPT_CHECK] Target magic immune: " .. tostring(targetIsMagicImmune))
    
    local availableInterrupts = {}
    
    if targetIsMagicImmune then
        local piercingAbilities = U.GetHeroInterruptAbilitiesPiercing()
        local piercingItems = U.GetItemInterruptsPiercing()
        
        for _, abilityName in pairs(piercingAbilities) do
            table.insert(availableInterrupts, {name = abilityName, type = "ability"})
        end
        
        for _, itemName in pairs(piercingItems) do
            table.insert(availableInterrupts, {name = itemName, type = "item"})
        end
        
        --print("[INTERRUPT_CHECK] Target is magic immune, checking " .. #availableInterrupts .. " piercing interrupts")
    else
        local regularAbilities = U.GetHeroInterruptAbilities()
        local regularItems = U.GetItemInterrupts()
        
        for _, abilityName in pairs(regularAbilities) do
            table.insert(availableInterrupts, {name = abilityName, type = "ability"})
        end
        
        for _, itemName in pairs(regularItems) do
            table.insert(availableInterrupts, {name = itemName, type = "item"})
        end
        
        --print("[INTERRUPT_CHECK] Target not magic immune, checking " .. #availableInterrupts .. " total interrupts")
    end
    
    for _, interrupt in pairs(availableInterrupts) do
        local success, interruptSource = U.CheckSpecificInterrupt(bot, enemy, interrupt.name, interrupt.type)
        if success then
            --print("[INTERRUPT_CHECK] Found usable interrupt: " .. interrupt.name .. " (" .. interrupt.type .. ")")
            return true, interruptSource
        end
    end
    
    --print("[INTERRUPT_CHECK] No usable interrupts found")
    return false, nil
end

function U.CheckSpecificInterrupt(bot, target, interruptName, interruptType)
    if interruptType == "ability" then
        local ability = bot:GetAbilityByName(interruptName)
        if ability ~= nil and ability:IsFullyCastable() then
            local castRange = ability:GetCastRange()
            local distance = GetUnitToUnitDistance(bot, target)
            
            --print("[INTERRUPT_CHECK] Checking ability " .. interruptName .. " - Range: " .. castRange .. " Distance: " .. distance)
            
            if distance <= castRange + 200 then
                return true, ability
            end
        end
    elseif interruptType == "item" then
        local item = bot:FindItemSlot(interruptName)
        if item ~= -1 then
            local itemObj = bot:GetItemInSlot(item)
            if itemObj ~= nil and itemObj:IsFullyCastable() then
                local castRange = itemObj:GetCastRange()
                local distance = GetUnitToUnitDistance(bot, target)
                
                --print("[INTERRUPT_CHECK] Checking item " .. interruptName .. " - Range: " .. castRange .. " Distance: " .. distance)
                
                if distance <= castRange + 200 then
                    return true, itemObj
                end
            end
        end
    end
    
    return false, nil
end

function U.GetEvacuationLocation(bot, threatLocation)
    local botLocation = bot:GetLocation()
    local fountainLocation = U.GetTeamFountain()
    
    local evacuationDirection = (botLocation - threatLocation):Normalized()
    local evacuationDistance = 800
    local evacuationLocation = botLocation + evacuationDirection * evacuationDistance
    
    --print("[EVACUATION] Moving from threat at " .. tostring(threatLocation))
    
    return evacuationLocation
end

function U.FindPhoenixSun(bot, range)
    local allUnits = {}
    
    -- Try all possible unit detection methods
    local neutrals = bot:GetNearbyNeutralCreeps(range)
    local enemies = bot:GetNearbyLaneCreeps(range, true)
    local heroes = bot:GetNearbyHeroes(range, true, BOT_MODE_NONE)
    local allies = bot:GetNearbyHeroes(range, false, BOT_MODE_NONE)  -- Add allies too
    local towers = bot:GetNearbyTowers(range, true)
    local barracks = bot:GetNearbyBarracks(range, true)
    
    -- Try GetNearbyCreeps (different from GetNearbyNeutralCreeps)
    local creeps = bot:GetNearbyCreeps(range, true)
    
    -- Combine all
    for _, unit in pairs(neutrals) do table.insert(allUnits, unit) end
    for _, unit in pairs(enemies) do table.insert(allUnits, unit) end
    for _, unit in pairs(heroes) do table.insert(allUnits, unit) end
    for _, unit in pairs(allies) do table.insert(allUnits, unit) end
    for _, unit in pairs(towers) do table.insert(allUnits, unit) end
    for _, unit in pairs(barracks) do table.insert(allUnits, unit) end
    for _, unit in pairs(creeps) do table.insert(allUnits, unit) end
    
    --print("[PHOENIX_SEARCH] Searching " .. #allUnits .. " units for Phoenix Sun")
    --print("[PHOENIX_SEARCH] Neutrals: " .. #neutrals .. " Enemies: " .. #enemies .. " Heroes: " .. #heroes)
    --print("[PHOENIX_SEARCH] Allies: " .. #allies .. " Towers: " .. #towers .. " Creeps: " .. #creeps)
    
    for _, unit in pairs(allUnits) do
        if unit ~= nil and unit:IsAlive() then
            local unitName = unit:GetUnitName()
            --print("[PHOENIX_SEARCH] Checking: " .. unitName)
            
            if unitName == "npc_dota_phoenix_sun" then
                --print("[PHOENIX_SEARCH] FOUND Phoenix Sun!")
                return unit
            end
        end
    end
    
    --print("[PHOENIX_SEARCH] Phoenix Sun not found in any category")
    return nil
end

function U.IsEnemyPhoenixSun(bot, phoenixSun)
    -- Look for nearby enemy Phoenix heroes to determine ownership
    local nearbyEnemies = bot:GetNearbyHeroes(1400, true, BOT_MODE_NONE)
    
    for _, enemy in pairs(nearbyEnemies) do
        if enemy:GetUnitName() == "npc_dota_hero_phoenix" then
            -- Check if this Phoenix has the supernova hiding modifier
            if enemy:HasModifier("modifier_phoenix_supernova_hiding") then
                --print("[PHOENIX_OWNERSHIP] Found enemy Phoenix with supernova hiding modifier")
                return true
            end
        end
    end
    
    -- Also check if the bot itself has the phoenix sun debuff (meaning it's in enemy supernova)
    if bot:HasModifier("modifier_phoenix_sun_debuff") then
        --print("[PHOENIX_OWNERSHIP] Bot has phoenix sun debuff, must be enemy supernova")
        return true
    end
    
    return false
end

function U.FindChannelingPhoenix(bot, range)
    local nearbyEnemies = bot:GetNearbyHeroes(range, true, BOT_MODE_NONE)
    
    for _, enemy in pairs(nearbyEnemies) do
        if enemy:GetUnitName() == "npc_dota_hero_phoenix" and enemy:HasModifier("modifier_phoenix_supernova_hiding") then
            --print("[PHOENIX_SEARCH] Found Phoenix with supernova hiding modifier")
            return enemy
        end
    end
    
    return nil
end

function U.FindPhoenixInSupernova(bot, range)
    local nearbyEnemies = bot:GetNearbyHeroes(range, true, BOT_MODE_NONE)
    
    --print("[PHOENIX_SUPERNOVA] Searching for Phoenix in " .. #nearbyEnemies .. " nearby enemies")
    
    for _, enemy in pairs(nearbyEnemies) do
        local enemyName = enemy:GetUnitName()
        local hasHidingModifier = enemy:HasModifier("modifier_phoenix_supernova_hiding")
        
        --print("[PHOENIX_SUPERNOVA] Checking enemy: " .. enemyName .. " - Has hiding modifier: " .. tostring(hasHidingModifier))
        
        if enemyName == "npc_dota_hero_phoenix" and hasHidingModifier then
            --print("[PHOENIX_SUPERNOVA] Found Phoenix in supernova mode")
            return enemy
        end
    end
    
    --print("[PHOENIX_SUPERNOVA] Phoenix not found")
    return nil
end



-- ========================================
-- CHAIN FROST DISPERSION SYSTEM  
-- ========================================

-- Chain Frost threat detection and dispersion
function U.GetChainFrostThreat(bot, range)
    if range == nil then range = 1200 end
    
    --print(("[CHAIN_FROST_THREAT] " .. bot:GetUnitName() .. " - Checking for Chain Frost threats in range " .. range)
    
    -- Get all nearby allies (including bot itself)
    local nearbyAllies = bot:GetNearbyHeroes(range, false, BOT_MODE_NONE)
    table.insert(nearbyAllies, bot) -- Include self in check
    
    --print(("[CHAIN_FROST_THREAT] Checking " .. #nearbyAllies .. " allies for Chain Frost modifier")
    
    for _, ally in pairs(nearbyAllies) do
        if ally:IsAlive() and ally:HasModifier("modifier_lich_chainfrost_slow") then
            --print(("[CHAIN_FROST_THREAT] FOUND ally with Chain Frost: " .. ally:GetUnitName())
            
            -- Check if current bot should disperse (within bounce range of hit ally)
            local distanceToHitAlly = GetUnitToUnitDistance(bot, ally)
            local bounceRange = 600 -- Typical Chain Frost bounce range
            
            --print(("[CHAIN_FROST_THREAT] Distance to hit ally: " .. distanceToHitAlly .. " (bounce range: " .. bounceRange .. ")")
            
            if ally == bot then
                -- Bot itself was hit - needs to move away from other allies
                --print(("[CHAIN_FROST_THREAT] Bot itself was hit by Chain Frost - dispersing from allies")
                return ally, "chain_frost_self_hit", bounceRange
            elseif distanceToHitAlly <= bounceRange + 200 then
                -- Bot is close enough to be a bounce target
                --print(("[CHAIN_FROST_THREAT] Bot is within bounce range of hit ally - dispersing")
                return ally, "chain_frost_dispersion", bounceRange
            else
                --print(("[CHAIN_FROST_THREAT] Bot is outside bounce range, no dispersion needed")
            end
        end
    end
    
    --print(("[CHAIN_FROST_THREAT] No Chain Frost threats detected")
    return nil, nil, nil
end

-- Calculate safe dispersion location away from Chain Frost
function U.GetChainFrostDispersionLocation(bot, hitAlly, bounceRange)
    local botLocation = bot:GetLocation()
    local hitAllyLocation = hitAlly:GetLocation()
    
    --print(("[CHAIN_FROST_DISPERSION] Calculating dispersion for " .. bot:GetUnitName() .. " away from " .. hitAlly:GetUnitName()))
    
    local awayDirection = nil
    
    -- If bot was hit by Chain Frost (hitAlly == bot), we need special logic
    if hitAlly == bot then
        --print(("[CHAIN_FROST_DISPERSION] Bot was hit - finding direction away from other allies"))
        
        -- Find all nearby allies to move away from
        local nearbyAllies = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE)
        
        if #nearbyAllies > 0 then
            -- Calculate center of mass of nearby allies
            local allyCenter = Vector(0, 0, 0)
            local validAllies = 0
            
            for _, ally in pairs(nearbyAllies) do
                if ally ~= bot and ally:IsAlive() then
                    allyCenter = allyCenter + ally:GetLocation()
                    validAllies = validAllies + 1
                    --print(("[CHAIN_FROST_DISPERSION] Found nearby ally: " .. ally:GetUnitName() .. " at " .. tostring(ally:GetLocation())))
                end
            end
            
            if validAllies > 0 then
                allyCenter = allyCenter / validAllies
                awayDirection = (botLocation - allyCenter):Normalized()
                --print(("[CHAIN_FROST_DISPERSION] Moving away from ally center: " .. tostring(allyCenter)))
                --print(("[CHAIN_FROST_DISPERSION] Initial away direction: " .. tostring(awayDirection)))
            else
                --print(("[CHAIN_FROST_DISPERSION] No valid allies found, using random direction"))
                -- FIXED: Use proper Dota 2 random function
                local randomAngle = RandomInt(0, 359) * math.pi / 180
                awayDirection = Vector(math.cos(randomAngle), math.sin(randomAngle), 0):Normalized()
            end
        else
            --print(("[CHAIN_FROST_DISPERSION] No allies nearby, using random direction"))
            -- FIXED: Use proper Dota 2 random function
            local randomAngle = RandomInt(0, 359) * math.pi / 180
            awayDirection = Vector(math.cos(randomAngle), math.sin(randomAngle), 0):Normalized()
        end
        
        -- DETERMINISTIC DIRECTION ASSIGNMENT based on bot's player ID
        local playerID = bot:GetPlayerID()
        local angleOffset = playerID * 72  -- 72 degrees apart (360/5 = 72 for 5 players)
        
        --print(("[CHAIN_FROST_DISPERSION] Bot PlayerID: " .. playerID .. " - Angle offset: " .. angleOffset .. " degrees"))
        
        -- Convert to radians
        local angleRad = angleOffset * math.pi / 180
        
        -- Create deterministic direction based on player ID
        local deterministicDirection = Vector(math.cos(angleRad), math.sin(angleRad), 0):Normalized()
        
        -- If we have a good "away from center" direction, blend it with deterministic direction
        if awayDirection and awayDirection:Length2D() > 0.1 then
            -- Blend the directions (70% away from center, 30% deterministic)
            awayDirection = (awayDirection * 0.7 + deterministicDirection * 0.3):Normalized()
            --print(("[CHAIN_FROST_DISPERSION] Blended direction - Away: 70%, Deterministic: 30%"))
        else
            -- Use pure deterministic direction
            awayDirection = deterministicDirection
            --print(("[CHAIN_FROST_DISPERSION] Using pure deterministic direction"))
        end
        
        --print(("[CHAIN_FROST_DISPERSION] Final direction: " .. tostring(awayDirection)))
        
    else
        -- Bot is dispersing away from a different hit ally
        awayDirection = (botLocation - hitAllyLocation):Normalized()
        --print(("[CHAIN_FROST_DISPERSION] Moving away from hit ally: " .. hitAlly:GetUnitName()))
    end
    
    -- If direction calculation still failed, use fountain direction as fallback
    if awayDirection:Length2D() < 0.1 then
        local fountainLocation = U.GetTeamFountain()
        if fountainLocation then
            local fountainDirection = (fountainLocation - botLocation):Normalized()
            awayDirection = fountainDirection
            --print(("[CHAIN_FROST_DISPERSION] Direction calculation failed, using fountain direction"))
        else
            -- Final fallback if fountain location fails
            local playerID = bot:GetPlayerID()
            local angleOffset = playerID * 72
            local angleRad = angleOffset * math.pi / 180
            awayDirection = Vector(math.cos(angleRad), math.sin(angleRad), 0):Normalized()
            --print(("[CHAIN_FROST_DISPERSION] Using player ID based direction as final fallback"))
        end
    end
    
    -- Move to safe distance (bounce range + safety margin)
    local safeDistance = bounceRange + 300
    local disperseLocation = botLocation + awayDirection * safeDistance
    
    --print(("[CHAIN_FROST_DISPERSION] Moving " .. safeDistance .. " units in direction: " .. tostring(awayDirection)))
    --print(("[CHAIN_FROST_DISPERSION] From: " .. tostring(botLocation) .. " To: " .. tostring(disperseLocation)))
    
    -- Ensure location is valid/passable, if not try shorter distance
    local attemptCount = 0
    local maxAttempts = 4
    
    while not IsLocationPassable(disperseLocation) and attemptCount < maxAttempts do
        attemptCount = attemptCount + 1
        --print(("[CHAIN_FROST_DISPERSION] Attempt " .. attemptCount .. " - Location not passable, trying alternative"))
        
        if attemptCount == 1 then
            -- Try shorter distance
            disperseLocation = botLocation + awayDirection * (bounceRange + 150)
        elseif attemptCount == 2 then
            -- Try perpendicular direction (90 degrees)
            local perpDirection = Vector(-awayDirection.y, awayDirection.x, 0):Normalized()
            disperseLocation = botLocation + perpDirection * (bounceRange + 200)
            --print(("[CHAIN_FROST_DISPERSION] Trying perpendicular direction: " .. tostring(perpDirection)))
        elseif attemptCount == 3 then
            -- Try opposite perpendicular direction (-90 degrees)
            local perpDirection = Vector(awayDirection.y, -awayDirection.x, 0):Normalized()
            disperseLocation = botLocation + perpDirection * (bounceRange + 200)
            --print(("[CHAIN_FROST_DISPERSION] Trying opposite perpendicular direction: " .. tostring(perpDirection)))
        else
            -- Final fallback - fountain direction
            local fountainLocation = U.GetTeamFountain()
            if fountainLocation then
                local fountainDirection = (fountainLocation - botLocation):Normalized()
                disperseLocation = botLocation + fountainDirection * 400
                --print(("[CHAIN_FROST_DISPERSION] Using fountain direction as final fallback"))
            else
                -- Use current location + small offset as absolute final fallback
                disperseLocation = botLocation + Vector(200, 200, 0)
                --print(("[CHAIN_FROST_DISPERSION] Using location offset as absolute final fallback"))
            end
        end
    end
    
    if attemptCount > 0 then
        --print(("[CHAIN_FROST_DISPERSION] Final location after " .. attemptCount .. " attempts: " .. tostring(disperseLocation)))
    end
    
    return disperseLocation
end

return U;