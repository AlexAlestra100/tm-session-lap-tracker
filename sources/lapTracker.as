array<SessionPlayerData@> GetSessionPlayers() {
    array<SessionPlayerData@> results;

    auto raceData = MLFeed::GetRaceData_V4();
    if (raceData is null || raceData.Map == "" || raceData.SortedPlayers_TimeAttack is null) {
        gInSessionClubMembers.DeleteAll();
        return results;
    }

    dictionary activeSet;
    array<string> newIds;

    auto players = raceData.SortedPlayers_TimeAttack;
    for (uint i = 0; i < players.Length; i++) {
        auto@ p = cast<MLFeed::PlayerCpInfo_V4>(players[i]);
        if (p is null) continue;

        InSessionClubMember@ m;
        if (!gInSessionClubMembers.Get(p.WebServicesUserId, @m)) {
            continue;
        }

        activeSet[p.WebServicesUserId] = true;

        // Update live fields
        m.bestLap = p.BestTime;

        // If we haven’t fetched PB yet, queue it
        if (m.personalBest == 0) {
            newIds.InsertLast(p.WebServicesUserId);
        }

        auto d = SessionPlayerData();
        d.name = p.Name != "" ? p.Name : m.name;
        d.bestLap = m.bestLap;
        d.personalBest = m.personalBest;
        d.lastLap = m.lastLap;
        results.InsertLast(d);
    }

    if (newIds.Length > 0) {
        auto@ ctx = FetchContext(raceData.Map, newIds);
        startnew(CoroutineFuncUserdata(FetchAndCachePBsEntry), ctx);
    }

    CleanupInactivePlayers(activeSet);
    return results;
}


// Remove cached data for players no longer in the session
void CleanupInactivePlayers(const dictionary& activeSet) {
    array<string> cached = gInSessionClubMembers.GetKeys();
    for (uint i = 0; i < cached.Length; i++) {
        if (!activeSet.Exists(cached[i])) {
            gInSessionClubMembers.Delete(cached[i]);
        }
    }
}
