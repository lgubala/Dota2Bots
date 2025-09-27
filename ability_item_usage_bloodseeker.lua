if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

-- Global variables
local npcBot = nil;
local abilityBR = nil;  -- Bloodrage (Q)
local abilityBB = nil;  -- Blood Bath (W)
local abilityTH = nil;  -- Thirst (E) - Passive
local abilityRU = nil;  -- Rupture (R)
local abilityBM = nil;  -- Blood Mist (Scepter)

-- State management for universal fixes
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Bloodseeker specific state
local lastBloodrageTime = 0;
local lastRuptureTargets = {}; -- Track rupture targets to avoid double casting
local bloodrageCooldown = 2.0; -- Prevent spam

-- Health management constants
local SAFE_HP_THRESHOLD = 0.20; -- Don't bloodrage if below this
local BLOODRAGE_MIN_HP = 0.35;  -- Minimum HP to use bloodrage
local BLOODRAGE_DAMAGE_PER_SEC = 0.014; -- 1.4% per second

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

    -- Check if we're already using an ability
    if mutil.CanNotUseAbility(npcBot) then return end

    -- Initialize abilities by name (RECOMMENDED approach)
    if abilityBR == nil then abilityBR = npcBot:GetAbilityByName("bloodseeker_bloodrage"); end
    if abilityBB == nil then abilityBB = npcBot:GetAbilityByName("bloodseeker_blood_bath"); end
    if abilityTH == nil then abilityTH = npcBot:GetAbilityByName("bloodseeker_thirst"); end
    if abilityRU == nil then abilityRU = npcBot:GetAbilityByName("bloodseeker_rupture"); end
    if abilityBM == nil then abilityBM = npcBot:GetAbilityByName("bloodseeker_blood_mist"); end

    -- Clean up old rupture tracking
    CleanupRuptureTargets();

    -- Check for thirst activation (hunt mode)
    local isThirsting = npcBot:HasModifier("modifier_bloodseeker_thirst_speed");

    -- PRIORITY ORDER: Ultimate -> Bloodrage -> Blood Bath -> Blood Mist

    -- 1. ULTIMATE: Rupture for movement denial
    local castRUDesire, castRUTarget = ConsiderRupture();
    if castRUDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityRU, castRUTarget);
        TrackRuptureTarget(castRUTarget);
        return;
    end

    -- 2. BUFF: Bloodrage for damage boost
    local castBRDesire, castBRTarget = ConsiderBloodrage();
    if castBRDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityBR, castBRTarget);
        lastBloodrageTime = DotaTime();
        return;
    end

    -- 3. NUKE/SILENCE: Blood Bath for area control
    local castBBDesire, castBBLocation = ConsiderBloodBath();
    if castBBDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilityBB, castBBLocation);
        return;
    end

    -- 4. SCEPTER: Blood Mist toggle management
    local castBMDesire = ConsiderBloodMist();
    if castBMDesire > 0 then
        npcBot:Action_UseAbility(abilityBM);
        return;
    end
end

function ConsiderBloodrage()
    if not abilityBR or not abilityBR:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Prevent spam
    if DotaTime() - lastBloodrageTime < bloodrageCooldown then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityBR:GetCastRange();
    local nDuration = abilityBR:GetSpecialValueFloat("duration");
    local nDamagePerSec = BLOODRAGE_DAMAGE_PER_SEC;
    local totalDamagePercent = nDamagePerSec * nDuration;

    -- TEAMFIGHT: Buff highest damage ally
    if mutil.IsInTeamFight(npcBot, 1200) then
        local allies = npcBot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
        local bestAlly = nil;
        local highestDamage = 0;

        -- Include self in consideration
        table.insert(allies, npcBot);

        for _, ally in pairs(allies) do
            if not ally:HasModifier("modifier_bloodseeker_bloodrage") and
               mutil.CanCastOnNonMagicImmune(ally) then
                
                local allyHealth = ally:GetHealth() / ally:GetMaxHealth();
                local allyDamage = ally:GetAttackDamage();
                
                -- Only buff if ally has enough health to survive the drain
                if allyHealth > BLOODRAGE_MIN_HP + totalDamagePercent then
                    if allyDamage > highestDamage then
                        highestDamage = allyDamage;
                        bestAlly = ally;
                    end
                end
            end
        end

        if bestAlly ~= nil then
            return BOT_ACTION_DESIRE_HIGH, bestAlly;
        end
    end

    -- OFFENSIVE: Self-buff when going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        
        if not npcBot:HasModifier("modifier_bloodseeker_bloodrage") and
           healthPercent > BLOODRAGE_MIN_HP + totalDamagePercent then
            
            local target = npcBot:GetTarget();
            if mutil.IsValidTarget(target) and GetUnitToUnitDistance(npcBot, target) <= 800 then
                return BOT_ACTION_DESIRE_HIGH, npcBot;
            end
        end
    end

    -- FARMING: Self-buff for faster farming
    if npcBot:GetActiveMode() == BOT_MODE_FARM then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        
        if not npcBot:HasModifier("modifier_bloodseeker_bloodrage") and
           healthPercent > 0.6 then
            
            local nearbyCreeps = npcBot:GetNearbyLaneCreeps(400, true);
            local nearbyNeutrals = npcBot:GetNearbyNeutralCreeps(400);
            
            if #nearbyCreeps >= 2 or #nearbyNeutrals >= 1 then
                local enemies = npcBot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
                if #enemies == 0 then -- Only farm buff when safe
                    return BOT_ACTION_DESIRE_MODERATE, npcBot;
                end
            end
        end
    end

    -- THIRST: Buff when hunting (thirst is active)
    if npcBot:HasModifier("modifier_bloodseeker_thirst_speed") then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        
        if not npcBot:HasModifier("modifier_bloodseeker_bloodrage") and
           healthPercent > BLOODRAGE_MIN_HP + totalDamagePercent then
            return BOT_ACTION_DESIRE_HIGH, npcBot;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderBloodBath()
    if not abilityBB or not abilityBB:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityBB:GetCastRange();
    local nRadius = abilityBB:GetSpecialValueInt("radius");
    local nDamage = abilityBB:GetSpecialValueInt("damage");
    local nDelay = abilityBB:GetSpecialValueFloat("delay");
    local nCastPoint = abilityBB:GetCastPoint();
    local totalDelay = nDelay + nCastPoint;

    -- LETHAL: Finish off low HP enemies
    local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutil.CanCastOnNonMagicImmune(enemy) and 
           mutil.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_PURE) then
            
            if enemy:GetMovementDirectionStability() >= 0.75 then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetExtrapolatedLocation(totalDelay);
            else
                return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
            end
        end
    end

    -- INTERRUPT: Stop channeling enemies
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
        end
    end

    -- TEAMFIGHT: AoE damage and silence
    if mutil.IsInTeamFight(npcBot, 1200) then
        local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nRadius/2, totalDelay, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end

    -- DEFENSIVE: Area denial when retreating
    if mutil.IsRetreating(npcBot) then
        for _, enemy in pairs(enemies) do
            if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) then
                -- Place at our current location to deter pursuit
                return BOT_ACTION_DESIRE_MODERATE, npcBot:GetLocation();
            end
        end
    end

    -- OFFENSIVE: When going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and 
           mutil.CanCastOnNonMagicImmune(target) and 
           mutil.IsInRange(target, npcBot, nCastRange) then
            
            if target:GetMovementDirectionStability() >= 0.75 then
                return BOT_ACTION_DESIRE_MODERATE, target:GetExtrapolatedLocation(totalDelay);
            else
                return BOT_ACTION_DESIRE_MODERATE, target:GetLocation();
            end
        end
    end

    -- FARMING: Clear creep waves efficiently
    if (npcBot:GetActiveMode() == BOT_MODE_FARM or mutil.IsPushing(npcBot)) then
        local nearbyCreeps = npcBot:GetNearbyLaneCreeps(nCastRange, true);
        if #nearbyCreeps >= 4 and npcBot:GetMana() / npcBot:GetMaxMana() > 0.6 then
            local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), nCastRange, nRadius/2, totalDelay, nDamage);
            if locationAoE.count >= 3 then
                return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderRupture()
    if not abilityRU or not abilityRU:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityRU:GetCastRange();
    local enemies = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);

    -- TEAMFIGHT: Priority target selection
    if mutil.IsInTeamFight(npcBot, 1200) then
        -- Prioritize carries and mobile heroes
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnMagicImmune(enemy) and 
               not IsTargetAlreadyRuptured(enemy) and
               not mutil.IsDisabled(true, enemy) then
                
                -- High priority targets
                local unitName = enemy:GetUnitName();
                if string.find(unitName, "antimage") or 
                   string.find(unitName, "phantom_assassin") or
                   string.find(unitName, "faceless_void") or
                   string.find(unitName, "spectre") then
                    return BOT_ACTION_DESIRE_VERYHIGH, enemy;
                end
                
                -- Any carry
                if IsCarryHero(enemy) then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
        
        -- Any valid target in teamfight
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnMagicImmune(enemy) and 
               not IsTargetAlreadyRuptured(enemy) and
               not mutil.IsDisabled(true, enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    -- OFFENSIVE: When going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and 
           mutil.CanCastOnMagicImmune(target) and 
           mutil.IsInRange(target, npcBot, nCastRange + 100) and
           not IsTargetAlreadyRuptured(target) and
           not mutil.IsDisabled(true, target) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    -- THIRST: Hunt low HP enemies when thirst is active
    if npcBot:HasModifier("modifier_bloodseeker_thirst_speed") then
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnMagicImmune(enemy) and 
               not IsTargetAlreadyRuptured(enemy) and
               enemy:GetHealth() / enemy:GetMaxHealth() < 0.6 then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- ESCAPE: Rupture pursuers when retreating
    if mutil.IsRetreating(npcBot) then
        for _, enemy in pairs(enemies) do
            if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) and
               mutil.CanCastOnMagicImmune(enemy) and
               not IsTargetAlreadyRuptured(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderBloodMist()
    if not abilityBM or not abilityBM:IsFullyCastable() or abilityBM:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = 450;
    local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
    local isMistActive = abilityBM:GetToggleState();

    -- FARMING: Use for wave clear when healthy
    if (mutil.IsPushing(npcBot) or npcBot:GetActiveMode() == BOT_MODE_FARM) and 
       healthPercent > 0.7 then
        
        local nearbyCreeps = npcBot:GetNearbyLaneCreeps(nRadius, true);
        if #nearbyCreeps >= 4 and not isMistActive then
            return BOT_ACTION_DESIRE_MODERATE;
        elseif #nearbyCreeps < 3 and isMistActive then
            return BOT_ACTION_DESIRE_MODERATE; -- Turn off
        end
    end

    -- OFFENSIVE: Use when going on targets
    if mutil.IsGoingOnSomeone(npcBot) and healthPercent > 0.5 then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(npcBot, target);
            
            if distance <= nRadius and not isMistActive then
                return BOT_ACTION_DESIRE_MODERATE; -- Turn on
            elseif distance > nRadius and isMistActive then
                return BOT_ACTION_DESIRE_MODERATE; -- Turn off
            end
        end
    end

    -- DEFENSIVE: Turn off when retreating or low HP
    if (mutil.IsRetreating(npcBot) or healthPercent < 0.4) and isMistActive then
        return BOT_ACTION_DESIRE_HIGH; -- Turn off immediately
    end

    -- AUTO CLEANUP: Turn off when no enemies or creeps nearby
    if isMistActive then
        local enemies = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        local creeps = npcBot:GetNearbyLaneCreeps(nRadius, true);
        
        if #enemies == 0 and #creeps == 0 then
            return BOT_ACTION_DESIRE_LOW; -- Turn off
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

-- Helper Functions

function IsTargetAlreadyRuptured(target)
    if not target then return false end
    return target:HasModifier("modifier_bloodseeker_rupture");
end

function TrackRuptureTarget(target)
    if not target then return end
    
    local targetID = target:GetPlayerID();
    lastRuptureTargets[targetID] = DotaTime();
end

function CleanupRuptureTargets()
    local currentTime = DotaTime();
    local ruptureDuration = 11; -- Max rupture duration
    
    for targetID, castTime in pairs(lastRuptureTargets) do
        if currentTime - castTime > ruptureDuration then
            lastRuptureTargets[targetID] = nil;
        end
    end
end

function IsCarryHero(enemy)
    if not enemy then return false end
    
    local unitName = enemy:GetUnitName();
    local carryNames = {
        "antimage", "phantom_assassin", "faceless_void", "spectre",
        "medusa", "drow_ranger", "sniper", "luna", "gyrocopter",
        "juggernaut", "lifestealer", "wraith_king", "sven",
        "phantom_lancer", "naga_siren", "terrorblade", "morphling"
    };
    
    for _, carryName in pairs(carryNames) do
        if string.find(unitName, carryName) then
            return true;
        end
    end
    
    return false;
end

function GetBloodrageHealthCost()
    if not abilityBR then return 0 end
    
    local duration = abilityBR:GetSpecialValueFloat("duration");
    local damagePerSec = BLOODRAGE_DAMAGE_PER_SEC;
    return duration * damagePerSec;
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