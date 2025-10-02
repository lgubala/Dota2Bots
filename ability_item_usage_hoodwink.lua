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
local abilityAcorn = nil;
local abilityBushwhack = nil;
local abilityScurry = nil;
local abilitySharpshooter = nil;
local abilitySharpshooterRelease = nil;
local abilityBoomerang = nil;
local abilityDecoy = nil;

-- Sharpshooter state management
local sharpshooterStartTime = 0;
local sharpshooterTarget = nil;
local sharpshooterMaxCharge = 3.0;
local sharpshooterMinCharge = 0.6;
local isChargingSharpshooter = false;

-- Acorn + Bushwhack combo state
local acornPlantTime = 0;
local acornPlantLocation = nil;
local comboWindow = 0.5;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- Initialize abilities
    if abilityAcorn == nil then abilityAcorn = bot:GetAbilityByName("hoodwink_acorn_shot"); end
    if abilityBushwhack == nil then abilityBushwhack = bot:GetAbilityByName("hoodwink_bushwhack"); end
    if abilityScurry == nil then abilityScurry = bot:GetAbilityByName("hoodwink_scurry"); end
    if abilitySharpshooter == nil then abilitySharpshooter = bot:GetAbilityByName("hoodwink_sharpshooter"); end
    if abilitySharpshooterRelease == nil then abilitySharpshooterRelease = bot:GetAbilityByName("hoodwink_sharpshooter_release"); end
    if abilityBoomerang == nil then abilityBoomerang = bot:GetAbilityByName("hoodwink_hunters_boomerang"); end
    if abilityDecoy == nil then abilityDecoy = bot:GetAbilityByName("hoodwink_decoy"); end

	if abilityAcorn ~= nil and not acornAutoCastEnabled then
        if abilityAcorn:GetAutoCastState() == false then
            abilityAcorn:ToggleAutoCast();
        end
        acornAutoCastEnabled = true;
    end

    -- SHARPSHOOTER CHANNELING MANAGEMENT
    if mutils.SafeIsChanneling(bot) then
        HandleSharpshooterChannel();
        return;
    end

    -- Reset charging state if not channeling
    if isChargingSharpshooter then
        isChargingSharpshooter = false;
        sharpshooterTarget = nil;
    end

    -- Consider abilities in priority order
    local castDecoyDes = ConsiderDecoy();
    local castBoomerangDes, boomerangTarget = ConsiderBoomerang();
    
    -- COMBO CHECK: Bushwhack right after Acorn plant
    if acornPlantTime > 0 and DotaTime() - acornPlantTime < comboWindow and acornPlantLocation ~= nil then
        if mutils.CanBeCast(abilityBushwhack) then
            local targetLoc = acornPlantLocation;
            acornPlantTime = 0;
            acornPlantLocation = nil;
            bot:Action_UseAbilityOnLocation(abilityBushwhack, targetLoc);
            return;
        end
    end
    
    local castSharpshooterDes, sharpshooterLoc = ConsiderSharpshooter();
    local castScurryDes = ConsiderScurry();
    local castBushwhackDes, bushwhackLoc = ConsiderBushwhack();  -- ADD THIS LINE
    local castAcornDes, acornTarget, acornType = ConsiderAcorn();

    -- Priority: Decoy (emergency) > Boomerang > Sharpshooter > Bushwhack > Acorn > Scurry
    if castDecoyDes > 0 then
        bot:Action_UseAbility(abilityDecoy);
        return;
    end

	if castScurryDes > 0 then
        bot:Action_UseAbility(abilityScurry);
        return;
    end

    if castBoomerangDes > 0 then
        bot:Action_UseAbilityOnEntity(abilityBoomerang, boomerangTarget);
        return;
    end

    if castSharpshooterDes > 0 then
        bot:Action_UseAbilityOnLocation(abilitySharpshooter, sharpshooterLoc);
        sharpshooterStartTime = DotaTime();
        sharpshooterTarget = sharpshooterLoc;
        isChargingSharpshooter = true;
        return;
    end

    if castBushwhackDes > 0 then
        bot:Action_UseAbilityOnLocation(abilityBushwhack, bushwhackLoc);
        return;
    end

    if castAcornDes > 0 then
        if acornType == "unit" then
            bot:Action_UseAbilityOnEntity(abilityAcorn, acornTarget);
        else
            bot:Action_UseAbilityOnLocation(abilityAcorn, acornTarget);
            -- Mark tree plant for combo
            acornPlantTime = DotaTime();
            acornPlantLocation = acornTarget;
        end
        return;
    end


end

-- Helper: Calculate distance between two points
local function GetDistanceBetweenTwoPoints(point1, point2)
    local dx = point1.x - point2.x
    local dy = point1.y - point2.y
    return math.sqrt(dx * dx + dy * dy)
end


-- Helper: Find best tree near location
local function FindNearestTree(location, radius)
    local trees = bot:GetNearbyTrees(math.min(radius, 1600));
    local bestTree = nil;
    local minDist = 9999;
    
    for _, tree in pairs(trees) do
        local treeLoc = GetTreeLocation(tree);
        local dist = GetDistanceBetweenTwoPoints(location, treeLoc)
        if dist < minDist then
            minDist = dist;
            bestTree = treeLoc;
        end
    end
    
    return bestTree, minDist;
end

-- Helper: Check if location has trees within the trap radius (checking the edges)
local function HasTreesInTrapRadius(location, trapRadius)
    local searchRadius = trapRadius + 150
    local trees = bot:GetNearbyTrees(math.min(searchRadius + GetUnitToLocationDistance(bot, location), 1600))

    for _, tree in pairs(trees) do
        local treeLoc = GetTreeLocation(tree)
        local distFromCenter = GetDistanceBetweenTwoPoints(location, treeLoc)

        if distFromCenter <= trapRadius then
            return true
        end
    end

    return false
end


function ConsiderAcorn()
    if not mutils.CanBeCast(abilityAcorn) then
        return BOT_ACTION_DESIRE_NONE, nil, nil;
    end

    local nCastRange = math.min(abilityAcorn:GetCastRange(), 1600);
    local nBounces = abilityAcorn:GetSpecialValueInt("bounce_count");
    local nBounceRange = abilityAcorn:GetSpecialValueInt("bounce_range");
    local manaCost = abilityAcorn:GetManaCost();

    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- CRITICAL COMBO: Plant tree for Bushwhack if both abilities ready
    if mutils.CanBeCast(abilityBushwhack) then
        local bushwhackRadius = abilityBushwhack:GetSpecialValueInt("trap_radius");
        if bot:GetLevel() >= 25 then
            bushwhackRadius = bushwhackRadius + 135;
        end
        
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) and 
               not mutils.IsDisabled(true, enemy) then
                -- Check if enemy has no trees in Bushwhack radius
                if not HasTreesInTrapRadius(enemy:GetLocation(), bushwhackRadius) then
                    -- Plant tree for combo!
                    return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation(), "point";
                end
            end
        end
    end

    -- INTERRUPT: Channeling enemies - plant tree for follow-up Bushwhack
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation(), "point";
        end
    end

    -- HARASSMENT: Bouncing shots in lane
    if bot:GetActiveMode() == BOT_MODE_LANING and mutils.CanSpamSpell(bot, manaCost) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                local nearbyUnits = enemy:GetNearbyHeroes(nBounceRange, false, BOT_MODE_NONE);
                local nearbyCreeps = enemy:GetNearbyLaneCreeps(nBounceRange, false);
                if #nearbyUnits > 0 or #nearbyCreeps >= 2 then
                    return BOT_ACTION_DESIRE_MODERATE, enemy, "unit";
                end
            end
        end
    end

    -- TEAMFIGHT: Multi-target damage
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                local nearbyEnemies = enemy:GetNearbyHeroes(nBounceRange * 0.75, false, BOT_MODE_NONE);
                if #nearbyEnemies >= 1 then
                    return BOT_ACTION_DESIRE_HIGH, enemy, "unit";
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange + 200) then
            local nearbyUnits = target:GetNearbyHeroes(nBounceRange, false, BOT_MODE_NONE);
            local nearbyCreeps = target:GetNearbyLaneCreeps(nBounceRange, false);
            if #nearbyUnits > 0 or #nearbyCreeps > 0 then
                return BOT_ACTION_DESIRE_HIGH, target, "unit";
            else
                -- No bounce targets - check if we need tree for Bushwhack combo
                if mutils.CanBeCast(abilityBushwhack) then
                    local bushwhackRadius = abilityBushwhack:GetSpecialValueInt("trap_radius");
                    if not HasTreesInTrapRadius(target:GetLocation(), bushwhackRadius) then
                        return BOT_ACTION_DESIRE_HIGH, target:GetLocation(), "point";
                    end
                end
            end
        end
    end

    -- FARMING: Wave clear
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and mutils.CanSpamSpell(bot, manaCost) then
        local creeps = bot:GetNearbyLaneCreeps(math.min(nCastRange + 200, 1600), true);
        if #creeps >= nBounces then
            for _, creep in pairs(creeps) do
                if mutils.CanCastOnNonMagicImmune(creep) then
                    return BOT_ACTION_DESIRE_LOW, creep, "unit";
                end
            end
        end
    end

    -- RETREATING: Slow pursuers
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy, "unit";
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil, nil;
end

function ConsiderBushwhack()
    if not mutils.CanBeCast(abilityBushwhack) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityBushwhack:GetCastRange(), 1600);
    local nRadius = abilityBushwhack:GetSpecialValueInt("trap_radius");
    
    if bot:GetLevel() >= 25 then
        nRadius = nRadius + 135;
    end

    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- INTERRUPT: Channeling/TP (ONLY IF TREES EXIST)
    for _, enemy in pairs(enemies) do
        if (mutils.SafeIsChanneling(enemy) or enemy:HasModifier('modifier_teleporting')) and 
           mutils.CanCastOnNonMagicImmune(enemy) then
            if HasTreesInTrapRadius(enemy:GetLocation(), nRadius) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
            end
        end
    end

    -- SAVE ALLY: Low HP ally being chased (ONLY IF TREES EXIST)
    local allies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if ally ~= bot and ally:GetHealth() / ally:GetMaxHealth() < 0.3 then
            if ally:WasRecentlyDamagedByAnyHero(1.5) then
                for _, enemy in pairs(enemies) do
                    local distToAlly = GetUnitToUnitDistance(enemy, ally);
                    if distToAlly <= 600 and HasTreesInTrapRadius(enemy:GetLocation(), nRadius) then
                        return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
                    end
                end
            end
        end
    end

    -- TEAMFIGHT: Stun setup (ONLY IF TREES EXIST)
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and not mutils.IsDisabled(true, enemy) then
                if HasTreesInTrapRadius(enemy:GetLocation(), nRadius) then
                    return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone with trees (ONLY IF TREES EXIST)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           mutils.IsInRange(target, bot, nCastRange + nRadius) and not mutils.IsDisabled(true, target) then
            if HasTreesInTrapRadius(target:GetLocation(), nRadius) then
                return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
            end
        end
    end

    -- RETREATING: Defensive stun (ONLY IF TREES EXIST)
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and not mutils.IsDisabled(true, enemy) then
                if HasTreesInTrapRadius(enemy:GetLocation(), nRadius) then
                    return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderScurry()
    if not mutils.CanBeCast(abilityScurry) or bot:HasModifier("modifier_hoodwink_scurry_active") then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- ESCAPE: Retreating with enemies nearby
    if mutils.IsRetreating(bot) and (bot:WasRecentlyDamagedByAnyHero(2.0) or bot:WasRecentlyDamagedByTower(2.0)) then
        local enemies = bot:GetNearbyHeroes(math.min(1200, 1600), true, BOT_MODE_NONE);
        if #enemies > 0 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- CHASE: Going on someone out of range
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            local attackRange = bot:GetAttackRange();
            
            -- Use to close gap or kite
            if distance > attackRange * 1.3 and distance <= 1500 then
                return BOT_ACTION_DESIRE_MODERATE;
            end
            
            -- Use to dodge physical attacks
            local nearEnemies = bot:GetNearbyHeroes(math.min(600, 1600), true, BOT_MODE_NONE);
            for _, enemy in pairs(nearEnemies) do
                if enemy:GetAttackRange() >= 300 and 
                   (mutils.SafeGetAttackTarget(enemy) == bot or enemy:GetTarget() == bot) then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end

    -- POSITIONING: Teamfight mobility
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(800, 1600), true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderSharpshooter()
    if not mutils.CanBeCast(abilitySharpshooter) or isChargingSharpshooter then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = 3000;
    local enemies = bot:GetNearbyHeroes(math.min(1800, 1600), true, BOT_MODE_NONE);

    -- COMBO: After Bushwhack stun
    for _, enemy in pairs(enemies) do
        if enemy:HasModifier("modifier_hoodwink_bushwhack_trap") and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end

    -- FINISH: Kill low HP enemies
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            local healthPercent = mutils.SafeGetHealth(enemy) / enemy:GetMaxHealth();
            if healthPercent < 0.3 and GetUnitToUnitDistance(bot, enemy) <= 2000 then
                return BOT_ACTION_DESIRE_HIGH, enemy:GetExtrapolatedLocation(0.5);
            end
        end
    end

    -- TEAMFIGHT: High-value target
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and GetUnitToUnitDistance(bot, enemy) <= 2000 then
                if mutils.IsDisabled(true, enemy) then
                    return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
                end
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance > bot:GetAttackRange() and distance <= 2000 then
                if mutils.IsDisabled(true, target) then
                    return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
                else
                    return BOT_ACTION_DESIRE_MODERATE, target:GetExtrapolatedLocation(0.8);
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function HandleSharpshooterChannel()
    if not isChargingSharpshooter or abilitySharpshooterRelease == nil then
        return;
    end

    local chargeTime = DotaTime() - sharpshooterStartTime;
    
    -- EMERGENCY CANCEL: Being damaged heavily
    if bot:WasRecentlyDamagedByAnyHero(0.5) then
        local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
        if healthPercent < 0.3 then
            bot:Action_UseAbility(abilitySharpshooterRelease);
            return;
        end
    end

    -- EMERGENCY CANCEL: Target is escaping
    if sharpshooterTarget and mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local targetDist = GetUnitToLocationDistance(target, sharpshooterTarget);
            if targetDist > 400 and chargeTime >= sharpshooterMinCharge then
                bot:Action_UseAbility(abilitySharpshooterRelease);
                return;
            end
        end
    end

    -- AUTO RELEASE: At max charge (3 seconds for max damage)
    if chargeTime >= 2.9 then  -- Release at 2.9 seconds for max damage
        bot:Action_UseAbility(abilitySharpshooterRelease);
        return;
    end

    -- OPTIMAL RELEASE: Good charge + stunned target (after 2.5s is good enough)
    if chargeTime >= 2.5 then
        if sharpshooterTarget then
            local enemies = bot:GetNearbyHeroes(math.min(2000, 1600), true, BOT_MODE_NONE);
            for _, enemy in pairs(enemies) do
                local dist = GetUnitToLocationDistance(enemy, sharpshooterTarget);
                if dist <= 300 and mutils.IsDisabled(true, enemy) then
                    bot:Action_UseAbility(abilitySharpshooterRelease);
                    return;
                end
            end
        end
    end

    -- MINIMUM CHARGE: Release after minimum for emergency
    if mutils.IsRetreating(bot) and chargeTime >= sharpshooterMinCharge then
        local enemies = bot:GetNearbyHeroes(math.min(800, 1600), true, BOT_MODE_NONE);
        if #enemies > 0 then
            bot:Action_UseAbility(abilitySharpshooterRelease);
            return;
        end
    end
    
    -- Let it auto-fire at 5 seconds if we haven't released yet
end

function ConsiderBoomerang()
    if abilityBoomerang == nil or abilityBoomerang:IsHidden() or not abilityBoomerang:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityBoomerang:GetCastRange(), 1600);
    local nDamage = abilityBoomerang:GetSpecialValueInt("damage");
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- KILL: Finish low HP enemies
    for _, enemy in pairs(enemies) do
        if mutils.CanCastOnNonMagicImmune(enemy) and mutils.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- INTERRUPT: Channeling
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- TEAMFIGHT: Apply debuff
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and not mutils.IsDisabled(true, enemy) then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           mutils.IsInRange(target, bot, nCastRange + 200) and not mutils.IsDisabled(true, target) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    -- RETREATING: Slow chaser
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderDecoy()
    if abilityDecoy == nil or abilityDecoy:IsHidden() or not abilityDecoy:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- EMERGENCY ESCAPE: Low HP
    if mutils.IsRetreating(bot) and (bot:WasRecentlyDamagedByAnyHero(2.0) or bot:WasRecentlyDamagedByTower(2.0)) then
        local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
        if healthPercent < 0.4 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end

    -- OFFENSIVE: Confusion in teamfights
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(math.min(1000, 1600), true, BOT_MODE_NONE);
        if #enemies >= 3 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- INITIATION: Invisible positioning
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance > 800 and distance <= 1500 then
                local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
                if healthPercent > 0.6 then
                    return BOT_ACTION_DESIRE_LOW;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end