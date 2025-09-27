if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

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

-- Ability variables
local abilityOnslaught = nil;           -- Q - Gap closer/escape
local abilityOnslaughtRelease = nil;    -- Q release
local abilityTrample = nil;             -- W - Movement damage
local abilityUproar = nil;              -- E - Damage/armor buff
local abilityPulverize = nil;           -- R - Ultimate stun
local abilityRockThrow = nil;           -- Shard ability

-- Combo timing variables
local onslaughtStartTime = 0;
local onslaughtChannelTime = 1.0;       -- Optimal charge time (tweakable)
local isChannelingOnslaught = false;

-- Desire variables
local castOnslaughtDesire = 0;
local castOnslaughtReleaseDesire = 0;
local castTrampleDesire = 0;
local castUproarDesire = 0;
local castPulverizeDesire = 0;
local castRockThrowDesire = 0;

local npcBot = nil;

function AbilityUsageThink()
    if npcBot == nil then npcBot = GetBot(); end
    
    -- Protect channeling abilities
    if npcBot:IsChanneling() then 
        print("[PRIMAL_BEAST] Currently channeling - not casting other abilities");
        return 
    end
    
    -- Check if we're already using an ability
    if mutil.CanNotUseAbility(npcBot) then return end

    -- Initialize abilities by name
    if abilityOnslaught == nil then abilityOnslaught = npcBot:GetAbilityByName("primal_beast_onslaught") end
    if abilityOnslaughtRelease == nil then abilityOnslaughtRelease = npcBot:GetAbilityByName("primal_beast_onslaught_release") end
    if abilityTrample == nil then abilityTrample = npcBot:GetAbilityByName("primal_beast_trample") end
    if abilityUproar == nil then abilityUproar = npcBot:GetAbilityByName("primal_beast_uproar") end
    if abilityPulverize == nil then abilityPulverize = npcBot:GetAbilityByName("primal_beast_pulverize") end
    if abilityRockThrow == nil then abilityRockThrow = npcBot:GetAbilityByName("primal_beast_rock_throw") end

    -- Check onslaught timing for release
    if isChannelingOnslaught and npcBot:HasModifier("modifier_primal_beast_onslaught_charge") then
        local chargeTime = DotaTime() - onslaughtStartTime;
        if chargeTime >= onslaughtChannelTime then
            print("[PRIMAL_BEAST] Releasing Onslaught after " .. chargeTime .. " seconds");
            npcBot:Action_UseAbility(abilityOnslaughtRelease);
            isChannelingOnslaught = false;
            return;
        end
    end

    -- Consider using each ability
    castOnslaughtDesire, castOnslaughtTarget = ConsiderOnslaught();
    castTrampleDesire = ConsiderTrample();
    castUproarDesire = ConsiderUproar();
    castPulverizeDesire, castPulverizeTarget = ConsiderPulverize();
    castRockThrowDesire, castRockThrowTarget = ConsiderRockThrow();

    -- PRIORITY 1: Ultimate - Pulverize (highest priority)
    if (castPulverizeDesire > 0) then
        print("[PRIMAL_BEAST] Using Pulverize on " .. castPulverizeTarget:GetUnitName());
        npcBot:Action_UseAbilityOnEntity(abilityPulverize, castPulverizeTarget);
        return;
    end

    -- PRIORITY 2: Rock Throw (shard ability - high priority)
    if (castRockThrowDesire > 0) then
        print("[PRIMAL_BEAST] Using Rock Throw");
        npcBot:Action_UseAbilityOnLocation(abilityRockThrow, castRockThrowTarget);
        return;
    end

    -- PRIORITY 3: Onslaught + Trample combo
    if (castOnslaughtDesire > 0 and castTrampleDesire > 0) then
        print("[PRIMAL_BEAST] Using COMBO: Onslaught + Trample");
        npcBot:Action_ClearActions(false);
        npcBot:ActionQueue_UseAbilityOnLocation(abilityOnslaught, castOnslaughtTarget);
        npcBot:ActionQueue_UseAbility(abilityTrample);
        onslaughtStartTime = DotaTime();
        isChannelingOnslaught = true;
        return;
    end

    -- PRIORITY 4: Individual abilities
    if (castUproarDesire > 0) then
        print("[PRIMAL_BEAST] Using Uproar");
        npcBot:Action_UseAbility(abilityUproar);
        return;
    end

    if (castOnslaughtDesire > 0) then
        print("[PRIMAL_BEAST] Using Onslaught");
        npcBot:Action_UseAbilityOnLocation(abilityOnslaught, castOnslaughtTarget);
        onslaughtStartTime = DotaTime();
        isChannelingOnslaught = true;
        return;
    end

    if (castTrampleDesire > 0) then
        print("[PRIMAL_BEAST] Using Trample");
        npcBot:Action_UseAbility(abilityTrample);
        return;
    end
end

function ConsiderOnslaught()
    -- Make sure it's castable
    if not mutil.CanBeCast(abilityOnslaught) then 
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = 1400; -- Reduced from 2000 to avoid cache warnings
    local nManaCost = abilityOnslaught:GetManaCost();
    local manaPercent = npcBot:GetMana() / npcBot:GetMaxMana();

    -- Don't use if already charging
    if npcBot:HasModifier("modifier_primal_beast_onslaught_charge") then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- MANA CONSERVATION: Don't use if low mana unless emergency
    if manaPercent < 0.4 and not mutil.IsRetreating(npcBot) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- INTERRUPT: Channeling enemies (highest priority)
    local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if enemy:IsChanneling() and mutil.CanCastOnNonMagicImmune(enemy) then
            print("[PRIMAL_BEAST] INTERRUPT Onslaught on " .. enemy:GetUnitName());
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end

    -- ESCAPE: Use when retreating and in real danger
    if mutil.IsRetreating(npcBot) then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
        if #tableNearbyEnemyHeroes > 0 and npcBot:WasRecentlyDamagedByAnyHero(2.0) then
            local escapeLocation = GetEscapeLocation(npcBot:GetLocation(), nCastRange);
            print("[PRIMAL_BEAST] ESCAPE Onslaught");
            return BOT_ACTION_DESIRE_HIGH, escapeLocation;
        end
    end

    -- TEAMFIGHT: Gap close in teamfights (more restrictive)
    if mutil.IsInTeamFight(npcBot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutil.IsValidTarget(enemy) then
                local distance = GetUnitToUnitDistance(enemy, npcBot);
                if distance > 800 and distance < nCastRange then
                    print("[PRIMAL_BEAST] TEAMFIGHT Onslaught gap close");
                    return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation();
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone (more restrictive)
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(target, npcBot);
            -- Only use for significant gap closing and when we have good mana
            if distance > 1000 and distance < nCastRange and manaPercent > 0.6 then
                print("[PRIMAL_BEAST] OFFENSIVE Onslaught on " .. target:GetUnitName());
                return BOT_ACTION_DESIRE_MODERATE, target:GetExtrapolatedLocation(1.0);
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTrample()
    -- Make sure it's castable
    if not mutil.CanBeCast(abilityTrample) then 
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = 230; -- From ability data
    local nManaCost = abilityTrample:GetManaCost();
    local manaPercent = npcBot:GetMana() / npcBot:GetMaxMana();

    -- TEAMFIGHT: Always use in team fights
    if mutil.IsInTeamFight(npcBot, 1200) then
        local nearbyEnemies = npcBot:GetNearbyHeroes(nRadius + 200, true, BOT_MODE_NONE);
        if #nearbyEnemies >= 1 then
            print("[PRIMAL_BEAST] TEAMFIGHT Trample");
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- OFFENSIVE: When going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and GetUnitToUnitDistance(target, npcBot) < nRadius + 300 then
            print("[PRIMAL_BEAST] OFFENSIVE Trample");
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- FARMING: Use when farming (more prominent farming behavior)
    if (npcBot:GetActiveMode() == BOT_MODE_FARM or npcBot:GetActiveMode() == BOT_MODE_LANING) and mutil.AllowedToSpam(npcBot, nManaCost) then
        local nearbyCreeps = npcBot:GetNearbyLaneCreeps(nRadius + 200, true);
        local neutralCreeps = npcBot:GetNearbyNeutralCreeps(nRadius + 200);
        
        -- Prioritize farming when we have good creep density
        if #nearbyCreeps >= 3 or #neutralCreeps >= 2 then
            print("[PRIMAL_BEAST] FARMING Trample - " .. #nearbyCreeps .. " lane creeps, " .. #neutralCreeps .. " neutrals");
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- JUNGLE FARMING: More aggressive jungle farming
    if npcBot:GetActiveMode() == BOT_MODE_FARM and manaPercent > 0.3 then
        local neutralCreeps = npcBot:GetNearbyNeutralCreeps(nRadius + 200);
        if #neutralCreeps >= 2 then
            print("[PRIMAL_BEAST] JUNGLE Trample - " .. #neutralCreeps .. " neutrals");
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- PUSHING/DEFENDING: Only when we have good mana
    if (mutil.IsPushing(npcBot) or mutil.IsDefending(npcBot)) and manaPercent > 0.4 then
        local nearbyCreeps = npcBot:GetNearbyLaneCreeps(nRadius + 200, true);
        if #nearbyCreeps >= 3 then
            print("[PRIMAL_BEAST] PUSHING/DEFENDING Trample");
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderUproar()
    -- Make sure it's castable
    if not mutil.CanBeCast(abilityUproar) then 
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Simple check: just verify if we have the uproar modifier (don't worry about stacks)
    local hasUproarBuff = npcBot:HasModifier("modifier_primal_beast_uproar");

    -- EMERGENCY: Use when low health and we have the buff
    if (npcBot:GetHealth() / npcBot:GetMaxHealth() < 0.3) and hasUproarBuff then
        local nearbyEnemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #nearbyEnemies > 0 then
            print("[PRIMAL_BEAST] EMERGENCY Uproar");
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end

    -- GENERAL USE: Use when we have the buff and in combat
    if hasUproarBuff then
        -- TEAMFIGHT: Always use in team fights
        if mutil.IsInTeamFight(npcBot, 1200) then
            print("[PRIMAL_BEAST] TEAMFIGHT Uproar");
            return BOT_ACTION_DESIRE_HIGH;
        end

        -- OFFENSIVE: When going on someone
        if mutil.IsGoingOnSomeone(npcBot) then
            print("[PRIMAL_BEAST] OFFENSIVE Uproar");
            return BOT_ACTION_DESIRE_HIGH;
        end

        -- GENERAL COMBAT: Any enemy nearby
        local nearbyEnemies = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
        if #nearbyEnemies > 0 then
            print("[PRIMAL_BEAST] COMBAT Uproar");
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderPulverize()
    -- Make sure it's castable
    if not mutil.CanBeCast(abilityPulverize) then 
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = 200; -- From ability data
    local nDamage = abilityPulverize:GetAbilityDamage();

    local nearbyEnemies = npcBot:GetNearbyHeroes(nCastRange + 100, true, BOT_MODE_NONE);

    -- INTERRUPT: Channeling enemies (HIGHEST PRIORITY - can pierce magic immunity)
    for _, enemy in pairs(nearbyEnemies) do
        if enemy:IsChanneling() then
            print("[PRIMAL_BEAST] INTERRUPT Pulverize on " .. enemy:GetUnitName());
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- KILL: If we can kill someone
    for _, enemy in pairs(nearbyEnemies) do
        if mutil.IsValidTarget(enemy) and mutil.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            print("[PRIMAL_BEAST] KILL Pulverize on " .. enemy:GetUnitName());
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- TEAMFIGHT: Use on priority targets
    if mutil.IsInTeamFight(npcBot, 1200) then
        -- Prioritize supports and carries
        for _, enemy in pairs(nearbyEnemies) do
            if mutil.IsValidTarget(enemy) then
                local enemyName = enemy:GetUnitName();
                -- Target supports and squishy heroes
                if string.find(enemyName, "crystal_maiden") or string.find(enemyName, "invoker") or 
                   string.find(enemyName, "pudge") or string.find(enemyName, "enigma") then
                    print("[PRIMAL_BEAST] TEAMFIGHT Priority Pulverize on " .. enemy:GetUnitName());
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
        
        -- Any valid target in teamfight
        if #nearbyEnemies > 0 then
            print("[PRIMAL_BEAST] TEAMFIGHT Pulverize");
            return BOT_ACTION_DESIRE_MODERATE, nearbyEnemies[1];
        end
    end

    -- OFFENSIVE: When going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and GetUnitToUnitDistance(target, npcBot) <= nCastRange then
            print("[PRIMAL_BEAST] OFFENSIVE Pulverize on " .. target:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    -- RETREAT: Use on pursuers when retreating
    if mutil.IsRetreating(npcBot) then
        for _, enemy in pairs(nearbyEnemies) do
            if npcBot:WasRecentlyDamagedByHero(enemy, 2.0) and mutil.IsValidTarget(enemy) then
                print("[PRIMAL_BEAST] RETREAT Pulverize on " .. enemy:GetUnitName());
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderRockThrow()
    -- Check if shard ability exists and is available
    if abilityRockThrow == nil or not abilityRockThrow:IsFullyCastable() or abilityRockThrow:IsHidden() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = 1800; -- From ability data
    local nRadius = 225; -- Impact radius
    local nDamage = 325; -- Base damage

    -- INTERRUPT: Channeling enemies
    local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if enemy:IsChanneling() and mutil.CanCastOnNonMagicImmune(enemy) then
            print("[PRIMAL_BEAST] INTERRUPT Rock Throw on " .. enemy:GetUnitName());
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end

    -- KILL: If we can kill someone
    for _, enemy in pairs(enemies) do
        if mutil.IsValidTarget(enemy) and mutil.CanCastOnNonMagicImmune(enemy) and 
           mutil.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_PHYSICAL) then
            print("[PRIMAL_BEAST] KILL Rock Throw on " .. enemy:GetUnitName());
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetExtrapolatedLocation(1.0);
        end
    end

    -- TEAMFIGHT: Multi-target scenarios
    if mutil.IsInTeamFight(npcBot, 1200) then
        local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nRadius/2, 1.0, 0);
        if locationAoE.count >= 2 then
            print("[PRIMAL_BEAST] TEAMFIGHT Rock Throw AoE - " .. locationAoE.count .. " enemies");
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end

    -- OFFENSIVE: Long range engagement
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(target, npcBot);
            if distance > 600 and distance < nCastRange then
                print("[PRIMAL_BEAST] OFFENSIVE Rock Throw on " .. target:GetUnitName());
                return BOT_ACTION_DESIRE_MODERATE, target:GetExtrapolatedLocation(1.0);
            end
        end
    end

    -- HARASSMENT: Long range poke
    if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, abilityRockThrow:GetManaCost()) then
        for _, enemy in pairs(enemies) do
            if mutil.IsValidTarget(enemy) and mutil.CanCastOnNonMagicImmune(enemy) and 
               GetUnitToUnitDistance(enemy, npcBot) > 800 then
                print("[PRIMAL_BEAST] HARASSMENT Rock Throw");
                return BOT_ACTION_DESIRE_LOW, enemy:GetExtrapolatedLocation(1.0);
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function GetEscapeLocation(currentLoc, maxDistance)
    local destination = {};
    if (GetTeam() == TEAM_RADIANT) then
        destination[1] = currentLoc[1] - maxDistance / math.sqrt(2);
        destination[2] = currentLoc[2] - maxDistance / math.sqrt(2);
    else
        destination[1] = currentLoc[1] + maxDistance / math.sqrt(2);
        destination[2] = currentLoc[2] + maxDistance / math.sqrt(2);
    end
    return Vector(destination[1], destination[2]);
end