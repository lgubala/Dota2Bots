local minionutils = dofile( GetScriptDirectory().."/NewMinionUtil" )
local bot = GetBot();

function  MinionThink(  hMinionUnit ) 
	if hMinionUnit:IsAlive() then		
		local name = bot:GetUnitName();
		--print("Bot NAME "..tostring(name) .. "unit " .. tostring(hMinionUnit:GetUnitName()) .. "ilu ".. tostring(hMinionUnit:IsIllusion()));
		minionutils.MinionThink(bot, hMinionUnit);		
	end		
end

