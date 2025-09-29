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

local abilityQ = nil; -- Ice Shards
local abilityW = nil; -- Snowball
local abilityE = nil; -- Tag Team
local abilityR = nil; -- Walrus Punch
local abilityScepter = nil; -- Walrus Kick
local abilitySnowballLaunch = nil; -- Launch Snowball (subability)

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;
local castScepterDesire = 0;
local castLaunchDesire = 0;

-- Snowball state tracking
local snowballStartTime = 0;
local inSnowball = false;

function AbilityUsageThink()
    
    -- Handle snowball launch first (even during ability use)
    if abilitySnowballLaunch == nil then 
        abilitySnowballLaunch = bot:GetAbilityByName("tusk_launch_snowball"); 
    end
    
    castLaunchDesire = ConsiderSnowballLaunch();
    if castLaunchDesire > 0 and not bot:IsUsingAbility() then
        bot:Action_UseAbility(abilitySnowballLaunch);
        return;
    end
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("tusk_ice_shards"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("tusk_snowball"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("tusk_tag_team"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("tusk_walrus_punch"); end
    if abilityScepter == nil then abilityScepter = bot:GetAbilityByName("tusk_walrus_kick"); end

    -- Consider using each ability
    castEDesire = ConsiderTagTeam();
    castWDesire, castWTarget = ConsiderSnowball();
    castScepterDesire, castScepterTarget = ConsiderWalrusKick();
    castRDesire, castRTarget = ConsiderWalrusPunch();
    castQDesire, castQLocation = ConsiderIceShards();

    -- Priority: Tag Team buff > Snowball engage > Kick > Punch > Ice Shards
    if castEDesire > 0 then
        bot:Action_UseAbility(abilityE);
        return;
    end

    if castWDesire > 0 then
        snowballStartTime = DotaTime();
        inSnowball = true;
        bot:Action_UseAbilityOnEntity(abilityW, castWTarget);
        return;
    end

    if castScepterDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityScepter, castScepterTarget);
        return;
    end

    if castRDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityR, castRTarget);
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityQ, castQLocation);
        return;
    end
end

function ConsiderTagTeam()
    if not mutils.CanBeCast(abilityE) then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- COMBO: Use before snowball for extra damage
    if mutils.CanBeCast(abilityW) and mutils.IsGoingOnSomeone(bot) then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end

    -- COMBO: Use before Walrus Punch
    if mutils.CanBeCast(abilityR) and mutils.IsGoingOnSomeone(bot) then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end

    -- TEAMFIGHT: Use for damage amp
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(400, true, BOT_MODE_NONE);
        if #enemies >= 1 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- OFFENSIVE: Use when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance < 600 then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderSnowball()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityW:GetCastRange(), 1600);
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- ESCAPE: Use on creeps/neutrals to escape
    if mutils.IsRetreating(bot) then
        local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
        if healthPercent < 0.4 and mutils.SafeWasRecentlyDamaged(bot, 1.0) then
            -- Try to find creep to snowball to
            local creeps = bot:GetNearbyCreeps(nCastRange, false);
            if #creeps > 0 then
                return BOT_ACTION_DESIRE_HIGH, creeps[1];
            end
            
            -- Snowball to enemy to escape (will launch immediately)
            if #enemies > 0 then
                return BOT_ACTION_DESIRE_MODERATE, enemies[1];
            end
        end
    end

    -- SAVE ALLIES: Snowball to pick up low HP allies
    local allies = bot:GetNearbyHeroes(350, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        local allyHealthPercent = ally:GetHealth() / ally:GetMaxHealth();
        if allyHealthPercent < 0.3 and mutils.SafeWasRecentlyDamaged(ally, 1.0) then
            -- Snowball away from danger
            local nearbyEnemies = ally:GetNearbyHeroes(600, true, BOT_MODE_NONE);
            if #nearbyEnemies > 0 then
                return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1];
            end
        end
    end

    -- AGGRESSIVE: Snowball on enemies in teamfight
    if mutils.IsInTeamFight(bot, 1200) then
        -- Find most dangerous enemy
        local mostDangerous = nil;
        local highestDamage = 0;
        
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                local damage = enemy:GetEstimatedDamageToTarget(true, bot, 3.0, DAMAGE_TYPE_ALL);
                if damage > highestDamage then
                    highestDamage = damage;
                    mostDangerous = enemy;
                end
            end
        end
        
        if mostDangerous ~= nil then
            return BOT_ACTION_DESIRE_HIGH, mostDangerous;
        end
    end

    -- OFFENSIVE: Snowball on target when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            return BOT_ACTION_DESIRE_VERYHIGH, target;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderSnowballLaunch()
    if abilitySnowballLaunch == nil or abilitySnowballLaunch:IsHidden() then
        inSnowball = false;
        return BOT_ACTION_DESIRE_NONE;
    end

    local currentTime = DotaTime();
    local snowballDuration = currentTime - snowballStartTime;

    -- AGGRESSIVE: Launch immediately when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end

    -- ESCAPE: Wait for full duration to get distance/cooldowns
    if mutils.IsRetreating(bot) then
        -- Wait at least 2 seconds before auto-launch
        if snowballDuration > 2.0 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
        return BOT_ACTION_DESIRE_NONE;
    end

    -- TEAMFIGHT: Launch after picking up allies (small delay)
    if mutils.IsInTeamFight(bot, 1200) then
        if snowballDuration > 0.5 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderIceShards()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = 1400;
    local nSpeed = abilityQ:GetSpecialValueInt("shard_speed");
    local nCastPoint = abilityQ:GetCastPoint();
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- BLOCK ESCAPE: Cut off retreating enemies
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            local travelTime = (distance / nSpeed) + nCastPoint;
            
            -- Predict where enemy will be and block AHEAD of them
            local predictedPos = target:GetExtrapolatedLocation(travelTime);
            
            -- Place shards slightly ahead to block escape
            local blockDistance = 200;
            local blockLocation = target:GetXUnitsTowardsLocation(predictedPos, blockDistance);
            
            return BOT_ACTION_DESIRE_HIGH, blockLocation;
        end
    end

    -- DEFENSIVE: Block enemies when retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) then
                if mutils.SafeWasRecentlyDamaged(bot, 2.0) then
                    -- Place shards between us and enemy
                    local toBotDistance = 300;
                    local blockLocation = enemy:GetXUnitsTowardsLocation(bot:GetLocation(), toBotDistance);
                    return BOT_ACTION_DESIRE_HIGH, blockLocation;
                end
            end
        end
    end

    -- FARMING: Clear creep waves
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) then
        local manaPercent = bot:GetMana() / bot:GetMaxMana();
        if manaPercent > 0.6 then
            local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, 200, 0, 0);
            if locationAoE.count >= 4 then
                return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderWalrusPunch()
    if not mutils.CanBeCast(abilityR) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityR:GetCastRange(), 1600);
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- INTERRUPT: Cancel channeling/teleports
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
        
        if mutils.IsValidTarget(enemy) and enemy:HasModifier("modifier_teleporting") then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- TEAMFIGHT: Punch most dangerous enemy
    if mutils.IsInTeamFight(bot, 1200) then
        local mostDangerous = nil;
        local highestDamage = 0;
        
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnMagicImmune(enemy) then
                local damage = enemy:GetEstimatedDamageToTarget(true, bot, 3.0, DAMAGE_TYPE_ALL);
                if damage > highestDamage then
                    highestDamage = damage;
                    mostDangerous = enemy;
                end
            end
        end
        
        if mostDangerous ~= nil then
            return BOT_ACTION_DESIRE_HIGH, mostDangerous;
        end
    end

    -- OFFENSIVE: Punch when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnMagicImmune(target) then
            return BOT_ACTION_DESIRE_VERYHIGH, target;
        end
    end

    -- DEFENSIVE: Punch to escape
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnMagicImmune(enemy) then
                if mutils.SafeWasRecentlyDamaged(bot, 1.0) then
                    return BOT_ACTION_DESIRE_MODERATE, enemy;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderWalrusKick()
    if not bot:HasScepter() or abilityScepter == nil or not abilityScepter:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityScepter:GetCastRange(), 1600);
    local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);

    -- TEAMFIGHT: Kick carry towards our team
    if mutils.IsInTeamFight(bot, 1200) then
        local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
        
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnMagicImmune(enemy) then
                -- Kick towards our team concentration
                if #allies >= 2 then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end

    -- OFFENSIVE: Kick target towards us when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnMagicImmune(target) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    -- DEFENSIVE: Kick to escape
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnMagicImmune(enemy) then
                if mutils.SafeWasRecentlyDamaged(bot, 1.0) then
                    return BOT_ACTION_DESIRE_MODERATE, enemy;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end