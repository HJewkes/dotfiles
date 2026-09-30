---
name: checking-gmail
description: Use when searching, reading, or verifying mail in the user's Gmail through the claude_ai_Gmail MCP connector — covers query syntax, thread reading, and the critical rule that empty results are never proof a message is absent.
---

# Checking Gmail

## The rule that matters most

**`search_threads` returning nothing does NOT mean the message does not exist.**

The connector can omit messages that match the query exactly, including messages
sitting in the Inbox inside the requested time window. Treat every empty or
short result as *inconclusive*, not as evidence of absence.

Never tell the user "there is no such email" on the strength of a search. Say
"I did not find it" and name what you searched.

### This is not staleness, and recency does not disprove it

The tempting check — "the connector returned a message from ten minutes ago, so
it is current" — is invalid. A live connector can still under-return. Freshness
and completeness are different properties. Do not use one to argue the other.

### Verified incident

2026-09-15. A message from `noreply@email.cloudflare.net`, subject
`Cloudflare Email Routing: Missing email from ... to ...`, was in the Inbox and
unread. None of these returned it:

```
from:cloudflare newer_than:1d
cloudflare in:anywhere newer_than:2d
subject:"Cloudflare Email Routing" in:anywhere
"Missing email from" in:anywhere
in:inbox newer_than:12h
```

The last returned six inbox threads and silently omitted the seventh. The
connector was demonstrably live throughout. The user produced a screenshot
proving the message had been there the whole time.

One possibly relevant detail: the omitted message was relayed through the user's
own custom domain (`via henryjewkes.com`), while an unrelated Cloudflare message
delivered directly *was* returned. Mail arriving through a user-controlled
forwarder is worth extra suspicion.

## Establishing that a message really is absent

Escalate in this order. Stop as soon as you find it.

1. **Re-query along a different axis.** Sender, exact subject phrase, a
   distinctive body word, the recipient alias. Different axes fail
   independently.
2. **Widen the scope.** Add `in:anywhere`, which covers spam and trash, and
   loosen the time bound.
3. **List rather than search.** `in:inbox newer_than:1d` with a large
   `pageSize` and scan the titles yourself. This surfaces things keyword
   matching misses.
4. **Look at the Gmail web UI** via the `claude-in-chrome` tools. This is ground
   truth. Do it before making any negative claim that matters.
5. **Ask the user for a screenshot.** Cheapest reliable path when the UI is slow
   to load, and it gives you the exact sender and subject.

## Query syntax

Standard Gmail operators work. The ones that carry weight:

| Operator | Use |
| --- | --- |
| `in:anywhere` | Include spam and trash. Not the default. |
| `newer_than:2d` / `older_than:1y` | Relative windows. |
| `from:` / `to:` / `subject:` | Field scoping. |
| `"exact phrase"` | Strict contiguous match — narrows hard, misses easily. |
| `has:attachment`, `filename:` | Attachments. |
| `OR`, `-`, `{ }`, `( )` | Boolean logic and grouping. |

Prefer a few distinctive keywords over long verbatim subject strings. Copying a
full subject from the user's prompt is a common cause of zero hits.

## Reading

`search_threads` returns only the messages that matched. A thread with five
messages may come back showing one. To see a full conversation, call
`get_thread` with the thread id.

Use `messageFormat: PLAIN_TEXT` on `get_thread`. `FULL_CONTENT` pulls the HTML
body too and burns context for no benefit in most cases.

## Testing mail delivery to a forwarding alias

Gmail deduplicates by `Message-ID`. If the user sends a test from their own
Gmail to an alias that forwards back to that same mailbox, Gmail accepts the
forwarded copy and then discards it as a duplicate. It lands in no folder, not
even All Mail, and `get_thread` shows only the sent original.

This is not a routing failure. Cloudflare Email Routing even sends a courtesy
notice explaining it.

**So: always test forwarding from an address outside the destination mailbox.**
To confirm delivery without a clean sender, read the forwarder's own logs
(Cloudflare's Email Routing activity log shows per-recipient status plus SPF,
DKIM, DMARC and ARC results) rather than trusting the inbox.

## Sending

Sending is an outward-facing action. Get explicit confirmation in chat before
`send_message`, `reply`, or `forward`, and confirm again for each new send —
one approval does not cover the next.
