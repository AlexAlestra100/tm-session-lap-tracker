void Main() {
    // Request login for the services we need
    NadeoServices::AddAudience("NadeoLiveServices");
    trace("[Init] Requested Live audience");

    // Kick off our fetch coroutine once Live is ready
    startnew(FetchUserClubsCoroutine);
}

void Render() {
    //auto players = GetSessionPlayers();
    //RenderOverlay(players);
}