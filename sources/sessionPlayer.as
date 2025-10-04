// Global cache: for personalBest/lastLap per player
// Format: (personalBest << 32) | lastLap - packed into single 64-bit int
dictionary gPlayerLapData; // string -> int64

class SessionPlayerData {
    string name;
    int personalBest;
    int bestLap;
    int lastLap;
}
