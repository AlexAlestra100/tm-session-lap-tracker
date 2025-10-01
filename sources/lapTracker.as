// Global cache: for bestLap/lastLap per player
// Format: (bestLap << 32) | lastLap - packed into single 64-bit int
dictionary gPlayerLaps; // string -> int64

array<SessionPlayerData@> GetSessionPlayers() {
    array<SessionPlayerData@> results;

    auto raceData = MLFeed::GetRaceData_V4();
    if (raceData is null || raceData.SortedPlayers_TimeAttack is null || raceData.SortedPlayers_TimeAttack.Length == 0) {
        // deletes the cache if no raceData or PlayerDatas found
        gPlayerLaps.DeleteAll();
        return results;
    }

    auto players = raceData.SortedPlayers_TimeAttack;

    // Pre-allocate results array for better performance
    results.Reserve(players.Length);
    
    // Collect active players and process data
    array<string> activePlayers;
    activePlayers.Reserve(players.Length);

    for (uint i = 0; i < players.Length; i++) {
        auto@ p = cast<MLFeed::PlayerCpInfo_V4>(players[i]);
        if (p is null) continue;
        
        // Add to active players list
        activePlayers.InsertLast(p.Name);

        // Build session data
        auto d = SessionPlayerData();
        d.name         = p.Name;
        d.personalBest = p.BestTime;

        // Get cached best/last lap values or initialize to 0
        int64 packedLaps = 0;
        if (gPlayerLaps.Get(p.Name, packedLaps)) {
            d.bestLap = int(packedLaps >> 32);
            d.lastLap = int(packedLaps & 0xFFFFFFFF);
        } else {
            d.bestLap = 0;
            d.lastLap = 0;
        }

        // Only update when BestLapTimes is populated (p.BestLapTimes will always have a 0 entry)
        if (p.BestLapTimes.Length > 1) {
            int candidate = p.BestLapTimes[p.BestLapTimes.Length - 1];
            if (d.bestLap == 0 || candidate < d.bestLap) {
                d.bestLap = candidate;
            }
            d.lastLap = candidate;
            
            // Pack both values into single 64-bit integer
            gPlayerLaps[p.Name] = (int64(d.bestLap) << 32) | int64(d.lastLap);
        }

        results.InsertLast(d);
    }
    
    // No need to cleanup if no cached players
    if (!gPlayerLaps.IsEmpty()) {
        CleanupInactivePlayers(activePlayers);
    }
    
    return results;
}

// Remove cached data for players no longer in the session
void CleanupInactivePlayers(const array<string>& activePlayers) {
    // Convert active players to dictionary for O(1) lookup
    dictionary activeSet;
    for (uint i = 0; i < activePlayers.Length; i++) {
        activeSet[activePlayers[i]] = true;
    }
    
    // Get cached players and remove those not in active set
    array<string> cachedPlayers = gPlayerLaps.GetKeys();
    for (uint i = 0; i < cachedPlayers.Length; i++) {
        if (!activeSet.Exists(cachedPlayers[i])) {
            gPlayerLaps.Delete(cachedPlayers[i]);
        }
    }
}
