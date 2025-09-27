local KillTracker = {};

-- Track last known kill counts to detect new kills
local lastKillCount = {};
local lastDeathCount = {};
local initialized = false;

-- Initialize kill tracking for all players
local function InitializeKillTracking()
    if initialized then return end
    
    -- Initialize for all players (both teams) - PlayerIDs 0-9
    for i = 0, 9 do
        lastKillCount[i] = GetHeroKills(i);
        lastDeathCount[i] = GetHeroDeaths(i);
    end
    initialized = true;
end


-- Get hero name for trash talk
local function GetHeroName(playerID)
    local heroName = GetSelectedHeroName(playerID);
    if heroName ~= nil and heroName ~= "" then
        -- Clean up hero name (remove "npc_dota_hero_" prefix)
        local cleanName = string.gsub(heroName, "npc_dota_hero_", "");
        cleanName = string.gsub(cleanName, "_", " ");
        -- Capitalize first letter
        cleanName = string.upper(string.sub(cleanName, 1, 1)) .. string.sub(cleanName, 2);
        return cleanName;
    end
    return "Unknown";
end

-- Generate random kill trash talk message
local function GetKillMessage(victimName)
    local killMessages = {
        "Sadni si, " .. victimName .. ", tu velím iba ja!",
        victimName .. ", easy frag, choď uninstall.",
        "Owned " .. victimName .. ", ďalší report do zbierky.",
        "Ďakujem za goldy, " .. victimName .. ". Free farm pokračuje.",
        "Aj creep wave kladie väčší odpor než ty, " .. victimName .. ".",
        victimName .. " padol jak hnilá hruška, R.I.P. " .. victimName .. ".",
        "Back to lobby, " .. victimName .. ", a tam zostaň.",
        "RIP " .. victimName .. ", uninstall kým máš čas.",
        "Outplayed, " .. victimName .. ", a to bez námahy.",
        "Keby bola DotA test, " .. victimName .. " by prepadol.",
        "Najväčší feeding award ide pre " .. victimName .. "! Potlesk prosím.",
        "Boti > " .. victimName .. ", smutné ale pravdivé.",
        "Skill diff? Nie, to je " .. victimName .. " diff.",
        "Vieš čo je skill, " .. victimName .. "? Lebo ja áno.",
        "MMR mínus 30 incoming, " .. victimName .. ".",
        "Easy clap, " .. victimName .. ", skill gap jak prasa.",
        victimName .. " = neutrál creep s menovkou " .. victimName .. ".",
        "Vlastním ťa, " .. victimName .. ", a vždy budem vlastniť.",
        "Feedíš jak profík, " .. victimName .. ". Pokračuj.",
        "Bot 1, " .. victimName .. " 0. Game over.",
        "Čistý outplay, " .. victimName .. ". Nula šanca pre teba.",
        victimName .. ", tvoje kliky sú horšie než moje AI skripty.",
        "GG, " .. victimName .. ". Get used to losing.",
        "Vieš kto je carry? Ja. Vieš kto je feeder? Ty, " .. victimName .. ".",
        "Neviem či hráš Dotu, " .. victimName .. ", alebo Minesweeper.",
        "Padáš znova, " .. victimName .. ", klasika.",
        "Tvoja existencia = free gold, ďakujem " .. victimName .. ".",
        "Som bot, a aj tak som lepší než ty, " .. victimName .. ".",
        "Ak by som mal ruky, facepalmuem nad tebou, " .. victimName .. ".",
        "Bolo to moc rýchle, " .. victimName .. ", ani som sa nespotil.",
        "Keby si bol item, " .. victimName .. ", si Quelling Blade – lacný a bez významu.",
        victimName .. ", tvoje kliky = content pre TikTok.",
        "Nepotrebujem ani ult, aby si spadol, " .. victimName .. ".",
        "Vieš čo je smutné? Že bot ti robí highlight, " .. victimName .. ".",
        "Ak si mal plán, " .. victimName .. ", tak totálne zlyhal.",
        "Máš veľké ego, " .. victimName .. ", ale malý impact.",
        "Padol si, " .. victimName .. ", a padneš zas.",
        "Aspoň skúšaj, " .. victimName .. ", toto je čistá hanba.",
        victimName .. ", pamätaj si tento moment – bot > ty.",
        "Outskilovaný botom, " .. victimName .. ", gratulujem.",
        "Vieš čo je diff? " .. victimName .. " diff. Koniec debaty.",
        "Padáš rýchlejšie ako FPS na tvojom PC, " .. victimName .. ".",
        "Tvoj nick mal byť FreeKill, " .. victimName .. "."
    };

    return killMessages[RandomInt(1, #killMessages)];
end

-- Generate random death trash talk message
local function GetDeathMessage(killerName)
    local deathMessages = {
        "Šťastie nič viac, " .. killerName .. ". Enjoy, lebo druhýkrát to nebude.",
        "Nice kill, " .. killerName .. ", ale aj tak si slabý.",
        killerName .. " len raz si ma dostal, užívaj si replay.",
        "Respawnujem a idem po teba, " .. killerName .. ".",
        "GG pre teba, " .. killerName .. ", ale len tento moment.",
        killerName .. ", náhoda, čistá náhoda.",
        "Keby môj team nebol trash, " .. killerName .. ", si nič.",
        killerName .. " nezachráni ťa ani ďalších 10 killov.",
        "Aspoň raz si sa blysol, " .. killerName .. ", ale to je všetko.",
        "Zabil si bota, gratulujem " .. killerName .. ", medailu ti netreba.",
        "MMR si týmto nenahypeš, " .. killerName .. ", sry not sry.",
        "Respawn = koniec pre teba, " .. killerName .. ".",
        killerName .. ", smrdíš aj s týmto killom, fakt.",
        "Neznamená to, že si dobrý, " .. killerName .. ". Vôbec.",
        "Bot sa dal zabiť, wow, veľký výkon " .. killerName .. ".",
        "Aj creep by to dokázal, " .. killerName .. ".",
        "Nebudem ti tlieskať, " .. killerName .. ".",
        "Luckshot, " .. killerName .. ", nič viac.",
        "Respawnujem, " .. killerName .. ", a potom ty padáš.",
        killerName .. " si king jednej sekundy, potom si trash znova.",
        "Ten kill ťa nezachráni, " .. killerName .. ".",
        "Počkaj si, " .. killerName .. ", moja pomsta príde.",
        "Aj random klik to by zvládol, " .. killerName .. ".",
        "Noob kill pre noob hráča, " .. killerName .. ".",
        "Len feeding bonus pre tvoje ego, " .. killerName .. ".",
        "Skill? Skôr náhoda, " .. killerName .. ".",
        "Respawnujem a vráti sa ti to, " .. killerName .. ".",
        killerName .. " si len štatistika v mojej hlave.",
        "Aj tower by to dokázal, " .. killerName .. ".",
        "Gratulujem, " .. killerName .. ", zabil si bota. Big deal.",
        "To nebola tvoja skill, " .. killerName .. ", to bola moja smola.",
        "Keby som hral vážne, " .. killerName .. ", padáš ty.",
        "Len si ver, " .. killerName .. ", aj tak padneš.",
        killerName .. " fragol bota. Wooow, standing ovation.",
        "Aj keby si mal Aghanim, aj tak si trash, " .. killerName .. ".",
        "Ten kill nič neznamená, " .. killerName .. ".",
        "Neplač keď sa ti to vráti, " .. killerName .. ".",
        "Aspoň chvíľka radosti pre " .. killerName .. ".",
        "Nič moc, " .. killerName .. ", čakal som viac.",
        "Aj môj AI script plače, že prehral s " .. killerName .. ".",
        "GG pre teba, ale len tentokrát, " .. killerName .. ".",
        "Respawn → revenge, " .. killerName .. ".",
        "Raz si to dal, " .. killerName .. ", ale len raz."
    };

    return deathMessages[RandomInt(1, #deathMessages)];
end

-- Check for kills/deaths and generate trash talk
function KillTracker.CheckForKillsAndDeaths(bot)
    if not bot:IsHero() or bot:IsIllusion() then
        return;
    end
    
    InitializeKillTracking();
    
    local botPlayerID = bot:GetPlayerID();
    local currentKills = GetHeroKills(botPlayerID);
    local currentDeaths = GetHeroDeaths(botPlayerID);
    
    -- Check if bot got a new kill
    if lastKillCount[botPlayerID] ~= nil and currentKills > lastKillCount[botPlayerID] then
        -- Find who died recently (check all enemy players)
        local enemyTeam = GetOpposingTeam();
        local enemyPlayers = GetTeamPlayers(enemyTeam);
        
        for _, enemyID in pairs(enemyPlayers) do
            local enemyDeaths = GetHeroDeaths(enemyID);
            if lastDeathCount[enemyID] ~= nil and enemyDeaths > lastDeathCount[enemyID] then
                -- Check if it was a human player
                if not IsPlayerBot(enemyID) then
                    local victimName = GetHeroName(enemyID);
                    local message = GetKillMessage(victimName);
                    print("[KILL] Sending trash talk: " .. message);
                    bot:ActionImmediate_Chat(message, true);
                end
                lastDeathCount[enemyID] = enemyDeaths;
                break;
            end
        end
    end
    
    -- Check if bot died to a human player
    if lastDeathCount[botPlayerID] ~= nil and currentDeaths > lastDeathCount[botPlayerID] then
        -- Find who got a new kill (check all enemy players)
        local enemyTeam = GetOpposingTeam();
        local enemyPlayers = GetTeamPlayers(enemyTeam);
        
        for _, enemyID in pairs(enemyPlayers) do
            local enemyKills = GetHeroKills(enemyID);
            if lastKillCount[enemyID] ~= nil and enemyKills > lastKillCount[enemyID] then
                -- Check if it was a human player
                if not IsPlayerBot(enemyID) then
                    local killerName = GetHeroName(enemyID);
                    local message = GetDeathMessage(killerName);
                    print("[KILL] Sending death trash talk: " .. message);
                    bot:ActionImmediate_Chat(message, true);
                end
                lastKillCount[enemyID] = enemyKills;
                break;
            end
        end
    end
    
    -- Update our tracking
    lastKillCount[botPlayerID] = currentKills;
    lastDeathCount[botPlayerID] = currentDeaths;
end

return KillTracker;