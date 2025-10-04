void Main() {}

void Render() {
    array<SessionPlayerData@> players = GetSessionPlayers();
    RenderOverlay(players);
}