if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

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

local bot = GetBot();

local abilityShrapnel = nil;
local abilityTakeAim = nil;
local abilityAssassinate = nil;
local abilityGrenade = nil;

local castShrapnelDesire = 0;
local castTakeAimDesire = 0;
local castAssassinateDesire = 0;
local castGrenadeDesire = 0;

-- Shrapnel tracking system
local shrapnelLocations = {};
local shrapnelCastTime = 0;
local shrapnelDelay = 1.5;
local shrapnelRadius = 0;
local shrapnelDuration = 0;

-- Safety constants
local DANGER_RANGE = 650; -- Max range we allow enemies to get close
local PANIC_RANGE = 400;  -- Emergency range - must escape immediately

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        -- Emergency: Cancel ultimate if enemy gets too close while channeling
        local nearbyEnemies = bot:GetNearbyHeroes(PANIC_RANGE, true, BOT_MODE_NONE);
        if #nearbyEnemies > 0 then
            bot:Action_ClearActions(false);
        end
        return;
    end

    -- Initialize abilities by name
    if abilityShrapnel == nil then abilityShrapnel = bot:GetAbilityByName("sniper_shrapnel"); end
    if abilityTakeAim == nil then abilityTakeAim = bot:GetAbilityByName("sniper_take_aim"); end
    if abilityAssassinate == nil then abilityAssassinate = bot:GetAbilityByName("sniper_assassinate"); end
    if abilityGrenade == nil then abilityGrenade = bot:GetAbilityByName("sniper_concussive_grenade"); end

    -- Clean up dead shrapnel locations
    CleanupShrapnelLocations();

    -- CRITICAL: Check positioning safety first
    local closestEnemy, closestDistance = GetClosestEnemyHero();
    if closestEnemy ~= nil then
        -- Emergency escape with grenade if available
        if closestDistance < PANIC_RANGE then
            castGrenadeDesire, castGrenadeLocation = ConsiderGrenade();
            if castGrenadeDesire > 0 then
                bot:Action_UseAbilityOnLocation(abilityGrenade, castGrenadeLocation);
                return;
            end
        end
        
        -- Don't use Take Aim if enemy is too close (would get caught)
        if closestDistance < DANGER_RANGE and abilityTakeAim ~= nil and not abilityTakeAim:IsHidden() then
            if bot:HasModifier("modifier_sniper_take_aim_bonus") then
                -- Already slowed, try to maintain distance
            end
        end
    end

    -- Consider using each ability
    castGrenadeDesire, castGrenadeLocation = ConsiderGrenade();
    castAssassinateDesire, castAssassinateTarget = ConsiderAssassinate();
    castTakeAimDesire = ConsiderTakeAim();
    castShrapnelDesire, castShrapnelLocation = ConsiderShrapnel();

    -- Priority: Grenade (escape) > Assassinate > Shrapnel > Take Aim
    if castGrenadeDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityGrenade, castGrenadeLocation);
        return;
    end

    if castAssassinateDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityAssassinate, castAssassinateTarget);
        return;
    end

    if castShrapnelDesire > 0 then
        shrapnelCastTime = DotaTime();
        table.insert(shrapnelLocations, {time = DotaTime(), location = castShrapnelLocation});
        bot:Action_UseAbilityOnLocation(abilityShrapnel, castShrapnelLocation);
        return;
    end

    if castTakeAimDesire > 0 then
        bot:Action_UseAbility(abilityTakeAim);
        return;
    end
end

function GetClosestEnemyHero()
    local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
    local closestEnemy = nil;
    local closestDistance = 999999;
    
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) then
            local distance = GetUnitToUnitDistance(bot, enemy);
            if distance < closestDistance then
                closestDistance = distance;
                closestEnemy = enemy;
            end
        end
    end
    
    return closestEnemy, closestDistance;
end

function CleanupShrapnelLocations()
    if not bot:IsAlive() then
        shrapnelLocations = {};
        return;
    end
    
    for i = #shrapnelLocations, 1, -1 do
        if DotaTime() > shrapnelLocations[i].time + shrapnelDuration then
            table.remove(shrapnelLocations, i);
        end
    end
end

function IsLocationCoveredByShrapnel(targetLocation)
    for _, shrap in pairs(shrapnelLocations) do
        local distance = GetUnitToLocationDistance(bot, shrap.location);
        if distance <= 1.75 * shrapnelRadius then
            return true;
        end
    end
    return false;
end

function ConsiderShrapnel()
    if not mutils.CanBeCast(abilityShrapnel) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Don't cast too quickly after last cast
    if DotaTime() <= shrapnelCastTime + shrapnelDelay then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityShrapnel:GetCastRange(), 1600);
    local nManaCost = abilityShrapnel:GetManaCost();
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    
    shrapnelRadius = abilityShrapnel:GetSpecialValueInt("radius");
    shrapnelDelay = abilityShrapnel:GetSpecialValueFloat("damage_delay") + abilityShrapnel:GetCastPoint();
    shrapnelDuration = abilityShrapnel:GetSpecialValueInt("duration");

    -- Get charge count
    local chargeCount = 0;
    local modIndex = bot:GetModifierByName("modifier_sniper_shrapnel_charge_counter");
    if modIndex > -1 then
        chargeCount = bot:GetModifierStackCount(modIndex);
    end

    -- ESCAPE: Slow enemies chasing us
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
        local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        if #enemies > 0 then
            -- Place behind us to slow pursuers
            return BOT_ACTION_DESIRE_VERYHIGH, bot:GetLocation();
        end
    end

    -- TEAMFIGHT: AOE damage and vision
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, shrapnelRadius, 0, 0);
        if locationAoE.count >= 2 then
            local targetLoc = locationAoE.targetloc;
            if not IsLocationCoveredByShrapnel(targetLoc) then
                return BOT_ACTION_DESIRE_HIGH, targetLoc;
            end
        end
        
        -- Illuminate uphill/fog areas in fights
        local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) then
                local enemyLoc = enemy:GetLocation();
                if not IsLocationCoveredByShrapnel(enemyLoc) and not enemy:HasModifier("modifier_sniper_shrapnel_slow") then
                    return BOT_ACTION_DESIRE_HIGH, enemyLoc;
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= nCastRange then
                local targetLoc = target:GetLocation();
                if not IsLocationCoveredByShrapnel(targetLoc) and not target:HasModifier("modifier_sniper_shrapnel_slow") then
                    return BOT_ACTION_DESIRE_HIGH, targetLoc;
                end
            end
        end
    end

    -- DEFENDING: Wave clear with extra charges
    if mutils.IsDefending(bot) and chargeCount > 2 and manaPercent > 0.5 then
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, shrapnelRadius, 0, 0);
        if locationAoE.count >= 3 then
            local targetLoc = locationAoE.targetloc;
            if not IsLocationCoveredByShrapnel(targetLoc) then
                return BOT_ACTION_DESIRE_MODERATE, targetLoc;
            end
        end
    end

    -- PUSHING: Wave clear with extra charges
    if mutils.IsPushing(bot) and chargeCount > 2 and manaPercent > 0.5 then
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, shrapnelRadius, 0, 0);
        if locationAoE.count >= 3 then
            local targetLoc = locationAoE.targetloc;
            if not IsLocationCoveredByShrapnel(targetLoc) then
                return BOT_ACTION_DESIRE_MODERATE, targetLoc;
            end
        end
    end

    -- LANING: Harass with extra charges
    if bot:GetActiveMode() == BOT_MODE_LANING and chargeCount > 2 and manaPercent > 0.6 then
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, shrapnelRadius, 0, 0);
        if locationAoE.count >= 4 then
            local targetLoc = locationAoE.targetloc;
            if not IsLocationCoveredByShrapnel(targetLoc) then
                return BOT_ACTION_DESIRE_LOW, targetLoc;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTakeAim()
    if not mutils.CanBeCast(abilityTakeAim) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local bonusRange = abilityTakeAim:GetSpecialValueInt("active_attack_range_bonus");
    local duration = abilityTakeAim:GetSpecialValueInt("duration");

    -- Safety check: Don't use if enemies too close (we get slowed!)
    local closestEnemy, closestDistance = GetClosestEnemyHero();
    if closestEnemy ~= nil and closestDistance < DANGER_RANGE then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- OFFENSIVE: Extended range for attacking
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            local attackRange = bot:GetAttackRange();
            
            -- Use if target is just out of range but within Take Aim range
            if distance > attackRange and distance <= attackRange + bonusRange then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderAssassinate()
    if not mutils.CanBeCast(abilityAssassinate) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityAssassinate:GetCastRange(), 2800); -- Max for safety
    local nDamage = abilityAssassinate:GetAbilityDamage();
    local nDamageType = abilityAssassinate:GetDamageType();
    local hasScepter = bot:HasScepter();

    -- WITH SCEPTER: Aggressive usage (stun, interrupt, initiate)
    if hasScepter then
        local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
        
        -- Interrupt channeling (HIGHEST PRIORITY)
        for _, enemy in pairs(enemies) do
            if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
        
        -- Cancel TP
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and enemy:IsChanneling() then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
        
        -- TEAMFIGHT: Stun priority targets
        if mutils.IsInTeamFight(bot, 1200) then
            for _, enemy in pairs(enemies) do
                if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                    -- Prioritize dangerous enemies or low HP
                    local healthPercent = mutils.SafeGetHealthPercent(enemy);
                    if healthPercent < 0.5 or enemy:IsChanneling() then
                        return BOT_ACTION_DESIRE_HIGH, enemy;
                    end
                end
            end
            
            -- Any valid target in teamfight
            if #enemies > 0 then
                return BOT_ACTION_DESIRE_MODERATE, enemies[1];
            end
        end
        
        -- OFFENSIVE: Initiate or stun target
        if mutils.IsGoingOnSomeone(bot) then
            local target = bot:GetTarget();
            if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
    end

    -- WITHOUT SCEPTER: Kill shot only
    -- Global check for killable enemies
    local allEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
    for _, enemy in pairs(allEnemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            local distance = GetUnitToUnitDistance(bot, enemy);
            if distance <= nCastRange then
                local enemyHealth = mutils.SafeGetHealth(enemy);
                local actualDamage = enemy:GetActualIncomingDamage(nDamage, nDamageType);
                
                -- Kill shot on fleeing/low HP enemy
                if enemyHealth > 0 and enemyHealth <= actualDamage then
                    return BOT_ACTION_DESIRE_VERYHIGH, enemy;
                end
            end
        end
    end

    -- OFFENSIVE: Harass low HP target (even without kill)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= nCastRange then
                local healthPercent = mutils.SafeGetHealthPercent(target);
                if healthPercent < 0.4 then
                    return BOT_ACTION_DESIRE_MODERATE, target;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderGrenade()
    -- Shard check: ability exists and not hidden
    if abilityGrenade == nil or not mutils.CanBeCast(abilityGrenade) or abilityGrenade:IsHidden() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityGrenade:GetCastRange(), 1600);
    local nRadius = abilityGrenade:GetSpecialValueInt("radius");

    -- EMERGENCY ESCAPE: Enemy too close
    local enemies = bot:GetNearbyHeroes(PANIC_RANGE, true, BOT_MODE_NONE);
    if #enemies > 0 then
        -- Throw grenade at closest enemy to push them away
        local closestEnemy = enemies[1];
        for _, enemy in pairs(enemies) do
            if GetUnitToUnitDistance(bot, enemy) < GetUnitToUnitDistance(bot, closestEnemy) then
                closestEnemy = enemy;
            end
        end
        return BOT_ACTION_DESIRE_VERYHIGH, closestEnemy:GetLocation();
    end

    -- DEFENSIVE: Retreating and enemies closing in
    if mutils.IsRetreating(bot) then
        enemies = bot:GetNearbyHeroes(DANGER_RANGE, true, BOT_MODE_NONE);
        if #enemies > 0 and bot:WasRecentlyDamagedByAnyHero(2.0) then
            return BOT_ACTION_DESIRE_HIGH, enemies[1]:GetLocation();
        end
    end

    -- OFFENSIVE: AOE damage in teamfights
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end