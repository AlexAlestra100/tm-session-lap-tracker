void RenderOverlay() {
    // Skip rendering if no data
    if (gSessionPlayers.GetSize() == 0) return;

    bool windowOpen = UI::Begin("Session Lap Tracker");
    
    if (windowOpen) {
        UI::Columns(4, "pbcols");
        UI::Text("Name"); UI::NextColumn();
        UI::Text("Personal Best"); UI::NextColumn();
        UI::Text("Best Lap"); UI::NextColumn();
        UI::Text("Last Lap"); UI::NextColumn();
        UI::Separator();

        // Iterate over all players in the global dictionary
        array<string> keys = gSessionPlayers.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            SessionPlayerData@ p;
            if (!gSessionPlayers.Get(keys[i], @p) || p is null) continue;

            UI::Text(p.name); UI::NextColumn();
            UI::Text(p.personalBest > 0 ? Time::Format(p.personalBest) : "-"); UI::NextColumn();
            UI::Text(p.bestLap > 0 ? Time::Format(p.bestLap) : "-"); UI::NextColumn();
            UI::Text(p.lastLap > 0 ? Time::Format(p.lastLap) : "-"); UI::NextColumn();
        }
    }

    UI::End();
}
