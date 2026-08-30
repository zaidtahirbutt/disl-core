# Changelog

All notable changes to `disl-core` are recorded here.

## v0.2.0 - 2026-08-30

**Memory images are now declared in `system.tml`, not hardcoded in the RTL.**

Two `$readmemh` calls named their memory images with hardcoded relative
paths (`"../../../RISCV_C_FW_VebpfManyCore/fw/.../x.hex"` in
`bram_axi_cachecontroller_v2.v`, `"../../../fpga/.../sim_combined_hex.hex"`
in `progloader_riscv_vebpf_v2.v`). Those paths encoded the directory depth
of one particular repository layout, so once this tree was vendored into a
consuming project they resolved -- by depth coincidence -- into a *different*
checkout that happened to hold identical files. A standalone clone would
have found nothing at all. A third call held an absolute path into a
developer's home directory.

New mechanism:

    [INSTANTIATIONS.<instance>.MEM_INIT.<VERILOG_PARAM>]
        FILE         = "${PROJECT_ROOT}/path/to/image.hex"
        PAD_TO_DEPTH = true
        DEPTH_WORDS  = 16384
        WORD_BITS    = 32

`build.py` resolves `${PROJECT_ROOT}` / `${DISL_ROOT}` / `${EXAMPLE_DIR}`,
copies the image into `<build_dir>/mem/`, optionally zero-pads it to the
depth the RTL declares, and injects the absolute staged path as the named
Verilog parameter. A `mem/manifest.json` records what each image resolved
from. Missing files now fail the build loudly instead of producing a
mid-simulation warning that was easy to miss.

Absolute paths are used deliberately: simulation runs from
`<build_dir>/tb_cocotb/` while Vivado synthesis runs from
`<build_dir>/<example>/<example>.runs/synth_1/`, so no single relative path
is correct for both.

Also new: `bram_axi_cachecontroller_v2` gained `PRELOAD_MEM`, which loads
the image in a delay-free `initial` block so Vivado can infer an
initialized BRAM and ship firmware inside the bitstream. This is a separate
block from the simulation path, which deliberately delays past the BRAM
zeroing loop -- a delay makes the block non-synthesizable.

Engine changes are generic: `build.py` knows only "a path to a file", never
what RISC-V firmware or eBPF rules are. Knowing how to *produce* those
belongs to the consuming project's tooling.

- `configure.py`: new `--project_root`; now aborts if `build.py` fails
  instead of continuing on to generate TCL scripts.
- `generate_parameters` renders string and boolean parameters correctly
  (previously bare `str()`, which was fine only because every parameter
  was numeric).

Validated against this exact commit:
- With no `MEM_INIT` declared anywhere, generated output is byte-identical
  to v0.1.3 across all 55 files (`top.v`, `parameters.vh`, all copied RTL);
  only `configure_options.tml` differs, by the intended new provenance field.
- Full cocotb simulation `PASS`, `sim_time_ns=3131136.001` -- identical to
  every prior run since the first recorded baseline.
- Both memory images now resolve inside the consuming checkout, load at
  exactly the declared depth, and the eBPF rule words were confirmed
  against the waveform to land at the correct array addresses. The
  long-standing "Not enough words in the file for the requested range"
  warnings are gone.


All notable changes to `disl-core` are recorded here.

## v0.1.3 - 2026-08-25

`configure.py`: `os.mkdir(build_dir)` -> `os.makedirs(build_dir, exist_ok=True)`.
Eliminates the long-documented `issues_and_stuff/issues.txt` gotcha ("Need
to make a build folder manually, otherwise it gives out an unrelated
error") entirely -- `build_dir` can now be any absolute, deeply-nested, or
externally-located path with zero pre-setup. This is what makes it safe
for `VebpfManyCore`'s `vebpf-mc` CLI to build into an external, uniquely-
named directory outside any git working tree. Verified with a
multi-level-nonexistent external path before and after the fix.

## v0.1.2 - 2026-08-23

Swapped the `VeBPF` submodule from the private `DISL_FPGA_eBPF.git` to the
public `https://github.com/zaidtahirbutt/VeBPF.git`, pinned to tag `v1.0.0`
(commit `ea246e5`, "Initial public release of VeBPF CPU Core"). This is the
deferred public-URL swap from the original repo's §11 Phase 1 plan.

Validated before tagging, against this exact commit: full cocotb simulation
(`PASS`, `sim_time_ns=3131136.001`, identical to every prior run) and a
complete Vivado 2021.1 synthesis/implementation/bitstream run on the
`artya7100t` target -- bitstream size, LUT/Register/BRAM/DSP utilization,
timing (WNS/TNS/failing endpoints), and DRC results are all bit-for-bit
identical to the pre-swap baseline. The public repo's file content is
functionally equivalent to the private one for this build.

## v0.1.1 - 2026-08-23

Removed the `RISCV_C_FW_VebpfManyCore` submodule. Verified via exhaustive grep
that nothing in `configure.py`, `fpga/system_builder/build.py`, or any
`system.tml`/`modules.tml` ever reads from it — it's a standalone RISC-V
firmware build tool a developer invokes manually (`make` inside it, then
`load.py` to upload the resulting hex), not something the system generator
touches. Kept only where it's actually useful: as a top-level submodule of
`VebpfManyCore` for discoverability. `VeBPF` stays in `disl-core` — confirmed
load-bearing (`eth_nic_100m_mmi`'s `COMMON_FOLDER = ["network_subsystem"]`
resolves its Verilog sources, including `VeBPF/cpu.v`, relative to this
tree) — removing it would break `build.py`.

## v0.1.0 - 2026-08-23

Initial designation of this fork as `disl-core` — the canonical, versioned home
of this DISL (hardware-OS generator) lineage going forward, superseding
dependence on the dormant upstream `rh-codes-lab/DISL` (last pushed 2024-04-05).

This version is a direct continuation of prior development, not a rewrite:

- Generalized `configure.py` CLI beyond upstream DISL (`--device`, `--tool`,
  `--src`, `-v_build`), plus `tomllib`/`tomli` fallback handling,
  auto-timestamped build directories, and a `configure_options.tml` provenance
  manifest.
- Extended `fpga/system_builder/build.py` (~250 lines beyond upstream) with
  the network-subsystem component library and its many-core packet-processing
  support.
- Board support beyond upstream: `artya7100t`, `alinx_ax7a200t`, `cvp13`,
  `nexysvideo` (upstream only ships `artya735t`/`cmoda735t`).
- The network communication primitives and VeBPF many-core architecture
  (packet slicer/DMA, many-core data/program loaders, scheduler/arbiter,
  result analyzer) — implemented as part of the generic HDL component
  library and its module registry (`fpga/common/config/modules.tml`),
  notably `progloader_riscv_vebpf_v2`.

**Known scope note**: this version's "generic" module registry still contains
VeBPF-specific entries (see above). This is intentional for now — the fork's
first and only real consumer is the `VeBPF_many_core`/`VebpfManyCore` project,
which needs exact structural fidelity to what was actually built and tested,
not a premature generalization. Splitting VeBPF-specific content out of the
shared registry is deferred until a second, genuinely unrelated project
actually needs a clean-of-VeBPF `disl-core` — not scheduled ahead of that.

Validated against this exact commit before tagging: full cocotb simulation
(`PASS`, `TESTS=1 PASS=1 FAIL=0 SKIP=0`) and a complete Vivado 2021.1
synthesis/implementation/bitstream run on the `artya7100t` target (bitstream
generated successfully; a pre-existing timing violation, confirmed identical
to a September 2025 build, is a known characteristic of this design, not a
regression).
