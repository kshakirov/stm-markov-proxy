# Handler Lifecycle — First Approach

## Status

First architectural approximation.

This page describes the current understanding of the lifecycle and responsibilities of `handleClient`.

The model is intentionally minimal and will evolve together with request body processing, forwarding, keep-alive support, and the Request Processing Automaton.

---

## 1. One Handler per Connection

For every accepted TCP connection, the server starts one `handleClient`.

```text
listen
  |
accept
  |
  +---- connection A ---> handleClient A
  |
  +---- connection B ---> handleClient B
  |
  +---- connection C ---> handleClient C
```

`handleClient` lives for the lifetime of its connection.

It is not invoked for every incoming TCP chunk.

Instead, it owns the socket and repeatedly calls `recv` when more input is required.

---

## 2. Handler as Connection Coordinator

`handleClient` is the coordination point for everything that belongs to one connection.

Conceptually:

```text
handleClient
    |
    +-- connection socket
    |
    +-- connection/request state
    |
    +-- recv
    |
    +-- Request Processing Automaton
            |
            +-- Wirth Parser
            |
            +-- Markov URI Rewriter
```

The handler owns the lifetime of the connection-level state.

The internal automata do not own the socket and do not perform network reads themselves.

---

## 3. `recv` Is the Byte Input Mechanism

The handler obtains bytes from the client socket using `recv`.

```text
socket
   |
 recv
   |
   v
ByteString
```

A returned `ByteString` is an **Input Chunk**.

The size and boundaries of this chunk are TCP/runtime artifacts.

They have no HTTP semantic meaning.

A URI, header, CRLF sequence, or request body may be split across arbitrary `recv` calls.

---

## 4. Empty ByteString Means Connection EOF

If:

```haskell
B.null chunk
```

then the peer has closed its sending side and the handler has reached EOF for that TCP stream.

This means:

```text
empty ByteString
        =
TCP stream EOF
```

It does **not** mean:

```text
HTTP request finished
```

HTTP message boundaries must be determined by the HTTP processing logic.

---

## 5. Recursive Handler Loop

While the connection is alive and processing requires more bytes, `handleClient` continues reading.

Conceptually:

```text
handleClient state
        |
        v
      recv
        |
        +---- empty ----> connection EOF
        |
        v
      chunk
        |
        v
Request Processing Automaton
        |
        +---- NeedMoreData ----> handleClient newState
        |
        +---- Ready -----------> next action
        |
        +---- Error -----------> failure policy
```

The recursive call carries the new connection/request processing state.

Therefore the handler forms the operational loop around the pure or locally state-transforming automata.

---

## 6. Division of Responsibilities

### `handleClient`

Owns:

- client socket;
- connection lifetime;
- `recv`;
- connection/request processing state;
- coordination of processing steps;
- decision whether to read again, forward, respond, or terminate.

### Request Processing Automaton

Coordinates preparation of the request.

It receives:

```text
old state + new Input Chunk
```

and produces something conceptually equivalent to:

```text
new state + NeedMoreData
new state + Ready
new state + Error
```

### Wirth Parser

Recognizes the syntactic structure of the incoming HTTP request.

It processes only bytes that have not already been processed.

It maintains structural boundaries such as:

```text
uriStart
uriEnd
headersEnd
bodyStart
```

### Markov URI Rewriter

Receives the URI identified by Wirth and performs the URI transformation.

It does not read from the socket and does not control the connection.

---

## 7. First Experiment: Request Without Body

For the current first approximation, consider an HTTP request without a body.

The lifecycle is:

```text
accept
  |
  v
handleClient initialState
  |
  v
recv
  |
  v
Input Chunk
  |
  v
Wirth / Request Processing Automaton
  |
  +---- incomplete headers
  |          |
  |          v
  |     recurse / recv again
  |
  +---- headers complete
             |
             v
        URI rewrite
             |
             v
           Ready
             |
             v
      forward / respond
             |
             v
      close connection
```

In this deliberately restricted experiment:

```text
headersEnd == requestEnd
```

because the request is known to contain no body.

This equality is a property of the experiment, not a general HTTP rule.

---

## 8. Future Extension: Request Body

When request bodies are introduced, reaching `headersEnd` will no longer necessarily mean that the request is complete.

The handler will have to determine the body framing from the parsed request.

For example:

```text
headers
   |
   v
Content-Length: N
   |
   v
forward already received body prefix
   |
   v
recv / forward remaining bytes
   |
   v
exactly N body bytes processed
   |
   v
request complete
```

The body should be streamed whenever possible rather than accumulated as one complete object.

The termination condition is determined by HTTP framing, **not by TCP EOF**.

Therefore this is incorrect as the general model:

```text
read body until recv returns empty ByteString
```

The client may send the complete body and keep the connection open while waiting for the response.

Later framing mechanisms such as chunked transfer encoding require their own termination logic.

---

## 9. Current Architectural Boundary

The important first approximation is:

```text
handleClient
    =
connection lifetime
+
network I/O loop
+
coordination

Wirth
    =
HTTP syntactic recognition

Markov
    =
URI transformation
```

The handler coordinates these components but should not absorb their internal logic.

Its desired operational shape remains small:

```text
recv
  ↓
step
  ↓
inspect result
  ↓
recurse / forward / finish
```

This keeps network lifetime management separate from request syntax and transformation semantics.

---

## 10. Working Principle

> One accepted connection has one handler.
>
> The handler owns the connection and its processing state.
>
> `recv` supplies arbitrary chunks of bytes.
>
> Internal automata determine the semantic state of the request.
>
> The handler reacts to their result by reading more data, forwarding, responding, or terminating the connection.

This is the **first approach**.

Keep-alive, multiple requests per connection, request bodies, body framing, forwarding state, half-close behavior, and more advanced connection lifecycle rules are deliberately postponed until the minimal recursive handler is understood and working.