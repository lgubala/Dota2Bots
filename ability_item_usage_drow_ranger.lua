if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

-- Global variables
local npcBot = nil;
local abilityFA = nil;  -- Frost Arrows (Q)
local abilityWS = nil;  -- Wave of Silence (W)
local abilityMS = nil;  -- Multishot (E)
local abilityTS = nil;  -- Trueshot (Passive)
local abilityMK = nil;  -- Marksmanship (R - Passive)
local abilityGL = nil;  -- Glacier (Shard)

-- State management for universal fixes
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Drow Ranger specific state
local multishotStartTime = 0;
local isChannelingMultishot = false;
local glacierCastTime = 0;
local glacierDuration = 8.0;

-- Think function protection
function AbilityLevelUpThink()  
    if isRecoveringFromDeath then return; end
    if mutil.SafeIsChanneling(npcBot) then return; end
    ability_item_usage_generic.AbilityLevelUpThink(); 
end

function BuybackUsageThink()
    if isRecoveringFromDeath then return; end
    if mutil.SafeIsChanneling(npcBot) then return; end
    ability_item_usage_generic.BuybackUsageThink();
end

function CourierUsageThink()
    if isRecoveringFromDeath then return; end
    if mutil.SafeIsChanneling(npcBot) then return; end
    ability_item_usage_generic.CourierUsageThink();
end

function ItemUsageThink()
    if isRecoveringFromDeath then return; end
    if mutil.SafeIsChanneling(npcBot) then return; end
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

    -- Initialize abilities by name (RECOMMENDED approach)
    if abilityFA == nil then abilityFA = npcBot:GetAbilityByName("drow_ranger_frost_arrows"); end
    if abilityWS == nil then abilityWS = npcBot:GetAbilityByName("drow_ranger_wave_of_silence"); end
    if abilityMS == nil then abilityMS = npcBot:GetAbilityByName("drow_ranger_multishot"); end
    if abilityTS == nil then abilityTS = npcBot:GetAbilityByName("drow_ranger_trueshot"); end
    if abilityMK == nil then abilityMK = npcBot:GetAbilityByName("drow_ranger_marksmanship"); end
    if abilityGL == nil then abilityGL = npcBot:GetAbilityByName("drow_ranger_glacier"); end

    -- Track multishot channeling
    local isCurrentlyChanneling = mutil.SafeIsChanneling(npcBot);
    
    if isCurrentlyChanneling then
        if not isChannelingMultishot then
            multishotStartTime = DotaTime();
            isChannelingMultishot = true;
        end
        
        -- CRITICAL: Check if we should cancel multishot early, but be VERY conservative
        local cancelDesire = ConsiderCancelMultishot();
        if cancelDesire >= BOT_ACTION_DESIRE_HIGH then -- Only cancel for HIGH priority threats
            npcBot:Action_ClearActions(false);
            isChannelingMultishot = false;
            return;
        end
        
        return; -- PROTECT channeling - don't use other abilities
    else
        if isChannelingMultishot then
            isChannelingMultishot = false; -- Channel completed or interrupted
        end
    end

    -- Check if we're already using an ability
    if mutil.CanNotUseAbility(npcBot) then return end

    -- PRIORITY ORDER: Emergency Cancel -> Combo (Glacier+Multishot) -> Wave of Silence -> Multishot -> Frost Arrows

    -- 1. COMBO: Glacier + Multishot for maximum damage
    local castGLDesire = ConsiderGlacier();
    local castMSDesire, castMSLocation = ConsiderMultishot();
    
    -- Prioritize glacier before multishot for combo
    if castGLDesire > 0 and castMSDesire > 0 then
        npcBot:Action_UseAbility(abilityGL);
        glacierCastTime = DotaTime();
        return;
    end

    -- 2. INTERRUPT/ESCAPE: Wave of Silence
    local castWSDesire, castWSLocation = ConsiderWaveOfSilence();
    if castWSDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilityWS, castWSLocation);
        return;
    end

    -- 3. NUKE: Multishot for damage
    if castMSDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilityMS, castMSLocation);
        multishotStartTime = DotaTime();
        isChannelingMultishot = true;
        return;
    end

    -- 4. AUTO-ATTACK MODIFIER: Frost Arrows
    ConsiderFrostArrows();
end

function ConsiderFrostArrows()
    if not abilityFA or not abilityFA:IsFullyCastable() then
        -- Turn off autocast if not castable
        if abilityFA and abilityFA:GetAutoCastState() then
            abilityFA:ToggleAutoCast();
        end
        return;
    end

    local target = npcBot:GetTarget();
    local shouldAutocast = false;

    -- ONLY use for chasing escaping enemies - main use case
    if mutil.IsGoingOnSomeone(npcBot) and mutil.IsValidTarget(target) then
        local distance = GetUnitToUnitDistance(npcBot, target);
        local attackRange = npcBot:GetAttackRange();
        
        -- Check if enemy is trying to escape (moving away from us)
        local enemyVelocity = target:GetVelocity();
        local directionToUs = (npcBot:GetLocation() - target:GetLocation()):Normalized();
        local isMovingAway = enemyVelocity:Dot(directionToUs) < -0.3; -- Moving away from us
        
        -- Only use if enemy is escaping AND we have good mana
        if isMovingAway and distance > attackRange * 0.8 and 
           npcBot:GetMana() / npcBot:GetMaxMana() > 0.6 then
            shouldAutocast = true;
        end
    end

    -- KITING: Use when retreating but only if we have plenty of mana
    if mutil.IsRetreating(npcBot) and npcBot:GetMana() / npcBot:GetMaxMana() > 0.8 then
        local enemies = npcBot:GetNearbyHeroes(npcBot:GetAttackRange() + 100, true, BOT_MODE_NONE);
        if #enemies >= 1 then
            shouldAutocast = true;
        end
    end

    -- Toggle autocast based on decision (much more restrictive now)
    local currentState = abilityFA:GetAutoCastState();
    if shouldAutocast and not currentState then
        abilityFA:ToggleAutoCast();
    elseif not shouldAutocast and currentState then
        abilityFA:ToggleAutoCast();
    end
end

function ConsiderWaveOfSilence()
    if not abilityWS or not abilityWS:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityWS:GetCastRange();
    local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);

    -- INTERRUPT: Stop channeling enemies (highest priority)
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
            -- Cast DIRECTLY AT the enemy, not their location
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end

    -- ESCAPE: Knockback pursuers when retreating
    if mutil.IsRetreating(npcBot) then
        for _, enemy in pairs(enemies) do
            if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) and 
               mutil.CanCastOnNonMagicImmune(enemy) then
                -- Cast DIRECTLY AT the enemy for knockback
                return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
            end
        end
    end

    -- TEAMFIGHT: Target closest enemy first
    if mutil.IsInTeamFight(npcBot, 1200) then
        local closestEnemy = nil;
        local closestDistance = 9999;
        
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnNonMagicImmune(enemy) then
                local distance = GetUnitToUnitDistance(npcBot, enemy);
                if distance < closestDistance then
                    closestDistance = distance;
                    closestEnemy = enemy;
                end
            end
        end
        
        if closestEnemy then
            return BOT_ACTION_DESIRE_HIGH, closestEnemy:GetLocation();
        end
    end

    -- OFFENSIVE: Target the enemy we're going after
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and 
           mutil.CanCastOnNonMagicImmune(target) and 
           mutil.IsInRange(target, npcBot, nCastRange) then
            return BOT_ACTION_DESIRE_MODERATE, target:GetLocation();
        end
    end

    -- SIMPLE: Just target any nearby enemy
    if #enemies > 0 then
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_LOW, enemy:GetLocation();
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderMultishot()
    if not abilityMS or not abilityMS:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nAttackRange = npcBot:GetAttackRange();
    local nArrowRange = nAttackRange * 1.75; -- Fixed range multiplier

    -- CRITICAL SAFETY: Don't channel if melee enemies are very close
    local nearbyEnemies = npcBot:GetNearbyHeroes(350, true, BOT_MODE_NONE);
    for _, enemy in pairs(nearbyEnemies) do
        if enemy:IsAlive() and not enemy:IsRangedAttacker() and not mutil.IsDisabled(true, enemy) then
            return BOT_ACTION_DESIRE_NONE, nil; -- Too dangerous
        end
    end

    -- TEAMFIGHT: Target center of enemy group
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(nArrowRange, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            -- Calculate center point of enemies
            local centerX, centerY = 0, 0;
            for _, enemy in pairs(enemies) do
                local pos = enemy:GetLocation();
                centerX = centerX + pos.x;
                centerY = centerY + pos.y;
            end
            local centerPoint = Vector(centerX / #enemies, centerY / #enemies, 0);
            return BOT_ACTION_DESIRE_HIGH, centerPoint;
        end
    end

    -- OFFENSIVE: Target the enemy we're going after
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.IsInRange(target, npcBot, nArrowRange) then
            return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
        end
    end

    -- FARMING: Target center of creep wave
    if npcBot:GetActiveMode() == BOT_MODE_FARM or mutil.IsPushing(npcBot) then
        local creeps = npcBot:GetNearbyLaneCreeps(nArrowRange, true);
        if #creeps >= 3 then
            local centerX, centerY = 0, 0;
            for _, creep in pairs(creeps) do
                local pos = creep:GetLocation();
                centerX = centerX + pos.x;
                centerY = centerY + pos.y;
            end
            local centerPoint = Vector(centerX / #creeps, centerY / #creeps, 0);
            return BOT_ACTION_DESIRE_MODERATE, centerPoint;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderGlacier()
    if not abilityGL or not abilityGL:IsFullyCastable() or abilityGL:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- TEAMFIGHT: Always use glacier in teamfights
    if mutil.IsInTeamFight(npcBot, 1200) then
        return BOT_ACTION_DESIRE_HIGH;
    end

    -- ESCAPE: Use against melee pursuers
    if mutil.IsRetreating(npcBot) then
        local enemies = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if enemy:IsAlive() and not enemy:IsRangedAttacker() then
                return BOT_ACTION_DESIRE_HIGH; -- Block melee
            end
        end
    end

    -- OFFENSIVE: Use when going on enemies
    if mutil.IsGoingOnSomeone(npcBot) then
        local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies >= 1 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- FARMING: Use when pushing with multishot available
    if mutil.IsPushing(npcBot) and abilityMS and abilityMS:IsFullyCastable() then
        local creeps = npcBot:GetNearbyLaneCreeps(800, true);
        if #creeps >= 3 then
            return BOT_ACTION_DESIRE_LOW;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderCancelMultishot()
    if not isChannelingMultishot then
        return BOT_ACTION_DESIRE_NONE;
    end

    local channelTime = DotaTime() - multishotStartTime;

    -- EMERGENCY ONLY: Cancel only for immediate life-threatening danger
    local nearbyEnemies = npcBot:GetNearbyHeroes(250, true, BOT_MODE_NONE);
    local immediateDanger = 0;
    
    for _, enemy in pairs(nearbyEnemies) do
        if enemy:IsAlive() and not enemy:IsRangedAttacker() and not mutil.IsDisabled(true, enemy) then
            immediateDanger = immediateDanger + 1;
        end
    end

    -- Only cancel if multiple melee enemies are very close
    if immediateDanger >= 2 then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end

    -- Cancel if health is critically low AND taking damage
    local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
    if healthPercent < 0.15 and npcBot:WasRecentlyDamagedByAnyHero(0.5) then
        return BOT_ACTION_DESIRE_HIGH;
    end

    -- Otherwise, let the channel complete
    return BOT_ACTION_DESIRE_NONE;
end

-- Helper Functions

function CountEnemiesInLine(startPos, endPos, width, maxRange)
    local enemies = npcBot:GetNearbyHeroes(maxRange, true, BOT_MODE_NONE);
    local count = 0;
    
    for _, enemy in pairs(enemies) do
        if mutil.CanCastOnNonMagicImmune(enemy) then
            local distance = PointToLineDistance(enemy:GetLocation(), startPos, endPos);
            if distance <= width / 2 then
                count = count + 1;
            end
        end
    end
    
    return count;
end

function GetBestMultishotDirection(enemies, range)
    local bestDirection = nil;
    local maxHits = 0;
    
    for _, enemy in pairs(enemies) do
        local direction = enemy:GetLocation();
        local hitCount = CountEnemiesInCone(npcBot:GetLocation(), direction, range);
        
        if hitCount > maxHits then
            maxHits = hitCount;
            bestDirection = direction;
        end
    end
    
    return bestDirection;
end

function CountEnemiesInCone(startPos, direction, range)
    local enemies = npcBot:GetNearbyHeroes(range, true, BOT_MODE_NONE);
    local count = 0;
    local coneAngle = 50; -- From ability definition
    
    for _, enemy in pairs(enemies) do
        local enemyDirection = (enemy:GetLocation() - startPos):Normalized();
        local targetDirection = (direction - startPos):Normalized();
        local angle = math.deg(math.acos(enemyDirection:Dot(targetDirection)));
        
        if angle <= coneAngle / 2 then
            count = count + 1;
        end
    end
    
    return count;
end

function GetCreepCenter(creeps)
    if #creeps == 0 then return nil end
    
    local sumX, sumY = 0, 0;
    for _, creep in pairs(creeps) do
        local pos = creep:GetLocation();
        sumX = sumX + pos.x;
        sumY = sumY + pos.y;
    end
    
    return Vector(sumX / #creeps, sumY / #creeps, 0);
end

function PointToLineDistance(point, lineStart, lineEnd)
    local lineVec = lineEnd - lineStart;
    local pointVec = point - lineStart;
    local lineLength = lineVec:Length();
    
    if lineLength == 0 then
        return (point - lineStart):Length();
    end
    
    local t = math.max(0, math.min(1, pointVec:Dot(lineVec) / (lineLength * lineLength)));
    local projection = lineStart + t * lineVec;
    return (point - projection):Length();
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