# Codex statusline source integration

The existing Claude collector and first-line/other-account ABI stay unchanged. The renderer adds a separate `codex <label> <5h-bar><weekly-bar>` cell. Unknown is two empty bars; zero is a real observed zero. Codex has a 900-second freshness limit, independent of Claude stale clocks.

The new `codex-rate-limits.py` requires Python3 and a caller-provided `~/.config/codex-statusline.json`. No configuration is installed by this change. Without configuration it returns unknown and launches nothing. A configured reader is an explicit opt-in to native backend access, whose managed credential refresh can occur. Account ID binding must come from the caller's account authority; never guess it from label/email/home.

Example structure (placeholders must be supplied by that authority):

```json
{"label":"basement","remote_host":"basement","argv":["/absolute/path/openai-account","status","--statusline","--code-home","/explicit/codex-home","--account","basement","--expected-account-id","CALLER_BINDING"]}
```

Omit `remote_host` for an explicit local command. Remote transport uses SSH BatchMode, a5s connect timeout, strict existing host-key checking, quoted arguments and a12s total source deadline. It does not provision SSH trust or accounts. The renderer reads local cache immediately and schedules a quiet background refresh. A lock and persisted attempt time enforce at least60s between source fetches, including failures. No foreground network or prompt is needed. Only a validated six-field line is retained; provider data/IDs/stderr never enter the cache or renderer. A configuration fingerprint prevents cross-binding cache reuse.

The CLI floors display age. Cache age therefore uses wire age+1 as a conservative bound, preserves fractional source-fetch start time, and adds full transfer and local residency before comparing to900. A source age899.9s plus0.2s transit is unknown, never freshened. Failed/malformed/mismatched/future/stale reads produce unknown and invalidate old numbers. Cache writes are atomic. Values cached near the exact boundary can expire up to one second early; the cache makes no quota reservation.

Source-only validation: `python3 -m unittest discover -s tests -p test_codex_cache.py -v`, `zsh tests/test_statusline.sh`, `zsh -n private_dot_claude/executable_statusline-command.sh`. Tests inject fetch/clock and scratchHOME fixtures; they never invoke live Codex/accounts/SSH or apply chezmoi. Actual account binding, native compatibility, released package consumption and deployment remain separate gates. `STATUSLINE_CODEX_CONFIG`, `STATUSLINE_CODEX_CACHE` and `STATUSLINE_CODEX_RATE_LIMITS` are explicit test/placement seams; no settings are modified here.
