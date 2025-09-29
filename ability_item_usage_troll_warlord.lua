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
local abilitySwitch = nil; -- Switch Stance
local abilityAxesRanged = nil; -- Whirling Axes Ranged
local abilityAxesMelee = nil; -- Whirling Axes Melee
local abilityUltimate = nil; -- Battle Trance

-- State tracking
local lastSwitchTime = 0;
local switchCooldown = 0.3; -- Prevent spam switching

-- Desire values
local castSwitchDesire = 0;
local castRangedDesire = 0;
local castMeleeDesire = 0;
local castUltDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilitySwitch == nil then abilitySwitch = bot:GetAbilityByName("troll_warlord_switch_stance"); end
    if abilityAxesRanged == nil then abilityAxesRanged = bot:GetAbilityByName("troll_warlord_whirling_axes_ranged"); end
    if abilityAxesMelee == nil then abilityAxesMelee = bot:GetAbilityByName("troll_warlord_whirling_axes_melee"); end
    if abilityUltimate == nil then abilityUltimate = bot:GetAbilityByName("troll_warlord_battle_trance"); end

    -- Consider using each ability
    castUltDesire = ConsiderBattleTrance();
    castRangedDesire, castRangedTarget = ConsiderWhirlingAxesRanged();
    castMeleeDesire = ConsiderWhirlingAxesMelee();
    castSwitchDesire = ConsiderSwitchStance();

    -- Priority order: Ultimate > Axes (for damage/utility) > Switch Stance
    if castUltDesire > 0 then
        bot:Action_UseAbility(abilityUltimate);
        return;
    end

    if castRangedDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityAxesRanged, castRangedTarget);
        lastSwitchTime = DotaTime(); -- Will auto-switch to ranged
        return;
    end

    if castMeleeDesire > 0 then
        bot:Action_UseAbility(abilityAxesMelee);
        lastSwitchTime = DotaTime(); -- Will auto-switch to melee
        return;
    end

    if castSwitchDesire > 0 then
        bot:Action_UseAbility(abilitySwitch);
        lastSwitchTime = DotaTime();
        return;
    end
end

function IsInMeleeForm()
    -- Troll is in melee form when attack range is low
    return bot:GetAttackRange() < 320;
end

function IsInRangedForm()
    return not IsInMeleeForm();
end

function ConsiderSwitchStance()
    if abilitySwitch == nil or not abilitySwitch:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    -- Prevent spam switching
    if DotaTime() - lastSwitchTime < switchCooldown then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
    local inMelee = IsInMeleeForm();
    
    -- CRITICAL: After using ranged axes, immediately switch back to melee for fighting
    if IsInRangedForm() and (mutils.IsGoingOnSomeone(bot) or mutils.IsInTeamFight(bot, 1200)) and #enemies > 0 then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distanceToTarget = GetUnitToUnitDistance(target, bot);
            -- If we can reach them in melee, switch immediately
            if distanceToTarget <= 500 then
                return BOT_ACTION_DESIRE_VERYHIGH;
            end
        end
    end
    
    -- LANING: Prefer ranged form for farming when no close enemies
    if bot:GetActiveMode() == BOT_MODE_LANING then
        if inMelee and #enemies == 0 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- FIGHTING: Prefer melee form in combat
    if mutils.IsGoingOnSomeone(bot) or mutils.IsInTeamFight(bot, 1200) then
        local target = bot:GetTarget();
        
        if mutils.IsValidTarget(target) then
            local distanceToTarget = GetUnitToUnitDistance(target, bot);
            
            -- Switch to melee when close enough (prioritize melee)
            if distanceToTarget <= 500 and not inMelee then
                return BOT_ACTION_DESIRE_VERYHIGH;
            end
            
            -- Only switch to ranged if target is very far
            if distanceToTarget > 700 and inMelee then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
        
        -- Default to melee in any teamfight
        if not inMelee and #enemies > 0 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- RETREATING: Use ranged form for kiting
    if mutils.IsRetreating(bot) and inMelee and #enemies > 0 then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- PUSHING: Use ranged for tower siege
    if mutils.IsPushing(bot) and inMelee then
        local towers = bot:GetNearbyTowers(900, true);
        if #towers > 0 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- DEFAULT: Prefer melee form when enemies nearby
    if #enemies > 0 and not inMelee then
        return BOT_ACTION_DESIRE_MODERATE;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderWhirlingAxesRanged()
    if abilityAxesRanged == nil or not abilityAxesRanged:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityAxesRanged:GetCastRange(), 1600);
    local nManaCost = abilityAxesRanged:GetManaCost();
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- INTERRUPT: Channeling enemies (highest priority)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- TEAMFIGHT: Use for AOE damage and slow
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, 150, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        elseif locationAoE.count >= 1 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end
    
    -- OFFENSIVE: Slow enemies when hunting
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(target, bot);
            -- Use to slow distant enemies so we can catch up
            if distance > 400 and distance <= nCastRange then
                return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation(0.4);
            end
        end
    end
    
    -- HARASSMENT: During laning
    if bot:GetActiveMode() == BOT_MODE_LANING and mutils.AllowedToSpam(bot, nManaCost) then
        if #enemies >= 1 and mutils.CanCastOnNonMagicImmune(enemies[1]) then
            return BOT_ACTION_DESIRE_MODERATE, enemies[1]:GetExtrapolatedLocation(0.4);
        end
    end
    
    -- FARMING: Clear creep waves
    if (bot:GetActiveMode() == BOT_MODE_LANING or mutils.IsPushing(bot)) and 
       mutils.AllowedToSpam(bot, nManaCost) then
        local creeps = bot:GetNearbyLaneCreeps(nCastRange, true);
        if #creeps >= 3 then
            return BOT_ACTION_DESIRE_LOW, creeps[1]:GetLocation();
        end
    end
    
    -- RETREAT: Slow pursuing enemies
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 1.0) then
                return BOT_ACTION_DESIRE_HIGH, enemy:GetExtrapolatedLocation(0.4);
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderWhirlingAxesMelee()
    if abilityAxesMelee == nil or not abilityAxesMelee:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local nRadius = abilityAxesMelee:GetSpecialValueInt("max_range");
    local nManaCost = abilityAxesMelee:GetManaCost();
    local enemies = bot:GetNearbyHeroes(math.min(nRadius + 100, 1600), true, BOT_MODE_NONE);
    
    -- TEAMFIGHT: Use for AOE damage and blind
    if mutils.IsInTeamFight(bot, 800) then
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        elseif #enemies >= 1 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- OFFENSIVE: Use when in melee range for blind effect
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(target, bot) <= nRadius then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- DEFENSIVE: Use when surrounded or taking damage
    if #enemies >= 2 or (mutils.IsRetreating(bot) and #enemies >= 1) then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- FARMING: Clear large creep groups efficiently
    if mutils.AllowedToSpam(bot, nManaCost) then
        local creeps = bot:GetNearbyLaneCreeps(nRadius, true);
        if #creeps >= 4 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderBattleTrance()
    if abilityUltimate == nil or not abilityUltimate:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    local enemies = bot:GetNearbyHeroes(900, true, BOT_MODE_NONE);
    
    -- EMERGENCY: Use when very low on health (core mechanic)
    if healthPercent <= 0.25 and #enemies > 0 then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end
    
    -- AGGRESSIVE: Use when low health but in good fighting position
    if healthPercent <= 0.4 and mutils.IsInTeamFight(bot, 900) and #enemies >= 1 then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- TEAMFIGHT: Use in major teamfights even with decent health
    if mutils.IsInTeamFight(bot, 900) and #enemies >= 3 then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- OFFENSIVE: Use when going on important targets
    if mutils.IsGoingOnSomeone(bot) and healthPercent <= 0.5 then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(target, bot) <= 600 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- ROSHAN: Use during Roshan fights
    if bot:GetActiveMode() == BOT_MODE_ROSHAN then
        local roshan = mutils.SafeGetAttackTarget(bot);
        if mutils.IsRoshan(roshan) and healthPercent <= 0.6 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- DESPERATE: Use when outnumbered and fighting
    if #enemies >= 2 and healthPercent <= 0.6 and 
       (mutils.IsGoingOnSomeone(bot) or bot:WasRecentlyDamagedByAnyHero(2.0)) then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end