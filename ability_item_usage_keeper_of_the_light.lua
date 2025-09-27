if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

-- Global variables
local abilityQ = nil;  -- Illuminate
local abilityW = nil;  -- Blinding Light
local abilityE = nil;  -- Chakra Magic / Radiant Bind (facet dependent)
local abilityR = nil;  -- Spirit Form
local abilityIllumEnd = nil;  -- Illuminate End
local abilityWillOWisp = nil;  -- Will O' Wisp (Scepter)
local abilityRadiantBind = nil;  -- Radiant Bind (Spirit Form)

local npcBot = nil;

-- State management
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;
local illuminateStartTime = 0;
local lastRadiantBindTargets = {};  -- Track shard charges
local lastRadiantBindTime = 0;

-- Think function protection
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
        -- Check if we should cancel Illuminate early
        local cancelDesire = ConsiderCancelIlluminate();
        if cancelDesire > 0 and abilityIllumEnd ~= nil and abilityIllumEnd:IsFullyCastable() then
            npcBot:Action_UseAbility(abilityIllumEnd);
        end
        return; -- Don't interrupt other channeling
    end
    
    -- Check if we're already using an ability
    if mutil.CanNotUseAbility(npcBot) then return end

    -- Initialize abilities by name (RECOMMENDED for KOTL)
    if abilityQ == nil then abilityQ = npcBot:GetAbilityByName("keeper_of_the_light_illuminate"); end
    if abilityW == nil then abilityW = npcBot:GetAbilityByName("keeper_of_the_light_blinding_light"); end
    if abilityE == nil then abilityE = npcBot:GetAbilityByName("keeper_of_the_light_chakra_magic"); end
    if abilityR == nil then abilityR = npcBot:GetAbilityByName("keeper_of_the_light_spirit_form"); end
    if abilityIllumEnd == nil then abilityIllumEnd = npcBot:GetAbilityByName("keeper_of_the_light_illuminate_end"); end
    if abilityWillOWisp == nil then abilityWillOWisp = npcBot:GetAbilityByName("keeper_of_the_light_will_o_wisp"); end
    if abilityRadiantBind == nil then abilityRadiantBind = npcBot:GetAbilityByName("keeper_of_the_light_radiant_bind"); end

    -- Consider using each ability in priority order
    local castWillOWispDesire, castWillOWispLoc = ConsiderWillOWisp();
    local castSpiritFormDesire = ConsiderSpiritForm();
    local castRadiantBindDesire, castRadiantBindTarget = ConsiderRadiantBind();
    local castBlindingLightDesire, castBlindingLightLoc = ConsiderBlindingLight();
    local castChakraMagicDesire, castChakraMagicTarget = ConsiderChakraMagic();
    local castIlluminateDesire, castIlluminateLoc = ConsiderIlluminate();

    -- Priority order: Scepter abilities > Ultimate > Escape > Offensive > Utility
    if castWillOWispDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilityWillOWisp, castWillOWispLoc);
        return;
    end

    if castSpiritFormDesire > 0 then
        npcBot:Action_UseAbility(abilityR);
        return;
    end

    if castBlindingLightDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilityW, castBlindingLightLoc);
        return;
    end

    if castRadiantBindDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityRadiantBind, castRadiantBindTarget);
        return;
    end

    if castChakraMagicDesire > 0 then
        npcBot:Action_UseAbilityOnEntity(abilityE, castChakraMagicTarget);
        return;
    end

    if castIlluminateDesire > 0 then
        illuminateStartTime = DotaTime();
        npcBot:Action_UseAbilityOnLocation(abilityQ, castIlluminateLoc);
        return;
    end
end

function ConsiderIlluminate()
    -- Check regular illuminate
    local illuminate = abilityQ;
    if illuminate == nil or not illuminate:IsFullyCastable() or illuminate:IsHidden() then 
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nRadius = illuminate:GetSpecialValueInt("radius");
    local nCastRange = math.min(illuminate:GetCastRange(), 1600);  -- RANGE FIX
    local nCastPoint = illuminate:GetCastPoint();

    -- Interrupt channeling enemies (highest priority)
    local enemies = npcBot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);  -- RANGE FIX
    for _, enemy in pairs(enemies) do
        if mutil.SafeIsChanneling(enemy) and mutil.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
        end
    end

    -- Farm lane creeps efficiently
    if mutil.IsDefending(npcBot) or mutil.IsPushing(npcBot) then
        local lanecreeps = npcBot:GetNearbyLaneCreeps(1600, true);
        local locationAoE = npcBot:FindAoELocation(true, false, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 3 and #lanecreeps >= 3 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end
    
    -- Team fight usage
    if mutil.IsInTeamFight(npcBot, 1200) then
        local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end
    
    -- Single target when going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) then
            return BOT_ACTION_DESIRE_MODERATE, npcTarget:GetExtrapolatedLocation(nCastPoint);
        end
    end
    
    -- Check for Sand King channeling (special case)
    local skThere, skLoc = mutil.IsSandKingThere(npcBot, nCastRange, 2.0);
    if skThere then
        return BOT_ACTION_DESIRE_HIGH, skLoc;
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderBlindingLight()
    if abilityW == nil or not abilityW:IsFullyCastable() or abilityW:IsHidden() then 
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nRadius = abilityW:GetSpecialValueInt("radius");
    local nCastRange = math.min(abilityW:GetCastRange(), 1600);  -- RANGE FIX
    local nCastPoint = abilityW:GetCastPoint();

    -- Escape usage (highest priority)
    if mutil.IsRetreating(npcBot) then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(math.min(nRadius + 200, 1600), true, BOT_MODE_NONE);  -- RANGE FIX
        for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
            if npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0) then
                -- Knock them back from our current position
                if GetUnitToUnitDistance(npcEnemy, npcBot) < nRadius then
                    return BOT_ACTION_DESIRE_HIGH, npcBot:GetLocation();
                else
                    return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetExtrapolatedLocation(nCastPoint);
                end
            end
        end
    end
    
    -- Team fight disruption
    if mutil.IsInTeamFight(npcBot, 1200) then
        local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end
    
    -- Offensive usage when going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and 
           mutil.IsInRange(npcTarget, npcBot, nCastRange - (nRadius / 2)) then
            return BOT_ACTION_DESIRE_MODERATE, npcTarget:GetExtrapolatedLocation(nCastPoint);
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderChakraMagic()
    if abilityE == nil or not abilityE:IsFullyCastable() then 
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityE:GetCastRange(), 1600);  -- RANGE FIX
    local currentManaPercent = npcBot:GetMana() / npcBot:GetMaxMana();
    
    -- Prioritize self when low on mana (30% more effective on self)
    if currentManaPercent < 0.4 then
        return BOT_ACTION_DESIRE_HIGH, npcBot;
    end
    
    -- Help nearby allies with low mana
    local tableNearbyFriendlyHeroes = npcBot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
    for _, myFriend in pairs(tableNearbyFriendlyHeroes) do
        if mutil.CanCastOnNonMagicImmune(myFriend) then
            local allyManaPercent = myFriend:GetMana() / myFriend:GetMaxMana();
            if allyManaPercent < 0.3 then
                return BOT_ACTION_DESIRE_HIGH, myFriend;
            elseif allyManaPercent < 0.6 then
                return BOT_ACTION_DESIRE_MODERATE, myFriend;
            end
        end
    end
    
    -- Use on self if we have decent mana but allies need help with cooldowns
    if currentManaPercent > 0.6 then
        return BOT_ACTION_DESIRE_LOW, npcBot;
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderRadiantBind()
    -- Only available in spirit form or with facet
    if abilityRadiantBind == nil or not abilityRadiantBind:IsFullyCastable() or abilityRadiantBind:IsHidden() then 
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityRadiantBind:GetCastRange(), 1600);  -- RANGE FIX
    local hasShard = npcBot:HasModifier("modifier_item_aghanims_shard");
    
    -- Clean up old targets from tracking
    if DotaTime() - lastRadiantBindTime > 30 then
        lastRadiantBindTargets = {};
    end
    
    -- Escape usage
    if mutil.IsRetreating(npcBot) then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
            if npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
                -- Don't waste shard charges on same target
                if not hasShard or not lastRadiantBindTargets[npcEnemy:GetPlayerID()] then
                    if hasShard then
                        lastRadiantBindTargets[npcEnemy:GetPlayerID()] = DotaTime();
                        lastRadiantBindTime = DotaTime();
                    end
                    return BOT_ACTION_DESIRE_HIGH, npcEnemy;
                end
            end
        end
    end

    -- Offensive usage
    if mutil.IsGoingOnSomeone(npcBot) then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and 
           mutil.IsInRange(npcTarget, npcBot, nCastRange + 200) then
            -- Don't waste shard charges
            if not hasShard or not lastRadiantBindTargets[npcTarget:GetPlayerID()] then
                if hasShard then
                    lastRadiantBindTargets[npcTarget:GetPlayerID()] = DotaTime();
                    lastRadiantBindTime = DotaTime();
                end
                return BOT_ACTION_DESIRE_HIGH, npcTarget;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderSpiritForm()
    if abilityR == nil or not abilityR:IsFullyCastable() or npcBot:HasModifier("modifier_keeper_of_the_light_spirit_form") then 
        return BOT_ACTION_DESIRE_NONE;
    end
    
    -- Use in team fights
    if mutil.IsInTeamFight(npcBot, 1200) then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
        if #tableNearbyEnemyHeroes >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- Use when going on someone for better positioning and illuminate
    if mutil.IsGoingOnSomeone(npcBot) then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, 1000) then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- Use when retreating for survivability
    if mutil.IsRetreating(npcBot) then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
        for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
            if npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0) then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end
    
    -- Use when pushing for better illuminate positioning
    if mutil.IsPushing(npcBot) then
        local nearbyTower = npcBot:GetNearbyTowers(1200, true);
        if #nearbyTower > 0 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderWillOWisp()
    -- Only available with Aghanim's Scepter
    if not npcBot:HasScepter() or abilityWillOWisp == nil or not abilityWillOWisp:IsFullyCastable() or abilityWillOWisp:IsHidden() then 
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nRadius = abilityWillOWisp:GetSpecialValueInt("radius");
    local nCastRange = math.min(abilityWillOWisp:GetCastRange(), 1300);  -- RANGE FIX
    local nCastPoint = abilityWillOWisp:GetCastPoint();

    -- Escape usage
    if mutil.IsRetreating(npcBot) then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(math.min(nRadius + 200, 1600), true, BOT_MODE_NONE);  -- RANGE FIX
        for _, npcEnemy in pairs(tableNearbyEnemyHeroes) do
            if npcBot:WasRecentlyDamagedByHero(npcEnemy, 2.0) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
                return BOT_ACTION_DESIRE_HIGH, npcBot:GetLocation();
            end
        end
    end

    -- Team fight usage
    if mutil.IsInTeamFight(npcBot, 1200) then
        local locationAoE = npcBot:FindAoELocation(true, true, npcBot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end
    
    -- Offensive usage
    if mutil.IsGoingOnSomeone(npcBot) then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) then
            return BOT_ACTION_DESIRE_MODERATE, npcTarget:GetExtrapolatedLocation(nCastPoint);
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderCancelIlluminate()
    -- Only cancel if we're channeling illuminate
    if not mutil.SafeIsChanneling(npcBot) or not npcBot:HasModifier('modifier_keeper_of_the_light_illuminate') then 
        return BOT_ACTION_DESIRE_NONE; 
    end
    
    local channelTime = DotaTime() - illuminateStartTime;
    local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes(1300, true, BOT_MODE_NONE);
    local botHealthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
    
    -- EMERGENCY: Cancel if very low health and taking damage
    if botHealthPercent < 0.25 and npcBot:WasRecentlyDamagedByAnyHero(0.5) then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end
    
    -- Cancel if we're taking heavy damage and haven't channeled for at least 2 seconds
    if #tableNearbyEnemyHeroes >= 2 and npcBot:WasRecentlyDamagedByAnyHero(1.0) and channelTime < 2.0 then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- Cancel if single enemy and taking damage but only after 1.5 seconds minimum
    if #tableNearbyEnemyHeroes == 1 and npcBot:WasRecentlyDamagedByAnyHero(1.0) and channelTime < 1.5 then
        return BOT_ACTION_DESIRE_MODERATE;
    end
    
    -- Cancel if enemies are escaping but only after 2.5 seconds of channeling
    if channelTime > 2.5 then
        for _, enemy in pairs(tableNearbyEnemyHeroes) do
            if mutil.IsValidTarget(enemy) then
                local enemyMoving = enemy:GetMovementDirectionStability() < 0.5;
                if enemyMoving and GetUnitToUnitDistance(enemy, npcBot) > 900 then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end
    
    -- Auto-release after 3.5 seconds for maximum damage (close to full charge)
    if channelTime >= 3.5 then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    return BOT_ACTION_DESIRE_NONE;
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