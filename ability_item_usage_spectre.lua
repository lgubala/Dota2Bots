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

local abilityDagger = nil;
local abilityDispersion = nil;
local abilityReality = nil;
local abilityHauntSingle = nil;
local abilityHaunt = nil;

local castDaggerDesire = 0;
local castDispersionDesire = 0;
local castRealityDesire = 0;
local castHauntSingleDesire = 0;
local castHauntDesire = 0;

-- Haunt tracking
local hauntCastTime = 0;
local hauntDuration = 6.0;
local realitySwapTime = 0;
local originalLocation = nil;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityDagger == nil then abilityDagger = bot:GetAbilityByName("spectre_spectral_dagger"); end
    if abilityDispersion == nil then abilityDispersion = bot:GetAbilityByName("spectre_dispersion"); end
    if abilityReality == nil then abilityReality = bot:GetAbilityByName("spectre_reality"); end
    if abilityHauntSingle == nil then abilityHauntSingle = bot:GetAbilityByName("spectre_haunt_single"); end
    if abilityHaunt == nil then abilityHaunt = bot:GetAbilityByName("spectre_haunt"); end

    -- Update haunt duration
    if abilityHauntSingle ~= nil then
        hauntDuration = abilityHauntSingle:GetSpecialValueFloat("duration");
    end

    -- Check if haunt expired
    if hauntCastTime > 0 and DotaTime() - hauntCastTime > hauntDuration then
        hauntCastTime = 0;
        originalLocation = nil;
    end

    -- Consider using each ability
    castHauntDesire = ConsiderHaunt();
    castHauntSingleDesire, castHauntSingleTarget = ConsiderHauntSingle();
    castRealityDesire, castRealityLocation = ConsiderReality();
    castDispersionDesire = ConsiderDispersion();
    castDaggerDesire, castDaggerTarget, castDaggerType = ConsiderDagger();

    -- Priority: Haunt (global) > Reality (swap) > Haunt Single > Dispersion > Dagger
    if castHauntDesire > 0 then
        bot:Action_UseAbility(abilityHaunt);
        hauntCastTime = DotaTime();
        originalLocation = bot:GetLocation();
        return;
    end

    if castRealityDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityReality, castRealityLocation);
        realitySwapTime = DotaTime();
        return;
    end

    if castHauntSingleDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityHauntSingle, castHauntSingleTarget);
        hauntCastTime = DotaTime();
        originalLocation = bot:GetLocation();
        return;
    end

    if castDispersionDesire > 0 then
        bot:Action_UseAbility(abilityDispersion);
        return;
    end

    if castDaggerDesire > 0 then
        if castDaggerType == "entity" then
            bot:Action_UseAbilityOnEntity(abilityDagger, castDaggerTarget);
        else
            bot:Action_UseAbilityOnLocation(abilityDagger, castDaggerTarget);
        end
        return;
    end
end

function ConsiderDagger()
    if not mutils.CanBeCast(abilityDagger) then
        return BOT_ACTION_DESIRE_NONE, nil, "";
    end

    local nCastRange = math.min(abilityDagger:GetCastRange(), 1600);
    local nDamage = abilityDagger:GetSpecialValueInt("damage");
    local manaPercent = bot:GetMana() / bot:GetMaxMana();

    -- ESCAPE: Throw dagger in escape direction for pathing
    if mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
        if #enemies > 0 and bot:WasRecentlyDamagedByAnyHero(2.0) then
            local escapeLoc = mutils.GetEscapeLoc();
            -- Throw toward escape location for shadow path
            local daggerLoc = bot:GetXUnitsTowardsLocation(escapeLoc, nCastRange);
            return BOT_ACTION_DESIRE_HIGH, daggerLoc, "location";
        end
    end

    -- STUCK: Get through terrain
    if mutils.IsStuck(bot) then
        local escapeLoc = mutils.GetEscapeLoc();
        local daggerLoc = bot:GetXUnitsTowardsLocation(escapeLoc, nCastRange / 2);
        return BOT_ACTION_DESIRE_HIGH, daggerLoc, "location";
    end

    -- TEAMFIGHT: Slow multiple enemies
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if not enemy:HasModifier("modifier_spectre_spectral_dagger") then
                    return BOT_ACTION_DESIRE_HIGH, enemy, "entity";
                end
            end
        end
    end

    -- OFFENSIVE: Chase target with dagger
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= nCastRange + 200 then
                if not target:HasModifier("modifier_spectre_spectral_dagger") then
                    return BOT_ACTION_DESIRE_HIGH, target, "entity";
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil, "";
end

function ConsiderDispersion()
    -- Check if shard active version exists
    if abilityDispersion == nil or not mutils.CanBeCast(abilityDispersion) then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Shard check: if ability has cooldown value, it's the active version
    local cooldown = abilityDispersion:GetCooldown();
    if cooldown == 0 then
        -- Passive version, can't activate
        return BOT_ACTION_DESIRE_NONE;
    end

    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();

    -- TEAMFIGHT: Boost reflection in fights
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= 600 then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end

    -- DEFENSIVE: Taking damage
    if healthPercent < 0.6 and bot:WasRecentlyDamagedByAnyHero(2.0) then
        local enemies = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies > 0 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- ESCAPE: Boost reflection when retreating
    if mutils.IsRetreating(bot) and healthPercent < 0.5 then
        local enemies = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies > 0 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderHauntSingle()
    if not mutils.CanBeCast(abilityHauntSingle) or hauntCastTime > 0 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Find isolated or low HP enemies
    local allEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
    local bestTarget = nil;
    local bestScore = 0;

    for _, enemy in pairs(allEnemies) do
        if mutils.IsValidTarget(enemy) and enemy:CanBeSeen() then
            local enemyHealthPercent = mutils.SafeGetHealthPercent(enemy);
            local nearbyAllies = enemy:GetNearbyHeroes(500, false, BOT_MODE_NONE);
            
            local score = 0;
            
            -- Low HP is priority
            if enemyHealthPercent < 0.4 then
                score = score + 50;
            elseif enemyHealthPercent < 0.6 then
                score = score + 30;
            end
            
            -- Isolated enemies are priority
            if #nearbyAllies == 0 then
                score = score + 40;
            elseif #nearbyAllies == 1 then
                score = score + 20;
            end
            
            -- Not in fountain
            local distance = GetUnitToUnitDistance(bot, enemy);
            if distance > 3000 then
                score = score + 20;
            end
            
            if score > bestScore then
                bestScore = score;
                bestTarget = enemy;
            end
        end
    end

    -- Use if we found a good target
    if bestTarget ~= nil and bestScore >= 40 then
        return BOT_ACTION_DESIRE_HIGH, bestTarget;
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderHaunt()
    -- Scepter ability
    if abilityHaunt == nil or not mutils.CanBeCast(abilityHaunt) or abilityHaunt:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end

    if hauntCastTime > 0 then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- TEAMFIGHT: Use on all enemies
    if mutils.IsInTeamFight(bot, 1400) then
        local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- GLOBAL PRESSURE: Enemies not visible (farming/split)
    local visibleEnemies = 0;
    local allEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
    for _, enemy in pairs(allEnemies) do
        if enemy:CanBeSeen() then
            visibleEnemies = visibleEnemies + 1;
        end
    end

    -- If most enemies are hidden, use haunt for global pressure
    if visibleEnemies <= 2 then
        return BOT_ACTION_DESIRE_MODERATE;
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderReality()
    if abilityReality == nil or not mutils.CanBeCast(abilityReality) or hauntCastTime == 0 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Check haunt still active
    if DotaTime() - hauntCastTime > hauntDuration then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local timeRemaining = hauntDuration - (DotaTime() - hauntCastTime);
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();

    -- INITIAL JUMP: Jump to low HP target
    if realitySwapTime == 0 or DotaTime() - realitySwapTime > 2.0 then
        local allEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
        
        for _, enemy in pairs(allEnemies) do
            if mutils.IsValidTarget(enemy) and enemy:CanBeSeen() then
                local enemyHealthPercent = mutils.SafeGetHealthPercent(enemy);
                local nearbyEnemyAllies = enemy:GetNearbyHeroes(500, false, BOT_MODE_NONE);
                
                -- Jump to isolated low HP enemy
                if enemyHealthPercent < 0.5 and #nearbyEnemyAllies <= 1 then
                    return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
                end
            end
        end
    end

    -- RETURN HOME: Jump back before haunt expires or if in danger
    if timeRemaining < 1.5 or (healthPercent < 0.3 and bot:WasRecentlyDamagedByAnyHero(1.0)) then
        if originalLocation ~= nil then
            return BOT_ACTION_DESIRE_VERYHIGH, originalLocation;
        end
    end

    -- KILL CONFIRMED: Enemy died, jump back early
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if target == nil or not target:IsAlive() then
            if originalLocation ~= nil and timeRemaining > 1.0 then
                return BOT_ACTION_DESIRE_HIGH, originalLocation;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end