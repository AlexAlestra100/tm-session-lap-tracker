// Global cache: for bestLap/lastLap per player
// Format: (bestLap << 32) | lastLap - packed into single 64-bit int
dictionary gPlayerLapData; // string -> int64

array<SessionPlayerData@> GetSessionPlayers() {
    array<SessionPlayerData@> results;

    auto raceData = MLFeed::GetRaceData_V4();
    if (raceData is null || raceData.SortedPlayers_TimeAttack is null || raceData.SortedPlayers_TimeAttack.Length == 0) {
        // deletes the cache if no raceData or PlayerDatas found
        gPlayerLapData.DeleteAll();
        return results;
    }

    auto players = raceData.SortedPlayers_TimeAttack;

    // Pre-allocate results array for better performance
    results.Reserve(players.Length);

    // Use a dictionary for active players for faster lookups
    dictionary activePlayers;

    for (uint i = 0; i < players.Length; i++) {
        auto@ p = cast<MLFeed::PlayerCpInfo_V4>(players[i]);
        if (p is null) continue;

        string userId = p.WebServicesUserId;
        activePlayers.Set(userId, true);

        // Build session data
        auto d = SessionPlayerData();
        d.name = p.Name;
        d.bestLap = p.BestTime;

        // Get cached PB/Last lap values or initialize to defaults
        int64 packedValue;
        if (!gPlayerLapData.Get(userId, packedValue)) {
            packedValue = (int64(21000) << 32) | int64(0); // Default values
            gPlayerLapData.Set(userId, packedValue);
        } else {
            int personalBest = int(packedValue >> 32);
            int lastLap = int(packedValue & 0xFFFFFFFF);

            // Update Cached data here for personal best and last lap
            if (p.BestTime > 0 && p.BestTime < personalBest) {
                personalBest = p.BestTime;
            }
            if (p.IsFinished && p.LastCpTime != lastLap) {
                lastLap = p.LastCpTime;
            }

            packedValue = (int64(personalBest) << 32) | int64(lastLap);
            gPlayerLapData.Set(userId, packedValue);
        }

        d.personalBest = int(packedValue >> 32);
        d.lastLap = int(packedValue & 0xFFFFFFFF);

        results.InsertLast(d);
    }

    // No need to cleanup if no cached players
    if (!gPlayerLapData.IsEmpty()) {
        CleanupInactivePlayers(activePlayers);
    }

    return results;
}

// Remove cached data for players no longer in the session
void CleanupInactivePlayers(const dictionary& activePlayers) {
    // Get cached player IDs and remove those not in active set
    array<string> cachedPlayerIds = gPlayerLapData.GetKeys();
    for (uint i = 0; i < cachedPlayerIds.Length; i++) {
        if (!activePlayers.Exists(cachedPlayerIds[i])) {
            gPlayerLapData.Delete(cachedPlayerIds[i]);
        }
    }
}