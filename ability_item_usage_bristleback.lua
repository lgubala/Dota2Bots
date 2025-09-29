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

local abilityQ = nil; -- Viscous Nasal Goo
local abilityW = nil; -- Quill Spray
local abilityE = nil; -- Bristleback (passive/active with scepter)
local abilityShard = nil; -- Hairball

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castShardDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("bristleback_viscous_nasal_goo"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("bristleback_quill_spray"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("bristleback_bristleback"); end
    if abilityShard == nil then abilityShard = bot:GetAbilityByName("bristleback_hairball"); end

    -- Consider using each ability
    castShardDesire, castShardLocation = ConsiderHairball();
    castEDesire, castELocation = ConsiderBristlebackActive();
    castQDesire, castQTarget = ConsiderViscousNasalGoo();
    castWDesire = ConsiderQuillSpray();

    -- Priority: Shard AoE > Scepter spray > Goo stacking > Quill spam
    if castShardDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityShard, castShardLocation);
        return;
    end

    if castEDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityE, castELocation);
        return;
    end

    if castQDesire > 0 then
        -- Check if we have scepter (makes it AoE)
        if bot:HasScepter() and abilityQ:GetBehavior() == DOTA_ABILITY_BEHAVIOR_NO_TARGET then
            bot:Action_UseAbility(abilityQ);
        else
            bot:Action_UseAbilityOnEntity(abilityQ, castQTarget);
        end
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbility(abilityW);
        return;
    end
end

function ConsiderViscousNasalGoo()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local nManaCost = abilityQ:GetManaCost();
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- Helper function to check goo stacks
    local function GetGooStacks(enemy)
        if enemy:HasModifier("modifier_bristleback_viscous_nasal_goo") then
            return enemy:GetModifierStackCount(enemy:GetModifierByName("modifier_bristleback_viscous_nasal_goo"));
        end
        return 0;
    end

    -- TEAMFIGHT: Stack on multiple enemies (SPAM MODE)
    if mutils.IsInTeamFight(bot, 1200) and manaPercent > 0.3 then
        -- Find enemy with lowest stacks to spread the debuff
        local lowestStackEnemy = nil;
        local lowestStacks = 999;
        
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                local stacks = GetGooStacks(enemy);
                if stacks < lowestStacks then
                    lowestStacks = stacks;
                    lowestStackEnemy = enemy;
                end
            end
        end
        
        if lowestStackEnemy ~= nil then
            return BOT_ACTION_DESIRE_VERYHIGH, lowestStackEnemy;
        end
    end

    -- OFFENSIVE: Stack on primary target (SPAM MODE)
    if mutils.IsGoingOnSomeone(bot) and manaPercent > 0.25 then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local stacks = GetGooStacks(target);
            local maxStacks = abilityQ:GetSpecialValueInt("stack_limit");
            
            -- Always stack if below max
            if stacks < maxStacks then
                return BOT_ACTION_DESIRE_VERYHIGH, target;
            end
            
            -- Refresh stacks if about to expire
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    -- DEFENSIVE: Slow enemies when retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if mutils.SafeWasRecentlyDamaged(bot, 2.0) then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end

    -- HARASSMENT: Use in lane if good mana
    local gameTime = DotaTime();
    if gameTime < 900 and manaPercent > 0.5 then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderQuillSpray()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityW:GetSpecialValueInt("radius");
    local nManaCost = abilityW:GetManaCost();
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    
    local enemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);

    -- TEAMFIGHT: SPAM MODE - Stack quills on everyone
    if mutils.IsInTeamFight(bot, 1200) and #enemies > 0 and manaPercent > 0.3 then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end

    -- OFFENSIVE: SPAM when going on someone
    if mutils.IsGoingOnSomeone(bot) and manaPercent > 0.25 then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance < nRadius - 50 then
                return BOT_ACTION_DESIRE_VERYHIGH;
            end
        end
    end

    -- DEFENSIVE: Use when retreating with enemies nearby
    if mutils.IsRetreating(bot) then
        if #enemies > 0 and mutils.SafeWasRecentlyDamaged(bot, 1.0) then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- FARMING: Use on creeps if good mana
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and manaPercent > 0.6 then
        local creeps = bot:GetNearbyLaneCreeps(nRadius, true);
        if #creeps >= 4 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderHairball()
    -- Check if we have shard
    if abilityShard == nil or abilityShard:IsHidden() or not abilityShard:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityShard:GetCastRange(), 1600);
    local nRadius = abilityShard:GetSpecialValueInt("radius");
    local nCastPoint = abilityShard:GetCastPoint();
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + nRadius, 1600), true, BOT_MODE_NONE);

    -- TEAMFIGHT: AoE goo + quills
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, nCastPoint, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation(nCastPoint);
        end
    end

    -- DEFENDING/PUSHING: Clear waves
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) then
        local manaPercent = bot:GetMana() / bot:GetMaxMana();
        if manaPercent > 0.5 then
            local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius/2, nCastPoint, 0);
            if locationAoE.count >= 4 then
                return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderBristlebackActive()
    -- Check if we have scepter (makes passive become active)
    if not bot:HasScepter() or abilityE == nil or not abilityE:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- With scepter, Bristleback becomes an active ability
    local nRadius = 700; -- Approximate spray radius
    local enemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);

    -- TEAMFIGHT: Use when multiple enemies in front
    if mutils.IsInTeamFight(bot, 1200) then
        if #enemies >= 2 then
            -- Find direction towards most enemies
            local enemyCenter = bot:FindAoELocation(true, true, bot:GetLocation(), nRadius, 300, 0, 0);
            if enemyCenter.count >= 2 then
                return BOT_ACTION_DESIRE_HIGH, enemyCenter.targetloc;
            end
        end
    end

    -- OFFENSIVE: Use when going on someone with nearby enemies
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and #enemies >= 1 then
            local manaPercent = bot:GetMana() / bot:GetMaxMana();
            if manaPercent > 0.3 then
                return BOT_ACTION_DESIRE_MODERATE, target:GetLocation();
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end