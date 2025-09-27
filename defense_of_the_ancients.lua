local utils = require(GetScriptDirectory() ..  "/util")
local baseUnderAttackStatus = false


local function IsBaseUnderAttack()
    if GetEnemyAtTheGates() ~= false then
        --do action only every 30s because bots will be stuck trying to repeat the action
       -- if DotaTime() >= lastAttackCheck + 5 then
            local closestT2Tower = GetTower(GetTeam(),GetClosestT2TowerLocation(GetEnemyAtTheGates()));
            if closestT2Tower == nil or not closestT2Tower:IsAlive() then
                return true;
                -- The tier 2 tower is not alive          
               -- print("defend at position: " .. tostring(GetEnemyAtTheGates()) .. "private " .. tostring(bot:GetUnitName()).. "my loc is : ".. tostring(bot:GetLocation()) .."and mode is: ".. tostring(bot:GetActiveMode()).."add desire: "..tostring(bot:GetActiveModeDesire()));           
               -- bot:Action_AttackMove(GetEnemyAtTheGates());
            else
                return false;
            end 
           -- lastAttackCheck = DotaTime();                 
        --end
    end
    return false;
end



function GetEnemyAtTheGates()
    --add ceck whats closer to ancient and target that... 
    local ancientLoc  = GetAncient(GetTeam()):GetLocation();
    nRadius= 3000;
    local enemyLocation = nil;
    for i,id in pairs(GetTeamPlayers(GetOpposingTeam())) do
        if IsHeroAlive(id) then
            local info = GetHeroLastSeenInfo(id);
            if info ~= nil then
                local dInfo = info[1];
                if dInfo ~= nil and utils.GetDistance(ancientLoc, dInfo.location) <= nRadius and dInfo.time_since_seen < 1.0 then
                    --print("HERO ENEMY");
                    enemyLocation = dInfo.location;
                end
            end
        end
    end

     -- Check for enemy creeps
    local enemyCreeps = GetUnitList(UNIT_LIST_ENEMY_CREEPS)
    for _, creep in pairs(enemyCreeps) do
        if creep:GetLocation() ~=nil then           
            if utils.GetDistance(ancientLoc, creep:GetLocation()) <= nRadius then
                --print("CREEp ENEMY");
                enemyLocation = creep:GetLocation()
            end
        end
    end

    if enemyLocation then
        --local lane = GetLaneFrontLocation(enemyLocation);
        --print("Enemy found on " .. lane .. " lane.");
        return enemyLocation;
    else
        --print("No enemy found.");
        return false;
    end
end

function GetClosestT2TowerLocation(location)
    local midLane = GetLaneFrontLocation(GetTeam(), LANE_MID, 0);
    local topLane = GetLaneFrontLocation(GetTeam(), LANE_TOP, 0);
    local botLane = GetLaneFrontLocation(GetTeam(), LANE_BOT, 0)
    local distToMid = (midLane - location):Length2D();
    local distToTop = (topLane - location):Length2D();
    local distToBot = (botLane - location):Length2D();
    if distToMid < distToTop and distToMid < distToBot then
        return TOWER_MID_2;
    elseif distToTop < distToMid and distToTop < distToBot then
        return TOWER_TOP_2;
    else
        return TOWER_BOT_2;
    end
end


return {
    IsBaseUnderAttack = IsBaseUnderAttack
}