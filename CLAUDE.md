# CLAUDE.md — disl-core

Guidance for Claude Code sessions working in this repo.

## What this repo is

**DISL**: a vendor-agnostic **hardware-OS generator** for FPGAs. Given a TOML
description of a system (`system.tml`) and a board (`board.tml`), it generates
the FPGA top-level Verilog, constraints, Vivado TCL, a RISC-V linker script and
reset handler, and a build directory ready to simulate or synthesize.

This fork is the **canonical, versioned lineage** of DISL, superseding the
dormant upstream `rh-codes-lab/DISL` (last pushed 2024-04-05, no VeBPF content,
no overlapping board support). It is meant to be reused as the engine for future
FPGA projects, which is why it is a separate repo rather than folded into its
current only consumer, `VebpfManyCore`.

**Keep it generic.** The engine should never learn what RISC-V firmware or eBPF
rules *are*. Project-specific knowledge belongs in the consuming project's
`system.tml` or CLI. Every mechanism below was designed with that constraint.

> Known scope note: the "generic" module registry still contains VeBPF-specific
> entries (e.g. `progloader_riscv_vebpf_v2`). Intentional — the registry is inert
> metadata, and splitting it is deferred until a second, genuinely unrelated
> project needs a VeBPF-free engine.

## Entry point

```console
python configure.py --example_dir ./examples/edgetestbed --example <name> \
                    --board artya7100t --build_dir <abs path> \
                    [--project_root <consuming repo>] [--skip_prebuild]
```

`configure.py` must run with **CWD = this repo root** — input paths are
`./fpga/...` relative. It reads the TOMLs, invokes
`fpga/system_builder/build.py`, then generates `create_project.tcl`,
`compile_project.tcl`, `run.sh`.

`build.py` order of operations (this order matters):

1. `emit_address_map_header()` — compare or regenerate the C address map
2. `run_prebuild()` — run declared software builds
3. `generate_top()` → `generate_parameters()` → `resolve_mem_init()`
4. `generate_constraints()`, `generate_ip_tcl()`, `get_required_files()` (copies)

`MEM_INIT` resolves *inside* step 3, so `PREBUILD` must precede it — a system
can compile firmware then consume it in the same invocation.

## The three `system.tml` mechanisms added to this fork

All three are **absent by default**, so existing examples are unaffected.

### `[MEM_INIT]` (v0.2.0) — memory images

```toml
[INSTANTIATIONS.<inst>.MEM_INIT.<VERILOG_PARAM>]
    FILE         = "${PROJECT_ROOT}/path/to/image.hex"
    PAD_TO_DEPTH = true
    DEPTH_WORDS  = 16384
    WORD_BITS    = 32
```

The table key is the **Verilog parameter name** that receives the resolved path.
`build.py` expands the anchor, **fails loudly** if the file is missing, stages a
copy into `<build_dir>/mem/`, zero-pads to depth, injects the **absolute** staged
path as a parameter, and writes `<build_dir>/mem/manifest.json` for provenance.

Anchors: `${PROJECT_ROOT}` (caller-supplied via `--project_root`, defaults to
this repo root), `${DISL_ROOT}`, `${EXAMPLE_DIR}`.

**Why absolute paths**: simulation runs from `<build_dir>/tb_cocotb/` while
Vivado synthesis runs from `<build_dir>/<example>/<example>.runs/synth_1/`. **No
single relative path is correct for both.** This is also why `$value$plusargs`
was rejected — it is simulation-only and does nothing for synthesis.

### `[PREBUILD.<name>]` (v0.3.0) — build software before generating hardware

```toml
[PREBUILD.riscv_firmware]
    DIR = "…"  COMMAND = "make"  ARGS = ["APP=x"]
    VARS = { SIMULATION_TESTING = 1, DEBUG = 0 }
    OPTIONAL = false
```

`VARS` become `NAME=VALUE` arguments (how `make` takes variables). `OPTIONAL =
true` downgrades a missing tool or failed step to a warning. Commands run as an
**argv list, never through a shell** — a config file must not be able to inject
shell syntax.

### `[ADDRESS_MAP_HEADER]` (v0.3.0) — one address map, not two

`MODE` = `off` (default) | `check` (verify the C header against
`[INSTANTIATIONS.<INSTANCE>.MAP]`; conflicting addresses fail, one-sided entries
warn unless `STRICT`) | `generate` (overwrite the header from the hardware map).

`NAMES` maps a hardware MAP key to its C macro name and is **load-bearing**: the
key `debug` would otherwise emit `#define DEBUG 0x…` and collide with the
firmware's `DEBUG` build flag.

## The parameter pipeline

```
system.tml [INSTANTIATIONS.<inst>.PARAMETERS] <name> = <value>
   └─ gated by modules.tml [<module>] PARAMETERS = [...]   ← WHITELIST (build.py:74)
        └─ generate_parameters() → parameters.vh
             parameter PARAMETER_<INST>_<PARAM> = <literal>;
               └─ instantiation: .PARAM(PARAMETER_<INST>_<PARAM>)
```

**A parameter that is not in `modules.tml`'s whitelist for that module is
silently dropped.** If a `system.tml` parameter seems to have no effect, check
the whitelist first. (`MEM_INIT` bypasses it by injecting directly.)

`verilog_literal()` renders ints bare, strings quoted, bools as `1`/`0`. Before
v0.2.0 it used a bare `str()` — which worked only because every parameter
happened to be numeric.

## Things to look out for

1. **`build.py` reads exactly five positionals** (`system`, `board`, `build_dir`,
   `src`, `build_verbose`) and has **never** read `tool`. Everything after
   argv[5] is a **named flag** (`--project-root=`, `--skip-prebuild`). Do not add
   positionals: `tool` and `project_root` can both be empty, and the old
   `os.system` string form silently shifted every later argument when one was.
   `configure.py` now uses `subprocess.run` with an argv list — keep it that way.

2. **Several `.v` files have CRLF line endings.** Never write them with Python
   text mode; use `newline=''` on read and write, and verify with
   `git diff --stat`.

3. **`$readmemh` inside `if (PARAMETER)` is constant-folded away at synthesis**,
   so it is simulation-only in practice — unlike `` `ifdef ``, it *looks*
   conditional but disappears. A `#delay` anywhere in that `initial` block makes
   it non-synthesizable, which is why `PRELOAD_MEM` uses a **separate,
   delay-free** block from the simulation load path in
   `bram_axi_cachecontroller_v2.v`.

4. **This repo is a submodule and sits on DETACHED HEAD.** See the parent's
   `CLAUDE.md` before pushing — `git push origin main` can report
   "Everything up-to-date" while pushing a stale branch.

5. **Regression gate for any generator change**: with no `MEM_INIT`/`PREBUILD`/
   `ADDRESS_MAP_HEADER` declared, generated output must be **byte-identical**
   across all ~55 files (only `configure_options.tml` legitimately differs, and
   `parameters.vh` differs between build dirs because it embeds staged absolute
   paths). Then: simulation `sim_time_ns = 3131136.001`, and synthesis matching
   the benchmark exactly (see the parent `CLAUDE.md` for the numbers).

6. **`fpga/common/hdl/network_subsystem/tb/` is 37 MB of committed simulation
   output** (a 23 MB `.vcd`, historical `.fst`s, a `sim.vvp` binary) that nothing
   references. Slated for deletion; do not add to it.

7. **`ERROR: [Vivado 12-3447] No sub-design file provided`** appears in every
   synthesis run because `ip.tcl` uses `[lindex $argv 0]` and `run.sh` passes no
   arguments. Pre-existing, harmless, on the backlog.

## Versions

| Tag | Change |
|---|---|
| `v0.1.0` | Designated this fork canonical |
| `v0.1.1` | Removed `RISCV_C_FW_VebpfManyCore` submodule (believed unused — later shown to be reachable via a hardcoded RTL `$readmemh`) |
| `v0.1.2` | `VeBPF` swapped to the public repo @ `v1.0.0` |
| `v0.1.3` | `os.mkdir` → `os.makedirs(exist_ok=True)` for `build_dir` |
| `v0.2.0` | `[MEM_INIT]`, `PRELOAD_MEM` |
| `v0.3.0` | `[PREBUILD]`, `[ADDRESS_MAP_HEADER]`, `subprocess` argv list |

`CHANGELOG.md` has the full rationale and per-release validation results.
