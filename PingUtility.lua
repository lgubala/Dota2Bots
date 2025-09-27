local PingUtility = {};

-- Private variables to track ping state
local lastProcessedPingTime = {};
local retreatFromPing = false;
local retreatPingLocation = nil;
local retreatPingTime = 0;

-- Check for X-pings from human players and determine if bot should retreat
function PingUtility.CheckForRetreatPings(bot)
    -- Only check during active game
    if GetGameState() ~= GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
        return false;
    end
    
    -- Check pings from human players
    local teamPlayers = GetTeamPlayers(GetTeam());
    for i, playerID in pairs(teamPlayers) do
        if not IsPlayerBot(playerID) then -- Only check human players
            local member = GetTeamMember(i);
            if member ~= nil then
                local ping = member:GetMostRecentPing();
                if ping ~= nil then
                    -- Only process if this is a new ping we haven't seen before
                    if lastProcessedPingTime[playerID] == nil or ping.time > lastProcessedPingTime[playerID] then
                        lastProcessedPingTime[playerID] = ping.time;
                        
                        if ping.normal_ping == false then -- X-ping detected
                            -- Check if X-ping is near this bot (within 1200 units)
                            local distanceToBot = GetUnitToLocationDistance(bot, ping.location);
                            
                            if distanceToBot <= 1200 then
                                retreatFromPing = true;
                                retreatPingLocation = ping.location;
                                retreatPingTime = DotaTime();
                                
                                bot:ActionImmediate_Chat("RETREATING due to X-ping!", true);
                                print("[PING] Bot " .. bot:GetUnitName() .. " retreating due to X-ping at distance " .. tostring(distanceToBot));
                                return true;
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Clear retreat command after 5 seconds
    if retreatFromPing and DotaTime() - retreatPingTime > 5.0 then
        retreatFromPing = false;
        retreatPingLocation = nil;
        print("[PING] Bot " .. bot:GetUnitName() .. " retreat timeout - resuming normal behavior");
    end
    
    return retreatFromPing;
end

-- Get the location to retreat to (away from ping location)
function PingUtility.GetRetreatLocation(bot)
    if not retreatFromPing or retreatPingLocation == nil then
        return nil;
    end
    
    -- Calculate retreat direction (away from ping location towards team base)
    local teamBase = GetAncient(GetTeam()):GetLocation();
    local directionToBase = (teamBase - retreatPingLocation):Normalized();
    local retreatLocation = retreatPingLocation + directionToBase * 1500; -- Move 1500 units away
    
    return retreatLocation;
end

-- Check if bot is currently in retreat mode due to ping
function PingUtility.IsRetreatingFromPing()
    return retreatFromPing;
end

-- Force clear retreat state (for testing or emergency)
function PingUtility.ClearRetreatState()
    retreatFromPing = false;
    retreatPingLocation = nil;
    retreatPingTime = 0;
end

return PingUtility;