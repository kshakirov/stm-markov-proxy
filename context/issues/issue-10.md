---
number: 10
state: OPEN
state_reason: 
author: kshakirov
created_at: 2026-10-09T05:31:04Z
updated_at: 2026-10-23T09:26:07Z
closed_at: 
url: https://github.com/kshakirov/stm-markov-proxy/issues/10
labels: []
assignees: []
milestone: 
---

# #10 — Build a specialized ChainDb TCP-to-Unix-socket proxy with Rake

## Goal

Test the first build-time composition of a specialized proxy:

```text
known Haskell components
        ↓
Ruby / Rake
        ↓
ERB templates
        ↓
generated Main.hs + Cabal description
        ↓
Cabal / GHC
        ↓
specialized ChainDb proxy binary
```

The governing principle is **Build the proxy, don't configure the proxy.** The runtime must not choose its component graph.

## First specialized machine

```text
TCP client
    ↓
raw byte stream
    ↓
Unix Domain Socket
    ↓
ChainDb / Chez listener
```

This machine contains no HTTP processing, Wirth recognizer or Markov rewriter. It does not parse or reinterpret the payload.

## First components

- **TCP Input**: accepts a TCP connection and yields incoming byte chunks.
- **Unix Socket Output**: connects to a configured Unix Domain Socket and forwards those chunks in order.

Do not design a universal component API in advance. Extract only the smallest contract required to connect these two real components.

## Build-time composition

Add an experimental Rake target:

```bash
rake chaindb
```

It should:

1. select only `TCP Input` and `Unix Socket Output`;
2. render `Main.hs` from an ERB template;
3. render the minimal Cabal description required for this executable;
4. invoke Cabal/GHC;
5. produce a specialized executable containing no HTTP/Wirth/Markov path.

Rake composes the machine; Cabal remains the Haskell build system. Ruby and ERB must not be runtime dependencies.

## Experiment stages

### Stage 1: forward flow

Prove byte-preserving forwarding:

```text
TCP client → generated proxy → Unix socket listener
```

### Stage 2: reverse flow

Extend the same connection lifecycle to:

```text
TCP client ⇄ generated proxy ⇄ Unix socket listener
```

Define EOF, half-close, error propagation and cleanup behavior from the observations of these two stages.

## Acceptance criteria

- `rake chaindb` generates ordinary valid Haskell and Cabal inputs and builds the executable.
- The generated executable transfers arbitrary binary chunks from TCP to the Unix socket without HTTP assumptions.
- Fragmentation does not change byte order or contents.
- The resulting build does not import or execute Wirth, Markov or HTTP rewriting code.
- The generated artifacts make the selected component composition visible and inspectable.
- The experiment records the minimal concrete composition contract that emerged.
- Bidirectional forwarding is demonstrated after the one-way path works.

## Out of scope

- optional outputs attached to the existing HTTP proxy;
- POST/PUT body framing;
- a universal proxy DSL or IR;
- a custom template engine;
- runtime plugins or protocol selection;
- automatic component discovery;
- Refal supercompilation.

Refal is a later semantic-specialization stage. This issue establishes the mechanical build-time baseline against which it can be compared.

## Terms introduced

- **Build-time metamachine**: the Rake/ERB layer that selects known components and emits a concrete Haskell build before runtime.
- **ChainDb proxy**: the first specialized raw-stream machine composed as `TCP Input → Unix Socket Output`.

## Comments

### kshakirov — 2026-10-14T18:09:54Z

Сегодня я собрал и проверил первый физический шов специализированного proxy:

```text
TCP client
→ TcpInput
→ ChainDbMain
→ UnixSocketOutput
→ console Unix-socket listener
```

Добавлены два независимых Haskell-кирпича: `Proxy.Transport.TcpInput` и `Proxy.Transport.UnixSocketOutput`. Конкретная машина возникает только в отдельном `ChainDbMain`; HTTP, Wirth и Markov в этот тракт не входят.

Первый живой эксперимент прошёл: proxy принял TCP-соединение на `127.0.0.1:9300`, подключился к `/tmp/chaindb-proxy-test.sock` и передал тестовый chunk в консольный Unix-socket listener. Пока доказан ровно однократный проход до 1024 байт — без заявлений о полном streaming lifecycle.

Главный результат для меня — не сам `recv → sendAll`, а появление настоящих заменяемых кирпичей. Следующий шаг: довести односторонний поток до TCP EOF и проверить payload больше одного chunk. После ручного эталона Rake/ERB механически соберёт эту композицию, а Refal станет следующим, уже семантическим проходом специализации.

### kshakirov — 2026-10-16T10:26:02Z

Сегодня я довёл первый build-time эксперимент до настоящего ChainDb.

Rake теперь собирает два композиционных терма из общего каталога кирпичей:

```text
TcpInput → UnixSocketOutput
TcpInput → NamedPipeOutput
```

ERB генерирует `Main.hs` и отдельный Cabal package, а GHC проверяет явную Kleisli-композицию в `IO`. Оба сгенерированных бинарника прошли живую проверку одного chunk. FIFO-вариант через временную ссылку дошёл до уже работающего `my_test_pipe`, и ChainDb принял сообщение штатным parser/dispatcher-трактом.

На этом этапе доказано ровно следующее: Rake выбирает кирпичи и строит композиционный терм, ERB отображает его в Haskell, Cabal/GHC получают обычный проект, а специализированный бинарник передаёт один chunk в выбранный output. Цикл, несколько клиентов и полный lifecycle пока не заявляются.

Следующий план:

1. Описать весь путь генерации и живой проверки одним воспроизводимым документом.
2. Отделить транспортные кирпичи `open/read/write` от runner, которому принадлежат цикл и состояние.
3. Определить ownership и lifecycle: EOF, закрытие ресурсов, ошибки output, повторное чтение и сохранение соединения.
4. Проверить многокусковую однонаправленную передачу.
5. Вставить `IdentityBytes` и сравнить прямую композицию с `TcpInput → IdentityBytes → Output`.
6. Пока использовать Kleisli-композицию внутри `IO`; обобщать модель только при появлении реальной несовместимой границы.
7. Позже оформить небольшой специализированный proxy на стороне ChainDb, не расширяя его раньше необходимости.

Сегодня хорошо сошлись теория и практика: композиция перестала быть только схемой и стала исполняемой машиной.

### kshakirov — 2026-10-23T09:26:07Z

Проверил ручную итерацию в `proxy-lab`: TCP → named pipe → работающая ChainDb. Через одно TCP-соединение отправил три `!get::2#` с паузами по 5 секунд; все три обработаны базой. После EOF итерация завершилась, клиентский и слушающий сокеты закрылись.

Разделил открытие, однотактовое чтение и закрытие ресурса. В общем состоянии храню сокеты и текущий ByteString. `compose` пропускает запись при `Left`, `iter` повторяет такт при `Right`. Старый тракт сохранён рядом. Это ручной эталон для будущего шаблона Rake/ERB; генератор итерации пока не менял.

Быстрые команды могут объединяться в одном чтении FIFO, а текущая база разбирает полученный буфер как одну команду. Паузы помогли проверить именно повторение тактов; фрейминг этим не решён.

Дальше: гарантированное освобождение ресурсов через bracket, затем отдельный цикл accept и параллельный обработчик каждого соединения со своим состоянием и Iter(Read → Write). Listener принадлежит серверу, клиентский сокет — обработчику. Для нескольких писателей в общий FIFO отдельно определим порядок и границы сообщений. После проверки ручной конструкции перенесём её в генератор.


