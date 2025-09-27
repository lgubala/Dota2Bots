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
"Ability1"		"tiny_avalanche"
"Ability2"		"tiny_toss"
"Ability3"		"tiny_tree_grab"
"Ability4"		"tiny_tree_channel"
"Ability7"		"tiny_toss_tree"
]]

local abilityQ = nil;  -- Avalanche
local abilityW = nil;  -- Toss
local abilityE = nil;  -- Tree Grab
local abilityD = nil;  -- Tree Channel (Scepter)
local abilityThrow = nil;  -- Toss Tree

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castDDesire = 0;
local castThrowDesire = 0;

-- Combo tracking
local avalancheStartTime = 0;
local comboWindow = 2.0; -- Time window for avalanche + toss combo

local function IsValidObject(object)
	return object ~= nil and object:IsNull() == false and object:CanBeSeen() == true;
end

-- Check if Tiny has a tree equipped
local function HasTree()
	return bot:HasModifier("modifier_tiny_tree_grab");
end

-- Check if Tiny has shard (unlimited tree attacks)
local function HasShard()
	return bot:HasModifier("modifier_item_aghanims_shard");
end

-- Get tree attack count remaining
local function GetTreeAttacksRemaining()
	if not HasTree() then return 0 end
	if HasShard() then return 999 end -- Unlimited with shard
	
	-- Try to estimate remaining attacks (default is 5)
	-- This is approximate since we can't directly read modifier stacks
	local treeDuration = 60; -- Tree lasts 60 seconds if not used
	-- Estimate based on time or assume 3-4 attacks left on average
	return 3;
end

local function ConsiderQ()
	if not mutils.CanBeCast(abilityQ) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = math.min(abilityQ:GetCastRange(), 1600);
	local nCastPoint = abilityQ:GetCastPoint();
	local manaCost = abilityQ:GetManaCost();
	local nRadius = abilityQ:GetSpecialValueInt("radius");
	
	-- INTERRUPT: Channeling enemies (highest priority)
	local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
	for _, enemy in pairs(enemies) do
		if mutils.SafeIsChanneling(enemy) and mutils.CanCastOnNonMagicImmune(enemy) then
			return BOT_ACTION_DESIRE_VERYHIGH, enemy:GetLocation();
		end
	end
	
	-- SAVE ALLY: Block enemies chasing low health allies
	local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE);
	for _, ally in pairs(allies) do
		if ally ~= bot and mutils.IsValidTarget(ally) then
			local allyHealth = ally:GetHealth() / ally:GetMaxHealth();
			if allyHealth < 0.4 then
				local enemiesNearAlly = ally:GetNearbyHeroes(600, true, BOT_MODE_NONE);
				if #enemiesNearAlly > 0 and mutils.CanCastOnNonMagicImmune(enemiesNearAlly[1]) then
					return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]:GetLocation();
				end
			end
		end
	end
	
	-- COMBO INITIATION: Start avalanche-toss combo
	if mutils.CanBeCast(abilityW) and mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
		   mutils.IsInRange(target, bot, nCastRange) then
			-- Check if we can grab the target or nearby unit for toss
			local grabRadius = abilityW:GetSpecialValueInt("grab_radius");
			local nearbyUnits = bot:GetNearbyHeroes(grabRadius, true, BOT_MODE_NONE);
			if #nearbyUnits > 0 or mutils.IsInRange(target, bot, grabRadius) then
				avalancheStartTime = DotaTime();
				return BOT_ACTION_DESIRE_VERYHIGH, target:GetExtrapolatedLocation(nCastPoint);
			end
		end
	end
	
	-- RETREATING: Stun pursuers
	if mutils.IsRetreating(bot) then
		for _, enemy in pairs(enemies) do
			if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
				return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation();
			end
		end
	end
	
	-- TEAMFIGHT: AoE stun multiple enemies
	if mutils.IsInTeamFight(bot, 1200) then
		local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, nCastPoint, 0);
		if locationAoE.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
		end
	end
	
	-- FARMING: Clear creep waves
	if (mutils.IsDefending(bot) or mutils.IsPushing(bot)) and mutils.CanSpamSpell(bot, manaCost) then
		local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, nCastPoint, 0);
		if locationAoE.count >= 3 then
			return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

local function ConsiderW()
	if not mutils.CanBeCast(abilityW) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = math.min(abilityW:GetCastRange(), 1600);
	local nCastPoint = abilityW:GetCastPoint();
	local manaCost = abilityW:GetManaCost();
	local grabRadius = abilityW:GetSpecialValueInt("grab_radius");
	local damageRadius = abilityW:GetSpecialValueInt("radius");
	
	-- COMBO EXECUTION: Complete avalanche-toss combo
	if avalancheStartTime > 0 and DotaTime() - avalancheStartTime < comboWindow then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
		   mutils.IsInRange(target, bot, nCastRange) then
			-- Prefer to toss the target enemy for maximum combo damage
			if mutils.IsInRange(target, bot, grabRadius) then
				return BOT_ACTION_DESIRE_VERYHIGH, target;
			else
				-- Toss nearest unit toward the target
				local nearbyUnits = bot:GetNearbyHeroes(grabRadius, true, BOT_MODE_NONE);
				local nearbyCreeps = bot:GetNearbyLaneCreeps(grabRadius, true);
				if #nearbyUnits > 0 then
					return BOT_ACTION_DESIRE_VERYHIGH, target;
				elseif #nearbyCreeps > 0 then
					return BOT_ACTION_DESIRE_VERYHIGH, target;
				end
			end
		end
	end
	
	-- SAVE ALLY: Toss ally away from danger
	local allies = bot:GetNearbyHeroes(grabRadius, false, BOT_MODE_NONE);
	for _, ally in pairs(allies) do
		if ally ~= bot and mutils.IsValidTarget(ally) then
			local allyHealth = ally:GetHealth() / ally:GetMaxHealth();
			if allyHealth < 0.3 then
				local enemiesNearAlly = ally:GetNearbyHeroes(400, true, BOT_MODE_NONE);
				if #enemiesNearAlly > 0 then
					-- Toss ally to safety (find safe location)
					local safeAllies = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
					for _, safeAlly in pairs(safeAllies) do
						if safeAlly ~= ally and safeAlly ~= bot and 
						   GetUnitToUnitDistance(safeAlly, enemiesNearAlly[1]) > 800 then
							return BOT_ACTION_DESIRE_HIGH, safeAlly;
						end
					end
				end
			end
		end
	end
	
	-- DISPLACEMENT: Toss enemy into team or isolate them
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
		   mutils.IsInRange(target, bot, nCastRange) then
			
			-- If target is in grab radius, toss them
			if mutils.IsInRange(target, bot, grabRadius) then
				-- Try to toss toward our allies
				local nearbyAllies = target:GetNearbyHeroes(600, false, BOT_MODE_NONE);
				if #nearbyAllies > 0 then
					return BOT_ACTION_DESIRE_HIGH, target; -- Toss target toward allies
				else
					return BOT_ACTION_DESIRE_HIGH, target; -- Toss for damage
				end
			else
				-- Toss nearby unit at the target
				local nearbyEnemies = bot:GetNearbyHeroes(grabRadius, true, BOT_MODE_NONE);
				local nearbyCreeps = bot:GetNearbyLaneCreeps(grabRadius, true);
				if #nearbyEnemies > 0 then
					return BOT_ACTION_DESIRE_HIGH, target;
				elseif #nearbyCreeps > 0 then
					return BOT_ACTION_DESIRE_MODERATE, target;
				end
			end
		end
	end
	
	-- ESCAPE: Toss enemy away when retreating
	if mutils.IsRetreating(bot) then
		local enemies = bot:GetNearbyHeroes(grabRadius, true, BOT_MODE_NONE);
		for _, enemy in pairs(enemies) do
			if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) then
				-- Toss enemy away from escape direction
				local escapeLocation = mutils.GetEscapeLoc();
				local behindBot = bot:GetXUnitsTowardsLocation(escapeLocation, -400);
				return BOT_ACTION_DESIRE_HIGH, enemy; -- Game will toss away from us
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

local function ConsiderE()
	if not mutils.CanBeCast(abilityE) or HasTree() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = abilityE:GetCastRange();
	
	-- ALWAYS try to get a tree when we don't have one
	if not mutils.IsRetreating(bot) and bot:GetHealth() > bot:GetMaxHealth() * 0.2 then
		local trees = bot:GetNearbyTrees(nCastRange);
		if #trees > 0 then
			-- Find accessible tree
			for _, tree in pairs(trees) do
				local treeLocation = GetTreeLocation(tree);
				if treeLocation and IsLocationPassable(treeLocation) then
					return BOT_ACTION_DESIRE_HIGH, tree;
				end
			end
			-- If no accessible tree found, use first available
			if #trees > 0 then
				return BOT_ACTION_DESIRE_MODERATE, trees[1];
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

local function ConsiderThrowTree()
	if not mutils.CanBeCast(abilityThrow) or not HasTree() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = math.min(abilityThrow:GetCastRange(), 1600);
	local nRadius = abilityThrow:GetSpecialValueInt("splash_radius");
	local attacksRemaining = GetTreeAttacksRemaining();
	
	-- PRESERVE TREE: Don't throw if we have shard (unlimited attacks)
	if HasShard() then
		-- Only throw tree in critical situations with shard
		if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(1.0) then
			local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
			for _, enemy in pairs(enemies) do
				if mutils.CanCastOnNonMagicImmune(enemy) and 
				   not mutils.IsInRange(enemy, bot, bot:GetAttackRange() + 50) then
					return BOT_ACTION_DESIRE_MODERATE, enemy;
				end
			end
		end
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	-- THROW BEFORE EXPIRY: Use tree when it's about to expire (1-2 attacks left)
	if attacksRemaining <= 2 then
		local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		if #enemies > 0 then
			local target = enemies[1];
			if mutils.CanCastOnNonMagicImmune(target) then
				return BOT_ACTION_DESIRE_HIGH, target;
			end
		end
	end
	
	-- ESCAPE: Throw tree at pursuers when retreating
	if mutils.IsRetreating(bot) then
		local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		for _, enemy in pairs(enemies) do
			if bot:WasRecentlyDamagedByHero(enemy, 2.0) and mutils.CanCastOnNonMagicImmune(enemy) and
			   not mutils.IsInRange(enemy, bot, bot:GetAttackRange() + 50) then
				return BOT_ACTION_DESIRE_HIGH, enemy;
			end
		end
	end
	
	-- RANGED HARASSMENT: Throw at enemies out of melee range
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and 
		   mutils.IsInRange(target, bot, nCastRange) and 
		   not mutils.IsInRange(target, bot, bot:GetAttackRange() + 100) then
			return BOT_ACTION_DESIRE_MODERATE, target;
		end
	end
	
	-- TEAMFIGHT: Throw for AoE damage
	if mutils.IsInTeamFight(bot, 1200) then
		local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
		if locationAoE.count >= 2 then
			local nearestEnemy = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)[1];
			if nearestEnemy and mutils.CanCastOnNonMagicImmune(nearestEnemy) then
				return BOT_ACTION_DESIRE_MODERATE, nearestEnemy;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

local function ConsiderTreeChannel()
	-- Only available with Aghanim's Scepter
	if not bot:HasScepter() or abilityD == nil or not abilityD:IsFullyCastable() or abilityD:IsHidden() then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = math.min(abilityD:GetCastRange(), 1600);
	local nRadius = abilityD:GetSpecialValueInt("splash_radius");
	local treeRadius = abilityD:GetSpecialValueInt("tree_grab_radius");
	local channelTime = abilityD:GetChannelTime();
	
	-- Check if we have enough trees nearby
	local nearbyTrees = bot:GetNearbyTrees(treeRadius);
	if #nearbyTrees < 3 then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	-- TEAMFIGHT: Massive AoE damage when enemies grouped
	if mutils.IsInTeamFight(bot, 1200) then
		local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
		local allies = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE);
		
		-- Only channel if we have backup and enemies are grouped
		if #enemies >= 2 and #allies >= 1 then
			local locationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0);
			if locationAoE.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc;
			end
		end
	end
	
	-- SIEGE: Channel on towers when pushing
	if mutil.IsPushing(bot) then
		local nearbyTowers = bot:GetNearbyTowers(nCastRange, true);
		local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
		
		-- Only if safe to channel (no enemies nearby)
		if #nearbyTowers > 0 and #enemies == 0 then
			return BOT_ACTION_DESIRE_MODERATE, nearbyTowers[1]:GetLocation();
		end
	end
	
	-- FARMING: Clear large creep waves
	if (mutils.IsDefending(bot) or mutils.IsPushing(bot)) and mutils.CanSpamSpell(bot, abilityD:GetManaCost()) then
		local enemies = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE);
		local creeps = bot:GetNearbyLaneCreeps(nCastRange, true);
		
		-- Only if safe and many creeps
		if #enemies == 0 and #creeps >= 5 then
			local locationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0);
			if locationAoE.count >= 4 then
				return BOT_ACTION_DESIRE_MODERATE, locationAoE.targetloc;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function AbilityUsageThink()
	
	if mutils.CanNotUseAbility(bot) then return end
	
	-- CHANNELING PROTECTION: Don't interrupt tree channel
	if mutils.SafeIsChanneling(bot) then
		-- Check if we should cancel channel due to danger
		local enemies = bot:GetNearbyHeroes(600, true, BOT_MODE_NONE);
		local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
		
		-- Cancel if low health and taking damage, or too many enemies
		if (healthPercent < 0.3 and bot:WasRecentlyDamagedByAnyHero(1.0)) or #enemies >= 3 then
			bot:Action_ClearActions(false);
		end
		return;
	end
	
	-- Initialize abilities by name
	if abilityQ == nil then abilityQ = bot:GetAbilityByName("tiny_avalanche") end
	if abilityW == nil then abilityW = bot:GetAbilityByName("tiny_toss") end
	if abilityE == nil then abilityE = bot:GetAbilityByName("tiny_tree_grab") end
	if abilityD == nil then abilityD = bot:GetAbilityByName("tiny_tree_channel") end
	if abilityThrow == nil then abilityThrow = bot:GetAbilityByName("tiny_toss_tree") end

	-- Consider using each ability
	local castQDesire, castQLocation = ConsiderQ();
	local castWDesire, castWTarget = ConsiderW();
	local castEDesire, castETarget = ConsiderE();
	local castDDesire, castDLocation = ConsiderTreeChannel();
	local castThrowDesire, castThrowTarget = ConsiderThrowTree();

	-- Priority: Combo execution > Tree channel > Throw tree > Individual abilities > Get tree
	
	-- COMBO: Avalanche + Toss (must be in correct order)
	if castQDesire > 0 and castWDesire > 0 and avalancheStartTime == 0 then
		-- Start combo with avalanche
		bot:Action_UseAbilityOnLocation(abilityQ, castQLocation);
		return;
	end
	
	-- Complete toss combo if avalanche was just cast
	if castWDesire > 0 and avalancheStartTime > 0 and DotaTime() - avalancheStartTime < comboWindow then
		bot:Action_UseAbilityOnEntity(abilityW, castWTarget);
		avalancheStartTime = 0; -- Reset combo
		return;
	end
	
	-- Tree Channel (scepter ability)
	if castDDesire > 0 then
		bot:Action_UseAbilityOnLocation(abilityD, castDLocation);
		return;
	end
	
	-- Throw tree (when appropriate)
	if castThrowDesire > 0 then
		bot:Action_UseAbilityOnEntity(abilityThrow, castThrowTarget);
		return;
	end
	
	-- Individual abilities
	if castQDesire > 0 then
		bot:Action_UseAbilityOnLocation(abilityQ, castQLocation);
		return;
	end
	
	if castWDesire > 0 then
		bot:Action_UseAbilityOnEntity(abilityW, castWTarget);
		return;
	end
	
	-- Get tree (lowest priority but important)
	if castEDesire > 0 then
		bot:Action_UseAbilityOnTree(abilityE, castETarget);
		return;
	end
	
	-- Reset combo timer if too much time passed
	if avalancheStartTime > 0 and DotaTime() - avalancheStartTime > comboWindow then
		avalancheStartTime = 0;
	end
end