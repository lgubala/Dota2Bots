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

--[[
"Ability1"		"zuus_arc_lightning"
"Ability2"		"zuus_lightning_bolt"
"Ability3"		"zuus_heavenly_jump"
"Ability4"		"zuus_cloud"
"Ability6"		"zuus_thundergods_wrath"
]]

local abilityQ = nil;  -- Arc Lightning
local abilityW = nil;  -- Lightning Bolt
local abilityE = nil;  -- Heavenly Jump
local abilityD = nil;  -- Nimbus (Scepter)
local abilityR = nil;  -- Thundergod's Wrath

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castDDesire = 0;
local castRDesire = 0;

local function IsValidObject(object)
	return object ~= nil and object:IsNull() == false and object:CanBeSeen() == true;
end

-- Check for global low HP enemies for ultimate killsteal
local function GetGlobalKillTarget()
	local nDamage = abilityR:GetSpecialValueInt('damage');
	local nDamageType = abilityR:GetDamageType();
	
	local gEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
	for _, enemy in pairs(gEnemies) do
		if enemy ~= nil and mutils.CanCastOnNonMagicImmune(enemy) then
			local enemyHealth = mutils.SafeGetHealth(enemy);
			if enemyHealth > 0 and enemyHealth <= enemy:GetActualIncomingDamage(nDamage, nDamageType) then
				return enemy;
			end
		end
	end
	return nil;
end

-- Check for enemies that can be revealed (invisible or in fog)
local function GetRevealTarget(nCastRange)
	local enemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
	for _, enemy in pairs(enemies) do
		if enemy ~= nil and GetUnitToUnitDistance(bot, enemy) <= nCastRange then
			-- Target invisible enemies or those we want to reveal
			if enemy:IsInvisible() or not enemy:CanBeSeen() then
				return enemy;
			end
		end
	end
	return nil;
end

local function ConsiderQ()
	if not mutils.CanBeCast(abilityQ) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
	local nCastPoint = abilityQ:GetCastPoint();
	local manaCost = abilityQ:GetManaCost();
	local nRadius = abilityQ:GetSpecialValueInt("radius");
	
	-- LAST HIT: Use for last hitting in lane
	if bot:GetActiveMode() == BOT_MODE_LANING then
		local target = mutils.GetSpellKillTarget(bot, false, nCastRange, abilityQ:GetAbilityDamage(), abilityQ:GetDamageType());
		if target ~= nil then
			return BOT_ACTION_DESIRE_HIGH, target;
		end
	end
	
	-- INTERRUPT: Channeling enemies (highest priority)
	local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
	for _, enemy in pairs(enemies) do
		if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
			return BOT_ACTION_DESIRE_VERYHIGH, enemy;
		end
	end
	
	-- HARASS: Lane harassment
	if bot:GetActiveMode() == BOT_MODE_LANING and mutils.CanSpamSpell(bot, manaCost) then
		local target = mutils.GetVulnerableWeakestUnit(true, true, nCastRange, bot);
		if target ~= nil then
			return BOT_ACTION_DESIRE_MODERATE, target;
		end
	end
	
	-- RETREATING: Hit pursuers
	if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local target = mutils.GetVulnerableWeakestUnit(true, true, nCastRange, bot);
		if target ~= nil then
			return BOT_ACTION_DESIRE_HIGH, target;
		end
	end
	
	-- TEAMFIGHT: Use on multiple enemies
	if mutils.IsInTeamFight(bot, 1200) then
		local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0);
		if locationAoE.count >= 2 then
			local target = mutils.GetVulnerableUnitNearLoc(true, true, nCastRange, nRadius/2, locationAoE.targetloc, bot);
			if target ~= nil then
				return BOT_ACTION_DESIRE_HIGH, target;
			end
		end
	end
	
	-- FARMING: Clear creep waves
	if (mutils.IsPushing(bot) or mutils.IsDefending(bot)) and mutils.CanSpamSpell(bot, manaCost) then
		local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0);
		if locationAoE.count >= 3 then
			local target = mutils.GetVulnerableUnitNearLoc(false, true, nCastRange, nRadius, locationAoE.targetloc, bot);
			if target ~= nil then
				return BOT_ACTION_DESIRE_MODERATE, target;
			end
		end
	end
	
	-- OFFENSIVE: Going on someone
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
			return BOT_ACTION_DESIRE_HIGH, target;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

local function ConsiderW()
	if not mutils.CanBeCast(abilityW) then
		return BOT_ACTION_DESIRE_NONE, nil, "";
	end
	
	local nCastRange = math.min(abilityW:GetCastRange(), 1600);
	local nCastPoint = abilityW:GetCastPoint();
	local manaCost = abilityW:GetManaCost();
	local spreadAoE = abilityW:GetSpecialValueInt("spread_aoe");
	
	-- INTERRUPT: Channeling enemies or TPs (highest priority)
	local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
	for _, enemy in pairs(enemies) do
		if (mutils.SafeIsChanneling(enemy) or enemy:IsChanneling()) and mutils.CanCastOnNonMagicImmune(enemy) then
			return BOT_ACTION_DESIRE_VERYHIGH, enemy, "unit";
		end
	end
	
	-- REVEAL: Invisible enemies or for vision
	local revealTarget = GetRevealTarget(nCastRange);
	if revealTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, revealTarget:GetLocation(), "location";
	end
	
	-- KILL POTENTIAL: Finish off low enemies
	for _, enemy in pairs(enemies) do
		if mutils.CanCastOnNonMagicImmune(enemy) then
			local damage = abilityW:GetAbilityDamage();
			if mutils.CanKillTarget(enemy, damage, DAMAGE_TYPE_MAGICAL) then
				return BOT_ACTION_DESIRE_VERYHIGH, enemy, "unit";
			end
		end
	end
	
	-- RETREATING: Hit pursuers
	if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local target = mutils.GetVulnerableWeakestUnit(true, true, nCastRange, bot);
		if target ~= nil then
			return BOT_ACTION_DESIRE_HIGH, target, "unit";
		end
	end
	
	-- TEAMFIGHT: Hit enemies in fights
	if mutils.IsInTeamFight(bot, 1200) then
		-- Use ground targeting for AoE when multiple enemies
		local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, spreadAoE, 0, 0);
		if locationAoE.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc, "location";
		end
		
		-- Single target on main threat
		local target = mutils.GetVulnerableWeakestUnit(true, true, nCastRange, bot);
		if target ~= nil then
			return BOT_ACTION_DESIRE_HIGH, target, "unit";
		end
	end
	
	-- OFFENSIVE: Going on someone
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
			return BOT_ACTION_DESIRE_HIGH, target, "unit";
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil, "";
end

local function ConsiderE()
	if not mutils.CanBeCast(abilityE) then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local hopDistance = abilityE:GetSpecialValueInt("hop_distance");
	local nRange = abilityE:GetSpecialValueInt("range");
	
	-- ESCAPE: When retreating and being chased
	if mutils.IsRetreating(bot) then
		local enemies = bot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
		if #enemies > 0 and bot:WasRecentlyDamagedByAnyHero(2.0) then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end
	
	-- HUNTING: Going on someone and need gap closer
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) then
			local distanceToTarget = GetUnitToUnitDistance(bot, target);
			-- Use jump to get closer if target is a bit far but in jump range
			if distanceToTarget > 400 and distanceToTarget <= nRange then
				return BOT_ACTION_DESIRE_MODERATE;
			end
		end
	end
	
	-- VISION: Use for scouting when safe
	if bot:GetActiveMode() == BOT_MODE_ROAM and not mutils.IsRetreating(bot) then
		local enemies = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
		if #enemies == 0 then -- Safe to use for vision
			return BOT_ACTION_DESIRE_LOW;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

local function ConsiderD()
	-- Check if Nimbus ability exists (scepter)
	if abilityD == nil or not abilityD:IsFullyCastable() or abilityD:IsHidden() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	-- GLOBAL KILLSTEAL: Place nimbus on low enemies anywhere
	local globalTarget = GetGlobalKillTarget();
	if globalTarget ~= nil then
		return BOT_ACTION_DESIRE_VERYHIGH, globalTarget:GetLocation();
	end
	
	-- TEAMFIGHT ASSISTANCE: Help in fights happening elsewhere
	local allies = GetUnitList(UNIT_LIST_ALLIED_HEROES);
	for _, ally in pairs(allies) do
		if ally ~= bot and ally:IsAlive() then
			local alliesNearby = ally:GetNearbyHeroes(600, false, BOT_MODE_NONE);
			local enemiesNearby = ally:GetNearbyHeroes(600, true, BOT_MODE_NONE);
			-- If ally is outnumbered, help with nimbus
			if #enemiesNearby > #alliesNearby and #enemiesNearby >= 2 then
				return BOT_ACTION_DESIRE_HIGH, ally:GetLocation();
			end
		end
	end
	
	-- INTERRUPT: Cancel channeling/TPs globally
	local enemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
	for _, enemy in pairs(enemies) do
		if enemy ~= nil and mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
			return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
		end
	end
	
	-- REVEAL: Place on suspected invisible enemies
	if mutils.IsInTeamFight(bot, 1200) then
		local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
		if #enemies >= 2 then
			-- Place nimbus in center of enemy group
			local totalX, totalY = 0, 0;
			for _, enemy in pairs(enemies) do
				local loc = enemy:GetLocation();
				totalX = totalX + loc.x;
				totalY = totalY + loc.y;
			end
			local centerX = totalX / #enemies;
			local centerY = totalY / #enemies;
			return BOT_ACTION_DESIRE_MODERATE, Vector(centerX, centerY, 0);
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

local function ConsiderR()
	if not mutils.CanBeCast(abilityR) then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local nDamage = abilityR:GetSpecialValueInt('damage');
	local nDamageType = abilityR:GetDamageType();
	
	-- GLOBAL KILLSTEAL: Check for low enemies anywhere (highest priority)
	local killTarget = GetGlobalKillTarget();
	if killTarget ~= nil then
		return BOT_ACTION_DESIRE_VERYHIGH;
	end
	
	-- RETREATING: Use to kill pursuers
	if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local target = mutils.GetSpellKillTarget(bot, true, 9999, nDamage, nDamageType);
		if target ~= nil then
			return BOT_ACTION_DESIRE_HIGH;
		end
	end
	
	-- TEAMFIGHT: Multiple visible enemies
	if mutils.IsInTeamFight(bot, 1200) then
		local tableNearbyEnemyHeroes = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
		local nInvUnit = mutils.CountInvUnits(false, tableNearbyEnemyHeroes);
		if nInvUnit >= 3 then
			return BOT_ACTION_DESIRE_MODERATE;
		elseif nInvUnit >= 2 then
			return BOT_ACTION_DESIRE_LOW;
		end
	end
	
	-- Check for multiple low HP enemies globally
	local lowHPCount = 0;
	local gEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES);
	for _, enemy in pairs(gEnemies) do
		if enemy ~= nil and mutils.CanCastOnNonMagicImmune(enemy) then
			local enemyHealth = mutils.SafeGetHealth(enemy);
			local enemyMaxHealth = mutils.SafeGetMaxHealth(enemy);
			if enemyHealth > 0 and (enemyHealth / enemyMaxHealth) < 0.4 then
				lowHPCount = lowHPCount + 1;
			end
		end
	end
	
	if lowHPCount >= 2 then
		return BOT_ACTION_DESIRE_MODERATE;
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

function AbilityUsageThink()
	
	if mutils.CanNotUseAbility(bot) then return end
	
	-- Initialize abilities by name
	if abilityQ == nil then abilityQ = bot:GetAbilityByName("zuus_arc_lightning") end
	if abilityW == nil then abilityW = bot:GetAbilityByName("zuus_lightning_bolt") end
	if abilityE == nil then abilityE = bot:GetAbilityByName("zuus_heavenly_jump") end
	if abilityD == nil then abilityD = bot:GetAbilityByName("zuus_cloud") end  -- Nimbus (scepter)
	if abilityR == nil then abilityR = bot:GetAbilityByName("zuus_thundergods_wrath") end

	castQDesire, targetQ = ConsiderQ();
	castWDesire, targetW, castWType = ConsiderW();
	castEDesire = ConsiderE();
	castDDesire, targetD = ConsiderD();
	castRDesire = ConsiderR();

	-- Priority: Ultimate killsteal > Nimbus killsteal > Interrupt > Offensive abilities
	if castRDesire > 0 then
		bot:Action_UseAbility(abilityR);		
		return
	end
	
	if castDDesire > 0 then
		bot:Action_UseAbilityOnLocation(abilityD, targetD);		
		return
	end
	
	if castWDesire > 0 then
		if castWType == "location" then
			bot:Action_UseAbilityOnLocation(abilityW, targetW);
		else
			bot:Action_UseAbilityOnEntity(abilityW, targetW);
		end
		return
	end
	
	if castQDesire > 0 then
		bot:Action_UseAbilityOnEntity(abilityQ, targetQ);		
		return
	end
	
	if castEDesire > 0 then
		bot:Action_UseAbility(abilityE);		
		return
	end
end