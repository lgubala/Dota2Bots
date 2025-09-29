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

local abilityQ = nil; -- Paralyzing Cask
local abilityW = nil; -- Voodoo Restoration
local abilityE = nil; -- Maledict
local abilityR = nil; -- Death Ward
local abilityShard = nil; -- Voodoo Switcheroo

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;
local castShardDesire = 0;

-- Combo tracking
local maledictStartTime = 0;
local comboWindow = 2.0;

-- Voodoo Restoration management
local lastToggleTime = 0;
local toggleCooldown = 2.0; -- Don't spam toggle

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION - Don't interrupt Death Ward!
    if mutils.SafeIsChanneling(bot) then
        -- But we can still toggle heal during channel
        if abilityW ~= nil and abilityW:IsTrained() then
            local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
            local manaPercent = bot:GetMana() / bot:GetMaxMana();
            
            if healthPercent < 0.5 and manaPercent > 0.3 and not abilityW:GetToggleState() then
                bot:Action_UseAbility(abilityW);
            elseif (healthPercent > 0.7 or manaPercent < 0.2) and abilityW:GetToggleState() then
                bot:Action_UseAbility(abilityW);
            end
        end
        return;
    end

    -- Initialize abilities by name
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("witch_doctor_paralyzing_cask"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("witch_doctor_voodoo_restoration"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("witch_doctor_maledict"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("witch_doctor_death_ward"); end
    if abilityShard == nil then abilityShard = bot:GetAbilityByName("witch_doctor_voodoo_switcheroo"); end

    -- Consider using each ability
    castShardDesire = ConsiderVoodooSwitcheroo();
    castRDesire, castRLocation = ConsiderDeathWard();
    castEDesire, castELocation = ConsiderMaledict();
    castQDesire, castQTarget = ConsiderParalyzingCask();
    castWDesire = ConsiderVoodooRestoration();

    -- Priority: Shard damage > Ultimate combo > Maledict setup > Stun > Heal toggle
    if castShardDesire > 0 then
        bot:Action_UseAbility(abilityShard);
        return;
    end

    -- Execute combo: Maledict first, then Death Ward
    if castEDesire > 0 and castRDesire > 0 and maledictStartTime == 0 then
        maledictStartTime = DotaTime();
        bot:Action_UseAbilityOnLocation(abilityE, castELocation);
        return;
    end

    -- Complete combo with Death Ward
    if castRDesire > 0 and maledictStartTime > 0 and DotaTime() - maledictStartTime < comboWindow then
        maledictStartTime = 0;
        bot:Action_UseAbilityOnLocation(abilityR, castRLocation);
        return;
    end

    -- Individual ability usage
    if castRDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityR, castRLocation);
        return;
    end

    if castEDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityE, castELocation);
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

function ConsiderParalyzingCask()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local nBounceRange = abilityQ:GetSpecialValueInt("bounce_range");
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- INTERRUPT: Channeling enemies
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- TEAMFIGHT: Multiple targets nearby
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                local nearbyEnemies = enemy:GetNearbyHeroes(nBounceRange, false, BOT_MODE_NONE);
                if #nearbyEnemies >= 2 then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    -- DEFENSIVE: Retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if mutils.SafeWasRecentlyDamaged(bot, 2.0) then
                    return BOT_ACTION_DESIRE_MODERATE, enemy;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderVoodooRestoration()
    if abilityW == nil or not abilityW:IsTrained() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Don't spam toggle
    if DotaTime() - lastToggleTime < toggleCooldown then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityW:GetSpecialValueInt("radius");
    local manaPerSecond = abilityW:GetSpecialValueInt("mana_per_second");
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    
    local isActive = abilityW:GetToggleState();
    
    -- Count low HP allies nearby
    local lowHpAllies = 0;
    local allies = bot:GetNearbyHeroes(nRadius, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if ally:GetHealth() / ally:GetMaxHealth() < 0.6 then
            lowHpAllies = lowHpAllies + 1;
        end
    end

    -- Turn ON if allies need healing and we have mana
    if not isActive and lowHpAllies >= 1 and manaPercent > 0.3 then
        lastToggleTime = DotaTime();
        return BOT_ACTION_DESIRE_MODERATE;
    end

    -- Turn OFF if no one needs healing or low mana
    if isActive and (lowHpAllies == 0 or manaPercent < 0.2) then
        lastToggleTime = DotaTime();
        return BOT_ACTION_DESIRE_MODERATE;
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderMaledict()
    if not mutils.CanBeCast(abilityE) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityE:GetCastRange(), 1600);
    local nRadius = abilityE:GetSpecialValueInt("radius");
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- TEAMFIGHT: Multi-target nuke
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_VERYHIGH, locationAoE.targetloc;
        end
    end

    -- OFFENSIVE: Going on someone (combo setup for Death Ward)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local castPoint = abilityE:GetCastPoint();
            return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation(castPoint);
        end
    end

    -- HARASSMENT: Use on any enemy in range
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            local enemyHealthPercent = mutils.SafeGetHealthPercent(enemy);
            if enemyHealthPercent < 0.7 then
                return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation();
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderDeathWard()
    if not mutils.CanBeCast(abilityR) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityR:GetCastRange(), 1600);
    local nAttackRange = 600; -- Death Ward attack range
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + nAttackRange, 1600), true, BOT_MODE_NONE);

    -- COMBO: Use after Maledict
    if maledictStartTime > 0 and DotaTime() - maledictStartTime < comboWindow then
        if mutils.IsGoingOnSomeone(bot) then
            local target = bot:GetTarget();
            if mutils.IsValidTarget(target) then
                -- Position ward between us and target, slightly closer to target
                local distance = GetUnitToUnitDistance(bot, target);
                local wardLocation = bot:GetXUnitsTowardsLocation(target:GetLocation(), math.min(distance * 0.7, nCastRange));
                return BOT_ACTION_DESIRE_VERYHIGH, wardLocation;
            end
        end
    end

    -- OFFENSIVE: Going on someone with good health
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local enemyHealth = mutils.SafeGetHealth(target);
            local distance = GetUnitToUnitDistance(bot, target);
            
            -- Only use if target has enough HP to be worth channeling
            if enemyHealth > 400 and distance < nCastRange + 200 then
                -- Check if safe to channel (no nearby enemies that can interrupt)
                local nearbyThreats = bot:GetNearbyHeroes(400, true, BOT_MODE_NONE);
                if #nearbyThreats <= 1 then
                    local wardLocation = bot:GetXUnitsTowardsLocation(target:GetLocation(), math.min(distance * 0.7, nCastRange));
                    return BOT_ACTION_DESIRE_HIGH, wardLocation;
                end
            end
        end
    end

    -- TEAMFIGHT: Multiple enemies in range
    if mutils.IsInTeamFight(bot, 1200) then
        if #enemies >= 2 then
            -- Check if relatively safe to channel
            local nearbyThreats = bot:GetNearbyHeroes(400, true, BOT_MODE_NONE);
            if #nearbyThreats == 0 then
                -- Place ward towards enemy concentration
                local enemyCenter = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nAttackRange, 0, 0);
                if enemyCenter.count >= 2 then
                    return BOT_ACTION_DESIRE_MODERATE, enemyCenter.targetloc;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderVoodooSwitcheroo()
    -- Check if we have shard by checking if ability is not hidden
    if abilityShard == nil or abilityShard:IsHidden() or not abilityShard:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    local enemies = bot:GetNearbyHeroes(600, true, BOT_MODE_NONE); -- Death Ward range

    -- AGGRESSIVE DAMAGE: Use after Maledict when ult is on cooldown
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            
            -- Use if we're in range and ult is on cooldown
            if distance <= 600 and (abilityR == nil or not abilityR:IsFullyCastable()) then
                -- Check if we recently used Maledict for combo
                if maledictStartTime > 0 and DotaTime() - maledictStartTime < 3.0 then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end

    -- DEFENSIVE: Use when surrounded to become invulnerable
    if mutils.IsRetreating(bot) then
        local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
        if healthPercent < 0.4 and #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- TEAMFIGHT: Use for extra damage when positioned well
    if mutils.IsInTeamFight(bot, 1200) and #enemies >= 2 then
        -- Only use if ult is on cooldown
        if abilityR == nil or not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end