---
number: 4
state: OPEN
state_reason: 
author: kshakirov
created_at: 2026-08-07T05:57:32Z
updated_at: 2026-09-02T16:14:00Z
closed_at: 
url: https://github.com/kshakirov/stm-markov-proxy/issues/4
labels: []
assignees: [kshakirov]
milestone: v0.1-mathematical-core
---

# #4 — # Issue: Реализация побайтового операционного автомата Вирта (FSM) для чтения заголовка запроса


## Статус
**В РАБОТЕ** (Исполнитель: Я)

## Задача
Разработать легковесный побайтовый конечный автомат (FSM) для разбора стартовой строки HTTP-запроса (Request Line) с целью точной изоляции URI до его передачи в вычислительное ядро `MarkovEngine` если надо и вообще заголовков запроса если таковые есть вплоть до тела.

## Требования к реализации
1. **Конфигурация состояний:** Объявить алгебраический тип данных `data ParserState` с четырьмя детерминированными фазами: `Method`, `URI`, `Version`, `Finish`.
2. Затем HeaderName, HeaderValue
3. **Побайтовый конвейер:** Написать чистую функцию перехода, которая принимает текущее состояние, один входящий байт (`Word8`), и возвращает новое состояние.
4. **Критерии переходов:**   - Из `Method` в `URI` по первому пробелу (`0x20`).
   - Из `URI` в `Version` по второму пробелу (`0x20`).
   - Из `Version` в `Finish` по маркеру конца строки (`\r\n`).
4. **Аккумуляция данных:** Обеспечить бережное накопление байт внутри конструктора состояния `URI` без промежуточных аллокаций.

**Связанная веха (Milestone):** `v0.1-mathematical-core`
5. Сделать его потоковым он должен возвращать состояния `Finished`, 'NeededMoreData`, `Error` - чтобы обработчик знал закончен ли разбор и на каком индексе буфера

## Comments

### kshakirov — 2026-08-21T08:31:35Z

уже почти там

### kshakirov — 2026-09-02T16:14:00Z

Зафиксировали внешний **Request Processing Automaton** над Виртом.

Рабочая схема такая:

```text
handleClient: recv chunk
        ↓
Request Processing Automaton
        ├── Wirth Parser
        └── Markov URI Rewriter
        ↓
Accumulated Buffer + Offset Table + Rewritten URI
```

`handleClient` владеет сокетом и повторяет `recv`. Операционный автомат получает
предыдущее состояние и только новый chunk, накапливает логический буфер и
дополняет таблицу абсолютных смещений. Вирту повторно старые байты не скармливаю.

Первый контракт результата: `NeedMoreData | Ready | Error`. После завершения
Вирта Марков получает только диапазон URI и возвращает только новый URI. Полный
request ради локальной замены не пересобираю: результат остаётся геометрией
`Prefix | Rewritten URI | Suffix`, причём `Suffix` может уже содержать байты
тела.

Отдельный вопрос перед реализацией — физика растущего буфера. Наивное
`strict ByteString <> chunk` может копировать всю историю на каждом шаге, так
что zero-overhead здесь сначала проектируем, потом проверяем Core и замерами.

Полный план: [Request Processing Automaton](https://github.com/kshakirov/stm-markov-proxy/wiki/Request-Processing-Automaton).


