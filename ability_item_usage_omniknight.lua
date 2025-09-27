if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

-- Global variables
local npcBot = nil;
local abilityPU = nil;  -- Purification (Q)
local abilityMA = nil;  -- Martyr (W)
local abilityHP = nil;  -- Hammer of Purity (E)
local abilityDA = nil;  -- Degen Aura (D - Passive)
local abilityGA = nil;  -- Guardian Angel (R)

-- State management for universal fixes
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Omniknight specific state
local lastHealCheck = 0;
local healCheckInterval = 1.0; -- Check for healing opportunities every second
local lastUltimateTime = 0;

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
    if abilityPU == nil then abilityPU = npcBot:GetAbilityByName("omniknight_purification"); end
    if abilityMA == nil then abilityMA = npcBot:GetAbilityByName("omniknight_martyr"); end
    if abilityHP == nil then abilityHP = npcBot:GetAbilityByName("omniknight_hammer_of_purity"); end
    if abilityDA == nil then abilityDA = npcBot:GetAbilityByName("omniknight_degen_aura"); end
    if abilityGA == nil then abilityGA = npcBot:GetAbilityByName("omniknight_guardian_angel"); end

    -- PRIORITY ORDER: Ultimate -> Emergency Heal -> Martyr -> Purification -> Hammer

    -- 1. ULTIMATE: Guardian Angel for team salvation
    local castGADesire, castGALocation = ConsiderGuardianAngel();
    if castGADesire > 0 then
        if castGALocation then
            npcBot:Action_UseAbilityOnLocation(abilityGA, castGALocation);
        else
            npcBot:Action_UseAbility(abilityGA);
        end
        lastUltimateTime = DotaTime();
        return;
    end

    -- 2. EMERGENCY: Martyr for magic immunity
    local castMADesire, castMATarget = ConsiderMartyr();
    if castMADesire >= BOT_ACTION_DESIRE_HIGH then
        npcBot:Action_UseAbilityOnEntity(abilityMA, castMATarget);
        return;
    end

    -- 3. HEAL: Purification for healing + damage
    local castPUDesire, castPUTarget = ConsiderPurification();
    if castPUDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityPU, castPUTarget);
        return;
    end

    -- 4. DAMAGE: Hammer of Purity for slow + nuke
    local castHPDesire, castHPTarget = ConsiderHammerOfPurity();
    if castHPDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityHP, castHPTarget);
        return;
    end

    -- 5. LOWER PRIORITY: Martyr for buffs
    if castMADesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityMA, castMATarget);
        return;
    end
end

function ConsiderPurification()
    if not abilityPU or not abilityPU:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityPU:GetCastRange();
    local nRadius = abilityPU:GetSpecialValueInt("radius");
    local nHeal = abilityPU:GetSpecialValueInt("heal");

    -- EMERGENCY: Self-heal when very low
    if mutil.IsRetreating(npcBot) then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        local enemies = npcBot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        
        if healthPercent < 0.25 and #enemies > 0 then
            return BOT_ACTION_DESIRE_VERYHIGH, npcBot;
        end
    end

    -- CRITICAL ALLY SAVE: Heal dying allies
    local allies = npcBot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
    local criticalAlly = nil;
    local lowestHealth = 9999;

    for _, ally in pairs(allies) do
        if mutil.CanCastOnNonMagicImmune(ally) and ally:IsAlive() then
            local healthPercent = ally:GetHealth() / ally:GetMaxHealth();
            local health = ally:GetHealth();
            
            -- Priority for critically low allies who were recently damaged
            if healthPercent < 0.3 and ally:WasRecentlyDamagedByAnyHero(3.0) then
                if health < lowestHealth then
                    lowestHealth = health;
                    criticalAlly = ally;
                end
            end
        end
    end

    if criticalAlly then
        return BOT_ACTION_DESIRE_VERYHIGH, criticalAlly;
    end

    -- TEAMFIGHT: Heal + AoE damage combo
    if mutil.IsInTeamFight(npcBot, 1200) then
        -- Find ally with enemies nearby for maximum damage
        local bestTarget = nil;
        local maxEnemiesNearby = 0;

        for _, ally in pairs(allies) do
            if mutil.CanCastOnNonMagicImmune(ally) and ally:IsAlive() then
                local healthPercent = ally:GetHealth() / ally:GetMaxHealth();
                local nearbyEnemies = ally:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
                
                -- Prefer injured allies with enemies nearby
                if healthPercent < 0.8 and #nearbyEnemies > maxEnemiesNearby then
                    maxEnemiesNearby = #nearbyEnemies;
                    bestTarget = ally;
                end
            end
        end

        if bestTarget and maxEnemiesNearby >= 1 then
            return BOT_ACTION_DESIRE_HIGH, bestTarget;
        end

        -- Fallback: Heal any injured ally in teamfight
        for _, ally in pairs(allies) do
            if mutil.CanCastOnNonMagicImmune(ally) and ally:IsAlive() then
                local healthPercent = ally:GetHealth() / ally:GetMaxHealth();
                if healthPercent < 0.6 then
                    return BOT_ACTION_DESIRE_MODERATE, ally;
                end
            end
        end
    end

    -- CARRY PRIORITY: Focus on carry heroes
    local carryAlly = GetBestCarryAlly(allies, nHeal);
    if carryAlly then
        return BOT_ACTION_DESIRE_MODERATE, carryAlly;
    end

    -- SELF HEAL: Heal yourself if injured
    local selfHealthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
    if selfHealthPercent < 0.5 and npcBot:WasRecentlyDamagedByAnyHero(3.0) then
        return BOT_ACTION_DESIRE_MODERATE, npcBot;
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderMartyr()
    if not abilityMA or not abilityMA:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityMA:GetCastRange();
    local allies = npcBot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);

    -- EMERGENCY: Magic immunity for silenced/disabled allies
    for _, ally in pairs(allies) do
        if mutil.CanCastOnNonMagicImmune(ally) and ally:IsAlive() then
            -- High priority for disabled carries
            if IsCarryHero(ally) and mutil.IsDisabled(false, ally) then
                return BOT_ACTION_DESIRE_VERYHIGH, ally;
            end
            
            -- Any disabled ally
            if mutil.IsDisabled(false, ally) then
                return BOT_ACTION_DESIRE_HIGH, ally;
            end
        end
    end

    -- EMERGENCY: Self-save when disabled
    if mutil.IsDisabled(false, npcBot) and mutil.CanCastOnNonMagicImmune(npcBot) then
        return BOT_ACTION_DESIRE_VERYHIGH, npcBot;
    end

    -- TEAMFIGHT: Buff carries before engagement
    if mutil.IsInTeamFight(npcBot, 1200) then
        local bestCarry = GetBestCarryForBuff(allies);
        if bestCarry then
            return BOT_ACTION_DESIRE_HIGH, bestCarry;
        end
        
        -- Buff any ally in danger
        for _, ally in pairs(allies) do
            if mutil.CanCastOnNonMagicImmune(ally) and ally:IsAlive() then
                local healthPercent = ally:GetHealth() / ally:GetMaxHealth();
                if healthPercent < 0.5 and ally:WasRecentlyDamagedByAnyHero(2.0) then
                    return BOT_ACTION_DESIRE_MODERATE, ally;
                end
            end
        end
    end

    -- PROACTIVE: Buff carry before fights
    if not mutil.IsRetreating(npcBot) then
        local carryAlly = GetBestCarryForBuff(allies);
        if carryAlly and mutil.IsGoingOnSomeone(carryAlly) then
            return BOT_ACTION_DESIRE_MODERATE, carryAlly;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderHammerOfPurity()
    if not abilityHP or not abilityHP:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityHP:GetCastRange();
    local enemies = npcBot:GetNearbyHeroes(nCastRange + 100, true, BOT_MODE_NONE);

    -- ESCAPE: Slow pursuers when retreating
    if mutil.IsRetreating(npcBot) then
        for _, enemy in pairs(enemies) do
            if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) and 
               mutil.CanCastOnNonMagicImmune(enemy) and
               mutil.IsInRange(enemy, npcBot, nCastRange) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- TEAMFIGHT: Slow key targets
    if mutil.IsInTeamFight(npcBot, 1200) then
        -- Prioritize carries and mobile heroes
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnNonMagicImmune(enemy) and 
               mutil.IsInRange(enemy, npcBot, nCastRange) then
                
                if IsCarryHero(enemy) or IsMobileHero(enemy) then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
        
        -- Any enemy in range
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnNonMagicImmune(enemy) and 
               mutil.IsInRange(enemy, npcBot, nCastRange) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    -- OFFENSIVE: When allies are going on someone
    local allies = npcBot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if mutil.IsGoingOnSomeone(ally) then
            local target = ally:GetTarget();
            if mutil.IsValidTarget(target) and 
               mutil.CanCastOnNonMagicImmune(target) and
               mutil.IsInRange(target, npcBot, nCastRange) then
                return BOT_ACTION_DESIRE_MODERATE, target;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderGuardianAngel()
    if not abilityGA or not abilityGA:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nRadius = abilityGA:GetSpecialValueInt("radius");
    local nCastRange = abilityGA:GetCastRange();
    local hasScepter = npcBot:HasScepter();

    -- EMERGENCY: Save multiple low HP allies
    local criticalAllies = 0;
    local allyCenter = nil;
    
    if hasScepter then
        -- Global cast - find allies anywhere on map
        local allAllies = GetUnitList(UNIT_LIST_ALLIED_HEROES);
        local urgentSaves = {};
        
        for _, ally in pairs(allAllies) do
            if ally:IsAlive() and ally ~= npcBot then
                local healthPercent = ally:GetHealth() / ally:GetMaxHealth();
                if healthPercent < 0.3 and ally:WasRecentlyDamagedByAnyHero(2.0) then
                    table.insert(urgentSaves, ally);
                end
            end
        end
        
        if #urgentSaves >= 2 then
            -- Cast on most critical area
            allyCenter = GetAllyCenter(urgentSaves);
            return BOT_ACTION_DESIRE_VERYHIGH, allyCenter;
        elseif #urgentSaves == 1 and IsCarryHero(urgentSaves[1]) then
            -- Save critical carry
            return BOT_ACTION_DESIRE_VERYHIGH, urgentSaves[1]:GetLocation();
        end
    else
        -- Normal cast range
        local allies = npcBot:GetNearbyHeroes(nCastRange + nRadius, false, BOT_MODE_NONE);
        
        for _, ally in pairs(allies) do
            local healthPercent = ally:GetHealth() / ally:GetMaxHealth();
            if healthPercent < 0.4 and ally:WasRecentlyDamagedByAnyHero(2.0) then
                criticalAllies = criticalAllies + 1;
            end
        end
        
        if criticalAllies >= 2 then
            allyCenter = GetAllyCenter(allies);
            return BOT_ACTION_DESIRE_VERYHIGH, allyCenter;
        end
    end

    -- TEAMFIGHT: Use when team is in danger
    if mutil.IsInTeamFight(npcBot, 1200) then
        local nearbyAllies = npcBot:GetNearbyHeroes(nRadius * 2, false, BOT_MODE_NONE);
        local injuredAllies = 0;
        local enemies = npcBot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        
        for _, ally in pairs(nearbyAllies) do
            local healthPercent = ally:GetHealth() / ally:GetMaxHealth();
            if healthPercent < 0.6 then
                injuredAllies = injuredAllies + 1;
            end
        end
        
        -- Use if multiple allies injured or outnumbered
        if (injuredAllies >= 2) or (#enemies > #nearbyAllies and #nearbyAllies >= 2) then
            allyCenter = GetAllyCenter(nearbyAllies);
            return BOT_ACTION_DESIRE_HIGH, allyCenter or npcBot:GetLocation();
        end
    end

    -- PROACTIVE: Protect carry during important fights
    if not mutil.IsRetreating(npcBot) then
        local importantAllies = {};
        local searchRange = hasScepter and 9999 or nCastRange + nRadius;
        local allies = hasScepter and GetUnitList(UNIT_LIST_ALLIED_HEROES) or 
                       npcBot:GetNearbyHeroes(searchRange, false, BOT_MODE_NONE);
        
        for _, ally in pairs(allies) do
            if ally:IsAlive() and ally ~= npcBot and IsCarryHero(ally) then
                if mutil.IsGoingOnSomeone(ally) or ally:WasRecentlyDamagedByAnyHero(3.0) then
                    table.insert(importantAllies, ally);
                end
            end
        end
        
        if #importantAllies >= 1 then
            allyCenter = GetAllyCenter(importantAllies);
            return BOT_ACTION_DESIRE_MODERATE, allyCenter;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

-- Helper Functions

function GetBestCarryAlly(allies, healAmount)
    local bestCarry = nil;
    local bestScore = 0;
    
    for _, ally in pairs(allies) do
        if mutil.CanCastOnNonMagicImmune(ally) and ally:IsAlive() and IsCarryHero(ally) then
            local healthPercent = ally:GetHealth() / ally:GetMaxHealth();
            local missingHealth = ally:GetMaxHealth() - ally:GetHealth();
            
            -- Score based on how much the heal helps and carry importance
            if healthPercent < 0.8 and missingHealth >= healAmount * 0.5 then
                local score = (1 - healthPercent) * 100; -- Lower health = higher score
                if ally:WasRecentlyDamagedByAnyHero(3.0) then
                    score = score * 1.5; -- Bonus for recently damaged
                end
                
                if score > bestScore then
                    bestScore = score;
                    bestCarry = ally;
                end
            end
        end
    end
    
    return bestCarry;
end

function GetBestCarryForBuff(allies)
    for _, ally in pairs(allies) do
        if mutil.CanCastOnNonMagicImmune(ally) and ally:IsAlive() and IsCarryHero(ally) then
            -- Don't buff if ally already has martyr
            if not ally:HasModifier("modifier_omniknight_martyr") then
                return ally;
            end
        end
    end
    return nil;
end

function IsCarryHero(unit)
    if not unit then return false end
    
    local unitName = unit:GetUnitName();
    local carryNames = {
        "antimage", "phantom_assassin", "faceless_void", "spectre",
        "medusa", "drow_ranger", "sniper", "luna", "gyrocopter",
        "juggernaut", "lifestealer", "wraith_king", "sven",
        "phantom_lancer", "naga_siren", "terrorblade", "morphling",
        "alchemist", "bloodseeker", "huskar", "riki", "clinkz"
    };
    
    for _, carryName in pairs(carryNames) do
        if string.find(unitName, carryName) then
            return true;
        end
    end
    
    return false;
end

function IsMobileHero(unit)
    if not unit then return false end
    
    local unitName = unit:GetUnitName();
    local mobileNames = {
        "antimage", "queen_of_pain", "storm_spirit", "ember_spirit",
        "void_spirit", "puck", "faceless_void", "weaver", "riki",
        "phantom_assassin", "slark", "spirit_breaker"
    };
    
    for _, mobileName in pairs(mobileNames) do
        if string.find(unitName, mobileName) then
            return true;
        end
    end
    
    return false;
end

function GetAllyCenter(allies)
    if #allies == 0 then return nil end
    
    local sumX, sumY = 0, 0;
    local validAllies = 0;
    
    for _, ally in pairs(allies) do
        if ally:IsAlive() then
            local pos = ally:GetLocation();
            sumX = sumX + pos.x;
            sumY = sumY + pos.y;
            validAllies = validAllies + 1;
        end
    end
    
    if validAllies == 0 then return nil end
    
    return Vector(sumX / validAllies, sumY / validAllies, 0);
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