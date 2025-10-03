// Context object to hold both parameters
class FetchContext {
    string mapUid;
    array<string>@ ids;
    FetchContext(const string &in m, array<string>@ a) {
        mapUid = m;
        @ids = a;
    }
}

// Coroutine entry point that takes a ref
void FetchAndCachePBsEntry(ref@ data) {
    auto@ ctx = cast<FetchContext>(data);
    if (ctx is null) return;
    FetchAndCachePBs(ctx.mapUid, ctx.ids);
}
