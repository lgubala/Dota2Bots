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
local abilityQ = nil; -- Dragon Slave
local abilityW = nil; -- Light Strike Array
local abilityE = nil; -- Fiery Soul (passive)
local abilityR = nil; -- Laguna Blade
local abilityScepter = nil; -- Flame Cloak

-- Desire values
local castQDesire = 0;
local castWDesire = 0;
local castRDesire = 0;
local castScepterDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name (ALWAYS RECOMMENDED)
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("lina_dragon_slave"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("lina_light_strike_array"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("lina_fiery_soul"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("lina_laguna_blade"); end
    if abilityScepter == nil then abilityScepter = bot:GetAbilityByName("lina_flame_cloak"); end

    -- Consider using each ability
    castScepterDesire = ConsiderFlameCloak();
    castRDesire, castRTarget = ConsiderLagunaBlade();
    castWDesire, castWTarget = ConsiderLightStrikeArray();
    castQDesire, castQTarget = ConsiderDragonSlave();

    -- Priority order: Scepter buff > Ultimate > Stun > Nuke
    -- Use Flame Cloak first for positioning/escape
    if castScepterDesire > 0 then
        bot:Action_UseAbility(abilityScepter);
        return;
    end

    if castRDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityR, castRTarget);
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityW, castWTarget);
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityQ, castQTarget);
        return;
    end
end

function ConsiderDragonSlave()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local nManaCost = abilityQ:GetManaCost();
    local nRadius = abilityQ:GetSpecialValueInt("dragon_slave_width_end");
    local nDamage = abilityQ:GetSpecialValueInt("dragon_slave_damage");
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- INTERRUPT: Channeling enemies (highest priority)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- KILLSTEAL: Finish off low HP enemies
    for _, enemy in pairs(enemies) do
        if mutils.CanCastOnNonMagicImmune(enemy) then
            local enemyHealth = mutils.SafeGetHealth(enemy);
            if enemyHealth > 0 and enemyHealth <= nDamage * 0.7 then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
            end
        end
    end
    
    -- TEAMFIGHT: Use liberally in teamfights for Fiery Soul stacks
    if mutils.IsInTeamFight(bot, 1300) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        elseif locationAoE.count >= 1 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end
    
    -- HARASSMENT: Use in lane to harass enemies
    if bot:GetActiveMode() == BOT_MODE_LANING and mutils.AllowedToSpam(bot, nManaCost) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and not mutils.IsDisabled(true, enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation();
            end
        end
    end
    
    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           GetUnitToUnitDistance(target, bot) <= nCastRange + 200 then
            return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
        end
    end
    
    -- FARMING: Last hit with decent mana
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot) or bot:GetActiveMode() == BOT_MODE_LANING) and 
       mutils.AllowedToSpam(bot, nManaCost) then
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 3 then
            return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
        end
    end
    
    -- RETREAT: Defensive usage
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderLightStrikeArray()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityW:GetCastRange(), 1600);
    local nManaCost = abilityW:GetManaCost();
    local nRadius = abilityW:GetSpecialValueInt("light_strike_array_aoe");
    local nDelay = abilityW:GetSpecialValueFloat("light_strike_array_delay_time");
    local nCastPoint = abilityW:GetCastPoint();
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- INTERRUPT: Channeling enemies (CRITICAL)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- INTERRUPT: TP cancelling
    for _, enemy in pairs(enemies) do
        if enemy:IsUsingAbility() and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- TEAMFIGHT: Multi-target stuns
    if mutils.IsInTeamFight(bot, 1300) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, nCastPoint, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_VERYHIGH, locationAoE.targetloc;
        elseif locationAoE.count >= 1 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end
    
    -- OFFENSIVE: Setup for kill
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           GetUnitToUnitDistance(target, bot) <= bot:GetAttackRange() + 150 then
            -- Predict movement
            local moveCon = target:GetMovementDirectionStability();
            local pLoc = target:GetExtrapolatedLocation(nCastPoint + nDelay);
            if moveCon < 0.8 then
                pLoc = target:GetLocation();
            end
            return BOT_ACTION_DESIRE_HIGH, pLoc;
        end
    end
    
    -- RETREAT: Defensive stun
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, nCastPoint, 0);
        if locationAoE.count >= 1 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end
    
    -- FARMING: Multi-creep stun (only with good mana)
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and mutils.AllowedToSpam(bot, nManaCost) then
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 4 then
            return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderLagunaBlade()
    if not mutils.CanBeCast(abilityR) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityR:GetCastRange(), 1600);
    local nDamage = abilityR:GetSpecialValueInt("damage");
    local nDamageType = abilityR:GetDamageType();
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- KILLSTEAL: Secure kills aggressively
    for _, enemy in pairs(enemies) do
        if mutils.CanCastOnNonMagicImmune(enemy) then
            local enemyHealth = mutils.SafeGetHealth(enemy);
            if enemyHealth > 0 and enemyHealth <= enemy:GetActualIncomingDamage(nDamage, nDamageType) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end
    
    -- TEAMFIGHT: Use on strongest/most dangerous enemy
    if mutils.IsInTeamFight(bot, 1300) then
        local bestTarget = nil;
        local bestHealth = 0;
        
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and not enemy:HasModifier('modifier_templar_assassin_refraction_absorb') then
                local enemyHealth = mutils.SafeGetHealth(enemy);
                if enemyHealth > bestHealth and enemyHealth <= nDamage * 1.2 then
                    bestHealth = enemyHealth;
                    bestTarget = enemy;
                end
            end
        end
        
        if bestTarget ~= nil then
            return BOT_ACTION_DESIRE_VERYHIGH, bestTarget;
        end
    end
    
    -- OFFENSIVE: Be aggressive with ultimate
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           GetUnitToUnitDistance(target, bot) <= nCastRange + 200 and
           not target:HasModifier('modifier_templar_assassin_refraction_absorb') then
            local enemyHealth = mutils.SafeGetHealth(target);
            -- Use if enemy is below 70% health (aggressive)
            if enemyHealth > 0 and enemyHealth <= target:GetMaxHealth() * 0.7 then
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
    end
    
    -- RETREAT: Use defensively to secure escape
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 1.0) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderFlameCloak()
    if abilityScepter == nil or not abilityScepter:IsFullyCastable() or abilityScepter:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    if not bot:HasScepter() then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
    
    -- TEAMFIGHT: Use for max Fiery Soul stacks and positioning
    if mutils.IsInTeamFight(bot, 1300) and #enemies >= 2 then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- OFFENSIVE: Use when going on someone for unobstructed movement
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(target, bot) <= 1200 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- RETREAT: Use for escape (unobstructed movement)
    if mutils.IsRetreating(bot) and #enemies >= 1 and bot:WasRecentlyDamagedByAnyHero(2.0) then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end
    
    -- ROAMING: Use for map movement (terrain crossing)
    if bot:GetActiveMode() == BOT_MODE_ROAM or bot:GetActiveMode() == BOT_MODE_GANK then
        return BOT_ACTION_DESIRE_MODERATE;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end