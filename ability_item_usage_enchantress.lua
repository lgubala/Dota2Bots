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
local abilityImpetus = nil;
local abilityEnchant = nil;
local abilityAttendants = nil;
local abilityBunnyHop = nil;
local abilityLittleFriends = nil;

local castImpetusDes = 0;
local castEnchantDes = 0;
local castAttendantsDes = 0;
local castBunnyHopDes = 0;
local castLittleFriendsDes = 0;

function AbilityUsageThink()
    
    -- Essential protection only
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityImpetus == nil then abilityImpetus = bot:GetAbilityByName("enchantress_impetus"); end
    if abilityEnchant == nil then abilityEnchant = bot:GetAbilityByName("enchantress_enchant"); end
    if abilityAttendants == nil then abilityAttendants = bot:GetAbilityByName("enchantress_natures_attendants"); end
    if abilityBunnyHop == nil then abilityBunnyHop = bot:GetAbilityByName("enchantress_bunny_hop"); end
    if abilityLittleFriends == nil then abilityLittleFriends = bot:GetAbilityByName("enchantress_little_friends"); end

    -- Consider using each ability
    castImpetusDes, castImpetusTarget = ConsiderImpetus();
    castEnchantDes, castEnchantTarget = ConsiderEnchant();
    castAttendantsDes = ConsiderAttendants();
    castBunnyHopDes = ConsiderBunnyHop();
    castLittleFriendsDes, castLittleFriendsTarget = ConsiderLittleFriends();

    -- Priority: Scepter ability > Bunny Hop (escape) > Heal > Enchant > Impetus
    if castLittleFriendsDes > 0 then
        bot:Action_UseAbilityOnEntity(abilityLittleFriends, castLittleFriendsTarget);
        return;
    end

    if castBunnyHopDes > 0 then
        bot:Action_UseAbility(abilityBunnyHop);
        return;
    end

    if castAttendantsDes > 0 then
        bot:Action_UseAbility(abilityAttendants);
        return;
    end

    if castEnchantDes > 0 then
        bot:Action_UseAbilityOnEntity(abilityEnchant, castEnchantTarget);
        return;
    end

    if castImpetusDes > 0 then
        bot:Action_UseAbilityOnEntity(abilityImpetus, castImpetusTarget);
        return;
    end
end

function ConsiderImpetus()
    if not mutils.CanBeCast(abilityImpetus) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityImpetus:GetCastRange(), 1600);
    local nAttackRange = bot:GetAttackRange();
    local nManaCost = abilityImpetus:GetManaCost();
    
    -- Only use if target is far enough (at least half cast range for decent damage)
    local minEffectiveRange = nCastRange * 0.5;

    -- Laning harass
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance >= minEffectiveRange and distance <= nAttackRange + 200 then
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
    end

    -- Teamfight usage - prioritize distant targets
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(nAttackRange + 200, 1600), true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnMagicImmune(enemy) then
                local distance = GetUnitToUnitDistance(bot, enemy);
                if distance >= minEffectiveRange then
                    return BOT_ACTION_DESIRE_MODERATE, enemy;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderEnchant()
    if not mutils.CanBeCast(abilityEnchant) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityEnchant:GetCastRange(), 1600);

    -- Enchant neutral creeps for control
    local neutrals = bot:GetNearbyNeutralCreeps(math.min(nCastRange, 1600));
    if #neutrals > 0 then
        local maxHP = 0;
        local bestCreep = nil;
        for _, neutral in pairs(neutrals) do
            if not neutral:IsAncientCreep() and neutral:GetHealth() > maxHP then
                bestCreep = neutral;
                maxHP = neutral:GetHealth();
            end
        end
        if bestCreep ~= nil then
            return BOT_ACTION_DESIRE_LOW, bestCreep;
        end
    end

    -- Retreating - slow pursuers
    if mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- Chasing - slow target
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange + 200) then
            return BOT_ACTION_DESIRE_MODERATE, target;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderAttendants()
    if not mutils.CanBeCast(abilityAttendants) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    
    -- Use when low on health
    if healthPercent < 0.5 and bot:WasRecentlyDamagedByAnyHero(2.0) then
        return BOT_ACTION_DESIRE_HIGH;
    end

    -- Save nearby low HP allies
    local allies = bot:GetNearbyHeroes(275, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if ally:GetHealth() / ally:GetMaxHealth() < 0.4 and ally:WasRecentlyDamagedByAnyHero(2.0) then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- Teamfight sustain
    if mutils.IsInTeamFight(bot, 1200) and healthPercent < 0.6 then
        return BOT_ACTION_DESIRE_MODERATE;
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderBunnyHop()
    -- Check if ability is available (shard check)
    if abilityBunnyHop == nil or abilityBunnyHop:IsHidden() or not abilityBunnyHop:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nAttackRange = bot:GetAttackRange();
    
    -- Retreating - ONLY use if facing enemies (to jump away from them)
    if mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(math.min(nAttackRange + 200, 1600), true, BOT_MODE_NONE);
        if #enemies > 0 then
            -- Check if facing any nearby enemy
            for _, enemy in pairs(enemies) do
                if bot:IsFacingUnit(enemy, 45) and bot:WasRecentlyDamagedByHero(enemy, 2.0) then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end

    -- Teamfight - create distance when pressured
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(nAttackRange / 2, 1600), true, BOT_MODE_NONE);
        if #enemies > 0 and bot:WasRecentlyDamagedByAnyHero(1.0) then
            -- Check facing
            for _, enemy in pairs(enemies) do
                if bot:IsFacingUnit(enemy, 45) then
                    return BOT_ACTION_DESIRE_MODERATE;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderLittleFriends()
    -- Scepter ability check
    if not bot:HasScepter() or not mutils.CanBeCast(abilityLittleFriends) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityLittleFriends:GetCastRange(), 1600);

    -- Teamfight usage
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- Root escaping enemies
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange + 200) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end