void FetchAndCachePBs(const string &in mapUid, const array<string>@ accountIds) {
    if (accountIds.Length == 0) return;

    // Build comma‑separated list of accountIds
    string joined;
    for (uint i = 0; i < accountIds.Length; i++) {
        if (i > 0) joined += ",";
        joined += accountIds[i];
    }

    // Wait until authenticated with LiveServices
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) {
        yield();
    }

    string url = "/api/token/leaderboard/group/Personal_Best/map/" + mapUid
               + "/players?accountIdList=" + joined;

    // Use NadeoServices::Get to automatically attach the token
    auto req = NadeoServices::Get("NadeoLiveServices", url);
    while (!req.Finished()) yield();

    if (req.ResponseCode() == 200) {
        auto json = Json::Parse(req.String());
        if (json.HasKey("records")) {
            auto records = json["records"];
            for (uint i = 0; i < records.Length; i++) {
                string accId = records[i]["accountId"];
                int pb = int(records[i]["time"]);

                InSessionClubMember@ m;
                if (gInSessionClubMembers.Get(accId, @m)) {
                    m.personalBest = pb;
                }
            }
        }
    } else {
        warn("[PB] Failed to fetch PBs (" + req.ResponseCode() + ")");
    }
}
