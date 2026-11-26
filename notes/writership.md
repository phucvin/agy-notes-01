# Writership Notes

Repository: <https://github.com/phucvin/Writership>  
Language / Platform: C# / Unity (MIT License, Sept 2018, marked *"HEAVILY UNDER DEVELOPMENT"*)

---

## 1. Overview

**Writership** is an experimental reactive state-management library for UI, games, and stateful applications. Inspired by **Rust**, **Redux**, and **SatchelJS**, it aims to combine:

- **Single-writer ownership ("Writership"):** Each state field should have only one place in code that mutates it.
- **Race-free multithreading:** Isolating reads and writes into buffered cells so independent reactive computations can run in parallel.
- **Reactive yet imperative:** Avoiding pure-immutable allocation overhead for game/UI performance.
- **Unidirectional data flow:** Events/ops trigger state computations, which trigger UI/side-effect readers.

---

## 2. Core Primitives (`Assets/Writership/`)

All state and events are created through an `IEngine` and implement `IHaveCells` (`CopyCell`, `ClearCell`):

| Primitive | Role | Key API |
| :--- | :--- | :--- |
| **`El<T>`** | Reactive scalar/value field (`ElWithRaw<T, TRaw>` pairs processed + raw values) | `Read()`, `Write(T)` (marks dirty only when value changes) |
| **`Li<T>`** / **`Ar<T>`** | Reactive `List<T>` and struct `T[]` collections | `Read()` (read-only view), `AsWrite()` (mutable write buffer), `Li<T>.AsWriteProxy()` (diffs before committing) |
| **`Op<T>`** | Transient one-shot event/action (cleared after listeners run) | `Fire(T)`, `TryRead(out T)`, `Unwrap` |
| **`MultiOp<T>`** | Transient event allowing multiple `Fire(T)` calls per update cycle, with optional `reducer` | `Fire(T)`, `Read()` (`IList<T>`), `Reduced` |
| **`Wa`** | Dynamic watcher tracking a field extracted from every item inside a `Li<T>` | `engine.Wa(cd, list, item => item.Field)` |

### Runtime Writership Enforcement (`Writership.cs`)
In `DEBUG` builds, each mutable container holds a `Writership` guard. On the first write, it captures a `System.Diagnostics.StackTrace`; on subsequent writes, it compares stack frames and throws `InvalidOperationException("Cannot write to same at different places")` if another code path mutates the same field (`Op`/`MultiOp` can opt out with `allowWriters: true`).

---

## 3. Execution & Cell-Buffering Model

Listeners subscribe to dependency arrays (`Dep.On(...)`) with a `CompositeDisposable` for cleanup:
- **Worker listeners** (`Computer`, `Worker`, `HeavyWorker`): execute in **parallel** via `ThreadPool`.
- **Main-thread listeners** (`Mainer`, `Reader`, `Writer`, `Firer`, `Guarder`): execute sequentially on the main thread (e.g., Unity UI).
- **`OpMainer` / `OpWorker`**: skip running immediately upon registration.

On each `engine.Update()`, the engine loops (`Process`) until no cells are dirty (with a 1,000-iteration overflow guard):
1. **Notify:** Run triggered worker jobs in parallel, then main-thread jobs sequentially. All reads come from the *read cell*; all writes go to the *write cell* and mark targets dirty.
2. **Clear:** Clear transient `Op` / `MultiOp` values from the read cell.
3. **Copy:** Copy newly dirtied write cells into the read cell (`CopyCell`).

Two engine implementations exist:
- **`SinglethreadEngine`** (2 cells: `Main = 0`, `Write = 1`): Still runs worker jobs in parallel via `ThreadPool`, synchronized within `Update()`.
- **`MultithreadEngine`** (3 cells: `Main = 0`, `Worker = 1`, `Write = 2`): Experimental background-thread computation between frames; marked `[Obsolete("Unresolved unsync when reader read a field write in computer")]`.

### Examples & Tests in the Repo
- **UI examples:** `Counter`, `TodoList`, `TwoWay`, `Http`, `Inventory`, `Scenes` (navigation stack, loading transitions, confirm dialogs).
- **Game / ECS-style examples:** `SimpleBattle` (entities, health, armor, damage reflection, modifiers) and `Tests/MultipleEngines.cs` (separate `Physics` and `Sprite` engines).

---

## 4. Evaluation: Strengths & Limitations

### What's Good
- **Single-writer ownership** makes state transitions predictable and easy to trace.
- **Double-buffered read/write cells** allow lock-free parallel reads during a wave.
- **Imperative mutation inside reactive nodes** keeps allocations low compared to pure immutable trees.

### Limitations in This Prototype
1. **Runtime `StackTrace` checks are brittle:** Only active in `DEBUG`, only catch executed paths, and require ad-hoc exceptions (e.g., `UnityEngine.UI`). Compile-time or scheduler-level checks are much stronger.
2. **No topological sorting ("glitches"):** Wave-based `Notify → CopyCells` propagation can evaluate diamond dependencies multiple times with inconsistent intermediate values, or spin on cycles until hitting the 1,000-iteration limit.
3. **Synchronization & copy overhead:** `ThreadPool` + `WaitHandle.WaitAll` per wave has non-trivial overhead for tiny tasks, and full-collection copying in `Li<T>`/`Ar<T>` doesn't scale to large collections.
4. **Cross-frame pipelining bugs:** As seen in `MultithreadEngine`, pipelining worker computations across frames creates subtle sync issues when main-thread readers depend on worker-computed fields.

---

## 5. Similar Industry Ideas & Projects

- **Game Engines / ECS (Single-writer + parallel scheduling):**
  - **Bevy ECS (Rust)**, **Unity DOTS / ECS + Jobs (C#)**, **Flecs (C/C++)** — explicit read/write access declarations (`&T` vs `&mut T`, `[ReadOnly]`), automatic parallel scheduling, and deferred command buffers.
- **Fine-Grained Reactive State & Incremental Computation:**
  - **Signals** (**SolidJS**, **Preact Signals**, **Angular Signals**, **Vue 3**, **Svelte 5 Runes**) — glitch-free reactive graphs using topological sorting / push-pull evaluation.
  - **MobX** & **SatchelJS** — imperative mutations inside actions with reactive derivations / strict unidirectional flow.
  - **Salsa (Rust)** & **Jane Street Incremental (OCaml)** — incremental computation graphs for compilers and trading systems.
- **Single-Writer Concurrency Patterns:**
  - **LMAX Disruptor / Single Writer Principle** — eliminating write contention by giving one owner write access per memory region.
  - **Rust Ownership & Borrowing** — static compile-time enforcement of "many readers or one writer."
  - **Actor Model** (**Erlang/OTP**, **Akka**, **Orleans**, **Swift Actors**) — single-writer encapsulated state communicating via messages.
- **Synchronous Dataflow & Hardware Design:**
  - **Lustre**, **Esterel**, **Verilog / VHDL** — discrete clock ticks reading current registers, writing next-cycle registers, and flipping on the clock edge (very close to Writership's read/write cell loop).

---

## 6. Problems Solved by the Writership Model

- **"Who mutated this?" (Action-at-a-distance):** Enforces a single authoritative owner per state field; other systems express intent via `Op` / `MultiOp` instead of mutating state directly.
- **Lock-free parallel computation without full immutability:** Single-writer eliminates write–write races, while double-buffered read/write cells eliminate read–write races within a wave—allowing imperative in-place buffer mutation (`AsWrite()`) with lower GC pressure than pure immutable trees.
- **Order-dependent bugs & re-entrancy:** Wave-based `Read → Write → Copy` gives every listener in wave *N* the same committed snapshot, avoiding synchronous cascading re-entrancy and subscription-order sensitivity.
- **Decoupling UI from domain logic:** Separating `Op` (intent) → `Worker/Computer` (state transitions) → `Main/Reader` (UI/side effects) keeps heavy computation off the main thread.

---

## 7. Design Challenges (Multiple Children, Dynamic UI, & Scale)

### Multiple Children ("Many-to-One" Fan-In)
- Children cannot write directly to a shared parent `El<T>` (e.g., many enemies damaging one player, multiple child items updating `selectedId` or `errors`); they must fire into a shared `MultiOp<T>` folded by the parent's single writer.
- **Non-deterministic ordering:** Non-commutative ops fired in the same wave (especially from parallel workers) need explicit priorities, tie-breakers, or commutative/CRDT-like reducers.
- **Boilerplate:** Every cross-cutting interaction requires defining an `Op` type and wiring it into the owner.

### Dynamic UI & Component Trees
- **Parent vs. child ownership ("Check All" problem):** If each child row owns `item.isChecked`, a parent "Check All" action cannot write it directly (must broadcast an `Op`). If the parent owns the whole `Li<Item>`, children lose encapsulation and single-item edits trigger list-level writes/diffs.
- **Dynamic lifecycles & mid-wave creation:** Dynamically mounting/unmounting UI nodes requires careful `CompositeDisposable` teardown to avoid zombie listeners. Spawning a child in wave 1 raises timing issues: deferring its first render to next frame causes a 1-frame uninitialized flash, while running mid-wave mutates the dependency graph during worker execution.
- **Nested dynamic dependencies:** Watching fields across nested collections (`List<Category>` → `List<Item>` → `El<Price>`) makes manual `Wa` wiring brittle, and keyed reconciliation is needed to avoid recreating child widgets on list updates.
- **Two-way UI bindings:** Native widgets (text inputs, sliders, drag gestures) hold mutable state; routing every keystroke through `Widget → Op → Wave → El → Widget` risks feedback loops, 1-frame input lag, or cursor jumps unless ephemeral local UI state is separated from committed state.

### Broader Architectural Challenges
- **Glitches (diamond dependencies):** Without topological sorting, wave-based propagation can evaluate downstream nodes twice with inconsistent intermediate values—causing wasted UI work or duplicate side effects.
- **Atomic multi-field / cross-entity transactions:** Operations spanning two writers (e.g., moving an item from `Inventory` to `Equipment`) require cross-wave coordination and rollback logic; merging them under one writer drifts back toward a monolithic store.
- **Granularity vs. overhead:** Coarse cells cause full-buffer copies and over-notification; overly fine cells create thousands of tiny jobs where synchronization overhead outweighs the work.
- **Enforcement mechanism:** Runtime `StackTrace` checks are debug-only and brittle around shared helpers. Splitting each cell into capability handles—a private `Writer<T>` for the owner and a shareable `Reader<T>` for everyone else—enforces single-writer at compile time with zero runtime cost.
