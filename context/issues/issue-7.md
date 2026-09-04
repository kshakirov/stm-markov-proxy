---
number: 7
state: OPEN
state_reason: 
author: kshakirov
created_at: 2026-09-04T03:51:00Z
updated_at: 2026-09-04T07:20:46Z
closed_at: 
url: https://github.com/kshakirov/stm-markov-proxy/issues/7
labels: []
assignees: []
milestone: 
---

# #7 — Make handleClient a recursive connection-processing loop and other fixes

# Make `handleClient` a recursive connection-processing loop

## Goal

Replace the current one-shot `handleClient` with the first correct connection lifecycle loop.

The purpose of this ticket is not to implement complete HTTP connection handling.

The purpose is to expose the whole processing pipeline from the top level:

```text
accept
  ↓
handleClient
  ↓
recv
  ↓
Request Processing Automaton
  ├── Wirth Parser
  └── Markov URI Rewriter
  ↓
NeedMoreData | Ready | Error
  ↓
recv again | forward/respond | terminate
```

`handleClient` must become the owner and coordinator of this loop.

---

## Current Problem

The current handler is effectively one-shot:

```text
handleClient
  ↓
recv 1024
  ↓
process received bytes
  ↓
return
```

This accidentally assumes that one `recv` contains everything required to process the request.

TCP provides no such guarantee.

A request line, URI, headers, CRLF sequence, or later request body may cross arbitrary `recv` boundaries.

---

## Required First Approach

One accepted connection gets one `handleClient`.

The handler remains alive while processing that connection and recursively continues when more bytes are required.

Conceptually:

```text
handleClient state
        ↓
      recv
        ↓
   +----+------------------+
   |                       |
 empty                   chunk
   |                       |
   v                       v
 TCP EOF          Request Processing Step
                           |
             +-------------+-------------+
             |             |             |
        NeedMoreData      Ready          Error
             |             |             |
             v             v             v
      handleClient      next action    terminate
       newState
```

---

## Responsibilities

### `handleClient`

Owns:

- client socket;
- connection lifetime;
- `recv`;
- current processing state;
- invocation of the Request Processing Automaton;
- reaction to `NeedMoreData`, `Ready`, and `Error`.

It should remain a coordinator rather than contain HTTP parsing or URI rewriting logic.

### Request Processing Automaton

Receives:

```text
previous state + new Input Chunk
```

and returns the updated processing state/result.

It coordinates the existing Wirth parser and Markov URI rewriter.

### Wirth

Remains responsible for HTTP syntactic recognition and structural boundaries.

It must receive only bytes not processed previously.

### Markov

Remains responsible only for URI transformation.

---

## EOF Semantics

An empty `ByteString` returned by `recv` means TCP stream EOF:

```text
B.null chunk
    ↓
connection EOF
```

It must not be treated as the general HTTP request terminator.

---

## Scope of This Ticket

For this first implementation, support the currently restricted experiment:

```text
one connection
    ↓
one request
    ↓
request without body
    ↓
headers complete
    ↓
request prepared
    ↓
respond / forward
    ↓
close connection
```

Therefore, **for this experiment only**, completion of headers may be treated as completion of the request.

Do not implement yet:

- keep-alive;
- multiple requests per connection;
- `Content-Length` body processing;
- chunked transfer encoding;
- general body framing;
- full forwarding automaton;
- universal connection state machine.

The structure introduced here must merely leave a natural place for those later stages.

---

## Desired Property

The handler must no longer depend on how TCP divided the request into chunks.

For the same logical request:

```text
request
```

all of these must be equivalent from the processing point of view:

```text
[request]
```

```text
[part1] [part2]
```

```text
[p1] [p2] [p3] ... [pN]
```

The recursive handler provides the outer lifecycle necessary for this property.

---

## Acceptance Criteria

- `handleClient` is invoked once for an accepted connection.
- It performs `recv`.
- Empty `ByteString` terminates connection processing.
- Non-empty input is passed into the request-processing pipeline.
- `NeedMoreData` preserves the returned state and causes another `recv`.
- Previously processed bytes are not fed into Wirth again.
- `Ready` terminates the current first-stage request-processing loop and proceeds to the existing response/forwarding behavior.
- `Error` terminates processing according to the current minimal failure policy.
- HTTP parsing details remain outside `handleClient`.
- URI rewriting details remain outside `handleClient`.
- The top-level code visibly expresses the complete lifecycle:

```text
recv → process → result → recurse / act / terminate
```

---

## Architectural Intent

This ticket establishes `handleClient` as the **connection-level coordinator**.

It should make the runtime pipeline visible from top to bottom before more HTTP functionality is added.

The desired shape is deliberately simple:

```text
accept
   ↓
connection handler
   ↓
network input
   ↓
request automaton
   ↓
specialized processing
   ↓
network action
```

Once this skeleton is correct, body streaming, forwarding, and later connection lifecycle features can be inserted into explicit stages instead of growing organically inside a one-shot handler.

## Comments

### kshakirov — 2026-09-04T07:20:46Z

Сегодня собрал первый живой сквозной контур обработчика — уже не макет на одном
`recv`, а настоящий цикл жизни соединения:

```text
recv chunk
    ↓
Request Processing Automaton
    ↓
NeedMoreData → сохранить buffer + Wirth state → recv дальше
Ready         → ответить и закрыть соединение
Error         → применить временную failure policy и закрыть соединение
TCP EOF       → закончить обработку и закрыть сокет
```

Что уже сделано:

- один `handleClient` остаётся жить внутри принятого соединения;
- полный логический request buffer переносится через рекурсивные вызовы;
- состояние Вирта тоже переносится между вызовами;
- Вирт получает только новый `Input Chunk`, старые байты повторно ему не
  скармливаются;
- `NeedMoreData`, `Finished` и `Error` разведены на уровне внешнего автомата;
- пустой результат `recv` трактуется как TCP EOF, а сокет закрывается;
- host и port слушателя теперь действительно берутся из `Config`.

Проверил это живым запросом с URI примерно в 10 КБ при размере `recv` 1024:

```bash
curl -v "http://127.0.0.1:8989/api/v1/users/123/orders?big=<10000 байт A>"
```

Получен `HTTP/1.1 200 OK`, тело `Hello, world`, время клиента около 7,8 мс.
Такой URI заведомо прошёл через несколько `recv`, поэтому эксперимент
подтверждает главное свойство тикета: состояние переживает границы TCP chunks,
и обработка завершается после того, как Вирт увидел конец заголовков.

Что пока сознательно не сделано:

- Марков ещё не включён в завершённый путь и новый URI не возвращается;
- вместо явной Offset Table пока используется существующий список `parsed`;
- накопитель пока наивно делает `ByteString.concat [buffer, chunk]`, его
  аллокации и стратегию роста ещё предстоит исследовать;
- нет лимитов request line / headers / общего удерживаемого буфера;
- нет настоящей error response — используется временная заглушка `200 OK`;
- выбор backend сейчас выполняется при каждом рекурсивном заходе, а должен быть
  привязан к соединению или готовому запросу;
- body framing, forwarding, keep-alive и несколько запросов на соединении не
  входят в сегодняшний эксперимент;
- длинный URI проверен сквозным ручным тестом, систематические тесты всех мест
  разреза ещё нужны.

Итого: lifecycle-каркас Issue #7 уже работает на реальном многокусковом входе.
Закрывать тикет рано — сначала уберу перечисленные хвосты в пределах его
acceptance criteria, не затаскивая сюда будущий forwarding automaton.


