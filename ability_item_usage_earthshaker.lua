if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
	return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutils = require(GetScriptDirectory() ..  "/MyUtility")
local nutils = require(GetScriptDirectory() ..  "/NewUtility")

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

local abilityQ = nil;
local abilityW = nil;
local abilityR = nil;

local castQDesire = 0;
local castWDesire = 0;
local castRDesire = 0;

local ItemBlink = nil;

local function IsValidObject(object)
	return object ~= nil and object:IsNull() == false and object:CanBeSeen() == true;
end

local function GetUnitCountWithinRadius(tUnits, radius)
	local count = 0;
	if tUnits ~= nil and #tUnits > 0 then
		for i=1,#tUnits do
			if IsValidObject(tUnits[i]) and GetUnitToUnitDistance(bot, tUnits[i]) <= radius then
				count = count + 1;
			end
		end	
	end
	return count;
end

local function ConsiderQ()
	if not mutils.CanBeCast(abilityQ) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
	local nCastPoint = abilityQ:GetCastPoint();
	local manaCost   = abilityQ:GetManaCost();
	local nRadius    = abilityQ:GetSpecialValueInt( "fissure_radius" );
	local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );

	-- Save ally - block enemies chasing low health allies
	local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	for _, ally in pairs(allies) do
		if ally ~= bot and mutils.IsValidTarget(ally) then
			local allyHealth = ally:GetHealth() / ally:GetMaxHealth();
			if allyHealth < 0.4 then
				local enemiesNearAlly = ally:GetNearbyHeroes(600, true, BOT_MODE_NONE);
				if #enemiesNearAlly > 0 and mutils.CanCastOnNonMagicImmune(enemiesNearAlly[1]) then
					local blockLocation = ally:GetXUnitsTowardsLocation(enemiesNearAlly[1]:GetLocation(), -200);
					if GetUnitToLocationDistance(bot, blockLocation) <= nCastRange then
						return BOT_ACTION_DESIRE_HIGH, blockLocation;
					end
				end
			end
		end
	end

	if mutils.IsRetreating(bot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( bot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutils.CanCastOnNonMagicImmune(npcEnemy) ) 
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation();
			end
		end
	end
	
	if mutils.IsInTeamFight(bot, 1200)
	then
		local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0 );
		if ( locationAoE.count >= 2 ) 
		then
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
		end
	end

	if mutils.IsGoingOnSomeone(bot)
	then
		local npcTarget = bot:GetTarget();
		if mutils.IsValidTarget(npcTarget) and mutils.CanCastOnNonMagicImmune(npcTarget) and mutils.IsInRange(npcTarget, bot, nCastRange) 
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget:GetExtrapolatedLocation(nCastPoint);
		end
	end

	if ( mutils.IsDefending(bot) ) and mutils.CanSpamSpell(bot, manaCost) 
	then
		local enemyCreeps = bot:GetNearbyLaneCreeps(nCastRange, true);
		if #enemyCreeps >= 4 then
			local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0 );
			if ( locationAoE.count >= 3 ) 
			then
				return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

local function ConsiderW()
	
	if not mutils.CanBeCast(abilityW) then
		return BOT_ACTION_DESIRE_NONE, "", nil;
	end
	local nCastRange = 0;
	if bot:HasScepter() == true then
		nCastRange = abilityW:GetSpecialValueInt("distance_scepter");
	end
	local nCastPoint = abilityW:GetCastPoint();
	local manaCost   = abilityW:GetManaCost();
	local nRadius    = abilityW:GetSpecialValueInt( "aftershock_range" );
	
	local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( nRadius, true, BOT_MODE_NONE );
	
	if bot:HasScepter() and mutils.IsRetreating(bot) and mutils.IsStuck(bot)
	then
		local loc = mutils.GetEscapeLoc();
		return BOT_ACTION_DESIRE_HIGH, "loc", bot:GetXUnitsTowardsLocation( loc, nCastRange );
	end
	
	if mutils.IsRetreating(bot)
	then
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( bot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and mutils.CanCastOnNonMagicImmune(npcEnemy) ) 
			then
				if bot:HasScepter() then
					return BOT_ACTION_DESIRE_HIGH, "loc", npcEnemy:GetLocation();
				else
					return BOT_ACTION_DESIRE_HIGH, "", nil;
				end
			end
		end
	end
	
	if mutils.IsInTeamFight(bot, 1200)
	then
		if bot:HasScepter() then
			return BOT_ACTION_DESIRE_HIGH, "unit", bot;
		else
			return BOT_ACTION_DESIRE_HIGH, "", nil;
		end	
	end

	if ( mutils.IsDefending(bot) or mutils.IsPushing(bot) ) and mutils.CanSpamSpell(bot, manaCost) 
	   and bot:HasModifier("modifier_earthshaker_enchant_totem") == false
	then
		if bot:HasScepter() then
			return BOT_ACTION_DESIRE_HIGH, "unit", bot;
		else
			return BOT_ACTION_DESIRE_HIGH, "", nil;
		end	
	end
	
	if mutils.IsGoingOnSomeone(bot) and bot:HasModifier("modifier_earthshaker_enchant_totem") == false
	then
		local npcTarget = bot:GetTarget();
		if mutils.IsValidTarget(npcTarget) and mutils.CanCastOnNonMagicImmune(npcTarget) 
		then
			if bot:HasScepter() == false and mutils.IsInRange(npcTarget, bot, nRadius) then
				return BOT_ACTION_DESIRE_HIGH, "", nil;
			elseif bot:HasScepter() then
				if mutils.IsInRange(npcTarget, bot, nRadius) == false and mutils.IsInRange(npcTarget, bot, nCastRange) then
					return BOT_ACTION_DESIRE_HIGH, "loc", npcTarget:GetLocation();
				elseif mutils.IsInRange(npcTarget, bot, nRadius) then
					return BOT_ACTION_DESIRE_HIGH, "unit", bot;				
				end
			end	
		end
	end

	return BOT_ACTION_DESIRE_NONE, "", nil;
end

local function ConsiderR()
	
	if not mutils.CanBeCast(abilityR) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	local nCastRange = 0;
	local nCastPoint = abilityR:GetCastPoint();
	local manaCost   = abilityR:GetManaCost();
	local nRadius    = 575;
	
	local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( nRadius, true, BOT_MODE_NONE );
	local tableNearbyEnemyCreeps = bot:GetNearbyLaneCreeps( nRadius, true );
	local tableNearbyNeutralCreeps = bot:GetNearbyNeutralCreeps( nRadius );
	
	local totalTargets = #tableNearbyEnemyHeroes + #tableNearbyEnemyCreeps + #tableNearbyNeutralCreeps;
	local heroCount = #tableNearbyEnemyHeroes;
	
	if mutils.IsInTeamFight(bot, 1200) 
	then
		if heroCount >= 3 or (heroCount >= 2 and totalTargets >= 5) then
			return BOT_ACTION_DESIRE_VERYHIGH, GetBestEchoPosition(tableNearbyEnemyHeroes);
		elseif heroCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH, GetBestEchoPosition(tableNearbyEnemyHeroes);
		end
	end

	-- Emergency use when low health but can get kills
	local botHealthPercent = bot:GetHealth() / bot:GetMaxHealth();
	if botHealthPercent < 0.3 and heroCount >= 1 then
		return BOT_ACTION_DESIRE_HIGH, GetBestEchoPosition(tableNearbyEnemyHeroes);
	end

	return BOT_ACTION_DESIRE_NONE, nil;
end

function GetBestEchoPosition(enemies)
	if #enemies == 0 then
		return bot:GetLocation();
	end
	
	-- Find center of enemy group
	local totalX, totalY = 0, 0;
	for _, enemy in pairs(enemies) do
		local loc = enemy:GetLocation();
		totalX = totalX + loc.x;
		totalY = totalY + loc.y;
	end
	
	local centerX = totalX / #enemies;
	local centerY = totalY / #enemies;
	
	return Vector(centerX, centerY, 0);
end

function AbilityUsageThink()
	
	if mutils.CanNotUseAbility(bot) then return end
	
	if abilityQ == nil then abilityQ = bot:GetAbilityByName( "earthshaker_fissure" ) end
	if abilityW == nil then abilityW = bot:GetAbilityByName( "earthshaker_enchant_totem" ) end
	if abilityR == nil then abilityR = bot:GetAbilityByName( "earthshaker_echo_slam" ) end

	-- Get Blink Dagger for combo
	ItemBlink = mutils.GetComboItem(bot, 'item_blink');

	castQDesire, QLoc  			 = ConsiderQ();
	castWDesire, targetType, tgt = ConsiderW();
	castRDesire, RLoc       	 = ConsiderR();

	-- BLINK + ECHO SLAM COMBO (like Axe's Blade Mail combo)
	if ItemBlink ~= nil and ItemBlink:IsFullyCastable() and castRDesire > 0 then
		bot:Action_UseAbilityOnLocation(ItemBlink, RLoc);
		return
	end

	if castRDesire > 0 then
		bot:Action_UseAbility(abilityR);		
		return
	end
	if castQDesire > 0 then
		bot:Action_UseAbilityOnLocation(abilityQ, QLoc);		
		return
	end
	if castWDesire > 0 then
		if targetType == "loc" then
			bot:Action_UseAbilityOnLocation(abilityW, tgt);
		elseif targetType == "unit" then
			bot:Action_UseAbilityOnEntity(abilityW, tgt);
		else
			bot:Action_UseAbility(abilityW);
		end	
		return
	end
end