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

local abilitySwarm = nil;
local abilityShukuchi = nil;
local abilityGeminate = nil;
local abilityTimeLapse = nil;

local castSwarmDesire = 0;
local castShukuchiDesire = 0;
local castTimeLapseDesire = 0;

local geminateAutoCastEnabled = false;
local lastHealthCheck = 1.0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilitySwarm == nil then abilitySwarm = bot:GetAbilityByName("weaver_the_swarm"); end
    if abilityShukuchi == nil then abilityShukuchi = bot:GetAbilityByName("weaver_shukuchi"); end
    if abilityGeminate == nil then abilityGeminate = bot:GetAbilityByName("weaver_geminate_attack"); end
    if abilityTimeLapse == nil then abilityTimeLapse = bot:GetAbilityByName("weaver_time_lapse"); end

    -- Enable Geminate Attack autocast (like Hoodwink's Acorn Shot)
    if abilityGeminate ~= nil and not geminateAutoCastEnabled then
        if abilityGeminate:GetAutoCastState() == false then
            abilityGeminate:ToggleAutoCast();
        end
        geminateAutoCastEnabled = true;
    end

    -- Consider using each ability
    castTimeLapseDesire, castTimeLapseTarget = ConsiderTimeLapse();
    castShukuchiDesire = ConsiderShukuchi();
    castSwarmDesire, castSwarmLocation = ConsiderSwarm();

    -- Priority: Ultimate (save) > Escape/Chase > Offensive
    if castTimeLapseDesire > 0 then
        if bot:HasScepter() and castTimeLapseTarget ~= nil then
            bot:Action_UseAbilityOnEntity(abilityTimeLapse, castTimeLapseTarget);
        else
            bot:Action_UseAbility(abilityTimeLapse);
        end
        return;
    end

    if castShukuchiDesire > 0 then
        bot:Action_UseAbility(abilityShukuchi);
        return;
    end

    if castSwarmDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilitySwarm, castSwarmLocation);
        return;
    end
end

function ConsiderSwarm()
    if not mutils.CanBeCast(abilitySwarm) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilitySwarm:GetCastRange(), 1600);
    local nManaCost = abilitySwarm:GetManaCost();
    local nRadius = abilitySwarm:GetSpecialValueInt("spawn_radius");
    local manaPercent = bot:GetMana() / bot:GetMaxMana();

    -- Don't spam if low on mana (save for escape)
    if manaPercent < 0.3 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- TEAMFIGHT: Multi-target scenarios (HIGH PRIORITY)
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end

    -- OFFENSIVE: Going on someone (AGGRESSIVE)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= nCastRange then
                return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation(0.3);
            end
        end
    end

    -- FARMING: Clear waves when pushing/defending (only with good mana)
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and manaPercent > 0.6 then
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 4 then
            return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderShukuchi()
    if not mutils.CanBeCast(abilityShukuchi) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nManaCost = abilityShukuchi:GetManaCost();
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    local manaPercent = bot:GetMana() / bot:GetMaxMana();

    -- ESCAPE: Retreating from danger (HIGHEST PRIORITY)
    if mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
        if #enemies > 0 then
            if healthPercent < 0.5 or #enemies >= 2 or bot:WasRecentlyDamagedByAnyHero(2.0) then
                return BOT_ACTION_DESIRE_VERYHIGH;
            end
        end
    end

    -- CHASE: Catching fleeing enemies
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            local attackRange = bot:GetAttackRange();
            
            -- Use to close gap if target is out of attack range
            if distance > attackRange + 200 and distance < 2000 then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    -- AGGRESSIVE POSITIONING: In teamfights for damage + repositioning
    if mutils.IsInTeamFight(bot, 1200) and manaPercent > 0.4 then
        local enemies = bot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderTimeLapse()
    if not mutils.CanBeCast(abilityTimeLapse) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local currentHealth = bot:GetHealth();
    local maxHealth = bot:GetMaxHealth();
    local healthPercent = currentHealth / maxHealth;
    local hasScepter = bot:HasScepter();

    -- Track health loss for emergency saves
    local healthLoss = lastHealthCheck - healthPercent;
    lastHealthCheck = healthPercent;

    -- SELF SAVE: Used Time Lapse to restore health after big damage
    local recentDamage = bot:WasRecentlyDamagedByAnyHero(2.0);
    
    -- Emergency save: took massive damage or very low health
    if healthPercent < 0.15 and recentDamage then
        if hasScepter then
            return BOT_ACTION_DESIRE_VERYHIGH, bot;
        else
            return BOT_ACTION_DESIRE_VERYHIGH, nil;
        end
    end

    -- Normal save: significant health loss in combat
    if healthPercent < 0.35 and healthLoss > 0.3 and recentDamage then
        if hasScepter then
            return BOT_ACTION_DESIRE_HIGH, bot;
        else
            return BOT_ACTION_DESIRE_HIGH, nil;
        end
    end

    -- ALLY SAVE: With Scepter, save low health allies
    if hasScepter then
        local allies = bot:GetNearbyHeroes(500, false, BOT_MODE_NONE);
        for _, ally in pairs(allies) do
            if ally ~= bot and not ally:IsIllusion() then
                local allyHealthPercent = mutils.SafeGetHealthPercent(ally);
                local allyRecentDamage = mutils.SafeWasRecentlyDamaged(ally, 2.0);
                
                -- Save ally from death
                if allyHealthPercent < 0.20 and allyRecentDamage then
                    return BOT_ACTION_DESIRE_VERYHIGH, ally;
                end
                
                -- Save retreating ally who took big damage
                if mutils.IsRetreating(ally) and allyHealthPercent < 0.35 and allyRecentDamage then
                    return BOT_ACTION_DESIRE_HIGH, ally;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end