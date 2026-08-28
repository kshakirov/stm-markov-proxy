# From Application Model to Executable Proxy

## Зачем нужна эта страница

ADR-0010 фиксирует принцип:

> **Build the proxy, don’t configure the proxy.**

Но слово **Build** требует отдельного объяснения.

Речь идёт не только о том, чтобы исключить ненужные библиотеки из итогового бинарника.

Более сильная идея состоит в том, чтобы **построить программу proxy из набора примитивов и знания о конкретном приложении**, разрешив максимально возможное количество решений до начала runtime.

В пределе конкретный proxy является не универсальным proxy с конфигурацией, а **скомпилированной специализированной машиной**.

---

# 1. Общая картина

Процесс концептуально делится на две фазы:

```text
                    BUILD TIME

 Primitive Set          Application Model
      │                       │
      │                       │
      └──────────┬────────────┘
                 ▼
        Specializer / Builder
                 │
                 ▼
        Specialized Proxy
          Program / IR
                 │
                 ▼
              Compile
                 │
═════════════════╪══════════════════════
                 │
               RUNTIME
                 ▼
         Proxy Executable
                 │
                 ▼
       bytes → decisions → bytes
```

Главное разделение проходит между **build time** и **runtime**.

Всё, что может быть определено заранее из Application Model, желательно разрешить во время построения proxy.

Runtime должен выполнять уже построенную программу, а не заново интерпретировать общую модель приложения.

---

# 2. Primitive Set

`Primitive Set` — набор элементарных строительных операций proxy.

Например:

```text
parse-http
recognize-operation
extract-json-field
authorize
route
rewrite
forward
reject
```

Физически на первом этапе они могут быть обычными Haskell-модулями:

```text
STMProxy.Primitive.HTTP
STMProxy.Primitive.Stream
STMProxy.Primitive.JSON
STMProxy.Primitive.Auth
STMProxy.Primitive.Route
```

Однако архитектурно Primitive Set — не просто библиотека.

Его можно рассматривать как **базис операций, из которых строятся специализированные proxy-программы**.

Конкретный proxy использует только необходимое ему подмножество примитивов.

---

# 3. Application Model

`Application Model` описывает требования конкретного приложения к proxy.

Например, модель может сообщать:

```text
Operation: EditDocument

transport:
    HTTP PATCH

recognition:
    /documents/{id}

required information:
    subject.role
    document.ownerId

policy:
    may-edit-document

success:
    forward DocumentsBackend

failure:
    reject
```

Форма этого описания пока **не определена**.

Это может быть:

- Haskell value;
- набор typed combinators;
- отдельный DSL;
- другое формальное представление.

На первом этапе не требуется создавать новый язык.

Главное свойство Application Model:

> **Это материал для построения программы, а не обязательно конфигурация runtime.**

После специализации модель может вообще отсутствовать в работающем proxy.

---

# 4. Builder / Specializer

`Builder` получает:

```text
Primitive Set
      +
Application Model
```

и строит конкретную proxy-программу.

Именно здесь находится смысл слова **Build** в ADR-0010.

Builder может заранее определить:

- какие примитивы необходимы;
- какие операции существуют;
- какие parser states нужны;
- какие поля необходимо извлекать;
- какая policy относится к операции;
- куда должен идти успешный запрос;
- какие состояния и переходы вообще достижимы.

Таким образом, часть вычислений переносится из runtime в build time.

---

# 5. Что исчезает из runtime

Рассмотрим универсальную модель.

При каждом запросе runtime мог бы выполнять:

```text
request
   ↓
find operation
   ↓
find policy
   ↓
interpret policy
   ↓
determine required fields
   ↓
select parser
   ↓
find route
   ↓
execute
```

Но если эти отношения известны при построении proxy, повторять эту работу при каждом запросе нет необходимости.

Builder может построить непосредственно:

```text
request
   ↓
recognize EditDocument
   ↓
extract ownerId
   ↓
authorize
  /       \
 no       yes
 │         │
reject   forward DocumentsBackend
```

Таким образом:

```text
BUILD TIME                         RUNTIME

Which policy?        ───────►      already known
Which fields?        ───────►      already known
Which parser?        ───────►      already known
Which route?         ───────►      already known
Which transitions?   ───────►      already constructed
```

Runtime получает уже специализированную машину.

---

# 6. Proxy Automaton

Результат специализации можно рассматривать как **proxy automaton**.

Например:

```text
             ┌───────────────┐
             │ Receive bytes │
             └───────┬───────┘
                     │
                     ▼
               Parse request
                     │
                     ▼
             EditDocument ?
                /         \
              no           yes
              │             │
             ...            ▼
                       Extract ownerId
                             │
                             ▼
                         Authorize
                         /       \
                       deny      allow
                        │          │
                        ▼          ▼
                     Reject      Forward
```

Это уже не описание того, как proxy следует настроить.

Это **конкретная программа обработки потока**.

---

# 7. Selective parsing как следствие специализации

Application Model и policy могут определить, какая информация реально необходима.

Если для `EditDocument` требуется только:

```text
subject.role
document.ownerId
```

то большой JSON body потенциально не нужно полностью превращать в объект.

Специализированная машина может иметь путь:

```text
byte stream
     ↓
streaming JSON automaton
     ↓
find ownerId
     ↓
policy decision
```

Остальные поля не обязаны становиться частью внутреннего состояния proxy.

Таким образом, специализация касается не только маршрутизации.

Она может определять даже **какую информацию необходимо извлечь из входного потока**.

---

# 8. Первый минимальный вариант

Необходимо избегать преждевременного создания собственного compiler infrastructure.

Первый эксперимент может выглядеть максимально просто:

```text
Haskell Primitive Modules
          +
Haskell Application Description
          ↓
Static Composition
          ↓
GHC
          ↓
Specialized Proxy Executable
```

Здесь:

- Haskell является языком описания;
- обычные модули являются Primitive Set;
- Haskell type system помогает проверять композицию;
- GHC выполняет обычную дальнейшую компиляцию.

Никакой отдельный DSL или собственный backend пока не требуется.

---

# 9. Возможная дальнейшая траектория

Если эксперименты покажут необходимость более явного представления, между Application Model и executable может появиться собственный промежуточный язык:

```text
Application Description
          ↓
Typed Proxy IR
          ↓
Proxy Automaton
          ↓
Lowering
          ↓
Native Code
```

Тогда архитектурные роли становятся особенно явными:

```text
Primitive Set       ≈ базис операций

Application Model   ≈ исходная программа

Builder             ≈ specializer/compiler

Proxy IR            ≈ промежуточное представление

Proxy Automaton     ≈ специализированная машина

Executable          ≈ физическое воплощение машины
```

Это **исследовательская возможность**, а не принятое архитектурное решение.

DSL, IR и собственный compiler должны появляться только в том случае, если их потребует практика.

---

# 10. Что означает отсутствие universal proxy runtime

Фраза «скомпилировать proxy» не означает буквального отсутствия всякого runtime.

Например, при использовании GHC остаются:

- Haskell RTS;
- операционная система;
- sockets;
- memory management;
- системные библиотеки.

Цель другая:

> **Не иметь собственного универсального proxy runtime, который во время исполнения интерпретирует полную Application Model.**

Proxy должен выполнять специализированную программу, уже построенную для конкретного приложения.

---

# 11. Отличие от обычной модульной сборки

Обычная модульность говорит:

```text
Program imports A, B, C

→ binary contains required implementation
```

Specialized Proxy идёт дальше.

Если приложению нужны только определённые возможности:

```text
Application requires A and C
```

то желательно получить:

```text
specialization
      ↓
automaton constructed from A and C
      ↓
states and transitions associated with B do not exist
```

Таким образом, устраняется не только ненужный код.

Устраняется **ненужное поведение и ненужные состояния машины**.

---

# 12. Центральная гипотеза

На текущем этапе можно сформулировать следующую исследовательскую гипотезу:

> **Application Model может оказаться не конфигурацией proxy, а программой на специализированном языке.**
>
> **Primitive Set может оказаться базисом этого языка.**
>
> **Builder может оказаться компилятором специализированных proxy-машин.**

Эта гипотеза должна быть проверена экспериментально.

Необходимо начать с минимальной Haskell-композиции и посмотреть, какие сущности действительно возникнут из практики.

---

# 13. Первый эксперимент

Первый эксперимент должен проверить всю вертикаль:

```text
Application Model
        ↓
Specialization
        ↓
Proxy Automaton
        ↓
Executable
        ↓
Runtime Decision
```

Для этого достаточно одной операции, например:

```text
EditDocument
```

для которой решение зависит от одного атрибута request body.

Эксперимент должен показать:

1. как операция описывается;
2. какие primitives выбираются;
3. как определяется необходимая информация;
4. как строится конечная композиция;
5. что остаётся в runtime;
6. что удалось устранить на build time.

---

# Ключевая идея

`Build the proxy` означает не просто:

> выбрать нужные библиотеки и собрать бинарник.

Более сильная цель:

> **использовать знание о конкретном приложении для построения минимальной специализированной программы обработки потока, а затем скомпилировать эту программу в исполнимый proxy.**

В пределе runtime не спрашивает, **что ему делать**.

Эта работа уже была выполнена при построении машины.