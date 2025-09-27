if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

-- Global variables
local npcBot = nil;
local abilityMI = nil;  -- Mirror Image (Q)
local abilityEN = nil;  -- Ensnare (W)
local abilityRT = nil;  -- Rip Tide (E) - Passive or Active depending on facet
local abilityDL = nil;  -- Deluge (E) - Alternative to Rip Tide
local abilityRI = nil;  -- Reel In (D)
local abilitySS = nil;  -- Song of the Siren (R)
local abilitySSC = nil; -- Song Cancel (R sub-ability)

-- State management for universal fixes
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Naga Siren specific state
local songStartTime = 0;
local maxSongDuration = 7.0;
local lastEnsnareTime = 0;
local ensnareTarget = nil;

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
    if abilityMI == nil then abilityMI = npcBot:GetAbilityByName("naga_siren_mirror_image"); end
    if abilityEN == nil then abilityEN = npcBot:GetAbilityByName("naga_siren_ensnare"); end
    if abilityRT == nil then abilityRT = npcBot:GetAbilityByName("naga_siren_rip_tide"); end
    if abilityDL == nil then abilityDL = npcBot:GetAbilityByName("naga_siren_deluge"); end
    if abilityRI == nil then abilityRI = npcBot:GetAbilityByName("naga_siren_reel_in"); end
    if abilitySS == nil then abilitySS = npcBot:GetAbilityByName("naga_siren_song_of_the_siren"); end
    if abilitySSC == nil then abilitySSC = npcBot:GetAbilityByName("naga_siren_song_of_the_siren_cancel"); end

    -- Clean up old ensnare tracking
    if ensnareTarget ~= nil and DotaTime() > lastEnsnareTime + 6.0 then
        ensnareTarget = nil;
    end

    -- PRIORITY ORDER: Song Cancel -> Ultimate -> Reel In -> Ensnare -> Deluge -> Mirror Image

    -- 1. HIGHEST PRIORITY: Song Cancel (when song is active and conditions are met)
    local castSSCDesire = ConsiderSongCancel();
    if castSSCDesire > 0 then
        npcBot:Action_UseAbility(abilitySSC);
        songStartTime = 0; -- Reset song tracking
        return;
    end

    -- 2. ULTIMATE: Song of the Siren for teamfight control
    local castSSDesire = ConsiderSongOfTheSiren();
    if castSSDesire > 0 then
        npcBot:Action_UseAbility(abilitySS);
        songStartTime = DotaTime();
        return;
    end

    -- 3. COMBO: Reel In (only after ensnare)
    local castRIDesire = ConsiderReelIn();
    if castRIDesire > 0 then
        npcBot:Action_UseAbility(abilityRI);
        return;
    end

    -- 4. DISABLE: Ensnare for catch/escape
    local castENDesire, castENTarget = ConsiderEnsnare();
    if castENDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityEN, castENTarget);
        ensnareTarget = castENTarget;
        lastEnsnareTime = DotaTime();
        return;
    end

    -- 5. NUKE: Deluge (if available instead of passive Rip Tide)
    local castDLDesire = ConsiderDeluge();
    if castDLDesire > 0 then
        npcBot:Action_UseAbility(abilityDL);
        return;
    end

    -- 6. UTILITY: Mirror Image for illusions
    local castMIDesire = ConsiderMirrorImage();
    if castMIDesire > 0 then
        npcBot:Action_UseAbility(abilityMI);
        return;
    end
end

function ConsiderEnsnare()
    if not abilityEN or not abilityEN:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityEN:GetCastRange();
    local nDuration = abilityEN:GetSpecialValueFloat("duration");

    -- INTERRUPT: Channeling enemies (highest priority)
    local enemies = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_HIGH, enemy;
        end
    end

    -- ESCAPE: Disable pursuers when retreating
    if mutil.IsRetreating(npcBot) then
        for _, enemy in pairs(enemies) do
            if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) and 
               mutil.CanCastOnNonMagicImmune(enemy) and 
               mutil.IsInRange(enemy, npcBot, nCastRange) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- OFFENSIVE: Catch fleeing enemies
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and 
           mutil.CanCastOnNonMagicImmune(target) and 
           mutil.IsInRange(target, npcBot, nCastRange + 100) then
            
            -- Prioritize if target is trying to escape
            local targetDistance = GetUnitToUnitDistance(npcBot, target);
            if targetDistance > 400 then
                return BOT_ACTION_DESIRE_HIGH, target;
            else
                return BOT_ACTION_DESIRE_MODERATE, target;
            end
        end
    end

    -- TEAMFIGHT: Disable dangerous enemies
    if mutil.IsInTeamFight(npcBot, 1200) then
        local mostDangerous = nil;
        local highestDamage = 0;

        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnNonMagicImmune(enemy) then
                local damage = mutil.SafeGetEstimatedDamageToTarget(enemy, false, npcBot, 3.0, DAMAGE_TYPE_ALL);
                if damage > highestDamage then
                    highestDamage = damage;
                    mostDangerous = enemy;
                end
            end
        end

        if mostDangerous ~= nil then
            return BOT_ACTION_DESIRE_MODERATE, mostDangerous;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderReelIn()
    if not abilityRI or not abilityRI:IsFullyCastable() or abilityRI:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Only use after we've ensnared someone recently
    if ensnareTarget == nil or DotaTime() > lastEnsnareTime + 1.0 then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Check if target is still ensnared
    if not ensnareTarget:HasModifier("modifier_naga_siren_ensnare") then
        ensnareTarget = nil;
        return BOT_ACTION_DESIRE_NONE;
    end

    -- OFFENSIVE: Pull ensnared enemies closer for follow-up
    if mutil.IsGoingOnSomeone(npcBot) and ensnareTarget == npcBot:GetTarget() then
        local distance = GetUnitToUnitDistance(npcBot, ensnareTarget);
        if distance > 300 then -- Only pull if they're far enough
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- TEAMFIGHT: Pull enemies into our team
    if mutil.IsInTeamFight(npcBot, 1200) then
        local nearbyAllies = npcBot:GetNearbyHeroes(600, false, BOT_MODE_NONE);
        if #nearbyAllies >= 1 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderMirrorImage()
    if not abilityMI or not abilityMI:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- ESCAPE: High priority when retreating and low HP
    if mutil.IsRetreating(npcBot) then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        
        if healthPercent < 0.5 and #enemies >= 1 then
            return BOT_ACTION_DESIRE_HIGH;
        end
        
        if npcBot:WasRecentlyDamagedByAnyHero(2.0) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- TEAMFIGHT: Confuse enemies and add DPS
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- OFFENSIVE: Use when engaging
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and GetUnitToUnitDistance(npcBot, target) <= 600 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- FARMING: Use for faster farming when safe
    if npcBot:GetActiveMode() == BOT_MODE_FARM then
        local nearbyCreeps = npcBot:GetNearbyLaneCreeps(600, true);
        local nearbyNeutrals = npcBot:GetNearbyNeutralCreeps(600);
        
        if (#nearbyCreeps >= 3 or #nearbyNeutrals >= 2) and 
           npcBot:GetMana() / npcBot:GetMaxMana() > 0.6 then
            local enemies = npcBot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
            if #enemies == 0 then
                return BOT_ACTION_DESIRE_LOW;
            end
        end
    end

    -- PUSHING: Use for faster push
    if mutil.IsPushing(npcBot) then
        local nearbyCreeps = npcBot:GetNearbyLaneCreeps(600, true);
        local nearbyTowers = npcBot:GetNearbyTowers(600, true);
        
        if (#nearbyCreeps >= 3 or #nearbyTowers >= 1) and 
           npcBot:GetMana() / npcBot:GetMaxMana() > 0.5 then
            return BOT_ACTION_DESIRE_LOW;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderDeluge()
    -- Check if we have the active Deluge instead of passive Rip Tide
    if not abilityDL or not abilityDL:IsFullyCastable() or abilityDL:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityDL:GetSpecialValueInt("radius");
    local nDamage = abilityDL:GetSpecialValueInt("damage");

    -- TEAMFIGHT: AoE damage and slow
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- OFFENSIVE: When going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and 
           mutil.CanCastOnNonMagicImmune(target) and 
           mutil.IsInRange(target, npcBot, nRadius) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- FARMING: Clear creep waves
    if npcBot:GetActiveMode() == BOT_MODE_FARM then
        local nearbyCreeps = npcBot:GetNearbyLaneCreeps(nRadius, true);
        if #nearbyCreeps >= 3 and npcBot:GetMana() / npcBot:GetMaxMana() > 0.6 then
            return BOT_ACTION_DESIRE_LOW;
        end
    end

    -- ESCAPE: Slow pursuers
    if mutil.IsRetreating(npcBot) then
        local enemies = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        if #enemies >= 1 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderSongOfTheSiren()
    if not abilitySS or not abilitySS:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilitySS:GetCastRange();

    -- EMERGENCY ESCAPE: Low health with multiple enemies
    if mutil.IsRetreating(npcBot) then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        local enemies = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        
        if healthPercent < 0.3 and #enemies >= 2 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
        
        if healthPercent < 0.5 and #enemies >= 3 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- TEAMFIGHT RESET: When overwhelmed
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        local allies = npcBot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
        
        -- Use when outnumbered
        if #enemies >= #allies + 2 and #enemies >= 3 then
            return BOT_ACTION_DESIRE_HIGH;
        end
        
        -- Use when allies are low HP
        local lowHpAllies = 0;
        for _, ally in pairs(allies) do
            if ally:GetHealth() / ally:GetMaxHealth() < 0.4 then
                lowHpAllies = lowHpAllies + 1;
            end
        end
        
        if lowHpAllies >= 2 and #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- SETUP: Catch fleeing enemies for team
    if not mutil.IsRetreating(npcBot) and not mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        local allies = npcBot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
        
        if #enemies >= 2 and #allies >= 2 then
            -- Check if enemies are trying to escape
            local fleeingEnemies = 0;
            for _, enemy in pairs(enemies) do
                if enemy:GetActiveMode() == BOT_MODE_RETREAT then
                    fleeingEnemies = fleeingEnemies + 1;
                end
            end
            
            if fleeingEnemies >= 2 then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderSongCancel()
    if not abilitySSC or not abilitySSC:IsFullyCastable() or abilitySSC:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Only consider if we're actually singing
    if songStartTime == 0 or not npcBot:HasModifier("modifier_naga_siren_song_of_the_siren_aura") then
        return BOT_ACTION_DESIRE_NONE;
    end

    local songDuration = DotaTime() - songStartTime;
    
    -- AUTO CANCEL: Near max duration
    if songDuration >= maxSongDuration * 0.95 then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end

    -- ENGAGE: Cancel when team is ready to fight
    if songDuration >= 1.0 then -- Give time for positioning
        local enemies = npcBot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        local allies = npcBot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
        
        -- Cancel when we have good positioning for fight
        if #allies >= #enemies and #allies >= 2 then
            -- Check if allies are healthy enough to fight
            local healthyAllies = 0;
            for _, ally in pairs(allies) do
                if ally:GetHealth() / ally:GetMaxHealth() > 0.6 then
                    healthyAllies = healthyAllies + 1;
                end
            end
            
            if healthyAllies >= #enemies then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    -- OPPORTUNITY: Cancel when enemies are isolated
    if songDuration >= 2.0 then
        local isolatedEnemies = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
        local nearbyAllies = npcBot:GetNearbyHeroes(600, false, BOT_MODE_NONE);
        
        if #isolatedEnemies == 1 and #nearbyAllies >= 1 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- SAFETY: If we're in danger during song
    if songDuration >= 0.5 then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        if healthPercent < 0.3 then
            -- Check if we can escape safely
            local nearbyEnemies = npcBot:GetNearbyHeroes(400, true, BOT_MODE_NONE);
            if #nearbyEnemies == 0 then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

-- Helper Functions

function IsEnemyEnsnared(enemy)
    if not enemy then return false end
    return enemy:HasModifier("modifier_naga_siren_ensnare");
end

function GetHealthyAlliesCount(range)
    local allies = npcBot:GetNearbyHeroes(range, false, BOT_MODE_NONE);
    local healthyCount = 0;
    
    for _, ally in pairs(allies) do
        if ally:GetHealth() / ally:GetMaxHealth() > 0.5 then
            healthyCount = healthyCount + 1;
        end
    end
    
    return healthyCount;
end

function GetFleeingEnemiesCount(range)
    local enemies = npcBot:GetNearbyHeroes(range, true, BOT_MODE_NONE);
    local fleeingCount = 0;
    
    for _, enemy in pairs(enemies) do
        if enemy:GetActiveMode() == BOT_MODE_RETREAT then
            fleeingCount = fleeingCount + 1;
        end
    end
    
    return fleeingCount;
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