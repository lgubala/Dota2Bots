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

local abilityDarkPact = nil;
local abilityPounce = nil;
local abilityShadowDance = nil;
local abilityDepthShroud = nil;

local castDarkPactDesire = 0;
local castPounceDesire = 0;
local castShadowDanceDesire = 0;
local castDepthShroudDesire = 0;

function AbilityUsageThink()
    
    if mutils.CanNotUseAbility(bot) then return end
    
    -- CHANNELING PROTECTION
    if mutils.SafeIsChanneling(bot) then
        return;
    end

    -- Initialize abilities by name
    if abilityDarkPact == nil then abilityDarkPact = bot:GetAbilityByName("slark_dark_pact"); end
    if abilityPounce == nil then abilityPounce = bot:GetAbilityByName("slark_pounce"); end
    if abilityShadowDance == nil then abilityShadowDance = bot:GetAbilityByName("slark_shadow_dance"); end
    if abilityDepthShroud == nil then abilityDepthShroud = bot:GetAbilityByName("slark_depth_shroud"); end

    -- Consider using each ability
    castShadowDanceDesire = ConsiderShadowDance();
    castDepthShroudDesire, castDepthShroudLocation = ConsiderDepthShroud();
    castDarkPactDesire = ConsiderDarkPact();
    castPounceDesire = ConsiderPounce();

    -- Priority: Ultimate (save) > Shard AoE save > Dark Pact (purge) > Pounce
    if castShadowDanceDesire > 0 then
        bot:Action_UseAbility(abilityShadowDance);
        return;
    end

    if castDepthShroudDesire > 0 then
        bot:Action_UseAbilityOnLocation(abilityDepthShroud, castDepthShroudLocation);
        return;
    end

    if castDarkPactDesire > 0 then
        bot:Action_UseAbility(abilityDarkPact);
        return;
    end

    if castPounceDesire > 0 then
        bot:Action_UseAbility(abilityPounce);
        return;
    end
end

function ConsiderDarkPact()
    if not mutils.CanBeCast(abilityDarkPact) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nRadius = abilityDarkPact:GetSpecialValueInt("radius");
    local nDamage = abilityDarkPact:GetSpecialValueInt("total_damage");
    local manaPercent = bot:GetMana() / bot:GetMaxMana();

    -- PURGE: Remove debuffs (HIGHEST PRIORITY)
    if bot:IsRooted() or bot:IsStunned() or bot:IsSilenced() or bot:IsHexed() then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end

    -- Check for common negative debuffs by name
    local commonDebuffs = {
        "modifier_silence",
        "modifier_doom_bringer_doom",
        "modifier_bloodseeker_rupture",
        "modifier_disruptor_thunder_strike",
        "modifier_slardar_amplify_damage",
        "modifier_track",
        "modifier_dust",
        "modifier_item_urn_damage",
        "modifier_venomancer_poison_nova",
        "modifier_viper_poison_attack_slow",
        "modifier_ice_blast",
        "modifier_cold_feet"
    };
    
    for _, debuffName in pairs(commonDebuffs) do
        if bot:HasModifier(debuffName) then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- ESCAPE: Slow enemies chasing us
    if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
        local enemies = bot:GetNearbyHeroes(nRadius + 200, true, BOT_MODE_NONE);
        if #enemies > 0 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- TEAMFIGHT: AOE damage on multiple enemies
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- OFFENSIVE: Going on someone - aggressive damage
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            if distance <= nRadius then
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    -- FARMING: Clear wave when pushing (only with good mana)
    if mutils.IsPushing(bot) and manaPercent > 0.6 then
        local creeps = bot:GetNearbyLaneCreeps(nRadius, true);
        if #creeps >= 3 then
            return BOT_ACTION_DESIRE_LOW;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderPounce()
    if not mutils.CanBeCast(abilityPounce) or bot:IsRooted() then
        return BOT_ACTION_DESIRE_NONE;
    end

    local nCastRange = abilityPounce:GetSpecialValueInt("pounce_distance");
    local hasScepter = bot:HasScepter();
    
    -- Scepter increases range
    if hasScepter then
        nCastRange = abilityPounce:GetSpecialValueInt("pounce_distance_scepter");
    end

    -- ESCAPE: Get out of danger
    if mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        if #enemies > 0 then
            if bot:WasRecentlyDamagedByAnyHero(2.0) or bot:WasRecentlyDamagedByTower(2.0) or #enemies >= 2 then
                -- Pounce away from enemies (toward escape location)
                local escapeLoc = mutils.GetEscapeLoc();
                if utils.IsFacingLocation(bot, escapeLoc, 20) then
                    -- Check we're not pouncing into more enemies
                    local facingEnemies = 0;
                    for _, enemy in pairs(enemies) do
                        if mutils.IsValidTarget(enemy) and bot:IsFacingUnit(enemy, 15) then
                            facingEnemies = facingEnemies + 1;
                        end
                    end
                    if facingEnemies == 0 then
                        return BOT_ACTION_DESIRE_VERYHIGH;
                    end
                end
            end
        end
    end

    -- OFFENSIVE: Leash target we're going for
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            
            -- Don't leash already leashed target (check modifier)
            if not target:HasModifier("modifier_slark_pounce_leash") then
                -- Pounce if in range and facing target
                if distance <= nCastRange and distance > 200 and bot:IsFacingUnit(target, 10) then
                    -- Don't pounce disabled enemies (waste of leash)
                    if not mutils.IsDisabled(true, target) then
                        return BOT_ACTION_DESIRE_HIGH;
                    end
                end
            end
        end
    end

    -- SAVE ALLY: Leash enemy attacking low HP ally
    local allies = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if ally ~= bot and not ally:IsIllusion() then
            local allyHealthPercent = mutils.SafeGetHealthPercent(ally);
            if allyHealthPercent < 0.35 and mutils.SafeWasRecentlyDamaged(ally, 1.5) then
                -- Find enemy attacking this ally
                local enemies = ally:GetNearbyHeroes(600, true, BOT_MODE_NONE);
                for _, enemy in pairs(enemies) do
                    if mutils.IsValidTarget(enemy) then
                        local distanceToEnemy = GetUnitToUnitDistance(bot, enemy);
                        if distanceToEnemy <= nCastRange and bot:IsFacingUnit(enemy, 15) then
                            if not enemy:HasModifier("modifier_slark_pounce_leash") then
                                return BOT_ACTION_DESIRE_HIGH;
                            end
                        end
                    end
                end
            end
        end
    end

    -- UNSTUCK: Get out of blocked position
    if mutils.IsStuck(bot) then
        return BOT_ACTION_DESIRE_MODERATE;
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderShadowDance()
    if not mutils.CanBeCast(abilityShadowDance) then
        return BOT_ACTION_DESIRE_NONE;
    end

    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();

    -- EMERGENCY SAVE: Very low HP
    if healthPercent < 0.25 and bot:WasRecentlyDamagedByAnyHero(2.0) then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end

    -- ESCAPE: Retreating and taking damage
    if mutils.IsRetreating(bot) then
        local enemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
        if #enemies > 0 and healthPercent < 0.5 then
            for _, enemy in pairs(enemies) do
                if bot:WasRecentlyDamagedByHero(enemy, 2.0) or enemy:IsChanneling() then
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end

    -- TEAMFIGHT: Multiple enemies and moderate health
    if mutils.IsInTeamFight(bot, 1200) and healthPercent < 0.6 then
        local enemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    -- OFFENSIVE: Going on someone but need healing/invis
    if mutils.IsGoingOnSomeone(bot) and healthPercent < 0.65 then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            local distance = GetUnitToUnitDistance(bot, target);
            -- Use when close to target to stay in fight and heal
            if distance <= 400 then
                local nearbyEnemies = target:GetNearbyHeroes(1000, false, BOT_MODE_NONE);
                if #nearbyEnemies >= 2 then
                    return BOT_ACTION_DESIRE_MODERATE;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderDepthShroud()
    -- Shard check: ability exists and not hidden
    if abilityDepthShroud == nil or not mutils.CanBeCast(abilityDepthShroud) or abilityDepthShroud:IsHidden() then
        return BOT_ACTION_DESIRE_NONE, nil;
    end

    local nCastRange = math.min(abilityDepthShroud:GetCastRange(), 1600);
    local nRadius = abilityDepthShroud:GetSpecialValueInt("radius");

    -- SAVE ALLIES: Low HP allies in teamfight
    local allies = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
    for _, ally in pairs(allies) do
        if not ally:IsIllusion() then
            local allyHealthPercent = mutils.SafeGetHealthPercent(ally);
            if allyHealthPercent < 0.30 and mutils.SafeWasRecentlyDamaged(ally, 2.0) then
                -- Place on low HP ally
                return BOT_ACTION_DESIRE_VERYHIGH, ally:GetLocation();
            end
        end
    end

    -- TEAMFIGHT: Protect multiple allies
    if mutils.IsInTeamFight(bot, 1200) then
        local alliesInDanger = 0;
        local centerLocation = bot:GetLocation();
        
        for _, ally in pairs(allies) do
            if not ally:IsIllusion() then
                local allyHealthPercent = mutils.SafeGetHealthPercent(ally);
                if allyHealthPercent < 0.5 and mutils.SafeWasRecentlyDamaged(ally, 2.0) then
                    alliesInDanger = alliesInDanger + 1;
                    centerLocation = ally:GetLocation();
                end
            end
        end
        
        if alliesInDanger >= 2 then
            return BOT_ACTION_DESIRE_HIGH, centerLocation;
        end
    end

    -- SELF SAVE: Use on self when low HP
    if bot:GetHealth() / bot:GetMaxHealth() < 0.35 then
        local enemies = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
        if #enemies > 0 and bot:WasRecentlyDamagedByAnyHero(2.0) then
            return BOT_ACTION_DESIRE_HIGH, bot:GetLocation();
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil;
end