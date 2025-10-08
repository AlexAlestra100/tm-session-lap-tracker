void FetchAndCachePBs(const string &in packed) {
    trace("Global player cache: " + gPlayerLapData.GetSize() + " entries, mapId: " + (mapId.Length > 0 ? mapId : "\"\""));

    auto parts = packed.Split("|");
    string mapUid = parts[0];
    string pbQueryFragment = parts[1];
    // Wait until authenticated
    while (!NadeoServices::IsAuthenticated("NadeoServices")) {
        trace("Waiting for NadeoServices authentication...");
        // yield so we don't block the render loop
        yield();
    }

    if (mapId.Length == 0) {
        ResolveMapId(mapUid);
        if (mapId.Length == 0) {
            error("Cannot fetch PBs: failed to resolve mapId for mapUid " + mapUid);
            return;
        }
    }

    // Build URL
    string url = "https://prod.trackmania.core.nadeo.online/v2/mapRecords?mapId=" + mapId + "&accountIdList=" + pbQueryFragment;
    trace("Bulk PB fetch URL: " + url);

    // Send request
    auto req = NadeoServices::Get("NadeoServices", url);
    req.Start();
    while (!req.Finished()) {
        yield();
    }

    if (req.ResponseCode() != 200) {
        error("PB fetch failed: " + req.String());
        return;
    }

    // Parse response
    auto jsonStr = req.String();
    auto json = Json::Parse(jsonStr);

    if (json.GetType() != Json::Type::Array) {
        trace("Unexpected PB response: " + jsonStr);
        return;
    }

    // Each entry has accountId + score
    for (uint i = 0; i < json.Length; i++) {
        auto entry = json[i];
        if (!entry.HasKey("accountId")) continue;

        string accountId = entry["accountId"];

        int score = 10000;
        if (entry.HasKey("recordScore") && entry["recordScore"].HasKey("time")) {
            score = int(entry["recordScore"]["time"]);
        }

        int64 packedValue;
        if (!gPlayerLapData.Get(accountId, packedValue)) {
            trace("Warning: got PB for unknown accountId " + accountId);
            continue;
        }

        int lastLap = int(packedValue & 0xFFFFFFFF);
        packedValue = (int64(score) << 32) | int64(lastLap);

        gPlayerLapData.Set(accountId, packedValue);
    }
}

// Resolve mapUid to mapId (UUID) once and cache it
void ResolveMapId(const string &in mapUid) {
    string url = "https://prod.trackmania.core.nadeo.online/maps/?mapUidList=" + mapUid;
    auto req = NadeoServices::Get("NadeoServices", url);
    req.Start();
    while (!req.Finished()) {
        yield();
    }

    if (req.ResponseCode() != 200) {
        trace("MapId resolve failed: " + req.String());
        return;
    }

    auto json = Json::Parse(req.String());
    if (json.GetType() == Json::Type::Array && json.Length > 0) {
        mapId = string(json[0]["mapId"]);
        trace("Resolved mapUid " + mapUid + " -> mapId " + mapId);
    } else {
        error("Unexpected map resolve response: " + req.String());
    }
}
