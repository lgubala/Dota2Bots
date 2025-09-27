if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion()  then
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


local abilityQ = nil;
local abilityW = nil;
local abilityE = nil;
local abilityR = nil;


local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;

local lastCheck = -90;

local npcBot = nil;

function AbilityUsageThink()

    if npcBot == nil then npcBot = GetBot(); end
    
    -- Check if we're already using an ability
    if mutils.CanNotUseAbility(npcBot) then return end

    if abilityQ == nil then abilityQ = npcBot:GetAbilityByName( "abaddon_death_coil" ) end
    if abilityW == nil then abilityW = npcBot:GetAbilityByName( "abaddon_aphotic_shield" ) end
    if abilityE == nil then abilityE = npcBot:GetAbilityByName( "abaddon_frostmourne" ) end
    if abilityR == nil then abilityR = npcBot:GetAbilityByName( "abaddon_borrowed_time" ) end

    -- Consider using each ability
    castQDesire, castQTarget = ConsiderDeathCoil();
    castWDesire, castWTarget = ConsiderAphoticShield();
    castRDesire = ConsiderBorrowedTime();
   
    if ( castRDesire > 0 ) 
    then
        npcBot:Action_UseAbility( abilityR );
        return;
    end

    if ( castQDesire > 0 ) 
    then
        npcBot:Action_UseAbilityOnEntity( abilityQ , castQTarget);
        return;
    end

    if ( castEDesire > 0 ) 
    then
        npcBot:Action_UseAbility( abilityE );
        return;
    end
    
    if ( castWDesire > 0 ) 
    then
        npcBot:Action_UseAbilityOnEntity( abilityW, castWTarget );
        return;
    end

end

function ConsiderDeathCoil()
    -- Make sure it's castable
    if  mutils.CanBeCast(abilityQ) == false then
        return BOT_ACTION_DESIRE_NONE, 0;
    end
    local nCastRange = mutils.GetProperCastRange(false, npcBot, abilityQ:GetCastRange());
    
    -- If we're going after someone
    if mutils.IsGoingOnSomeone(npcBot)
    then
        local npcTarget = npcBot:GetTarget();
        if  mutils.IsValidTarget(npcTarget) and mutils.CanCastOnNonMagicImmune(npcTarget) and mutils.IsInRange(npcTarget, npcBot, nCastRange)
        then
           -- ability_item_usage_generic.DoShitTalk();
            return BOT_ACTION_DESIRE_MODERATE, npcTarget;
        end
    end
    
    return BOT_ACTION_DESIRE_NONE, 0;
    -- body
end

function ConsiderAphoticShield()
     -- Make sure it's castable
     if  mutils.CanBeCast(abilityW) == false then
        return BOT_ACTION_DESIRE_NONE, 0;
    end

    local nCastRange = mutils.GetProperCastRange(false, npcBot, abilityW:GetCastRange());
    local nCastPoint = abilityW:GetCastPoint();
    local manaCost   = abilityW:GetManaCost();

    if mutils.IsRetreating(npcBot) 
    then
        local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
        for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
        do
            if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) ) 
            then
                return BOT_ACTION_DESIRE_HIGH, npcBot;
            end
        end
    end

    if mutils.IsInTeamFight(npcBot, 1200)
    then  
        local tableNearbyAllyHeroes = npcBot:GetNearbyHeroes( nCastRange, false, BOT_MODE_NONE );
        for _,npcAlly in pairs( tableNearbyAllyHeroes )
        do
            if (  mutils.CanCastOnNonMagicImmune(npcAlly) and( npcAlly:GetHealth() / npcAlly:GetMaxHealth() ) < 0.5 ) 
            then
                return BOT_ACTION_DESIRE_MODERATE, npcAlly;
            end
        end
    end    
   
    return BOT_ACTION_DESIRE_NONE, 0;
    -- body
end

function ConsiderBorrowedTime()
      -- Make sure it's castable
    if ( not abilityQ:IsFullyCastable() ) then 
        return BOT_ACTION_DESIRE_NONE, 0;
    end

    if mutils.IsRetreating(npcBot)
    then
        local enemies = npcBot:GetNearbyHeroes(1200, true, BOT_MODE_NONE);
        if #enemies > 0 and npcBot:GetHealth() <= 500 then
            return BOT_ACTION_DESIRE_HIGH;
        end
    end  

    return BOT_ACTION_DESIRE_NONE;
end