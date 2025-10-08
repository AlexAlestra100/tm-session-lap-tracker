array<SessionPlayerData@> GetSessionPlayers() {
    array<SessionPlayerData@> results;

    // Get race data
    auto raceData = MLFeed::GetRaceData_V4();

    // Early exit and cleanup when there is no race or players
    if (raceData is null || raceData.Map.Length == 0 || raceData.SortedPlayers_TimeAttack is null || raceData.SortedPlayers_TimeAttack.Length == 0) {
        gPlayerLapData.DeleteAll();
        gPbRequestQueue.Resize(0);
        gPbWorkerRunning = false;
        mapId = "";
        return results;
    }

    auto players = raceData.SortedPlayers_TimeAttack;
    results.Reserve(players.Length);

    dictionary activePlayers;
    string pbQueryFragment;

    for (uint i = 0; i < players.Length; i++) {
        auto@ p = cast<MLFeed::PlayerCpInfo_V4>(players[i]);
        if (p is null) continue;

        string userId = p.WebServicesUserId;
        if (userId.Length == 0) continue;

        activePlayers.Set(userId, true);

        auto d = SessionPlayerData();
        d.name = p.Name;
        d.bestLap = p.BestTime;

        int64 packedValue;

        // Checks if we have cached data
        if (!gPlayerLapData.Get(userId, packedValue)) {
            AppendAccountIdToQuery(userId, pbQueryFragment);
            // Initialize with unknown PB (-1) and lastLap 0
            packedValue = (int64(-1) << 32) | int64(0);
            gPlayerLapData.Set(userId, packedValue);
        } else {
            int personalBest = int(packedValue >> 32);
            int lastLap = int(packedValue & 0xFFFFFFFF);

            // Only update if we already have a PB and this lap is faster
            if (personalBest >= 0 && p.BestTime > 0 && p.BestTime < personalBest) {
                personalBest = p.BestTime;
            }
            if (p.IsFinished && p.LastCpTime != lastLap) {
                lastLap = p.LastCpTime;
            }

            // Additional check to avoid unnecessary writes
            int64 newPacked = (int64(personalBest) << 32) | int64(lastLap);
            if (newPacked != packedValue) {
                gPlayerLapData.Set(userId, newPacked);
                packedValue = newPacked;
            }
        }

        d.personalBest = int(packedValue >> 32);
        d.lastLap = int(packedValue & 0xFFFFFFFF);
        results.InsertLast(d);
    }

    // Remove players we no longer see in the session
    if (gPlayerLapData.GetSize() > 0) {
        CleanupInactivePlayers(activePlayers);
    }

    // If we queued any PB lookups, trigger the fetch
    if (pbQueryFragment.Length > 0) {
        trace("Making api call");
        EnqueuePbRequest(raceData.Map + "|" + pbQueryFragment);
    }

    return results;
}

// Helper to append an accountId to the query string
void AppendAccountIdToQuery(string &in userId, string &out pbQueryFragment) {
    if (pbQueryFragment.Length == 0) {
        // start with the first accountId
        pbQueryFragment = userId;
    } else {
        // append additional accountIds with commas
        pbQueryFragment += "," + userId;
    }
}

// Remove players from the cache that are no longer active in the session
void CleanupInactivePlayers(const dictionary&in activePlayers) {
    array<string> cachedIds = gPlayerLapData.GetKeys();
    for (uint i = 0; i < cachedIds.Length; i++) {
        if (!activePlayers.Exists(cachedIds[i])) {
            gPlayerLapData.Delete(cachedIds[i]);
        }
    }
}
