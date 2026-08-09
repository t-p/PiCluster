# PiCluster — Remote Access

Covers how devices outside the home LAN reach services running on the Pi cluster.

## Language

**Private Network Route**:
The Kubernetes Service CIDR (ClusterIP range, e.g. `10.43.0.0/16` — verify against the live cluster) that cloudflared advertises to Cloudflare Zero Trust, letting enrolled WARP clients reach ClusterIPs through the existing tunnel. Deliberately *not* the physical LAN (`192.168.88.0/24`) — scoping to the Service CIDR keeps the blast radius to the Kubernetes network instead of the whole home LAN. Replaces the old per-pod Tailscale subnet router, which advertised the LAN.
_Avoid_: subnet route (Tailscale-specific term, being retired), tunnel route, pod network route (pod IPs churn on reschedule — not what gets advertised)

**Split DNS**: *(abandoned — see below)*
Cloudflare Gateway DNS policy intended to resolve `*.svc.cluster.local` queries from enrolled WARP clients via the cluster's internal resolver (CoreDNS ClusterIP). Doesn't work: `.local` is a reserved mDNS/Bonjour TLD (RFC 6762) that client OSes (macOS confirmed) intercept before any configured DNS server ever sees the query — the request never reaches Gateway. Devices connect to the ClusterIP directly instead.
_Avoid_: relying on `*.svc.cluster.local` resolution from any client device — it cannot work as long as the cluster's domain is `cluster.local`.

**WARP Client**:
The device-side app (phone, laptop) that enrolls into the Zero Trust org and, in split-tunnel mode, routes only traffic destined for the Private Network Route through Cloudflare.
_Avoid_: Tailscale client, VPN client

**Split Tunnel**:
WARP mode where only traffic destined for the advertised Private Network Route CIDR goes through Cloudflare; all other device traffic uses the normal internet path. Chosen over full-tunnel/Gateway mode.

**Tunnel-Encrypted Transport**:
The decision to rely on the Cloudflare tunnel's own TLS for confidentiality instead of restoring Dovecot's own TLS listener. Applies specifically to the `imap-server` IMAP traffic (currently plaintext port 143).

**Published Application Route**:
cloudflared's mechanism for exposing a public hostname (e.g. `nextcloud.pfeiffer.pw`) through the tunnel to an internal origin (e.g. `http://nextcloud.nextcloud.svc.cluster.local:80`). `cloudflared` itself resolves the origin's DNS server-side, so `.local` names work fine here — the mDNS collision only affects client-side resolution attempts. Distinct from the Private Network Route (which exposes a CIDR to enrolled devices, not a single hostname to the public internet).

**Access-gated Hostname**:
A Published Application Route protected by a Cloudflare Access policy requiring interactive browser login (OTP or IdP). Works for browsers; breaks non-browser API clients (sync apps, mobile apps) that don't follow the login redirect. `nextcloud.pfeiffer.pw` is the one Access-gated hostname in this project; browser access to Nextcloud goes through it, app/sync access does not (see ClusterIP-direct below).
_Avoid_: "protected route", "secured app" — name the mechanism (Access policy), not just the outcome.

**ClusterIP-direct**:
Connecting a client straight to a Service's ClusterIP (e.g. `10.43.27.203`) over the Private Network Route, bypassing DNS and Cloudflare Access entirely. The only way non-browser clients (Nextcloud sync app, mail clients) reach these two apps, since Access's interactive login blocks them and `*.svc.cluster.local` can't resolve from client devices. Access control for this path is WARP device enrollment, not an Access policy.
