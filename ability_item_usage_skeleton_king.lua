if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
	return;
end

local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
local mutils = require(GetScriptDirectory() ..  "/MyUtility")
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

local bot = GetBot();

local abilities = {};

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;

local lastCheck = -90;
local checkChanneling = DotaTime();

local lastGhostAttackTime = 0;
local lastGhostTarget = nil;


function AbilityUsageThink()
	
	if #abilities == 0 then 
		abilities[1] = bot:GetAbilityByName("skeleton_king_hellfire_blast");     -- Q
		abilities[2] = bot:GetAbilityByName("skeleton_king_bone_guard");         -- W (facet ability)
		abilities[3] = bot:GetAbilityByName("skeleton_king_mortal_strike");      -- E (passive)
		abilities[4] = bot:GetAbilityByName("skeleton_king_reincarnation");      -- R
	end
	
	-- CRITICAL: Check ghost form FIRST and override everything
	local isGhost = bot:HasModifier("modifier_skeleton_king_reincarnation_scepter_active");
	
	if isGhost then
		print("[WK] GHOST FORM ACTIVE - OVERRIDING ALL BEHAVIOR!");
		
		-- Find enemies
		local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
		if #enemies > 0 then
			-- Find closest enemy
			local closestEnemy = enemies[1];
			local closestDist = GetUnitToUnitDistance(bot, enemies[1]);
			
			for _, enemy in pairs(enemies) do
				local dist = GetUnitToUnitDistance(bot, enemy);
				if dist < closestDist then
					closestEnemy = enemy;
					closestDist = dist;
				end
			end
			
			-- PRIORITY: Use abilities first (they don't get cancelled)
			if mutils.CanBeCast(abilities[1]) then
				if mutils.CanCastOnNonMagicImmune(closestEnemy) and mutils.IsInRange(closestEnemy, bot, abilities[1]:GetCastRange()) then
					print("[WK] Ghost using Hellfire Blast!");
					bot:Action_UseAbilityOnEntity(abilities[1], closestEnemy);
					return;
				end
			end
			
			if mutils.CanBeCast(abilities[2]) then
				print("[WK] Ghost using Bone Guard!");
				bot:Action_UseAbility(abilities[2]);
				return;
			end
			
			-- ATTACK: Only issue attack command with timing control
			local currentTime = DotaTime();
			local timeSinceLastAttack = currentTime - lastGhostAttackTime;
			
			-- Only issue new attack commands every 0.5 seconds or if target changed
			if (timeSinceLastAttack > 0.5) or (lastGhostTarget ~= closestEnemy) then
				print("[WK] Ghost issuing attack command on: " .. closestEnemy:GetUnitName());
				bot:Action_AttackUnit(closestEnemy, false);
				lastGhostAttackTime = currentTime;
				lastGhostTarget = closestEnemy;
			else
				-- Don't spam commands, just let the attack execute
				-- Do nothing here, let the previous attack command complete
			end
			
		else
			-- No enemies nearby, find something else to attack
			local nearbyCreeps = bot:GetNearbyCreeps(1600, true);
			if #nearbyCreeps > 0 then
				local currentTime = DotaTime();
				if (currentTime - lastGhostAttackTime > 0.5) or (lastGhostTarget ~= nearbyCreeps[1]) then
					print("[WK] Ghost attacking creeps!");
					bot:Action_AttackUnit(nearbyCreeps[1], false);
					lastGhostAttackTime = currentTime;
					lastGhostTarget = nearbyCreeps[1];
				end
			end
		end
		return; -- Exit completely when in ghost form
	end
	-- Normal behavior when not ghost
	if mutils.CantUseAbility(bot) then return end
	
	castQDesire, targetQ = ConsiderQ();
	castWDesire = ConsiderW();
	castEDesire = ConsiderE();
	castRDesire = ConsiderR();
	
	if castRDesire > 0 then
		bot:Action_UseAbilityOnEntity(abilities[4], bot);
		return
	end
	
	if castQDesire > 0 then
		bot:Action_UseAbilityOnEntity(abilities[1], targetQ);
		return
	end

	if castWDesire > 0 then
		bot:Action_UseAbility(abilities[2]);
		return
	end

	if castEDesire > 0 then
		bot:Action_UseAbility(abilities[3]);
		return
	end
end

function ConsiderQ()
	if not mutils.CanBeCast(abilities[1]) then
		return BOT_ACTION_DESIRE_NONE, nil;
	end
	
	local nCastRange = mutils.GetProperCastRange(false, bot, abilities[1]:GetCastRange());
	local nCastPoint = abilities[1]:GetCastPoint();
	local manaCost  = abilities[1]:GetManaCost();
	local manaCost2  = abilities[4]:GetManaCost();
	
	if abilities[4]:IsTrained() and abilities[4]:IsFullyCastable() then
		if bot:GetMana() - manaCost <= manaCost2 + 50 then
			return BOT_ACTION_DESIRE_NONE, nil;
		end
	end
	
	-- INTERRUPT: Channeling enemies (highest priority)
	if DotaTime() > checkChanneling + 0.5 then
		local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( nCastRange, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs(tableNearbyEnemyHeroes)
		do
			if mutils.CanCastOnNonMagicImmune(npcEnemy) and  mutils.SafeIsChanneling(npcEnemy) then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy;
			end
		end
		checkChanneling = DotaTime();
	end
	
	-- RETREAT: Use when retreating and being damaged
	if mutils.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local target = mutils.GetVulnerableWeakestUnit(true, true, nCastRange, bot);
		if target ~= nil then
			return BOT_ACTION_DESIRE_HIGH, target;
		end
	end
	
	-- AGGRESSIVE: Going on someone
	if mutils.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget();
		if mutils.IsValidTarget(target) and mutils.CanCastOnNonMagicImmune(target) and mutils.IsInRange(target, bot, nCastRange) then
			return BOT_ACTION_DESIRE_HIGH, target;
		end
	end
	
	-- TEAMFIGHT: Use on low HP priority targets
	if mutils.IsInTeamFight(bot, 1200) then
		local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
		for _, enemy in pairs(enemies) do
			if mutils.CanCastOnNonMagicImmune(enemy) and 
			   (enemy:GetHealth() / enemy:GetMaxHealth()) < 0.4 then
				return BOT_ACTION_DESIRE_HIGH, enemy;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, nil;
end

function ConsiderW()
    if not mutils.CanBeCast(abilities[2]) then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local manaCost = abilities[2]:GetManaCost();
    
    -- Don't waste mana if we need it for ultimate
    if abilities[4]:IsTrained() and abilities[4]:IsFullyCastable() then
        if bot:GetMana() - manaCost <= abilities[4]:GetManaCost() + 50 then
            return BOT_ACTION_DESIRE_NONE;
        end
    end
    
    -- TOWER PUSH/DEFEND: Use when attacking or defending towers
    if (bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or 
        bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or 
        bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT or
        bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP or
        bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID or
        bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT) then
        return BOT_ACTION_DESIRE_HIGH;
    end
    
    -- TEAMFIGHT: Use when in team fights
    if mutils.IsInTeamFight(bot, 1200) then
        local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        if #enemies >= 2 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end
    
    -- AGGRESSIVE: Use when going on someone for extra damage
    if mutils.IsGoingOnSomeone(bot) then
        local target = bot:GetTarget();
        if mutils.IsValidTarget(target) then
            return BOT_ACTION_DESIRE_MODERATE;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE;
end

function ConsiderE()
	-- Note: Mortal Strike is primarily passive, but checking if there's an active component
	if not mutils.CanBeCast(abilities[3]) then
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local nCastRange = 4*bot:GetAttackRange();
	local manaCost = abilities[3]:GetManaCost();
	local manaCost2  = abilities[4]:GetManaCost();
	
	if abilities[4]:IsTrained() and abilities[4]:IsFullyCastable() then
		if bot:GetMana() - manaCost <= manaCost2 + 50 then
			return BOT_ACTION_DESIRE_NONE;
		end
	end
	
	-- ROSHAN: Use on Roshan
	if ( bot:GetActiveMode() == BOT_MODE_ROSHAN  ) then
		local npcTarget = mutils.SafeGetAttackTarget(bot);
		if ( mutils.IsRoshan(npcTarget) and mutils.IsInRange(npcTarget, bot, nCastRange) ) then
			return BOT_ACTION_DESIRE_LOW;
		end
	end

	-- TEAMFIGHT: Use in team fights
	if mutils.IsInTeamFight(bot, 1200) then
		local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
		if #enemies >= 2 then
			local allies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE);
			if #allies >= 2 then
				return BOT_ACTION_DESIRE_LOW;
			end
		end
	end
	
	-- AGGRESSIVE: If we're going after someone
	if mutils.IsGoingOnSomeone(bot) then
		local npcTarget = bot:GetTarget();
		if mutils.IsValidTarget(npcTarget) then
			local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
			if mutils.IsInRange(npcTarget, bot, nCastRange + #enemies * 150 ) then 
				return BOT_ACTION_DESIRE_HIGH;
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE;
end		

function ConsiderR()
    if not mutils.CanBeCast(abilities[4]) then
        return BOT_ACTION_DESIRE_NONE;
    end
    
    local healthPercent = bot:GetHealth() / bot:GetMaxHealth();
    local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
    
    -- Only use if we're about to die and enemies are nearby
    if healthPercent <= 0.25 and #enemies >= 1 then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end
    
    -- Emergency use if very low HP and being attacked
    if healthPercent <= 0.15 and bot:WasRecentlyDamagedByAnyHero(2.0) then
        return BOT_ACTION_DESIRE_VERYHIGH;
    end
    
    return BOT_ACTION_DESIRE_NONE;
end


