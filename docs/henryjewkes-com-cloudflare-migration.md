# henryjewkes.com: HostGator to Cloudflare, plus Email Routing

Moving `henryjewkes.com` DNS to Cloudflare and standing up email aliases for the
Claude profile accounts. Surveyed and **executed 2026-09-14**; see "Status" below
for what is done and what remains.

Companion doc: `claude-account-separation.md`.

## Status

Done:

- Zone `henryjewkes.com` created on the Free plan in `Hjewkes@gmail.com's Account`
  (`588a4144e18ac484905121eda2826d61`).
- Three A records imported unchanged (apex, `www`, `*`), all `192.254.250.172`,
  all proxied.
- Nameservers changed at IONOS to `aitana.ns.cloudflare.com` and
  `kipp.ns.cloudflare.com`. The registry reflects this already.
- Email Routing enabled. `hjewkes@gmail.com` added as a destination and verified
  automatically, no confirmation click needed.
- Routing rules active: `agentic@henryjewkes.com` and `coach@henryjewkes.com`,
  both to `hjewkes@gmail.com`.
- Email Routing DNS added: three MX (`route1/2/3.mx.cloudflare.net`), the
  `cf2024-1._domainkey` DKIM TXT, and the Cloudflare SPF TXT.
- Stage-1 DMARC TXT added at `_dmarc`.

- Nameservers propagated. Both `1.1.1.1` and `8.8.8.8` return the Cloudflare pair.
- **Delivery verified.** A test message to both aliases shows `Forwarded` for each
  in the Email Routing activity log. Note that Gmail suppresses the inbox copy of
  a message you sent to yourself, so the activity log is the evidence, not the
  inbox.
- Site repointed at GitHub Pages (see below).

Remaining:

- Create the two Claude accounts and bind them to profiles (step 7).
- Wait for GitHub to issue the Pages certificate, then enable Enforce HTTPS.
- Tighten DMARC to `p=reject` after two weeks of clean reports.

## The dead site

The site was broken for a reason worth recording. `HJewkes/henryjewkes-com` is a
real personal-site repo with GitHub Pages enabled, serving at
`hjewkes.github.io/henryjewkes-com`. IONOS held A records pointing at GitHub
Pages (`185.199.108-111.153`), but two things were never finished:

1. The registry delegation still pointed at HostGator, so the IONOS zone was
   never authoritative and those records never took effect.
2. GitHub Pages has no custom domain set (`cname: null` on the Pages API).

So the domain resolved through HostGator to a dead shared-hosting error page.
The Cloudflare import faithfully copied that dead state, which is correct as a
pure lift but is not where the records should stay.

This was fixed on 2026-09-14. The zone now holds:

| Name | Type | Value | Proxy |
| --- | --- | --- | --- |
| `henryjewkes.com` | A | `185.199.108.153` | DNS only |
| `henryjewkes.com` | A | `185.199.109.153` | DNS only |
| `henryjewkes.com` | A | `185.199.110.153` | DNS only |
| `henryjewkes.com` | A | `185.199.111.153` | DNS only |
| `www` | CNAME | `hjewkes.github.io` | DNS only |

The wildcard is deleted. `cname` on the Pages API is now `henryjewkes.com`.

**Why DNS only rather than proxied.** GitHub validates the domain over HTTP to
issue its Let's Encrypt certificate. Proxying through Cloudflare breaks that
validation, so Enforce HTTPS never becomes available. Leave these grey-clouded.
Cloudflare still serves the DNS; it just is not in the request path.

`https_enforced` is currently `false` because no certificate exists yet. Once
GitHub issues one, turn Enforce HTTPS on in the repo's Pages settings.

### One thing still broken: the Vite base path

GitHub Pages now serves the right site (`Server: GitHub.com`, title "Henry
Jewkes"), and `www` 301s to the apex. But every asset 404s:

```
$ curl -I http://henryjewkes.com/henryjewkes-com/assets/index-k2RVs94w.js
404
```

`vite.config.ts` in `HJewkes/henryjewkes-com` sets `base: '/henryjewkes-com/'`,
which is correct for a project page at `hjewkes.github.io/henryjewkes-com/` and
wrong for a custom domain serving at the root. The HTML loads; the JS and CSS
do not, so the page renders blank.

Fix is one line, `base: '/'`, plus a rebuild and redeploy. Not done here because
it is a code change in a separate repo.

Note that local DNS/HTTP caches on this machine kept returning the old HostGator
error page for a while after cutover. Use
`curl --resolve henryjewkes.com:80:185.199.108.153` to check the real thing.

## Current state

Registrar is IONOS SE. Registry expiry 2027-07-11. DNS is served by HostGator
(`NS1775.HOSTGATOR.COM`, `NS1776.HOSTGATOR.COM`).

The entire zone, as enumerated against the authoritative nameserver:

| Name | Type | Value |
| --- | --- | --- |
| `henryjewkes.com` | A | `192.254.250.172` |
| `*.henryjewkes.com` | A | `192.254.250.172` |

Confirmed absent: AAAA, MX, TXT, CAA. No SPF, no DKIM, no DMARC. The wildcard is
real, verified by resolving a random label. AXFR is refused, as expected.

`192.254.250.172` is HostGator shared hosting. It serves an Apache error page
("Error. Page cannot be displayed") over HTTP 200, and HTTPS fails certificate
validation because the cert does not match the hostname. Nothing of value is
hosted there.

**Migration risk is therefore near zero.** There is no live site to break and no
mail flow to preserve.

## Target state

Zone on Cloudflare. Email Routing enabled with two forwarding aliases into the
existing Gmail inbox, one per new Claude account:

| Alias | Destination | Claude profile |
| --- | --- | --- |
| `agentic@henryjewkes.com` | `hjewkes@gmail.com` | `agents` |
| `coach@henryjewkes.com` | `hjewkes@gmail.com` | `workout` |

The `personal` profile stays on the existing `hjewkes@gmail.com` Max account.

## Which Cloudflare account

Not relay's. R-44 moved relay's Worker, D1 and KV into a dedicated Cloudflare
account precisely to remove the cross-reach that R-20 documented. Adding a zone
to that account hands every "all zones" token there authority over your email
routing. Put the zone in the other account, the one `mascot-madness` uses.

## Steps

1. **Record inventory.** Done, see the table above. Two A records, nothing else.

2. **Create the zone.** Add `henryjewkes.com` to the chosen Cloudflare account.
   Cloudflare's onboarding scan will find both A records; verify it produced
   exactly the two rows above and nothing invented.

3. **Change nameservers at IONOS.** Interactive, registrar side. Replace the two
   HostGator nameservers with the pair Cloudflare assigns. Propagation is
   typically under an hour; Cloudflare emails when the zone goes active.

4. **Verify before trusting.** `dig NS henryjewkes.com` returns the Cloudflare
   pair, and `dig +short henryjewkes.com` still returns `192.254.250.172` (or
   whatever you have repointed it to by then).

5. **Enable Email Routing.** Cloudflare adds its own MX and SPF records
   automatically. Add the two aliases, then verify `hjewkes@gmail.com` as a
   destination by clicking the confirmation link Cloudflare sends there.
   Verification is per destination address, once, not per alias.

6. **Create the Claude accounts.** Sign up at claude.ai with `agentic@` and
   `coach@`. Remember that a Claude account's email can never be changed, so
   these addresses are permanent.

7. **Bind each profile to its account.**

   ```
   claude-profile agents   && claude auth login --claudeai --email agentic@henryjewkes.com
   claude-profile workout  && claude auth login --claudeai --email coach@henryjewkes.com
   ```

   Watch for anthropics/claude-code#94195: subscription metadata can go stale
   when switching accounts. `claude auth status` should report the right email
   and `subscriptionType` before you trust a profile.

## Cleanup worth doing afterward

- **Drop the wildcard.** `*.henryjewkes.com` pointing at a dead shared host is a
  liability, not a feature. Replicate it through the cutover so the migration is
  a pure lift, then delete it once the zone is active.
- **Repoint or remove the apex.** It currently serves a HostGator error page.
- **Reconsider the HostGator plan.** You are paying for hosting that serves
  nothing. Do not cancel until after the nameserver cutover completes, since the
  registrar is IONOS but the DNS is HostGator's.
## DMARC

Email Routing is receive-only, and Cloudflare adds its own SPF record
(`v=spf1 include:_spf.mx.cloudflare.net ~all`) when you enable it. Leave that
one alone; Cloudflare manages it.

DMARC is yours to add. Deploy in two stages rather than jumping to enforcement.

**Stage 1, on the day Email Routing goes live.** Monitor only, breaks nothing:

```
Name:  _dmarc
Type:  TXT
Value: v=DMARC1; p=none; rua=mailto:hjewkes@gmail.com; fo=1
```

**Stage 2, after two weeks of clean reports.** Nothing legitimate sends from
this domain, so enforcement should be strict:

```
Name:  _dmarc
Type:  TXT
Value: v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:hjewkes@gmail.com; fo=1
```

**The one thing that would break stage 2.** If you ever configure Gmail's "Send
mail as" to send outbound as `agentic@` or `coach@`, that mail leaves through
Google's SMTP and will not align with the Cloudflare SPF record. Either keep
these addresses receive-only, or stay at `p=none` and add a Gmail `include:` to
SPF before tightening. Receive-only is the simpler choice and is all the Claude
accounts need.

Reports arrive as XML attachments. Two weeks at `p=none` is enough to see
whether anything unexpected is sending as the domain.
