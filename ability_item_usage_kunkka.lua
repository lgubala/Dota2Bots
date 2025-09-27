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
local abilityQ = nil; -- Torrent
local abilityW = nil; -- Tidebringer  
local abilityE = nil; -- X Marks the Spot
local abilityR = nil; -- Ghostship
local abilityShard = nil; -- Tidal Wave
local abilityReturn = nil; -- Return

-- Combo timing
local xMarkTime = 0;
local comboWindow = 3.0;
local torrentDelay = 1.6;
local ghostshipDelay = 3.1;

-- Desire values
local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;
local castShardDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name (ALWAYS RECOMMENDED)
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("kunkka_torrent"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("kunkka_tidebringer"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("kunkka_x_marks_the_spot"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("kunkka_ghostship"); end
    if abilityShard == nil then abilityShard = bot:GetAbilityByName("kunkka_tidal_wave"); end
    if abilityReturn == nil then abilityReturn = bot:GetAbilityByName("kunkka_return"); end

    -- Handle X Marks return timing
    if abilityReturn ~= nil and not abilityReturn:IsHidden() and ShouldReturn() then
        bot:Action_UseAbility(abilityReturn);
        xMarkTime = 0;
        return;
    end

    -- Consider combo usage
    local comboDesire, comboTarget, comboLoc = ConsiderCombo();
    if comboDesire > 0 then
        ExecuteCombo(comboTarget, comboLoc);
        return;
    end

    -- Consider individual abilities
    castQDesire, castQTarget = ConsiderTorrent();
    castWDesire, castWTarget = ConsiderTidebringer();
    castEDesire, castETarget = ConsiderXMarks();
    castRDesire, castRTarget = ConsiderGhostship();
    castShardDesire, castShardTarget = ConsiderTidalWave();

    -- Priority order: Ultimate > Interrupt > Combo setup > Offensive > Utility
    if castRDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityR, castRTarget);
        return;
    end

    if castQDesire > BOT_ACTION_DESIRE_HIGH then
        bot:Action_UseAbilityOnLocation(abilityQ, castQTarget);
        return;
    end

    if castEDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityE, castETarget);
        xMarkTime = DotaTime();
        return;
    end

    if castShardDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityShard, castShardTarget);
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

function ShouldReturn()
    if xMarkTime == 0 then return false end
    
    local timeSinceXMark = DotaTime() - xMarkTime;
    local target = bot:GetTarget();
    
    -- Auto-return before X mark expires (3 seconds for enemies)
    if timeSinceXMark >= 2.8 then
        return true;
    end
    
    -- Early return if target is channeling a dangerous ability
    if mutils.IsValidTarget(target) and mutils.SafeIsChanneling(target) then
        return true;
    end
    
    -- Return if we have combo abilities ready and enough time has passed
    if timeSinceXMark >= torrentDelay - 0.2 then
        if abilityQ ~= nil and abilityQ:IsFullyCastable() then
            return true;
        end
        if abilityR ~= nil and abilityR:IsFullyCastable() and timeSinceXMark >= ghostshipDelay - 0.5 then
            return true;
        end
    end
    
    return false;
end

function ConsiderCombo()
    if abilityE == nil or not abilityE:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil, nil;
    end
    
    local nCastRange = math.min(abilityE:GetCastRange(), 1600);
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- Check combo conditions
    local hasComboSpells = false;
    local comboMana = abilityE:GetManaCost();
    
    if abilityQ ~= nil and abilityQ:IsFullyCastable() then
        hasComboSpells = true;
        comboMana = comboMana + abilityQ:GetManaCost();
    end
    
    if abilityR ~= nil and abilityR:IsFullyCastable() then
        hasComboSpells = true;
        comboMana = comboMana + abilityR:GetManaCost();
    end
    
    if not hasComboSpells or bot:GetMana() < comboMana then
        return BOT_ACTION_DESIRE_NONE, nil, nil;
    end
    
    -- TEAMFIGHT: Liberal combo usage in teamfights
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_VERYHIGH, enemy, enemy:GetLocation();
            end
        end
    end
    
    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           GetUnitToUnitDistance(target, bot) <= nCastRange then
            return BOT_ACTION_DESIRE_HIGH, target, target:GetLocation();
        end
    end
    
    -- INTERRUPT: Channeling enemies
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy, enemy:GetLocation();
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil, nil;
end

function ExecuteCombo(target, location)
    if target == nil then return end
    
    bot:Action_ClearActions(false);
    
    -- Start with X Marks
    bot:ActionQueue_UseAbilityOnEntity(abilityE, target);
    xMarkTime = DotaTime();
    
    -- Queue combo spells based on availability
    if abilityR ~= nil and abilityR:IsFullyCastable() then
        bot:ActionQueue_UseAbilityOnLocation(abilityR, location);
    end
    
    if abilityQ ~= nil and abilityQ:IsFullyCastable() then
        bot:ActionQueue_UseAbilityOnLocation(abilityQ, location);
    end
    
    -- Add Tidal Wave if we have shard and positioning is good
    if abilityShard ~= nil and abilityShard:IsFullyCastable() and HasShard() then
        local tidalWaveLoc = CalculateTidalWaveLocation(target, location);
        if tidalWaveLoc ~= nil then
            bot:ActionQueue_UseAbilityOnLocation(abilityShard, tidalWaveLoc);
        end
    end
end

function ConsiderTorrent()
    if abilityQ == nil or not abilityQ:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local nRadius = abilityQ:GetSpecialValueInt("radius");
    local nDelay = abilityQ:GetSpecialValueFloat("delay");
    local nCastPoint = abilityQ:GetCastPoint();
    local nManaCost = abilityQ:GetManaCost();
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- INTERRUPT: Channeling enemies (highest priority)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- TEAMFIGHT: Use in teamfights
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        elseif locationAoE.count >= 1 then
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
        end
    end
    
    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           GetUnitToUnitDistance(target, bot) <= nCastRange then
            return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation(nDelay + nCastPoint);
        end
    end
    
    -- FARMING: Clear creep waves efficiently
    if (bot:GetActiveMode() == BOT_MODE_LANING or mutils.IsPushing(bot)) and 
       mutils.AllowedToSpam(bot, nManaCost) then
        local creeps = bot:GetNearbyLaneCreeps(nCastRange, true);
        if #creeps >= 3 then
            return BOT_ACTION_DESIRE_LOW, creeps[1]:GetLocation();
        end
    end
    
    -- RETREAT: Defensive usage
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 1.0) then
                return BOT_ACTION_DESIRE_HIGH, enemy:GetExtrapolatedLocation(nDelay + nCastPoint);
            end
        end
    end
    
    -- Sand King detection
    local skThere, skLoc = mutils.IsSandKingThere(bot, nCastRange, 2.0);
    if skThere then
        return BOT_ACTION_DESIRE_VERYHIGH, skLoc;
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTidebringer()
    if abilityW == nil or not abilityW:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityW:GetCastRange(), 1600);
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 100, 1600), true, BOT_MODE_NONE);
    
    -- AGGRESSIVE: Use on cooldown for damage and farming
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(target, bot) <= nCastRange then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end
    
    -- TEAMFIGHT: Use in fights for cleave damage
    if mutils.IsInTeamFight(bot, 1200) and #enemies > 0 then
        return BOT_ACTION_DESIRE_HIGH, enemies[1];
    end
    
    -- FARMING: Use for last hitting and farming
    if bot:GetActiveMode() == BOT_MODE_LANING then
        local creeps = bot:GetNearbyLaneCreeps(nCastRange, true);
        if #creeps > 0 then
            -- Find creep that will die to tidebringer damage
            for _, creep in pairs(creeps) do
                local damage = abilityW:GetSpecialValueInt("damage_bonus") + bot:GetAttackDamage();
                if creep:GetHealth() <= damage and creep:GetHealth() > bot:GetAttackDamage() then
                    return BOT_ACTION_DESIRE_MODERATE, creep;
                end
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderXMarks()
    if abilityE == nil or not abilityE:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityE:GetCastRange(), 1600);
    local nManaCost = abilityE:GetManaCost();
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- Don't use standalone X Marks if we have combo spells ready
    if (abilityQ ~= nil and abilityQ:IsFullyCastable()) or 
       (abilityR ~= nil and abilityR:IsFullyCastable()) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    -- INTERRUPT: Channeling or teleporting enemies
    for _, enemy in pairs(enemies) do
        if (mutils.SafeIsChanneling(enemy) or enemy:IsUsingAbility()) and 
           mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end
    
    -- CATCH: Retreating enemies
    for _, enemy in pairs(enemies) do
        if enemy:GetActiveMode() == BOT_MODE_RETREAT and 
           enemy:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
           mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_HIGH, enemy;
        end
    end
    
    -- HARASSMENT: During laning with good mana
    if bot:GetActiveMode() == BOT_MODE_LANING and mutils.AllowedToSpam(bot, nManaCost) then
        if #enemies >= 1 and mutils.CanCastOnNonMagicImmune(enemies[1]) then
            return BOT_ACTION_DESIRE_MODERATE, enemies[1];
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderGhostship()
    if abilityR == nil or not abilityR:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityR:GetCastRange(), 1600);
    local nWidth = abilityR:GetSpecialValueInt("ghostship_width");
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- TEAMFIGHT: Liberal ultimate usage
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nWidth/2, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_VERYHIGH, locationAoE.targetloc;
        elseif locationAoE.count >= 1 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
        end
    end
    
    -- INTERRUPT: Channeling enemies
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
        end
    end
    
    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
           GetUnitToUnitDistance(target, bot) <= nCastRange then
            return BOT_ACTION_DESIRE_HIGH, target:GetLocation();
        end
    end
    
    -- RETREAT: Defensive usage
    if mutils.IsRetreating(bot) then
        for _, enemy in pairs(enemies) do
            if bot:WasRecentlyDamagedByHero(enemy, 1.0) then
                return BOT_ACTION_DESIRE_HIGH, GetTowardsFountainLocation(bot:GetLocation(), 400);
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderTidalWave()
    if abilityShard == nil or not abilityShard:IsFullyCastable() or not HasShard() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = math.min(abilityShard:GetCastRange(), 1600);
    local nManaCost = abilityShard:GetManaCost();
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);
    
    -- TEAMFIGHT: Use for positioning enemies (much more liberal)
    if mutils.IsInTeamFight(bot, 1200) and #enemies >= 1 then -- Reduced from 2
        local bestLoc = CalculateTidalWaveLocation(enemies[1], enemies[1]:GetLocation());
        if bestLoc ~= nil then
            return BOT_ACTION_DESIRE_HIGH, bestLoc;
        end
    end
    
    -- OFFENSIVE: Use aggressively when going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and GetUnitToUnitDistance(target, bot) <= nCastRange then
            local waveLoc = CalculateTidalWaveLocation(target, target:GetLocation());
            if waveLoc ~= nil then
                return BOT_ACTION_DESIRE_HIGH, waveLoc; -- Increased from MODERATE
            end
        end
    end
    
    -- FARMING: Use for clearing creep waves if we have good mana
    if (bot:GetActiveMode() == BOT_MODE_LANING or mutils.IsPushing(bot)) and 
       mutils.AllowedToSpam(bot, nManaCost) then
        local creeps = bot:GetNearbyLaneCreeps(nCastRange, true);
        if #creeps >= 3 then
            return BOT_ACTION_DESIRE_MODERATE, creeps[1]:GetLocation();
        end
    end
    
    -- HARASSMENT: Use during laning if we have plenty of mana
    if bot:GetActiveMode() == BOT_MODE_LANING and bot:GetMana() > nManaCost * 3 then
        if #enemies >= 1 and mutils.CanCastOnNonMagicImmune(enemies[1]) then
            local waveLoc = CalculateTidalWaveLocation(enemies[1], enemies[1]:GetLocation());
            if waveLoc ~= nil then
                return BOT_ACTION_DESIRE_MODERATE, waveLoc;
            end
        end
    end
    
    -- RETREAT: Push enemies away
    if mutils.IsRetreating(bot) and #enemies > 0 then
        local pushLoc = bot:GetLocation() + (bot:GetLocation() - enemies[1]:GetLocation()):Normalized() * 400;
        return BOT_ACTION_DESIRE_HIGH, pushLoc;
    end
    
    -- INTERRUPT: Use to disrupt channeling enemies  
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            local waveLoc = CalculateTidalWaveLocation(enemy, enemy:GetLocation());
            if waveLoc ~= nil then
                return BOT_ACTION_DESIRE_VERYHIGH, waveLoc;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, nil;
end

function HasShard()
    return bot:HasModifier("modifier_item_aghanims_shard");
end

function CalculateTidalWaveLocation(target, targetLoc)
    if target == nil then return nil end
    
    local botLoc = bot:GetLocation();
    local distanceToTarget = GetUnitToLocationDistance(bot, targetLoc);
    
    -- Wave spawns behind Kunkka and moves forward
    -- If we want to pull enemies toward us, we position behind them
    -- If we want to push enemies away, we position in front of them
    
    if mutils.IsRetreating(bot) then
        -- Push enemies away - cast in front of enemies
        return targetLoc + (targetLoc - botLoc):Normalized() * 300;
    else
        -- Pull enemies closer - position ourselves so wave comes from behind them
        local behindTarget = targetLoc + (botLoc - targetLoc):Normalized() * 400;
        return behindTarget;
    end
end

function GetTowardsFountainLocation(unitLoc, distance)
    local destination = {};
    if GetTeam() == TEAM_RADIANT then
        destination[1] = unitLoc[1] - distance / math.sqrt(2);
        destination[2] = unitLoc[2] - distance / math.sqrt(2);
    else
        destination[1] = unitLoc[1] + distance / math.sqrt(2);
        destination[2] = unitLoc[2] + distance / math.sqrt(2);
    end
    return Vector(destination[1], destination[2]);
end