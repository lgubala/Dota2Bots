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

-- Ability references
local abilityQ = nil; -- Lucent Beam
local abilityW = nil; -- Lunar Orbit
local abilityE = nil; -- Moon Glaive (passive)
local abilityR = nil; -- Eclipse

-- Desire values
local castQDesire = 0;
local castWDesire = 0;
local castRDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name (ALWAYS RECOMMENDED)
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("luna_lucent_beam"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("luna_lunar_orbit"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("luna_moon_glaive"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("luna_eclipse"); end

    -- Consider using each ability
    castRDesire, castRTarget, castRType = ConsiderEclipse();
    castQDesire, castQTarget = ConsiderLucentBeam();
    castWDesire = ConsiderLunarOrbit();

    -- Priority order: Ultimate > Interrupt > Nuke > Orbit
    if castRDesire > 0 then
        if castRType == "entity" then
            bot:Action_UseAbilityOnEntity(abilityR, castRTarget);
        elseif castRType == "location" then
            bot:Action_UseAbilityOnLocation(abilityR, castRTarget);
        else
            bot:Action_UseAbility(abilityR);
        end
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityQ, castQTarget);
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbility(abilityW);
        return;
    end
end

function ConsiderLucentBeam()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local nManaCost = abilityQ:GetManaCost();
    local nDamage = abilityQ:GetSpecialValueInt("beam_damage");
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- Save mana for Eclipse if available
    if mutils.CanBeCast(abilityR) and bot:GetMana() < nManaCost + abilityR:GetManaCost() + 50 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    -- INTERRUPT: Channeling enemies (CRITICAL)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end
    
    -- INTERRUPT: TP cancelling
    for _, enemy in pairs(enemies) do
        if enemy:IsUsingAbility() and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end
    
    -- KILLSTEAL: Finish off low HP enemies
    for _, enemy in pairs(enemies) do
        if mutils.CanCastOnNonMagicImmune(enemy) then
            local enemyHealth = mutils.SafeGetHealth(enemy);
            if enemyHealth > 0 and enemyHealth <= nDamage * 0.8 then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end
    
    -- TEAMFIGHT: Use aggressively
    if mutils.IsInTeamFight(bot, 1300) then
        -- Target weakest enemy first
        local weakestEnemy = nil;
        local lowestHealth = 999999;
        
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                local enemyHealth = mutils.SafeGetHealth(enemy);
                if enemyHealth > 0 and enemyHealth < lowestHealth then
                    lowestHealth = enemyHealth;
                    weakestEnemy = enemy;
                end
            end
        end
        
        if weakestEnemy ~= nil then
            return BOT_ACTION_DESIRE_HIGH, weakestEnemy;
        end
    end
    
    -- HARASSMENT: Use in lane aggressively
    if bot:GetActiveMode() == BOT_MODE_LANING and mutils.AllowedToSpam(bot, nManaCost) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end
    
    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           GetUnitToUnitDistance(target, bot) <= nCastRange + 200 then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end
    
    -- DEFENSIVE: When defending and have good mana
    if mutils.IsDefending(bot) and mutils.AllowedToSpam(bot, nManaCost) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end
    
    -- ROSHAN: Use on Roshan
    if bot:GetActiveMode() == BOT_MODE_ROSHAN and mutils.AllowedToSpam(bot, nManaCost) then
        local npcTarget = mutils.SafeGetAttackTarget(bot);
        if mutils.IsRoshan(npcTarget) and mutils.IsInRange(npcTarget, bot, nCastRange) then
            return BOT_ACTION_DESIRE_LOW, npcTarget;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderLunarOrbit()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local nManaCost = abilityW:GetManaCost();
    local nRadius = abilityW:GetSpecialValueInt("rotating_glaives_movement_radius");
    
    local enemies = bot:GetNearbyHeroes(math.min(nRadius + 300, 1600), true, BOT_MODE_NONE);
    
    -- TEAMFIGHT: Use liberally in teamfights
    if mutils.IsInTeamFight(bot, 1300) and #enemies >= 1 then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- OFFENSIVE: Use when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(target, bot) <= nRadius + 200 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- FARMING: Use for farming with good mana
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot) or bot:GetActiveMode() == BOT_MODE_FARM) and 
       mutils.AllowedToSpam(bot, nManaCost) then
        local creeps = bot:GetNearbyLaneCreeps(math.min(nRadius + 200, 1600), true);
        if #creeps >= 3 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- HARASSMENT: Use in lane with good mana
    if bot:GetActiveMode() == BOT_MODE_LANING and mutils.AllowedToSpam(bot, nManaCost) and #enemies >= 1 then
        return BOT_ACTION_DESIRE_MODERATE;
    end
    
    -- DEFENSIVE: Use when being chased
    if mutils.IsRetreating(bot) and #enemies >= 1 and bot:WasRecentlyDamagedByAnyHero(2.0) then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderEclipse()
    if not mutils.CanBeCast(abilityR) then
        return BOT_ACTION_DESIRE_NONE, nil, "";
    end
    
    local nRadius = abilityR:GetSpecialValueInt("radius");
    local hitCount = abilityR:GetSpecialValueInt("hit_count");
    local beamDamage = abilityQ:GetSpecialValueInt("beam_damage");
    local totalDamage = beamDamage * hitCount;
    
    -- Check if we have Scepter
    if bot:HasScepter() then
        local nCastRange = math.min(abilityR:GetSpecialValueInt("AbilityCastRange"), 1600);
        hitCount = 999; -- Scepter removes hit limit
        totalDamage = beamDamage * abilityR:GetSpecialValueInt("beams");
        
        -- SCEPTER: Cast on allies in teamfight
        if mutils.IsInTeamFight(bot, 1300) then
            local allies = bot:GetNearbyHeroes(math.min(nCastRange, 1600), false, BOT_MODE_NONE);
            
            -- Find ally with most enemies nearby
            local bestAlly = nil;
            local maxEnemies = 0;
            
            for _, ally in pairs(allies) do
                local nearbyEnemies = ally:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
                if #nearbyEnemies > maxEnemies then
                    maxEnemies = #nearbyEnemies;
                    bestAlly = ally;
                end
            end
            
            -- Cast on self if we have most enemies
            local ourEnemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
            if #ourEnemies > maxEnemies then
                bestAlly = bot;
                maxEnemies = #ourEnemies;
            end
            
            if bestAlly ~= nil and maxEnemies >= 2 then
                return BOT_ACTION_DESIRE_VERYHIGH, bestAlly, "entity";
            end
        end
        
        -- SCEPTER: Cast on location in teamfight
        if mutils.IsInTeamFight(bot, 1300) then
            local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
            if locationAoE.count >= 2 then
                return BOT_ACTION_DESIRE_VERYHIGH, locationAoE.targetloc, "location";
            end
        end
        
        -- SCEPTER: Cast on single target for guaranteed kill
        if mutils.IsGoingOnSomeone(bot) then
            local target = bot:GetTarget();
            if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
                local enemyHealth = mutils.SafeGetHealth(target);
                local nearbyCreeps = target:GetNearbyCreeps(nRadius, false);
                
                -- If target is isolated or low HP, cast on their location
                if #nearbyCreeps <= 2 and (enemyHealth <= totalDamage * 0.8 or enemyHealth <= target:GetMaxHealth() * 0.5) then
                    return BOT_ACTION_DESIRE_VERYHIGH, target:GetLocation(), "location";
                end
            end
        end
    else
        -- NO SCEPTER: Standard Eclipse
        local enemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        local creeps = bot:GetNearbyCreeps(nRadius, true);
        
        -- SINGLE TARGET ISOLATED: This is where Eclipse shines!
        if #enemies == 1 and #creeps <= 2 then
            local target = enemies[1];
            if mutils.CanCastOnNonMagicImmune(target) then
                local enemyHealth = mutils.SafeGetHealth(target);
                -- Very aggressive - use if enemy is below 80% HP
                if enemyHealth > 0 and enemyHealth <= target:GetMaxHealth() * 0.8 then
                    return BOT_ACTION_DESIRE_VERYHIGH, nil, "notarget";
                end
            end
        end
        
        -- TEAMFIGHT: Multiple enemies with few creeps
        if mutils.IsInTeamFight(bot, 1300) and #enemies >= 2 and #creeps <= 3 then
            return BOT_ACTION_DESIRE_HIGH, nil, "notarget";
        end
        
        -- OFFENSIVE: Going on someone isolated
        if mutils.IsGoingOnSomeone(bot) then
            local target = bot:GetTarget();
            if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
               GetUnitToUnitDistance(target, bot) <= nRadius then
                local nearbyEnemies = target:GetNearbyHeroes(nRadius, false, BOT_MODE_NONE);
                local nearbyCreeps = target:GetNearbyCreeps(nRadius, false);
                
                -- Use if target is relatively isolated
                if #nearbyEnemies <= 1 and #nearbyCreeps <= 3 then
                    local enemyHealth = mutils.SafeGetHealth(target);
                    if enemyHealth > 0 and enemyHealth <= target:GetMaxHealth() * 0.7 then
                        return BOT_ACTION_DESIRE_HIGH, nil, "notarget";
                    end
                end
            end
        end
        
        -- DEFENSIVE: Use when being chased by multiple enemies
        if mutils.IsRetreating(bot) and #enemies >= 2 and #creeps <= 2 and 
           bot:WasRecentlyDamagedByAnyHero(2.0) then
            return BOT_ACTION_DESIRE_HIGH, nil, "notarget";
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil, "";
end