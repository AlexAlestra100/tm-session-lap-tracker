uint gLastSessionUpdateMs = 0;
const uint gSessionUpdateIntervalMs = 500;

void Main() {
    NadeoServices::AddAudience("NadeoServices");
}

void Render() {
    uint now = Time::Now;
    if (now - gLastSessionUpdateMs >= gSessionUpdateIntervalMs) {
        gLastSessionUpdateMs = now;
        GetSessionPlayers();
    }

    RenderOverlay();
}