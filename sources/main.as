void Main() {
    NadeoServices::AddAudience("NadeoServices");
}

void Render() {
    array<SessionPlayerData@> players = GetSessionPlayers();
    RenderOverlay(players);
}