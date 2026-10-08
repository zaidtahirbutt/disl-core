# DISL (disl-core)

> **About this repo.** `disl-core` is the canonical, versioned continuation of Zaid Tahir's DISL fork — the hardware-OS generator engine used to build the [VeBPF many-core architecture](https://github.com/zaidtahirbutt/VeBPF) for FPGA-based SmartNICs and IoT. It supersedes dependence on the original upstream, [`rh-codes-lab/DISL`](https://github.com/rh-codes-lab/DISL) (dormant since April 2024), while extending it with a generalized `configure.py`/`build.py`, additional board support, and the network communication primitives + VeBPF many-core packet-processing architecture. See `CHANGELOG.md` for version history and `DISL_VERSION` for the current tag. The primary consumer of this repo is [`VebpfManyCore`](https://github.com/zaidtahirbutt/VebpfManyCore), which vendors it as a pinned git submodule.

The **full generic DISL reference** — system definitions, the component library,
the `system.tml` format, the system builder, PyJTAP — is in
**[`docs/DISL_REFERENCE.md`](docs/DISL_REFERENCE.md)**. That is the document to
read when adding a board or a component. This README covers what the fork adds,
how to run it, and what it ships.

## What DISL does

Given a TOML description of a system (`system.tml`) and a board (`board.tml`),
DISL generates the FPGA top-level Verilog, the constraints, the Vivado TCL, a
RISC-V linker script and reset handler, and a build directory ready to simulate
or synthesize. It is vendor-agnostic and application-agnostic: the engine never
learns what RISC-V firmware or eBPF rules *are*.

```
system.tml  ─┐
board.tml   ─┼─▶ configure.py ─▶ fpga/system_builder/build.py ─▶ <build_dir>/
modules.tml ─┘                                                    ├── top.v, parameters.vh, constraints
                                                                  ├── create_project.tcl, compile_project.tcl, run.sh
                                                                  ├── mem/        (staged memory images + manifest.json)
                                                                  └── tb_cocotb/  (simulation)
```

`build.py`'s order of operations matters:

1. `emit_address_map_header()` — compare or regenerate the C address map
2. `run_prebuild()` — run declared software builds
3. `generate_top()` → `generate_parameters()` → `resolve_mem_init()`
4. `generate_constraints()`, `generate_ip_tcl()`, `get_required_files()`

`MEM_INIT` resolves inside step 3, so `PREBUILD` necessarily precedes it — which
is what lets one invocation compile firmware and then consume the hex it just
produced.

## Repository layout

| Path | What |
|---|---|
| `configure.py` | Entry point: reads the TOMLs, calls the system builder, emits the Vivado TCL and `run.sh` |
| `fpga/system_builder/build.py` | The generator itself |
| `fpga/boards/` | Board support — `artya7100t`, `alinx_ax7a200t`, `artya735t`, `cmoda735t`, `nexysvideo`, `cvp13` |
| `fpga/common/hdl/` | The hardware IP library, including the network subsystem and the nested `VeBPF/` core |
| `examples/VebpfManyCore/` | The VeBPF many-core example systems (see [Examples](#examples)) |
| `examples/edgetestbed/` | The generic upstream DISL examples |
| `scripts/` | Host-side traffic generation and bring-up helpers |
| `docs/DISL_REFERENCE.md` | The full generic DISL documentation |
| `CHANGELOG.md`, `DISL_VERSION` | Version history and the current tag |

## Quick start

```console
# defaults: examples/VebpfManyCore/vebpf_manycore_1core_arty100t_SIM on artya7100t
python configure.py --build_dir /abs/path/to/build
cd /abs/path/to/build && source run.sh && make
```

Requirements for generation alone are small: **Python 3**, `toml`, and `tomli`
on Python < 3.11 (3.11+ has `tomllib` in the standard library). There is no
`requirements.txt` in this repo — the upstream reference mentions one, but this
fork's dependencies are supplied by the consuming project's environment
(`environment.yml` / `pyproject.toml` in `VebpfManyCore`), which also carries
cocotb, scapy and the eBPF rule assembler.

Beyond generation: **Vivado** for synthesis, **Icarus Verilog** for simulation,
and a `riscv32-unknown-elf-` toolchain if an example declares a `[PREBUILD]`
firmware step (or pass `--skip_prebuild`).

Most users reach this through the parent project's CLI (`./vebpf-mc sim` /
`./vebpf-mc build` in
[`VebpfManyCore`](https://github.com/zaidtahirbutt/VebpfManyCore)), which picks
the example, the build root and the Python environment for you. Drive
`configure.py` directly when you are working on the generator itself.

For the upstream `examples/edgetestbed/` flow, including the precompiled-binary
route, see
[the reference](docs/DISL_REFERENCE.md#the-edgetestbed-examples).

## Running it

`configure.py` is the entry point. **Run it with the current directory set to
this repo root** — its internal input paths are `./fpga/...` relative.

```console
python configure.py [--example_dir DIR] [--example NAME] [--board SHORTNAME] \
                    [--build_dir PATH] [--project_root PATH] \
                    [--prebuild_var STEP:NAME=VALUE] [--skip_prebuild] [-v] [-v_build]
```

Arguments:
- `--example_dir`: Specify the directory containing the target system configuration. A project is defined as a sub-directory (within this directory) that contains a `system.tml` configuration file. 
- `--example`: Specify the target project. 
- `--build_dir`: Specify the build directory
- `--board`: Target FPGA board - use the short name (e.g. cmoda735t)
- `-v`: Print debug information
- `-v_build`: Print system-builder debug information

Added by this fork:
- `--project_root`: Root that `${PROJECT_ROOT}` in a `system.tml` path resolves to — the consuming project's checkout. Defaults to this repo root.
- `--prebuild_var STEP:NAME=VALUE`: Append one extra `NAME=VALUE` argument to a single named `[PREBUILD]` step, after its own `VARS` (so for `make` it overrides them). Repeatable. Scoped per step on purpose: a value meant for the firmware build must not leak into the eBPF-rules build.
- `--skip_prebuild`: Skip every `[PREBUILD]` step — useful when the cross-toolchain is not installed and you only want the hardware generated.

`--example_dir`, `--example` and `--board` all default to the VeBPF many-core
1-core Arty A7-100T simulation example; `--build_dir` defaults to
`./build/build_<YYYY_MM_DD>_<example>`, relative to this repo root.

**Synthesis parallelism.** The generated `compile_project.tcl` passes
`launch_runs -jobs N`, where `N` is `min(8, os.cpu_count())`. Set `VIVADO_JOBS`
to override it. This used to be hardcoded at 24, which OOM-killed synthesis on
any machine with fewer cores than that.


The `configure.py` script also generates tool specific tcl and bash scripts, and places these in the build directory. Currently we only support Vivado, but more tools can be easily added by extending `configure.py`. There is currently no fixed template or requirement for what tool specific support should look like - virtually any capability can be added to automate the hardware compilation process. In the case of Vivado, the scripts currently generated are: 
- `create_project.tcl`: This TCL script is responsible for creating a project for the target board, adding the necessary files to it (e.g. HDL source code, HDL headers, constraints), setting the top module, and then executing any IP block specific tcl commands generated by the system builder. 
- `compile_project.tcl`: This TCL script is responsible for running synthesis, place and route, and bitstream generation. 
- `run.sh`: This bash script creates the tool specific methods for executing the above two tcl scripts. 



## Fork extensions: building software alongside hardware

Three `system.tml` blocks exist only in this fork. All three are **absent by
default**, so every upstream example behaves exactly as before. Full rationale
and per-release validation are in `CHANGELOG.md`; `CLAUDE.md` has the
implementation notes.

### `[MEM_INIT]` — memory images as a first-class input

```toml
[INSTANTIATIONS.<inst>.MEM_INIT.<VERILOG_PARAM>]
    FILE         = "${PROJECT_ROOT}/path/to/image.hex"
    PAD_TO_DEPTH = true
    DEPTH_WORDS  = 16384
    WORD_BITS    = 32
```

The table key is the **Verilog parameter name** that receives the resolved path.
`build.py` expands the anchor, **fails loudly** if the file is missing, stages a
copy into `<build_dir>/mem/`, zero-pads it to depth, injects the **absolute**
staged path as a parameter, and writes `<build_dir>/mem/manifest.json` for
provenance.

Supported anchors: `${PROJECT_ROOT}`, `${DISL_ROOT}`, `${EXAMPLE_DIR}`, and
`${PREBUILD:<step>:<NAME>}` — the last resolving to whatever a `[PREBUILD]` step
will actually be invoked with (its `DIR`, or any of its `VARS`, after
`--prebuild_var` overrides), so a memory image path can be *derived* from the
step that produces it rather than repeated:

```toml
FILE = "${PREBUILD:riscv_firmware:DIR}/build/${PREBUILD:riscv_firmware:APP}/${PREBUILD:riscv_firmware:TARGET}/firmware.sim.hex"
```

Paths are injected **absolute** because simulation runs from
`<build_dir>/tb_cocotb/` while Vivado synthesis runs from
`<build_dir>/<example>/<example>.runs/synth_1/` — no single relative path is
correct for both.

### `[PREBUILD.<name>]` — compile software before generating hardware

```toml
[PREBUILD.riscv_firmware]
    DIR      = "${PROJECT_ROOT}/RISCV_C_FW_VebpfManyCore/fw/vebpf_network_packet_processing"
    COMMAND  = "make"
    VARS     = { APP = "rx_firewall_vebpf/firewall", TARGET = "sim" }
    OPTIONAL = false
```

`VARS` become `NAME=VALUE` arguments (how `make` takes variables).
`OPTIONAL = true` downgrades a missing tool or a failed step to a warning.
Commands run as an **argv list, never through a shell** — a config file must not
be able to inject shell syntax.

Prebuild runs *before* `MEM_INIT` resolution, which is what lets one invocation
compile the firmware and then consume the hex it just produced.

### `[ADDRESS_MAP_HEADER]` — one address map, not two

`MODE` is `off` (default), `check` (verify the C header against
`[INSTANTIATIONS.<INSTANCE>.MAP]`; conflicting addresses fail, one-sided entries
warn unless `STRICT`), or `generate` (overwrite the header from the hardware
map). `NAMES` maps a hardware MAP key to its C macro name and is load-bearing —
the key `debug` would otherwise emit `#define DEBUG` and collide with the
firmware's build flag.



## The parameter pipeline

```
system.tml [INSTANTIATIONS.<inst>.PARAMETERS] <name> = <value>
   └─ gated by modules.tml [<module>] PARAMETERS = [...]   ← WHITELIST
        └─ generate_parameters() → parameters.vh
             parameter PARAMETER_<INST>_<PARAM> = <literal>;
               └─ instantiation: .PARAM(PARAMETER_<INST>_<PARAM>)
```

**A parameter that is not on `modules.tml`'s whitelist for that module is
silently dropped.** If a `system.tml` parameter appears to have no effect, check
the whitelist first. `MEM_INIT` bypasses it by injecting directly.

## Examples

### VeBPF many-core (`examples/VebpfManyCore/`)

The examples this fork is actively developed against. Ten projects across two
boards, along three orthogonal axes — **core count**, **board**, and **how the
memories are initialised**:

| Example | Board | VeBPF cores | Purpose |
|---|---|---|---|
| `vebpf_manycore_1core_arty100t_SIM` | Arty A7-100T | 1 | **Default.** cocotb + Icarus simulation |
| `vebpf_manycore_1core_arty100t` | Arty A7-100T | 1 | Synthesis / bitstream |
| `vebpf_manycore_1core_arty100t_PRELOAD_MEMFILES` | Arty A7-100T | 1 | Synthesis with the firmware BRAM preloaded from a hex image (no UART upload needed) |
| `vebpf_manycore_2core_arty100t{,_SIM,_PRELOAD_MEMFILES}` | Arty A7-100T | 2 | The same three, with a 2-core array |
| `vebpf_manycore_1core_alinx200t` | Alinx AX7A200T | 1 | Synthesis / bitstream |
| `vebpf_manycore_2core_alinx200t{,_SIM,_PRELOAD_MEMFILES}` | Alinx AX7A200T | 2 | Synthesis, simulation, and preloaded synthesis |

Core count is set by `PARAMETERS.NUMBER_OF_VEBPF` in the example's `system.tml`,
so adding an N-core variant is a one-line change plus a copy.

The Alinx examples use RGMII rather than MII, and their `_SIM` variant carries
`src/xilinx_sim_primitives.v` — behavioural models of `IBUFGDS`, `BUFG` and
`MMCME2_BASE`, which Icarus has no cell library for. The MMCM model measures its
input period at runtime and derives each output from `CLKFBOUT_MULT_F`,
`DIVCLK_DIVIDE` and `CLKOUT<n>_DIVIDE`, so retuning the clock plan needs no
change to the model.

All ten declare `[PREBUILD]` + `[MEM_INIT]`, so one invocation compiles the
RISC-V firmware and the eBPF rules and feeds them into the design.

### Host-side scripts (`scripts/`)

Traffic generation and bring-up helpers for a board on the bench:

| Script | Purpose |
|---|---|
| `vebpf_firewall_experiment.py` | The throughput/filtering experiment driver — selectable rule set, packet size, packet count and iterations |
| `vebpf_arp_setup.sh`, `vebpf_src_ip_arp_setup.sh` | Static ARP entries so the host will talk to the board's synthetic sources |
| `setup_iptables_for_vebpf_exp.sh` | Stops the host kernel from answering traffic meant for the FPGA |
| `udp_test.py`, `udp_test_demo.py` | Minimal UDP send/receive smoke tests |
| `dev-netns-shell.sh` | Runs the above inside a network namespace, off the real NIC |

```console
python3 scripts/vebpf_firewall_experiment.py --list
python3 scripts/vebpf_firewall_experiment.py --engine vebpf --ruleset ip --size 64 --dry-run
```

`--dry-run` prints the exact packet plan and sends nothing, so the script can be
checked without a board. Larger packet sizes use longer inter-packet delays —
that is deliberate, not tuning left over from a run: the Arty's receive path
drops packets below those gaps.


## Things to look out for

1. **Run `configure.py` from this repo root.** Its input paths are `./fpga/...`
   relative; running it from anywhere else fails in confusing ways.

2. **Several `.v` files have CRLF line endings.** Never rewrite them with
   Python text mode — use `newline=''` on read *and* write, or a 20-line edit
   becomes a 1600-line diff.

3. **What makes a `$readmemh` synthesizable.** A parameter-conditional
   `$readmemh` is constant-folded on the parameter's *value*: it survives
   synthesis when the condition is true and vanishes when it is false. It is not
   "simulation-only" as a category — `PRELOAD_MEM`'s load is genuinely honoured
   by Vivado. Two things *do* disqualify one: a `#delay` anywhere in the same
   `initial` block, and sitting inside a disabled generate-if, where the whole
   block including its arrays is eliminated at elaboration.

4. **`ERROR: [Vivado 12-3447] No sub-design file provided`** appears in every
   synthesis run, including ones that reproduce the benchmark exactly. It is a
   pre-existing `ip.tcl` quirk — `[lindex $argv 0]` with no arguments passed —
   and is harmless.

5. **This repo is consumed as a git submodule** and will normally sit on a
   detached HEAD in a consuming checkout. Check before pushing: `git push origin
   main` can report "Everything up-to-date" while pushing a stale local branch.

## Versions

| Tag | Change |
|---|---|
| `v0.1.0` | Designated this fork canonical |
| `v0.1.1` | Removed the `RISCV_C_FW_VebpfManyCore` submodule |
| `v0.1.2` | `VeBPF` swapped to the public repo @ `v1.0.0` |
| `v0.1.3` | `os.mkdir` → `os.makedirs(exist_ok=True)` for `build_dir` |
| `v0.2.0` | `[MEM_INIT]`, `PRELOAD_MEM` |
| `v0.3.0` | `[PREBUILD]`, `[ADDRESS_MAP_HEADER]`, `subprocess` argv list |

`CHANGELOG.md` carries the full rationale and per-release validation results;
`DISL_VERSION` holds the current tag.

## Related

- [VebpfManyCore](https://github.com/zaidtahirbutt/VebpfManyCore) — the many-core system this engine builds
- [VeBPF](https://github.com/zaidtahirbutt/VeBPF) — the eBPF-ISA-compliant CPU core
- [rh-codes-lab/DISL](https://github.com/rh-codes-lab/DISL) — the original upstream

## License

See [`LICENSE`](LICENSE).
