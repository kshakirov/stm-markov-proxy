# Ruby as a Build-Time Metamachine

## Контекст

Архитектура STM Markov Proxy следует принципу:

> **Build the proxy, don't configure the proxy.**

Конкретный proxy должен строиться из набора примитивов и модели приложения, после чего компилироваться в специализированный executable.

При обсуждении физической реализации этой идеи возник естественный вопрос:

> На каком языке должна описываться и выполняться сама процедура построения proxy?

Первоначально можно предположить, что поскольку runtime написан на Haskell, механизм композиции также должен находиться внутри Haskell.

Однако это смешивает две различные вычислительные задачи.

---

# 1. Два разных вычисления

В системе присутствуют как минимум два принципиально разных вычисления.

Первое:

```text
Какую машину построить?
```

Второе:

```text
Как построенная машина должна обрабатывать поток?
```

Это разные уровни.

```text
BUILD TIME                         RUNTIME

выбрать primitives                читать bytes
выбрать composition               выполнять transitions
построить программу               принимать decisions
выбрать dependencies              переписывать fragments
вызвать compiler                  пересылать stream
        │
        ▼
   proxy binary
```

Поэтому нет необходимости использовать один язык для обоих уровней.

---

# 2. Ruby и Haskell выполняют разные роли

Предварительная архитектурная модель:

```text
Ruby / Rake
     │
     │ constructs
     ▼
Haskell Proxy Program
     │
     │ GHC
     ▼
Specialized Proxy Binary
     │
     │ executes
     ▼
Byte Stream
```

Роли языков различны.

## Ruby

Ruby работает на **meta-level**.

Он отвечает на вопрос:

> Какую конкретную программу необходимо построить?

Ruby может:

- предоставить небольшой DSL;
- выбрать необходимые primitives;
- определить application-specific composition;
- выбрать Haskell modules;
- создать или параметризовать `Main`;
- сформировать build graph;
- вызвать GHC;
- произвести конкретный executable.

Ruby необходим только во время построения.

В runtime его нет.

## Haskell

Haskell является языком реализации самой proxy-машины.

Он предоставляет:

- streaming primitives;
- parsers;
- STM/concurrency primitives;
- rewrite operations;
- routing;
- authorization primitives;
- forwarding;
- typed composition;
- runtime behaviour.

Haskell отвечает уже на другой вопрос:

> Как должна работать выбранная proxy-машина?

---

# 3. Rake как ближайшая модель

Ближайшая практическая аналогия — Rake.

Например, описание proxy может со временем выглядеть концептуально так:

```ruby
proxy :documents do
  use :http_parser
  use :uri_rewrite
  use :authorization
  use :stream_forward

  rule :edit_document
end
```

После чего:

```text
rake documents
```

означает:

```text
read application description
        ↓
select primitives
        ↓
construct Haskell composition
        ↓
invoke GHC
        ↓
build/documents-proxy
```

Результатом выполнения Ruby-программы является **не конфигурационный файл**, а другая программа.

---

# 4. Принципиальное отличие от конфигурации

Нежелательная модель:

```text
Ruby DSL
    ↓
config
    ↓
Universal Haskell Proxy
    ↓
runtime interpretation
```

Это фактически возвращает нас к универсальному конфигурируемому proxy.

Предпочтительная модель:

```text
Ruby DSL
    ↓
specialization
    ↓
Concrete Haskell Program
    ↓
GHC
    ↓
Concrete Proxy Binary
```

После сборки Ruby DSL и Application Model могут полностью исчезнуть.

Полученный proxy не обязан знать, **как стать другим proxy**.

Он уже является конкретной машиной.

---

# 5. Динамический язык как метамашина

Этот эксперимент представляет интерес не только для архитектуры proxy.

Он демонстрирует одну возможную роль динамических языков программирования.

Обычно сравнение dynamic/static languages сводится к вопросам:

- typing;
- syntax;
- runtime checks;
- performance;
- convenience.

Здесь возникает другой аспект.

Ruby оказывается удобен как:

> **машина, вычисляющая структуру другой программы.**

Его объектом вычисления становится не только пользовательское значение.

Объектом вычисления может стать **сама будущая вычислительная машина**.

```text
Ruby computation
       ↓
Haskell program
       ↓
native executable
       ↓
runtime computation
```

В этом смысле Ruby выступает как **build-time metamachine**.

---

# 6. Последовательная специализация

Архитектуру можно рассматривать как последовательное уменьшение универсальности:

```text
Ruby
 │
 │ chooses structure
 ▼
Haskell Program
 │
 │ compilation
 ▼
Specialized Proxy
 │
 │ execution
 ▼
Concrete State Transitions
```

На верхнем уровне существует большая свобода выбора.

Ruby может построить множество различных proxy-программ.

После построения Haskell-программа уже значительно более определена.

После компиляции конкретный proxy ещё более специализирован.

Во время обработки запроса остаётся только необходимое runtime-вычисление.

Таким образом:

```text
universality
     ↓
specialization
     ↓
specialization
     ↓
execution
```

---

# 7. Почему не только Haskell

Теоретически весь механизм можно реализовать средствами Haskell.

Возможны:

- combinators;
- embedded DSL;
- Template Haskell;
- staged programming;
- typed intermediate representations.

Поэтому утверждение:

> «Haskell не способен построить такую систему»

было бы неверным.

Интерес представляет другой вопрос:

> **Какова стоимость выражения конкретной вычислительной задачи средствами данного языка?**

Задача построения программ динамична по своей природе:

```text
choose
combine
generate
invoke
inspect
rebuild
```

Ruby предоставляет для такой деятельности чрезвычайно пластичную среду.

Haskell, напротив, особенно интересен после того, как структура машины уже определена и требуется строгая реализация её поведения.

Поэтому использование двух языков здесь может быть не компромиссом, а отражением **двух различных вычислительных ролей**.

---

# 8. Связь с компаративистикой языков

Этот пример даёт более содержательный критерий сравнения языков, чем список language features.

Вместо вопроса:

> Может ли язык X выразить вычисление Y?

можно исследовать:

> Насколько естественным представлением вычисления Y является язык X?

Формальная вычис