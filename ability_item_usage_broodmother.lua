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

local castSSDesire = 0;
local castSWDesire = 0;
local castSBDesire = 0;
local castIHDesire = 0;
local castSTDesire = 0;

local abilityST = nil;
local abilitySS = nil;
local abilitySW = nil;
local abilitySB = nil;
local abilityIH = nil;

local cast = false;
local timeCast = 0;
local npcBot = nil;

function AbilityUsageThink()

	if npcBot == nil then npcBot = GetBot(); end
	
	-- Check if we're already using an ability
	if mutil.CanNotUseAbility(npcBot) then return end

	-- Initialize abilities by name (more reliable)
	if abilitySS == nil then abilitySS = npcBot:GetAbilityByName("broodmother_spawn_spiderlings"); end
	if abilitySW == nil then abilitySW = npcBot:GetAbilityByName("broodmother_spin_web"); end
	if abilityIH == nil then abilityIH = npcBot:GetAbilityByName("broodmother_insatiable_hunger"); end
	if abilityST == nil then abilityST = npcBot:GetAbilityByName("broodmother_sticky_snare"); end

	-- Consider using each ability
	castSSDesire, castSSTarget = ConsiderSpawnSpiderlings();
	castSWDesire, castSWLocation = ConsiderSpinWeb();
	castIHDesire = ConsiderInsatiableHunger();
	castSTDesire, castSTLocation = ConsiderStickySnare();

	-- Add to debug
	if npcBot:GetUnitName() == "npc_dota_hero_broodmother" then
		--print("[BM] SS:" .. castSSDesire .. " SW:" .. castSWDesire .. " IH:" .. castIHDesire .. " ST:" .. castSTDesire);
	end
	
	if ( castSTDesire > 0 ) 
	then
		--print("[BM] Using Sticky Snare");
		npcBot:Action_UseAbilityOnLocation( abilityST, castSTLocation );
		return;
	end
	
	if ( castIHDesire > 0 ) 
	then
		--print("[BM] Using Insatiable Hunger");
		npcBot:Action_UseAbility( abilityIH );
		return;
	end
	
	if ( castSSDesire > 0 ) 
	then
		--print("[BM] Using Spawn Spiderlings on " .. castSSTarget:GetUnitName());
		npcBot:Action_UseAbilityOnEntity( abilitySS, castSSTarget );
		return;
	end
	
	if ( castSWDesire > 0 and DotaTime() >= timeCast + 0.8 ) 
	then
		--print("[BM] Placing Spin Web");
		npcBot:Action_UseAbilityOnLocation( abilitySW, castSWLocation );
		timeCast = DotaTime();
		return;
	end
	
end

function LocationOverlapWeb(location, nRadius)
	local flag = ( 1.5*nRadius ) + 150;
	local unit = GetUnitList(UNIT_LIST_ALLIES);
	for _,u in pairs (unit)
	do
		if u:GetUnitName() == "npc_dota_broodmother_web"
		then
			if GetUnitToLocationDistance(u, location) <= flag then
				return true
			end
		end
	end
	return false;
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

function ConsiderSpawnSpiderlings()

	-- Make sure it's castable
	if ( not abilitySS:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	-- Get some of its values
	local nCastRange = abilitySS:GetCastRange();
	local nDamage = abilitySS:GetSpecialValueInt("damage");
	local manaPercent = npcBot:GetMana() / npcBot:GetMaxMana();

	-- INTERRUPT: Channeling enemies
	local enemies = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);
	for _, enemy in pairs(enemies) do
		if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
			return BOT_ACTION_DESIRE_HIGH, enemy;
		end
	end

	-- KILL SECURING: If we can kill a target
	local npcTarget = npcBot:GetTarget();
	if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) 
		and mutil.CanKillTarget(npcTarget, nDamage, DAMAGE_TYPE_MAGICAL) 
		and mutil.IsInRange(npcTarget, npcBot, nCastRange + 200) then
		return BOT_ACTION_DESIRE_HIGH, npcTarget;
	end

	-- AGGRESSIVE: Use on hero targets for slow
	if mutil.IsGoingOnSomeone(npcBot) then
		local target = npcBot:GetTarget();
		if mutil.IsValidTarget(target) and mutil.CanCastOnNonMagicImmune(target) 
			and mutil.IsInRange(target, npcBot, nCastRange + 200) then
			return BOT_ACTION_DESIRE_MODERATE, target;
		end
	end

	-- FARMING: Use on creeps for last hits and spiderlings
	if (npcBot:GetActiveMode() == BOT_MODE_LANING or mutil.IsDefending(npcBot) or mutil.IsPushing(npcBot)) 
		and manaPercent > 0.4 then
		local tableNearbyEnemyCreeps = npcBot:GetNearbyLaneCreeps(nCastRange + 200, true);
		for _, creep in pairs(tableNearbyEnemyCreeps) do
			if mutil.CanKillTarget(creep, nDamage, DAMAGE_TYPE_MAGICAL) then
				return BOT_ACTION_DESIRE_MODERATE, creep;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;
end

function ConsiderSpinWeb()

	-- Make sure it's castable
	if ( not abilitySW:IsFullyCastable() or npcBot:IsCastingAbility() or abilitySW:IsInAbilityPhase() ) 
	then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	-- Get some of its values
	local nRadius = abilitySW:GetSpecialValueInt( "radius" );
	local nCastRange = 900;
	local nCastPoint = abilitySW:GetCastPoint( );
	
	-- PRIORITY 1: Always place web when laning and no web at current location
	if npcBot:GetActiveMode() == BOT_MODE_LANING then
		if not LocationOverlapWeb(npcBot:GetLocation(), nRadius) then
			return BOT_ACTION_DESIRE_VERYHIGH, npcBot:GetLocation();
		end
		
		-- Also place web slightly ahead in lane direction for movement
		local laneWaypoint = npcBot:GetNextRouteWaypoint();
		if laneWaypoint ~= nil and GetUnitToLocationDistance(npcBot, laneWaypoint) > 300 then
			local forwardLoc = npcBot:GetXUnitsTowardsLocation(laneWaypoint, 400);
			if not LocationOverlapWeb(forwardLoc, nRadius) then
				return BOT_ACTION_DESIRE_HIGH, forwardLoc;
			end
		end
	end
	
	-- PRIORITY 2: Stuck or need pathing
	if mutil.IsStuck(npcBot) then
		return BOT_ACTION_DESIRE_VERYHIGH, npcBot:GetLocation();
	end
	
	-- PRIORITY 3: Retreating - place web towards fountain
	if mutil.IsRetreating(npcBot) then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes ) do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) and 
				not LocationOverlapWeb(GetTowardsFountainLocation( npcBot:GetLocation(), nCastRange ), nRadius) ) 
			then
				return BOT_ACTION_DESIRE_HIGH, GetTowardsFountainLocation( npcBot:GetLocation(), nCastRange );
			end
		end
	end

	-- PRIORITY 4: Chasing someone - place web ahead of target
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) then
			local targetLoc = npcTarget:GetExtrapolatedLocation( nCastPoint );
			if not LocationOverlapWeb(targetLoc, nRadius) then
				return BOT_ACTION_DESIRE_HIGH, targetLoc;
			end
		end
	end

	-- PRIORITY 5: Pushing - place web for farming efficiency
	if mutil.IsPushing(npcBot) then
		local lanecreeps = npcBot:GetNearbyLaneCreeps(nCastRange, true);
		local NearbyTower = npcBot:GetNearbyTowers(nRadius, true);
		local locationAoE = npcBot:FindAoELocation( true, false, npcBot:GetLocation(), nCastRange, nRadius / 3, 0, 0 );
		
		if locationAoE.count >= 3 and #lanecreeps >= 3 and not LocationOverlapWeb(locationAoE.targetloc, nRadius) then
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
		end
		
		if NearbyTower[1] ~= nil and not NearbyTower[1]:IsInvulnerable() and 
			not LocationOverlapWeb(NearbyTower[1]:GetLocation(), nRadius) then
			return BOT_ACTION_DESIRE_MODERATE, NearbyTower[1]:GetLocation();
		end
		
		-- Place web at current location if pushing and no web here
		if not LocationOverlapWeb(npcBot:GetLocation(), nRadius) then
			return BOT_ACTION_DESIRE_MODERATE, npcBot:GetLocation();
		end
	end
	
	-- PRIORITY 6: Defending
	if mutil.IsDefending(npcBot) then
		local NearbyTower = npcBot:GetNearbyTowers(nRadius, false);
		if NearbyTower[1] ~= nil and not NearbyTower[1]:IsInvulnerable() and 
			not LocationOverlapWeb(NearbyTower[1]:GetLocation(), nRadius) then
			return BOT_ACTION_DESIRE_MODERATE, NearbyTower[1]:GetLocation();
		end
		
		-- Place web at current location if defending and no web here
		if not LocationOverlapWeb(npcBot:GetLocation(), nRadius) then
			return BOT_ACTION_DESIRE_MODERATE, npcBot:GetLocation();
		end
	end
	
	-- PRIORITY 7: General movement - always try to have web where we are
	local manaPercent = npcBot:GetMana() / npcBot:GetMaxMana();
	if manaPercent > 0.6 and not LocationOverlapWeb(npcBot:GetLocation(), nRadius) then
		return BOT_ACTION_DESIRE_LOW, npcBot:GetLocation();
	end

	return BOT_ACTION_DESIRE_NONE, 0;
end


function ConsiderInsatiableHunger()

	-- Make sure it's castable
	if ( not abilityIH:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local nAttackRange = npcBot:GetAttackRange();
	
	-- AGGRESSIVE: Use when going after someone
	if mutil.IsGoingOnSomeone(npcBot) then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nAttackRange + 200) then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end
	
	-- TEAMFIGHT: Use when enemies nearby
	if mutil.IsInTeamFight(npcBot, 1200) then
		local nearbyEnemies = npcBot:GetNearbyHeroes(nAttackRange + 200, true, BOT_MODE_NONE);
		if #nearbyEnemies > 0 then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end
	
	-- FARMING: Use when attacking creeps if low health (for lifesteal)
	if npcBot:GetActiveMode() == BOT_MODE_FARM or mutil.IsPushing(npcBot) then
		local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
		if healthPercent < 0.7 then
			local nearbyCreeps = npcBot:GetNearbyCreeps(nAttackRange + 100, true);
			if #nearbyCreeps > 0 then
				return BOT_ACTION_DESIRE_MODERATE;
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE;
end


function ConsiderStickySnare()

    -- Check if we have scepter and ability exists
    if not npcBot:HasScepter() or abilityST == nil or not abilityST:IsFullyCastable() then 
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityST:GetCastRange();
    local nWidth = abilityST:GetSpecialValueInt("width");
    local nRootDuration = abilityST:GetSpecialValueFloat("root_duration");
    
    -- Function to check if location has existing snare
    local function HasStickySnareAtLocation(location, checkRadius)
        local nearbyUnits = GetUnitList(UNIT_LIST_ALL);
        for _, unit in pairs(nearbyUnits) do
            if unit:HasModifier("modifier_broodmother_sticky_snare") then
                if GetUnitToLocationDistance(unit, location) <= checkRadius then
                    return true;
                end
            end
        end
        return false;
    end
    
    -- INTERRUPT: Channeling enemies (highest priority)
    local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
            local targetLoc = enemy:GetLocation();
            if not HasStickySnareAtLocation(targetLoc, nWidth/2) then
                return BOT_ACTION_DESIRE_VERYHIGH, targetLoc;
            end
        end
    end
    
    -- TEAMFIGHT: Multi-target scenarios
    if mutil.IsInTeamFight(npcBot, 1200) then
        local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nWidth/2, 2.0, 0);
        if locationAoE.count >= 2 and not HasStickySnareAtLocation(locationAoE.targetloc, nWidth/2) then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end
    
    -- RETREATING: Block pursuers
    if mutil.IsRetreating(npcBot) and npcBot:WasRecentlyDamagedByAnyHero(3.0) then
        local nearbyEnemies = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
        if #nearbyEnemies > 0 then
            -- Place snare between us and closest enemy
            local closestEnemy = nearbyEnemies[1];
            local botLoc = npcBot:GetLocation();
            local enemyLoc = closestEnemy:GetLocation();
            local midPoint = (botLoc + enemyLoc) * 0.5;
            
            if not HasStickySnareAtLocation(midPoint, nWidth/2) and 
               GetUnitToLocationDistance(npcBot, midPoint) <= nCastRange then
                return BOT_ACTION_DESIRE_HIGH, midPoint;
            end
        end
    end
    
    -- AGGRESSIVE: Root target when going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.CanCastOnNonMagicImmune(target) then
            local targetLoc = target:GetExtrapolatedLocation(2.0); -- Account for formation delay
            if mutil.IsInRange(target, npcBot, nCastRange) and 
               not HasStickySnareAtLocation(targetLoc, nWidth/2) then
                return BOT_ACTION_DESIRE_HIGH, targetLoc;
            end
        end
    end
    
    -- CONTROL: Block enemy escape routes near objectives
    if mutil.IsPushing(npcBot) or mutil.IsDefending(npcBot) then
        local nearbyTowers = npcBot:GetNearbyTowers(800, true);
        local nearbyEnemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        
        if #nearbyTowers > 0 and #nearbyEnemies > 0 then
            local tower = nearbyTowers[1];
            local enemy = nearbyEnemies[1];
            -- Place snare to cut off enemy escape from tower
            local blockLoc = enemy:GetLocation() + (enemy:GetLocation() - tower:GetLocation()):Normalized() * 200;
            
            if not HasStickySnareAtLocation(blockLoc, nWidth/2) and 
               GetUnitToLocationDistance(npcBot, blockLoc) <= nCastRange then
                return BOT_ACTION_DESIRE_MODERATE, blockLoc;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end


