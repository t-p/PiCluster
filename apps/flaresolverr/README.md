# FlareSolverr

Proxy that solves Cloudflare anti-bot challenges (JS challenge, CAPTCHA) for
Prowlarr, letting it index trackers that would otherwise return "blocked by
CloudFlare Protection" (e.g. 1337x, EZTV).

ClusterIP-only — Prowlarr is the sole consumer, reached at
`http://flaresolverr.flaresolverr.svc.cluster.local:8191`.

## Wiring up Prowlarr

Settings > Indexers > Add FlareSolverr Proxy (or per-indexer under Advanced):

- Host: `http://flaresolverr.flaresolverr.svc.cluster.local:8191`
- Request Timeout: 60

Then retry adding CF-blocked indexers (1337x, EZTV) — Prowlarr routes their
fetches through FlareSolverr instead of failing the connectivity check.
