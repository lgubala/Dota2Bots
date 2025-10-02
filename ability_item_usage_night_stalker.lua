if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile(GetScriptDirectory().."/ability_item_usage_generic")
local utils = require(GetScriptDirectory() .. "/util")
local mutils = require(GetScriptDirectory() .. "/MyUtility")

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

-- Ability variables
local abilityVoid = nil;
local abilityCripplingFear = nil;
local abilityHunter = nil;
local abilityDarkness = nil;

local castVoidDes = 0;
local castFearDes = 0;
local castHunterDes = 0;
local castDarknessDes = 0;

-- Scepter toggle management
local lastToggleTime = 0;
local toggleCooldown = 0.5;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityVoid == nil then abilityVoid = bot:GetAbilityByName("night_stalker_void"); end
    if abilityCripplingFear == nil then abilityCripplingFear = bot:GetAbilityByName("night_stalker_crippling_fear"); end
    if abilityHunter == nil then abilityHunter = bot:GetAbilityByName("night_stalker_hunter_in_the_night"); end
    if abilityDarkness == nil then abilityDarkness = bot:GetAbilityByName("night_stalker_darkness"); end

    -- Manage Crippling Fear toggle (Scepter)
    if bot:HasScepter() and abilityCripplingFear ~= nil then
        ManageCripplingFearToggle();
    end

    -- Consider abilities
    castDarknessDes = ConsiderDarkness();
    castHunterDes, castHunterTarget = ConsiderHunterShard();
    castFearDes = ConsiderCripplingFear();
    castVoidDes, castVoidTarget = ConsiderVoid();

    -- Priority: Ultimate > Hunter (heal) > Void > Fear
    if castDarknessDes > 0 then
        bot:Action_UseAbility(abilityDarkness);
        return;
    end

    if castHunterDes > 0 then
        bot:Action_UseAbilityOnEntity(abilityHunter, castHunterTarget);
        return;
    end

    if castVoidDes > 0 then
        bot:Action_UseAbilityOnEntity(abilityVoid, castVoidTarget);
        return;
    end

    if castFearDes > 0 then
        bot:Action_UseAbility(abilityCripplingFear);
        return;
    end
end

-- Helper function to check if it's night time
local function IsNightTime()
    return GetTimeOfDay() == 0.0 or bot:HasModifier("modifier_night_stalker_darkness");
end

function ManageCripplingFearToggle()
    if not bot:HasScepter() or abilityCripplingFear == nil then return end
    if DotaTime() - lastToggleTime < toggleCooldown then return end

    local isToggled = bot:HasModifier("modifier_night_stalker_crippling_fear");
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    
    -- Turn OFF if low on mana or no enemies nearby
    if isToggled then
        if manaPercent < 0.3 then
            bot:Action_UseAbility(abilityCripplingFear);
            lastToggleTime = DotaTime();
            return;
        end
        
        local enemies = bot:GetNearbyHeroes(math.min(400, 1600), true, BOT_MODE_NONE);
        if #enemies == 0 and not mutils.IsInTeamFight(bot, 1200) then
            bot:Action_UseAbility(abilityCripplingFear);
            lastToggleTime = DotaTime();
            return;
        end
    end
    
    -- Turn ON if enemies nearby and good mana
    if not isToggled and manaPercent > 0.5 then
        local enemies = bot:GetNearbyHeroes(math.min(375, 1600), true, BOT_MODE_NONE);
        if #enemies > 0 or mutils.IsInTeamFight(bot, 1200) then
            if abilityCripplingFear:IsFullyCastable() then
                bot:Action_UseAbility(abilityCripplingFear);
                lastToggleTime = DotaTime();
                return;
            end
        end
    end
end

function ConsiderVoid()
    if not mutils.CanBeCast(abilityVoid) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityVoid:GetCastRange(), 1600);
    local hasScepter = bot:HasScepter();

    -- INTERRUPT CHANNELING/TP (Highest priority - only at night when it mini-stuns)
    if IsNightTime() then
        local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end

    -- ROSHAN
    if bot:GetActiveMode() == BOT_MODE_ROSHAN then
        local target = bot:GetTarget();
        if mutils.IsRoshan(target) and mutils.CanCastOnMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
            return BOT_ACTION_DESIRE_LOW, target;
        end
    end

    -- RETREATING: Slow pursuers
    if mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- TEAMFIGHT: Target most dangerous enemy
    if mutils.IsInTeamFight(bot, 1200) then
        local mostDangerous = nil;
        local maxDamage = 0;
        
        local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                local damage = mutils.SafeGetEstimatedDamageToTarget(enemy, false, bot, 3.0, DAMAGE_TYPE_ALL);
                if damage > maxDamage then
                    maxDamage = damage;
                    mostDangerous = enemy;
                end
            end
        end
        
        if mostDangerous ~= nil then
            return BOT_ACTION_DESIRE_HIGH, mostDangerous;
        end
    end

    -- GOING ON SOMEONE: Always use
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange + 200) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderCripplingFear()
    -- Don't manually cast if Scepter toggle is active
    if bot:HasScepter() then
        return BOT_ACTION_DESIRE_NONE;
    end

    if not mutils.CanBeCast(abilityCripplingFear) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityCripplingFear:GetSpecialValueInt("radius");

    -- INTERRUPT CHANNELING
    local enemies = bot:GetNearbyHeroes(math.min(nRadius, 1600), true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end

    -- RETREATING: Silence chasers
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    -- TEAMFIGHT: Multiple enemies
    if mutils.IsInTeamFight(bot, 1200) then
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- GOING ON SOMEONE: Silence target
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nRadius) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderHunterShard()
    -- Check if ability is castable (shard makes it active)
    if abilityHunter == nil or not abilityHunter:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = 125; -- From ability values
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    
    -- Only use if missing health or mana
    if healthPercent > 0.8 and manaPercent > 0.8 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- PRIORITIZE ENEMY CREEPS
    local enemyCreeps = bot:GetNearbyLaneCreeps(math.min(nCastRange + 50, 1600), true);
    for _, creep in pairs(enemyCreeps) do
        if creep ~= nil and creep:CanBeSeen() and not creep:IsAncientCreep() then
            if healthPercent < 0.6 or manaPercent < 0.6 then
                return BOT_ACTION_DESIRE_HIGH, creep;
            end
        end
    end

    -- ALLIED CREEPS (only if no enemy creeps and really need heal)
    if healthPercent < 0.4 or manaPercent < 0.4 then
        local alliedCreeps = bot:GetNearbyLaneCreeps(math.min(nCastRange + 50, 1600), false);
        for _, creep in pairs(alliedCreeps) do
            if creep ~= nil and creep:CanBeSeen() then
                return BOT_ACTION_DESIRE_MODERATE, creep;
            end
        end
    end

    -- NEUTRAL CREEPS
    local neutrals = bot:GetNearbyNeutralCreeps(math.min(nCastRange + 50, 1600));
    for _, neutral in pairs(neutrals) do
        if neutral ~= nil and neutral:CanBeSeen() then
            -- Can't target ancients during daytime
            if IsNightTime() or not neutral:IsAncientCreep() then
                if healthPercent < 0.6 or manaPercent < 0.6 then
                    return BOT_ACTION_DESIRE_HIGH, neutral;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderDarkness()
    if not mutils.CanBeCast(abilityDarkness) then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- PRIMARY USE: During daytime for night bonuses
    if not IsNightTime() then
        -- Use in teamfights during day
        if mutils.IsInTeamFight(bot, 1200) then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
        
        -- Use when going on someone during day
        if mutils.IsGoingOnSomeone(bot) then
            local target = bot:GetTarget();
            if mutils.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) <= 1200 then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
        
        -- Use when retreating during day with enemies close
        if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
            local enemies = bot:GetNearbyHeroes(math.min(800, 1600), true, BOT_MODE_NONE);
            if #enemies > 0 then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end
    
    -- EMERGENCY USE at night: Big teamfight or need bonus damage
    if IsNightTime() then
        if mutils.IsInTeamFight(bot, 1200) then
            local enemies = bot:GetNearbyHeroes(math.min(1200, 1600), true, BOT_MODE_NONE);
            if #enemies >= 3 then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end