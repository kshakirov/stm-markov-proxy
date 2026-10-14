---
number: 8
state: OPEN
state_reason: 
author: kshakirov
created_at: 2026-10-09T04:41:10Z
updated_at: 2026-10-09T04:41:10Z
closed_at: 
url: https://github.com/kshakirov/stm-markov-proxy/issues/8
labels: []
assignees: []
milestone: 
---

# #8 — Detect and extend an existing Via field

## Goal

Upgrade the first minimal `Via` insertion into RFC-compliant proxy-chain handling.

The initial implementation deliberately does only this:

```text
end of header section
        ↓
insert Via: <received-version> stm-markov-proxy

```

It does not search for an incoming `Via` field. This issue records the second step and is not part of today’s implementation.

## Required behavior

- recognize the `Via` field name case-insensitively while parsing headers;
- if no `Via` is present, insert our own field before the terminating empty line;
- if `Via` is present, preserve the existing ordered chain and append our entry as the last member;
- derive the received protocol version from the already recognized request version;
- use the stable pseudonym `stm-markov-proxy` unless the application model selects another identity;
- retain only the bounded workspace needed for the `Via` value, not the complete request or all headers;
- define an explicit limit and failure policy for an oversized `Via` value;
- add tests for absent, single, multiple, mixed-case, fragmented, and oversized `Via` input.

Expected shape:

```http
Via: 1.0 upstream, 1.1 stm-markov-proxy
```

Reference: RFC 9110, Section 7.6.3.

## Out of scope

- `Forwarded`;
- `X-Forwarded-*`;
- generic storage or rewriting of arbitrary headers;
- implementation during the current minimal-header step.

## Terms introduced

- **Via Field** — the ordered HTTP intermediary chain field that each forwarding proxy appends to.

