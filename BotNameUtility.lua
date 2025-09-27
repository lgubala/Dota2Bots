local U = {}

local dota2team = {

	[1] = {
		['name'] = "Team Pejko";
		['alias'] = "PejK";
		['players'] = {
			'pejko3.0',
			'Jesus',
			'Satan',
			'Ganjalf2.0',
			'Cvok1.5'
		};
		['sponsorship'] = 'Telekom';
	},
	[2] = {
		['name'] = "Kudus Esports";
		['alias'] = "KUDUS";
		['players'] = {
			'Kudus',
			'Melisko',
			'RAijin',
			'Marek2.0',
			'Filipko'
		};
		['sponsorship'] = 'WOODCOTE';
	},
	[3] = {
		['name'] = "Parlament Gaming";
		['alias'] = "KKTI";
		['players'] = {
			'Fico',
			'Harabin',
			'Matovic',
			'Sulik',
			'Kotleba'
		};
		['sponsorship'] = 'McDonald';
	}	
	
}

local sponsorship = {"McDonald", "WOODCOTE", "Telekom"};

function U.GetDota2Team()
	local bot_names = {};
	local rand = RandomInt(1, #dota2team); 
	local srand = RandomInt(1, #sponsorship); 
	if GetTeam() == TEAM_RADIANT then
		while rand%2 ~= 0 do
			rand = RandomInt(1, #dota2team); 
		end
	else
		while rand%2 ~= 1 do
			rand = RandomInt(1, #dota2team); 
		end
	end
	local team = dota2team[rand];
	for _,player in pairs(team.players) do
		if sponsorship[srand] == "" then
			table.insert(bot_names, team.alias.."."..player);
		else
			table.insert(bot_names, team.alias.."."..player.."."..sponsorship[srand]);
		end
	end
	return bot_names;
end

return U