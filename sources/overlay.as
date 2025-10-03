void RenderOverlay(array<SessionPlayerData@>@ players) {
    if (players.Length == 0) return; // Skip rendering if no data

    bool windowOpen = UI::Begin("Session Lap Tracker");
    
    if (windowOpen) {
        UI::Columns(4, "pbcols");
        UI::Text("Name"); UI::NextColumn();
        UI::Text("Personal Best"); UI::NextColumn();
        UI::Text("Best Lap"); UI::NextColumn();
        UI::Text("Last Lap"); UI::NextColumn();
        UI::Separator();

        for (uint i = 0; i < players.Length; i++) {
            auto p = players[i];
            UI::Text(p.name); UI::NextColumn();
            UI::Text(p.personalBest > 0 ? Time::Format(p.personalBest) : "-"); UI::NextColumn();
            UI::Text(p.bestLap > 0 ? Time::Format(p.bestLap) : "-"); UI::NextColumn();
            UI::Text(p.lastLap > 0 ? Time::Format(p.lastLap) : "-"); UI::NextColumn();
        }
    }

    UI::End();
}