if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

-- Global variables
local npcBot = nil;
local abilityBS = nil;  -- Boundless Strike (Q)
local abilityTD = nil;  -- Tree Dance (W)
local abilityPS = nil;  -- Primal Spring (E)
local abilityJM = nil;  -- Jingu Mastery (D - Passive)
local abilityMC = nil;  -- Mischief (F)
local abilityWC = nil;  -- Wukong's Command (R)
local abilityPSE = nil; -- Primal Spring Early
local abilityUT = nil;  -- Untransform

-- State management for universal fixes
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Monkey King specific state
local PSLoc = nil;
local WCLoc = nil;
local castWCTime = -90;
local lastMischiefTime = 0;
local springChannelStartTime = 0;
local boundlessStrikeAltCast = false; -- Track alt-cast mode for shard

-- Think function protection
function AbilityLevelUpThink()  
    if isRecoveringFromDeath then return; end
    ability_item_usage_generic.AbilityLevelUpThink(); 
end

function BuybackUsageThink()
    if isRecoveringFromDeath then return; end
    ability_item_usage_generic.BuybackUsageThink();
end

function CourierUsageThink()
    if isRecoveringFromDeath then return; end
    ability_item_usage_generic.CourierUsageThink();
end

function ItemUsageThink()
    if isRecoveringFromDeath then return; end
    ability_item_usage_generic.ItemUsageThink();
end

function AbilityUsageThink()
    if npcBot == nil then npcBot = GetBot(); end
    
    -- UNIVERSAL FOUNTAIN STUCK FIX
    local distanceFromFountain = npcBot:DistanceFromFountain();
    local botLevel = npcBot:GetLevel();
    
    if distanceFromFountain <= 100 and botLevel >= 1 and DotaTime() > 10 then
        npcBot:Action_ClearActions(false);
        local escapeLocation = nil;
        if GetTeam() == TEAM_RADIANT then
            escapeLocation = Vector(-6000, -6000, 0);
        else
            escapeLocation = Vector(6000, 6000, 0);
        end
        if escapeLocation ~= nil then
            npcBot:Action_MoveToLocation(escapeLocation);
            return;
        end
    end
    
    -- DEATH RECOVERY SYSTEM
    if not npcBot:IsAlive() then
        lastDeathTime = DotaTime();
        isRecoveringFromDeath = true;
        return;
    end
    
    if isRecoveringFromDeath and DotaTime() - lastDeathTime < postDeathCooldown then
        if distanceFromFountain < 300 then
            npcBot:Action_ClearActions(false);
            local escapeLocation = nil;
            if GetTeam() == TEAM_RADIANT then
                escapeLocation = Vector(-6000, -6000, 0);
            else
                escapeLocation = Vector(6000, 6000, 0);
            end
            if escapeLocation ~= nil then
                npcBot:Action_MoveToLocation(escapeLocation);
            end
        end
        return;
    elseif isRecoveringFromDeath then
        isRecoveringFromDeath = false;
    end

    -- Clean up old WC location
    if WCLoc ~= nil and DotaTime() > castWCTime + 14 then
        WCLoc = nil;
    end

    -- Initialize abilities by name (RECOMMENDED approach)
    if abilityBS == nil then abilityBS = npcBot:GetAbilityByName("monkey_king_boundless_strike"); end
    if abilityTD == nil then abilityTD = npcBot:GetAbilityByName("monkey_king_tree_dance"); end
    if abilityPS == nil then abilityPS = npcBot:GetAbilityByName("monkey_king_primal_spring"); end
    if abilityJM == nil then abilityJM = npcBot:GetAbilityByName("monkey_king_jingu_mastery"); end
    if abilityMC == nil then abilityMC = npcBot:GetAbilityByName("monkey_king_mischief"); end
    if abilityWC == nil then abilityWC = npcBot:GetAbilityByName("monkey_king_wukongs_command"); end
    if abilityPSE == nil then abilityPSE = npcBot:GetAbilityByName("monkey_king_primal_spring_early"); end
    if abilityUT == nil then abilityUT = npcBot:GetAbilityByName("monkey_king_untransform"); end

    -- Protect channeling (Primal Spring)
    if mutil.SafeIsChanneling(npcBot) then
        -- Handle Primal Spring early release
        local castPSEDesire = ConsiderPrimalSpringEarly();
        if castPSEDesire > 0 and abilityPSE ~= nil and abilityPSE:IsFullyCastable() then
            npcBot:Action_UseAbility(abilityPSE);
        end
        return; -- Don't interrupt channeling with other actions
    end
    
    -- Check if we're already using an ability
    if mutil.CanNotUseAbility(npcBot) then return end

    -- PRIORITY ORDER: Emergency -> Combo -> Offensive -> Defensive -> Utility

    -- 1. EMERGENCY: Mischief for projectile disjoint (highest priority)
    local castMCDesire = ConsiderMischief();
    if castMCDesire > 0 then
        npcBot:Action_UseAbility(abilityMC);
        lastMischiefTime = DotaTime();
        return;
    end

    -- 2. EMERGENCY: Untransform after mischief
    local castUTDesire = ConsiderUntransform();
    if castUTDesire > 0 then
        npcBot:Action_UseAbility(abilityUT);
        return;
    end

    -- 3. ULTIMATE: Wukong's Command in teamfights
    local castWCDesire, castWCLocation = ConsiderWukongCommand();
    if castWCDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilityWC, castWCLocation);
        WCLoc = castWCLocation;
        castWCTime = DotaTime();
        return;
    end

    -- 4. COMBO: Tree Dance for positioning/escape
    local castTDDesire, castTDTarget = ConsiderTreeDance();
    if castTDDesire > 0 then
        npcBot:Action_UseAbilityOnTree(abilityTD, castTDTarget);
        return;
    end

    -- 5. COMBO: Primal Spring from tree
    local castPSDesire, castPSLocation = ConsiderPrimalSpring();
    if castPSDesire > 0 then
        PSLoc = castPSLocation;
        springChannelStartTime = DotaTime();
        npcBot:Action_UseAbilityOnLocation(abilityPS, castPSLocation);
        return;
    end

    -- 6. OFFENSIVE: Boundless Strike for stun/damage
    local castBSDesire, castBSLocation = ConsiderBoundlessStrike();
    if castBSDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilityBS, castBSLocation);
        return;
    end
end

function ConsiderBoundlessStrike()
    if not abilityBS or not abilityBS:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityBS:GetCastRange();
    local nCastPoint = abilityBS:GetCastPoint();
    local nStunDuration = abilityBS:GetSpecialValueFloat("stun_duration");

    -- INTERRUPT: Channeling enemies (highest priority)
    local enemies = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_HIGH, enemy:GetExtrapolatedLocation(nCastPoint);
        end
    end

    -- JINGU MASTERY: Enhanced damage when we have charges
    if npcBot:HasModifier('modifier_monkey_king_jingu_mastery') then
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnNonMagicImmune(enemy) and mutil.IsInRange(enemy, npcBot, nCastRange - 100) then
                return BOT_ACTION_DESIRE_HIGH, enemy:GetExtrapolatedLocation(nCastPoint);
            end
        end
    end

    -- TEAMFIGHT: Multi-target stuns
    if mutil.IsInTeamFight(npcBot, 1200) then
        local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, 200, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end

    -- OFFENSIVE: Going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.CanCastOnNonMagicImmune(target) then
            if mutil.IsInRange(target, npcBot, nCastRange - 100) then
                return BOT_ACTION_DESIRE_MODERATE, target:GetExtrapolatedLocation(nCastPoint);
            end
        end
    end

    -- DEFENSIVE: Retreating - stun pursuers
    if mutil.IsRetreating(npcBot) then
        for _, enemy in pairs(enemies) do
            if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) and mutil.IsInRange(enemy, npcBot, nCastRange) then
                return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation();
            end
        end
    end

    -- SHARD: Alt-cast for gap closing (if we have shard)
    if HasShard() and mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and GetUnitToUnitDistance(npcBot, target) > 600 then
            -- Use alt-cast to leap to target location
            boundlessStrikeAltCast = true;
            return BOT_ACTION_DESIRE_MODERATE, target:GetLocation();
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTreeDance()
    if not abilityTD or not abilityTD:IsFullyCastable() or npcBot:IsRooted() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityTD:GetCastRange();
    local trees = npcBot:GetNearbyTrees(nCastRange);
    
    if not trees or #trees == 0 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- ESCAPE: High priority when retreating
    if mutil.IsRetreating(npcBot) then
        local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies >= 1 and npcBot:DistanceFromFountain() > 1000 then
            -- Find tree furthest from enemies
            local bestTree = GetBestEscapeTree(trees, enemies);
            if bestTree then
                return BOT_ACTION_DESIRE_HIGH, bestTree;
            end
        end
    end

    -- OFFENSIVE: Position for Primal Spring combo
    if mutil.IsGoingOnSomeone(npcBot) and abilityPS and abilityPS:IsFullyCastable() then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.CanCastOnNonMagicImmune(target) then
            -- Find tree near target for combo
            local targetTrees = target:GetNearbyTrees(600);
            if targetTrees and #targetTrees > 0 then
                -- Respect Wukong Command area if active
                local bestTree = GetBestOffensiveTree(targetTrees, target);
                if bestTree then
                    return BOT_ACTION_DESIRE_MODERATE, bestTree;
                end
            end
        end
    end

    -- VISION: Get high ground vision
    if not mutil.IsRetreating(npcBot) and not mutil.IsGoingOnSomeone(npcBot) then
        local enemies = npcBot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        if #enemies > 0 then
            -- Find highest tree for vision
            local visionTree = GetBestVisionTree(trees);
            if visionTree then
                return BOT_ACTION_DESIRE_LOW, visionTree;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderPrimalSpring()
    if not abilityPS or not abilityPS:IsFullyCastable() or abilityPS:IsHidden() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Only castable when on a tree
    local nearbyTrees = npcBot:GetNearbyTrees(50);
    if not nearbyTrees or #nearbyTrees == 0 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityPS:GetCastRange();
    local nRadius = abilityPS:GetSpecialValueInt("impact_radius");
    local nDamage = abilityPS:GetSpecialValueInt("impact_damage");

    -- ESCAPE: Jump to safety when retreating
    if mutil.IsRetreating(npcBot) then
        local enemies = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
        if #enemies >= 1 then
            local escapeLocation = GetEscapeLocation(nCastRange);
            if escapeLocation then
                return BOT_ACTION_DESIRE_HIGH, escapeLocation;
            end
        end
    end

    -- TEAMFIGHT: AoE damage
    if mutil.IsInTeamFight(npcBot, 1200) then
        local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end

    -- OFFENSIVE: Hunt down target
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.CanCastOnNonMagicImmune(target) then
            local targetDistance = GetUnitToUnitDistance(npcBot, target);
            if targetDistance <= nCastRange then
                -- Predict target location based on movement
                local targetLocation = target:GetLocation();
                if target:GetMovementDirectionStability() > 0.8 and target:GetCurrentMovementSpeed() > 0 then
                    -- Target is moving predictably
                    targetLocation = target:GetExtrapolatedLocation(1.75); -- Channel time
                end
                return BOT_ACTION_DESIRE_HIGH, targetLocation;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderPrimalSpringEarly()
    if not abilityPSE or not abilityPSE:IsFullyCastable() or abilityPSE:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Only available when channeling Primal Spring
    if not mutil.SafeIsChanneling(npcBot) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local channelTime = DotaTime() - springChannelStartTime;
    local maxChannelTime = 1.75;
    
    -- EMERGENCY: Release early if target is escaping
    if mutil.IsGoingOnSomeone(npcBot) and PSLoc then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) then
            local targetDistance = GetUnitToLocationDistance(target, PSLoc);
            local impactRadius = 375;
            
            -- Release if target is about to escape impact area
            if targetDistance > impactRadius - 100 then
                return BOT_ACTION_DESIRE_HIGH;
            end
            
            -- Release if target is low HP and minimum damage is enough
            local targetHealth = target:GetHealth();
            if targetHealth <= 200 and channelTime >= 0.5 then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    -- EMERGENCY: Release if taking damage while channeling
    if npcBot:WasRecentlyDamagedByAnyHero(1.0) then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        if healthPercent < 0.4 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- AUTO: Release near max channel time for maximum damage
    if channelTime >= maxChannelTime * 0.9 then
        return BOT_ACTION_DESIRE_MODERATE;
    end

    -- ESCAPE: Quick release when retreating
    if mutil.IsRetreating(npcBot) and channelTime >= 0.3 then
        return BOT_ACTION_DESIRE_MODERATE;
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderMischief()
    if not abilityMC or not abilityMC:IsFullyCastable() or abilityMC:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Don't use if recently used (cooldown management)
    if DotaTime() - lastMischiefTime < 2.0 then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- PROJECTILE DISJOINT: Detect incoming projectiles
    local incomingProjectiles = npcBot:GetIncomingTrackingProjectiles();
    if incomingProjectiles and #incomingProjectiles > 0 then
        for _, projectile in pairs(incomingProjectiles) do
            -- Projectile structure: { location, caster, player, ability, is_dodgeable, is_attack }
            local projectileLocation = projectile[1];  -- location
            local projectileCaster = projectile[2];    -- caster
            local projectilePlayer = projectile[3];    -- player
            local projectileAbility = projectile[4];   -- ability
            local isDodgeable = projectile[5];         -- is_dodgeable
            local isAttack = projectile[6];            -- is_attack
            
            -- Only disjoint projectiles that are dodgeable
            if isDodgeable and projectileLocation and projectileCaster then
                -- Calculate time to impact based on distance and estimated speed
                local distance = GetUnitToLocationDistance(npcBot, projectileLocation);
                local estimatedSpeed = 800; -- Default projectile speed estimate
                
                -- Get more accurate speed if it's an ability projectile
                if projectileAbility then
                    local success, abilitySpeed = pcall(function() 
                        return projectileAbility:GetSpecialValueInt("projectile_speed") 
                    end);
                    if success and abilitySpeed > 0 then
                        estimatedSpeed = abilitySpeed;
                    end
                end
                
                local timeToImpact = distance / estimatedSpeed;
                
                -- Disjoint if projectile will hit us soon
                if timeToImpact > 0 and timeToImpact < 2.0 then
                    return BOT_ACTION_DESIRE_VERYHIGH;
                end
            end
        end
    end

    -- EMERGENCY ESCAPE: Low health and being chased
    if mutil.IsRetreating(npcBot) then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        
        if healthPercent < 0.3 and #enemies >= 1 then
            return BOT_ACTION_DESIRE_HIGH;
        end
        
        -- Recent damage from heroes or towers
        if npcBot:WasRecentlyDamagedByAnyHero(2.0) or npcBot:WasRecentlyDamagedByTower(2.0) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- INITIATION: Use for positioning before engage
    if not mutil.IsRetreating(npcBot) and not mutil.IsGoingOnSomeone(npcBot) then
        local enemies = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
        if #enemies >= 2 and npcBot:GetHealth() / npcBot:GetMaxHealth() > 0.6 then
            -- Use for sneaky positioning in teamfights
            return BOT_ACTION_DESIRE_LOW;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderUntransform()
    if not abilityUT or not abilityUT:IsFullyCastable() or abilityUT:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- AUTO: Always untransform after successful disjoint
    if DotaTime() - lastMischiefTime < 1.0 and DotaTime() - lastMischiefTime > 0.1 then
        return BOT_ACTION_DESIRE_HIGH;
    end

    -- OFFENSIVE: Untransform to engage targets
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(npcBot, target);
            if distance <= 800 then -- Close enough to engage
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end

    -- ESCAPE: Untransform when safe to continue escape
    if mutil.IsRetreating(npcBot) and not npcBot:WasRecentlyDamagedByAnyHero(3.0) then
        local enemies = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
        if #enemies == 0 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- TIMEOUT: Auto untransform if transformed too long
    if DotaTime() - lastMischiefTime > 8.0 then
        return BOT_ACTION_DESIRE_LOW;
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderWukongCommand()
    if not abilityWC or not abilityWC:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nRadius = abilityWC:GetSpecialValueInt("second_radius");
    local nCastRange = abilityWC:GetSpecialValueInt("cast_range");

    -- TEAMFIGHT: Multi-hero fights
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(nRadius + 200, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            -- Cast at our location to ensure we stay in ring
            return BOT_ACTION_DESIRE_HIGH, npcBot:GetLocation();
        end
    end

    -- OFFENSIVE: Big engage with team
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) then
            local targetDistance = GetUnitToUnitDistance(npcBot, target);
            if targetDistance <= nRadius then
                local nearbyEnemies = target:GetNearbyHeroes(600, false, BOT_MODE_NONE);
                local nearbyAllies = npcBot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
                
                if #nearbyEnemies >= 2 or (#nearbyAllies >= 1 and targetDistance <= 400) then
                    -- Cast at our location to stay in ring
                    return BOT_ACTION_DESIRE_HIGH, npcBot:GetLocation();
                end
            end
        end
    end

    -- DEFENSIVE: Use when surrounded
    local enemies = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
    if #enemies >= 3 then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        if healthPercent < 0.6 then
            return BOT_ACTION_DESIRE_HIGH, npcBot:GetLocation();
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

-- Helper Functions

function GetBestEscapeTree(trees, enemies)
    local bestTree = nil;
    local maxDistance = 0;
    
    for _, tree in pairs(trees) do
        local treeLocation = GetTreeLocation(tree);
        local minEnemyDistance = 9999;
        
        for _, enemy in pairs(enemies) do
            local distance = GetUnitToLocationDistance(enemy, treeLocation);
            if distance < minEnemyDistance then
                minEnemyDistance = distance;
            end
        end
        
        if minEnemyDistance > maxDistance then
            maxDistance = minEnemyDistance;
            bestTree = tree;
        end
    end
    
    return bestTree;
end

function GetBestOffensiveTree(trees, target)
    if not target or not mutil.IsValidTarget(target) then
        return nil;
    end
    
    local bestTree = nil;
    local bestDistance = 9999;
    
    for _, tree in pairs(trees) do
        local treeLocation = GetTreeLocation(tree);
        local distance = GetUnitToLocationDistance(target, treeLocation);
        
        -- Respect Wukong Command area
        if WCLoc then
            -- Calculate distance between tree location and WC location manually
            local wcDistance = math.sqrt((treeLocation.x - WCLoc.x)^2 + (treeLocation.y - WCLoc.y)^2);
            
            local wcRadius = abilityWC:GetSpecialValueInt("second_radius");
            if wcDistance <= wcRadius * 0.8 then
                if distance < bestDistance and distance >= 200 and distance <= 600 then
                    bestDistance = distance;
                    bestTree = tree;
                end
            end
        else
            if distance < bestDistance and distance >= 200 and distance <= 600 then
                bestDistance = distance;
                bestTree = tree;
            end
        end
    end
    
    return bestTree;
end

function GetBestVisionTree(trees)
    -- Simple implementation - pick a random tree for vision
    if #trees > 0 then
        return trees[1];
    end
    return nil;
end

function GetEscapeLocation(maxRange)
    local ancient = GetAncient(GetTeam());
    if ancient then
        local ancientLocation = ancient:GetLocation();
        local escapeLocation = npcBot:GetXUnitsTowardsLocation(ancientLocation, maxRange);
        return escapeLocation;
    end
    return nil;
end

function HasShard()
    -- Check if we have Aghanim's Shard (no direct API function)
    -- Alternative: Check if boundless strike has shard upgrade behavior
    if abilityBS and abilityBS:GetSpecialValueInt("HasShardUpgrade") == 1 then
        -- Check for shard-specific modifiers or ability changes
        return npcBot:HasModifier("modifier_item_aghanims_shard");
    end
    return false;
end

-- ANTI-STUCK MODE OVERRIDE FUNCTIONS
function GetDesire()
    if npcBot == nil then npcBot = GetBot(); end
    
    local distanceFromFountain = npcBot:DistanceFromFountain();
    local botLevel = npcBot:GetLevel();
    
    if distanceFromFountain < 2000 and botLevel >= 6 and DotaTime() > 180 then
        return BOT_MODE_DESIRE_ABSOLUTE;
    end
    
    if distanceFromFountain < 1500 and DotaTime() > 120 and 
       npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.6 and
       not npcBot:WasRecentlyDamagedByAnyHero(5.0) then
        return BOT_MODE_DESIRE_VERYHIGH;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ModeDesire()
    if npcBot == nil then npcBot = GetBot(); end
    
    local distanceFromFountain = npcBot:DistanceFromFountain();
    local botLevel = npcBot:GetLevel();
    
    if distanceFromFountain < 1800 and botLevel >= 6 and 
       npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.5 and
       DotaTime() > 180 then
        return BOT_MODE_DESIRE_ABSOLUTE;
    end
    
    return BOT_MODE_DESIRE_NONE;
end


