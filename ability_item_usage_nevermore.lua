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
local abilityRaze1 = nil;  -- Short range (200)
local abilityRaze2 = nil;  -- Medium range (450)
local abilityRaze3 = nil;  -- Long range (700)
local abilityFrenzy = nil;
local abilityRequiem = nil;
local abilityNecromastery = nil;

local castRaze1Des = 0;
local castRaze2Des = 0;
local castRaze3Des = 0;
local castFrenzyDes = 0;
local castRequiemDes = 0;

-- Raze combo tracking
local lastRazeTime = 0;
local razeComboWindow = 0.5;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityRaze1 == nil then abilityRaze1 = bot:GetAbilityByName("nevermore_shadowraze1"); end
    if abilityRaze2 == nil then abilityRaze2 = bot:GetAbilityByName("nevermore_shadowraze2"); end
    if abilityRaze3 == nil then abilityRaze3 = bot:GetAbilityByName("nevermore_shadowraze3"); end
    if abilityFrenzy == nil then abilityFrenzy = bot:GetAbilityByName("nevermore_frenzy"); end
    if abilityRequiem == nil then abilityRequiem = bot:GetAbilityByName("nevermore_requiem"); end
    if abilityNecromastery == nil then abilityNecromastery = bot:GetAbilityByName("nevermore_necromastery"); end

    -- Check for Euls combo
    local eulsCombo = ConsiderEulsRequiemCombo();
    if eulsCombo > 0 then
        return;
    end

    -- Consider abilities
    castRequiemDes = ConsiderRequiem();
    castFrenzyDes = ConsiderFrenzy();
    castRaze1Des = ConsiderRaze1();
    castRaze2Des = ConsiderRaze2();
    castRaze3Des = ConsiderRaze3();

    -- Priority: Ultimate > Frenzy > Razes
    if castRequiemDes > 0 then
        bot:Action_UseAbility(abilityRequiem);
        return;
    end

    if castFrenzyDes > 0 then
        bot:Action_UseAbility(abilityFrenzy);
        return;
    end

    if castRaze1Des > 0 then
        bot:Action_UseAbility(abilityRaze1);
        lastRazeTime = DotaTime();
        return;
    end

    if castRaze2Des > 0 then
        bot:Action_UseAbility(abilityRaze2);
        lastRazeTime = DotaTime();
        return;
    end

    if castRaze3Des > 0 then
        bot:Action_UseAbility(abilityRaze3);
        lastRazeTime = DotaTime();
        return;
    end
end

-- Helper functions
local function GetSoulCount()
    if abilityNecromastery == nil then return 0, 0 end
    local maxSouls = abilityNecromastery:GetSpecialValueInt("necromastery_max_souls");
    local souls = bot:GetModifierStackCount(bot:GetModifierByName("modifier_nevermore_necromastery"));
    return souls, maxSouls;
end

local function IsInRazeRange(target, rangeCenter, radius)
    if not mutils.IsValidTarget(target) then return false end
    if not bot:IsFacingLocation(target:GetLocation(), 15) then return false end
    
    local distance = GetUnitToUnitDistance(bot, target);
    return distance >= (rangeCenter - radius) and distance <= (rangeCenter + radius);
end

local function CountCreepsInRazeArea(rangeCenter, radius)
    local creeps = bot:GetNearbyLaneCreeps(math.min(rangeCenter + radius + 200, 1600), true);
    local count = 0;
    
    for _, creep in pairs(creeps) do
        if creep ~= nil and creep:CanBeSeen() and not creep:IsMagicImmune() then
            local dist = GetUnitToUnitDistance(bot, creep);
            if dist >= (rangeCenter - radius) and dist <= (rangeCenter + radius) then
                if bot:IsFacingLocation(creep:GetLocation(), 15) then
                    count = count + 1;
                end
            end
        end
    end
    
    return count;
end

function ConsiderRaze1()
    if not mutils.CanBeCast(abilityRaze1) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityRaze1:GetSpecialValueInt("shadowraze_radius");
    local nRange = abilityRaze1:GetSpecialValueInt("shadowraze_range");
    local manaCost = abilityRaze1:GetManaCost();

    -- FARMING: Clear creep waves
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot) or bot:GetActiveMode() == BOT_MODE_LANING) and mutils.CanSpamSpell(bot, manaCost) then
        local creepCount = CountCreepsInRazeArea(nRange, nRadius);
        if creepCount >= 3 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- HARASS/COMBAT: Hit enemy heroes
    local enemies = bot:GetNearbyHeroes(math.min(nRange + nRadius + 200, 1600), true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if IsInRazeRange(enemy, nRange, nRadius) then
                -- Aggressive in lane with good mana
                if bot:GetActiveMode() == BOT_MODE_LANING and mutils.CanSpamSpell(bot, manaCost) then
                    return BOT_ACTION_DESIRE_MODERATE;
                end
                
                -- Always use when going on someone
                if mutils.IsGoingOnSomeone(bot) then
                    return BOT_ACTION_DESIRE_HIGH;
                end
                
                -- Use when retreating if enemy is close
                if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByHero(enemy, 2.0) then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderRaze2()
    if not mutils.CanBeCast(abilityRaze2) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityRaze2:GetSpecialValueInt("shadowraze_radius");
    local nRange = abilityRaze2:GetSpecialValueInt("shadowraze_range");
    local manaCost = abilityRaze2:GetManaCost();

    -- FARMING
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot) or bot:GetActiveMode() == BOT_MODE_LANING) and mutils.CanSpamSpell(bot, manaCost) then
        local creepCount = CountCreepsInRazeArea(nRange, nRadius);
        if creepCount >= 3 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- COMBAT
    local enemies = bot:GetNearbyHeroes(math.min(nRange + nRadius + 200, 1600), true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if IsInRazeRange(enemy, nRange, nRadius) then
                if bot:GetActiveMode() == BOT_MODE_LANING and mutils.CanSpamSpell(bot, manaCost) then
                    return BOT_ACTION_DESIRE_MODERATE;
                end
                
                if mutils.IsGoingOnSomeone(bot) then
                    return BOT_ACTION_DESIRE_HIGH;
                end
                
                if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByHero(enemy, 2.0) then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderRaze3()
    if not mutils.CanBeCast(abilityRaze3) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityRaze3:GetSpecialValueInt("shadowraze_radius");
    local nRange = abilityRaze3:GetSpecialValueInt("shadowraze_range");
    local manaCost = abilityRaze3:GetManaCost();

    -- FARMING
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot) or bot:GetActiveMode() == BOT_MODE_LANING) and mutils.CanSpamSpell(bot, manaCost) then
        local creepCount = CountCreepsInRazeArea(nRange, nRadius);
        if creepCount >= 3 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- COMBAT
    local enemies = bot:GetNearbyHeroes(math.min(nRange + nRadius + 200, 1600), true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if IsInRazeRange(enemy, nRange, nRadius) then
                if bot:GetActiveMode() == BOT_MODE_LANING and mutils.CanSpamSpell(bot, manaCost) then
                    return BOT_ACTION_DESIRE_MODERATE;
                end
                
                if mutils.IsGoingOnSomeone(bot) then
                    return BOT_ACTION_DESIRE_HIGH;
                end
                
                if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByHero(enemy, 2.0) then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderFrenzy()
    if not mutils.CanBeCast(abilityFrenzy) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local souls, maxSouls = GetSoulCount();
    local soulCost = abilityFrenzy:GetSpecialValueInt("soul_cost");
    
    -- Need enough souls to use
    if souls < soulCost then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- TEAMFIGHT: Use for attack speed boost
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(1000, 1600), true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- GOING ON SOMEONE: Boost damage output
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) <= 800 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- PUSHING: Fast tower damage with good soul count
    if mutils.IsPushing(bot) and souls >= maxSouls * 0.7 then
        local towers = bot:GetNearbyTowers(math.min(900, 1600), true);
        if #towers > 0 then
            return BOT_ACTION_DESIRE_LOW;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderRequiem()
    if not mutils.CanBeCast(abilityRequiem) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local souls, maxSouls = GetSoulCount();
    local nRadius = abilityRequiem:GetSpecialValueInt("requiem_radius");
    
    -- Need decent soul count for damage
    if souls < maxSouls * 0.5 then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- TEAMFIGHT: Multiple enemies nearby
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(nRadius * 0.75, 1600), true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end

    -- GOING ON SOMEONE: Burst damage on target
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= nRadius * 0.6 then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    -- RETREATING: Defensive nuke
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
        local enemies = bot:GetNearbyHeroes(math.min(nRadius * 0.75, 1600), true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderEulsRequiemCombo()
    if not mutils.CanBeCast(abilityRequiem) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local souls, maxSouls = GetSoulCount();
    if souls < maxSouls * 0.5 then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Check if we have Euls
    local euls = nil;
    for i = 0, 8 do
        local item = bot:GetItemInSlot(i);
        if item ~= nil and item:GetName() == "item_cyclone" then
            euls = item;
            break;
        end
    end

    if euls == nil or not euls:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Look for isolated enemy hero
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= euls:GetCastRange() then
                -- Execute combo: Euls -> wait -> Requiem
                bot:Action_UseAbilityOnEntity(euls, target);
                bot:ActionQueue_Delay(2.2); -- Euls duration
                bot:ActionQueue_UseAbility(abilityRequiem);
                return BOT_ACTION_DESIRE_VERYHIGH;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end