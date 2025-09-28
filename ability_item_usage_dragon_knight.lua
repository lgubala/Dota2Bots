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

-- Initialize abilities by name (CRITICAL UPDATE)
local abilityQ = nil;  -- Breathe Fire
local abilityW = nil;  -- Dragon Tail
local abilityE = nil;  -- Dragon Blood (passive)
local abilityR = nil;  -- Elder Dragon Form
local abilityFire = nil;  -- Fireball (Shard ability)

local castQDesire = 0;
local castWDesire = 0;
local castRDesire = 0;
local castFireDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return; -- Don't interrupt channeling
    end

    -- Initialize abilities by exact name (ALWAYS RECOMMENDED)
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("dragon_knight_breathe_fire"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("dragon_knight_dragon_tail"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("dragon_knight_dragon_blood"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("dragon_knight_elder_dragon_form"); end
    if abilityFire == nil then abilityFire = bot:GetAbilityByName("dragon_knight_fireball"); end
    
    -- Consider using each ability
    castQDesire, castQTarget = ConsiderBreatheFire();
    castWDesire, castWTarget = ConsiderDragonTail();
    castRDesire = ConsiderElderDragonForm();
    castFireDesire, castFireTarget = ConsiderFireball();

    -- PRIORITY ORDER: Shard Fireball > Ultimate > Stun > Nuke
    -- Prioritize Fireball for aggressive spam gameplay
    if castFireDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityFire, castFireTarget);
        return;
    end

    if castRDesire > 0 then
        bot:Action_UseAbility(abilityR);
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityW, castWTarget);
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityQ, castQTarget);
        return;
    end
end

function ConsiderBreatheFire()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Get ability properties with range safety
    local nCastRange = math.min(abilityQ:GetSpecialValueInt("AbilityCastRange"), 1600);
    local nRadius = abilityQ:GetSpecialValueInt("end_radius");
    local nManaCost = abilityQ:GetManaCost();
    local nDamage = abilityQ:GetAbilityDamage();
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- INTERRUPT: Channeling enemies (highest priority)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
        end
    end
    
    -- KILLSTEAL: Secure kills
    for _, enemy in pairs(enemies) do
        if mutils.CanCastOnNonMagicImmune(enemy) and mutils.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- FARMING: Last hit and harass
    if bot:GetActiveMode() == BOT_MODE_FARM then
        local target = mutils.SafeGetAttackTarget(bot);
        if target ~= nil and not target:IsBuilding() then
            return BOT_ACTION_DESIRE_MODERATE, target:GetLocation();
        end
    end
    
    -- TEAMFIGHT: Multi-target scenarios
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end
    
    -- OFFENSIVE: Going on someone (aggressive harass)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
            return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
        end
    end
    
    -- DEFENSIVE: Retreating
    if mutils.IsRetreating(bot) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 1 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end
    
    -- PUSHING/DEFENDING: Wave clear when allowed to spam
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and mutils.AllowedToSpam(bot, nManaCost) then
        local creeps = bot:GetNearbyLaneCreeps(math.min(nCastRange + 200, 1600), true);
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 3 and #creeps >= 3 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end
    
    -- ROSHAN
    if bot:GetActiveMode() == BOT_MODE_ROSHAN then
        local target = mutils.SafeGetAttackTarget(bot);
        if mutils.IsRoshan(target) and mutils.CanCastOnMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
            return BOT_ACTION_DESIRE_MODERATE, target:GetLocation();
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderDragonTail()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Get cast range based on dragon form
    local nCastRange = abilityW:GetCastRange();
    if bot:HasModifier("modifier_dragon_knight_dragon_form") then
        nCastRange = abilityW:GetSpecialValueInt("dragon_cast_range");
    end
    nCastRange = math.min(nCastRange, 1600);
    
    local nManaCost = abilityW:GetManaCost();
    local nDamage = abilityW:GetAbilityDamage();
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- INTERRUPT: Channeling enemies (highest priority)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end
    
    -- KILLSTEAL: Secure kills
    for _, enemy in pairs(enemies) do
        if mutils.CanCastOnNonMagicImmune(enemy) and mutils.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end
    
    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           mutils.IsInRange(target, bot, nCastRange + 100) and not mutils.IsDisabled(true, target) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end
    
    -- TEAMFIGHT: Stun priority targets
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and mutils.IsInRange(enemy, bot, nCastRange) and
               not mutils.IsDisabled(true, enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end
    
    -- DEFENSIVE: Retreating - stun pursuers
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and mutils.IsInRange(enemy, bot, nCastRange) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end
    
    -- ROSHAN
    if bot:GetActiveMode() == BOT_MODE_ROSHAN then
        local target = mutils.SafeGetAttackTarget(bot);
        if mutils.IsRoshan(target) and mutils.CanCastOnMagicImmune(target) and 
           mutils.IsInRange(target, bot, nCastRange) and not mutils.IsDisabled(true, target) then
            return BOT_ACTION_DESIRE_MODERATE, target;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderElderDragonForm()
    if not mutils.CanBeCast(abilityR) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nManaCost = abilityR:GetManaCost();
    
    -- TEAMFIGHT: Transform for maximum impact
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.IsInRange(target, bot, 600) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- PUSHING: Transform when pushing towers
    if mutils.IsPushing(bot) then
        local towers = bot:GetNearbyTowers(1000, true);
        local creeps = bot:GetNearbyLaneCreeps(1000, false);
        if #towers >= 1 and #creeps >= 4 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- DEFENDING: Transform when defending
    if mutils.IsDefending(bot) then
        local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        if #enemies >= 1 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderFireball()
    -- Check if shard ability is available
    if abilityFire == nil or abilityFire:IsHidden() or not abilityFire:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Get cast range based on dragon form
    local nCastRange;
    if bot:HasModifier("modifier_dragon_knight_dragon_form") then
        nCastRange = abilityFire:GetSpecialValueInt("dragon_form_cast_range");
    else
        nCastRange = abilityFire:GetSpecialValueInt("melee_cast_range");
    end
    nCastRange = math.min(nCastRange, 1600);
    
    local nRadius = abilityFire:GetSpecialValueInt("radius");
    local nManaCost = abilityFire:GetManaCost();
    local nDamage = abilityFire:GetSpecialValueInt("damage");
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- INTERRUPT: Channeling enemies (highest priority)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- KILLSTEAL: Secure kills with DOT
    for _, enemy in pairs(enemies) do
        if mutils.CanCastOnNonMagicImmune(enemy) and mutils.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- TEAMFIGHT: AGGRESSIVE SPAM - This is our main damage dealer!
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 1 then -- Spam on even single targets in teamfights
            return BOT_ACTION_DESIRE_VERYHIGH, locationAoE.targetloc;
        end
    end
    
    -- OFFENSIVE: Going on someone - SPAM AGGRESSIVELY
    if mutil.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           mutils.IsInRange(target, bot, nCastRange) then
            return BOT_ACTION_DESIRE_VERYHIGH, target:GetLocation();
        end
    end
    
    -- FARMING: Enhanced farming with shard
    if bot:GetActiveMode() == BOT_MODE_FARM then
        local target = mutils.SafeGetAttackTarget(bot);
        if target ~= nil and not target:IsBuilding() then
            return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
        end
    end
    
    -- PUSHING/DEFENDING: Wave clear spam
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and mutils.AllowedToSpam(bot, nManaCost) then
        local creeps = bot:GetNearbyLaneCreeps(math.min(nCastRange + 200, 1600), true);
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 3 and #creeps >= 3 then
            return BOT_ACTION_DESIRE_VERYHIGH, locationAoE.targetloc;
        end
    end
    
    -- DEFENSIVE: Retreating - area denial
    if mutils.IsRetreating(bot) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 1 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end
    
    -- ROSHAN: Constant damage
    if bot:GetActiveMode() == BOT_MODE_ROSHAN then
        local target = mutils.SafeGetAttackTarget(bot);
        if mutils.IsRoshan(target) and mutils.CanCastOnMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
            return BOT_ACTION_DESIRE_VERYHIGH, target:GetLocation();
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end