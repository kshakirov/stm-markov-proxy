---
number: 5
state: OPEN
state_reason: 
author: kshakirov
created_at: 2026-08-26T17:37:49Z
updated_at: 2026-08-26T17:38:21Z
closed_at: 
url: https://github.com/kshakirov/stm-markov-proxy/issues/5
labels: []
assignees: []
milestone: 
---

# #5 — Specialized application proxy: define the first executable model

## Context

ADR-0010 фиксирует основной архитектурный принцип:

> **Build the proxy, don’t configure the proxy.**

Wiki `Application-Specialized Proxy` расширяет это направление: application-aware operations, authorization specialization, минимальное информационное представление и selective streaming parsing.

Теперь необходимо перейти от архитектурного тезиса к первому минимальному эксперименту.

## Goal

Определить **первую исполнимую модель специализированного proxy**, не пытаясь сразу проектировать универсальный framework или DSL.

Нужно показать на одном конкретном сценарии цепочку:

```text
Proxy Primitives
        +
Application Model
        +
Policy / Rules
        ↓
Specialization
        ↓
Application-Specific Proxy Automaton
```

## First experiment

Выбрать минимальную прикладную операцию, для которой proxy должен:

1. распознать операцию;
2. извлечь только необходимые для решения данные;
3. принять routing/authorization decision;
4. передать запрос соответствующему backend либо отклонить его.

Желательно выбрать сценарий, где решение зависит не только от HTTP method/path, но и от одного атрибута запроса или body.

Это позволит проверить, действительно ли application-aware модель даёт что-то сверх обычной REST-маршрутизации.

## Questions to answer

В ходе эксперимента определить:

- что является минимальным `Primitive Set`;
- что именно входит в `Application Model`;
- как представляется прикладная `Operation`;
- какие данные реально нужны policy;
- можно ли извлечь их потоково без построения полного объекта;
- какое состояние должен хранить proxy automaton;
- где проходит минимальная граница между proxy и backend application.

## Constraints

На этом этапе **не проектировать заранее**:

- универсальный DSL;
- полный policy language;
- универсальную RPC-модель;
- code generator/framework;
- окончательную систему авторизации.

Эти конструкции должны появляться только тогда, когда их потребует конкретный эксперимент.

## Result

Тикет считается выполненным, когда существует один минимальный работающий application-specific proxy experiment и по его результатам можно явно описать:

```text
Application Model
      ↓
Required Information
      ↓
Proxy Automaton
      ↓
Decision
```

Полученные ограничения и новые архитектурные решения фиксируются отдельными ADR/issues.

