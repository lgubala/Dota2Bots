if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or  GetBot():IsIllusion()  then
	return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local skills = require(GetScriptDirectory() ..  "/SkillsUtility")
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

local castFBDesire = 0;
local castFB2Desire = 0;
local castTWDesire = 0;
local castTDDesire = 0;
local castRCDesire = 0;
local castMRADesire = 0;
local castMRSDesire = 0;
local castGhostDesire = 0;
local castEBDesire = 0;
local itemGhost = nil;
local itemEB = nil;
local alreadyCastEB = false;

local abilityFB = nil;
local abilityFB2 = nil;
local abilityTW = nil;
local abilityMRA = nil;
local abilityMRS = nil;
local abilityRC = nil;
local justMorph = true;
local npcBot = nil;

local skill1 = nil;
local skill2 = nil;
local skill3 = nil;
local asMorphling = true;
local plusFactor = 0;

function AbilityUsageThink()

	if npcBot == nil then npcBot = GetBot(); end
	
	plusFactor = npcBot:GetLevel() / 30 * 1.0;	
		
	if abilityRC == nil then abilityRC = npcBot:GetAbilityByName( "morphling_replicate" ) end
	
	local ab1 = npcBot:GetAbilityInSlot(0);
	
	if ab1 ~= nil and ab1:GetName() == 'morphling_waveform' then
		asMorphling = true;
	else
		asMorphling = false;
	end	

	if asMorphling == false then
		if justMorph == false then
			skill1 = npcBot:GetAbilityInSlot(0);
			skill2 = npcBot:GetAbilityInSlot(1);
			skill3 = npcBot:GetAbilityInSlot(2);	
			justMorph = true; 
		end
		if mutil.CanNotUseAbility(npcBot) then return end
		skills.CastStolenSpells(skill1);
		skills.CastStolenSpells(skill2);
		skills.CastStolenSpells(skill3);
		if ( (skill1 ~= nil and skill1:IsNull() == false and skill1:IsFullyCastable() == false) and
		     (skill2 ~= nil and skill2:IsNull() == false and skill2:IsFullyCastable() == false) and
		     (skill3 ~= nil and skill3:IsNull() == false and skill3:IsFullyCastable() == false) ) or npcBot:GetHealth() <= 0.35*npcBot:GetMaxHealth()
		then
			npcBot:Action_UseAbility(npcBot:GetAbilityByName( "morphling_morph_replicate" ));
			return
		end 
	else
		--[[if abilityFB == nil then abilityFB = npcBot:GetAbilityByName( "morphling_adaptive_strike_agi" ) end
		if abilityFB2 == nil then abilityFB2 = npcBot:GetAbilityByName( "morphling_adaptive_strike_str" ) end
		if abilityTW == nil then abilityTW = npcBot:GetAbilityByName( "morphling_waveform" ) end
		if abilityMRA == nil then abilityMRA = npcBot:GetAbilityByName( "morphling_morph_agi" ) end
		if abilityMRS == nil then abilityMRS = npcBot:GetAbilityByName( "morphling_morph_str" ) end]]--
		
		if justMorph then
			abilityFB = npcBot:GetAbilityByName( "morphling_adaptive_strike_agi" );
			abilityFB2 = npcBot:GetAbilityByName( "morphling_adaptive_strike_str" );
			abilityTW = npcBot:GetAbilityByName( "morphling_waveform" );
			abilityMRA = npcBot:GetAbilityByName( "morphling_morph_agi" );
			abilityMRS = npcBot:GetAbilityByName( "morphling_morph_str" ); 
			
			-- Debug: Check if abilities exist
			if abilityFB2 == nil then
				--print(("[MORPHLING] morphling_adaptive_strike_str not found - hero reworked");
			end
			
			justMorph = false;
		end
		
		
		if npcBot:IsSilenced() == false and npcBot:IsHexed() == false 
		   and npcBot:IsInvulnerable() == false and npcBot:HasModifier("modifier_doom_bringer_doom") == false
		then
			castMRADesire = ConsiderMorphAgility();
			castMRSDesire = ConsiderMorphStrength();
			if castMRSDesire > 0 then
				npcBot:Action_UseAbility( abilityMRS );
				return;
			end
			if castMRADesire > 0 then
				npcBot:Action_UseAbility( abilityMRA );
				return;
			end
		end
		
		-- Check if we're already using an ability
		if mutil.CanNotUseAbility(npcBot) then return end
		
		itemGhost = IsItemAvailable("item_ghost");
		itemEB = IsItemAvailable("item_ethereal_blade");
		
		-- Consider using each ability
		castTWDesire, castTWLocation = ConsiderTimeWalk();
		castFBDesire, castFBTarget = ConsiderFireblast();
		castFB2Desire, castFB2Target = ConsiderFireblast2();

		
		if abilityFB2 ~= nil then
			castFB2Desire, castFB2Target = ConsiderFireblast2();
		else
			castFB2Desire = 0;
			castFB2Target = nil;
		end

		castRCDesire, castRCTarget = ConsiderReplicate();
		castGhostDesire = ConsiderGhostScepter();
		castEBDesire, castEBTarget = ConsiderEtherealBlade();
		
		if ( castTWDesire > 0 ) 
		then
			npcBot:Action_UseAbilityOnLocation( abilityTW, castTWLocation );
			return;
		end	
		
		if ( castEBDesire > 0 ) 
		then
			npcBot:Action_UseAbilityOnEntity( itemEB, castEBTarget );
			alreadyCastEB = true;
			return;
		end
		
		if ( castFBDesire > 0 ) 
		then
			npcBot:Action_UseAbilityOnEntity( abilityFB, castFBTarget );
			alreadyCastEB = false;
			return;
		end
		
		if ( abilityFB2 ~= nil and castFB2Desire > 0 ) 
		then
			npcBot:Action_UseAbilityOnEntity( abilityFB2, castFB2Target );
			return;
		end

		if ( castRCDesire > 0 ) 
		then
			npcBot:Action_UseAbilityOnEntity( abilityRC, castRCTarget );
			return;
		end
		
		
		if castGhostDesire > 0 then
			npcBot:Action_UseAbility( itemGhost );
			return;
		end
	end
end

function IsItemAvailable(item_name)
    for i = 0, 5 do
        local item = npcBot:GetItemInSlot(i);
		if (item~=nil) then
			if(item:GetName() == item_name) then
				return item;
			end
		end
    end
    return nil;
end
	
function ConsiderFireblast()

    -- Make sure it's castable
    if ( not abilityFB:IsFullyCastable() ) then 
        return BOT_ACTION_DESIRE_NONE, 0;
    end
    
    if castEBDesire > 0 then
        return BOT_ACTION_DESIRE_NONE, 0;
    end
    
    -- Get some of its values
    local nCastRange = abilityFB:GetCastRange();
    local nMinAGIX = abilityFB:GetSpecialValueFloat("damage_min");
    local nMaxAGIX =  abilityFB:GetSpecialValueFloat("damage_max");
    local nAGI = npcBot:GetAttributeValue(ATTRIBUTE_AGILITY); 
    local nSTR = npcBot:GetAttributeValue(ATTRIBUTE_STRENGTH);
    local nDamage = 0; 
    
    if nAGI > nSTR and ( nAGI - nSTR ) / nSTR >= 0.5 then
        nDamage = nMaxAGIX * nAGI;
    else
        nDamage = nMinAGIX * nAGI;
    end
    
    --print(("[MORPHLING] Adaptive Strike damage: " .. nDamage .. " (AGI: " .. nAGI .. " STR: " .. nSTR .. ")");
    
    -- INTERRUPT CHANNELING - High priority
    local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange + 200, true, BOT_MODE_NONE );
    for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
    do
        if ( mutil.SafeIsChanneling(npcEnemy) and mutil.CanCastOnMagicImmune(npcEnemy) ) 
        then
            --print(("[MORPHLING] Interrupting channeling enemy: " .. npcEnemy:GetUnitName());
            return BOT_ACTION_DESIRE_HIGH, npcEnemy;
        end
    end
    
    if alreadyCastEB then
        -- If we're going after someone after Ethereal Blade
        if mutil.IsGoingOnSomeone(npcBot)
        then
            local npcTarget = npcBot:GetTarget();
            if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange+200)
            then
                --print(("[MORPHLING] Follow-up after Ethereal Blade");
                return BOT_ACTION_DESIRE_HIGH, npcTarget;
            end
        end
    end
    
    -- KILL SECURING - High priority
    local npcTarget = npcBot:GetTarget();
    if mutil.IsValidTarget(npcTarget) and mutil.CanKillTarget(npcTarget, nDamage, DAMAGE_TYPE_MAGICAL ) and mutil.CanCastOnMagicImmune(npcTarget) 
       and mutil.IsInRange(npcTarget, npcBot, nCastRange+200) 
    then
        --print(("[MORPHLING] Kill securing target");
        return BOT_ACTION_DESIRE_HIGH, npcTarget;
    end

    -- GENERAL COMBAT - More aggressive usage
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) 
           and mutil.IsInRange(npcTarget, npcBot, nCastRange+200)
        then
            -- Use if target has significant HP (worth the damage)
            if npcTarget:GetHealth() > 200 or nDamage > npcTarget:GetHealth() * 0.3 then
                --print(("[MORPHLING] Combat usage - target HP: " .. npcTarget:GetHealth());
                return BOT_ACTION_DESIRE_MODERATE, npcTarget;
            end
        end
    end
    
    -- HARASSMENT - Use on low HP enemies even if not targeting them
    for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
    do
        if mutil.IsValidTarget(npcEnemy) and mutil.CanCastOnMagicImmune(npcEnemy) then
            local enemyHPPercent = npcEnemy:GetHealth() / npcEnemy:GetMaxHealth();
            if enemyHPPercent < 0.4 and nDamage > npcEnemy:GetHealth() * 0.4 then
                --print(("[MORPHLING] Harassment on low HP enemy: " .. npcEnemy:GetUnitName());
                return BOT_ACTION_DESIRE_MODERATE, npcEnemy;
            end
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, 0;
end

function ConsiderFireblast2()

    -- Make sure the ability exists and is castable
    if ( abilityFB2 == nil or not abilityFB2:IsFullyCastable() ) then 
        return BOT_ACTION_DESIRE_NONE, 0;
    end
	-- Get some of its values
	local nCastRange = abilityFB2:GetCastRange();
	local nMinStun = abilityFB2:GetSpecialValueFloat("stun_min");
	local nMaxStun = abilityFB2:GetSpecialValueFloat("stun_max");
	local nAGI = npcBot:GetAttributeValue(ATTRIBUTE_AGILITY); 
	local nSTR = npcBot:GetAttributeValue(ATTRIBUTE_STRENGTH);
	local nStun = 0; 
	
	if nSTR > nAGI and ( nSTR - nAGI ) / nAGI >= 0.5 then
		nStun = nMaxStun;
	else
		nStun = nMinStun;
	end
	--------------------------------------
	-- Mode based usage
	--------------------------------------
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
	for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
	do
		if ( mutil.SafeIsChanneling(npcEnemy) ) 
		then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy;
		end
	end

	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nCastRange+200, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) and mutil.CanCastOnMagicImmune(npcEnemy) 
			    and nStun > nMinStun and mutil.IsDisabled(true, npcEnemy) == false ) 
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy;
			end
		end
	end

	-- If we're going after someone
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if ( npcTarget ~= nil  and npcTarget:IsHero() ) 
		then
			if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) 
			   and mutil.IsInRange(npcTarget, npcBot, nCastRange+200) and nStun > nMinStun and mutil.IsDisabled(true, npcTarget) == false 
			then
				return BOT_ACTION_DESIRE_HIGH, npcTarget;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;

end	


function ConsiderTimeWalk()

	-- Make sure it's castable
	if ( not abilityTW:IsFullyCastable() or npcBot:IsRooted() ) 
	then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end
	
	-- Get some of its values
	local nCastRange = abilityTW:GetCastRange()
	local nCastPoint = abilityTW:GetCastPoint();
	local nSpeed = abilityTW:GetSpecialValueInt("speed");
	local nDamage = abilityTW:GetAbilityDamage();
	local nAttackRange = npcBot:GetAttackRange();

	if mutil.IsStuck(npcBot)
	then
		return BOT_ACTION_DESIRE_HIGH, npcBot:GetXUnitsTowardsLocation( GetAncient(GetTeam()):GetLocation(), nCastRange );
	end
	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) ) 
			then
				local loc = mutil.GetEscapeLoc();
		    	return BOT_ACTION_DESIRE_HIGH, npcBot:GetXUnitsTowardsLocation( loc, nCastRange );
			end
		end
	end
	
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange)
		then
			local tableNearbyEnemyHeroes = npcTarget:GetNearbyHeroes( 1000, false, BOT_MODE_NONE );
			if tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes <= 2 then
				return BOT_ACTION_DESIRE_MODERATE, npcTarget:GetExtrapolatedLocation( ( GetUnitToUnitDistance( npcTarget, npcBot )/ nSpeed ) + nCastPoint );
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;
end


function ConsiderMorphAgility()
    
    -- Make sure it's castable
    if ( not abilityMRA:IsFullyCastable() ) then 
        return BOT_ACTION_DESIRE_NONE, 0;
    end
    
    -- Don't morph if low on mana (save mana for other abilities)
    if npcBot:GetMana() < 50 then
        return BOT_ACTION_DESIRE_NONE, 0;
    end
    
    -- Don't morph during retreat unless absolutely necessary
    if ( npcBot:GetActiveMode() == BOT_MODE_RETREAT  ) 
    then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1600, true, BOT_MODE_NONE );
        if ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0 ) 
            or npcBot:WasRecentlyDamagedByAnyHero(2.0) == true or npcBot:WasRecentlyDamagedByTower(2.0) == true 
        then
            return BOT_ACTION_DESIRE_NONE, 0;
        end
    end    
    
    -- Don't morph to AGI if low HP in combat
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget)  and mutil.IsInRange(npcTarget, npcBot, 1300)  and npcBot:GetHealth() < 0.35 * npcBot:GetMaxHealth() then
            return BOT_ACTION_DESIRE_NONE, 0;
        end
    end    
    
    local currAGI = npcBot:GetAttributeValue(ATTRIBUTE_AGILITY);
    local currSTRENGTH = npcBot:GetAttributeValue(ATTRIBUTE_STRENGTH);
    local isToggled = abilityMRA:GetToggleState();
    local botLevel = npcBot:GetLevel();
    
    -- Stop morphing if out of mana
    if npcBot:GetMana() < 1 and isToggled then
        --print(("[MORPHLING] Stopping AGI morph - out of mana");
        return BOT_ACTION_DESIRE_LOW;
    end
    
    -- SCALING THRESHOLDS: Adjust based on level and total attributes
    local totalAttributes = currAGI + currSTRENGTH;
    local desiredAgiRatio = 0.65; -- Want AGI to be ~65% of total attributes
    local targetAGI = totalAttributes * desiredAgiRatio;
    local agiDeficit = targetAGI - currAGI;
    
    --print(("[MORPHLING] Level: " .. botLevel .. " AGI: " .. currAGI .. " STR: " .. currSTRENGTH .. " Target AGI: " .. math.floor(targetAGI) .. " Deficit: " .. math.floor(agiDeficit));
    
    if isToggled then
        -- Currently morphing AGI - stop when close to target
        if agiDeficit <= 5 then  -- Stop when within 5 points of target
            --print(("[MORPHLING] Stopping AGI morph - target reached");
            return BOT_ACTION_DESIRE_LOW;
        end
    else
        -- Not morphing AGI - start if significantly below target
        if agiDeficit > 15 then  -- Start if more than 15 points below target
            --print(("[MORPHLING] Starting AGI morph - need " .. math.floor(agiDeficit) .. " more AGI");
            return BOT_ACTION_DESIRE_LOW;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, 0;
end

function ConsiderMorphStrength()

    -- Make sure it's castable
    if ( not abilityMRS:IsFullyCastable() ) then 
        return BOT_ACTION_DESIRE_NONE, 0;
    end
    
    local currAGI = npcBot:GetAttributeValue(ATTRIBUTE_AGILITY);
    local currSTRENGTH = npcBot:GetAttributeValue(ATTRIBUTE_STRENGTH);
    local isToggled = abilityMRS:GetToggleState();
    
    -- EMERGENCY: Low HP in combat - morph to STR immediately
    if mutil.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, npcBot, 1300) then
            if npcBot:GetHealth() < 0.25 * npcBot:GetMaxHealth() and not isToggled then
                --print(("[MORPHLING] EMERGENCY STR morph - low HP in combat");
                return BOT_ACTION_DESIRE_HIGH;
            elseif npcBot:GetHealth() > 0.5 * npcBot:GetMaxHealth() and isToggled then
                --print(("[MORPHLING] Stopping emergency STR morph - HP recovered");
                return BOT_ACTION_DESIRE_MODERATE;
            end
        end
    end    
    
    -- Stop morphing if out of mana
    if npcBot:GetMana() < 1 and isToggled then
        --print(("[MORPHLING] Stopping STR morph - out of mana");
        return BOT_ACTION_DESIRE_LOW;
    end
    
    -- RETREAT: Morph to STR for survivability
    if ( npcBot:GetActiveMode() == BOT_MODE_RETREAT ) 
    then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1300, true, BOT_MODE_NONE );
        if tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0 then
            if not isToggled and npcBot:GetHealth() < 0.6 * npcBot:GetMaxHealth() then
                --print(("[MORPHLING] Retreat STR morph");
                return BOT_ACTION_DESIRE_MODERATE;
            end
        elseif #tableNearbyEnemyHeroes == 0 and isToggled then     
            --print(("[MORPHLING] Stopping retreat STR morph - safe");
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    -- SCALING LOGIC: Only morph STR if AGI is way too high
    local totalAttributes = currAGI + currSTRENGTH;
    local currentAgiRatio = currAGI / totalAttributes;
    local maxDesiredAgiRatio = 0.75; -- Don't let AGI go above 75% of total
    
    --print(("[MORPHLING] AGI ratio: " .. string.format("%.2f", currentAgiRatio) .. " Max desired: " .. maxDesiredAgiRatio);
    
    if isToggled then
        -- Currently morphing STR - stop when AGI ratio is reasonable
        if currentAgiRatio <= 0.68 then  -- Stop when AGI drops to 68%
            --print(("[MORPHLING] Stopping STR morph - AGI ratio normalized");
            return BOT_ACTION_DESIRE_LOW;
        end
    else
        -- Not morphing STR - only start if AGI ratio is too high
        if currentAgiRatio > maxDesiredAgiRatio and not mutil.IsGoingOnSomeone(npcBot) then
            --print(("[MORPHLING] Starting STR morph - AGI ratio too high: " .. string.format("%.2f", currentAgiRatio));
            return BOT_ACTION_DESIRE_LOW;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, 0;
end

function ConsiderReplicate()

	-- Make sure it's castable
	if ( not abilityRC:IsFullyCastable() or npcBot:GetHealth() < 0.4*npcBot:GetMaxHealth() ) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end
	
	local nCastRange = abilityRC:GetCastRange();
	local nCastPoint = abilityRC:GetCastPoint();
	
	if mutil.IsInTeamFight(npcBot, 1200)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
		if ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 3 ) 
		then 
			local nMaxAD = 0;
			local target = nil;
			for _,enemy in pairs(tableNearbyEnemyHeroes)
			do
				local enemyAD = enemy:GetAttackDamage();
				if enemyAD > nMaxAD then
					target = enemy;
				end
			end
			if target ~= nil then
				return BOT_ACTION_DESIRE_MODERATE, target;
			end
		end
	end
	
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange+200) 
		   and npcTarget:GetHealth()/npcTarget:GetMaxHealth() > 0.75  
		then
			return BOT_ACTION_DESIRE_MODERATE, npcTarget;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;
end	

function ConsiderGhostScepter()

	-- Make sure it's castable
	if ( itemGhost == nil or not itemGhost:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE;
	end
	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) ) 
			then
				return BOT_ACTION_DESIRE_HIGH;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE;
end


function ConsiderEtherealBlade()

	-- Make sure it's castable
	if ( itemEB == nil or not itemEB:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end
	
	local nCastRange = abilityFB:GetCastRange();
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if mutil.IsRetreating(npcBot)
	then
		if ( npcBot:WasRecentlyDamagedByAnyHero(2.0) ) 
		then
			return BOT_ACTION_DESIRE_HIGH, npcBot;
		end
	end
	
	if mutil.IsGoingOnSomeone(npcBot)
	then
		local npcTarget = npcBot:GetTarget();
		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, npcBot, nCastRange+200)  
		then
			return BOT_ACTION_DESIRE_MODERATE, npcTarget;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;
end


