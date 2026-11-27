# WasmGC Cross-Module Memory Sharing & Runtime Composition vs. Optrich VM 02

Notes on how WebAssembly GC (WasmGC) enables sharing memory/objects across Wasm modules and instances for runtime composition, and how those options compare to `optrich-vm-02`'s capability-safe handle-and-span memory model.

---

## Core Architectural Premise

Unlike traditional WebAssembly linear memory—which is an explicit `memory` object that modules import/export—the **WasmGC heap is implicit and store-wide**. All module instances living in the same engine/store already share a single GC heap, and the runtime's collector automatically tracks object liveness across module boundaries.

Therefore, the real design choices for **runtime composition** in WasmGC center on **type compatibility, mutability/encapsulation, and threading**.

---

## WasmGC Options for Cross-Module Memory Sharing

### 1. Direct Sharing via Matching `rec` Groups (Zero-Copy, Direct Field Access)
WasmGC uses **iso-recursive structural typing**. Independently loaded modules can pass concrete `(ref $T)` values directly across imports/exports and execute `struct.get`/`struct.set` or `array.get`/`array.set` **if and only if** both modules declare `$T` inside structurally identical `rec` groups (same field types, mutability, supertypes, and positions).

* **How to use:** Emit a small canonical "shared ABI" set of `rec` groups identically in every participating module, keeping private types in separate `rec` groups.
* **Pros:** Zero-copy, no runtime casts on access, native performance, works today in all WasmGC runtimes (V8, SpiderMonkey, JSC, Wasmtime, etc.).
* **Cons:** Fragile if compilers bundle all module types into a single whole-program `rec` group; provides no nominal encapsulation against untrusted modules that replicate the `rec` layout.

### 2. Opaque References (`anyref` / `eqref` / `structref`) + Accessor/Vtable Pattern
Module A exports functions taking/returning abstract top types (`anyref`, `eqref`, `structref`, `arrayref`, or `externref`) and downcasts internally (`ref.cast`) to private concrete GC types.

* **Dynamic dispatch variant:** Combine Option 1 and Option 2 with a small shared "vtable/interface" struct containing typed `funcref`s plus an `anyref` payload (fat pointers / trait objects).
* **Pros:** Works today everywhere WasmGC is supported; zero-copy and GC-tracked across instances; strong encapsulation and ABI stability across independently compiled modules/languages.
* **Cons:** Cross-module accesses pay function call overhead and `ref.cast` checks instead of direct `struct.get`/`struct.set`.

### 3. Shared Tables and Globals of GC References (Runtime Linking & Registries)
Modules import/export `table`s (e.g., `(table (ref null any))` or `(table (ref null $SharedStruct))`) and mutable `global`s holding GC references.

* **How to use:** A host or linker instantiates a shared registry/table and passes it to plugins at instantiation time so modules can register exported objects, closures (`funcref`), or shared state graphs dynamically.
* **Pros:** Idiomatic for plugin registries, dynamic linking, and shared singletons.
* **Cons:** Still relies on Option 1 or Option 2 for element typing.

### 4. Hybrid: Shared Linear Memory Alongside WasmGC
WasmGC modules can still import/export standard linear `memory` (including `shared` linear memory).

* **When to use:**
  * Interop with non-GC modules (Rust, C/C++, Zig).
  * **Multi-threading today:** Baseline WasmGC references are strictly thread-local; shared linear memory (`SharedArrayBuffer`) is currently the only standardized way to share mutable memory across threads.
  * Bulk flat binary data where byte buffers are cheaper than GC object graphs.
* **Cons:** Loses GC lifetime management and type safety for data in linear memory; requires manual allocation/coordination or serialization.

### 5. WebAssembly Component Model (WIT + `resource` Handles)
Standardized multi-language, sandboxed runtime composition via WIT interfaces.

* **How it relates to sharing:** Defaults to **shared-nothing** (lifting/lowering values via the Canonical ABI). WIT **`resource` types** allow passing opaque handles across components without copying the underlying object graph (conceptually similar to Option 2, standardized across languages).
* **Caveat:** Current Canonical ABI primarily targets linear memory; GC-native Canonical ABI support is still evolving.

### Upcoming Proposals to Watch
* **Shared-Everything Threads:** Adds `shared` annotations on GC types, tables, globals, functions, and atomic GC operations so GC objects can cross threads/workers.
* **Type Imports:** Lets a module import an abstract/nominal type directly from another module instead of duplicating `rec` groups or falling back to `anyref` + `ref.cast`.

### WasmGC Quick Decision Guide

| Composition Scenario | Best Option Today |
| :--- | :--- |
| Same language/compiler, trusted modules, max performance | Shared `rec` groups (Option 1) + shared tables/globals (Option 3) |
| Independently compiled modules / plugins, encapsulated state | Opaque `anyref` + accessor/vtable structs (Option 2) |
| Mixing WasmGC with Rust/C++ or needing multi-threading today | Hybrid linear memory (Option 4) |
| Polyglot, untrusted, standardized runtime composition | Component Model + WIT `resource`s (Option 5) |

---

## Comparison with `optrich-vm-02`

Both WasmGC and `optrich-vm-02` share a **single runtime-managed GC heap across all module instances** for zero-copy composition, but they make different tradeoffs:

* **WasmGC:** Statically typed object graphs (`struct`/`array` + `rec` groups).
* **`optrich-vm-02`:** Untyped, capability-tagged split blocks (`mem.alloc(num_bytes, num_refs)`) with zero-copy sub-views (`mem.span`, `mem.ref_span`), in-place read-only attenuation (`mem.readonly` / `ro_handle`), and `funcref` vtables + `call_ref`.

### Dimension-by-Dimension Comparison

| Dimension | WasmGC Options | `optrich-vm-02` |
| :--- | :--- | :--- |
| **Zero-copy slicing / substrings** | **No native slice primitive.** Must pass `(array, off, len)` triples or wrap in a shared `struct` (requiring matching `rec` groups or accessors). | **First-class:** `mem.span` / `mem.ref_span` produce $O(1)$ zero-copy views carrying their own bounds (`mem.byte_len` / `mem.ref_len`) and `rootHandle` for GC safety (plus `mem.clone_span` to detach). |
| **Read-only sharing of mutable buffers** | **Not supported zero-copy.** Mutability (`(mut T)` vs `T`) is fixed at allocation time; sharing a mutable array read-only requires copying or wrapping in `anyref` + read-only accessors (Option 2). | **First-class:** `mem.readonly` downgrades a mutable `rw_handle` (or sub-span) to a `ro_handle` in-place with zero copying; enforced statically on `ro_handle` and dynamically on `handle`. |
| **Cross-module type coupling** | **Option 1 (`rec` groups)** requires identical structural `rec` definitions across modules. **Option 2 (`anyref` + `ref.cast`)** decouples layouts at the cost of casts/wrappers. | **Minimal coupling:** Modules only agree on `handle` / `ro_handle` / `rw_handle` and lightweight conventions (UTF-8 `ro_handle` spans, typed slices, 2-ref trait objects). No `rec`-group hierarchies to synchronize. |
| **Polymorphic interfaces / dynamic dispatch** | **Option 2** (vtable `struct` + `anyref`) or **Option 3** (shared `table`s + `call_indirect`). | **Trait objects + `call_ref`:** Frozen 2-ref block `[data, ro_vtable]` with `mem.alloc_vtable` + `call_ref (type $sig)`—no shared tables, no slot collisions, no `rec`-group boilerplate. |
| **Raw byte layouts & bulk data** | Poor fit for WasmGC structs; usually requires **Option 4 (Hybrid Linear Memory)** alongside GC, losing GC safety for the shared buffer. | **Unified:** Split blocks keep raw `bytes` (bulk `mem.copy`/`fill`/`cmp`, packed layouts, $O(1)$ GC scan) and GC-traced `refs` in one model without falling back to linear memory. |
| **Isolation model** | **Option 5 (Component Model)** enforces shared-nothing copying by default (with WIT `resource` handles for opacity). | **Capability-based zero-copy:** Unforgeable handles + `ro_handle` attenuation + opaque data behind trait objects/accessor modules, avoiding Component Model copying overhead. |

### Where WasmGC Has an Edge Over `optrich-vm-02`
1. **Field-level static type safety & zero bounds checks on structs:** WasmGC's `struct.get`/`struct.set` have statically verified offsets and types with no runtime bounds check. In `optrich-vm-02`, `bytes` is untyped, so byte accesses require bounds checks (until hoisted by a JIT) and field types are enforced by the language frontend (e.g., Optic) rather than the VM.
2. **Built-in subtyping & `i31ref`:** Native `sub` hierarchies, `ref.test`/`ref.cast`, and unboxed 31-bit integers.
3. **Standard ecosystem, JITs, and threading roadmap:** Production optimizing JITs (V8, SpiderMonkey, JSC, Wasmtime), existing toolchains (Kotlin, Dart, Java, OCaml), and standard proposals like Shared-Everything Threads and Type Imports. `optrich-vm-02` is a custom VM/ISA requiring a capability-aware frontend rather than off-the-shelf LLVM/WasmGC compilers.

### Summary Takeaway
For runtime composition, `optrich-vm-02` aligns closest to **WasmGC Option 2 (opaque refs + trait/vtable dispatch)** combined with **capability-safe slices (`mem.span`, `mem.readonly`)** and **raw byte buffers (Option 4)**—directly addressing WasmGC's two biggest ergonomics gaps for cross-module sharing (**no zero-copy slices** and **no zero-copy mutable-to-readonly views**) without fragile `rec`-group synchronization, at the cost of static field-level struct typing and standard WebAssembly ecosystem compatibility.
