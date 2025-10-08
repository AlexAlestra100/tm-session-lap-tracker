array<string> gPbRequestQueue;
bool gPbWorkerRunning = false;

void EnqueuePbRequest(const string &in packed) {
    gPbRequestQueue.InsertLast(packed);
    if (!gPbWorkerRunning) {
        gPbWorkerRunning = true;
        startnew(PbRequestWorker);
    }
}

void PbRequestWorker() {
    while (gPbRequestQueue.Length > 0) {
        string packed = gPbRequestQueue[0];
        gPbRequestQueue.RemoveAt(0);

        // Run the actual fetch
        try {
            FetchAndCachePBs(packed);
        } catch {
            error("PB fetch threw an exception for: " + packed);
        }

        // Enforce at least 1 second between calls
        sleep(1000);
    }
    gPbWorkerRunning = false;
}
