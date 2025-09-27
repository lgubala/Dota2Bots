if GetBot():IsInvulnerable() or not GetBot():IsHero() or not string.find(GetBot():GetUnitName(), "hero") or GetBot():IsIllusion() then
	return;
end

local bot = GetBot();

function ModeDesire()
	-- Force attack mode when in ghost form
	if bot:HasModifier("modifier_skeleton_king_reincarnation_scepter_active") then
		print("[WK] Ghost form - forcing ATTACK mode");
		return BOT_ACTION_DESIRE_ABSOLUTE;
	end
	
	-- Normal behavior
	return BOT_ACTION_DESIRE_NONE;
end