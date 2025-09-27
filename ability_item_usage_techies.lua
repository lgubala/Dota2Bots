if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
    return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")

-- Global variables
local npcBot = nil;
local abilitySB = nil;  -- Sticky Bomb (Q)
local abilityRT = nil;  -- Reactive Tazer (W)
local abilitySU = nil;  -- Suicide (E)
local abilityMS = nil;  -- Minefield Sign (D)
local abilityLM = nil;  -- Land Mines (R)

-- State management for universal fixes
local lastDeathTime = 0;
local postDeathCooldown = 3.0;
local isRecoveringFromDeath = false;

-- Techies specific state
local lastComboTime = 0;
local comboStartTime = 0;
local isInCombo = false;
local mineLocations = {}; -- Track where we've placed mines
local lastMinePlantTime = 0;
local minePlantCooldown = 1.0; -- Space out mine planting
local lastSuicideTime = 0;
local suicideCooldown = 30.0; -- Don't spam suicide

-- Combo constants
local COMBO_SUICIDE_RANGE = 800;
local COMBO_MINE_COUNT = 3; -- How many mines to plant in combo
local MINE_OVERLAP_DISTANCE = 350; -- Minimum distance between mines

-- Think function protection
function AbilityLevelUpThink()  
    if isRecoveringFromDeath then return; end
    if mutil.SafeIsChanneling(npcBot) then return; end
    ability_item_usage_generic.AbilityLevelUpThink(); 
end

function BuybackUsageThink()
    if isRecoveringFromDeath then return; end
    if mutil.SafeIsChanneling(npcBot) then return; end
    ability_item_usage_generic.BuybackUsageThink();
end

function CourierUsageThink()
    if isRecoveringFromDeath then return; end
    if mutil.SafeIsChanneling(npcBot) then return; end
    ability_item_usage_generic.CourierUsageThink();
end

function ItemUsageThink()
    if isRecoveringFromDeath then return; end
    if mutil.SafeIsChanneling(npcBot) then return; end
    ability_item_usage_generic.ItemUsageThink();
end

function AbilityUsageThink()
    if npcBot == nil then npcBot = GetBot(); end
    
    -- UNIVERSAL FOUNTAIN STUCK FIX
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
        isInCombo = false; -- Reset combo state on death
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

    -- Check if we're already using an ability
    if mutil.CanNotUseAbility(npcBot) then return end

    -- Initialize abilities by name (RECOMMENDED approach)
    if abilitySB == nil then abilitySB = npcBot:GetAbilityByName("techies_sticky_bomb"); end
    if abilityRT == nil then abilityRT = npcBot:GetAbilityByName("techies_reactive_tazer"); end
    if abilitySU == nil then abilitySU = npcBot:GetAbilityByName("techies_suicide"); end
    if abilityMS == nil then abilityMS = npcBot:GetAbilityByName("techies_minefield_sign"); end
    if abilityLM == nil then abilityLM = npcBot:GetAbilityByName("techies_land_mines"); end

    -- Clean up old mine locations
    CleanupOldMineLocations();

    -- Handle combo logic first
    if isInCombo then
        local comboAction = HandleComboExecution();
        if comboAction then
            return;
        end
    end

    -- PRIORITY ORDER: Combo Initiation -> Emergency -> Harassment -> Mining -> Defense

    -- 1. COMBO: THE TECHIES SPECIAL (Suicide + Tazer + Mines + Minefield)
    local comboDesire = ConsiderComboInitiation();
    if comboDesire > 0 then
        print("[TECHIES] INITIATING COMBO! Desire: " .. comboDesire); -- Debug
        InitiateTechiesCombo();
        return;
    end

    -- 2. EMERGENCY: Reactive Tazer for defense
    local castRTDesire, castRTTarget = ConsiderReactiveTazer();
    if castRTDesire >= BOT_ACTION_DESIRE_HIGH then
        if castRTTarget then
            npcBot:Action_UseAbilityOnEntity(abilityRT, castRTTarget);
        else
            npcBot:Action_UseAbility(abilityRT);
        end
        return;
    end

    -- 3. HARASSMENT: Sticky Bomb for damage
    local castSBDesire, castSBLocation = ConsiderStickyBomb();
    if castSBDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilitySB, castSBLocation);
        return;
    end

    -- 4. MINING: Strategic mine placement
    local castLMDesire, castLMLocation = ConsiderLandMines();
    if castLMDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilityLM, castLMLocation);
        TrackMinePlacement(castLMLocation);
        lastMinePlantTime = DotaTime();
        return;
    end

    -- 5. DEFENSE: Minefield Sign (Scepter only)
    local castMSDesire, castMSLocation = ConsiderMinefieldSign();
    if castMSDesire > 0 then
        npcBot:Action_UseAbilityOnLocation(abilityMS, castMSLocation);
        return;
    end

    -- 6. LOWER PRIORITY: Reactive Tazer for utility
    if castRTDesire > 0 then
        if castRTTarget then
            npcBot:Action_UseAbilityOnEntity(abilityRT, castRTTarget);
        else
            npcBot:Action_UseAbility(abilityRT);
        end
        return;
    end
end

function ConsiderStickyBomb()
    if not abilitySB or not abilitySB:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilitySB:GetCastRange();
    local nRadius = abilitySB:GetSpecialValueInt("radius");
    local nDamage = abilitySB:GetSpecialValueInt("damage");

    -- TEAMFIGHT: High priority in fights
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnNonMagicImmune(enemy) then
                -- Predict enemy movement
                local targetLocation = enemy:GetLocation();
                if enemy:GetMovementDirectionStability() > 0.7 then
                    targetLocation = enemy:GetExtrapolatedLocation(0.5);
                end
                return BOT_ACTION_DESIRE_HIGH, targetLocation;
            end
        end
    end

    -- HARASSMENT: Lane harassment
    if npcBot:GetActiveMode() == BOT_MODE_LANING then
        local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnNonMagicImmune(enemy) then
                local healthPercent = enemy:GetHealth() / enemy:GetMaxHealth();
                if healthPercent < 0.7 then -- Harass wounded enemies
                    return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation();
                end
            end
        end
    end

    -- FINISHING: Kill low HP enemies
    local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if mutil.CanCastOnNonMagicImmune(enemy) and 
           mutil.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end

    -- OFFENSIVE: When going on someone
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and 
           mutil.CanCastOnNonMagicImmune(target) and 
           mutil.IsInRange(target, npcBot, nCastRange) then
            return BOT_ACTION_DESIRE_MODERATE, target:GetLocation();
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderReactiveTazer()
    if not abilityRT or not abilityRT:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local hasShard = npcBot:HasModifier("modifier_item_aghanims_shard");

    -- EMERGENCY: Defensive use when being attacked
    if mutil.IsRetreating(npcBot) or npcBot:WasRecentlyDamagedByAnyHero(2.0) then
        local enemies = npcBot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
        if #enemies >= 1 then
            if hasShard then
                -- Use on self for escape
                return BOT_ACTION_DESIRE_VERYHIGH, npcBot;
            else
                return BOT_ACTION_DESIRE_VERYHIGH, nil;
            end
        end
    end

    -- ALLY SAVE: Use shard version on endangered allies
    if hasShard then
        local allies = npcBot:GetNearbyHeroes(500, false, BOT_MODE_NONE);
        for _, ally in pairs(allies) do
            if ally:IsAlive() and ally:WasRecentlyDamagedByAnyHero(1.5) then
                local healthPercent = ally:GetHealth() / ally:GetMaxHealth();
                if healthPercent < 0.3 then
                    return BOT_ACTION_DESIRE_HIGH, ally;
                end
            end
        end
    end

    -- TEAMFIGHT: Use for positioning and disruption
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(450, true, BOT_MODE_NONE); -- Disarm radius
        if #enemies >= 2 then
            if hasShard then
                return BOT_ACTION_DESIRE_MODERATE, npcBot;
            else
                return BOT_ACTION_DESIRE_MODERATE, nil;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderSuicide()
    if not abilitySU or not abilitySU:IsFullyCastable() or npcBot:IsRooted() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Don't spam suicide
    if DotaTime() - lastSuicideTime < suicideCooldown then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilitySU:GetCastRange();
    local nRadius = abilitySU:GetSpecialValueInt("radius");
    local nDamage = abilitySU:GetSpecialValueInt("damage");
    local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();

    -- Don't suicide if we're too low (would be fatal)
    if healthPercent < 0.25 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- TEAMFIGHT: Big impact in teamfights
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
        local potentialTargets = 0;
        local totalEnemyHealth = 0;
        
        for _, enemy in pairs(enemies) do
            if mutil.CanCastOnNonMagicImmune(enemy) then
                potentialTargets = potentialTargets + 1;
                totalEnemyHealth = totalEnemyHealth + enemy:GetHealth();
            end
        end
        
        -- Use if we can hit multiple enemies or deal significant damage
        if potentialTargets >= 2 or totalEnemyHealth < nDamage * potentialTargets then
            local centerLocation = GetEnemyCenter(enemies);
            if centerLocation then
                return BOT_ACTION_DESIRE_HIGH, centerLocation;
            end
        end
    end

    -- FINISHING: Kill multiple low HP enemies
    local enemies = npcBot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
    local killableEnemies = 0;
    
    for _, enemy in pairs(enemies) do
        if mutil.CanCastOnNonMagicImmune(enemy) and 
           mutil.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            killableEnemies = killableEnemies + 1;
        end
    end
    
    if killableEnemies >= 1 then
        local centerLocation = GetEnemyCenter(enemies);
        if centerLocation then
            return BOT_ACTION_DESIRE_VERYHIGH, centerLocation;
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderLandMines()
    if not abilityLM or not abilityLM:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Rate limit mine placement
    if DotaTime() - lastMinePlantTime < minePlantCooldown then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = abilityLM:GetCastRange();
    local distanceFromFountain = npcBot:DistanceFromFountain(); -- Fix: Define the variable

    -- DEFENSE: Protect base and towers
    if mutil.IsDefending(npcBot) then
        local towers = npcBot:GetNearbyTowers(800, false);
        if #towers > 0 then
            local tower = towers[1];
            local mineLocation = GetRandomMineLocation(tower:GetLocation(), 400);
            if mineLocation and not IsMineLocationOccupied(mineLocation) then
                return BOT_ACTION_DESIRE_MODERATE, mineLocation;
            end
        end
    end

    -- STRATEGIC: Random mine placement around map
    if npcBot:GetMana() / npcBot:GetMaxMana() > 0.6 and distanceFromFountain > 1000 then
        local randomLocation = GetStrategicMineLocation();
        if randomLocation and not IsMineLocationOccupied(randomLocation) then
            return BOT_ACTION_DESIRE_LOW, randomLocation;
        end
    end

    -- RETREAT: Place mines while retreating
    if mutil.IsRetreating(npcBot) then
        local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies > 0 then
            local mineLocation = npcBot:GetLocation() + RandomVector(200);
            if not IsMineLocationOccupied(mineLocation) then
                return BOT_ACTION_DESIRE_MODERATE, mineLocation;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderMinefieldSign()
    if not abilityMS or not abilityMS:IsFullyCastable() or abilityMS:IsHidden() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Only use with scepter (otherwise it's useless)
    if not npcBot:HasScepter() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- DEFENSE: Protect towers and base
    if mutil.IsDefending(npcBot) then
        local towers = npcBot:GetNearbyTowers(600, false);
        if #towers > 0 then
            local tower = towers[1];
            return BOT_ACTION_DESIRE_MODERATE, tower:GetLocation();
        end
    end

    -- TEAMFIGHT: Area denial
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            local centerLocation = GetEnemyCenter(enemies);
            if centerLocation then
                return BOT_ACTION_DESIRE_MODERATE, centerLocation;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

-- COMBO SYSTEM
function ConsiderComboInitiation()
    -- Don't start combo if recently used
    if DotaTime() - lastComboTime < 30.0 then -- Reduced from 45s to 30s
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Need suicide available for combo
    if not abilitySU or not abilitySU:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Need tazer available
    if not abilityRT or not abilityRT:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Need at least 1 mine charge
    if not abilityLM or not abilityLM:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    local healthPercent = npcBot:GetHealth() / npcBot:GetMaxHealth();
    if healthPercent < 0.3 then -- Reduced from 0.4 to 0.3 (more aggressive)
        return BOT_ACTION_DESIRE_NONE;
    end

    -- TEAMFIGHT COMBO: Multiple enemies (made more aggressive)
    if mutil.IsInTeamFight(npcBot, 1200) then
        local enemies = npcBot:GetNearbyHeroes(COMBO_SUICIDE_RANGE, true, BOT_MODE_NONE);
        if #enemies >= 1 then -- Reduced from 2 to 1 enemy
            return BOT_ACTION_DESIRE_VERYHIGH; -- Increased desire
        end
    end

    -- BIG OPPORTUNITY: Any enemy in range (much more aggressive)
    if mutil.IsGoingOnSomeone(npcBot) then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and 
           GetUnitToUnitDistance(npcBot, target) <= COMBO_SUICIDE_RANGE then
            return BOT_ACTION_DESIRE_HIGH; -- Always combo when going on someone
        end
    end

    -- OPPORTUNISTIC: Any nearby enemy when we have good health
    if healthPercent > 0.6 then
        local enemies = npcBot:GetNearbyHeroes(COMBO_SUICIDE_RANGE, true, BOT_MODE_NONE);
        if #enemies >= 1 then
            return BOT_ACTION_DESIRE_MODERATE; -- Try combo on any enemy
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function InitiateTechiesCombo()
    print("[TECHIES] COMBO STARTED!");
    isInCombo = true;
    comboStartTime = DotaTime();
    lastComboTime = DotaTime();
    
    -- Step 1: Activate Reactive Tazer first
    if abilityRT and abilityRT:IsFullyCastable() then
        print("[TECHIES] Using Reactive Tazer!");
        if npcBot:HasModifier("modifier_item_aghanims_shard") then
            npcBot:Action_UseAbilityOnEntity(abilityRT, npcBot);
        else
            npcBot:Action_UseAbility(abilityRT);
        end
    end
end

function HandleComboExecution()
    local comboTime = DotaTime() - comboStartTime;
    
    -- Combo timeout
    if comboTime > 8.0 then
        print("[TECHIES] Combo timeout!");
        isInCombo = false;
        return false;
    end

    -- Step 2: After tazer, use suicide (small delay)
    if comboTime > 0.5 and comboTime < 2.0 then -- Increased delay and window
        if abilitySU and abilitySU:IsFullyCastable() then
            local enemies = npcBot:GetNearbyHeroes(COMBO_SUICIDE_RANGE, true, BOT_MODE_NONE);
            if #enemies > 0 then
                print("[TECHIES] SUICIDE BOMBING! Enemies: " .. #enemies);
                local centerLocation = GetEnemyCenter(enemies);
                if centerLocation then
                    npcBot:Action_UseAbilityOnLocation(abilitySU, centerLocation);
                    lastSuicideTime = DotaTime();
                    return true;
                else
                    -- Fallback: suicide at first enemy
                    npcBot:Action_UseAbilityOnLocation(abilitySU, enemies[1]:GetLocation());
                    lastSuicideTime = DotaTime();
                    return true;
                end
            end
        end
    end
    
    -- Step 3: Plant mines rapidly after suicide
    if comboTime > 2.5 and comboTime < 6.0 then -- Longer window
        if abilityLM and abilityLM:IsFullyCastable() and 
           DotaTime() - lastMinePlantTime > 0.5 then -- Slower mine planting
            
            print("[TECHIES] Planting combo mine!");
            local mineLocation = GetComboMineLocation();
            if mineLocation and not IsMineLocationOccupied(mineLocation) then
                npcBot:Action_UseAbilityOnLocation(abilityLM, mineLocation);
                TrackMinePlacement(mineLocation);
                lastMinePlantTime = DotaTime();
                return true;
            else
                -- Fallback: plant at current location
                local fallbackLocation = npcBot:GetLocation() + RandomVector(200);
                npcBot:Action_UseAbilityOnLocation(abilityLM, fallbackLocation);
                TrackMinePlacement(fallbackLocation);
                lastMinePlantTime = DotaTime();
                return true;
            end
        end
    end
    
    -- Step 4: Minefield sign if we have scepter
    if comboTime > 6.0 and comboTime < 8.0 then
        if abilityMS and abilityMS:IsFullyCastable() and npcBot:HasScepter() then
            print("[TECHIES] Placing Minefield Sign!");
            local signLocation = npcBot:GetLocation();
            npcBot:Action_UseAbilityOnLocation(abilityMS, signLocation);
            isInCombo = false; -- Combo complete
            return true;
        else
            print("[TECHIES] Combo complete (no scepter)!");
            isInCombo = false; -- No scepter, combo done
            return false;
        end
    end
    
    return false;
end

-- Helper Functions

function TrackMinePlacement(location)
    table.insert(mineLocations, {
        location = location,
        time = DotaTime()
    });
end

function CleanupOldMineLocations()
    local currentTime = DotaTime();
    local mineDuration = 600; -- 10 minutes
    
    for i = #mineLocations, 1, -1 do
        if currentTime - mineLocations[i].time > mineDuration then
            table.remove(mineLocations, i);
        end
    end
end

function IsMineLocationOccupied(location)
    for _, mine in pairs(mineLocations) do
        local distance = GetLocationToLocationDistance(location, mine.location);
        if distance < MINE_OVERLAP_DISTANCE then
            return true;
        end
    end
    return false;
end

function GetStrategicMineLocation()
    local nCastRange = abilityLM:GetCastRange();
    local attempts = 0;
    
    while attempts < 5 do
        local randomLocation = npcBot:GetLocation() + RandomVector(nCastRange * 0.8);
        if not IsMineLocationOccupied(randomLocation) then
            return randomLocation;
        end
        attempts = attempts + 1;
    end
    
    return nil;
end

function GetRandomMineLocation(centerLocation, radius)
    local randomOffset = RandomVector(radius);
    return centerLocation + randomOffset;
end

function GetComboMineLocation()
    -- Place mines in a tight circle around current location
    local nCastRange = abilityLM:GetCastRange();
    local baseLocation = npcBot:GetLocation();
    
    -- Try to place in a pattern around the location
    local angles = {0, 120, 240}; -- 3 mines in triangle
    local radius = MINE_OVERLAP_DISTANCE + 50; -- Just outside overlap distance
    
    for _, angle in pairs(angles) do
        local radians = math.rad(angle);
        local offsetX = radius * math.cos(radians);
        local offsetY = radius * math.sin(radians);
        local mineLocation = baseLocation + Vector(offsetX, offsetY, 0);
        
        if not IsMineLocationOccupied(mineLocation) then
            return mineLocation;
        end
    end
    
    return nil;
end

function GetEnemyCenter(enemies)
    if #enemies == 0 then return nil end
    
    local sumX, sumY = 0, 0;
    local validEnemies = 0;
    
    for _, enemy in pairs(enemies) do
        if mutil.CanCastOnNonMagicImmune(enemy) then
            local pos = enemy:GetLocation();
            sumX = sumX + pos.x;
            sumY = sumY + pos.y;
            validEnemies = validEnemies + 1;
        end
    end
    
    if validEnemies == 0 then return nil end
    
    return Vector(sumX / validEnemies, sumY / validEnemies, 0);
end

function IsHighValueTarget(target)
    if not target then return false end
    
    local unitName = target:GetUnitName();
    local valueTargets = {
        "antimage", "phantom_assassin", "faceless_void", "spectre",
        "invoker", "pudge", "enigma", "crystal_maiden"
    };
    
    for _, valueName in pairs(valueTargets) do
        if string.find(unitName, valueName) then
            return true;
        end
    end
    
    return false;
end

function GetLocationToLocationDistance(loc1, loc2)
    if not loc1 or not loc2 then return 9999 end
    local dx = loc1.x - loc2.x;
    local dy = loc1.y - loc2.y;
    return math.sqrt(dx * dx + dy * dy);
end

-- ANTI-STUCK MODE OVERRIDE FUNCTIONS
function GetDesire()
    if npcBot == nil then npcBot = GetBot(); end
    
    local distanceFromFountain = npcBot:DistanceFromFountain();
    local botLevel = npcBot:GetLevel();
    
    if distanceFromFountain < 2000 and botLevel >= 6 and DotaTime() > 180 then
        return BOT_MODE_DESIRE_ABSOLUTE;
    end
    
    if distanceFromFountain < 1500 and DotaTime() > 120 and 
       npcBot:GetHealth() > npcBot:GetMaxHealth() * 0.6 and
       not npcBot:WasRecentlyDamagedByAnyHero(5.0) then
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