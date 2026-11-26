# Old Original Repos — Summary & Evaluation

Audit of 14 original repositories under [`phucvin`](https://github.com/phucvin), covering what each project actually implements, the problems it targets, a candid assessment of the idea, industry equivalents across languages/platforms, and concrete challenges if continued.

---

## Quick Index

| # | Repo | Era | Stack | Verdict | Summary |
| :-: | :--- | :--- | :--- | :--- | :--- |
| 1 | [`solv-03`](#1-solv-03) | Nov–Dec 2025 | TypeScript | Clever idea, steep tradeoffs | Stateless, offline-capable LiveView prototype with fine-grained signals, `CommandMap` DOM patches, and volatile server cache + 404 client-state fallback. |
| 2 | [`waas`](#2-waas) | Nov–Dec 2022 | Go, TypeScript | Solid concept, crowded space | Experimental Go/wazero WebAssembly-as-a-Service runtime with location-aware routing, polyglot waPC guests, and token-based async host capabilities. |
| 3 | [`project-teneng`](#3-project-teneng) | Oct 2022 | Go | Early PoC, crowded space | 2.5-hour Go + gRPC skeleton for a centralized `ServiceRouter` deployed on Fly.io's private network. |
| 4 | [`Okeva`](#4-okeva) | Jan 2019 | C# | Clever prototype, crowded space | Three-layer C# embedded KV & hierarchical object storage engine with in-memory Trie/TST key indexes, append-only values, LRU views, and reactive secondary indexes. |
| 5 | [`hkv`](#5-hkv) | Jan 2019 | C++ | Neat concept, rough prototype | Minimalist C++ embedded append-only KV store with built-in per-key version history (`past_int`) and a prototype hierarchical C++ object-mapping layer. |
| 6 | [`tl_sync`](#6-tl_sync) | Aug 2018 | Rust | Clever concept, unsound execution | Experimental 2018 nightly Rust crate implementing a triple-buffered, thread-local reactive state tree for lock-free UI/compute thread sync. |
| 7 | [`Memory-Chaos`](#7-memory-chaos) | Sep 2017 | C# (Unity) | Good learning exercise | Unity 5.3 mobile sequential tile-tapping ("1 to 50" / Schulte-table) prototype with AssetBundle image packs and deterministic event-log replays. |
| 8 | [`unidirectional-data-flow`](#8-unidirectional-data-flow) | Sep 2017 | C# | Good learning exercise | Single-file C# console prototype contrasting event-based and callback-based async service wiring with a Passive View / reactive presenter pattern. |
| 9 | [`try-microservices-locally`](#9-try-microservices-locally) | Sep 2017 | Go | Good learning exercise | Tiny Go prototype simulating event-sourced banking microservices in-process with optimistic transfers and lazy read-time cancellation. |
| 10 | [`test-mvrvm`](#10-test-mvrvm) | Sep 2017 | C# | Solid pattern, rough prototype | C# console prototype experimenting with a reactive MVVM/MVRP client architecture using ReactiveProperty, Rx.NET, and Ninject DI. |
| 11 | [`q2c`](#11-q2c) | Sep 2017 | C# | Clever prototype, flawed execution | 377-line C# prototype of a version-stamped, deferred-queue reactive dataflow system ("queue-to-change") for game-entity-to-HUD binding. |
| 12 | [`edi`](#12-edi) | Sep 2017 | C# | Clever pattern, rough prototype | Early C# prototype for a deterministic, path-addressed, transactionally-queued state-management and replay framework for game simulations. |
| 13 | [`Components`](#13-components) | Sep 2017 (~2012 code) | Lua (LÖVE) | Good learning exercise | LÖVE 0.8.0 prototype demonstrating a Unity-style component composition layer on top of a custom coroutine-driven Lua micro-engine (`flatmoon`). |
| 14 | [`MultiMatch`](#14-multimatch) | Sep 2017 (~2012 code) | Lua (LÖVE) | Clever twist, dated stack | Playable LÖVE 0.8.0 match-3 puzzle game with a 3-swap combo-engineering twist, `flatmoon` coroutine micro-engine, and threaded DFS hint solver. |

---

## Cross-Cutting Themes

Looking across all 14 repos (alongside [`Writership`](writership.md)), five clear technical arcs stand out:

1. **Reactive State & Deterministic Simulation (2016–2018):** `edi` → `q2c` → `test-mvrvm` → `unidirectional-data-flow` → `tl_sync` (and `Writership`). A sustained progression from deferred-queue/version-stamped C# prototypes to triple-buffered lock-free Rust state trees—repeatedly anticipating modern signals, ECS change filters, and pipelined UI/compute sync.
2. **Embedded Storage Internals (Jan 2019):** `hkv` (C++) → `Okeva` (C#). Back-to-back explorations of Bitcask/WiscKey-style key-value separation (ordered in-memory key index + append-only value log) layered with hierarchical `0xFF`-delimited object paths.
3. **Distributed Systems & Wasm Compute (2017–2022):** `try-microservices-locally` → `project-teneng` → `waas`. Moving from in-process event-sourced microservice simulation to Fly.io gRPC routing and polyglot WebAssembly-as-a-Service.
4. **Full-Stack Reactive Web (2025):** `solv-03` brings the fine-grained reactive signal obsession to the web, threading a clever needle between Phoenix LiveView, Qwik resumability, and Datastar.
5. **Indie Games & Coroutine Micro-Engines (~2012–2017):** `MultiMatch`, `Components`, and `Memory-Chaos` showcase pragmatic game-loop ergonomics (`flatmoon` coroutine sequencing, deterministic event-log replays, and a genuinely fun 3-swap match-3 mechanic).

---

## 1. `solv-03`

- **Repo:** <https://github.com/phucvin/solv-03>
- **Activity:** Created 2025-11-02 · Last pushed 2025-12-24
- **Stack:** TypeScript (Express 5, ESM, Cloudflare Workers branch)
- **Verdict:** **Clever idea, steep tradeoffs**

### What is it?
`solv-03` is a compact (~41 KB TypeScript) prototype of a **"Stateless Offline-capable LiveView"** built on Express 5 (with ESM output via `tsc` + `mjscjs` and a `wrangler`/Cloudflare Workers deployment branch). It defines a symmetric imperative `Solv` API (`newElement`, `newSignal`, `getElement`, `getSignal`, `addEffect`) in `src/shared.ts` that runs on both server (`src/server.ts`) and client (`src/client.ts`), recording all DOM creations/updates and signal/effect mutations into a serializable `CommandMap`. Action and effect handlers are manually registered in `src/registry.ts` under short static IDs prefixed by execution environment (`a_` client action, `A_` server action, `e_` client effect, `E_` server effect).

On initial page load, `serve()` executes the route component, runs initial effects, stores only `{ signals, effects, nextNumber }` in a volatile in-memory cache (`src/cache01.ts`, 10s TTL) keyed by `cid`, and emits SSR HTML (`src/ssr.ts`) with inline `solv.dispatch(...)` attributes and a tiny hydration bootstrap that loads only signals and effects—avoiding component re-execution. User events run locally if registered on the client (`a_`), updating DOM nodes directly via explicit signal-ID dependency tracking (`effectMap`) and a 5-iteration `resolvePendingSignals()` loop; server actions (`A_`) POST `{ cid, cm: lcm, handler, params }` to `/action`, receive streamed `|>JSON<|` `CommandMap` chunks, and automatically retry with full `{ signals, effects }` if the server returns 404 due to cache eviction. Three counter demos (`counter01`–`counter03`) validate client-only reactivity, server-side resets, and server-rendered dynamic list items with optimistic client loading states, though several runtime features (server-side effect loops, `E_` effects, signal/effect GC, and JSX compilation) remain unimplemented.

### What problems does it solve?
Targets the tradeoff between stateful server-driven UI frameworks (like Phoenix LiveView, which require persistent WebSocket connections, sticky server memory, and break offline) and client-heavy SPAs (like React/Solid, which incur hydration costs, duplicate business logic behind REST/RPC APIs, and ship full component trees to the browser). Solv lets server actions directly mutate reactive signals and render new components into the client DOM with minimal diff payloads, while keeping servers horizontally scalable/serverless-friendly and allowing client-side actions to run locally without network round-trips.

### Is it a good idea?
The core architectural hook—a volatile server-side cache of reactive state backed by transparent 404 full-state resends from the client, paired with a unified `CommandMap` for fine-grained DOM and signal patches—is genuinely clever. It threads an interesting needle between LiveView's stateful WebSocket overhead and ViewState/Datastar's per-request payload bloat, while enabling near-zero hydration and mixed client/server interactivity. However, as a practical framework idea it faces steep headwinds: (1) trusting client-resent signals/effects introduces a major security boundary problem unless solved with signed state or strict server/client state separation; (2) the raw imperative API is far too verbose to use without a Qwik-caliber compiler and code-splitter, which is an order of magnitude harder to build than the runtime; and (3) the surrounding ecosystem (Qwik, Datastar, SolidStart, Phoenix LiveView) already covers most of these tradeoffs with much greater maturity. Impressive architectural prototype, risky as a full production framework without major compiler investment.

### Similar ideas in the industry
- **Qwik (TypeScript / Web)** — Pioneered resumability by serializing reactive state and event listeners into HTML and lazy-loading handlers via static symbol IDs, very close to Solv's serialized signals/effects and static registry, though Qwik relies on a compiler optimizer and renders resumed components on the client rather than streaming server DOM `CommandMap`s.
- **Datastar (Hypermedia / Web)** — Pairs server-driven DOM patches over SSE with client-side reactive signals for lightweight interactivity; shares Solv's stateless server + fine-grained client reactivity ethos, but sends client signals on every request rather than caching them server-side with a 404 resend fallback.
- **Phoenix LiveView (Elixir / BEAM)** — The primary inspiration for server-driven interactive UIs with minimal wire diffs, but depends on long-lived stateful WebSocket processes on the server and does not natively execute reactive signal graphs offline on the client.
- **htmx + Alpine.js (Hypermedia / JS)** — Solves the same split between server-rendered HTML updates and local client interactivity, but operates via coarser HTML fragment swaps and attribute-based glue rather than a unified fine-grained signal/effect graph across client and server.
- **Laravel Livewire / ASP.NET ViewState (PHP / C#)** — Stateless server-driven component architectures that round-trip serialized state between browser and server; Solv improves on their payload overhead by caching state in a volatile server cache on the happy path and adding fine-grained client-side signals.
- **SolidJS / SolidStart (TypeScript / Web)** — Direct inspiration for Solv's fine-grained signal/effect reactivity and server functions, though Solid uses full client-side hydration and RPC boundaries rather than server-emitted DOM mutation `CommandMap`s.

### Challenges if continued
- **Security and state integrity on cache miss:** On a 404 cache miss, `src/server.ts:act()` blindly accepts `{ signals, effects }` and `cm.setSignals` from the client. Making this safe requires cryptographically signing/encrypting server-owned state (or strictly partitioning server-authoritative vs. client-mutable signals and validating effect graphs).
- **Massive compiler and bundler investment:** Authoring components against the imperative `Solv` API with manual static IDs (`NEXT_STATIC_ID.txt`), explicit dependency arrays, and hand-wired `*_handlers.mjs` imports is unsustainable for real apps. Solid-like JSX DX requires a Qwik-style optimizer/compiler to auto-split closures and extract signal dependencies.
- **Reactive graph GC and client-server runtime parity:** Deleted components currently leak signals and effects indefinitely (e.g., removing counters in `counter03` never prunes `signals`, `effects`, or `effectMap`). Server-side effect propagation in `act()` is commented out, `E_` server effects throw `Unimplemented` on the client, and `src/client.ts:numberToId` generates `_x`/`@x` IDs that break `isSignal()` (which expects prefix `s`).
- **True offline sync and ID/state reconciliation:** Supporting genuine offline workflows beyond simple local clicks requires persisting pending `CommandMap` mutations across page reloads, resolving conflicts against mutated server/DB state, and preventing `nextNumber` ID collisions when client (offline) and server create elements/signals independently.
- **SSR/DOM correctness and XSS hardening:** `src/ssr.ts` concatenates raw strings with single-quoted attributes and unescaped `innerHTML` (opening XSS/escaping bugs, lacking void-tag and SVG support), while `src/client.ts:applyElementUpdate` blindly writes both `node[name]` and `node.setAttribute(name, value)` and lacks proper two-way input binding or event object serialization.

---

## 2. `waas`

- **Repo:** <https://github.com/phucvin/waas>
- **Activity:** Created 2022-11-23 · Last pushed 2022-12-09
- **Stack:** Go (`wazero`, `wapc-go`, Karmem), TypeScript (AssemblyScript), TinyGo
- **Verdict:** **Solid concept, crowded space**

### What is it?
A ~220-line Go prototype (`main.go`) implementing a WebAssembly microservice host on top of `wazero` (`v1.0.0-pre.3`) and `waPC` (`wapc-go v0.5.5`), using Karmem (`km/waas.km`) for zero-copy binary serialization of an `Invocation` envelope (`Source`, `Destination{Name, Location}`, `Payload`, `Metadata`). Each server starts with `--locations` and `--port`, precompiles hardcoded `.wasm` modules from `services/`, and serves raw binary HTTP requests. Invocations are either dispatched to host capabilities (destination names prefixed with `_`, e.g., `capabilities/wait/lib.go` providing `_wait`, `_async_wait`, and `_await_wait` backed by goroutines and a `sync.Map` of `WaitGroup`s), rerouted via HTTP POST to hardcoded peer ports if the target location isn't local, or executed locally by instantiating a fresh Wasm instance per request. A single waPC host callback (`"invoke"`) loops back into the same router, allowing polyglot guest services—TinyGo (`services/hello`, `services/capitalize`) and AssemblyScript (`services/ping`)—to invoke each other, recurse, or call host capabilities uniformly. Includes two load/smoke-test clients (`cmd/test01`, `cmd/test02`), with no dynamic deployment, no auth, and hardcoded routing/modules.

### What problems does it solve?
Targets lightweight, polyglot microservice execution (running TinyGo and AssemblyScript services inside one Go process with per-request Wasm sandboxing), uniform RPC across client calls, service-to-service calls, and host capabilities via a single binary envelope, region/location-aware request rerouting across nodes, and non-blocking concurrency for single-threaded Wasm guests via host-managed async wait tokens.

### Is it a good idea?
As a 2022 systems prototype, it is a sharp, thoughtful exploration of WebAssembly microservices: unifying client-to-service, service-to-service, cross-region routing, and host capabilities (`_wait`/`_async_wait`) behind a single zero-copy Karmem `Invocation` envelope is clean and minimal, and pairing per-request instantiation with TinyGo's `-gc=leaking` and `-scheduler=none` shows strong intuition for Wasm performance trade-offs. However, as a standalone project to continue today, the core custom layer (waPC + Karmem + hand-rolled token async) has been largely superseded by the WASI Component Model (WIT and WASI 0.3 async)—a convergence the author already anticipated in the README—and the broader "Wasm-as-a-service" space is now well-served by mature platforms like wasmCloud and Fermyon Spin.

### Similar ideas in the industry
- **wasmCloud (Rust / CNCF Wasm platform)** — Implements the same actor, capability-provider, and location-transparent distributed routing model `waas` prototypes, but at production scale over NATS with WASI Component Model and mTLS.
- **Fermyon Spin (Rust / WebAssembly FaaS)** — Runs polyglot Wasm microservices with per-request instantiation and host-provided capabilities (HTTP, KV, SQL), using standard WIT/WASI interfaces instead of waPC and Karmem.
- **WebAssembly Component Model & WASI 0.2/0.3 (W3C / Bytecode Alliance)** — Standardizes the exact polyglot cross-module invocation, typed host capability boundaries (WIT), and native async I/O that `waas` hand-rolled with waPC, Karmem, and `_async_wait` tokens.
- **Cloudflare Workers / workerd (C++ / V8 isolates, edge FaaS)** — Addresses the same sub-millisecond multi-region sandboxed compute and service-binding RPC problem using V8 isolates and smart placement rather than `wazero`.
- **Dapr (Go / distributed application runtime)** — Provides language-agnostic service-to-service invocation and pluggable capabilities via a sidecar abstraction, targeting containers rather than in-process Wasm sandboxes.

### Challenges if continued
- **Standards and dependency obsolescence:** Built on 2022-era `wapc-go v0.5.5`, `wazero v1.0.0-pre.3`, Karmem, and TinyGo `v0.26.0`. Continuing today forces either maintaining a bespoke Karmem/waPC ABI isolated from the ecosystem or rewriting around WASI 0.2/0.3 Component Model (WIT) and a runtime with full Component Model support (e.g., Wasmtime).
- **Resource exhaustion and sandbox safety:** Recursive guest-to-host invocations (as in `services/ping`) instantiate a new Wasm instance per hop with no depth limit, Wasm fuel/CPU metering, or memory cap; `capabilities/wait` spawns unbounded goroutines (100k per `hello` call) and leaks `sync.Map` entries if a guest traps or never calls `_await_wait`.
- **Distributed topology and dynamic lifecycle:** Loaded modules and region-to-URL mappings (`us-west1 -> localhost:8081`, `us-east1 -> localhost:8082`) are hardcoded in `main.go`. Evolving into a multi-region platform requires artifact distribution, hot-reloading, service discovery/health checks, and cross-region retry/timeout semantics.
- **Identity spoofing and service-to-service security:** `Invocation.Source` is self-declared by the caller/guest, so any module can impersonate another. Implementing mTLS-like authN/authZ requires host-enforced caller identity, per-module capability ACLs, and authenticated/encrypted inter-node transport.
- **Host correctness and production hardening:** `main.go` panics on missing modules via `check(err)` inside `invoke()`, omits early returns after `w.WriteHeader(500)` in `handleHTTP()`, leaks HTTP response bodies in `post()`, and lacks request timeouts, graceful shutdown, and distributed tracing.

---

## 3. `project-teneng`

- **Repo:** <https://github.com/phucvin/project-teneng>
- **Activity:** Created 2022-10-23 · Last pushed 2022-10-23
- **Stack:** Go (gRPC, Protobuf, Fly.io)
- **Verdict:** **Early PoC, crowded space**

### What is it?
An unfinished, ~2.5-hour Go 1.16 proof-of-concept monorepo containing two minimal Fly.io-deployed services (`services/servicerouter` and `services/sample`) and a shared protobuf module (`services/servicerouter/proto`), plus a README pointing to an external Google Doc design. `servicerouter` (Fly app `proud-dust-984`, internal port `50051`) is a 42-line gRPC server (`google.golang.org/grpc v1.50.1`) exposing a single `ServiceRouter.Invoke(InvokeRequest) -> InvokeResponse` RPC that currently just logs and echoes the `description` string—no routing table, discovery, or forwarding logic exists yet. `sample` (Fly app `red-dust-2147`, public HTTP/HTTPS on `80/443 -> 8080`) is a 47-line HTTP server that dials `proud-dust-984.internal:50051` over Fly.io's private 6PN network using insecure gRPC credentials, sends a hardcoded `InvokeRequest{Description: "From: Sample To: Something"}` with a 1s timeout, and returns `FLY_REGION` plus the echoed response. Leftover tutorial comments in `servicerouter.proto` and mismatched `go.mod` module paths confirm it stopped right after initial "hello world" connectivity worked.

### What problems does it solve?
Targets the microservice networking pain point of decoupling service-to-service RPC calls from direct host addressing, discovery, regional routing, and resilience logic by funneling calls through a unified routing service (`ServiceRouter.Invoke`). In its actual implemented state, it only proves out basic private-network gRPC connectivity between two Go apps on Fly.io.

### Is it a good idea?
As a 2.5-hour spike to test Go gRPC communication over Fly.io's private `.internal` network and sketch a Meta ServiceRouter-inspired abstraction, it is a reasonable learning exercise. As an ongoing system or product, building a custom centralized L7 RPC router from scratch is questionable: the problem space is thoroughly solved by Envoy, Linkerd, Dapr, and proxyless gRPC xDS, and the repo's centralized-hop `Invoke` API design creates both a latency/availability bottleneck and awkward ergonomics compared to transparent proxies or client-side routing libraries (which is how Meta's own ServiceRouter actually operates).

### Similar ideas in the industry
- **Meta ServiceRouter (Meta / C++ & Thrift)** — The clear namesake and inspiration; Meta's internal L7 routing layer handling service discovery, load balancing, and locality-aware routing, typically embedded as a client library rather than a central proxy hop.
- **Dapr (CNCF / Cross-platform)** — Provides a sidecar-based service-to-service invocation API with built-in discovery and resiliency, closely mirroring the uniform `Invoke` abstraction sketched in `servicerouter.proto`.
- **Envoy Proxy / Istio / Linkerd (Cloud Native / CNCF)** — Production L7 service meshes and gRPC-aware proxies that handle routing, load balancing, retries, and mTLS transparently without forcing applications into a custom `Invoke` schema.
- **gRPC xDS / Proxyless Service Mesh (gRPC / Google)** — Delivers centralized routing policy and load balancing directly inside gRPC clients via an xDS control plane, avoiding the extra network hop of a standalone router service.
- **Fly.io 6PN + Fly Proxy (Fly.io PaaS)** — Fly's native WireGuard private networking (`.internal` DNS, regional routing, and `fly-replay`) already provides much of the basic multi-region service discovery this prototype was experimenting on top of.

### Challenges if continued
- **Envelope RPC vs. transparent gRPC proxying:** The current `Invoke(InvokeRequest)` contract forces either wrapping opaque byte/`google.protobuf.Any` payloads (breaking native typed gRPC clients, streaming, and tooling) or pivoting to a transparent HTTP/2 frame-level reverse proxy, which is a much harder engineering problem.
- **Centralized hop bottleneck and blast radius:** Running `servicerouter` as a standalone Fly app (`proud-dust-984.internal:50051`) introduces an extra network hop, serialization overhead, and a single point of failure unless re-architected as a sidecar, regional fleet, or client-side routing library.
- **Unbuilt distributed-systems core:** Dynamic service registry/discovery, health checks, locality-aware load balancing, retries, circuit breaking, and deadline propagation (currently `sample` hardcodes a 1-second timeout) all remain unimplemented.
- **Security and observability gaps:** Uses plaintext gRPC (`insecure.NewCredentials()`) relying solely on Fly.io's private network, with no workload identity, mTLS, authorization policies, structured error codes, or distributed tracing/metrics.
- **Outdated Go/Fly.io setup and module hygiene:** Targets EOL Go 1.16 and `google.golang.org/grpc v1.50.1`, relies on legacy Paketo buildpacks in `fly.toml`, has zero tests/CI, and has mismatched Go module paths (`.../servicerouter/servicerouter/proto` with a local `replace` vs. a pinned pseudo-version).

---

## 4. `Okeva`

- **Repo:** <https://github.com/phucvin/Okeva>
- **Activity:** Created 2019-01-21 · Last pushed 2019-01-27
- **Stack:** C# (.NET Framework 4.7.1)
- **Verdict:** **Clever prototype, crowded space**

### What is it?
Okeva ("Object" + "Keva" key-value) is a zero-dependency C# (.NET Framework 4.7.1) embedded storage engine prototype built in a 6-day sprint in January 2019, organized into three clean architectural layers:
1. **`Keva`** — A raw byte key-value store splitting keys (`<db>.ke`) and values (`<db>.va`) across two files via a custom `Fs` wrapper with compact varint encoding and a 512-byte read buffer. Supports pluggable in-memory key indexes (`TrieMemKeyManager`, `TernaryMemKeyManager`, `HashMemKeyManager`, with `RedBlackTreeInMemory` unimplemented) replayed sequentially from `.ke` on startup, an append-only value store (`AppendValueManager`, with `ReuseOnDisk` unimplemented) that chains `prevLoc` pointers per write, and a `(prefix, suffix)` `PreWriteListener` hook.
2. **`HandledKeva`** — A handle/caching layer (`Handler`, `Lru`, `IntView`, `StringView`) where each `IKeyNode` tracks a single canonical `Handler` so duplicate handles shadow it for read/write coherence, while an LRU evicts cached view values.
3. **`Oss*` (Object Storage System)** — A higher-level domain mapping layer (`OssPath`, `OssObject`, `OssInt`, `OssString`, `OssMap<V>`, `CachedOssMap<V>`, `OssAutoKey`, `OssIndex`) encoding object hierarchies as `0xFF`-delimited `PathKey`s, generating base-254 sortable auto-keys, and maintaining secondary indexes reactively via `PreWriteListener`.

Includes MSTest unit tests (`OssTodoTests`, `HandledKevaSimpleTests`, `KevaSimpleTests`, `OssAutoKeyTests`, `TenraryDraftTests`) and SSD microbenchmarks (`KevaBenchmarks`).

### What problems does it solve?
Targets the friction of persisting structured C# domain objects locally without standing up an external database server or writing ORM/SQL boilerplate. Specifically addresses: (1) fast ordered key/prefix lookups and cursor pagination over hierarchical object paths via in-memory Trie/Ternary Search Tree indexes; (2) keeping multiple in-memory references to the same stored property coherent via canonical `Handler` shadowing and LRU-evicted typed views (`IntView`, `StringView`); and (3) automatic secondary indexing (`OssIndex`) and lexicographically sortable auto-incrementing keys (`OssAutoKey`) on top of a raw byte KV store.

### Is it a good idea?
As a 6-day architectural exploration of embedded storage internals, it is genuinely clever and well-structured. Separating keys (`.ke`) from append-only values (`.va`) mirrors proven log-structured designs (Bitcask/WiscKey), the `Handler` shadowing + LRU view invalidation cleanly solves coherent in-memory caching across multiple handles to the same key, and building secondary indexes (`OssIndex`) via key-pattern `PreWriteListener`s over a sorted hierarchical keyspace is an elegant compositional pattern. However, as a production database or library to adopt, the core idea is dated and redundant in a crowded space: hand-rolling a non-ACID, single-threaded, all-keys-in-RAM storage engine in C# gives up crash safety, compaction, concurrency, and query power that mature embedded engines (SQLite, RocksDB, LiteDB, FASTER) already provide. The hierarchical property-per-key object mapping (e.g., `item.Content.It` writing immediately to disk per field) also encourages chatty I/O and lacks atomic multi-field object updates.

### Similar ideas in the industry
- **Bitcask / Riak (Erlang / Go / Rust)** — Pioneered the exact log-structured append-only value file + all-keys-in-memory index architecture that `Keva`'s `.ke`/`.va` split implements, though Bitcask uses a hash table (no ordered scans) and includes merging/compaction.
- **WiscKey / BadgerDB (C++ / Go)** — Uses key-value separation (keeping keys in an ordered structure and values in an append-only value log) to reduce write amplification, similar in spirit to Okeva's `.ke`/`.va` split, but backed by an LSM-tree with crash recovery and GC.
- **FoundationDB Record Layer (Java / C++)** — Maps structured hierarchical objects, collections, and secondary indexes onto an ordered key-value space using path prefixes and tuple encoding, closely paralleling Okeva's `OssMap`/`OssPath`/`OssIndex` layer with full ACID transactions.
- **LiteDB (C# / .NET)** — Mature embedded NoSQL document database in pure C# solving the same zero-dependency .NET local object persistence problem, with B-tree indexing, ACID transactions, and LINQ queries instead of per-field KV paths.
- **Microsoft FASTER (C# / .NET)** — High-performance concurrent KV store and hybrid log in C# using modern .NET primitives, log-structured storage, and in-memory caching.
- **Firebase Realtime Database / LevelGraph (Web / JS)** — Shares the hierarchical path-addressed tree model where reading/writing nested paths maps directly to reactive listeners and indexed subtrees.

### Challenges if continued
- **Data durability, crash recovery, and space reclamation:** `AppendValueManager` never frees overwritten or deleted values (`Delete()` is a no-op), `Fs` uses `_flushToDisk = false` with non-atomic two-file (`.ke`/`.va`) writes and never invalidates its 512-byte read buffer on overlapping writes; adding WAL/checksums, atomic commits, and background compaction is a major engineering lift.
- **Correctness bugs and hardcoded limits in the prototype:** Concrete defects include a missing `return` in `Handler.Read` (double-reads on shadowed handlers), a copy-paste bug in `TernaryMemKeyManager.RecursiveDelete` (checking `Parent.Next` twice instead of `Parent.Right`), stale `OssIndex` entries on `OssMap.Remove`, little-endian integer sorting breaking `OssIndex` for ints > 255 or negative numbers, and hardcoded 512-byte limits in `StringView`, `OssIndex`, and `Load()`.
- **Memory scaling and concurrency:** Keeping every key in an in-memory object graph (Trie/TST/Hash nodes) limits dataset size to RAM and creates heavy GC pressure in .NET; there is also zero thread-safety or transaction isolation across `Keva`, `Fs`, `Lru`, and `OssIndex`.
- **Modernization and ergonomics in .NET:** Targets legacy .NET Framework 4.7.1 with manual `byte[]` allocations and explicit wrapper boilerplate (`OssInt`, `OssString`, `.It`). Reviving today requires migrating to modern .NET (`Span<byte>`/`Memory<byte>`, `RandomAccess`, Source Generators).
- **Ecosystem adoption against entrenched embedded stores:** Earning trust over SQLite, RocksDB, LMDB, LiteDB, or FASTER requires extensive fuzz/crash testing, schema evolution tooling, and richer query expressiveness.

---

## 5. `hkv`

- **Repo:** <https://github.com/phucvin/hkv>
- **Activity:** Created 2019-01-21 · Last pushed 2019-01-21
- **Stack:** C++ (Visual Studio 2017)
- **Verdict:** **Neat concept, rough prototype**

### What is it?
`hkv` is a small (~750 LOC across 5 C++ files, Visual Studio 2017 project, no README or tests) prototype of an embedded, append-only historical/hierarchical key-value store (created the same day as `Okeva`). The core engine (`hkv.h`, `hkv.cpp`, `converters.h`, `converters.cpp`) stores data across two binary `std::fstream` files: `<path>.key` (magic `"hk1"`) and `<path>.val` (magic `"hv1"`). On open, it scans `.key` to populate an in-memory ordered index (`std::map<std::vector<char>, std::pair<streampos, streampos>>`) mapping each key to its offset in `.key` and latest value offset in `.val`, enabling lexicographical range queries via `get_keys(start, end)`. Every write (`set_int`, `set_str`; `double`/`bytes` are commented out) appends `[compact(prev_vpos)][compact(size)][payload]` to `.val` using a custom 1-to-9-byte little-endian length-prefixed integer encoding, forming a backward-linked version chain on disk that powers `past_int(key)` to retrieve a key's full value history. Updates overwrite `vpos` in place in `.key` if its compact byte length is unchanged, or append a new key record otherwise. On top of `hkv`, `main.cpp` prototypes a write-through hierarchical ORM (`hkv_path` with `0xFF` separators and a key-shortening map, `hkv_field_int`, `hkv_field_str`, `hkv_vector<T>`, `hkv_umap<K, T>`) demonstrated with a game `Profile`/`Team`/`Item` schema.

### What problems does it solve?
Targets three practical pain points—particularly visible in the game-profile example in `main.cpp`: (1) avoiding full-object re-serialization when persisting frequent small mutations to nested state (e.g., player gold, gems, friends, inventory items); (2) retaining a built-in historical audit trail of past field values (via `past_int`) for debugging, undo, or economy/anti-cheat inspection without maintaining a separate audit table; and (3) providing zero-dependency, write-through C++ object persistence with compact key storage via a field-name shortening dictionary.

### Is it a good idea?
The core idea is genuinely clever as a focused prototype, especially for game state or audit-heavy embedded workloads, but it is redundant and too fragile to compete with production embedded databases as-is. Pairing a Bitcask-style append-only value log with per-record backward pointers (`prev_vpos`) gives full key mutation history (`past_int`) almost for free, and layering a hierarchical C++ object wrapper with a key-shortening dictionary on top of an ordered KV index is a clean way to persist structured state incrementally. However, it is an early proof-of-concept with serious foundational gaps: no crash safety or checksums, unsafe in-place `.key` overwrites, unbounded file growth with no compaction or delete support, high RAM usage from `std::map<std::vector<char>, ...>`, and several low-level C++ bugs. Worth studying as a neat systems/game-dev experiment, not worth adopting over SQLite, RocksDB, or LMDB unless heavily redesigned for a niche historical-state use case.

### Similar ideas in the industry
- **Bitcask / Riak (Erlang / distributed KV)** — Uses the same append-only value log paired with an in-memory key-to-offset index for O(1) writes and single-seek reads, but adds CRC checksums, tombstones, hint files, and background compaction.
- **RocksDB / LevelDB (C++ / embedded LSM-tree KV)** — Production embedded ordered KV stores supporting fast lexicographical range scans (like `hkv::get_keys`) and prefix compression, commonly used beneath hierarchical document/object layers.
- **SQLite (C / embedded relational DB)** — The standard zero-dependency embedded persistence engine for local apps and game saves, providing full ACID transactions, crash recovery, and rich querying.
- **Firebase Realtime Database / Realm (Mobile & Game State)** — Offers a similar hierarchical path-based object/collection persistence model (fields, lists, maps) with automatic write-through sync for structured player profiles.
- **Datomic / EventStoreDB (Immutable & temporal databases)** — Shares the append-only, history-preserving model where prior versions of a key/attribute remain queryable (like `hkv::past_int`), implemented with full transactional guarantees and retention controls.

### Challenges if continued
- **Crash safety and durability:** `std::fstream::flush()` does not `fsync` to disk, there are no CRC checksums to detect torn/corrupted records, and in-place `vpos` overwrites in `.key` can corrupt the index on a crash mid-write.
- **Compaction and deletion semantics:** Neither deletes (tombstones) nor log compaction exist, so `.val` grows unboundedly on every mutation and `.key` accumulates dead duplicate entries whenever `vpos` crosses a compact-encoding byte boundary; adding compaction while preserving configurable history depth (`past_*`) adds significant complexity.
- **Memory overhead and cold-start latency:** Startup linearly scans the entire `.key` file (with 3 seeks per key) and loads every key into a `std::map<std::vector<char>, ...>`, incurring heavy per-key heap/tree-node overhead and slow open times as key counts grow.
- **Low-level correctness and portability bugs:** Negative integer truncation (`write_compact` writes up to 9 bytes for negative ints while `get_int`/`past_int` only read 5 bytes), fixed `buff[512]` overflow risk for long keys, signed-`char` bugs with the `255` path delimiter in `hkv_umap` range scans, UB in the self-initializing `hkv_path()` default constructor, endianness-dependent union punning, and moving from a Windows-only VS2017 `.vcxproj` to CMake with unit tests.
- **Concurrency and schema evolution:** Single-threaded with shared mutable scratch buffers (`buff`, `ckey`, `ckey2`) on the `hkv` instance, and the manual `shorter` key-abbreviation map in `main.cpp` is brittle—any rename or collision silently orphans or corrupts persisted objects.

---

## 6. `tl_sync`

- **Repo:** <https://github.com/phucvin/tl_sync>
- **Activity:** Created 2018-08-08 · Last pushed 2018-08-30
- **Stack:** Rust (2018 nightly)
- **Verdict:** **Clever concept, unsound execution**

### What is it?
`tl_sync` is a small (~600 LOC in `src/`, no README, 1 unit test, 1 benchmark, 10 examples) experimental Rust crate from August 2018 targeting nightly Rust (`#![feature(box_into_raw_non_null, fnbox, drain_filter)]`). It implements a thread-local, triple-buffered reactive state tree designed to share nested UI/application state between a UI thread (slot 0) and a background compute thread (slot 1) via a staging mutation slot (slot 2, `MUTATE_THREAD_INDEX`).

Core building blocks: `TrustCell<T>` (`src/cell.rs`) wraps `UnsafeCell<[T; 3]>` with an unconditional `unsafe impl Sync`; `Tl<T>` (`src/tl.rs`) wraps `Arc<TrustCell<T>>`, dereferencing to the calling thread's slot (determined by parsing the first byte of `thread::current().name()` in `src/threads.rs`) and mutating slot 2 via `to_mut()`/`to_mut_advanced()` while recording `Box<dyn Dirty>` entries in a global `static mut DIRTIES` vector. `src/sync.rs` propagates dirty values across slots using a custom `ManualCopy<T>` trait (`src/manual_copy.rs`, implemented for primitives, `String`, `Option`, 2-tuples, `Vec`, `HashMap`) and dispatches UUID-deduplicated `FnMut()` callbacks stored in a global `static mut LISTENERS` map keyed by raw pointer address (`get_ptr() -> usize`). On top of `Tl<T>`, `Action<T>` (`src/actions.rs`) provides a one-shot event queue that drains on copy and clears after notification, `Wrc<T>` (`src/rc.rs`) wraps `Arc`/`Weak` to break listener reference cycles, `Trust<T>` (`src/trust.rs`) unsafely forces `Send + Sync` (used to pass `iui::UI` across threads), and `runner::setup()` (`src/runner.rs`) orchestrates a lockstep `mpsc` handshake (`Idle` / `JustSync`) between `UiSetup` and `ComputeSetup` within a configurable frame duration.

### What problems does it solve?
Targets three concrete pain points in multithreaded desktop UI/interactive Rust applications: (1) keeping the UI thread responsive without `Mutex`/`RwLock` contention while heavy compute (e.g., `rayon` parallel loops) mutates state on a background thread; (2) avoiding the boilerplate of wrapping every field in a nested scene/UI tree (`examples/scene_tree.rs`) in locks or hand-rolling message-passing diffs, instead letting code deref `*field` for lock-free reads and `*field.to_mut() = ...` for dirty-tracked writes; and (3) coordinating bidirectional UI/compute events (`Action<T>`) and reactive listener subscriptions (`ListenerHandleRef`, `Wrc<T>`) without leaking cyclic `Arc` references.

### Is it a good idea?
The core architectural idea—decoupling UI and compute threads via per-thread state snapshots, dirty-set propagation, and a frame-budgeted sync barrier—is genuinely solid and mirrors proven patterns in game engines and reactive UIs (and directly precedes `Writership`'s 3-cell model). Layering one-shot `Action<T>` queues onto the same `Tl<T>` + `ManualCopy` transport is also a neat unifying abstraction. However, the execution in Rust is deeply compromised by unsound `unsafe` shortcuts: `TrustCell` produces aliased `&mut T` references from `&self` (instant UB if called twice via `to_mut_advanced`), blanket `unsafe impl Sync` ignores thread-safety invariants, `static mut` globals and cross-thread `Drop` on `ListenerHandleRef` introduce data races, and thread identity is hacked via the first character of the OS thread name. Storing 3 full clones of every node and deep-copying entire `Vec`/`HashMap` collections on every dirty sync is also expensive. Strong systems intuition, but modern Rust patterns (ECS pipelined extraction, `triple_buffer`/`left-right`, persistent CoW state, or arena-based reactive signals) achieve the same goals safely and with far better ergonomics.

### Similar ideas in the industry
- **Bevy Pipelined Rendering / Extract Phase (Rust / game engines)** — Decouples simulation and rendering threads by extracting dirty/needed state at a per-frame sync barrier, achieving the same lock-free read/compute split safely via ECS scheduling.
- **`left-right` / `evmap` (Rust / concurrency)** — Maintains two copies of a data structure so readers access one snapshot completely lock-free while a single writer updates the other via op-log replay, solving the same read-contention problem with sound memory safety.
- **`triple_buffer` / `arc-swap` (Rust / concurrency)** — Dedicated lock-free multi-buffering primitives that separate writer staging from reader views without `UnsafeCell` aliasing UB or hardcoded thread-name indexing.
- **MobX / SolidJS / Leptos Signals (JS & Rust / reactive UI)** — Provide fine-grained reactive state trees with automatic dirty tracking and listener deduplication, using safe single-threaded or atomic/arena-backed ownership rather than raw-pointer-keyed global maps.
- **Redux / Elm Architecture + Web Workers / Flutter Isolates (Web & Dart / UI)** — Isolate UI rendering from background compute using explicit action queues and immutable state snapshots, trading implicit shared-memory mutation for safe isolation.

### Challenges if continued
- **Eliminating pervasive Undefined Behavior (UB):** `TrustCell::to_mut` hands out `&mut T` from `&self` without aliasing protection, `Trust<T>` and `TrustCell<T>` blanket-implement `Send`/`Sync` for arbitrary `T`, `static mut DIRTIES`/`LISTENERS` are accessed unsafely, and `ListenerHandleRef::drop` mutates another thread's listener map without synchronization. Making this Miri-clean requires redesigning the core API (closure-scoped mutation guards, proper `Send` bounds, deferred cross-thread unsubscription).
- **Modernizing off removed Rust 2018 nightly features:** Relies on `#![feature(fnbox)]`, `#![feature(drain_filter)]`, and `#![feature(box_into_raw_non_null)]` (all removed or stabilized differently), pre-2018 edition syntax, and an unmaintained git dependency on `iui`/`libui-rs`.
- **Scaling beyond 2 hardcoded threads and fragile thread-name dispatch:** `THREADS = 3` is hardcoded, and thread slot lookup parses the first ASCII byte of `thread::current().name()` (panicking on unnamed threads). Supporting arbitrary threads or multiple contexts requires replacing global statics with an explicit runtime handle.
- **Memory and copy overhead on large collections:** Every `Tl<T>` allocates 3 full copies upfront (e.g., 3× 5M-element `Vec`s in `examples/complex.rs`), and `ManualCopy` deep-clones `Vec`/`HashMap` on every dirty sync. Production viability needs structural sharing (CoW / persistent data structures), delta replication, or swap-based double buffering.
- **Developer ergonomics:** Manual `ManualCopy` impls, arity-specific `register_listener_1`/`register_listener_2` functions, manual `ListenerHandleRef` lifetimes, and manual `Wrc::clone_weak` cycle-breaking are far more boilerplate-heavy than modern Rust reactive/UI frameworks without proc-macros and arena-managed lifetimes.

---

## 7. `Memory-Chaos`

- **Repo:** <https://github.com/phucvin/Memory-Chaos>
- **Activity:** Created 2017-09-24 · Last pushed 2017-09-24
- **Stack:** C# (Unity 5.3.4f1, Android)
- **Verdict:** **Good learning exercise**

### What is it?
`Memory-Chaos` is an early-stage Unity 5.3.4f1 C# mobile puzzle game (Android-targeted, single `"Initial"` commit, no README) implementing a sequential tile-tapping speed game rather than a systems/memory-testing tool. A `GridLayoutGroup` (`Board.cs`) spawns `MaxTileOnBoard` tiles (default 35 out of `End=50` in `BoardInfo.cs`, or 6 out of 10 in `G.cs`) displaying either ascending numbers (`1..N`) or ordered sprites loaded asynchronously from `StreamingAssets` via Unity's legacy `AssetBundleManager` (`G.H.LoadSpriteAsync`). Tiles are shuffled in chunks of `MaxTileOnBoard` (`Board.generateIndexes`) so the next target is always visible, with optional `FixedIndexes` for scripted layouts; tapping the right tile recycles that slot with the next queued index, hesitating >= 2s triggers an auto-hint animation, and any wrong tap immediately loses the round. On victory, the game passes a compact `ReplayData` object (`BoardInfo`, tile index order, and timestamped tap/hint `ReplayEvents`) to `WinOverlay` and a parallel `ReplayGame`/`ReplayBoard`/`ReplayTile`/`ReplayTimer` stack that deterministically replays the run.

### What problems does it solve?
Targets casual brain-training / visual-scanning speed games by making the board grid size, target count, and tile visuals (numbers or custom ordered sprite packs like the bundled `"ee"` set) configurable via `BoardInfo` and swappable AssetBundles. Also solves lightweight run playback by recording only the board seed/index order and timestamped tap/hint events in `ReplayData` rather than capturing video.

### Is it a good idea?
As a 2017 solo Unity learning prototype, the implementation shows genuinely good engineering instincts: data-driven board presets via `BoardInfo`, chunked shuffling to guarantee the next required tile is always on-screen, dynamic sprite-pack loading via AssetBundles so the game isn't limited to numbers, and a lightweight event-sourced replay system instead of brute-force recording. However, as a standalone product idea, the core "1 to N" sequential tapping loop is a heavily commoditized hyper-casual genre with minimal retention on its own, and the repo is an unpolished single-commit prototype whose title ("Memory-Chaos") promises memory/chaos twists that the code does not yet implement.

### Similar ideas in the industry
- **1to50 (mobile / web casual game)** — The canonical viral version of this exact sequential tapping mechanic (a 5×5 grid of 1–25 that refills with 26–50 as tiles are cleared).
- **Schulte Table apps (iOS / Android brain-training utilities)** — Peripheral-vision and speed-scanning grid trainers built around finding sequential numbers on a timed board.
- **Human Benchmark Chimp Test & Sequence Memory (web)** — Minimalist cognitive speed/memory games showing how pairing a simple tile-tapping loop with percentile leaderboards creates strong replayability.
- **Trackmania / osu! deterministic replay systems (PC & mobile games)** — Production examples of the same event-sourced replay pattern (initial layout + timestamped events) used here in `ReplayData`/`ReplayBoard`, extended to ghost racing and anti-cheat verification.

### Challenges if continued
- **Unity 5.3.4f1 and legacy asset pipeline overhaul:** Targets Unity 5.3.4f1 with the deprecated `AssetBundleManager` sample (and `Editor/AssetBundleServer.exe`), legacy Animation clips, and pre-AAB Android AssetBundles. Reviving requires migrating to a modern Unity LTS, replacing `AssetBundleManager` with Unity Addressables, and meeting modern 64-bit store requirements.
- **Duplicated live vs. replay architecture and subtle runtime bugs:** `Board`/`Tile`/`Timer` are largely copy-pasted into `ReplayBoard`/`ReplayTile`/`ReplayTimer` rather than sharing one renderer driven by pluggable live vs. replay event sources. Concrete bugs exist today: `ReplayBoard.Update` calls `Game.End()` every frame once events are exhausted, `Time.realtimeSinceStartup` keeps ticking when backgrounded/paused, `G.BoardInfo` uses global mutable state, and `Board.shuffleIndexes` has a biased shuffle.
- **Missing MVP game systems and persistence:** No score persistence, leaderboard, audio/haptic feedback, pause/resume, or replay serialization (`ReplayData` is in-memory only and not even `[Serializable]`). `Menu.cs` is an empty stub.
- **Differentiation in an ultra-crowded hyper-casual niche:** Plain "tap 1 to N" games have low organic retention; sustaining interest requires leaning into the "Memory-Chaos" name (face-down memory twists, dynamic tile swaps/chaos modifiers) and turning replays into shareable ghosts or daily seeded challenges.

---

## 8. `unidirectional-data-flow`

- **Repo:** <https://github.com/phucvin/unidirectional-data-flow>
- **Activity:** Created 2017-09-24 · Last pushed 2017-09-24
- **Stack:** C# (.NET Framework 4.5.2)
- **Verdict:** **Good learning exercise**

### What is it?
A minimal, single-commit C# (.NET Framework 4.5.2, VS 2015) console prototype (`Program.cs`, 288 lines, no README or tests) experimenting with decoupled UI logic and reactive presenter binding. It implements a tiny observable `Label` primitive (`Text` property firing an `Action<string> SetText` delegate plus `PresenterReady()` to replay current state) and compares two implementations of an `ISomeUi` logic controller (`Action<bool> SetLoading` + `PresenterReady()`) wired to a console `SomeUiPresenter`: (1) `SomeUi` + `HttpService`, using C# events (`OnAddResult`, `OnAddError`, and a custom `OnDescription` event whose `add` accessor spawns a `Thread` to emit a value after 50ms) with a manual `Dispose()` method; and (2) `SomeUi2` + `HttpService2`, replacing events with per-call delegate callbacks (`GetDescription`, `DoAdd`) to avoid unsubscription boilerplate. Async work is simulated with `new Thread` + `Thread.Sleep` and deterministic odd/even second branching to trigger success vs. `NotSupportedException` paths.

### What problems does it solve?
Targets three classic UI architecture pain points: (1) decoupling testable UI logic/state (`SomeUi`, `SomeUi2`) from concrete view rendering (`SomeUiPresenter`) via `Action<T>` hooks; (2) synchronizing initial UI state when a presenter attaches after logic has already initialized or started loading (`PresenterReady()` replays `_isLoading` and `Label._text`); and (3) comparing the lifecycle/memory-leak ergonomics of long-lived C# events (`HttpService` requiring manual unsubscription in `Dispose()`) versus scoped per-call callbacks (`HttpService2`) during async success/error state transitions.

### Is it a good idea?
As a 2017 learning scratchpad, the core instinct is solid: decoupling UI state/logic from passive rendering, pushing state updates downward via delegates, explicitly handling initial state replay (`PresenterReady()`), and contrasting event-driven vs. callback-driven async APIs are all worthwhile architectural concepts—especially in C#/Unity codebases where UI frameworks encourage tight coupling. However, despite the repo name, it is not true Flux/Redux/Elm-style unidirectional data flow: there is no single immutable state tree, no action/intent stream, and no pure reducer—it is really Passive View MVP with ad-hoc `BehaviorSubject`-like replay. Technically dated even for .NET 4.5.2 (raw `new Thread` + `Thread.Sleep` instead of `Task`/`async-await`, no `IDisposable`, no thread marshaling), so its value is purely historical/educational.

### Similar ideas in the industry
- **UniRx / R3 (Unity / C#)** — Provides `ReactiveProperty<T>`, which natively encapsulates value storage, change notification, and immediate initial-value replay (directly superseding `Label` + `PresenterReady()`), alongside composable async streams and `IDisposable` cleanup.
- **ReactiveUI (C# / .NET)** — Full reactive MVVM framework built on Rx.NET formalizing view-to-viewmodel data binding, async commands, and UI-thread scheduling with strong lifecycle management.
- **Android ViewModel + StateFlow / LiveData (Android / Kotlin)** — Mirrors the `SomeUi` + `SomeUiPresenter` + `PresenterReady()` pattern by holding UI state in a lifecycle-aware observable that automatically replays the latest state when a view attaches.
- **Fluxor / Redux.NET (C# / Blazor / .NET)** — Implements true Flux/Redux unidirectional data flow with a central immutable store, explicit actions, pure reducers, and async effects, whereas this repo relies on mutable OOP fields and imperative callbacks.
- **The Elm Architecture / MVU (Elm, Fabulous for F#/.NET, MauiReactor)** — Enforces strict unidirectional data flow (`Model -> View -> Msg -> Update`) with immutable state, eliminating manual `triggerSetLoading()` and `PresenterReady()` boilerplate.

### Challenges if continued
- **Architectural drift away from true UDF:** Scaling mutable private fields (`_isLoading`), public mutable sub-controls (`Label.Text` has a public setter), and manual `triggerSetLoading()` calls easily leads to inconsistent intermediate states, missed notifications, and bidirectional mutations unless refactored into immutable state snapshots, explicit actions, and a reducer/store.
- **Concurrency, race conditions, and UI-thread marshaling:** `HttpService` and `HttpService2` spawn raw foreground `Thread` instances and invoke `SetLoading`/`SetText` directly from background threads. Any real UI host (WPF, MAUI, Unity) requires `SynchronizationContext`/main-thread marshaling, `async`/`await` with `CancellationToken`, and protection against out-of-order responses on `Retry()`.
- **Lifecycle and memory-leak hazards:** Even within 288 lines, `SomeUi.Dispose()` does not implement `IDisposable`, forgets to unsubscribe `_httpService.OnAddError`, and `HttpService.OnDescription` has an empty `remove` block. Meanwhile, `SomeUi2`'s per-call delegates capture `this` and fire on a torn-down UI if an async call completes after disposal.
- **Ecosystem redundancy and boilerplate:** Hand-rolling `Label`, `Action<T>` binding properties, and `PresenterReady()` hooks creates heavy boilerplate already solved more safely by `async`/`await`, Rx.NET/R3, `CommunityToolkit.Mvvm`, or modern MVU/Flux libraries.

---

## 9. `try-microservices-locally`

- **Repo:** <https://github.com/phucvin/try-microservices-locally>
- **Activity:** Created 2017-09-24 · Last pushed 2017-09-24
- **Stack:** Go (pre-modules GOPATH)
- **Verdict:** **Good learning exercise**

### What is it?
A minimal, single-commit, pre-Go-modules (`GOPATH`) experiment (~155 lines of Go across 5 files, no README) modeling two banking "microservices" (`account` and `transfer`) as in-process Go packages communicating through a shared in-memory event store (`evsrc`). `evsrc` defines an `Ev` interface with `OpenAccountEv` and `TransferEv` structs stored in a global slice (`evsrc.list`) with `Push` and `QueryForAccount` operations. `transfer.Transfer` blindly appends `TransferEv` records without checking balances. `account.GetBalance` lazily projects balances by replaying events from `evsrc` and attempts optimistic, read-time overdraft reconciliation: if an outgoing transfer exceeds the sender's balance, it mutates `transferEv.Canceled = true` in-place, resets cached balances, and recursively recomputes. `simulation_test.go` exercises a cascading overdraft scenario (`acc1 -> acc2 -> acc3`), though the implementation is incomplete and buggy (notably `account.go` line 42 overwrites `lastCalculatedBalance[accountID]` with `ev.EID()` instead of updating `lastEvID` and caching the computed balance, and cascading cancellations do not cleanly propagate across downstream accounts).

### What problems does it solve?
Targets two pain points: (1) the operational overhead of running and testing multi-service architectures locally (avoiding separate processes, databases, and brokers by co-locating service packages around an in-memory event log), and (2) write-path decoupling in distributed transactions—exploring how a transfer service can accept commands asynchronously without synchronously locking or querying the account service, deferring overdraft detection and balance reconciliation to event replay.

### Is it a good idea?
As a quick learning spike to test event-sourcing and eventual-consistency ideas in-process without spinning up containers or message brokers, the approach is genuinely clever—prototyping service boundaries as Go packages driven by a single `simulation_test.go` gives instant feedback. However, the specific domain architecture it explores is flawed for production systems: accepting unvalidated transfers, letting downstream accounts spend phantom balances, and mutating historical events in-place (`transferEv.Canceled = true`) during a read (`GetBalance`) breaks both financial accounting guarantees and core event-sourcing immutability. Worth keeping as a historical learning artifact, not as a foundation to build on directly.

### Similar ideas in the industry
- **EventStoreDB / KurrentDB (Event Sourcing / Multi-language)** — Dedicated append-only event store with stream projections; enforces strict event immutability and compensating events instead of mutating past events in-place like `evsrc`.
- **Axon Framework (Java / JVM)** — Full CQRS and Event Sourcing framework that validates invariants on command-side aggregates and orchestrates cross-account transfers via Sagas rather than lazy read-time rollbacks.
- **Temporal (Go / Multi-language)** — Durable workflow engine for multi-service Sagas and compensating transactions, including an in-process test harness that achieves the same fast local simulation goal cleanly.
- **Watermill (Go)** — Idiomatic Go library for event-driven microservices supporting an in-memory `GoChannel` pub/sub for local testing alongside Kafka/NATS/RabbitMQ for production.
- **TigerBeetle (Financial Ledger DB / Zig)** — Purpose-built double-entry accounting database using atomic two-phase pending/posted transfers to prevent the exact cascading overdraft scenario explored in `simulation_test.go`.

### Challenges if continued
- **Replacing read-time event mutation with real event-sourcing invariants:** Mutating `TransferEv.Canceled = true` inside `GetBalance` violates log immutability, causes read-order-dependent side effects, and cannot reliably cascade rollbacks across multi-hop transfers (`acc1 -> acc2 -> acc3`). Fixing this requires immutable compensating events and a Saga or two-phase hold/commit flow on the write side.
- **Immediate implementation bugs and concurrency hazards:** `account.go` relies on unsynchronized package-level globals (`lastEvID`, `lastCalculatedBalance`, `nextAccountID`, `evsrc.list`) and has the line-42 typo assigning `ev.EID()` to `lastCalculatedBalance` instead of `lastEvID`.
- **Modeling real distributed failure modes:** Direct in-memory calls to `evsrc.Push` hide network latency, message reordering, duplicate deliveries (requiring idempotency keys), serialization/schema evolution, and crash recovery.
- **Modernizing the 2017 Go setup:** Migrating away from legacy `GOPATH` structure (`src/phucvin.me/trymicros`) and hardcoded Windows VS Code paths to `go.mod`, replacing package singletons with injectable instances, and adding persistence/snapshotting.
- **Differentiating in a mature ecosystem:** Competes with Watermill, Temporal's test environment, Dapr, and Testcontainers, making it hard to justify beyond a personal educational sandbox.

---

## 10. `test-mvrvm`

- **Repo:** <https://github.com/phucvin/test-mvrvm>
- **Activity:** Created 2017-09-24 · Last pushed 2017-09-24
- **Stack:** C# (.NET Framework 4.5.2, ReactiveProperty, Rx.NET, Ninject)
- **Verdict:** **Solid pattern, rough prototype**

### What is it?
A single-commit (~400 LOC) C# .NET Framework 4.5.2 console prototype exploring a reactive client architecture ("MVRVM" — Model-View-ReactiveViewModel) built with ReactiveProperty 2.2, Rx.NET 2.2.5, Ninject 3.2, and Newtonsoft.Json 6.0.8. Domain logic is organized into "DLO" (Data/Domain Logic Object) classes—`TodoDlo`, `TodoItemDlo`, `MoneyDlo`, and `CurrentUserDlo`—wired via Ninject (mixing constructor injection and `[Inject]` property injection). State changes are exposed reactively via `ReactiveProperty<T>`, `ReadOnlyReactiveCollection<T>`, and `Subject<int>` on `Scheduler.Immediate`. Persistence is modeled as a flat JSON-serializable `LocalSaveRaw` DTO (parallel `todo_contents[]`/`todo_is_dones[]` arrays, XOR-masked `money_v`/`money_k` alongside plaintext `money`, user credentials, and a group-import timestamp dictionary), and networking is stubbed via a callback-based `HttpRequester` subclassed by `FakeHttpRequester` in `Program.cs`. No UI layer, real HTTP/file I/O, or test suite; `Program.cs` acts as a manual console harness.

### What problems does it solve?
Targets client-side state management and testability pain points (especially in game/mobile apps): decoupling domain/business logic from UI views via reactive observable properties and collections, enabling headless execution with fake HTTP/save dependencies via DI, coordinating cross-domain side effects (e.g., consuming virtual currency in `MoneyDlo` when adding a `TodoDlo` item and forcing an immediate save), gating concurrent mutations via an `IsBusy` flag, and sketching basic client-side save obfuscation and incremental group-import sync tracking.

### Is it a good idea?
The underlying architectural instinct—decoupling reactive domain/logic models from views via `ReactiveProperty`/Rx and injecting persistence and HTTP dependencies so business logic can be exercised headlessly—is genuinely sound and mirrors what became standard practice in Unity (MVRP with UniRx + Zenject) and .NET client apps. However, this specific repo is a rough, single-commit 2017 scratchpad rather than a reusable library: it mixes raw persistence structs (`LocalSaveRaw`) directly into domain objects (even noting a `FIXME` about bypassing a DAO), uses parallel arrays instead of structured models, relies on callback-based HTTP instead of `async`/`await` or observables, and contains several concrete prototype bugs (such as inverted login-check logic in `HttpRequester` leaving `TodoDlo.IsBusy` stuck at `true`, and broken XOR currency obfuscation in `MoneyDlo` that still stores plaintext `money`). Good as a personal architecture experiment, not something to build on directly.

### Similar ideas in the industry
- **UniRx + Zenject / Extenject (Unity / C#)** — The direct Unity ecosystem counterpart to this exact MVRP/MVRVM pattern, combining `ReactiveProperty`/`ReactiveCollection` with DI for testable game client architectures.
- **ReactiveUI (C# / .NET / Avalonia / MAUI)** — Full-featured reactive MVVM framework on Rx.NET that solves `IsBusy` gating, async commands, and observable collections via `ReactiveCommand` and DynamicData.
- **CommunityToolkit.Mvvm (C# / .NET)** — Microsoft's modern, source-generated MVVM toolkit providing lightweight observable properties and async relay commands without Rx boilerplate.
- **MobX (JavaScript / TypeScript)** — Cross-platform reactive state management library with fine-grained observable properties and decoupled actions similar to `ReactiveProperty`-based DLOs.
- **Android ViewModel + StateFlow + Hilt (Kotlin / Android)** — Modern mobile architecture pairing DI with reactive state streams and a repository/DAO layer that cleanly separates raw persistence from UI/domain state.

### Challenges if continued
- **Legacy .NET stack migration:** Targets EOL .NET Framework 4.5.2, old-style MSBuild/`packages.config`, Rx 2.2.5, ReactiveProperty 2.2, and Ninject 3.2; reviving for modern .NET 8+ or Unity (e.g., R3 + VContainer) requires replacing project infrastructure and rewriting obsolete APIs.
- **Tight coupling to a shared mutable persistence god-struct:** Every DLO directly reads and mutates `LocalSaveRaw` fields, and `TodoDlo` stores items as parallel arrays (`todo_contents[]`, `todo_is_dones[]`), making schema migrations, partial saves, and transactional integrity fragile without a proper Repository/DAO layer.
- **Fragile async, threading, and busy-state management:** Relying on `Scheduler.Immediate`, a single boolean `IsBusy` guard, and raw `Action` callbacks already causes a stuck-busy bug when `HttpRequester` returns `false` without firing callbacks; real apps need `async`/`await` or `IObservable` pipelines with cancellation, error propagation, and UI-thread scheduling.
- **Subscription and disposal lifecycle bugs:** Manual `IDisposable` handling already leaks or mis-orders cleanup (`TodoDlo.Dispose` disposes `_items` before iterating it to dispose children; `Load()` clears `_items` without disposing old `TodoItemDlo` instances).
- **Broken client-side currency protection:** `MoneyDlo`'s XOR obfuscation (`money_v ^ money_k`) is defeated by storing plaintext `money` alongside it and generating `money_k == 0` half the time via `(1 - _rand.Next(2))`; any real economy requires server-authoritative validation.

---

## 11. `q2c`

- **Repo:** <https://github.com/phucvin/q2c>
- **Activity:** Created 2017-09-24 · Last pushed 2017-09-24
- **Stack:** C# (.NET Framework 4.5.2)
- **Verdict:** **Clever prototype, flawed execution**

### What is it?
A minimal, single-file C# console prototype (.NET Framework 4.5.2, Visual Studio 2015, 377 lines in `Program.cs`, 1 commit) implementing a custom pull-and-queue reactive programming model ("q2c" / queue-to-change). Core primitives:
1. `ChangeMaster` — a static deferred-execution queue that drains queued `Action` lambdas in waves with a re-entrancy guard.
2. `ITraverse` — a manual tree-traversal interface.
3. `Ir<T>` — a reactive value interface exposing a monotonic `long Stamp` and `T Value`.
4. `Rv<T>` — a mutable reactive source cell whose `Set()` queues value + stamp updates.
5. `Rc<T,R>` and `Rc<T1,T2,R>` (exposed via `Ir.Map` and `Ir.Combine`) — computed nodes that recursively traverse upstream origins, compare origin stamps against `_lastKnownOriginStamp`, and queue recomputations (asserting origin stamps do not mutate mid-conversion).
6. `Rn<T>` — a sink node that queues an `Action<T>` side effect on stamp change.

`Program.Main` demonstrates binding a simulated game entity (`Box` with `Hp`, `IsDead`, `Position`, `IsOnGround`, `Coins`) to a mock HUD (`Label`, `Visibility`), pumping `ChangeMaster.Process()` and `Traverse()` in a while-loop until quiescent. No README, tests, or packaging, and several unfinished pieces (e.g., `Rn.Stamp`/`Value` throw `NotImplementedException`).

### What problems does it solve?
Targets reactive state propagation and UI/HUD data binding in game loops and simulations—specifically trying to avoid push-based observer spaghetti (event subscription/unsubscription memory leaks, re-entrant mutation cascades, and inconsistent intermediate states) by batching all state writes through a central queue (`ChangeMaster`) and polling monotonic version stamps (`Stamp`) during explicit update traversals.

### Is it a good idea?
The underlying intuition—combining frame-batched deferred mutations (`ChangeMaster`) with version-stamped pull-based dirty checking (`Ir<T>.Stamp`) to bind game state to UI without observer subscription leaks or mid-frame re-entrancy glitches—is genuinely sound and anticipates patterns later popularized by ECS change filters and pull-based signals. However, the specific "queue-to-change on traverse" execution model is awkward in practice: deferring derived recomputations back into `ChangeMaster` forces O(depth) full-tree traversals per frame, creates duplicate work on shared/diamond nodes, and shifts heavy boilerplate onto developers who must manually implement `ITraverse` everywhere. Thoughtful experiment exploring alternatives to push-based Rx/events, superseded by modern push-pull signals and zero-allocation reactive frameworks.

### Similar ideas in the industry
- **Salsa (Rust / rust-analyzer)** — Pull-based incremental computation engine using revision stamps and memoization; solves the same DAG dirty-checking problem with proper early cutoff, cycle recovery, and automatic dependency tracking.
- **SolidJS / Preact Signals / Angular Signals (TypeScript / Web UI)** — Fine-grained reactive primitives (`signal`, `computed`, `effect`) using version counters and hybrid push-pull propagation to deliver glitch-free updates without manual `ITraverse` boilerplate.
- **Rx.NET / UniRx / R3 (C# / Unity)** — Industry-standard push-based reactive libraries for C# and Unity HUD binding (`ReactiveProperty`, `Select`, `CombineLatest`), with R3 adding zero-allocation optimizations.
- **Unity DOTS / ECS Change Filters (C# / Game Engines)** — Uses monotonic change-version stamps polled during explicit system passes to detect mutated components with zero GC allocations, closely mirroring `q2c`'s Stamp-and-Traverse philosophy at engine scale.
- **MobX (JavaScript / TypeScript)** — Batches state mutations inside transactions/actions before propagating changes through a computed derivation graph to side-effect reactions.

### Challenges if continued
- **Broken propagation semantics & subtle bugs in the core algorithm:** Because `Rc.Traverse()` defers recomputation into `ChangeMaster` instead of computing inline, a dependency chain of depth *N* requires *N*+1 full-tree `Traverse()`+`Process()` waves to settle. Shared/diamond dependencies (already present in the demo: `box.IsDead` is traversed by both `Box.Traverse()` and `Hud.Traverse()`) queue duplicate recomputations in the same pass because `_lastKnownOriginStamp` is not updated until the queued closure executes. Additionally, `Rv.Set()` has an inverted equality guard (`newValue == null || _value != null || !newValue.Equals(_value)`) that evaluates `true` for all non-null values and boxed structs, causing spurious updates.
- **Manual `ITraverse` wiring and static global state do not scale:** Every composite entity and UI widget must manually implement `ITraverse` and wire child traversals, which breaks down for dynamic collections or spawning/despawning entities. `ChangeMaster` is a non-thread-safe static singleton.
- **Per-update heap allocations undermine its game-loop target:** Every dirty check and `Rv.Set()` allocates a new `Action` closure, and `ChangeMaster.Process()` allocates a new `List<Action>` on every wave—causing GC frame-time spikes in C# game engines.
- **Missing essential reactive primitives:** No value-equality cutoff in `Rc` (changing `Hp` from 100 to 90 still increments `IsDead.Stamp` and fires `CoinVisibility`'s sink even though `IsDead` stays `false`), no dynamic/higher-order operators (`FlatMap`/`Switch`), no reactive collections, no cycle detection, and no disposal lifecycle.
- **Stiff competition and dated baseline:** Single 377-line .NET Framework 4.5.2 VS 2015 console prototype competing against mature zero-allocation C# reactive libraries (R3, UniRx) and built-in ECS change-versioning.

---

## 12. `edi`

- **Repo:** <https://github.com/phucvin/edi>
- **Activity:** Created 2017-09-24 (copyright 2016) · Last pushed 2017-09-24
- **Stack:** C# (.NET Framework 4.5.2)
- **Verdict:** **Clever pattern, rough prototype**

### What is it?
`edi` is a small, private .NET Framework 4.5.2 C# console proof-of-concept (VS 2015, copyright 2016, pushed Sept 2017, no README or tests) containing two successive architectural iterations of a deterministic, centrally-mediated state-management engine for game simulations:
- **Iteration 1 (`Program.cs`, `Main2`, 253 lines):** Wraps mutable fields in `V<T>` assigned sequential numeric IDs (`Vid` starting at 1001) by a singleton `TheVidGiver`; mutations are staged in `AboveAll.Modi` and batch-applied via `AboveAll.ApplyAllModis` while logging stringified changes across a toy `Uni`/`Mob` simulation with injected `Time` and seeded `Random`.
- **Iteration 2 (`Prototype.cs`, `Main`, 793 lines):** Evolves this into a hierarchical, path-addressed state tree (`edi.prototype`): mutable scalars use `Wrap<T>`, derived readonly values use `WrapF<T>` (`Func<T>`), and mutable collections use `WrapList<T>`, all registered via `WeakReference` in `SimpleWrapManager` under dot-delimited paths (e.g., `Universe.Battle.Characters.Character#_1.Health.Current`) with `PathedList<T>` auto-incrementing entity IDs. Direct writes to `Wrap<T>.Value` are disallowed; all changes must be queued via `WrapMaster` (either typed or string-serialized via `Convert.ChangeType`), which detects same-tick write-write or clear-vs-add race conditions and throws `InvalidOperationException`. `Prototype.step` drives a fixed-point loop (`ApplyQueuedModifications -> Universe.Traverse` until no internal modifications remain), recording only external boundary inputs in history. The demo models a `Universe` state machine (`Loading -> Init -> PrepareBattle -> Wait`) with a `Popup` and a `Battle` of `Characters` whose `Health` decays over time and randomly heals via `PendingAdds`.

Strictly an exploratory spike: no replay runner is wired up, minor bugs exist (duplicate `" << "` in `PrintHistoryModifications`, `Program.cs` printing `Time.Value` for `TheJson`), and internal timers (`_lastTime`, `_lastRandomTime`) leak outside the `Wrap` system.

### What problems does it solve?
Targets common pain points in game and interactive simulation architecture: (1) non-deterministic bugs and hard-to-reproduce QA issues—by funneling all external inputs (time, random seeds, UI clicks, CSV data) through a single serializable queue and recording only external mutations for replay; (2) order-dependent mid-frame state mutation bugs—by deferring writes into a central queue, applying them atomically between traversal passes, and throwing on conflicting writes to the same variable within a step; (3) opaque state trees—by giving every variable a canonical hierarchical path for generic state dumps, string-command scripting, and serialization without reflection; and (4) tight coupling between simulation logic and UI/engine frameworks—by representing UI triggers (`IsOkClicked`, `ToastToShow`) and clocks as plain wrapped values at the boundary.

### Is it a good idea?
The core architectural instinct—especially in Iteration 2 (`Prototype.cs`)—is genuinely clever and ahead of typical 2016–2017 Unity/C# game code. Combining a deterministic fixed-point step loop (`ApplyQueuedModifications -> Traverse` until quiescence), deferred transactional writes with explicit write-write conflict detection, canonical string-path addressing with `WeakReference` cleanup, and logging only external boundary inputs (excluding derived internal micro-steps) is a clean, thoughtful foundation for deterministic game logic and reproducible bug replays. However, as implemented, the ergonomics and mechanics are rough and leaky: every state field requires verbose `Wrap<T>`/`IPath`/`DoneSetup()` boilerplate, and even the author bypassed the model by storing `_lastTime` and `_lastRandomTime` as raw private fields. The strict "throw on second write" rule also forces awkward workarounds like `Health.PendingAdds` (`WrapList<int>`) just to accumulate multiple heals in one tick, while `BoxedValue` boxing, repeated string concatenation in `Path`, static singletons (`WrapMaster`), and an unguarded `while (didApply)` loop make it impractical for production without a major redesign.

### Similar ideas in the industry
- **Redux / The Elm Architecture (JS / Web)** — Shares the unidirectional, centrally-mediated state mutation and input/action-log replay philosophy, though Redux/Elm use immutable state trees and pure reducers instead of mutable path-registered wrapper objects.
- **MobX / UniRx `ReactiveProperty` (JS / C# Unity)** — Offers a similar observable (`Wrap<T>`) and computed (`WrapF<T>`) value-wrapper API, but propagates changes via fine-grained push dependency graphs rather than full-tree `Traverse()` fixed-point polling.
- **Photon Quantum / GGPO (C# Unity / C++)** — Solves the exact same deterministic game simulation, seeded RNG, and input-only replay problem, but uses unmanaged blittable ECS snapshots and fixed-point math instead of boxed heap wrappers and string paths.
- **Unity Netcode `NetworkVariable` / Unreal Property System (C# / C++)** — Wraps game state fields in generic containers with hierarchical object addressing for serialization and synchronization, though optimized for network replication rather than local transactional fixed-point stepping.
- **Synchronous Reactive Languages like Esterel / Statecharts (Formal & Embedded Systems)** — The `Traverse()`-until-quiescence microstep loop with atomic commits and write-conflict detection mirrors synchronous reactive semantics, implemented ad-hoc here in imperative C#.

### Challenges if continued
- **Eliminating heavy boilerplate:** Hand-wiring `IPath`, `Wrap<T>`, `DoneSetup()`, and `Traverse()` does not scale beyond a toy demo; reviving in modern C# requires Roslyn Source Generators (or an ECS/record-based model) to auto-generate wrappers, paths, and traversal.
- **Fixing boxing, GC, and path-lookup overhead:** `IWrap.BoxedValue` boxes every primitive, `Path` concatenates strings on every property read (`_parent.Path + "." + _name`), and `WrapList<T>` maintains a duplicate `List<object>` mirror—causing severe GC pressure in a real-time game loop without unboxed typed command buffers and hashed/interned path IDs.
- **Closing determinism and serialization gaps:** Floating-point time math is not cross-platform deterministic (requiring fixed-point math), `Convert.ChangeType` breaks on enums (`Universe.State`), custom types, and locale-sensitive floats, and untracked private fields (`_lastTime`, `_lastRandomTime`) plus `WeakReference` GC timing nondeterminism break exact replay fidelity.
- **Removing global singletons and guarding the fixed-point loop:** `WrapMaster` is a static singleton (blocking parallel simulations and isolated unit tests), the unbounded `do { ... } while (didApply)` loop has no cycle/max-iteration guard, and concurrent writers need principled reducers/combinators rather than ad-hoc `PendingAdds` lists.
- **Standing out in a mature C#/game-dev ecosystem:** Competes with zero-allocation ECS frameworks (Unity DOTS, Arch), reactive libraries (R3/UniRx), and deterministic engines (Photon Quantum); to justify adoption, `edi` would need a narrow high-leverage niche like turn-based/strategy game state machines with out-of-the-box visual state-tree inspection and replay debugging.

---

## 13. `Components`

- **Repo:** <https://github.com/phucvin/Components>
- **Activity:** Created 2017-09-24 (LÖVE 0.8.0 era, ~2012) · Last pushed 2017-09-24
- **Stack:** Lua (LÖVE 0.8.0)
- **Verdict:** **Good learning exercise**

### What is it?
An early-stage LÖVE2D (0.8.0-era) prototype implementing a stateful Entity-Component system on top of a custom Lua micro-framework called `flatmoon`. Contains 14 Lua files (single commit, no README): `flatmoon/engine.lua` (600 LOC) provides the core `Thing` entity container, `Coms` component registry (`add`, `get`, `refresh`, `registerSubDraw`; `remove` is disabled), tag queries (`Thing.getAll`), z-ordered draw list, deferred/immediate destruction with metatable-trapped dead objects (`makeInaccessible` + `NOTHING` sentinels), coroutine sequencing (`seq`, `yield`, `wait`), and input listeners; `flatmoon/tweener.lua` adds coroutine-driven sequential/parallel tweening (`stween`/`ptween`) with Penner easings; and `flatmoon/director.lua` adds a monkey-patched scene manager (unused in the demo). Eight small modules under `components/` (`Transform`, `Color`, `Shape`, `ShapeRenderer`, `ImageRenderer`, `StickMouse`, `Health`, `Damage`) implement data and behavior via `refresh()` (dependency lookup + pre-draw hook registration) and `always()` (per-frame update). `main.lua` wires these into a minimal playable demo: a mouse-following puck that clicks to fire tweened bullets at 10 stationary red circle enemies with health.

### What problems does it solve?
Addresses entity composition over rigid OOP inheritance in LÖVE2D games by letting entities (`Thing`) assemble reusable behaviors (`Transform`, `Shape`, `ShapeRenderer`, `ImageRenderer`, `Health`, `Damage`, `StickMouse`). Through `flatmoon`, it also reduces raw LÖVE callback boilerplate by managing entity lifecycles, z-ordered rendering, input listeners, scene teardown (`director`), coroutine-based sequencing/tweening (`wait`, `stween`, `ptween`), and fail-fast detection of dangling references to destroyed entities.

### Is it a good idea?
As a personal learning exercise or lightweight game-jam prototype, it's a solid, pragmatic exploration of component composition and coroutine-driven game scripting. Several design touches are genuinely clever: the two-phase `coms:add()` + `coms:refresh()` pattern cleanly wires inter-component dependencies regardless of attachment order; `makeInaccessible()` turns destroyed entities into metatable-trapped "poisoned" tables (while keeping `:alive()` and `:destroy()` callable via `rawset`) to catch dangling references immediately; and coroutine-based `stween`/`ptween`/`wait` make sequential animations concise. However, as a reusable library or modern game architecture, the idea is dated and redundant: it implements Unity-style stateful Object-Components rather than a decoupled data-oriented ECS, couples rendering/collision/damage directly into components with O(N²) queries, targets obsolete LÖVE 0.8.0 / Lua 5.1, and is superseded by mature LÖVE libraries like Concord, tiny-ecs, and HUMP.

### Similar ideas in the industry
- **Unity `GameObject`/`MonoBehaviour` (C# / Unity)** — Uses the same entity-container + stateful component model (`GetComponent<T>()`, `Start`/`Update` hooks analogous to `refresh`/`always`) rather than pure data-oriented ECS.
- **Concord (Lua / LÖVE2D)** — Modern, idiomatic ECS library for LÖVE cleanly separating data components from processing systems with proper entity/world management and LÖVE 11+ support.
- **tiny-ecs (Lua / LÖVE2D)** — Lightweight single-file Lua ECS offering filtered system queries and decoupled composition without `flatmoon`'s monolithic engine coupling.
- **HUMP (Lua / LÖVE2D)** — Provides modular gamestate (like `flatmoon.director`), timer/tweening (like `flatmoon.tweener`), camera, and signal utilities without forcing a single entity base class.
- **Godot Node/Scene Tree (GDScript / Godot)** — Achieves composable game behaviors (transforms, collision shapes, renderers, health/damage) via attachable child nodes with standardized lifecycle callbacks.
- **Bevy ECS / EnTT (Rust / C++)** — Modern archetype/sparse-set ECS frameworks decoupling pure data components from systems for cache locality and scalability.

### Challenges if continued
- **LÖVE 0.8.0 & Lua 5.1 bitrot:** Migrating to modern LÖVE (11.x/12.x) and LuaJIT/Lua 5.4 requires rewriting `conf.lua` (`t.screen -> t.window`), normalizing 0–255 colors to 0–1, replacing Lua 5.1's deprecated implicit `arg` table in `Coms:registerSubDraw` and `unpack`, updating input callbacks, and removing the brittle `love.timer.sleep(0.016 - dt)` manual frame limiter.
- **Incomplete and buggy core primitives:** `Coms:remove()` is commented out so components cannot be detached dynamically; `Shape` only implements circle-circle collision while ignoring local shape offsets (`s.x`, `s.y`), rotation, and scale; `ImageRenderer`/`ShapeRenderer` also ignore `Transform` rotation/scale; and `Damage:always()` calls `self.shape:isCollideWith(s)` before checking if `s` is non-nil.
- **Non-deterministic rendering and tight coupling:** `listSubDrawPre` and `listSubDrawPost` iterate via Lua's `pairs()`, making draw order between multiple renderers on the same entity undefined, while `Damage` directly mutates other entities' `Health` instead of emitting events.
- **Performance and scaling bottlenecks:** `Damage:always()` allocates a new table via `Thing.getAll()` every frame and runs O(N·M) collision checks without spatial partitioning; `things`, `drawList`, and `listeners` rely on linear scans over `NOTHING`-sentinel arrays that never shrink; and `director.lua` monkey-patches `Thing.new`/`listener.add` with unresolved scene-transition race conditions.
- **Crowded LÖVE2D ecosystem:** Mature modular libraries (`Concord`, `tiny-ecs`, `bump.lua`, `flux`, `hump`) already cover ECS, collision, tweening, and scenes cleanly; continuing would need a compelling niche (most plausibly leaning into its coroutine-first scripting model).

---

## 14. `MultiMatch`

- **Repo:** <https://github.com/phucvin/MultiMatch>
- **Activity:** Created 2017-09-24 (LÖVE 0.8.0 era, ~2012) · Last pushed 2017-09-24
- **Stack:** Lua (LÖVE 0.8.0, Lua Lanes)
- **Verdict:** **Clever twist, dated stack**

### What is it?
A complete, playable 2D match-3 puzzle game written in Lua for LÖVE (Love2D) 0.8.0, built on top of the same custom coroutine-driven micro-engine (`flatmoon`). Unlike standard match-3 games, `MultiMatch` lets players make **3 adjacent swaps** on an 8×8 grid before match detection fires (`Board.lua`), displaying remaining swaps on a custom mouse cursor. After the 3rd swap, all 3+ horizontal/vertical runs explode simultaneously with particle effects and recursive gravity cascades (`Board:explode`) that score exponentially with depth; new gems only spawn after cascades finish (`Board:spawnGems`), avoiding accidental free matches. Includes Challenge mode (Easy/Normal/Hard with 4–6 gem kinds, turn limits, escalating score targets in `LevelManager.lua`, and save/resume via `Saved.lua`), Fun mode (3 gem kinds, single-turn high-score sandbox), a background Lua Lanes DFS hint solver on `F1` (`getBestMoves.lua`), async asset loading (`love-loader`), sprite-sheet animations (`AnAL`), custom GUI widgets (`GUI.lua`), and full scenes (`menu`, `play`, `how`, `highs`, `settings`). Uploaded in 2017 as a single commit with no README, it is a feature-complete ~2012-era indie/student game frozen on legacy LÖVE 0.8.0 APIs.

### What problems does it solve?
Targets two areas: (1) **Gameplay**—alleviates the single-swap myopia and RNG-heavy cascade feel of classic match-3 games by giving players a 3-swap planning window and deterministic refill-after-cascade resolution to engineer deliberate chain reactions; (2) **LÖVE game-loop ergonomics**—`flatmoon` eliminates callback hell for chained animations, tweening, audio timing, and scene teardown via Lua coroutines (`Thing:seq`, `wait`, `stween`/`ptween`) and scene-scoped entity/listener tracking, while offloading combinatorial move search to a background Lua Lanes thread to keep the 60 FPS render loop responsive.

### Is it a good idea?
The core gameplay twist is genuinely clever: letting the player spend a 3-swap budget before evaluating matches—and deferring new gem refills until the entire gravity cascade finishes—turns a casual, luck-heavy match-3 into a deterministic combo-engineering puzzle. Even the `F1` hint solver's design (revealing 2 of the 3 swaps so the player still completes the combo) is thoughtful. On the engineering side, `flatmoon`'s coroutine-based sequencing (`seq` + `stween`/`ptween`) is an idiomatic, readable Lua pattern for orchestrating game juice. However, the codebase itself is a frozen ~2012 LÖVE 0.8.0 portfolio/learning project with brittle globals, monkey-patched constructors, and a native Lua Lanes dependency—so while the **game design idea** is worth reviving (especially as a crisp web/mobile daily puzzle), the implementation should be treated as a prototype rather than a production base.

### Similar ideas in the industry
- **Bejeweled (PopCap / multi-platform)** — The direct visual and audio template (8×8 gem grid, spinning selection sprites, and escalating "Good" to "Unbelievable" cascade voiceovers), though Bejeweled resolves every swap immediately.
- **Puzzle & Dragons (GungHo / Mobile)** — Shares the core multi-swap combo-engineering hook within a single turn, using continuous timed orb-dragging rather than `MultiMatch`'s discrete 3-swap budget.
- **Tower of Saviors (Mad Head / Mobile)** — Another multi-swap match-3 puzzle system built around deterministic cascade planning, paired with deep RPG meta-progression.
- **Candy Crush Saga (King / Mobile)** — Popularized the turn-limited, target-score Challenge loop used in `MultiMatch`, but relies on single-swap special-piece synergies rather than multi-swap board setup.
- **HUMP / Flux / Knife (LÖVE / Lua ecosystem)** — Modern modular LÖVE libraries covering the same gamestate management, tweening, and coroutine/timer scheduling as `MultiMatch`'s custom `flatmoon` engine without global monkey-patching.

### Challenges if continued
- **Breaking LÖVE 0.8.0 → 11.x/12.x migration:** Won't run on modern LÖVE without porting `conf.lua` (`t.screen -> t.window`), 0–255 to 0–1 color ranges across all draw calls, removed APIs (`love.graphics.drawq`, `love.filesystem.exists`), `ParticleSystem` API changes, and replacing the external native `lua51-lanes` dependency with LÖVE's built-in `love.thread` and channels.
- **Combinatorial blowup and edge-case bugs in the DFS hint solver (`getBestMoves.lua`):** Naive brute-force search evaluates O(N^k) full board simulations (and currently skips the last row/column by looping `1..nr-1`, `1..nc-1`), making depth 3+ infeasible without symmetry pruning, beam search, or transposition tables.
- **Engine and state-management fragility:** `flatmoon.director` globally monkey-patches `Thing.new` and `listener.add` (with an acknowledged scene-transition race comment), `Gem:draw` allocates a new `Quad` every frame per unselected gem, `Board:moveOut` has a typo (`if aftern then after() end`), and `Saved.lua` uses unescaped Lua table serialization loaded via `love.filesystem.load` (a quote in `playerName` breaks saves).
- **Hardcoded desktop layout vs. mobile/web expectations:** All UI coordinates, board sizing (960×640), and the hover-based swap-counter cursor assume desktop mouse input; adapting to modern mobile/web requires responsive scaling, touch-drag affordances, and deeper progression/mechanics (obstacles, power-ups, daily puzzles).
- **Asset provenance and licensing:** Bundled assets include Windows Consolas fonts (`consola*.ttf`) and Bejeweled-style announcer voice clips that would need properly licensed or original replacements before any public/commercial distribution.
