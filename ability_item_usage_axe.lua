if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

-- Global variables
local abilityQ = nil;  -- Berserker's Call
local abilityW = nil;  -- Battle Hunger
local abilityE = nil;  -- Counter Helix (passive)
local abilityR = nil;  -- Culling Blade
local npcBot = nil;

-- State management for death recovery
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Item tracking
local ItemBM = nil;

-- Think function protection during death recovery
function AbilityLevelUpThink()  
    if isRecoveringFromDeath then return; end
    ability_item_usage_generic.AbilityLevelUpThink(); 
end

function BuybackUsageThink()
    if isRecoveringFromDeath then return; end
    ability_item_usage_generic.BuybackUsageThink();
end

function CourierUsageThink()
    if isRecoveringFromDeath then return; end
    ability_item_usage_generic.CourierUsageThink();
end

function ItemUsageThink()
    if isRecoveringFromDeath then return; end
    ability_item_usage_generic.ItemUsageThink();
end

function AbilityUsageThink()
    if npcBot == nil then npcBot = GetBot(); end
    
    -- UNIVERSAL FOUNTAIN STUCK FIX (HIGHEST PRIORITY)
    local distanceFromFountain = npcBot:DistanceFromFountain();
    local botLevel = npcBot:GetLevel();
    
    if distanceFromFountain <= 100 and botLevel >= 1 and DotaTime() > 10 then
        npcBot:Action_ClearActions(false);
        local escapeLocation = nil;
        if GetTeam() == TEAM_RADIANT then
            escapeLocation = Vector(-6000, -6000, 0);
        else
            escapeLocation = Vector(6000, 6000, 0);
        end
        if escapeLocation ~= nil then
            npcBot:Action_MoveToLocation(escapeLocation);
            return;
        end
    end
    
    -- DEATH RECOVERY SYSTEM
    if not npcBot:IsAlive() then
        lastDeathTime = DotaTime();
        isRecoveringFromDeath = true;
        return;
    end
    
    if isRecoveringFromDeath and DotaTime() - lastDeathTime < postDeathCooldown then
        if distanceFromFountain < 300 then
            npcBot:Action_ClearActions(false);
            local escapeLocation = nil;
            if GetTeam() == TEAM_RADIANT then
                escapeLocation = Vector(-6000, -6000, 0);
            else
                escapeLocation = Vector(6000, 6000, 0);
            end
            if escapeLocation ~= nil then
                npcBot:Action_MoveToLocation(escapeLocation);
            end
        end
        return;
    elseif isRecoveringFromDeath then
        isRecoveringFromDeath = false;
    end
    
    -- CHANNELING PROTECTION
    if mutil.SafeIsChanneling(npcBot) then
        return; -- Don't interrupt channeling
    end
    
    -- Check if we're already using an ability
    if mutil.CanNotUseAbility(npcBot) then return end

    -- Initialize abilities by name
    if abilityQ == nil then abilityQ = npcBot:GetAbilityByName("axe_berserkers_call"); end
    if abilityW == nil then abilityW = npcBot:GetAbilityByName("axe_battle_hunger"); end
    if abilityE == nil then abilityE = npcBot:GetAbilityByName("axe_counter_helix"); end
    if abilityR == nil then abilityR = npcBot:GetAbilityByName("axe_culling_blade"); end
    
    -- Get Blade Mail for combo
    ItemBM = mutil.GetComboItem(npcBot, 'item_blade_mail');

    -- Consider using each ability in priority order
    local castRDesire, castRTarget = ConsiderCullingBlade();
    local castQDesire, castQType = ConsiderBerserkersCall();
    local castWDesire, castWTarget = ConsiderBattleHunger();

    -- BLADE MAIL + BERSERKER'S CALL COMBO
    if ItemBM ~= nil and ItemBM:IsFullyCastable() and castQDesire > 0 and castQType == "hero" then
        npcBot:Action_UseAbility(ItemBM);
        return;
    end
    
    -- Priority: Ultimate > Call > Battle Hunger
    if castRDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityR, castRTarget);
        return;
    end

    if castQDesire > 0 then
        npcBot:Action_UseAbility(abilityQ);
        return;
    end
    
    if castWDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityW, castWTarget);
        return;
    end
end

-- Berserker's Call: Taunt enemies and gain armor
function ConsiderBerserkersCall()
    if abilityQ == nil or not abilityQ:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, "";
    end

    local nRadius = abilityQ:GetSpecialValueInt("radius");
    local nManaCost = abilityQ:GetManaCost();

    -- Interrupt channeling enemies (highest priority)
    local enemies = npcBot:GetNearbyHeroes(nRadius + 100, true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, "hero";
        end
    end

    -- EMERGENCY: Retreating and being chased
    if mutil.IsRetreating(npcBot) then
        local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
        if healthPercent < 0.4 and npcBot:WasRecentlyDamagedByAnyHero(2.0) then
            local nearbyEnemies = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
            if #nearbyEnemies > 0 then
                return BOT_ACTION_DESIRE_HIGH, "hero";
            end
        end
    end

    -- TEAMFIGHT: Initiate on multiple enemies
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemyHeroes = npcBot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        local allyHeroes = npcBot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
        
        -- Only initiate if we have backup nearby
        if #enemyHeroes >= 2 and #allyHeroes >= 1 then
            return BOT_ACTION_DESIRE_HIGH, "hero";
        end
        
        if #enemyHeroes >= 1 and #allyHeroes >= 2 then
            return BOT_ACTION_DESIRE_MODERATE, "hero";
        end
    end

    -- OFFENSIVE: Going on someone (be more aggressive than original)
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.CanCastOnMagicImmune(target) then
            local distanceToTarget = GetUnitToUnitDistance(npcBot, target);
            if distanceToTarget <= nRadius then
                -- Check if we have allies nearby for support
                local allyHeroes = npcBot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
                if #allyHeroes >= 1 or npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.6 then
                    return BOT_ACTION_DESIRE_HIGH, "hero";
                end
            end
        end
    end

    -- ROSHAN: Use on Roshan for bonus armor
    if npcBot:GetActiveMode() == BOT_MODE_ROSHAN then
        local target = mutil.SafeGetAttackTarget(npcBot);
        if mutil.IsRoshan(target) and mutil.CanCastOnMagicImmune(target) and mutil.IsInRange(npcBot, target, nRadius) then
            return BOT_ACTION_DESIRE_MODERATE, "creep";
        end
    end

    -- FARMING: Large creep waves (when we have good mana)
    if (mutil.IsPushing(npcBot) or mutil.IsDefending(npcBot)) and mutil.AllowedToSpam(npcBot, nManaCost) then
        local creeps = npcBot:GetNearbyLaneCreeps(nRadius, true);
        if #creeps >= 4 then
            return BOT_ACTION_DESIRE_LOW, "creep";
        end
    end

    return BOT_ACTION_DESIRE_NONE, "";
end

-- Battle Hunger: DoT that's removed by killing units
function ConsiderBattleHunger()
    if abilityW == nil or not abilityW:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityW:GetCastRange();
    local nManaCost = abilityW:GetManaCost();
    local nDamagePerSecond = abilityW:GetSpecialValueInt("damage_per_second");
    local nDuration = abilityW:GetSpecialValueFloat("duration");
    local totalDamage = nDamagePerSecond * nDuration;

    local enemies = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);

    -- Check for shard (allows stacking on same enemy)
    local hasShard = abilityW:GetSpecialValueInt("should_stack") > 0;

    -- KILL POTENTIAL: Can kill enemy with battle hunger (prioritize stacking if we have shard)
    for _, enemy in pairs(enemies) do
        if mutil.CanCastOnNonMagicImmune(enemy) then
            -- Calculate damage including existing stacks if shard
            local effectiveDamage = totalDamage;
            if hasShard and enemy:HasModifier("modifier_axe_battle_hunger") then
                -- Each stack adds full damage, so multiple stacks = multiple times damage
                effectiveDamage = totalDamage * 2; -- Assume we'll have 2 stacks after this cast
            end
            
            if mutil.CanKillTarget(enemy, effectiveDamage, DAMAGE_TYPE_PHYSICAL) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end

    -- INTERRUPT: Channeling enemies
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_HIGH, enemy;
        end
    end

    -- HARASSMENT: Lane phase harassment
    if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, nManaCost) then
        local nearbyCreeps = npcBot:GetNearbyLaneCreeps(1200, false);
        
        -- Use on enemies when no creeps around (harder to remove debuff)
        if #nearbyCreeps == 0 and #enemies > 0 then
            for _, enemy in pairs(enemies) do
                if mutil.CanCastOnNonMagicImmune(enemy) then
                    -- With shard, we can stack on same enemy for more damage
                    if hasShard then
                        return BOT_ACTION_DESIRE_HIGH, enemy;
                    else
                        -- Without shard, don't use on already affected enemies (doesn't stack)
                        if not enemy:HasModifier("modifier_axe_battle_hunger") then
                            return BOT_ACTION_DESIRE_HIGH, enemy;
                        end
                    end
                end
            end
        end
    end

    -- RETREATING: Slow pursuers (stack if we have shard for more slow)
    if mutil.IsRetreating(npcBot) then
        for _, enemy in pairs(enemies) do
            if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) and mutil.CanCastOnNonMagicImmune(enemy) then
                -- With shard, stack on same enemy for stronger slow
                if hasShard then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                else
                    -- Without shard, only use if not already affected
                    if not enemy:HasModifier("modifier_axe_battle_hunger") then
                        return BOT_ACTION_DESIRE_HIGH, enemy;
                    end
                end
            end
        end
    end

    -- GENERAL COMBAT: Use on enemies we're fighting (stack for more damage if shard)
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.CanCastOnNonMagicImmune(target) and 
           mutil.IsInRange(target, npcBot, nCastRange + 200) then
            -- With shard, keep stacking on the same target for maximum damage
            if hasShard then
                return BOT_ACTION_DESIRE_HIGH, target;
            else
                -- Without shard, only use if not already affected
                if not target:HasModifier("modifier_axe_battle_hunger") then
                    return BOT_ACTION_DESIRE_HIGH, target;
                end
            end
        end
    end

    -- ROSHAN: Use on Roshan (can stack for more damage if shard)
    if npcBot:GetActiveMode() == BOT_MODE_ROSHAN then
        local target = mutil.SafeGetAttackTarget(npcBot);
        if mutil.IsRoshan(target) and mutil.CanCastOnMagicImmune(target) and 
           mutil.IsInRange(target, npcBot, nCastRange) then
            -- Always use on Roshan if we have shard (stacking damage)
            if hasShard then
                return BOT_ACTION_DESIRE_MODERATE, target;
            else
                -- Without shard, only if not already affected
                if not target:HasModifier("modifier_axe_battle_hunger") then
                    return BOT_ACTION_DESIRE_LOW, target;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

-- Culling Blade: Ultimate execution ability
function ConsiderCullingBlade()
    if abilityR == nil or not abilityR:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityR:GetCastRange();
    local nDamage = abilityR:GetSpecialValueInt("damage");

    -- Look for execution opportunities
    local enemies = npcBot:GetNearbyHeroes(nCastRange + 200, true, BOT_MODE_NONE);

    for _, enemy in pairs(enemies) do
        if mutil.IsValidTarget(enemy) and mutil.CanCastOnMagicImmune(enemy) then
            local enemyHealth = mutil.SafeGetHealth(enemy);
            
            -- GUARANTEED KILL: Enemy health is below threshold
            if enemyHealth > 0 and enemyHealth <= nDamage then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
            
            -- NEAR KILL: Enemy is very close to threshold (accounting for damage calculations)
            if enemyHealth > 0 and enemyHealth <= (nDamage + 50) then
                -- Check if enemy is likely to take damage soon
                if mutil.SafeIsChanneling(enemy) or 
                   enemy:HasModifier("modifier_axe_battle_hunger") or
                   GetUnitToUnitDistance(npcBot, enemy) <= 300 then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end

    -- INTERRUPT: Use on channeling enemies even if not killable
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnMagicImmune(enemy) and
           mutil.IsInRange(enemy, npcBot, nCastRange + 200) then
            local enemyHealth = mutil.SafeGetHealth(enemy);
            if enemyHealth <= nDamage * 1.5 then -- Use if reasonably close to kill threshold
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

-- ANTI-STUCK MODE OVERRIDE FUNCTIONS (REQUIRED)
function GetDesire()
    if npcBot == nil then npcBot = GetBot(); end
    
    local distanceFromFountain = npcBot:DistanceFromFountain();
    local botLevel = npcBot:GetLevel();
    
    if distanceFromFountain < 2000 and botLevel >= 6 and DotaTime() > 180 then
        return BOT_MODE_DESIRE_ABSOLUTE;
    end
    
    if distanceFromFountain < 1500 and DotaTime() > 120 and 
       npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.6 and
       not mutil.SafeWasRecentlyDamaged(npcBot, 5.0) then
        return BOT_MODE_DESIRE_VERYHIGH;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ModeDesire()
    if npcBot == nil then npcBot = GetBot(); end
    
    local distanceFromFountain = npcBot:DistanceFromFountain();
    local botLevel = npcBot:GetLevel();
    
    if distanceFromFountain < 1800 and botLevel >= 6 and 
       npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.5 and
       DotaTime() > 180 then
        return BOT_MODE_DESIRE_ABSOLUTE;
    end
    
    return BOT_MODE_DESIRE_NONE;
end