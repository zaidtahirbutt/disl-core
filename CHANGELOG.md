# Changelog

All notable changes to `disl-core` are recorded here.

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
