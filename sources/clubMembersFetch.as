void FetchUserClubsCoroutine() {
    // Wait until Live audience is authenticated
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) {
        trace("[Club] Waiting for LiveServices auth...");
        yield();
    }

    // Wait until the game has a valid LocalPlayerInfo and accountId
    auto app = cast<CTrackMania>(GetApp());
    while (app is null || app.LocalPlayerInfo is null || app.LocalPlayerInfo.WebServicesUserId.Length == 0) {
        trace("[Club] Waiting for LocalPlayerInfo...");
        yield();
        @app = cast<CTrackMania>(GetApp());
    }
    string accountId = app.LocalPlayerInfo.WebServicesUserId;
    trace("[Club] Local accountId resolved: " + accountId);

    // Build the path we want to hit
    string path = "/api/clubs/player/" + accountId;

    // Try to request clubs, retrying if "no state" is thrown
    Net::HttpRequest@ req = null;
    int backoff = 5;
    while (@req is null) {
        try {
            trace("[Club] Attempting request: " + path);
            @req = NadeoServices::Get("NadeoLiveServices", path);
        } catch {
            trace("[Club] LiveServices not quite ready (no state), retrying in " + tostring(backoff) + " frames...");
            for (int i = 0; i < backoff; i++) yield();
            backoff = Math::Min(backoff * 2, 120); // exponential backoff up to ~2s
        }
    }

    // Wait for the request to finish
    while (!req.Finished()) yield();

    // Print out the raw response for debugging
    trace("[Club] Response code: " + req.ResponseCode());
    trace("[Club] Response body: " + req.String());

    if (req.ResponseCode() == 200) {
        auto json = Json::Parse(req.String());
        array<int> userClubs;
        for (uint i = 0; i < json.Length; i++) {
            int clubId = int(json[i]["id"]);
            userClubs.InsertLast(clubId);
            trace("[Club] User is in club " + string(json[i]["name"]) + " (" + tostring(clubId) + ")");
        }

        // Clear old state before adding new members
        gInSessionClubMembers.DeleteAll();

        // Now fetch members for each club
        for (uint i = 0; i < userClubs.Length; i++) {
            FetchClubMembers(userClubs[i]);
        }
    } else {
        warn("[Club] Failed to fetch clubs (" + req.ResponseCode() + ")");
    }
}


void FetchClubMembers(int clubId) {
    string path = "/api/clubs/" + tostring(clubId) + "/members?length=100&offset=0";

    Net::HttpRequest@ req = null;
    int backoff = 5;
    while (@req is null) {
        try {
            trace("[Club] Attempting request: " + path);
            @req = NadeoServices::Get("NadeoLiveServices", path);
        } catch {
            trace("[Club] Members endpoint not ready (no state), retrying in " + tostring(backoff) + " frames...");
            for (int i = 0; i < backoff; i++) yield();
            backoff = Math::Min(backoff * 2, 120);
        }
    }

    while (!req.Finished()) yield();

    // Print out the raw response for debugging
    trace("[Club] Members response code: " + req.ResponseCode());
    trace("[Club] Members response body: " + req.String());

    if (req.ResponseCode() == 200) {
        auto json = Json::Parse(req.String());

        // Handle both raw array and wrapped {"members": [...]}
        Json::Value@ members = json;
        if (json.HasKey("members")) {
            @members = json["members"];
        }

        for (uint i = 0; i < members.Length; i++) {
            string accId = members[i]["accountId"];
            string name = members[i].Get("name", "Unknown");

            InSessionClubMember@ m;
            if (!gInSessionClubMembers.Get(accId, @m)) {
                @m = InSessionClubMember();
                m.accountId = accId;
                m.name = name;
                m.personalBest = 0;
                m.lastLap = 0;
                m.bestLap = 0;
                gInSessionClubMembers[accId] = m;
                trace("[Club] Added member: " + m.name + " (" + m.accountId + ")");
            }
        }
    } else {
        warn("[Club] Failed to fetch members for club " + tostring(clubId)
            + " (" + req.ResponseCode() + ")");
    }
}
