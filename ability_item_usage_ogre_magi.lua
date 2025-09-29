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

local abilityQ = nil; -- Fireblast
local abilityW = nil; -- Ignite
local abilityE = nil; -- Bloodlust
local abilityR = nil; -- Multicast (passive)
local abilityScepter = nil; -- Unrefined Fireblast
local abilityShard = nil; -- Fire Shield (Smash)

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castScepterDesire = 0;
local castShardDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("ogre_magi_fireblast"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("ogre_magi_ignite"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("ogre_magi_bloodlust"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("ogre_magi_multicast"); end
    if abilityScepter == nil then abilityScepter = bot:GetAbilityByName("ogre_magi_unrefined_fireblast"); end
    if abilityShard == nil then abilityShard = bot:GetAbilityByName("ogre_magi_smash"); end

    -- Consider using each ability
    castScepterDesire, castScepterTarget = ConsiderUnrefinedFireblast();
    castQDesire, castQTarget = ConsiderFireblast();
    castWDesire, castWTarget = ConsiderIgnite();
    castShardDesire, castShardTarget = ConsiderFireShield();
    castEDesire, castETarget = ConsiderBloodlust();

    -- Priority: Scepter stun (if needed) > Regular stun > Ignite harassment > Fire Shield > Bloodlust buff
    if castScepterDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityScepter, castScepterTarget);
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityQ, castQTarget);
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityW, castWTarget);
        return;
    end

    if castShardDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityShard, castShardTarget);
        return;
    end

    if castEDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityE, castETarget);
        return;
    end
end

function ConsiderFireblast()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- INTERRUPT: Channeling enemies (HIGHEST PRIORITY)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- INTERRUPT: Teleporting enemies
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if enemy:HasModifier("modifier_teleporting") then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end

    -- DEFENSIVE: Save allies or self when retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if mutils.SafeWasRecentlyDamaged(bot, 2.0) then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end

    -- OFFENSIVE: Stop escaping enemies
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if enemy:IsRetreating() and enemy:GetHealth() / enemy:GetMaxHealth() < 0.4 then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            -- Don't stun if already stunned (save for chain stun)
            if not target:IsStunned() then
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderIgnite()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityW:GetCastRange(), 1600);
    local nDuration = abilityW:GetSpecialValueInt("duration");
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- DEFENSIVE: Slow enemies when retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if not enemy:HasModifier("modifier_ogre_magi_ignite") then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            if not target:HasModifier("modifier_ogre_magi_ignite") then
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
    end

    -- HARASSMENT: Spam on any enemy without the debuff (be annoying!)
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if not enemy:HasModifier("modifier_ogre_magi_ignite") then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    -- FARMING: Use on creeps if multicast is trained and pushing
    if abilityR ~= nil and abilityR:IsTrained() then
        if mutils.IsPushing(bot) or mutils.IsDefending(bot) then
            local manaPercent = bot:GetMana() / bot:GetMaxMana();
            if manaPercent > 0.6 then
                local creeps = bot:GetNearbyLaneCreeps(nCastRange, true);
                if #creeps >= 3 then
                    return BOT_ACTION_DESIRE_LOW, creeps[1];
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderBloodlust()
    if not mutils.CanBeCast(abilityE) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityE:GetCastRange(), 1600);
    local allies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), false, BOT_MODE_NONE);

    -- DEFENSIVE: Buff self when retreating for movement speed
    if mutils.IsRetreating(bot) then
        if not bot:HasModifier("modifier_ogre_magi_bloodlust") then
            return BOT_ACTION_DESIRE_HIGH, bot;
        end
    end

    -- OFFENSIVE: Buff carry or self when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        -- Prioritize carry
        for _, ally in pairs(allies) do
            if not ally:HasModifier("modifier_ogre_magi_bloodlust") then
                -- Prioritize right-click carries
                if ally:GetAttackDamage() > bot:GetAttackDamage() then
                    return BOT_ACTION_DESIRE_HIGH, ally;
                end
            end
        end
        
        -- Buff self if no carry needs it
        if not bot:HasModifier("modifier_ogre_magi_bloodlust") then
            return BOT_ACTION_DESIRE_MODERATE, bot;
        end
    end

    -- DEFENSE: Buff towers when defending
    if mutils.IsDefending(bot) then
        local towers = bot:GetNearbyTowers(math.min(nCastRange + 200, 1600), false);
        for _, tower in pairs(towers) do
            if not tower:HasModifier("modifier_ogre_magi_bloodlust") then
                return BOT_ACTION_DESIRE_MODERATE, tower;
            end
        end
    end

    -- GENERAL: Buff allies without the buff
    for _, ally in pairs(allies) do
        if not ally:HasModifier("modifier_ogre_magi_bloodlust") then
            return BOT_ACTION_DESIRE_LOW, ally;
        end
    end

    -- GENERAL: Buff self if no one else needs it
    if not bot:HasModifier("modifier_ogre_magi_bloodlust") then
        return BOT_ACTION_DESIRE_LOW, bot;
    end

    -- PUSHING: Buff towers when pushing
    if mutils.IsPushing(bot) then
        local towers = bot:GetNearbyTowers(math.min(nCastRange + 200, 1600), false);
        for _, tower in pairs(towers) do
            if not tower:HasModifier("modifier_ogre_magi_bloodlust") then
                return BOT_ACTION_DESIRE_LOW, tower;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderUnrefinedFireblast()
    -- Check if we have scepter
    if not bot:HasScepter() or abilityScepter == nil or not abilityScepter:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Only use if regular Fireblast is on cooldown
    if abilityQ ~= nil and abilityQ:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityScepter:GetCastRange(), 1600);
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- Only use if we have good mana (costs 35% of current mana)
    if manaPercent < 0.5 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- INTERRUPT: Channeling enemies (HIGHEST PRIORITY)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- INTERRUPT: Teleporting enemies
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if enemy:HasModifier("modifier_teleporting") then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end

    -- DEFENSIVE: Save allies when retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if mutils.SafeWasRecentlyDamaged(bot, 2.0) then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            if not target:IsStunned() then
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderFireShield()
    -- Check if we have shard by checking if ability is not hidden
    if abilityShard == nil or abilityShard:IsHidden() or not abilityShard:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityShard:GetCastRange(), 1600);
    local allies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), false, BOT_MODE_NONE);

    -- DEFENSIVE: Protect allies taking damage
    for _, ally in pairs(allies) do
        if not ally:HasModifier("modifier_ogre_magi_smash_buff") then
            local allyHealthPercent = ally:GetHealth() / ally:GetMaxHealth();
            if allyHealthPercent < 0.6 and mutils.SafeWasRecentlyDamaged(ally, 2.0) then
                return BOT_ACTION_DESIRE_HIGH, ally;
            end
        end
    end

    -- OFFENSIVE: Buff carry when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        -- Prioritize carry
        for _, ally in pairs(allies) do
            if not ally:HasModifier("modifier_ogre_magi_smash_buff") then
                if ally:GetAttackDamage() > bot:GetAttackDamage() then
                    return BOT_ACTION_DESIRE_MODERATE, ally;
                end
            end
        end
        
        -- Buff self if no carry needs it
        if not bot:HasModifier("modifier_ogre_magi_smash_buff") then
            return BOT_ACTION_DESIRE_MODERATE, bot;
        end
    end

    -- DEFENSIVE: Protect towers
    if mutils.IsDefending(bot) then
        local towers = bot:GetNearbyTowers(math.min(nCastRange + 200, 1600), false);
        for _, tower in pairs(towers) do
            if not tower:HasModifier("modifier_ogre_magi_smash_buff") then
                local enemies = tower:GetNearbyHeroes(800, true, BOT_MODE_NONE);
                if #enemies > 0 then
                    return BOT_ACTION_DESIRE_MODERATE, tower;
                end
            end
        end
    end

    -- GENERAL: Buff any ally without the buff
    for _, ally in pairs(allies) do
        if not ally:HasModifier("modifier_ogre_magi_smash_buff") then
            return BOT_ACTION_DESIRE_LOW, ally;
        end
    end

    -- GENERAL: Buff self if no one else needs it
    if not bot:HasModifier("modifier_ogre_magi_smash_buff") then
        local enemies = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies > 0 then
            return BOT_ACTION_DESIRE_LOW, bot;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end