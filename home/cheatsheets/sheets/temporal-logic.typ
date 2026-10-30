#import "lib/style.typ": sheet
#show: sheet.with(title: "Temporal logic · fairness · Quint")

== Операторы

#table(
  columns: (auto, auto, 1fr),
  [*TLA+*], [*Quint*], [*смысл*],
  [`[]P`], [`always(P)`], [P во всех состояниях поведения],
  [`<>P`], [`eventually(P)`], [P когда-нибудь станет истинным],
  [`[]<>P`], [`always(eventually(P))`], [P истинно снова и снова (бесконечно часто)],
  [`<>[]P`], [`eventually(always(P))`], [с какого-то момента P навсегда],
  [`P ~> Q`], [`P leadsTo Q`], [каждый раз после P когда-нибудь Q \ = `[](P => <>Q)`],
  [`P'`, `x' = e`], [`x' = e`], [значение в следующем состоянии],
  [`[A]_v`], [`A.orKeep(v)`], [шаг A или v не меняется (stuttering)],
  [`<<A>>_v`], [`A.mustChange(v)`], [шаг A, и v меняется],
  [`ENABLED A`], [`enabled(A)`], [A возможно в текущем состоянии],
  [`UNCHANGED v`], [`v' = v` для каждой], [в Quint нет — присваивать всё],
)

== Safety и liveness

- *Safety* — «плохое никогда не случится». Нарушение видно на *конечном* префиксе трассы. Проверяется как *инвариант*: `--invariant=...`
- *Liveness* — «хорошее когда-нибудь случится». Контрпример — *бесконечное* поведение: «лассо» (путь + цикл). Проверяется как *temporal*-свойство: `--temporal=...`
- Любое свойство = safety ∧ liveness.

== Stuttering

Спецификация `Init /\ [][Next]_vars` разрешает шаги, где ничего не меняется, в том числе *бесконечно*. Поэтому без fairness liveness *не выполняется никогда*: «никто ничего не сделал» — всегда контрпример.

== Fairness

#table(
  columns: (auto, 1fr),
  [*weak* \ `WF_v(A)` \ `weakFair(A, v)`], [если A *непрерывно* возможно, оно рано или поздно произойдёт],
  [*strong* \ `SF_v(A)` \ `strongFair(A, v)`], [если A возможно *бесконечно часто* (пусть с перерывами), оно произойдёт],
)

- WF хватает, когда работа, раз появившись, не исчезает до выполнения (очередь событий, шаг процесса).
- SF нужна, когда A то включается, то выключается из-за других (захват лока в гонке).
- Fairness — *допущение*, не проверяемое свойство: «если процесс не встаёт навсегда, то…». Обеспечивается кодом и эксплуатацией.
- Fairness ставят на *систему* (процессы, обработчики), не на *окружение* (пользователи, время): ставка или конец лота могут не случиться.

== Где fairness

TLA+ — в спецификации:
```
FairSpec == Init /\ [][Next]_vars
         /\ WF_vars(PM) /\ WF_vars(Reactor)
```
Quint — в посылке свойства:
```
temporal fairness =
  weakFair(pm, vars) and weakFair(reactor, vars)
temporal live =
  fairness implies eventually(done)
```
`vars` — кортеж *всех* переменных (аналог `_vars`).

== Шаблоны свойств

#table(
  columns: (1fr, auto),
  [*хочу сказать*], [*формула*],
  [никогда X], [инвариант `not(X)`],
  [всегда в итоге дойдёт до X], [`eventually(X)`],
  [после запроса — ответ], [`req leadsTo resp`],
  [сходится и остаётся], [`eventually(always(X))`],
  [не застревает: прогресс снова и снова], [`always(eventually(X))`],
  [X держится, пока не Y], [инвариант на флаге / `leadsTo`],
)

*Ловушка «финал маскирует баг»*: `eventually(always(ok))` проходит, если в конце всё сходится, даже когда *посередине* система долго врёт. Нужен `leadsTo` про каждое промежуточное событие, а «конец» — без fairness (окружение может тянуть вечно).

*Ловушка «выход»*: в `P leadsTo (Q or not P)` выход `not P` разрешает гонку. Чтобы он не прятал баг, P не должно быть обязано закончиться: нет fairness на шаг, который его снимает.

== Red-green

У каждой важной детали — *контрольная* конфигурация без неё, которая *обязана* нарушить *названное* свойство.
- Контроль прошёл / упал не тем → зелёному дизайну не верим.
- Отдельно контроль на fairness: без неё liveness должен падать.

== Quint: команды

```
quint typecheck M.qnt
quint run    --invariant=inv --max-steps=40 M.qnt
quint verify --backend=tlc --invariant=inv M.qnt
quint verify --backend=tlc --temporal=p1,p2 M.qnt
quint compile --target=tlaplus M.qnt
quint repl -r M.qnt::Main   # REPL
```
- `run` — случайная симуляция: *не* доказательство, редкие трассы пропускает.
- `verify` (Apalache) — bounded, `--max-steps`; temporal → предлагает TLC.
- `--backend=tlc` — исчерпывающе, liveness с fairness.
- Конфигурация = модуль: `import M(N = 2, …).* from "./M"`; одна на файл.

== Quint: синтаксис

```
action a = all { cond, x' = x + 1, y' = y }
action b = any { a1, a2 }
nondet v = S.oneOf()   // + guard S != Set()
pure def f(x: int): int = …  // без состояния
def g(l: int): bool = …   // читает состояние
val inv = not(bad)
temporal p = …
type Pos = NoPos | Run({ seq: int }) | Top
match p { | Run(r) => r.seq | _ => 0 }
{ ...r, field: v }     // обновить запись
m.get(k) m.set(k, v) m.setBy(k, f) S.mapBy(f)
l.append(x) l.indices() l[i]  // с 0
f(a, b) == a.f(b)
```
Инфиксно — только встроенные: `and or implies iff leadsTo`.

== Quint: грабли (0.32–0.33)

- `///` у `type` и вариантов → внутренняя ошибка typecheck → `//`.
- `x' = a or b` при трансляции в TLA+ → `(x' = a) \/ b` → выносить в `val`.
- Много модулей-конфигураций в файле → лимит 20 МБ Apalache.
- Встроенные имена (`Rec`, `leadsTo`) нельзя переопределить.
- Потерянная скобка → «Couldn't unify bool and set».
- LSP тащит ядро на версию старше CLI.

== TLA+: грабли

- `Naturals` без унарного минуса: `-1` не парсится.
- `Seq` занято модулем `Sequences`.
- TLC: `-workers auto`, liveness медленнее safety; `CONSTRAINT` урезает пространство, но с liveness ненадёжен.
