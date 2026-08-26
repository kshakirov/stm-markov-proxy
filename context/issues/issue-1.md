---
number: 1
state: CLOSED
state_reason: COMPLETED
author: kshakirov
created_at: 2026-08-05T18:20:40Z
updated_at: 2026-08-05T18:22:22Z
closed_at: 2026-08-05T18:22:22Z
url: https://github.com/kshakirov/stm-markov-proxy/issues/1
labels: []
assignees: [kshakirov]
milestone: v0.1-mathematical-core
---

# #1 — Сетевой каркас диспетчера

## Задача
Поднять базовый сетевой контур L7-прокси.

## Требования
1. Открыть IPv4-сокет на localhost (порт 9000).
2. Запустить бесконечный диспетчерский цикл `forever` с приемом клиентов через `S.accept`.
3. Изолировать обработку каждого клиента в легковесном потоке `forkIO` внутри монады `ProxyM`.
4. Реализовать функцию `handleClient` с отправкой константной HTTP-заглушки через `sendAll` и обязательным закрытием дескриптора сокета через `S.close`.
5. Проверить пропускную способность рантайма под нагрузкой утилиты `wrk`.

**Связанная веха:** `v0.1-mathematical-core`


