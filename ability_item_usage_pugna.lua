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

local abilityBlast = nil;
local abilityDecrepify = nil;
local abilityWard = nil;
local abilityDrain = nil;

local castBlastDesire = 0;
local castDecrepifyDesire = 0;
local castWardDesire = 0;
local castDrainDesire = 0;

-- Base ward cast range (without shard)
local BASE_WARD_RANGE = 150;
local SHARD_WARD_RANGE = 350;

function AbilityUsageThink()

    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION - but allow Life Drain channeling
    if mutils.SafeIsChanneling(bot) then
        -- Only return if channeling Life Drain - don't interrupt it
        if bot:HasModifier("modifier_pugna_life_drain") then
            return;
        end
    end

    if abilityBlast == nil then abilityBlast = bot:GetAbilityByName("pugna_nether_blast"); end
    if abilityDecrepify == nil then abilityDecrepify = bot:GetAbilityByName("pugna_decrepify"); end
    if abilityWard == nil then abilityWard = bot:GetAbilityByName("pugna_nether_ward"); end
    if abilityDrain == nil then abilityDrain = bot:GetAbilityByName("pugna_life_drain"); end

    -- Consider using each ability
    castWardDesire, castWardLocation = ConsiderWard();
    castDecrepifyDesire, castDecrepifyTarget = ConsiderDecrepify();
    castBlastDesire, castBlastLocation = ConsiderBlast();
    castDrainDesire, castDrainTarget = ConsiderLifeDrain();

    -- Priority: Ward (setup) > Decrepify (amp/save) > Life Drain > Blast
    if castWardDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityWard, castWardLocation);
        return;
    end

    if castDecrepifyDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityDecrepify, castDecrepifyTarget);
        return;
    end

    if castDrainDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityDrain, castDrainTarget);
        return;
    end

    if castBlastDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityBlast, castBlastLocation);
        return;
    end
end

function HasShard()
    if abilityWard == nil or not abilityWard:IsTrained() then
        return false;
    end
    
    -- Check if ward cast range equals shard range (350)
    local currentRange = abilityWard:GetCastRange();
    return currentRange >= SHARD_WARD_RANGE;
end

function FindNearestWard()
    -- Find Pugna's Nether Ward in range
    local units = bot:GetNearbyCreeps(1600, false);
    for _, unit in pairs(units) do
        if unit ~= nil and not unit:IsNull() and unit:GetUnitName() == "npc_dota_pugna_nether_ward" then
            if unit:IsAlive() and unit:GetTeam() == bot:GetTeam() then
                return unit;
            end
        end
    end
    return nil;
end

function ConsiderBlast()
    if not mutils.CanBeCast(abilityBlast) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityBlast:GetCastRange(), 1600);
    local nRadius = abilityBlast:GetSpecialValueInt("radius");
    local nDelay = abilityBlast:GetSpecialValueFloat("delay");
    local nCastPoint = abilityBlast:GetCastPoint();
    local nDamage = abilityBlast:GetSpecialValueInt("blast_damage");
    local manaPercent = bot:GetMana() / bot:GetMaxMana();

    -- STRUCTURE DAMAGE: Towers and Barracks (high priority)
    if mutils.IsPushing(bot) or mutils.IsDefending(bot) then
        local towers = bot:GetNearbyTowers(nCastRange, true);
        if #towers > 0 then
            return BOT_ACTION_DESIRE_HIGH, towers[1]:GetLocation();
        end
        
        local barracks = bot:GetNearbyBarracks(nCastRange, true);
        if #barracks > 0 then
            return BOT_ACTION_DESIRE_HIGH, barracks[1]:GetLocation();
        end
    end

    -- TEAMFIGHT: Multi-target damage
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius / 2, nDelay, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation(nDelay + nCastPoint);
        end
    end

    -- ESCAPE: Slow pursuers
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
        local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        if #enemies > 0 then
            return BOT_ACTION_DESIRE_MODERATE, enemies[1]:GetLocation();
        end
    end

    -- FARMING: Wave clear with good mana
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and manaPercent > 0.5 then
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius / 2, nDelay, 0);
        if locationAoE.count >= 4 then
            return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderDecrepify()
    if not mutils.CanBeCast(abilityDecrepify) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityDecrepify:GetCastRange(), 1600);

    -- SAVE ALLIES: Low HP allies under attack
    local allies = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if ally ~= bot and not ally:IsIllusion() then
            local allyHealthPercent = mutils.SafeGetHealthPercent(ally);
            if allyHealthPercent < 0.35 and mutils.SafeWasRecentlyDamaged(ally, 2.0) then
                return BOT_ACTION_DESIRE_VERYHIGH, ally;
            end
        end
    end

    -- SELF SAVE: Escape from physical damage
    if mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies > 0 and bot:WasRecentlyDamagedByAnyHero(2.0) then
            return BOT_ACTION_DESIRE_HIGH, bot;
        end
    end

    -- OFFENSIVE: Amplify magic damage on target
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            if not target:HasModifier("modifier_pugna_decrepify") and not mutils.IsDisabled(true, target) then
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderWard()
    if not mutils.CanBeCast(abilityWard) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityWard:GetCastRange(), 1600);
    local hasShard = HasShard();

    -- TEAMFIGHT: Place ward aggressively close to enemies
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(1400, true, BOT_MODE_NONE);
        if #enemies >= 1 then
            if hasShard then
                -- Place ward VERY close to enemies for drain combo
                local closestEnemy = enemies[1];
                for _, enemy in pairs(enemies) do
                    if GetUnitToUnitDistance(bot, enemy) < GetUnitToUnitDistance(bot, closestEnemy) then
                        closestEnemy = enemy;
                    end
                end
                -- Place between bot and enemy (about 60% towards enemy)
                local targetLoc = bot:GetXUnitsTowardsLocation(closestEnemy:GetLocation(), math.min(nCastRange * 0.9, 500));
                return BOT_ACTION_DESIRE_VERYHIGH, targetLoc;
            else
                return BOT_ACTION_DESIRE_HIGH, bot:GetXUnitsInFront(nCastRange);
            end
        end
    end

    -- OFFENSIVE: Place ward when going on someone
    if mutils.IsGoingOnSomeone(bot) and hasShard then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= 1200 then
                -- Place ward between bot and target
                local targetLoc = bot:GetXUnitsTowardsLocation(target:GetLocation(), math.min(nCastRange * 0.8, 400));
                return BOT_ACTION_DESIRE_HIGH, targetLoc;
            end
        end
    end

    -- DEFENSIVE: Place ward when defending
    if mutils.IsDefending(bot) then
        local enemies = bot:GetNearbyHeroes(1400, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_MODERATE, bot:GetXUnitsInFront(nCastRange);
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderLifeDrain()
    if not mutils.CanBeCast(abilityDrain) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityDrain:GetCastRange(), 1600);
    local hasShard = HasShard();
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();

    -- WITH SHARD: Prioritize ward for AOE damage (HIGHEST PRIORITY)
    if hasShard then
        local ward = FindNearestWard();
        if ward ~= nil then
            local wardDistance = GetUnitToUnitDistance(bot, ward);
            
            if wardDistance <= nCastRange then
                -- Check enemies near ward
                local enemies = ward:GetNearbyHeroes(1400, true, BOT_MODE_NONE);
                
                -- TEAMFIGHT: Drain ward if ANY enemies near it
                if mutils.IsInTeamFight(bot, 1200) and #enemies >= 1 then
                    return BOT_ACTION_DESIRE_VERYHIGH, ward;
                end
                
                -- OFFENSIVE: Drain ward when going on someone if enemies nearby
                if mutils.IsGoingOnSomeone(bot) and #enemies >= 1 then
                    return BOT_ACTION_DESIRE_VERYHIGH, ward;
                end
                
                -- ANY COMBAT: Drain ward if enemies are near it (even if not in teamfight)
                if #enemies >= 2 then
                    return BOT_ACTION_DESIRE_HIGH, ward;
                end
            end
        end
    end

    -- HEAL ALLIES: Only if no ward available or no enemies near ward
    local allies = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if ally ~= bot and not ally:IsIllusion() then
            local allyHealthPercent = mutils.SafeGetHealthPercent(ally);
            -- Only heal critically low allies (<25%)
            if allyHealthPercent < 0.25 and mutils.SafeWasRecentlyDamaged(ally, 2.0) then
                return BOT_ACTION_DESIRE_HIGH, ally;
            end
        end
    end

    -- OFFENSIVE: Damage enemies (fallback if no ward)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= nCastRange then
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
    end

    -- SUSTAIN: Drain enemy to heal when low HP
    if healthPercent < 0.5 then
        local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        if #enemies > 0 then
            for _, enemy in pairs(enemies) do
                if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                    return BOT_ACTION_DESIRE_MODERATE, enemy;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end