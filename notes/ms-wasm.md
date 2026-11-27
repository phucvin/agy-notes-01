# MS-Wasm (Memory-Safe WebAssembly)

Notes on **MS-Wasm** (Michael et al., POPL 2023; UCSD PLSysSec, CMU, Microsoft Research, Cambridge), the threat model it addresses in standard WebAssembly linear memory, its current adoption/standardization status, and why it hasn't been standardized.

See also: [`notes/wasm-memory-models.md`](wasm-memory-models.md).

---

## 1. The Threat Model: How Attacks Happen Inside Wasm Linear Memory

WebAssembly's sandbox protects the **host** from a Wasm module and prevents classic native exploits like overwriting return addresses or executing injected shellcode—because the Wasm call stack and code are separate from linear memory.

**However, inside linear memory itself, there is zero internal protection.** Everything C/C++ stores in memory—the shadow stack (local arrays, address-taken variables), the heap (`malloc`/`free` metadata), static globals, and even `.rodata` constants (writable in Wasm)—lives in **one flat, unprotected byte array** with no guard pages, no ASLR, and no stack canaries.

As demonstrated in *"Everything Old is New Again: Binary Security of WebAssembly"* (Lehmann et al., USENIX Security 2020), C/C++ memory bugs (buffer overflows, use-after-free, out-of-bounds reads) remain exploitable inside Wasm in four main ways:

1. **Data-Only Attacks Against Host Imports:**
   * Overflowing a buffer on the shadow stack or heap to overwrite a string, URL, file path, SQL query, or permission flag (`is_admin`) right before it is passed to a host import.
   * Turns a C parser bug into **XSS in the browser** or **arbitrary file read/write / privilege escalation in WASI/Node.js**, using the module's own legitimate host capabilities.
2. **Control-Flow Hijacking via `call_indirect`:**
   * Function pointers and C++ vtable pointers live in linear memory as plain `i32` table indices.
   * Overwriting one redirects `call_indirect` to **any other function in the table with the same Wasm signature** (since all C pointers lower to `i32`, many unrelated C functions share signatures like `(i32, i32) -> i32`), potentially invoking sensitive host imports.
3. **Information Leaks (Heartbleed-Style Over-Reads):**
   * Out-of-bounds reads can exfiltrate crypto keys, auth tokens, or another user's data from anywhere else in the same linear memory.
4. **Shared Linear Memory / Linked-Library Blast Radius:**
   * Untrusted parser libraries (e.g., image/PDF/XML) linked into the same linear memory can compromise the entire application's state from a single memory bug.

---

## 2. How MS-Wasm Works

MS-Wasm extends WebAssembly with **language-level capabilities** inspired by **CHERI**:

* **Segment memory:** Replaces or augments flat linear memory with discrete, bounded **segments**.
* **Unforgeable handles:** Pointers become unforgeable handles carrying `(base, bounds, permissions)` rather than raw `i32` offsets.
* **Tagged memory:** Per-word tags distinguish valid handles from raw integers so integer arithmetic cannot forge handles.
* **Portability:** Designed to compile either to **software bounds/tag checks** on conventional x86/ARM CPUs or directly onto **CHERI hardware capabilities** (e.g., Arm Morello).
* **Formal guarantees:** Follow-up work (*Iris-MSWasm*) mechanically verified spatial and temporal memory safety properties in Coq.

---

## 3. Current Status: Used or Standardized?

* **Status:** Strictly an **academic research project / prototype**.
* **Production adoption:** **Not** used in production.
* **Standardization:** **Not** on the official W3C WebAssembly CG standardization track.

---

## 4. Why MS-Wasm Hasn't Been Standardized or Adopted

1. **High Software Overhead on Mainstream CPUs:**
   * Without ubiquitous CHERI hardware, emulating full spatial + temporal memory safety in software incurs steep slowdowns (up to **~2× / ~198%** on PolyBenchC, and **~22–50%+** even for spatial-only or partial hardware-assisted variants like MPK), undermining Wasm's near-native performance pitch.
2. **Deep Toolchain & Engine Disruption:**
   * Supporting handles, segmented memory, and tagged words requires invasive changes across **LLVM/Clang** (similar to CHERI-LLVM) and across **every major Wasm JIT/runtime** (V8, SpiderMonkey, JSC, Wasmtime).
3. **Less Disruptive Industry Alternatives Won Bandwidth:**
   * **Coarse-grained sandboxing (Component Model / WASI / RLBox):** Isolates untrusted C/C++ libraries at the module/component boundary instead of securing every pointer *inside* a module.
   * **Memory-safe source languages & WasmGC:** New systems code targets Wasm from **Rust** (compile-time safety on flat linear memory), while managed languages target **WasmGC**, reducing demand for a capability-safe C/C++ target.
4. **High W3C Standardization Bar:**
   * W3C Wasm standardization requires multi-browser consensus and independent production implementations. Browser vendors have little appetite to maintain a third memory model alongside Linear Memory and WasmGC—especially one whose hardware acceleration (CHERI) isn't widely deployed.

---

## 5. Takeaway for `optrich-vm-02`

MS-Wasm's two biggest adoption blockers—**heavy software temporal/tag-bit overhead** and **retrofitting legacy C/LLVM pointers**—highlight why `optrich-vm-02` makes three deliberate simplifications:
* **Split blocks (`bytes` vs. `refs`)** instead of per-word capability tags.
* **Tracing GC** instead of per-access temporal revocation checks for manual `free()`.
* A **native capability-aware language frontend (Optic)** instead of forcing legacy C/LLVM onto handles.
