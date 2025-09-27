if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

-- Global variables
local abilityQ = nil;  -- Death Pulse
local abilityW = nil;  -- Ghost Shroud
local abilityE = nil;  -- Heartstopper Aura (passive)
local abilityR = nil;  -- Reaper's Scythe
local abilityDS = nil; -- Death Seeker (shard ability)
local npcBot = nil;

-- State management for death recovery
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Ghost Shroud combo state
local ghostShroudUsedTime = 0;
local comboWindow = 2.0; -- Time window to use Death Pulse after Ghost Shroud

-- Think function protection during death recovery
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
    
    -- UNIVERSAL FOUNTAIN STUCK FIX (HIGHEST PRIORITY)
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
    
    -- CHANNELING PROTECTION
    if mutil.SafeIsChanneling(npcBot) then
        return; -- Don't interrupt channeling
    end
    
    -- Check if we're already using an ability
    if mutil.CanNotUseAbility(npcBot) then return end

    -- Initialize abilities by name (RECOMMENDED for reliability)
    if abilityQ == nil then abilityQ = npcBot:GetAbilityByName("necrolyte_death_pulse"); end
    if abilityW == nil then abilityW = npcBot:GetAbilityByName("necrolyte_ghost_shroud"); end
    if abilityE == nil then abilityE = npcBot:GetAbilityByName("necrolyte_heartstopper_aura"); end
    if abilityR == nil then abilityR = npcBot:GetAbilityByName("necrolyte_reapers_scythe"); end
    if abilityDS == nil then abilityDS = npcBot:GetAbilityByName("necrolyte_death_seeker"); end

    -- Consider using each ability in priority order
    local castRDesire, castRTarget = ConsiderReapersScythe();
    local castDSDesire, castDSTarget = ConsiderDeathSeeker();
    local castWDesire = ConsiderGhostShroud();
    local castQDesire = ConsiderDeathPulse();

    -- Priority: Ultimate > Shard Ability > Combo abilities > Basic abilities
    if castRDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityR, castRTarget);
        return;
    end

    if castDSDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityDS, castDSTarget);
        return;
    end

    if castWDesire > 0 then
        ghostShroudUsedTime = DotaTime();
        npcBot:Action_UseAbility(abilityW);
        return;
    end

    if castQDesire > 0 then
        npcBot:Action_UseAbility(abilityQ);
        return;
    end
end

-- Death Pulse: Heal allies/self or damage enemies
function ConsiderDeathPulse()
    if abilityQ == nil or not abilityQ:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local nRadius = abilityQ:GetSpecialValueInt("area_of_effect");
    local nHeal = abilityQ:GetSpecialValueInt("heal");
    local nDamage = abilityQ:GetAbilityDamage();
    
    -- Enhanced healing if we recently used Ghost Shroud
    local healBonus = 1.0;
    if npcBot:HasModifier("modifier_necrolyte_ghost_shroud") then
        local ghostShroudLevel = abilityW:GetLevel();
        if ghostShroudLevel > 0 then
            healBonus = 1 + (abilityW:GetSpecialValueFloat("heal_bonus") / 100);
        end
    end
    
    local effectiveHeal = nHeal * healBonus;
    local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
    
    -- HIGH PRIORITY: Heal ourselves when low health (especially with Ghost Shroud bonus)
    if healthPercent < 0.4 and effectiveHeal > 100 then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- MODERATE PRIORITY: Heal ourselves with Ghost Shroud combo
    if npcBot:HasModifier("modifier_necrolyte_ghost_shroud") and healthPercent < 0.7 then
        return BOT_ACTION_DESIRE_MODERATE;
    end
    
    -- Interrupt channeling enemies
    local enemies = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- Teamfight usage
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemyHeroes = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        local allyHeroes = npcBot:GetNearbyHeroes(nRadius, false, BOT_MODE_NONE);
        
        -- Count low health allies
        local lowHPAllies = 0;
        for _, ally in pairs(allyHeroes) do
            if ally ~= npcBot and mutil.SafeGetHealthPercent(ally) < 0.5 then
                lowHPAllies = lowHPAllies + 1;
            end
        end
        
        -- Use if we can heal multiple allies or damage multiple enemies
        if lowHPAllies >= 2 or #enemyHeroes >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
        
        if lowHPAllies >= 1 or #enemyHeroes >= 1 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- Farming usage when high mana
    if mutil.IsDefending(npcBot) or mutil.IsPushing(npcBot) then
        local manaPercent = npcBot:GetMana() / npcBot:GetMaxMana();
        if manaPercent > 0.7 then
            local creeps = npcBot:GetNearbyLaneCreeps(nRadius, true);
            if #creeps >= 3 then
                return BOT_ACTION_DESIRE_LOW;
            end
        end
    end
    
    -- Going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.IsInRange(target, npcBot, nRadius) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

-- Ghost Shroud: Protection and heal amplification
function ConsiderGhostShroud()
    if abilityW == nil or not abilityW:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
    
    -- HIGH PRIORITY: Emergency protection when being right-clicked and low health
    if healthPercent < 0.3 and npcBot:WasRecentlyDamagedByAnyHero(2.0) then
        local nearbyEnemies = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
        local physicalThreats = 0;
        
        for _, enemy in pairs(nearbyEnemies) do
            if mutil.SafeGetAttackTarget(enemy) == npcBot then
                physicalThreats = physicalThreats + 1;
            end
        end
        
        if physicalThreats > 0 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end
    
    -- MODERATE PRIORITY: Combo setup when we have Death Pulse ready and need healing
    if healthPercent < 0.6 and abilityQ ~= nil and abilityQ:IsFullyCastable() then
        local qManaCost = abilityQ:GetManaCost();
        local wManaCost = abilityW:GetManaCost();
        
        if npcBot:GetMana() >= (qManaCost + wManaCost) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- RETREAT: Use for movement speed bonus when retreating
    if mutil.IsRetreating(npcBot) and healthPercent < 0.5 then
        return BOT_ACTION_DESIRE_MODERATE;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

-- Reaper's Scythe: Ultimate execution based on missing health
function ConsiderReapersScythe()
    if abilityR == nil or not abilityR:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = abilityR:GetCastRange();
    local nDamagePerHealth = abilityR:GetSpecialValueFloat("damage_per_health");
    
    -- Check for execution opportunities
    local enemies = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);
    
    for _, enemy in pairs(enemies) do
        if mutil.IsValidTarget(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
            local enemyHealth = mutil.SafeGetHealth(enemy);
            local enemyMaxHealth = mutil.SafeGetMaxHealth(enemy);
            local missingHealth = enemyMaxHealth - enemyHealth;
            
            -- Calculate potential damage
            local estimatedDamage = nDamagePerHealth * missingHealth;
            
            -- HIGH PRIORITY: Can kill the target
            if mutil.CanKillTarget(enemy, estimatedDamage, DAMAGE_TYPE_MAGICAL) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
            
            -- MODERATE PRIORITY: Interrupt channeling
            if mutil.SafeIsChanneling(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
            
            -- MODERATE PRIORITY: Target is very low (even if not guaranteed kill)
            local healthPercent = enemyHealth / enemyMaxHealth;
            if healthPercent < 0.25 and estimatedDamage > enemyHealth * 0.7 then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

-- Death Seeker: Shard ability for gap closing and AOE heal/damage
function ConsiderDeathSeeker()
    -- Check if we have shard (check if ability exists and is not hidden)
    if abilityDS == nil or abilityDS:IsHidden() or not abilityDS:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = abilityDS:GetCastRange();
    
    -- ESCAPE: Use on distant ally or creep to escape
    if mutil.IsRetreating(npcBot) then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        if healthPercent < 0.4 then
            -- Look for allied heroes to dash to
            local allies = npcBot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
            for _, ally in pairs(allies) do
                if ally ~= npcBot and mutil.SafeGetHealthPercent(ally) < 0.7 then
                    -- Dash to ally and heal them
                    return BOT_ACTION_DESIRE_HIGH, ally;
                end
            end
            
            -- Look for creeps to dash to for escape
            local creeps = npcBot:GetNearbyCreeps(nCastRange, false);
            if #creeps > 0 then
                return BOT_ACTION_DESIRE_MODERATE, creeps[1];
            end
        end
    end
    
    -- ENGAGE: Use to gap close to enemies
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.IsInRange(target, npcBot, nCastRange) then
            local distanceToTarget = GetUnitToUnitDistance(npcBot, target);
            if distanceToTarget > 400 then -- Only if we need to close distance
                return BOT_ACTION_DESIRE_MODERATE, target;
            end
        end
    end
    
    -- HEAL: Use on low health allies
    if mutil.IsInTeamFight(npcBot, 1200) then
        local allies = npcBot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
        for _, ally in pairs(allies) do
            if ally ~= npcBot and mutil.SafeGetHealthPercent(ally) < 0.3 then
                return BOT_ACTION_DESIRE_HIGH, ally;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

-- ANTI-STUCK MODE OVERRIDE FUNCTIONS (REQUIRED)
function GetDesire()
    if npcBot == nil then npcBot = GetBot(); end
    
    local distanceFromFountain = npcBot:DistanceFromFountain();
    local botLevel = npcBot:GetLevel();
    
    if distanceFromFountain < 2000 and botLevel >= 6 and DotaTime() > 180 then
        return BOT_MODE_DESIRE_ABSOLUTE;
    end
    
    if distanceFromFountain < 1500 and DotaTime() > 120 and 
       npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.6 and
       not mutil.SafeWasRecentlyDamaged(npcBot, 5.0) then
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