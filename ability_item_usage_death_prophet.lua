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

local abilityQ = nil; -- Carrion Swarm / Crypt Swarm
local abilityW = nil; -- Silence
local abilityE = nil; -- Spirit Siphon
local abilityR = nil; -- Exorcism

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;

-- Track siphon charges and targets
local siphonCharges = 0;
local siphonedEnemies = {};

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("death_prophet_carrion_swarm"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("death_prophet_silence"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("death_prophet_spirit_siphon"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("death_prophet_exorcism"); end

    -- Update siphon charges
    UpdateSiphonTracking();

    -- Consider using each ability
    castRDesire = ConsiderExorcism();
    castQDesire, castQLocation = ConsiderCryptSwarm();
    castWDesire, castWLocation = ConsiderSilence();
    castEDesire, castETarget = ConsiderSpiritSiphon();

    -- Priority: Ultimate > Swarm spam > Silence > Siphon
    if castRDesire > 0 then
        bot:Action_UseAbility(abilityR);
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityQ, castQLocation);
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityW, castWLocation);
        return;
    end

    if castEDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityE, castETarget);
        return;
    end
end

function UpdateSiphonTracking()
    if abilityE == nil or not abilityE:IsTrained() then return end
    
    -- Get current charges
    siphonCharges = abilityE:GetCurrentCharges();
    
    -- Clean up siphoned enemies list (remove those without the debuff)
    local newSiphonedEnemies = {};
    for _, enemy in pairs(siphonedEnemies) do
        if enemy ~= nil and enemy:IsAlive() and enemy:HasModifier("modifier_death_prophet_spirit_siphon_slow") then
            table.insert(newSiphonedEnemies, enemy);
        end
    end
    siphonedEnemies = newSiphonedEnemies;
end

function ConsiderCryptSwarm()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local nRadius = abilityQ:GetSpecialValueInt("end_radius");
    local nDamage = abilityQ:GetSpecialValueInt("damage");
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- LAST HIT: Use for securing last hits on heroes
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            local enemyHealth = mutils.SafeGetHealth(enemy);
            local actualDamage = enemy:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_MAGICAL);
            if enemyHealth > 0 and enemyHealth <= actualDamage then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
            end
        end
    end

    -- TEAMFIGHT: Multi-target damage
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_VERYHIGH, locationAoE.targetloc;
        end
    end

    -- HARASSMENT: Spam on enemies constantly
    if manaPercent > 0.4 then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                local castPoint = abilityQ:GetCastPoint();
                return BOT_ACTION_DESIRE_HIGH, enemy:GetExtrapolatedLocation(castPoint);
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local castPoint = abilityQ:GetCastPoint();
            return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation(castPoint);
        end
    end

    -- FARMING: Use on creeps if we have good mana
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and manaPercent > 0.5 then
        local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 3 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderSilence()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityW:GetCastRange(), 1600);
    local nRadius = abilityW:GetSpecialValueInt("radius");
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- INTERRUPT: Channeling enemies (HIGHEST PRIORITY)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            -- Don't silence teleporting enemies (let stuns handle that)
            if not enemy:HasModifier("modifier_teleporting") then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
            end
        end
    end

    -- SAVE ALLIES: Silence enemies attacking low HP allies
    local allies = bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        local allyHealthPercent = ally:GetHealth() / ally:GetMaxHealth();
        if allyHealthPercent < 0.3 then
            for _, enemy in pairs(enemies) do
                if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                    local distance = GetUnitToUnitDistance(enemy, ally);
                    if distance < 600 then
                        return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
                    end
                end
            end
        end
    end

    -- TEAMFIGHT: Multi-target silence
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end

    -- DEFENSIVE: Silence when retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if mutils.SafeWasRecentlyDamaged(bot, 2.0) then
                    return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            -- Don't silence if already disabled
            if not target:IsStunned() and not target:IsSilenced() then
                local castPoint = abilityW:GetCastPoint();
                return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation(castPoint);
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderSpiritSiphon()
    if not mutils.CanBeCast(abilityE) or siphonCharges == 0 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityE:GetCastRange(), 1600);
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- Helper function to check if enemy is already siphoned
    local function IsAlreadySiphoned(enemy)
        return enemy:HasModifier("modifier_death_prophet_spirit_siphon_slow");
    end

    -- DEFENSIVE: Use when low HP for healing
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    if healthPercent < 0.6 and (mutils.IsRetreating(bot) or mutils.IsInTeamFight(bot, 1200)) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if not IsAlreadySiphoned(enemy) then
                    table.insert(siphonedEnemies, enemy);
                    return BOT_ACTION_DESIRE_VERYHIGH, enemy;
                end
            end
        end
    end

    -- TEAMFIGHT: Use on multiple enemies
    if mutils.IsInTeamFight(bot, 1200) then
        -- Find enemy without siphon
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if not IsAlreadySiphoned(enemy) then
                    table.insert(siphonedEnemies, enemy);
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            if not IsAlreadySiphoned(target) then
                table.insert(siphonedEnemies, target);
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
        
        -- If primary target already siphoned, find another nearby enemy
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if not IsAlreadySiphoned(enemy) and enemy ~= target then
                    table.insert(siphonedEnemies, enemy);
                    return BOT_ACTION_DESIRE_MODERATE, enemy;
                end
            end
        end
    end

    -- HARASSMENT: Use on any enemy hero without siphon
    if healthPercent < 0.95 then -- Only if we can benefit from healing
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                if not IsAlreadySiphoned(enemy) then
                    table.insert(siphonedEnemies, enemy);
                    return BOT_ACTION_DESIRE_LOW, enemy;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderExorcism()
    if not mutils.CanBeCast(abilityR) then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Don't use if already active
    if bot:HasModifier("modifier_death_prophet_exorcism") then
        return BOT_ACTION_DESIRE_NONE;
    end

    local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);

    -- TEAMFIGHT: Big teamfight usage (highest priority)
    if mutils.IsInTeamFight(bot, 1200) then
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end

    -- PUSHING: Use when pushing towers with team
    if mutils.IsPushing(bot) then
        local towers = bot:GetNearbyTowers(1000, true);
        if #towers > 0 then
            local allies = bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE);
            local creeps = bot:GetNearbyLaneCreeps(1000, false);
            -- Use if we have support and creeps
            if #allies >= 1 and #creeps >= 3 then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    -- OFFENSIVE: Use when going on multiple enemies
    if mutils.IsGoingOnSomeone(bot) then
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end