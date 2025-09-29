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

local abilityQ = nil; -- Split Earth
local abilityW = nil; -- Diabolic Edict
local abilityE = nil; -- Lightning Storm
local abilityR = nil; -- Pulse Nova
local abilityScepter = nil; -- Nihilism (Greater Lightning Storm)

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;
local castScepterDesire = 0;

-- Pulse Nova management
local lastNovaToggleTime = 0;
local novaToggleCooldown = 1.0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("leshrac_split_earth"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("leshrac_diabolic_edict"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("leshrac_lightning_storm"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("leshrac_pulse_nova"); end
    if abilityScepter == nil then abilityScepter = bot:GetAbilityByName("leshrac_greater_lightning_storm"); end

    -- Consider using each ability
    castScepterDesire = ConsiderNihilism();
    castWDesire = ConsiderDiabolicEdict();
    castQDesire, castQLocation = ConsiderSplitEarth();
    castEDesire, castETarget = ConsiderLightningStorm();
    castRDesire = ConsiderPulseNova();

    -- Priority: Scepter buff > Edict > Stun > Lightning > Pulse Nova toggle
    if castScepterDesire > 0 then
        bot:Action_UseAbility(abilityScepter);
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbility(abilityW);
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityQ, castQLocation);
        return;
    end

    if castEDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityE, castETarget);
        return;
    end

    if castRDesire > 0 then
        bot:Action_UseAbility(abilityR);
        return;
    end
end

function ConsiderSplitEarth()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local nRadius = abilityQ:GetSpecialValueInt("radius");
    local nDelay = abilityQ:GetSpecialValueFloat("delay");
    local nCastPoint = abilityQ:GetCastPoint();
    local totalDelay = nCastPoint + nDelay;
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- INTERRUPT: Channeling enemies (HIGHEST PRIORITY)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end

    -- INTERRUPT: Teleporting enemies
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if enemy:HasModifier("modifier_teleporting") then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
            end
        end
    end

    -- SHARD DEFENSE: Place in front of towers when defending (with shard)
    if bot:HasModifier("modifier_item_aghanims_shard") and mutils.IsDefending(bot) then
        local towers = bot:GetNearbyTowers(1200, false);
        if #towers > 0 then
            local tower = towers[1];
            local towerLoc = tower:GetLocation();
            -- Find enemies approaching tower
            for _, enemy in pairs(enemies) do
                if mutils.IsValidTarget(enemy) then
                    local enemyToTowerDist = GetUnitToLocationDistance(enemy, towerLoc);
                    if enemyToTowerDist < 800 then
                        -- Place between tower and enemies
                        local defenseLoc = tower:GetXUnitsTowardsLocation(enemy:GetLocation(), 400);
                        return BOT_ACTION_DESIRE_HIGH, defenseLoc;
                    end
                end
            end
        end
    end

    -- TEAMFIGHT: Multi-target stun
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, totalDelay, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            -- Don't stun if already stunned
            if not target:IsStunned() then
                return BOT_ACTION_DESIRE_MODERATE, target:GetExtrapolatedLocation(totalDelay);
            end
        end
    end

    -- DEFENSIVE: Stun when retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if mutils.SafeWasRecentlyDamaged(bot, 2.0) then
                    return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation();
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderDiabolicEdict()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityW:GetSpecialValueInt("radius");
    local enemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);

    -- PUSHING: Use when attacking towers (HIGHEST PRIORITY for Leshrac)
    if mutils.IsPushing(bot) then
        local towers = bot:GetNearbyTowers(nRadius, true);
        if #towers > 0 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end

    -- DEFENDING: Use when enemies attacking our towers
    if mutils.IsDefending(bot) then
        local towers = bot:GetNearbyTowers(nRadius, false);
        if #towers > 0 and #enemies > 0 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- TEAMFIGHT: Multi-target damage
    if mutils.IsInTeamFight(bot, 1200) then
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance < nRadius then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end

    -- DEFENSIVE: Use when retreating with enemies nearby
    if mutils.IsRetreating(bot) then
        if #enemies > 0 and mutils.SafeWasRecentlyDamaged(bot, 2.0) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderLightningStorm()
    if not mutils.CanBeCast(abilityE) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityE:GetCastRange(), 1600);
    local nDamage = abilityE:GetSpecialValueInt("damage");
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- LAST HIT: Secure kills on low HP enemies
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            local enemyHealth = mutils.SafeGetHealth(enemy);
            local actualDamage = enemy:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_MAGICAL);
            if enemyHealth > 0 and enemyHealth <= actualDamage then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end

    -- TEAMFIGHT: Use in fights
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- HARASSMENT: Spam on enemies in lane
    if manaPercent > 0.4 then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
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

    -- FARMING: Use on creeps if good mana
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and manaPercent > 0.6 then
        local creeps = bot:GetNearbyLaneCreeps(nCastRange, true);
        if #creeps >= 3 then
            return BOT_ACTION_DESIRE_MODERATE, creeps[1];
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderPulseNova()
    if abilityR == nil or not abilityR:IsTrained() or not abilityR:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Don't spam toggle
    if DotaTime() - lastNovaToggleTime < novaToggleCooldown then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityR:GetSpecialValueInt("radius");
    local nManaPerSecond = abilityR:GetSpecialValueInt("mana_cost_per_second");
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    local isActive = bot:HasModifier("modifier_leshrac_pulse_nova");
    
    local enemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);

    -- TURN OFF: Low mana or no enemies nearby
    if isActive then
        -- Turn off if low mana
        if manaPercent < 0.25 then
            lastNovaToggleTime = DotaTime();
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
        
        -- Turn off if no enemies nearby
        if #enemies == 0 and not mutils.IsGoingOnSomeone(bot) then
            lastNovaToggleTime = DotaTime();
            return BOT_ACTION_DESIRE_MODERATE;
        end
        
        return BOT_ACTION_DESIRE_NONE;
    end

    -- TURN ON conditions:
    
    -- TEAMFIGHT: Turn on for teamfights
    if mutils.IsInTeamFight(bot, 1200) and #enemies >= 1 and manaPercent > 0.3 then
        lastNovaToggleTime = DotaTime();
        return BOT_ACTION_DESIRE_HIGH;
    end

    -- OFFENSIVE: Turn on when going on someone
    if mutils.IsGoingOnSomeone(bot) and manaPercent > 0.4 then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance < nRadius + 200 then
                lastNovaToggleTime = DotaTime();
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    -- FARMING: Turn on for farming if high mana
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and manaPercent > 0.7 then
        local creeps = bot:GetNearbyLaneCreeps(nRadius, true);
        if #creeps >= 4 then
            lastNovaToggleTime = DotaTime();
            return BOT_ACTION_DESIRE_LOW;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderNihilism()
    -- Check if we have scepter
    if not bot:HasScepter() or abilityScepter == nil or not abilityScepter:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = 500; -- Nihilism radius
    local enemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);

    -- TEAMFIGHT: Use in big teamfights for magic amp
    if mutils.IsInTeamFight(bot, 1200) then
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- DEFENSIVE: Use when low HP and retreating
    if mutils.IsRetreating(bot) then
        local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
        if healthPercent < 0.4 and #enemies >= 1 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end

    -- OFFENSIVE: Use when going on someone with multiple enemies nearby
    if mutils.IsGoingOnSomeone(bot) then
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end