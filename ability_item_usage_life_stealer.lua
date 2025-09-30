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
local abilityQ = nil; -- Rage
local abilityW = nil; -- Open Wounds
local abilityE = nil; -- Ghoul Frenzy (passive)
local abilityR = nil; -- Infest
local abilityConsume = nil; -- Consume (when infested)

-- Desire values
local castQDesire = 0;
local castWDesire = 0;
local castRDesire = 0;
local castConsumeDesire = 0;

-- Infest tracking
local infestTime = 0;
local minInfestDuration = 2.0; -- Minimum time to stay infested

function AbilityUsageThink()
    
    -- Initialize abilities by name (ALWAYS RECOMMENDED)
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("life_stealer_rage"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("life_stealer_open_wounds"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("life_stealer_ghoul_frenzy"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("life_stealer_infest"); end
    if abilityConsume == nil then abilityConsume = bot:GetAbilityByName("life_stealer_consume"); end

    -- CONSUME has ABSOLUTE highest priority (check first, before CanNotUseAbility)
    castConsumeDesire = ConsiderConsume();
    if castConsumeDesire > 0 then
        bot:Action_UseAbility(abilityConsume);
        infestTime = 0;
        return;
    end
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Consider other abilities
    castRDesire, castRTarget = ConsiderInfest();
    castQDesire = ConsiderRage();
    castWDesire, castWTarget = ConsiderOpenWounds();

    -- Priority order: Infest (save) > Rage > Open Wounds
    if castRDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityR, castRTarget);
        infestTime = DotaTime();
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbility(abilityQ);
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityW, castWTarget);
        return;
    end
end

function ConsiderRage()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local enemies = bot:GetNearbyHeroes(math.min(1200, 1600), true, BOT_MODE_NONE);
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    
    -- AGGRESSIVE: Use when going on someone - BUT ONLY IF CLOSE ENOUGH
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distToTarget = GetUnitToUnitDistance(bot, target);
            
            -- CRITICAL FIX: Only use Rage if target is within 800 range
            -- This prevents wasting Rage when target is 3000 units away
            if distToTarget <= 800 then
                -- Use if target is casting
                if target:IsUsingAbility() then
                    return BOT_ACTION_DESIRE_VERYHIGH;
                end
                
                -- Use if enemies are casting spells nearby
                for _, enemy in pairs(enemies) do
                    if enemy:IsUsingAbility() and GetUnitToUnitDistance(bot, enemy) <= 700 then
                        return BOT_ACTION_DESIRE_VERYHIGH;
                    end
                end
                
                -- Use aggressively when very close
                if distToTarget <= 400 then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end
    
    -- TEAMFIGHT: Use liberally in teamfights when enemies are close
    if mutils.IsInTeamFight(bot, 1200) then
        local closeEnemies = 0;
        for _, enemy in pairs(enemies) do
            if GetUnitToUnitDistance(bot, enemy) <= 800 then
                closeEnemies = closeEnemies + 1;
            end
        end
        if closeEnemies >= 1 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- DEFENSIVE: Emergency usage
    if healthPercent <= 0.25 and #enemies >= 1 and bot:WasRecentlyDamagedByAnyHero(1.5) then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end
    
    -- RETREAT: Use when being chased and enemies are close
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            local distToEnemy = GetUnitToUnitDistance(bot, enemy);
            if distToEnemy <= 600 and (bot:WasRecentlyDamagedByHero(enemy, 2.0) or enemy:IsUsingAbility()) then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end
    
    -- FARMING: Use for sustain when low HP
    if bot:GetActiveMode() == BOT_MODE_FARM and healthPercent < 0.5 then
        local attackTarget = mutils.SafeGetAttackTarget(bot);
        if attackTarget ~= nil and not attackTarget:IsNull() then
            return BOT_ACTION_DESIRE_LOW;
        end
    end
    
    -- ROSHAN: Use on Roshan
    if bot:GetActiveMode() == BOT_MODE_ROSHAN then
        local attackTarget = mutils.SafeGetAttackTarget(bot);
        if mutils.IsRoshan(attackTarget) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderOpenWounds()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityW:GetCastRange(), 1600);
    local nManaCost = abilityW:GetManaCost();
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- AGGRESSIVE: Always use on target when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           GetUnitToUnitDistance(target, bot) <= nCastRange + 200 and
           not mutils.IsDisabled(true, target) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end
    
    -- TEAMFIGHT: Use on weakest/closest enemy
    if mutils.IsInTeamFight(bot, 1200) then
        local bestTarget = nil;
        local lowestHealth = 999999;
        
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                local enemyHealth = mutils.SafeGetHealth(enemy);
                if enemyHealth > 0 and enemyHealth < lowestHealth then
                    lowestHealth = enemyHealth;
                    bestTarget = enemy;
                end
            end
        end
        
        if bestTarget ~= nil then
            return BOT_ACTION_DESIRE_HIGH, bestTarget;
        end
    end
    
    -- RETREAT: Slow pursuer for escape
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end
    
    -- FARMING: Use for sustain when low HP
    if bot:GetActiveMode() == BOT_MODE_FARM and bot:GetHealth() / bot:GetMaxHealth() < 0.6 then
        local attackTarget = mutils.SafeGetAttackTarget(bot);
        if attackTarget ~= nil and not attackTarget:IsNull() and 
           not attackTarget:IsAncientCreep() and
           GetUnitToUnitDistance(bot, attackTarget) <= nCastRange then
            return BOT_ACTION_DESIRE_LOW, attackTarget;
        end
    end
    
    -- ROSHAN: Use on Roshan for healing
    if bot:GetActiveMode() == BOT_MODE_ROSHAN then
        local attackTarget = mutils.SafeGetAttackTarget(bot);
        if mutils.IsRoshan(attackTarget) and GetUnitToUnitDistance(bot, attackTarget) <= nCastRange then
            return BOT_ACTION_DESIRE_MODERATE, attackTarget;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderInfest()
    if not mutils.CanBeCast(abilityR) or abilityR:IsHidden() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityR:GetCastRange(), 1600);
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    
    local enemies = bot:GetNearbyHeroes(math.min(1000, 1600), true, BOT_MODE_NONE);
    local allies = bot:GetNearbyHeroes(math.min(nCastRange * 3, 1600), false, BOT_MODE_NONE);
    local alliedCreeps = bot:GetNearbyLaneCreeps(math.min(nCastRange * 3, 1600), false);
    local enemyCreeps = bot:GetNearbyLaneCreeps(math.min(nCastRange * 3, 1600), true);
    
    -- CRITICAL SAVE: Low HP and being chased
    if healthPercent <= 0.35 and #enemies >= 1 and bot:WasRecentlyDamagedByAnyHero(2.0) then
        -- Priority: Allied heroes for saving ally and self
        for _, ally in pairs(allies) do
            if ally:GetUnitName() ~= bot:GetUnitName() and 
               GetUnitToUnitDistance(bot, ally) <= nCastRange then
                return BOT_ACTION_DESIRE_VERYHIGH, ally;
            end
        end
        
        -- Scepter: Can infest enemies
        if bot:HasScepter() then
            for _, enemy in pairs(enemies) do
                if GetUnitToUnitDistance(bot, enemy) <= nCastRange then
                    return BOT_ACTION_DESIRE_VERYHIGH, enemy;
                end
            end
        end
        
        -- Allied creeps for escape
        for _, creep in pairs(alliedCreeps) do
            if GetUnitToUnitDistance(bot, creep) <= nCastRange then
                return BOT_ACTION_DESIRE_VERYHIGH, creep;
            end
        end
        
        -- Enemy creeps as last resort
        for _, creep in pairs(enemyCreeps) do
            if GetUnitToUnitDistance(bot, creep) <= nCastRange then
                return BOT_ACTION_DESIRE_VERYHIGH, creep;
            end
        end
    end
    
    -- RETREAT: Being chased, need escape
    if mutils.IsRetreating(bot) and #enemies >= 1 then
        -- Find closest safe unit to infest
        for _, ally in pairs(allies) do
            if ally:GetUnitName() ~= bot:GetUnitName() and 
               GetUnitToUnitDistance(bot, ally) <= nCastRange then
                return BOT_ACTION_DESIRE_HIGH, ally;
            end
        end
        
        -- Use creeps to escape
        for _, creep in pairs(alliedCreeps) do
            if GetUnitToUnitDistance(bot, creep) <= nCastRange then
                return BOT_ACTION_DESIRE_HIGH, creep;
            end
        end
    end
    
    -- GANK SETUP: Infest melee ally for surprise attack
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(target, bot) > 2000 then
            -- Find melee ally going towards same target
            for _, ally in pairs(allies) do
                if ally:GetUnitName() ~= bot:GetUnitName() and 
                   ally:GetAttackRange() < 320 and
                   GetUnitToUnitDistance(bot, ally) <= nCastRange then
                    return BOT_ACTION_DESIRE_MODERATE, ally;
                end
            end
        end
    end
    
    -- SAVE ALLY: Low HP ally getting damaged
    for _, ally in pairs(allies) do
        if ally:GetUnitName() ~= bot:GetUnitName() then
            local allyHealthPercent = ally:GetHealth() / ally:GetMaxHealth();
            if allyHealthPercent <= 0.25 and ally:WasRecentlyDamagedByAnyHero(1.5) and
               GetUnitToUnitDistance(bot, ally) <= nCastRange then
                return BOT_ACTION_DESIRE_HIGH, ally;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderConsume()
    -- CRITICAL: Check if consume exists and is not hidden FIRST
    if abilityConsume == nil or abilityConsume:IsHidden() then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    -- Check if it's castable
    if not abilityConsume:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local nDamage = abilityR:GetSpecialValueInt("damage");
    local nRadius = abilityR:GetSpecialValueInt("radius");
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    local timeInfested = DotaTime() - infestTime;
    
    -- Make sure we've been infested for a minimum time
    if infestTime == 0 or timeInfested < 0.5 then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local enemies = bot:GetNearbyHeroes(math.min(nRadius + 200, 1600), true, BOT_MODE_NONE);
    
    -- KILLSTEAL: Jump out if we can kill someone
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) then
            local enemyHealth = mutils.SafeGetHealth(enemy);
            if enemyHealth > 0 and enemyHealth <= nDamage * 1.2 then
                return BOT_ACTION_DESIRE_VERYHIGH;
            end
        end
    end
    
    -- AGGRESSIVE: Jump out when going on someone with good timing
    if mutils.IsGoingOnSomeone(bot) then
        -- Jump out if multiple enemies nearby
        if #enemies >= 2 and timeInfested >= 1.5 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
        
        -- Jump out after getting some healing and enemies are close
        if timeInfested >= minInfestDuration and #enemies >= 1 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- TEAMFIGHT: Jump out in good position
    if mutils.IsInTeamFight(bot, 1200) then
        -- Jump out if multiple enemies in range
        if #enemies >= 2 and timeInfested >= 1.0 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
        
        -- Jump out after sufficient healing
        if #enemies >= 1 and timeInfested >= minInfestDuration then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- HEALED: Jump out when fully healed
    if healthPercent >= 0.9 and timeInfested >= minInfestDuration then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- SAFE EXIT: No enemies nearby and somewhat healed
    if #enemies == 0 and timeInfested >= minInfestDuration then
        if healthPercent >= 0.6 or timeInfested >= 8.0 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- LONG INFEST: Jump out after being inside too long
    if timeInfested >= 12.0 then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end