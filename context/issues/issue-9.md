---
number: 9
state: OPEN
state_reason: 
author: kshakirov
created_at: 2026-10-09T05:31:00Z
updated_at: 2026-10-09T05:31:00Z
closed_at: 
url: https://github.com/kshakirov/stm-markov-proxy/issues/9
labels: []
assignees: []
milestone: 
---

# #9 — Stream POST and PUT request bodies to the backend

## Problem

The current live proxy path stops request parsing when the end of the header section is recognized. It then rebuilds and forwards only the request prefix. A POST or PUT body is neither framed nor forwarded, including body bytes already received in the same TCP chunk as the final header delimiter.

Method recognition alone must not be treated as POST or PUT support.

## Goal

After the request line and headers have been processed, forward the complete request body to the selected backend without requiring the whole body to be buffered in memory.

## Scope

- Keep `requestBuffer` for now: it is needed to retain received chunks and the bytes following the header boundary.
- Determine body framing from the processed headers.
- Support `Content-Length` for POST and PUT first.
- Separate bytes already received after `\r\n\r\n` from bytes still to be read from the client socket.
- Forward exactly the declared body length to the backend in chunks.
- Define explicit behavior for early EOF, malformed length, body overflow and bytes beyond the current request.
- Add tests where the header/body boundary and the body itself cross several `recv` calls.
- Treat `Transfer-Encoding: chunked` as a separately stated follow-up unless it is deliberately included in the first implementation.

## Acceptance criteria

- A POST or PUT body larger than one 1024-byte receive buffer reaches the backend byte-for-byte.
- A body fragment arriving with the final header chunk is not lost or duplicated.
- The proxy does not close either connection before the complete framed body has been forwarded.
- GET without a body keeps its existing behavior.

## Terms introduced

- **Request body forwarding**: the mandatory proxy path that transfers the framed request body from the client connection to the selected backend connection.

