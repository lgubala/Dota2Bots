if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion()  then
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

local npcBot = GetBot();

local abilityQ = nil;
local abilityE = nil;
local abilityR = nil;
local abilityTendril = nil;

local castQDesire = 0;
local castEDesire = 0;
local castRDesire = 0;
local castTendrilDesire = 0;

function AbilityUsageThink()
	
	if mutil.CanNotUseAbility(npcBot) then return end
	
	if abilityQ == nil then abilityQ = npcBot:GetAbilityByName( "tidehunter_gush" ) end
	if abilityE == nil then abilityE = npcBot:GetAbilityByName( "tidehunter_anchor_smash" ) end
	if abilityR == nil then abilityR = npcBot:GetAbilityByName( "tidehunter_ravage" ) end
	if abilityTendril == nil then abilityTendril = npcBot:GetAbilityByName( "tidehunter_dead_in_the_water" ) end

	castQDesire, castQTarget, Aghs = ConsiderQ();
	castEDesire                    = ConsiderE();
	castRDesire                    = ConsiderR();

	castTendrilDesire, castTendilsLoc = ConsiderTendril();

	if ( castTendrilDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnEntity( abilityTendril ,castTendilsLoc);
		return;
	end

	if ( castRDesire > 0 ) 
	then
		npcBot:Action_UseAbility( abilityR );
		return;
	end

	if ( castQDesire > 0 ) 
	then
		if Aghs then
			npcBot:Action_UseAbilityOnLocation( abilityQ, castQTarget );
			return;
		else
			npcBot:Action_UseAbilityOnEntity( abilityQ, castQTarget );
			return;
		end
	end
	
	if ( castEDesire > 0 ) 
	then
		npcBot:Action_UseAbility( abilityE );
		return;
	end
	
end

function ConsiderQ()

    -- Make sure it's castable
    if ( not abilityQ:IsFullyCastable() ) then 
        return BOT_ACTION_DESIRE_NONE, 0;
    end

    -- Get some of its values
    local nRadius     = abilityQ:GetSpecialValueInt('aoe_scepter');
    local nCastRange = abilityQ:GetCastRange();
    local nCastPoint = abilityQ:GetCastPoint( );
    local nManaCost  = abilityQ:GetManaCost( );
    local nDamage    = abilityQ:GetAbilityDamage( );
    
    local HasScepter = npcBot:HasScepter();
    
    if HasScepter then nCastRange = abilityQ:GetSpecialValueInt('cast_range_scepter') end
    
    if nCastRange > 1600 then nCastRange = 1600 else nCastRange = nCastRange + 200 end
    
    local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
    
    --print(("[TIDEHUNTER] Gush check - Enemies in range: " .. #tableNearbyEnemyHeroes .. " Has Scepter: " .. tostring(HasScepter));
    
    --if we can kill any enemies
    for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
    do
        if mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.CanKillTarget(npcEnemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            --print(("[TIDEHUNTER] KILL GUSH on " .. npcEnemy:GetUnitName());
            if HasScepter then
                return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation(), true;
            else
                return BOT_ACTION_DESIRE_HIGH, npcEnemy, false;
            end    
        end
    end
    
    -- HARASSMENT: Use Gush for harassment during laning
    if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, nManaCost)
    then
        for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
        do
            if mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.SafeGetHealth(npcEnemy) > 200 then
                --print(("[TIDEHUNTER] HARASSMENT GUSH on " .. npcEnemy:GetUnitName());
                if HasScepter then
                    return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetLocation(), true;
                else
                    return BOT_ACTION_DESIRE_MODERATE, npcEnemy, false;
                end    
            end
        end
    end
    
    -- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
    if mutil.IsRetreating(npcBot)
    then
        for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
        do
            if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy) and not mutil.IsDisabled(true, npcEnemy) ) 
            then
                --print(("[TIDEHUNTER] RETREAT GUSH on " .. npcEnemy:GetUnitName());
                if HasScepter then
                    return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation(), true;
                else
                    return BOT_ACTION_DESIRE_HIGH, npcEnemy, false;
                end    
            end
        end
    end
    
    if ( npcBot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
    then
        local npcTarget = mutil.SafeGetAttackTarget(npcBot);
        if ( mutil.IsRoshan(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)  )
        then
            --print(("[TIDEHUNTER] ROSHAN GUSH");
            if HasScepter then
                return BOT_ACTION_DESIRE_HIGH, npcTarget:GetLocation(), true;
            else
                return BOT_ACTION_DESIRE_HIGH, npcTarget, false;
            end    
        end
    end
    
    if mutil.IsInTeamFight(npcBot, 1200) and HasScepter
    then
        local locationAoE = npcBot:FindAoELocation( true, true, npcBot:GetLocation(), nCastRange-(2*nRadius), nRadius, nCastPoint, 0 );
        if ( locationAoE.count >= 1 ) -- Reduced from 2 to 1
        then
            --print(("[TIDEHUNTER] AOE GUSH - Targets: " .. locationAoE.count);
            return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc, true;
        end
    end

    -- If we're going after someone
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange) 
           and not mutil.IsDisabled(true, npcTarget)
        then
            --print(("[TIDEHUNTER] COMBAT GUSH on " .. npcTarget:GetUnitName());
            if HasScepter then
                return BOT_ACTION_DESIRE_HIGH, npcTarget:GetLocation(), true;
            else
                return BOT_ACTION_DESIRE_HIGH, npcTarget, false;
            end    
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, 0;
end

function ConsiderE()

    -- Make sure it's castable
    if ( not abilityE:IsFullyCastable() ) then 
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Get some of its values
    local nRadius    = abilityE:GetSpecialValueInt( "radius" );
    local nCastPoint = abilityE:GetCastPoint( );
    local nManaCost  = abilityE:GetManaCost( );
    local nDamage    = abilityE:GetAbilityDamage( );
    
    --print(("[TIDEHUNTER] Anchor Smash - Damage: " .. nDamage .. " Radius: " .. nRadius .. " Mana: " .. nManaCost);
    
    -- FARMING: Use for last hitting and farming (more aggressive)
    if ( mutil.IsPushing(npcBot) or mutil.IsDefending(npcBot) or npcBot:GetActiveMode() == BOT_MODE_LANING ) and mutil.AllowedToSpam(npcBot, nManaCost)
    then
        local tableNearbyCreeps = npcBot:GetNearbyLaneCreeps( nRadius, true );
        if ( tableNearbyCreeps ~= nil and #tableNearbyCreeps >= 2 ) 
        then
            --print(("[TIDEHUNTER] Using Anchor Smash for farming - " .. #tableNearbyCreeps .. " creeps");
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- NEUTRAL FARMING: Use in jungle
    if npcBot:GetActiveMode() == BOT_MODE_FARM and mutil.AllowedToSpam(npcBot, nManaCost)
    then
        local neutralCreeps = npcBot:GetNearbyNeutralCreeps( nRadius );
        if ( neutralCreeps ~= nil and #neutralCreeps >= 1 ) 
        then
            --print(("[TIDEHUNTER] Using Anchor Smash for neutrals - " .. #neutralCreeps .. " creeps");
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- HARASSMENT: Use on enemy heroes during laning
    if npcBot:GetActiveMode() == BOT_MODE_LANING and npcBot:GetMana() > npcBot:GetMaxMana() * 0.4
    then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nRadius, true, BOT_MODE_NONE );
        if ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 1 ) 
        then
            --print(("[TIDEHUNTER] Using Anchor Smash for harassment");
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
    if mutil.IsRetreating(npcBot) and npcBot:WasRecentlyDamagedByAnyHero( 2.0 )
    then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nRadius, true, BOT_MODE_NONE );
        if ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 1  ) 
        then
            --print(("[TIDEHUNTER] Using Anchor Smash for retreat");
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    if ( npcBot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
    then
        local npcTarget = mutil.SafeGetAttackTarget(npcBot);
        if ( mutil.IsRoshan(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nRadius)  )
        then
            --print(("[TIDEHUNTER] Using Anchor Smash on Roshan");
            return BOT_ACTION_DESIRE_HIGH
        end
    end
    
    if mutil.IsInTeamFight(npcBot, 1200)
    then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nRadius, true, BOT_MODE_NONE );
        if ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 1 ) 
        then
            --print(("[TIDEHUNTER] Using Anchor Smash in teamfight - " .. #tableNearbyEnemyHeroes .. " enemies");
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- If we're going after someone
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nRadius-50)
        then
            --print(("[TIDEHUNTER] Using Anchor Smash on target");
            return BOT_ACTION_DESIRE_HIGH;
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end


function ConsiderR()

    -- Make sure it's castable
    if ( not abilityR:IsFullyCastable() ) then 
        return BOT_ACTION_DESIRE_NONE;
    end

    -- Get some of its values
    local nRadius    = abilityR:GetSpecialValueInt( "radius" );
    local nCastPoint = abilityR:GetCastPoint( );
    local nManaCost  = abilityR:GetManaCost( );
    local nDamage    = abilityR:GetAbilityDamage( );
    
    -- REDUCE the effective range for better positioning
    local nEffectiveRadius = nRadius * 0.7; -- Use 70% of actual radius for better positioning
    
    --print(("[TIDEHUNTER] Checking Ravage - Actual Radius: " .. nRadius .. " Effective Radius: " .. nEffectiveRadius);
    
    local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nEffectiveRadius, true, BOT_MODE_NONE );
    local tableNearbyAllyHeroes  = npcBot:GetNearbyHeroes( 1200, false, BOT_MODE_NONE );
    
    --print(("[TIDEHUNTER] Ravage check - Enemies in range: " .. #tableNearbyEnemyHeroes .. " Allies nearby: " .. #tableNearbyAllyHeroes);
    
    -- TEAMFIGHT: Use Ravage more aggressively in teamfights
    if mutil.IsInTeamFight(npcBot, 1200)
    then
        -- Use if we can hit 2+ enemies OR 1 important enemy
        if ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 2 ) 
        then
            --print(("[TIDEHUNTER] TEAMFIGHT RAVAGE - Multiple enemies: " .. #tableNearbyEnemyHeroes);
            return BOT_ACTION_DESIRE_VERYHIGH;
        elseif ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 1 and #tableNearbyAllyHeroes >= 2 ) 
        then
            -- Single enemy but we have ally support - be more conservative
            local npcEnemy = tableNearbyEnemyHeroes[1];
            if mutil.IsInRange(npcEnemy, npcBot, nEffectiveRadius * 0.8) then -- Even closer for single target
                --print(("[TIDEHUNTER] TEAMFIGHT RAVAGE - Single enemy with ally support");
                return BOT_ACTION_DESIRE_HIGH;
            end
        end
    end
    
    -- EMERGENCY: If we're low HP and surrounded - use slightly larger range for safety
    local emergencyRadius = nRadius * 0.85; -- Slightly larger for emergencies
    local tableEmergencyEnemies = npcBot:GetNearbyHeroes( emergencyRadius, true, BOT_MODE_NONE );
    if mutil.SafeGetHealth(npcBot) < 0.3 * npcBot:GetMaxHealth() and #tableEmergencyEnemies >= 2
    then
        --print(("[TIDEHUNTER] EMERGENCY RAVAGE - Low HP surrounded");
        return BOT_ACTION_DESIRE_VERYHIGH;
    end
    
    -- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
    if mutil.IsRetreating(npcBot) and npcBot:WasRecentlyDamagedByAnyHero( 2.0 )
    then
        if ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 2 ) 
        then
            --print(("[TIDEHUNTER] RETREAT RAVAGE - Multiple pursuers");
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- GANK/INITIATION: More aggressive when going after someone
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nEffectiveRadius)
        then
            -- Use Ravage if target is important OR we can hit multiple enemies
            if ( #tableNearbyEnemyHeroes >= 2 ) 
            then
                --print(("[TIDEHUNTER] GANK RAVAGE - Multiple targets");
                return BOT_ACTION_DESIRE_VERYHIGH;
            elseif ( #tableNearbyAllyHeroes >= 1 and mutil.SafeGetHealth(npcTarget) > 0.5 * npcTarget:GetMaxHealth() ) 
            then
                -- Single target but we have backup and target has decent HP - be even closer
                if mutil.IsInRange(npcTarget, npcBot, nEffectiveRadius * 0.6) then -- 60% of effective radius
                    --print(("[TIDEHUNTER] GANK RAVAGE - Single target with backup (close range)");
                    return BOT_ACTION_DESIRE_HIGH;
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE;
end


function ConsiderTendril()

    -- Make sure it's castable
    if ( not abilityTendril:IsFullyCastable() ) then 
        return BOT_ACTION_DESIRE_NONE, 0;
    end

    -- Get some of its values
    local nCastRange = abilityTendril:GetCastRange();
    local nCastPoint = abilityTendril:GetCastPoint();
    local nManaCost  = abilityTendril:GetManaCost();
    local nDamage    = 50;
    
    local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange + 200, true, BOT_MODE_NONE );
    
    --print(("[TIDEHUNTER] Dead in Water check - Enemies in range: " .. #tableNearbyEnemyHeroes .. " Range: " .. nCastRange);
    
    --if we can kill any enemies
    for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
    do
        if mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.CanKillTarget(npcEnemy, nDamage, DAMAGE_TYPE_MAGICAL) then
            --print(("[TIDEHUNTER] KILL TENDRIL on " .. npcEnemy:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, npcEnemy;
        end
    end
    
    -- INTERRUPT CHANNELING - High priority
    for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
    do
        if mutil.SafeIsChanneling(npcEnemy) and mutil.CanCastOnNonMagicImmune(npcEnemy) then
            --print(("[TIDEHUNTER] INTERRUPT TENDRIL on channeling " .. npcEnemy:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, npcEnemy;
        end
    end
    
    -- HARASSMENT: Use during laning for harassment
    if npcBot:GetActiveMode() == BOT_MODE_LANING and mutil.AllowedToSpam(npcBot, nManaCost)
    then
        for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
        do
            if mutil.CanCastOnNonMagicImmune(npcEnemy) and mutil.SafeGetHealth(npcEnemy) > 150 then
                --print(("[TIDEHUNTER] HARASSMENT TENDRIL on " .. npcEnemy:GetUnitName());
                return BOT_ACTION_DESIRE_MODERATE, npcEnemy;
            end
        end
    end
    
    -- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
    if mutil.IsRetreating(npcBot)
    then
        for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
        do
            if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutil.CanCastOnNonMagicImmune(npcEnemy) and not mutil.IsDisabled(true, npcEnemy) ) 
            then
                --print(("[TIDEHUNTER] RETREAT TENDRIL on " .. npcEnemy:GetUnitName());
                return BOT_ACTION_DESIRE_HIGH, npcEnemy;
            end
        end
    end
    
    if ( npcBot:GetActiveMode() == BOT_MODE_ROSHAN  ) 
    then
        local npcTarget = mutil.SafeGetAttackTarget(npcBot);
        if ( mutil.IsRoshan(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)  )
        then
            --print(("[TIDEHUNTER] ROSHAN TENDRIL");
            return BOT_ACTION_DESIRE_MODERATE, npcTarget;
        end
    end
    
    -- FARMING: Use for last hitting big neutrals
    if npcBot:GetActiveMode() == BOT_MODE_FARM and mutil.AllowedToSpam(npcBot, nManaCost)
    then
        local lanecreeps = npcBot:GetNearbyNeutralCreeps(nCastRange+200);
        local target = mutil.GetMostHpUnit(lanecreeps);
        if target ~= nil and mutil.SafeGetHealth(target) > 200 then
            --print(("[TIDEHUNTER] FARMING TENDRIL on big neutral");
            return BOT_ACTION_DESIRE_LOW, target;
        end
    end
    
    -- TEAMFIGHT: Target carries and important heroes
    if mutil.IsInTeamFight(npcBot, 1200)
    then
        -- Priority 1: Look for carries
        for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
        do
            if ( npcEnemy:IsHero() and mutil.CanCastOnNonMagicImmune(npcEnemy) and not mutil.IsDisabled(true, npcEnemy) ) 
            then
                -- Check if it's a carry or important hero
                local heroName = npcEnemy:GetUnitName();
                if string.find(heroName, "antimage") or string.find(heroName, "phantom_assassin") or 
                   string.find(heroName, "drow_ranger") or string.find(heroName, "sniper") or
                   string.find(heroName, "invoker") or string.find(heroName, "pudge") or
                   string.find(heroName, "crystal_maiden") then
                    --print(("[TIDEHUNTER] PRIORITY TEAMFIGHT TENDRIL on " .. npcEnemy:GetUnitName());
                    return BOT_ACTION_DESIRE_HIGH, npcEnemy;
                end
            end
        end
        
        -- Priority 2: Any enemy hero if no carries found
        for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
        do
            if ( npcEnemy:IsHero() and mutil.CanCastOnNonMagicImmune(npcEnemy) and not mutil.IsDisabled(true, npcEnemy) ) 
            then
                --print(("[TIDEHUNTER] GENERAL TEAMFIGHT TENDRIL on " .. npcEnemy:GetUnitName());
                return BOT_ACTION_DESIRE_MODERATE, npcEnemy;
            end
        end
    end

    -- If we're going after someone
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange + 200) 
           and not mutil.IsDisabled(true, npcTarget)
        then
            --print(("[TIDEHUNTER] COMBAT TENDRIL on " .. npcTarget:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, npcTarget;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, 0;
end


