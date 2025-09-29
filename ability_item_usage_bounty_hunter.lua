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

-- Abilities
local abilityShuriken = nil;
local abilityJinada = nil;
local abilityShadowWalk = nil;
local abilityShadowWalkAlly = nil;
local abilityTrack = nil;

-- Desire values
local castShurikenDesire = 0;
local castJinadaDesire = 0;
local castShadowWalkDesire = 0;
local castTrackDesire = 0;

-- Jinada autocast management
local lastJinadaCheck = 0;
local jinadaCheckInterval = 1.0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end

    -- Initialize abilities by name
    if abilityShuriken == nil then abilityShuriken = bot:GetAbilityByName("bounty_hunter_shuriken_toss"); end
    if abilityJinada == nil then abilityJinada = bot:GetAbilityByName("bounty_hunter_jinada"); end
    if abilityShadowWalk == nil then abilityShadowWalk = bot:GetAbilityByName("bounty_hunter_wind_walk"); end
    if abilityShadowWalkAlly == nil then abilityShadowWalkAlly = bot:GetAbilityByName("bounty_hunter_wind_walk_ally"); end
    if abilityTrack == nil then abilityTrack = bot:GetAbilityByName("bounty_hunter_track"); end

    -- Manage Jinada autocast based on game time
    ManageJinadaAutocast();

    -- Consider using each ability
    castTrackDesire, castTrackTarget = ConsiderTrack();
    castShurikenDesire, castShurikenTarget = ConsiderShuriken();
    castShadowWalkDesire, castShadowWalkTarget, castShadowWalkType = ConsiderShadowWalk();

    -- Priority: Track > Shuriken (interrupt/kill) > Shadow Walk
    if castTrackDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityTrack, castTrackTarget);
        return;
    end

    if castShurikenDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityShuriken, castShurikenTarget);
        return;
    end

    if castShadowWalkDesire > 0 then
        if castShadowWalkType == "ally" then
            bot:Action_UseAbilityOnEntity(abilityShadowWalkAlly, castShadowWalkTarget);
        else
            bot:Action_UseAbility(abilityShadowWalk);
        end
        return;
    end
end

function ManageJinadaAutocast()
    if abilityJinada == nil or not abilityJinada:IsFullyCastable() then
        return;
    end

    local currentTime = DotaTime();
    if currentTime - lastJinadaCheck < jinadaCheckInterval then
        return;
    end
    lastJinadaCheck = currentTime;

    local gameTime = DotaTime();
    local laningPhase = gameTime < 600; -- First 10 minutes

    -- During laning: Manual cast only (autocast OFF)
    -- Mid/Late game: Always autocast ON
    if laningPhase then
        if abilityJinada:GetAutoCastState() then
            abilityJinada:ToggleAutoCast();
        end
    else
        if not abilityJinada:GetAutoCastState() then
            abilityJinada:ToggleAutoCast();
        end
    end
end

function ConsiderTrack()
    if not mutils.CanBeCast(abilityTrack) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityTrack:GetCastRange(), 1600);
    local nManaCost = abilityTrack:GetManaCost();

    -- IMPORTANT: Track doesn't break invisibility, so always consider using it
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) then
            -- Don't track if already tracked
            if not enemy:HasModifier("modifier_bounty_hunter_track") then
                
                -- PRIORITY 1: Track low HP enemies (about to die for bonus gold)
                local enemyHealthPercent = mutils.SafeGetHealthPercent(enemy);
                if enemyHealthPercent < 0.3 then
                    return BOT_ACTION_DESIRE_VERYHIGH, enemy;
                end

                -- PRIORITY 2: Track in teamfights
                if mutils.IsInTeamFight(bot, 1200) then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end

                -- PRIORITY 3: Track when going on someone
                if mutils.IsGoingOnSomeone(bot) then
                    local target = bot:GetTarget();
                    if target == enemy then
                        return BOT_ACTION_DESIRE_HIGH, enemy;
                    end
                end

                -- PRIORITY 4: Track any enemy in range when roaming
                if bot:GetActiveMode() == BOT_MODE_ROAM then
                    return BOT_ACTION_DESIRE_MODERATE, enemy;
                end

                -- PRIORITY 5: Opportunistic tracking when safe
                local nearbyAllies = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
                if #nearbyAllies >= 1 then
                    return BOT_ACTION_DESIRE_MODERATE, enemy;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderShuriken()
    if not mutils.CanBeCast(abilityShuriken) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Don't break invisibility with Shuriken unless necessary
    if bot:HasModifier("modifier_bounty_hunter_wind_walk") then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityShuriken:GetCastRange(), 1600);
    local nBounceRange = 1200;
    local nDamage = abilityShuriken:GetSpecialValueInt("bonus_damage");
    local nManaCost = abilityShuriken:GetManaCost();

    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    local creeps = bot:GetNearbyLaneCreeps(math.min(nCastRange + 200, 1600), true);

    -- INTERRUPT: Channeling enemies (HIGHEST PRIORITY)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if mutils.IsInRange(enemy, bot, nCastRange) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end

    -- KILL: Can kill enemy with shuriken
    for _, enemy in pairs(enemies) do
        if mutils.CanCastOnNonMagicImmune(enemy) and mutils.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            if mutils.IsInRange(enemy, bot, nCastRange) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
            
            -- Bounce kill through tracked enemy
            if enemy:HasModifier("modifier_bounty_hunter_track") then
                for _, creep in pairs(creeps) do
                    if GetUnitToUnitDistance(enemy, creep) < nBounceRange - 150 then
                        return BOT_ACTION_DESIRE_VERYHIGH, creep;
                    end
                end
            end
        end
    end

    -- TEAMFIGHT: Bounce to multiple tracked enemies
    if mutils.IsInTeamFight(bot, 1200) then
        local trackedCount = 0;
        for _, enemy in pairs(enemies) do
            if enemy:HasModifier("modifier_bounty_hunter_track") then
                trackedCount = trackedCount + 1;
            end
        end

        if trackedCount >= 2 then
            -- Throw at creep to bounce to tracked enemies
            if #creeps > 0 then
                return BOT_ACTION_DESIRE_HIGH, creeps[1];
            end
            -- Or throw directly at tracked enemy
            for _, enemy in pairs(enemies) do
                if enemy:HasModifier("modifier_bounty_hunter_track") and mutils.IsInRange(enemy, bot, nCastRange) then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            if mutils.IsInRange(target, bot, nCastRange) then
                return BOT_ACTION_DESIRE_MODERATE, target;
            end

            -- Bounce through creep to reach tracked target
            if target:HasModifier("modifier_bounty_hunter_track") then
                for _, creep in pairs(creeps) do
                    if GetUnitToUnitDistance(target, creep) < nBounceRange - 150 then
                        return BOT_ACTION_DESIRE_MODERATE, creep;
                    end
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderShadowWalk()
    if not mutils.CanBeCast(abilityShadowWalk) then
        return BOT_ACTION_DESIRE_NONE, nil, "";
    end

    -- Already invisible, don't recast
    if bot:HasModifier("modifier_bounty_hunter_wind_walk") then
        return BOT_ACTION_DESIRE_NONE, nil, "";
    end

    local nManaCost = abilityShadowWalk:GetManaCost();
    local gameTime = DotaTime();
    local laningPhase = gameTime < 600;

    -- Check if we have shard (ally cast ability)
    local hasShard = false;
    if abilityShadowWalkAlly ~= nil and not abilityShadowWalkAlly:IsHidden() then
        hasShard = true;
    end

    -- SHARD: Cast on allies
    if hasShard and abilityShadowWalkAlly:IsFullyCastable() then
        local nAllyRange = math.min(abilityShadowWalkAlly:GetCastRange(), 1600);
        local allies = bot:GetNearbyHeroes(math.min(nAllyRange, 1600), false, BOT_MODE_NONE);

        for _, ally in pairs(allies) do
            if ally ~= bot then
                -- Save retreating ally taking damage
                if mutils.IsRetreating(ally) and ally:WasRecentlyDamagedByAnyHero(2.0) then
                    local allyHealthPercent = ally:GetHealth() / ally:GetMaxHealth();
                    if allyHealthPercent < 0.5 then
                        return BOT_ACTION_DESIRE_VERYHIGH, ally, "ally";
                    end
                end

                -- Hide ally for gank
                if mutils.IsGoingOnSomeone(bot) then
                    local target = bot:GetTarget();
                    if mutils.IsValidTarget(target) then
                        local allyDist = GetUnitToUnitDistance(ally, target);
                        local botDist = GetUnitToUnitDistance(bot, target);
                        -- If ally is closer to target, hide them for surprise
                        if allyDist < botDist and allyDist < 1000 then
                            return BOT_ACTION_DESIRE_HIGH, ally, "ally";
                        end
                    end
                end
            end
        end
    end

    -- SELF: Escape when retreating
    if mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(1300, true, BOT_MODE_NONE);
        if #enemies >= 1 or bot:WasRecentlyDamagedByTower(2.5) then
            return BOT_ACTION_DESIRE_HIGH, nil, "self";
        end
    end

    -- SELF: Roaming/ganking (but not during laning phase)
    if not laningPhase then
        if mutils.IsGoingOnSomeone(bot) then
            local target = bot:GetTarget();
            if mutils.IsValidTarget(target) then
                local distance = GetUnitToUnitDistance(target, bot);
                -- Use invis to close distance for gank
                if distance > 1000 and distance < 2500 then
                    return BOT_ACTION_DESIRE_MODERATE, nil, "self";
                end
            end
        end

        -- Roam mode: Stay invisible
        if bot:GetActiveMode() == BOT_MODE_ROAM then
            local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
            if #enemies == 0 then
                return BOT_ACTION_DESIRE_LOW, nil, "self";
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil, "";
end