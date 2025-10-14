void GetSessionPlayers() {
    // Get race data
    auto raceData = MLFeed::GetRaceData_V4();

    // Early exit and cleanup when there is no race or players
    if (raceData is null || raceData.Map.Length == 0 || raceData.SortedPlayers_TimeAttack is null || raceData.SortedPlayers_TimeAttack.Length == 0) {
        gSessionPlayers.DeleteAll();
        gPbRequestQueue.Resize(0);
        gPbWorkerRunning = false;
        mapId = "";
        return;
    }

    auto players = raceData.SortedPlayers_TimeAttack;

    dictionary activePlayers;
    string pbQueryFragment;

    for (uint i = 0; i < players.Length; i++) {
        auto@ p = cast<MLFeed::PlayerCpInfo_V4>(players[i]);
        if (p is null) continue;

        string userId = p.WebServicesUserId;
        if (userId.Length == 0) continue;

        activePlayers.Set(userId, true);

        SessionPlayerData@ d;
        // Checks if we have cached data
        if (!gSessionPlayers.Get(userId, @d)) {
            AppendAccountIdToQuery(userId, pbQueryFragment);

            // Initialize with unknown PB (-1) and lastLap 0
            @d = SessionPlayerData();
            d.name = p.Name;

            gSessionPlayers.Set(userId, d);
        }

        // Keep name fresh only if it changed
        if (d.name != p.Name) {
            d.name = p.Name;
        }
        // Always update bestLap (cheap)
        d.bestLap = p.BestTime;

        if ((p.BestTime > 0 && p.BestTime < d.personalBest) || d.personalBest == -1) {
            d.personalBest = p.BestTime;
        }
        if (p.IsFinished && p.LastCpTime != d.lastLap) {
            d.lastLap = p.LastCpTime;
        }
    }

    // Remove players we no longer see in the session
    if (gSessionPlayers.GetSize() > 0) {
        CleanupInactivePlayers(activePlayers);
    }

    // If we queued any PB lookups, trigger the fetch
    if (pbQueryFragment.Length > 0) {
        trace("Making api call, fetching PBs for: " + pbQueryFragment);
        EnqueuePbRequest(raceData.Map + "|" + pbQueryFragment);
    }
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
void CleanupInactivePlayers(const dictionary &in activePlayers) {
    array<string> cachedIds = gSessionPlayers.GetKeys();
    for (uint i = 0; i < cachedIds.Length; i++) {
        if (!activePlayers.Exists(cachedIds[i])) {
            gSessionPlayers.Delete(cachedIds[i]);
        }
    }
}
