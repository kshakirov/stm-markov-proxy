---
number: 6
state: OPEN
state_reason: 
author: kshakirov
created_at: 2026-08-28T04:53:23Z
updated_at: 2026-08-28T07:10:38Z
closed_at: 
url: https://github.com/kshakirov/stm-markov-proxy/issues/6
labels: []
assignees: []
milestone: 
---

# #6 — # Streaming request rewriting without full message reconstruction


## Context

Proxy parses the incoming request as a byte stream and records structural boundaries using the Wirth-style finite-state parser.

For a request rewrite such as URI replacement, the proxy already knows the original URI interval:

```text
[uriStart, uriEnd)
```

The request buffer can therefore be treated as a sequence of structural segments rather than as one object that must always be reconstructed.

Example:

```text
prefix | oldURI | suffix
```

After rewriting:

```text
prefix | newURI | suffix
```

The proxy should avoid copying unchanged data unless required by the underlying I/O mechanism.

---

## Goal

Define and implement the first streaming rewrite path where a local modification to the request does **not** require rebuilding the complete request buffer.

The initial experiment should support:

1. parsing request boundaries;
2. locating the URI using recorded offsets;
3. rewriting the URI independently;
4. forwarding unchanged request regions without copying them into a new combined buffer;
5. continuing to stream the request body directly to the selected backend.

---

## Core idea

A local rewrite should produce a logical sequence of segments:

```text
Segment 1: Prefix
Segment 2: Replacement
Segment 3: Suffix
```

For URI rewriting:

```text
Prefix      = bytes before uriStart
Replacement = rewritten URI
Suffix      = bytes from uriEnd onward
```

The proxy may forward these segments sequentially:

```text
send Prefix
send Replacement
send Suffix
```

Subsequent body chunks should be forwarded directly:

```text
client socket
    ↓
recv chunk
    ↓
backend socket
```

No full-request reconstruction is required.

---

## Architectural principle

> **Do not reconstruct the complete message when the transformation is local.**

Unchanged regions should remain unchanged byte ranges.

Only the transformed fragment should require new storage.

---

## Terms introduced

The following terms are used deliberately and should be added to the project glossary.

### Byte Stream

The ordered sequence of bytes received from the client connection.

The proxy must not assume that socket chunk boundaries correspond to HTTP structural boundaries.

### Input Chunk

One physical portion of the Byte Stream returned by a socket read operation.

A chunk is a transport artifact, not an application-level structure.

### Structural Boundary

An index recorded by the parser that identifies the beginning or end of a recognized request component.

Examples:

```text
methodStart
methodEnd
uriStart
uriEnd
headersEnd
bodyStart
```

Intervals follow the project convention:

```text
[start, end)
```

### Segment

A contiguous byte range treated as one forwarding unit.

A Segment may reference existing input memory without requiring a copy.

### Prefix

The unchanged Segment before a rewritten region.

For URI rewriting:

```text
[requestStart, uriStart)
```

### Replacement

A newly produced byte sequence replacing an existing request region.

For the first experiment this is the rewritten URI.

### Suffix

The unchanged Segment following the rewritten region.

For URI rewriting:

```text
[uriEnd, currentlyBufferedEnd)
```

The Suffix may already contain headers and part of the request body.

### Local Rewrite

A transformation that changes only one bounded region of the message while preserving surrounding byte ranges.

URI replacement is the first Local Rewrite experiment.

### Message Reconstruction

Creation of a new contiguous buffer containing the complete transformed request.

Message Reconstruction should not be the default strategy for Local Rewrite.

### Streaming Forwarding

Forwarding bytes to the backend as they become available without materializing the complete request.

### Early Decision

A routing or authorization decision that can be made before the request body must be fully consumed.

Example:

```text
method + URI + headers
    ↓
backend selected
```

### Late Decision

A decision that depends on information located inside the request body.

Late Decision may require selective body parsing and temporary buffering until the required information becomes available.

### Passthrough

Forwarding byte ranges without semantic transformation.

After an Early Decision and local header/URI rewrite, the request body may normally enter Passthrough mode.

### Scatter/Gather I/O

An I/O strategy where several independent memory segments are transmitted as one logical byte stream without first concatenating them into one contiguous buffer.

This is a possible later optimization and is not required for the first implementation.

---

## Initial experiment

Use a request such as:

```http
POST /old/path HTTP/1.1
Host: example.com
Content-Length: ...

<body>
```

The parser identifies:

```text
uriStart
uriEnd
bodyStart
```

A rewrite rule transforms:

```text
/old/path
```

into:

```text
/new/path
```

The forwarding path becomes:

```text
original prefix
    ↓
rewritten URI
    ↓
original suffix
    ↓
future body chunks
```

The implementation should demonstrate that the request body size does not force creation of an equivalently large transformed buffer.

---

## Constraints

For the first implementation:

- do not introduce a general-purpose buffering framework;
- do not create a scatter/gather abstraction unless ordinary sequential forwarding proves insufficient;
- do not parse the request body unless the selected rule requires body data;
- do not reconstruct the full request merely for convenience;
- preserve the existing half-open interval convention `[start, end)`.

---

## Questions to answer

The experiment should clarify:

- what lifetime the original input buffer must have while Prefix/Suffix are being sent;
- whether sequential `sendAll` operations are sufficient;
- where the boundary lies between buffered headers and streamed body;
- how partial socket writes are handled;
- when a backend connection must be established;
- how the design changes for Late Decision;
- whether the segment model should become an explicit internal representation.

---

## Result

The ticket is complete when a request URI can be rewritten and forwarded while:

- preserving unchanged byte ranges;
- allocating storage only for the replacement fragment where practical;
- avoiding full-message reconstruction;
- continuing body forwarding as a stream;
- preserving correct request ordering and framing.

## Comments

### kshakirov — 2026-08-28T07:10:38Z

Для первого прохода предлагаю не тащить body в нашу кухню.

Я буферизую только request line + headers до жёсткого лимита. Автомат хранит свой `currentIndex`, а при каждом новом `recv` получает только ещё не обработанный хвост:

```haskell
B.drop currentIndex cumulativeHeaderBuffer
```

Когда поймали `headersEnd`, делаем rewrite и переключаемся в **Passthrough**. Если тот же `recv` уже прихватил начало body, не теряем его: отделяем `bodyPrefix`, сразу шлём backend, а следующие chunks просто гоняем туда же через `sendAll` без склейки и накопления.

То есть схема первой версии такая:

```text
bounded headers buffer → Early Decision → Local Rewrite → body Passthrough
```

Семантика body пока головная боль backend. Наша головная боль — не потерять и не переставить байты. Keep-alive, `Content-Length`, chunked framing и Late Decision берём отдельным заходом; для первого эксперимента можно честно ограничиться одним запросом на соединение / `Connection: close`.


