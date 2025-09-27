if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion()  then
	return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutil = require(GetScriptDirectory() ..  "/MyUtility")
local abUtils = require(GetScriptDirectory() ..  "/AbilityItemUsageUtility")

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
----------------------------------------------------------------------------------------------------

local castPNDesire = 0;
local castPWDesire = 0;
local castVGDesire = 0;
local castRDesire = 0;

local abilityPW = nil;
local abilityVG = nil;
local abilityPN = nil;

local npcBot = nil;

function AbilityUsageThink()

    if npcBot == nil then npcBot = GetBot(); end

    -- Check if we're already using an ability
    if mutil.CanNotUseAbility(npcBot) then return end

	if abilityPW == nil then abilityPW = npcBot:GetAbilityByName( "venomancer_plague_ward" ) end
	if abilityVG == nil then abilityVG = npcBot:GetAbilityByName( "venomancer_venomous_gale" ) end
	if abilityPN == nil then abilityPN = npcBot:GetAbilityByName( "venomancer_noxious_plague" ) end

	-- Debug: Check if abilities exist
	--print(("[VENOMANCER] Abilities - PW: " .. tostring(abilityPW ~= nil) .. " VG: " .. tostring(abilityVG ~= nil) .. " PN: " .. tostring(abilityPN ~= nil));
	if abilityPN ~= nil then
		--print(("[VENOMANCER] Ultimate level: " .. abilityPN:GetLevel() .. " Trained: " .. tostring(abilityPN:IsTrained()));
	end

    -- Consider using each ability
    castRDesire, targetR = ConsiderR();  -- This handles the ultimate
    castPWDesire, castPWLocation = ConsiderPlagueWard();
    castVGDesire, castVGLocation = ConsiderVenomGale();

    --print(("[VENOMANCER] Desires - PN: " .. castPNDesire .. " PW: " .. castPWDesire .. " VG: " .. castVGDesire .. " R: " .. castRDesire);

    -- Use ultimate first (highest priority)
    if castRDesire > 0 and targetR ~= nil then
        --print(("[VENOMANCER] Using Noxious Plague on " .. targetR:GetUnitName());
        npcBot:Action_UseAbilityOnEntity(abilityPN, targetR);        
        return
    end

    if ( castPWDesire > 0 )
    then
        --print(("[VENOMANCER] Using Plague Ward");
        npcBot:Action_UseAbilityOnLocation( abilityPW, castPWLocation );
        return;
    end

    if ( castVGDesire > 0 )
    then
        --print(("[VENOMANCER] Using Venomous Gale");
        npcBot:Action_UseAbilityOnLocation( abilityVG, castVGLocation );
        return;
    end

end


function ConsiderPlagueWard()

    -- Make sure it's castable
    if ( not abilityPW:IsFullyCastable() )
    then
        return BOT_ACTION_DESIRE_NONE, 0;
    end

    local nCastRange = abilityPW:GetCastRange();

    --print(("[VENOMANCER] Plague Ward check - Range: " .. nCastRange);

    -- FARMING: Use for last hitting and farming
    if ( npcBot:GetActiveMode() == BOT_MODE_LANING and
        npcBot:GetMana()/npcBot:GetMaxMana() >= 0.4 )  -- Reduced from 0.75
    then
        local tableNearbyEnemyCreeps = npcBot:GetNearbyLaneCreeps( 800, true);
        if(tableNearbyEnemyCreeps[1] ~= nil) then
            --print(("[VENOMANCER] FARMING PLAGUE WARD");
            return BOT_ACTION_DESIRE_MODERATE, tableNearbyEnemyCreeps[1]:GetLocation();
        end
    end

    -- HARASSMENT: Use for harassment during laning
    if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, abilityPW:GetManaCost())
    then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
        if #tableNearbyEnemyHeroes >= 1 then
            --print(("[VENOMANCER] HARASSMENT PLAGUE WARD");
            return BOT_ACTION_DESIRE_MODERATE, tableNearbyEnemyHeroes[1]:GetLocation();
        end
    end
    
    if ( npcBot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
    then
        local npcTarget = npcBot:GetTarget();
        if ( mutil.IsRoshan(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)  )
        then
            --print(("[VENOMANCER] ROSHAN PLAGUE WARD");
            return BOT_ACTION_DESIRE_HIGH, npcTarget:GetLocation();
        end
    end

    -- If we're pushing or defending a lane
    if mutil.IsDefending(npcBot) or mutil.IsPushing(npcBot) and npcBot:GetMana()/npcBot:GetMaxMana() >= 0.3  -- Reduced from 0.55
    then
        local tableNearbyEnemyCreeps = npcBot:GetNearbyLaneCreeps( 800, true);
        if(tableNearbyEnemyCreeps[1] ~= nil ) 
        then
            --print(("[VENOMANCER] PUSH/DEFEND PLAGUE WARD");
            return BOT_ACTION_DESIRE_MODERATE, tableNearbyEnemyCreeps[1]:GetLocation();
        end
    end

    -- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
    if mutil.IsRetreating(npcBot)
    then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
        for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
        do
            if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy) )
            then
                --print(("[VENOMANCER] RETREAT PLAGUE WARD");
                return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
            end
        end
    end

    -- If we're going after someone
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)
        then
            --print(("[VENOMANCER] COMBAT PLAGUE WARD");
            return BOT_ACTION_DESIRE_HIGH, npcTarget:GetExtrapolatedLocation(0.63);
        end
    end

    return BOT_ACTION_DESIRE_NONE, 0;
end

----------------------------------------------------------------------------------------------------

function ConsiderVenomGale()
    
    -- Make sure it's castable
    if ( not abilityVG:IsFullyCastable() ) then
        return BOT_ACTION_DESIRE_NONE, 0;
    end

    -- Get some of its values
    local nCastRange = abilityVG:GetCastRange();
    local nRadius = 125;
    local nDamage = abilityVG:GetAbilityDamage();

	-- Fix for 0 damage issue
    if nDamage == 0 and abilityVG:GetLevel() > 0 then
        nDamage = 25 + (abilityVG:GetLevel() * 50); -- Approximate damage scaling
    end
    
    --print(("[VENOMANCER] Venomous Gale check - Range: " .. nCastRange .. " Damage: " .. nDamage);
    
    local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
    
    -- INTERRUPT CHANNELING
    for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
    do
        if mutil.SafeIsChanneling(npcEnemy) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
            --print(("[VENOMANCER] INTERRUPT GALE on " .. npcEnemy:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
        end
    end

    -- KILL SECURING
    for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
    do
        if mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.CanKillTarget(npcEnemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            --print(("[VENOMANCER] KILL GALE on " .. npcEnemy:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
        end
    end

    -- HARASSMENT: Use during laning
    if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, abilityVG:GetManaCost())
    then
        for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
        do
            if mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.SafeGetHealth(npcEnemy) > 150 then
                --print(("[VENOMANCER] HARASSMENT GALE on " .. npcEnemy:GetUnitName());
                return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetLocation();
            end
        end
    end
    
    -- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
    if mutil.IsRetreating(npcBot)
    then
        for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
        do
            if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy) )
            then
                --print(("[VENOMANCER] RETREAT GALE on " .. npcEnemy:GetUnitName());
                return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
            end
        end
    end

    -- If we're going after someone
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)
        then
            --print(("[VENOMANCER] COMBAT GALE on " .. npcTarget:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, npcTarget:GetLocation();
        end
    end

    return BOT_ACTION_DESIRE_NONE, 0;
end


----------------------------------------------------------------------------------------------------

function ConsiderPoisonNova()

    -- Make sure it's castable
    if ( not abilityPN:IsFullyCastable() ) then
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Get some of its values
    local nRadius = abilityPN:GetSpecialValueInt( "radius" );
    local nCastRange = abilityPN:GetCastRange();
    local nDamage = abilityPN:GetAbilityDamage();

    --print(("[VENOMANCER] Poison Nova check - Radius: " .. nRadius .. " Damage: " .. nDamage);

    local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nRadius, true, BOT_MODE_NONE );
    --print(("[VENOMANCER] Enemies in Nova range: " .. #tableNearbyEnemyHeroes);

    -- TEAMFIGHT: Use more aggressively in teamfights
    if mutil.IsInTeamFight(npcBot, 1200) 
    then
        if ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 2 )
        then
            --print(("[VENOMANCER] TEAMFIGHT POISON NOVA - " .. #tableNearbyEnemyHeroes .. " enemies");
            return BOT_ACTION_DESIRE_HIGH;
        elseif ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 1 )
        then
            --print(("[VENOMANCER] TEAMFIGHT POISON NOVA - Single enemy");
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end

    -- EMERGENCY: If low HP and enemies nearby
    if mutil.SafeGetHealth(npcBot) < 0.4 * npcBot:GetMaxHealth() and #tableNearbyEnemyHeroes >= 1
    then
        --print(("[VENOMANCER] EMERGENCY POISON NOVA - Low HP");
        return BOT_ACTION_DESIRE_HIGH;
    end

    -- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
    if mutil.IsRetreating(npcBot)
    then
        for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
        do
            if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy) )
            then
                --print(("[VENOMANCER] RETREAT POISON NOVA");
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    -- If we're going after someone
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if  mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget)
        then
            if ( mutil.IsInRange(npcTarget, npcBot, nRadius - 100) and #tableNearbyEnemyHeroes >= 1 )
            then
                --print(("[VENOMANCER] COMBAT POISON NOVA");
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end



function ConsiderR()
    if not mutil.CanBeCast(abilityPN) then
        --print(("[VENOMANCER] Ultimate not castable");
        return BOT_ACTION_DESIRE_NONE, nil;
    end
    
    local nCastRange = abilityPN:GetCastRange();
    if nCastRange > 1600 then nCastRange = 1600 else nCastRange = nCastRange + 200 end
    local nCastPoint = abilityPN:GetCastPoint();
    local manaCost  = abilityPN:GetManaCost();
    
    --print(("[VENOMANCER] Ultimate check - Range: " .. nCastRange .. " Mana cost: " .. manaCost);
    
    local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
    --print(("[VENOMANCER] Enemies in ultimate range: " .. #tableNearbyEnemyHeroes);
    
    -- TEAMFIGHT: Use aggressively in teamfights
    if mutil.IsInTeamFight(npcBot, 1300)
    then
        local target = mutil.GetStrongestUnit(nCastRange, npcBot, true, false, 5.0);
        if target ~= nil then
            --print(("[VENOMANCER] TEAMFIGHT ULTIMATE on " .. target:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, target;
        end
        
        -- Fallback: target any enemy in teamfight
        for _,enemy in pairs(tableNearbyEnemyHeroes) do
            if mutil.CanCastOnNonMagicImmune(enemy) then
                --print(("[VENOMANCER] TEAMFIGHT ULTIMATE fallback on " .. enemy:GetUnitName());
                return BOT_ACTION_DESIRE_HIGH, enemy;
            end
        end
    end
    
    -- RETREAT: Use when retreating and damaged
    if mutil.IsRetreating(npcBot) and npcBot:WasRecentlyDamagedByAnyHero(2.0)
    then
        local target = mutil.GetVulnerableWeakestUnit(true, true, nCastRange, npcBot);
        if target ~= nil then
            --print(("[VENOMANCER] RETREAT ULTIMATE on " .. target:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end
    
    -- COMBAT: Use when going after someone
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local target = npcBot:GetTarget();
        if mutil.IsValidTarget(target) and mutil.CanCastOnNonMagicImmune(target) and mutil.IsInRange(target, npcBot, nCastRange) 
            and target:HasModifier('modifier_templar_assassin_refraction_absorb') == false
        then
            --print(("[VENOMANCER] COMBAT ULTIMATE on " .. target:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, target;
        end
    end
    
    -- HARASSMENT: Use ultimate for harassment if enemies are low
    if npcBot:GetActiveMode() == BOT_MODE_LANING and npcBot:GetMana() > npcBot:GetMaxMana() * 0.6
    then
        for _,enemy in pairs(tableNearbyEnemyHeroes) do
            if mutil.CanCastOnNonMagicImmune(enemy) and mutil.SafeGetHealthPercent(enemy) * 0.5 then
                --print(("[VENOMANCER] HARASSMENT ULTIMATE on low HP " .. enemy:GetUnitName());
                return BOT_ACTION_DESIRE_MODERATE, enemy;
            end
        end
    end
    
    --print(("[VENOMANCER] No ultimate usage condition met");
    return BOT_ACTION_DESIRE_NONE, nil;
end
