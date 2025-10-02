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
local abilityArcaneOrb = nil;
local abilityAstralImprisonment = nil;
local abilityEquilibrium = nil;
local abilitySanityEclipse = nil;

local castOrbDes = 0;
local castAstralDes = 0;
local castEclipseDes = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityArcaneOrb == nil then abilityArcaneOrb = bot:GetAbilityByName("obsidian_destroyer_arcane_orb"); end
    if abilityAstralImprisonment == nil then abilityAstralImprisonment = bot:GetAbilityByName("obsidian_destroyer_astral_imprisonment"); end
    if abilityEquilibrium == nil then abilityEquilibrium = bot:GetAbilityByName("obsidian_destroyer_equilibrium"); end
    if abilitySanityEclipse == nil then abilitySanityEclipse = bot:GetAbilityByName("obsidian_destroyer_sanity_eclipse"); end

    -- Auto-cast management for Arcane Orb
    if abilityArcaneOrb ~= nil and abilityArcaneOrb:IsTrained() then
        if abilityEquilibrium ~= nil and abilityEquilibrium:GetLevel() >= 3 then
            if not abilityArcaneOrb:GetAutoCastState() then
                abilityArcaneOrb:ToggleAutoCast();
            end
        else
            if abilityArcaneOrb:GetAutoCastState() then
                abilityArcaneOrb:ToggleAutoCast();
            end
        end
    end

    -- Consider abilities
    castEclipseDes, castEclipseTarget = ConsiderSanityEclipse();
    castAstralDes, castAstralTarget = ConsiderAstralImprisonment();
    castOrbDes, castOrbTarget = ConsiderArcaneOrb();

    -- Priority: Ultimate > Astral (save/disable) > Arcane Orb
    if castEclipseDes > 0 then
        bot:Action_UseAbilityOnLocation(abilitySanityEclipse, castEclipseTarget);
        return;
    end

    if castAstralDes > 0 then
        bot:Action_UseAbilityOnEntity(abilityAstralImprisonment, castAstralTarget);
        return;
    end

    if castOrbDes > 0 then
        bot:Action_UseAbilityOnEntity(abilityArcaneOrb, castOrbTarget);
        return;
    end
end

-- Helper function to safely get mana
local function SafeGetMana(unit)
    if not unit or unit == nil then return 0 end
    if unit:GetTeam() == GetTeam() then return unit:GetMana() end
    
    local success, mana = pcall(function() return unit:GetMana() end)
    return success and mana or 0;
end

-- Helper function to calculate Eclipse damage
local function CalculateEclipseDamage(target)
    if abilitySanityEclipse == nil or not mutils.IsValidTarget(target) then
        return 0;
    end

    local baseDamage = abilitySanityEclipse:GetSpecialValueInt("base_damage");
    local multiplier = abilitySanityEclipse:GetSpecialValueFloat("damage_multiplier");
    
    local myMana = bot:GetMana();
    local targetMana = SafeGetMana(target);
    
    if targetMana == 0 then return 0 end
    
    local manaDiff = myMana - targetMana;
    if manaDiff <= 0 then return baseDamage end
    
    local totalDamage = baseDamage + (manaDiff * multiplier);
    return totalDamage;
end

function ConsiderArcaneOrb()
    -- Don't manually cast if auto-cast is on
    if not mutils.CanBeCast(abilityArcaneOrb) or abilityArcaneOrb:GetAutoCastState() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nAttackRange = bot:GetAttackRange();
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    
    -- Need good mana to use
    if manaPercent < 0.4 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- HARASS in lane
    if bot:GetActiveMode() == BOT_MODE_LANING then
        local enemies = bot:GetNearbyHeroes(math.min(nAttackRange + 200, 1600), true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    -- GOING ON SOMEONE
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nAttackRange + 200) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    -- TEAMFIGHT
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(nAttackRange + 200, 1600), true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderAstralImprisonment()
    if not mutils.CanBeCast(abilityAstralImprisonment) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityAstralImprisonment:GetCastRange(), 1600);
    local nDamage = abilityAstralImprisonment:GetSpecialValueInt("damage");

    -- SAVE LOW HP ALLIES
    local allies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if ally ~= bot and ally:GetHealth() / ally:GetMaxHealth() < 0.3 then
            if ally:WasRecentlyDamagedByAnyHero(1.5) and mutils.CanCastOnNonMagicImmune(ally) then
                return BOT_ACTION_DESIRE_VERYHIGH, ally;
            end
        end
    end

    -- INTERRUPT CHANNELING/TP
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- SECURE KILL
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if mutils.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end

    -- TEAMFIGHT: Remove dangerous enemy or tank
    if mutils.IsInTeamFight(bot, 1200) then
        local mostDangerous = nil;
        local maxDamage = 0;
        
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if not mutils.IsDisabled(true, enemy) then
                    local damage = mutils.SafeGetEstimatedDamageToTarget(enemy, false, bot, 3.0, DAMAGE_TYPE_ALL);
                    if damage > maxDamage then
                        maxDamage = damage;
                        mostDangerous = enemy;
                    end
                end
            end
        end
        
        if mostDangerous ~= nil then
            return BOT_ACTION_DESIRE_HIGH, mostDangerous;
        end
    end

    -- HARASS in lane (steal mana)
    if bot:GetActiveMode() == BOT_MODE_LANING and bot:GetMana() / bot:GetMaxMana() > 0.6 then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_LOW, enemy;
            end
        end
    end

    -- GOING ON SOMEONE: Disable and steal mana
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            if mutils.IsInRange(target, bot, nCastRange + 200) and not mutils.IsDisabled(true, target) then
                -- Don't use if target is too close and we want to attack
                local distance = GetUnitToUnitDistance(bot, target);
                if distance > nCastRange * 0.5 then
                    return BOT_ACTION_DESIRE_MODERATE, target;
                end
            end
        end
    end

    -- RETREATING: Save self or disable chaser
    if mutils.IsRetreating(bot) then
        local nearAllies = bot:GetNearbyHeroes(1000, false, BOT_MODE_ATTACK);
        if #nearAllies >= 2 then
            return BOT_ACTION_DESIRE_HIGH, bot;
        end
        
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 1.5) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderSanityEclipse()
    if not mutils.CanBeCast(abilitySanityEclipse) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nRadius = abilitySanityEclipse:GetSpecialValueInt("radius");
    local nCastRange = math.min(abilitySanityEclipse:GetCastRange(), 1600);

    -- INSTA-KILL CHECK: If we can kill someone, do it
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + nRadius, 1600), true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            local damage = CalculateEclipseDamage(enemy);
            local enemyHealth = mutils.SafeGetHealth(enemy);
            
            if damage > 0 and enemyHealth > 0 then
                local actualDamage = enemy:GetActualIncomingDamage(damage, DAMAGE_TYPE_MAGICAL);
                if actualDamage >= enemyHealth then
                    return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
                end
            end
        end
    end

    -- TEAMFIGHT: Hit multiple low-mana enemies
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 2 then
            -- Check if enemies in AoE are low on mana
            local goodTargets = 0;
            for _, enemy in pairs(enemies) do
                local distance = GetUnitToLocationDistance(enemy, locationAoE.targetloc);
                if distance <= nRadius and mutils.CanCastOnNonMagicImmune(enemy) then
                    local enemyManaPercent = SafeGetMana(enemy) / enemy:GetMaxMana();
                    if enemyManaPercent < 0.5 then
                        goodTargets = goodTargets + 1;
                    end
                end
            end
            
            if goodTargets >= 2 then
                return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
            end
        end
    end

    -- GOING ON SOMEONE: Big damage on low mana target
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            if mutils.IsInRange(target, bot, nCastRange + nRadius) then
                local targetManaPercent = SafeGetMana(target) / target:GetMaxMana();
                local damage = CalculateEclipseDamage(target);
                local targetHealth = mutils.SafeGetHealth(target);
                
                -- Use if target is low mana and damage is significant
                if targetManaPercent < 0.4 and damage > targetHealth * 0.4 then
                    return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
                end
            end
        end
    end

    -- RETREATING with allies: Defensive nuke
    if mutils.IsRetreating(bot) then
        local nearAllies = bot:GetNearbyHeroes(1000, false, BOT_MODE_ATTACK);
        if #nearAllies >= 2 and bot:WasRecentlyDamagedByAnyHero(2.0) then
            local nearEnemies = bot:GetNearbyHeroes(math.min(nCastRange, 1600), true, BOT_MODE_NONE);
            if #nearEnemies >= 2 then
                return BOT_ACTION_DESIRE_MODERATE, bot:GetLocation();
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end