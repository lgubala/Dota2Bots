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

local abilityQ = nil; -- Curse of the Silent
local abilityW = nil; -- Glaives of Wisdom
local abilityE = nil; -- Last Word
local abilityR = nil; -- Global Silence

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;

-- Combo tracking
local curseStartTime = 0;
local comboWindow = 1.5;

-- Glaives autocast management
local lateGameTime = 1200; -- 20 minutes

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityQ == nil then abilityQ = bot:GetAbilityByName("silencer_curse_of_the_silent"); end
    if abilityW == nil then abilityW = bot:GetAbilityByName("silencer_glaives_of_wisdom"); end
    if abilityE == nil then abilityE = bot:GetAbilityByName("silencer_last_word"); end
    if abilityR == nil then abilityR = bot:GetAbilityByName("silencer_global_silence"); end

    -- Manage Glaives autocast (turn on in late game to be more annoying)
    ManageGlaivesAutocast();

    -- Consider using each ability
    castRDesire = ConsiderGlobalSilence();
    castQDesire, castQLocation = ConsiderCurseOfTheSilent();
    castEDesire, castETarget = ConsiderLastWord();
    castWDesire, castWTarget = ConsiderGlaivesOfWisdom();

    -- Priority: Ultimate > Combo setup > Combo finish > Harassment
    if castRDesire > 0 then
        bot:Action_UseAbility(abilityR);
        return;
    end

    -- Execute combo: Curse first, then Last Word for max damage
    if castQDesire > 0 and castEDesire > 0 and curseStartTime == 0 then
        curseStartTime = DotaTime();
        bot:Action_UseAbilityOnLocation(abilityQ, castQLocation);
        return;
    end

    -- Complete combo with Last Word
    if castEDesire > 0 and curseStartTime > 0 and DotaTime() - curseStartTime < comboWindow then
        curseStartTime = 0;
        bot:Action_UseAbilityOnEntity(abilityE, castETarget);
        return;
    end

    -- Individual ability usage
    if castQDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityQ, castQLocation);
        return;
    end

    if castEDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityE, castETarget);
        return;
    end

    if castWDesire > 0 then
        bot:Action_UseAbilityOnEntity(abilityW, castWTarget);
        return;
    end
end

function ManageGlaivesAutocast()
    if abilityW == nil or not abilityW:IsTrained() then return end
    
    local gameTime = DotaTime();
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    
    -- Turn on autocast in late game or when we have plenty of mana
    if gameTime > lateGameTime or manaPercent > 0.6 then
        if not abilityW:GetAutoCastState() then
            abilityW:ToggleAutoCast();
        end
    else
        -- Turn off in early/mid game to conserve mana for Curse spam
        if abilityW:GetAutoCastState() then
            abilityW:ToggleAutoCast();
        end
    end
end

function ConsiderCurseOfTheSilent()
    if not mutils.CanBeCast(abilityQ) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
    local nRadius = abilityQ:GetSpecialValueInt("radius");
    local nManaCost = abilityQ:GetManaCost();
    local gameTime = DotaTime();
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- TEAMFIGHT: Multi-target harassment (highest priority - be annoying!)
    if mutils.IsInTeamFight(bot, 1200) then
        local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0);
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_VERYHIGH, locationAoE.targetloc;
        end
    end

    -- AGGRESSIVE LANING: Spam this constantly in lane if we have mana
    if gameTime < 900 and manaPercent > 0.3 then -- First 15 minutes, keep at least 30% mana
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                -- Just spam it on anyone in range - be super annoying!
                return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
            end
        end
    end

    -- OFFENSIVE: Going on someone (combo setup)
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local castPoint = abilityQ:GetCastPoint();
            return BOT_ACTION_DESIRE_VERYHIGH, target:GetExtrapolatedLocation(castPoint);
        end
    end

    -- CONSTANT HARASSMENT: Always look for targets if we have mana
    if manaPercent > 0.4 then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                -- Spam on low HP enemies
                local enemyHealthPercent = mutils.SafeGetHealthPercent(enemy);
                if enemyHealthPercent < 0.7 then
                    return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation();
                end
            end
        end
        
        -- Even hit full HP enemies if we have good mana
        if manaPercent > 0.6 and #enemies > 0 then
            return BOT_ACTION_DESIRE_LOW, enemies[1]:GetLocation();
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderGlaivesOfWisdom()
    -- Don't manually cast if autocast is on
    if abilityW == nil or not abilityW:IsFullyCastable() or abilityW:GetAutoCastState() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityW:GetCastRange(), 1600);
    local nManaCost = abilityW:GetManaCost();
    local manaPercent = bot:GetMana() / bot:GetMaxMana();
    local gameTime = DotaTime();
    
    -- Save mana for Curse spam in early game
    if gameTime < 900 and manaPercent < 0.5 then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);

    -- OFFENSIVE: Manually cast on our target for guaranteed hit
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    -- LANE HARASSMENT: Steal int and deal damage
    if gameTime < 900 and manaPercent > 0.6 then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderLastWord()
    if not mutils.CanBeCast(abilityE) then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityE:GetCastRange(), 1600);
    local enemies = bot:GetNearbyHeroes(math.min(nCastRange + 200, 1600), true, BOT_MODE_NONE);

    -- INTERRUPT: Channeling enemies (HIGHEST PRIORITY - be super annoying!)
    for _, enemy in pairs(enemies) do
        if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH, enemy;
        end
    end

    -- COMBO: Use after Curse for max damage
    if curseStartTime > 0 and DotaTime() - curseStartTime < comboWindow then
        if mutils.IsGoingOnSomeone(bot) then
            local target = bot:GetTarget();
            if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
                return BOT_ACTION_DESIRE_VERYHIGH, target;
            end
        end
    end

    -- PREVENT ESCAPES: Target enemies trying to cast or escape
    for _, enemy in pairs(enemies) do
        if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
            if enemy:IsRetreating() or enemy:IsCastingAbility() then
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end

    -- OFFENSIVE: Going on someone
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end

    -- TEAMFIGHT: Silence priority targets
    if mutils.IsInTeamFight(bot, 1200) then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end

    -- AGGRESSIVE LANING: Use on low HP enemies
    local gameTime = DotaTime();
    if gameTime < 900 then
        for _, enemy in pairs(enemies) do
            if mutils.IsValidTarget(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
                local enemyHealthPercent = mutils.SafeGetHealthPercent(enemy);
                if enemyHealthPercent < 0.5 then
                    return BOT_ACTION_DESIRE_MODERATE, enemy;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderGlobalSilence()
    if not mutils.CanBeCast(abilityR) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local globalEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);

    -- INTERRUPT BIG CHANNELING SPELLS (Enigma BH, CM ult, etc) - HIGHEST PRIORITY!
    for _, enemy in pairs(globalEnemies) do
        if enemy ~= nil and mutils.SafeIsChanneling(enemy) then
            return BOT_ACTION_DESIRE_VERYHIGH;
        end
    end

    -- SAVE CARRY: Use if our carry is in danger
    local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if ally:GetHealth() / ally:GetMaxHealth() < 0.3 then
            local nearbyEnemies = ally:GetNearbyHeroes(600, true, BOT_MODE_NONE);
            if #nearbyEnemies >= 2 then
                return BOT_ACTION_DESIRE_VERYHIGH;
            end
        end
    end

    -- TEAMFIGHT: Big teamfight usage
    if mutils.IsInTeamFight(bot, 1200) then
        local nearbyEnemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        local nearbyAllies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
        
        -- Use if we have numbers advantage and multiple enemies
        if #nearbyEnemies >= 3 and #nearbyAllies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- PREVENT ENEMY COMBO: Stop them from casting in teamfight
    local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
    if #enemies >= 2 then
        for _, enemy in pairs(enemies) do
            if enemy:IsCastingAbility() then
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end