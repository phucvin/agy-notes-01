# `unkernel` `fib(40)` Benchmark & Performance Notes

- **Environment:** [`pithings/unkernel`](https://github.com/pithings/unkernel) (`linux/arm64`, 4 vCPUs, running in browser via WebAssembly)
- **Workload:** Naive recursive `fib(40)` (`fib(n-1) + fib(n-2)`, no memoization)
  - Result: `102,334,155`
  - Function calls: `331,160,281`
  - Profile: 100% single-threaded, zero syscalls inside recursion, max stack depth 40 (L1-cache resident). Runtime depends almost purely on single-core CPU speed + per-call language/runtime overhead.

---

## Measured Results on `unkernel` (`linux/arm64`)

Each benchmark measured only the `fib(40)` call itself (excluding process startup and compilation), passing `n` via CLI argument to prevent compile-time constant folding.

| Language | Runtime / Compiler | Duration | Relative to GCC `-O2` |
| :--- | :--- | :---: | :---: |
| **Go** | `go 1.24.4` | **1.92 s** | 0.7× |
| **C (`-O3`)** | `gcc 14.2.0` | **2.46 s** | 0.9× |
| **C (`-O2`)** | `gcc 14.2.0` | **2.71 s** | 1.0× |
| **Fil-C (`-O2`)** | `fil-c 0.687` (`clang 20.1.8`) | **5.85 s** | 2.2× |
| **Fil-C (`-O3`)** | `fil-c 0.687` (`clang 20.1.8`) | **5.96 s** | 2.2× |
| **Node.js** | `v26.13.1` | **6.10 s** | 2.3× |
| **Python 3** | `CPython 3.13.5` | **70.16 s** | 25.9× |

---

## Baseline Reference: Laptop vs. Cloud Web-Server VM

| Language / Runtime | Modern Laptop *(Apple M2–M4, recent Intel/AMD)* | Cloud Web-Server VM *(AWS t3/m6i/c7g, GCP e2/n2)* |
| :--- | :---: | :---: |
| **C / C++ / Rust** (`-O2` / `--release`) | ~0.15 – 0.4 s | ~0.3 – 0.8 s |
| **Go / Java (JIT) / C#** | ~0.3 – 0.7 s | ~0.5 – 1.3 s |
| **Node.js (V8) / Bun** | ~0.6 – 1.2 s | ~1.0 – 2.2 s |
| **PHP 8 / Ruby** *(no JIT)* | ~4 – 10 s | ~7 – 18 s |
| **Python (CPython 3.11+)** | ~10 – 25 s | ~18 – 45 s |

- Cloud web-server VMs are typically **1.3× – 2.5× slower** than modern laptops on single-threaded CPU benchmarks due to lower boost clocks (~2.5–3.5 GHz vs. 4–5+ GHz / wide Apple Silicon cores), and burstable/shared vCPUs (`t3.micro`, `e2-micro`) can be **2× – 5×+ slower** under throttling or neighbor contention.
- `unkernel` ran roughly **4–6× slower** than a modern laptop and **2–4× slower** than an unthrottled cloud VM across all tested runtimes.

---

## Why `unkernel` Is Fast for a Browser, Yet Slower Than a Real VM

### Why it's fast for a browser
1. **Native Wasm Linux kernel:** Rather than emulating a full PC (BIOS, motherboard, hardware interrupts, kernel instructions) like v86 or QEMU-in-Wasm, `unkernel` compiles the Linux kernel directly into WebAssembly (`unkernel.wasm`).
2. **`kwemu` ARM64 → Wasm JIT:** User-space unmodified `aarch64` binaries run under `kwemu` (written in Zig), which JIT-compiles hot ARM64 basic blocks into Wasm modules on the fly. The browser's Wasm engine (e.g., V8 TurboFan) then compiles that Wasm down to host native machine code.
3. **JIT-friendly workload:** `fib(40)` is a tiny code footprint executed 331M times with zero syscalls, staying in hot JIT-compiled code for almost the entire run.

### Why it's slower than a hardware-virtualized VM
Real cloud VMs use hardware virtualization (KVM / VT-x / ARMv8 virtualization extensions) so guest instructions run directly on physical silicon at near-1:1 speed. `unkernel` still pays translation and sandboxing overhead:
- **Software MMU & stack traffic:** Guest virtual-to-physical address translation (software TLB checks) runs in Wasm linear memory on memory loads/stores—including stack pushes/pops across 331M recursive calls.
- **Emulated guest control flow & registers:** ARM64 registers, flags, and `bl`/`ret` jumps must map onto Wasm's structured control flow, adding dispatch overhead per recursive call/return.
- **Wasm sandbox & translation overhead:** Bounds checks and translating already-compiled ARM64 into Wasm produce less optimal host code than compiling source directly to the host CPU.

### Notable Benchmark Quirks
- **Triple-JIT in Node.js (`6.10 s`):** Node's V8 JITs JS → **ARM64** → `kwemu` JITs ARM64 → **Wasm** → browser JITs Wasm → **host native CPU**.
- **Go (`1.92 s`) beating GCC (`2.46 s`):** Under binary translation + software MMU, small differences in ARM64 codegen (stack frame layout, spills, branch structure) get amplified across 331M calls.
- **Fil-C (`5.85 s`, ~2.2× GCC):** Even with zero pointers or heap allocations, Fil-C pays per-call overhead for its concurrent GC safepoint pollchecks and memory-safe calling convention / frame bookkeeping, which is further amplified by `kwemu`'s software MMU.
  - Note: The prebuilt `filc-0.687-linux-aarch64.tar.xz` release ran unmodified inside `unkernel` without `patchelf` by symlinking `/usr/include/{linux,asm-generic,aarch64-linux-gnu/asm}` into `pizfix/os-include/` and passing `-Wl,-rpath` + `LD_LIBRARY_PATH`.
