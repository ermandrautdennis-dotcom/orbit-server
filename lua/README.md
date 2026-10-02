# Lua loader

`loader.lua` is served verbatim (with `__API_BASE_URL__` substituted for your
public HTTPS origin) by `GET /api/script/loader`.

## What the user runs

```lua
script_key  = "osk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
script_tier = "public"   -- or "private"
loadstring(game:HttpGet("https://your-domain/api/script/loader"))()
```

The Discord panel's **Get Script** button hands the user this snippet with the
script key already filled in. There is no website involved.

## Threat model

Everything in this file is readable by whoever runs it. That is assumed, not
worked around. The loader holds:

* the public API base URL — not a secret;
* the user's own script key — a credential scoped to one license, rotated by
  pressing **Get Script** again, revoked the moment the license is revoked or the
  owner is blacklisted.

It does **not** hold the admin secret, the key pepper, the token pepper, or any
signing key, and it makes no authorisation decision of its own. A user who
patches the loader to skip a check gains nothing: the server re-checks the
license, the tier, the whitelist and both online switches before it emits a
single byte of source, and the grant it issues is single-use, IP-bound and
expires in seconds.

What this design does not do — and no client-side design can — is prevent
someone who legitimately authenticates from dumping the source they received.
The useful levers against that are revocation and attribution, both of which the
platform gives you: every download is attributed to a license and a hashed IP in
`audit_logs`, and `/blacklist` burns the account, its licenses, its script keys
and its outstanding grants in one transaction.
