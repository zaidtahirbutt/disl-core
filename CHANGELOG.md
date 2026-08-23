# Changelog

All notable changes to `disl-core` are recorded here.

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
