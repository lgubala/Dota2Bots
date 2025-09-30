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

-- Ability references
local abilityQ = nil; -- Shackleshot
local abilityW = nil; -- Powershot
local abilityE = nil; -- Windrun
local abilityR = nil; -- Focus Fire
local abilityShard = nil; -- Gale Force

-- Desire values
local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;
local castShardDesire = 0;

-- Powershot channeling tracking
local powershotStartTime = 0;
local maxChannelTime = 1.0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- Initialize abilities by name (ALWAYS RECOMMENDED)
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("windrunner_shackleshot"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("windrunner_powershot"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("windrunner_windrun"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("windrunner_focusfire"); end
    if abilityShard == nil then abilityShard = bot:GetAbilityByName("windrunner_gale_force"); end

    -- CHANNELING PROTECTION - Special handling for Powershot
    if mutils.SafeIsChanneling(bot) then
        -- Check if we should release Powershot
        if powershotStartTime > 0 then
            local channelTime = DotaTime() - powershotStartTime;
            if channelTime >= maxChannelTime then
                -- Release Powershot after max channel
                bot:Action_ClearActions(false);
                powershotStartTime = 0;
            end
        end
        return;
    end

    -- Consider using each ability
    castShardDesire, castShardTarget = ConsiderGaleForce();
    castRDesire, castRTarget = ConsiderFocusFire();
    castQDesire, castQTarget = ConsiderShackleshot();
    castWDesire, castWTarget = ConsiderPowershot();
    castEDesire = ConsiderWindrun();

    -- Priority order: Shard > Ultimate > Shackle > Powershot > Windrun
    if castShardDesire > 0 then
        ----print("[WINDRUNNER] TRYING TO CAST GALE FORCE! Desire: " .. castShardDesire .. " Target: " .. tostring(castShardTarget));
        -- Try just using it as a point-targeted ability
        bot:Action_UseAbilityOnLocation(abilityShard, castShardTarget);
        return;
    end

    if castRDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityR, castRTarget);
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityQ, castQTarget);
        return;
    end

    if castWDesire > 0 then
        bot:Action_ClearActions(true);
        bot:Action_UseAbilityOnLocation(abilityW, castWTarget);
        powershotStartTime = DotaTime();
        return;
    end

    if castEDesire > 0 then
        bot:Action_UseAbility(abilityE);
        return;
    end
end

-- Helper function to find if there's a tree or enemy behind target for shackle
local function CanShackleTarget(target)
    local nShackleDistance = abilityQ:GetSpecialValueInt("shackle_distance");
    local nShackleAngle = abilityQ:GetSpecialValueInt("shackle_angle");
    
    -- Direction from bot to target
    local botToTarget = (target:GetLocation() - bot:GetLocation()):Normalized();
    
    -- Check for trees behind target
    local trees = bot:GetNearbyTrees(nShackleDistance);
    for _, tree in pairs(trees) do
        local treeLocation = GetTreeLocation(tree);
        local targetToTree = (treeLocation - target:GetLocation()):Normalized();
        
        -- Check if tree is roughly behind target
        local dotProduct = botToTarget.x * targetToTree.x + botToTarget.y * targetToTree.y;
        if dotProduct > 0.7 then -- Roughly same direction
            local distToTree = GetUnitToLocationDistance(target, treeLocation);
            if distToTree <= nShackleDistance then
                return true;
            end
        end
    end
    
    -- Check for enemy heroes behind target
    local enemies = target:GetNearbyHeroes(nShackleDistance, false, BOT_MODE_NONE);
    for _, enemy in pairs(enemies) do
        if enemy ~= target then
            local targetToEnemy = (enemy:GetLocation() - target:GetLocation()):Normalized();
            local dotProduct = botToTarget.x * targetToEnemy.x + botToTarget.y * targetToEnemy.y;
            if dotProduct > 0.7 then
                return true;
            end
        end
    end
    
    return false;
end

function ConsiderShackleshot()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local nManaCost = abilityQ:GetManaCost();
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- INTERRUPT: Channeling or TPing enemies (CRITICAL)
    for _, enemy in pairs(enemies) do
        if (mutils.SafeIsChanneling(enemy) or enemy:HasModifier('modifier_teleporting')) and
           mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end
    
    -- AGGRESSIVE: Going on someone with good shackle
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           GetUnitToUnitDistance(target, bot) <= nCastRange + 200 and
           not mutils.IsDisabled(true, target) then
            -- Only shackle if we can get a good stun
            if CanShackleTarget(target) then
                return BOT_ACTION_DESIRE_HIGH, target;
            end
        end
    end
    
    -- TEAMFIGHT: Look for good shackle opportunities
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and not mutils.IsDisabled(true, enemy) then
                if CanShackleTarget(enemy) then
                    return BOT_ACTION_DESIRE_HIGH, enemy;
                end
            end
        end
    end
    
    -- RETREAT: Defensive shackle
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and not mutils.IsDisabled(true, enemy) then
                -- Don't need perfect shackle when retreating, short stun is fine
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderGaleForce()
    --print("[WINDRUNNER] ConsiderGaleForce called");
    
    -- Check if ability exists
    if abilityShard == nil then
        --print("[WINDRUNNER] Gale Force is NIL");
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    --print("[WINDRUNNER] Gale Force exists, checking if hidden");
    
    -- If ability is hidden, we don't have shard yet
    if abilityShard:IsHidden() then
        --print("[WINDRUNNER] Gale Force is HIDDEN - no shard purchased");
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    --print("[WINDRUNNER] Gale Force is NOT hidden, checking castable");
    
    if not abilityShard:IsFullyCastable() then
        --print("[WINDRUNNER] Gale Force NOT castable - CD: " .. abilityShard:GetCooldownTimeRemaining() .. " Mana: " .. bot:GetMana() .. "/" .. abilityShard:GetManaCost());
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    --print("[WINDRUNNER] Gale Force ready to use!");
    
    local nCastRange = math.min(abilityShard:GetCastRange(), 1600);
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    --print("[WINDRUNNER] Found " .. #enemies .. " enemies in range");
    
    -- VERY AGGRESSIVE: Use on ANY enemy
    if #enemies >= 1 then
        local target = enemies[1];
        --print("[WINDRUNNER] RETURNING HIGH DESIRE FOR GALE FORCE on enemy: " .. target:GetUnitName());
        return BOT_ACTION_DESIRE_VERYHIGH, target:GetLocation();
    end
    
    -- AGGRESSIVE: Use when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(target, bot) <= nCastRange then
            --print("[WINDRUNNER] RETURNING HIGH DESIRE FOR GALE FORCE on target");
            return BOT_ACTION_DESIRE_VERYHIGH, target:GetLocation();
        end
    end
    
    --print("[WINDRUNNER] No desire for Gale Force");
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderPowershot()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = 3000; -- Max range
    local nManaCost = abilityW:GetManaCost();
    local nRadius = abilityW:GetSpecialValueInt("arrow_width");
    
    local enemies = bot:GetNearbyHeroes(math.min(1800, 1600), true, BOT_MODE_NONE);
    
    -- COMBO: After shackle
    for _, enemy in pairs(enemies) do
        if enemy:HasModifier('modifier_windrunner_shackle_shot') and
           mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- TEAMFIGHT: Multi-target damage
    if mutils.IsInTeamFight(bot, 1300) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), 1800, nRadius, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end
    
    -- HARASSMENT: Use in lane
    if bot:GetActiveMode() == BOT_MODE_LANING and mutils.AllowedToSpam(bot, nManaCost) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and
               GetUnitToUnitDistance(enemy, bot) > bot:GetAttackRange() then
                return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation();
            end
        end
    end
    
    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and
           GetUnitToUnitDistance(target, bot) <= 2000 and
           GetUnitToUnitDistance(target, bot) > bot:GetAttackRange() * 0.5 then
            return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
        end
    end
    
    -- FARMING: Clear waves
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and mutils.AllowedToSpam(bot, nManaCost) then
        local creeps = bot:GetNearbyLaneCreeps(math.min(1800, 1600), true);
        if #creeps >= 3 then
            local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), 1800, nRadius, 0, 0);
            if locationAoE.count >= 3 then
                return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderWindrun()
    if not mutils.CanBeCast(abilityE) or bot:HasModifier('modifier_windrunner_windrun') then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local enemies = bot:GetNearbyHeroes(math.min(1200, 1600), true, BOT_MODE_NONE);
    
    -- RETREAT: Escape mechanism
    if mutils.IsRetreating(bot) and (bot:WasRecentlyDamagedByAnyHero(3.0) or bot:WasRecentlyDamagedByTower(3.0)) then
        if #enemies >= 1 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- AGGRESSIVE: Chase enemy
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distToTarget = GetUnitToUnitDistance(target, bot);
            
            -- Use to close distance
            if distToTarget > bot:GetAttackRange() * 1.5 and distToTarget <= 2000 then
                return BOT_ACTION_DESIRE_MODERATE;
            end
            
            -- Use to dodge attacks while fighting
            local physicalDamagers = 0;
            for _, enemy in pairs(enemies) do
                if enemy:GetAttackRange() >= 300 and 
                   GetUnitToUnitDistance(enemy, bot) <= 600 and
                   (mutils.SafeGetAttackTarget(enemy) == bot or enemy:GetTarget() == bot) then
                    physicalDamagers = physicalDamagers + 1;
                end
            end
            if physicalDamagers >= 1 then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end
    
    -- TEAMFIGHT: Positioning and evasion
    if mutils.IsInTeamFight(bot, 1200) and #enemies >= 2 then
        return BOT_ACTION_DESIRE_MODERATE;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderFocusFire()
    if not mutils.CanBeCast(abilityR) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityR:GetCastRange(), 1600);
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- RETREAT: Kill pursuing melee enemy
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) and
       (mutils.CanBeCast(abilityE) or bot:HasModifier('modifier_windrunner_windrun')) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and 
               enemy:GetAttackRange() < 325 and
               GetUnitToUnitDistance(enemy, bot) <= nCastRange * 0.65 and
               (mutils.SafeGetAttackTarget(enemy) == bot or enemy:GetTarget() == bot) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy;
            end
        end
    end
    
    -- AGGRESSIVE: Going on someone (USE LIBERALLY!)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and 
           GetUnitToUnitDistance(target, bot) <= nCastRange then
            -- ALWAYS use ultimate on target - don't check HP restrictions
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end
    
    -- TEAMFIGHT: Focus any valid target
    if mutils.IsInTeamFight(bot, 1200) and #enemies >= 1 then
        -- Find closest enemy
        local closestEnemy = nil;
        local closestDist = 999999;
        
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) then
                local dist = GetUnitToUnitDistance(enemy, bot);
                if dist <= nCastRange and dist < closestDist then
                    closestDist = dist;
                    closestEnemy = enemy;
                end
            end
        end
        
        if closestEnemy ~= nil then
            return BOT_ACTION_DESIRE_HIGH, closestEnemy;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end