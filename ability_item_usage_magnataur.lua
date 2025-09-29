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

-- Initialize abilities by name (CRITICAL FIX)
local abilityQ = nil;  -- Shockwave
local abilityW = nil;  -- Empower
local abilityE = nil;  -- Skewer
local abilityR = nil;  -- Reverse Polarity
local abilityHornToss = nil;  -- Horn Toss (Scepter)

-- Combo state tracking
local comboState = "";
local comboStartTime = 0;
local comboWindow = 3.0;
local lastBlinkTime = 0;
local blinkCooldown = 1.0;

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;
local castHornTossDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return; -- Don't interrupt channeling
    end

    -- Initialize abilities by exact name (ALWAYS RECOMMENDED)
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("magnataur_shockwave"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("magnataur_empower"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("magnataur_skewer"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("magnataur_reverse_polarity"); end
    if abilityHornToss == nil then abilityHornToss = bot:GetAbilityByName("magnataur_horn_toss"); end
    
    -- COMBO SYSTEM - Check for blink dagger combos first
    local blinkResult = ConsiderBlinkCombo();
    if blinkResult then
        return; -- Blink combo is executing
    end
    
    -- Consider using each ability
    castQDesire, castQTarget = ConsiderShockwave();
    castWDesire, castWTarget = ConsiderEmpower();
    castEDesire, castETarget = ConsiderSkewer();
    castRDesire = ConsiderReversePolarity();
    castHornTossDesire = ConsiderHornToss();

    -- PRIORITY ORDER: Ultimate combo > Horn Toss > Skewer > Shockwave > Empower
    if castRDesire > 0 then
        bot:Action_UseAbility(abilityR);
        return;
    end

    if castHornTossDesire > 0 then
        bot:Action_UseAbility(abilityHornToss);
        return;
    end

    if castEDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityE, castETarget);
        return;
    end

    if castQDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityQ, castQTarget);
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityW, castWTarget);
        return;
    end
end

function ConsiderBlinkCombo()
    local blink = bot:GetItemInSlot(0);
    if blink == nil then
        blink = bot:GetItemInSlot(1);
    end
    if blink == nil then
        blink = bot:GetItemInSlot(2);
    end
    if blink == nil then
        blink = bot:GetItemInSlot(3);
    end
    if blink == nil then
        blink = bot:GetItemInSlot(4);
    end
    if blink == nil then
        blink = bot:GetItemInSlot(5);
    end
    
    -- Find blink dagger
    if blink ~= nil and blink:GetName() ~= "item_blink" then
        blink = nil;
    end
    
    if blink == nil or not blink:IsFullyCastable() then
        return false;
    end
    
    local currentTime = DotaTime();
    if currentTime - lastBlinkTime < blinkCooldown then
        return false;
    end
    
    -- COMBO 1: Blink + RP + Skewer (Classic teamfight combo)
    if mutils.CanBeCast(abilityR) and mutils.CanBeCast(abilityE) and mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            local bestPosition = FindBestRPPosition(enemies);
            if bestPosition ~= nil then
                bot:Action_UseAbilityOnLocation(blink, bestPosition);
                comboState = "BLINK_RP_SKEWER";
                comboStartTime = currentTime;
                lastBlinkTime = currentTime;
                return true;
            end
        end
    end
    
    -- COMBO 2: Blink + Horn Toss + Skewer (Single target displacement)
    if bot:HasScepter() and mutils.CanBeCast(abilityHornToss) and mutils.CanBeCast(abilityE) and mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) > 600 then
            local blinkPos = target:GetLocation() + RandomVector(200);
            bot:Action_UseAbilityOnLocation(blink, blinkPos);
            comboState = "BLINK_HORN_SKEWER";
            comboStartTime = currentTime;
            lastBlinkTime = currentTime;
            return true;
        end
    end
    
    -- COMBO 3: Blink + Skewer (Simple displacement)
    if mutils.CanBeCast(abilityE) and mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) > 800 then
            -- Blink behind target for optimal skewer angle
            local targetPos = target:GetLocation();
            local botPos = bot:GetLocation();
            local direction = (targetPos - botPos):Normalized();
            local blinkPos = targetPos + direction * 300; -- Behind target
            
            bot:Action_UseAbilityOnLocation(blink, blinkPos);
            comboState = "BLINK_SKEWER";
            comboStartTime = currentTime;
            lastBlinkTime = currentTime;
            return true;
        end
    end
    
    return false;
end

function FindBestRPPosition(enemies)
    local bestPos = nil;
    local bestCount = 0;
    local rpRadius = abilityR:GetSpecialValueInt("pull_radius");
    
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) then
            local count = 0;
            local enemyPos = enemy:GetLocation();
            
            for _, otherEnemy in pairs(enemies) do
                if GetUnitToLocationDistance(otherEnemy, enemyPos) <= rpRadius then
                    count = count + 1;
                end
            end
            
            if count > bestCount then
                bestCount = count;
                bestPos = enemyPos;
            end
        end
    end
    
    return bestPos;
end

function ConsiderShockwave()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    -- Get ability properties with range safety
    local nCastRange = math.min(abilityQ:GetSpecialValueInt("AbilityCastRange"), 1600);
    local nManaCost = abilityQ:GetManaCost();
    local nDamage = abilityQ:GetSpecialValueInt("shock_damage");
    local nSpeed = abilityQ:GetSpecialValueInt("shock_speed");
    
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
    
    -- TEAMFIGHT: Line damage and pull
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and mutils.IsInRange(enemy, bot, nCastRange) then
                local pullTarget = enemy:GetExtrapolatedLocation((GetUnitToUnitDistance(enemy, bot)/nSpeed) + 0.3);
                return BOT_ACTION_DESIRE_HIGH, pullTarget;
            end
        end
    end
    
    -- OFFENSIVE: Going on someone (with prediction)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
            local predictedPos = target:GetExtrapolatedLocation((GetUnitToUnitDistance(target, bot)/nSpeed) + 0.3);
            return BOT_ACTION_DESIRE_HIGH, predictedPos;
        end
    end
    
    -- DEFENSIVE: Retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation();
            end
        end
    end
    
    -- PUSHING/DEFENDING: Wave clear when allowed to spam
    if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and bot:GetMana() / bot:GetMaxMana() > 0.6 then
        local creeps = bot:GetNearbyLaneCreeps(math.min(nCastRange + 200, 1600), true);
        if #creeps >= 4 then
            local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, 200, 0, 0);
            if locationAoE.count >= 4 then
                return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderEmpower()
    if not mutils.CanBeCast(abilityW) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityW:GetCastRange(), 1600);
    
    -- SELF BUFF: Priority if we don't have it
    if not bot:HasModifier("modifier_magnataur_empower") then
        -- Buff self in combat scenarios
        if mutils.IsGoingOnSomeone(bot) or mutils.IsInTeamFight(bot, 1200) or 
           mutils.IsPushing(bot) or mutils.IsDefending(bot) or bot:GetActiveMode() == BOT_MODE_ROSHAN then
            return BOT_ACTION_DESIRE_HIGH, bot;
        end
    end
    
    -- ALLY BUFF: Look for carry without buff
    local allies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if not ally:HasModifier("modifier_magnataur_empower") and not ally:IsIllusion() then
            -- Priority: Carries and right-clickers
            local heroName = ally:GetUnitName();
            if string.find(heroName, "drow") or string.find(heroName, "phantom_assassin") or 
               string.find(heroName, "anti") or string.find(heroName, "juggernaut") or
               string.find(heroName, "sven") or string.find(heroName, "wraith_king") or
               string.find(heroName, "troll") or string.find(heroName, "sniper") then
                return BOT_ACTION_DESIRE_HIGH, ally;
            end
            
            -- Secondary priority: Any ally in combat
            if mutils.IsInTeamFight(ally, 800) or ally:GetAttackTarget() ~= nil then
                return BOT_ACTION_DESIRE_MODERATE, ally;
            end
        end
    end
    
    -- ROSHAN: Buff for Roshan fight
    if bot:GetActiveMode() == BOT_MODE_ROSHAN then
        if not bot:HasModifier("modifier_magnataur_empower") then
            return BOT_ACTION_DESIRE_MODERATE, bot;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderSkewer()
    if not mutils.CanBeCast(abilityE) or bot:IsRooted() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityE:GetSpecialValueInt("range"), 1600);
    local nSpeed = abilityE:GetSpecialValueInt("skewer_speed");
    
    -- ESCAPE: High priority when retreating or stuck
    if mutils.IsStuck(bot) or mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
        if #enemies > 0 then
            local escapeLoc = mutils.GetEscapeLoc();
            local skewerTarget = bot:GetXUnitsTowardsLocation(escapeLoc, nCastRange);
            return BOT_ACTION_DESIRE_HIGH, skewerTarget;
        end
    end
    
    -- COMBO EXECUTION: Part of combo sequences
    if comboState == "BLINK_RP_SKEWER" and DotaTime() - comboStartTime < comboWindow then
        if bot:HasModifier("modifier_magnataur_reverse_polarity") or DotaTime() - comboStartTime > 1.0 then
            local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
            if #allies > 0 then
                -- Skewer towards allies
                local allyPos = allies[1]:GetLocation();
                local skewerTarget = bot:GetXUnitsTowardsLocation(allyPos, nCastRange);
                comboState = "";
                return BOT_ACTION_DESIRE_VERYHIGH, skewerTarget;
            else
                -- Skewer towards fountain as fallback
                local fountain = GetAncient(GetTeam()):GetLocation();
                local skewerTarget = bot:GetXUnitsTowardsLocation(fountain, nCastRange);
                comboState = "";
                return BOT_ACTION_DESIRE_VERYHIGH, skewerTarget;
            end
        end
    end
    
    if comboState == "BLINK_HORN_SKEWER" and DotaTime() - comboStartTime < comboWindow then
        if DotaTime() - comboStartTime > 0.5 then -- Wait for horn toss
            local target = bot:GetTarget();
            if mutils.IsValidTarget(target) then
                -- Skewer target towards team/tower
                local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
                local destination;
                if #allies > 0 then
                    destination = allies[1]:GetLocation();
                else
                    destination = GetAncient(GetTeam()):GetLocation();
                end
                local skewerTarget = bot:GetXUnitsTowardsLocation(destination, nCastRange);
                comboState = "";
                return BOT_ACTION_DESIRE_VERYHIGH, skewerTarget;
            end
        end
    end
    
    if comboState == "BLINK_SKEWER" and DotaTime() - comboStartTime < comboWindow then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            -- Skewer target towards safety/team
            local destination = GetAncient(GetTeam()):GetLocation();
            local skewerTarget = target:GetXUnitsTowardsLocation(destination, nCastRange);
            comboState = "";
            return BOT_ACTION_DESIRE_VERYHIGH, skewerTarget;
        end
    end
    
    -- DISPLACEMENT: Skewer enemies towards team/tower (requires positioning behind target)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           mutils.IsInRange(target, bot, nCastRange - 200) then
            
            -- Check if we're behind the target relative to their escape route
            local targetPos = target:GetLocation();
            local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
            local towers = bot:GetNearbyTowers(1600, false);
            
            local destination;
            if #allies > 0 then
                destination = allies[1]:GetLocation();
            elseif #towers > 0 then
                destination = towers[1]:GetLocation();
            else
                destination = GetAncient(GetTeam()):GetLocation();
            end
            
            local skewerTarget = target:GetXUnitsTowardsLocation(destination, math.min(nCastRange, 600));
            return BOT_ACTION_DESIRE_HIGH, skewerTarget;
        end
    end
    
    -- TEAMFIGHT: Displacement and damage
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(nCastRange - 100, true, BOT_MODE_NONE);
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and not mutils.IsDisabled(true, enemy) then
                -- Skewer towards allies
                local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
                if #allies > 0 then
                    local skewerTarget = enemy:GetXUnitsTowardsLocation(allies[1]:GetLocation(), math.min(nCastRange, 400));
                    return BOT_ACTION_DESIRE_HIGH, skewerTarget;
                end
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderReversePolarity()
    if not mutils.CanBeCast(abilityR) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityR:GetSpecialValueInt("pull_radius");
    local enemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
    
    -- TEAMFIGHT: Multiple enemies (highest priority)
    if mutils.IsInTeamFight(bot, 1200) then
        local validEnemies = 0;
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                validEnemies = validEnemies + 1;
            end
        end
        
        if validEnemies >= 2 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        elseif validEnemies >= 1 then
            -- Check if it's a high-value target
            for _, enemy in pairs(enemies) do
                local heroName = enemy:GetUnitName();
                if string.find(heroName, "carry") or string.find(heroName, "invoker") or 
                   string.find(heroName, "sniper") or string.find(heroName, "drow") then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end
    
    -- COMBO EXECUTION: Part of blink combo
    if comboState == "BLINK_RP_SKEWER" and DotaTime() - comboStartTime < 1.0 then
        if #enemies >= 1 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end
    
    -- DEFENSIVE: Retreating with multiple enemies nearby
    if mutils.IsRetreating(bot) then
        local closeEnemies = 0;
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 2.0) then
                closeEnemies = closeEnemies + 1;
            end
        end
        
        if closeEnemies >= 2 then
            local allies = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
            if #allies >= 1 then -- Have backup
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end
    
    -- SINGLE TARGET: High-value targets only
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.IsInRange(target, bot, nRadius) and
           mutils.CanCastOnNonMagicImmune(target) then
            -- Only RP single targets if they're high-value or low HP
            local healthPercent = mutils.SafeGetHealth(target) / target:GetMaxHealth();
            if healthPercent < 0.4 then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderHornToss()
    -- Check if scepter ability is available
    if not bot:HasScepter() or not mutils.CanBeCast(abilityHornToss) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityHornToss:GetSpecialValueInt("radius");
    local nDamage = abilityHornToss:GetSpecialValueInt("damage");
    local enemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
    
    -- KILLSTEAL: Secure kills
    for _, enemy in pairs(enemies) do
        if mutils.CanCastOnNonMagicImmune(enemy) and mutils.CanKillTarget(enemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end
    
    -- COMBO SETUP: Part of Horn Toss + Skewer combo
    if comboState == "BLINK_HORN_SKEWER" and DotaTime() - comboStartTime < 1.0 then
        if #enemies >= 1 then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end
    
    -- POSITIONING: Set up for skewer when we have both abilities
    if mutils.CanBeCast(abilityE) and mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.IsInRange(target, bot, nRadius) and
           mutils.CanCastOnNonMagicImmune(target) and not mutils.IsDisabled(true, target) then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- TEAMFIGHT: Area stun and displacement
    if mutils.IsInTeamFight(bot, 1200) then
        local validEnemies = 0;
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) and not mutils.IsDisabled(true, enemy) then
                validEnemies = validEnemies + 1;
            end
        end
        
        if validEnemies >= 1 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- DEFENSIVE: Retreating
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end
    
    -- FARMING: Clear neutrals/creeps efficiently
    if bot:GetActiveMode() == BOT_MODE_FARM then
        local creeps = bot:GetNearbyNeutralCreeps(nRadius);
        if #creeps >= 2 then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE;
end