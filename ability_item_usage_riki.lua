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
local abilitySmokeScreen = nil;
local abilityBlinkStrike = nil;
local abilityTricks = nil;
local abilityBackstab = nil;

-- Desire values
local castSmokeDesire = 0;
local castBlinkDesire = 0;
local castTricksDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION - Never interrupt Tricks of the Trade
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilitySmokeScreen == nil then abilitySmokeScreen = bot:GetAbilityByName("riki_smoke_screen"); end
    if abilityBlinkStrike == nil then abilityBlinkStrike = bot:GetAbilityByName("riki_blink_strike"); end
    if abilityTricks == nil then abilityTricks = bot:GetAbilityByName("riki_tricks_of_the_trade"); end
    if abilityBackstab == nil then abilityBackstab = bot:GetAbilityByName("riki_backstab"); end

    -- Consider using each ability
    castSmokeDesire, castSmokeLocation = ConsiderSmokeScreen();
    castBlinkDesire, castBlinkTarget = ConsiderBlinkStrike();
    castTricksDesire, castTricksTarget, castTricksType = ConsiderTricksOfTheTrade();

    -- Priority: Emergency Tricks > Smoke Screen interrupt > Blink Strike > Tricks offensive
    if castTricksDesire > BOT_ACTION_DESIRE_HIGH then
        if castTricksType == "ally" then
            bot:Action_UseAbilityOnEntity(abilityTricks, castTricksTarget);
        else
            bot:Action_UseAbilityOnLocation(abilityTricks, castTricksTarget);
        end
        return;
    end

    if castSmokeDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilitySmokeScreen, castSmokeLocation);
        return;
    end
    
    if castBlinkDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityBlinkStrike, castBlinkTarget);
        return;
    end
    
    if castTricksDesire > 0 then
        if castTricksType == "ally" then
            bot:Action_UseAbilityOnEntity(abilityTricks, castTricksTarget);
        else
            bot:Action_UseAbilityOnLocation(abilityTricks, castTricksTarget);
        end
        return;
    end
end

function ConsiderSmokeScreen()
    if not mutils.CanBeCast(abilitySmokeScreen) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilitySmokeScreen:GetCastRange(), 1600);
    local nRadius = abilitySmokeScreen:GetSpecialValueInt("radius");
    local nManaCost = abilitySmokeScreen:GetManaCost();

    -- INTERRUPT: Channeling enemies (HIGHEST PRIORITY)
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end

    -- DEFENSIVE: Being attacked and detected (escape smoke)
    if bot:WasRecentlyDamagedByAnyHero(2.0) and not bot:HasModifier("modifier_riki_permanent_invisibility") then
        local nearbyEnemies = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #nearbyEnemies >= 1 then
            return BOT_ACTION_DESIRE_HIGH, bot:GetLocation();
        end
    end

    -- TEAMFIGHT: Multi-target smoke
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end

    -- OFFENSIVE: Going on someone (aggressive smoke to prevent counterplay)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
            -- Use smoke on dangerous targets or when they're casting
            local targetHealth = mutils.SafeGetHealthPercent(target);
            if targetHealth > 0.4 or mutils.SafeIsChanneling(target) then
                return BOT_ACTION_DESIRE_MODERATE, target:GetExtrapolatedLocation(0.2);
            end
        end
    end

    -- RETREATING: Defensive smoke to escape
    if mutils.IsRetreating(bot) then
        local nearbyEnemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        if #nearbyEnemies >= 1 and bot:WasRecentlyDamagedByAnyHero(2.0) then
            return BOT_ACTION_DESIRE_MODERATE, bot:GetLocation();
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderBlinkStrike()
    if not mutils.CanBeCast(abilityBlinkStrike) or bot:IsRooted() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityBlinkStrike:GetCastRange(), 1600);
    local nManaCost = abilityBlinkStrike:GetManaCost();
    local nBonusDamage = abilityBlinkStrike:GetSpecialValueInt("bonus_damage");

    -- ESCAPE: Blink to allied creeps/heroes when retreating
    if mutils.IsRetreating(bot) then
        if bot:WasRecentlyDamagedByAnyHero(2.0) then
            -- Try to blink to allied heroes first
            local allies = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
            for _, ally in pairs(allies) do
                if ally ~= bot then
                    local allyToFountain = GetUnitToLocationDistance(ally, mutils.GetEscapeLoc());
                    local botToFountain = GetUnitToLocationDistance(bot, mutils.GetEscapeLoc());
                    if allyToFountain < botToFountain then
                        return BOT_ACTION_DESIRE_HIGH, ally;
                    end
                end
            end
            
            -- Blink to allied creeps as backup
            local creeps = bot:GetNearbyLaneCreeps(nCastRange, false);
            for _, creep in pairs(creeps) do
                local creepToFountain = GetUnitToLocationDistance(creep, mutils.GetEscapeLoc());
                local botToFountain = GetUnitToLocationDistance(bot, mutils.GetEscapeLoc());
                if creepToFountain < botToFountain - 200 then
                    return BOT_ACTION_DESIRE_HIGH, creep;
                end
            end
        end
    end

    -- AGGRESSIVE: Chase and gap close
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.IsInRange(target, bot, nCastRange) then
            local distance = GetUnitToUnitDistance(target, bot);
            
            -- Don't blink if already in melee range
            if distance > 250 then
                -- Check if target can be killed
                local targetHealth = mutils.SafeGetHealth(target);
                local estimatedDamage = bot:GetAttackDamage() + nBonusDamage;
                
                -- Blink aggressively on low HP targets
                if targetHealth > 0 and targetHealth < estimatedDamage * 3 then
                    return BOT_ACTION_DESIRE_HIGH, target;
                end
                
                -- Blink to close gap on healthy targets
                if distance > 400 then
                    return BOT_ACTION_DESIRE_MODERATE, target;
                end
            end
        end
    end

    -- FARMING: Blink to farm when safe
    if bot:GetActiveMode() == BOT_MODE_FARM then
        local enemyHeroes = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        if #enemyHeroes == 0 then
            local creeps = bot:GetNearbyLaneCreeps(nCastRange, true);
            for _, creep in pairs(creeps) do
                local creepHealth = mutils.SafeGetHealth(creep);
                if creepHealth > 0 and creepHealth < bot:GetAttackDamage() + nBonusDamage then
                    return BOT_ACTION_DESIRE_LOW, creep;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTricksOfTheTrade()
    if not mutils.CanBeCast(abilityTricks) then
        return BOT_ACTION_DESIRE_NONE, nil, "";
    end

    local nCastRange = math.min(abilityTricks:GetCastRange(), 1600);
    local nRadius = abilityTricks:GetSpecialValueInt("radius");
    local nManaCost = abilityTricks:GetManaCost();
    local hasScepter = bot:HasScepter();

    -- EMERGENCY: Low HP and taking damage (phase out to survive)
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    if healthPercent < 0.3 and bot:WasRecentlyDamagedByAnyHero(1.5) then
        local enemies = bot:GetNearbyHeroes(math.min(nRadius + 200, 1600), true, BOT_MODE_NONE);
        if #enemies >= 1 then
            -- With scepter, prefer jumping to ally in teamfight
            if hasScepter then
                local allies = bot:GetNearbyHeroes(math.min(nCastRange, 1600), false, BOT_MODE_NONE);
                for _, ally in pairs(allies) do
                    if ally ~= bot then
                        local allyEnemies = ally:GetNearbyHeroes(800, true, BOT_MODE_NONE);
                        if #allyEnemies == 0 then
                            return BOT_ACTION_DESIRE_VERYHIGH, ally, "ally";
                        end
                    end
                end
            end
            return BOT_ACTION_DESIRE_VERYHIGH, bot:GetLocation(), "location";
        end
    end

    -- TEAMFIGHT: Use tricks in teamfights
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(nRadius, 1600), true, BOT_MODE_NONE);
        
        if #enemies >= 2 then
            -- With scepter, prefer ally target in middle of fight
            if hasScepter then
                local allies = bot:GetNearbyHeroes(math.min(nCastRange, 1600), false, BOT_MODE_NONE);
                for _, ally in pairs(allies) do
                    if ally ~= bot then
                        local allyNearbyEnemies = ally:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
                        if #allyNearbyEnemies >= 2 then
                            return BOT_ACTION_DESIRE_HIGH, ally, "ally";
                        end
                    end
                end
            end
            
            -- Default to location cast
            local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0);
            if locationAoE.count >= 2 then
                return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc, "location";
            end
        end
    end

    -- OFFENSIVE: Finishing target without getting stunned
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local targetHealth = mutils.SafeGetHealthPercent(target);
            local distance = GetUnitToUnitDistance(target, bot);
            
            -- Use tricks to finish low HP dangerous targets
            if targetHealth < 0.4 and distance < nRadius then
                local enemies = bot:GetNearbyHeroes(math.min(nRadius, 1600), true, BOT_MODE_NONE);
                if #enemies >= 1 then
                    return BOT_ACTION_DESIRE_MODERATE, target:GetLocation(), "location";
                end
            end
        end
    end

    -- DEFENSIVE: Taking heavy damage
    if bot:WasRecentlyDamagedByAnyHero(1.0) then
        local enemies = bot:GetNearbyHeroes(math.min(nRadius, 1600), true, BOT_MODE_NONE);
        if #enemies >= 2 and healthPercent < 0.5 then
            -- With scepter, try to jump to safe ally
            if hasScepter then
                local allies = bot:GetNearbyHeroes(math.min(nCastRange, 1600), false, BOT_MODE_NONE);
                for _, ally in pairs(allies) do
                    if ally ~= bot then
                        local allyEnemies = ally:GetNearbyHeroes(600, true, BOT_MODE_NONE);
                        if #allyEnemies == 0 then
                            return BOT_ACTION_DESIRE_MODERATE, ally, "ally";
                        end
                    end
                end
            end
            
            return BOT_ACTION_DESIRE_MODERATE, bot:GetLocation(), "location";
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil, "";
end