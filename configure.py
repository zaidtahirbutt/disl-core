#Example: python configure.py -example edgetestbed -build_dir ./build -board artya735t -v
# Tested with Vivado 2020.1
# Known issue with MIG IP generation in 2021.2

import os
import sys
import subprocess
import toml
import json
import argparse
from pathlib import Path
if sys.version_info >= (3, 11):
    import tomllib  # Python 3.11+
else:
    import tomli as tomllib  # Use tomli for older versions

from datetime import datetime 

########################### Defaults ###########################
DEFAULT_EXAMPLE = "vebpf_manycore_1core_arty100t_SIM"
DEFAULT_EXAMPLE_DIR = "./examples/VebpfManyCore"
DEFAULT_BOARD = "artya7100t"
DEFAULT_DEVICE = "fpga"
DEFAULT_TOOL = ""
DEFAULT_SRC = "cpu_test.c"
# Build dir will be auto-generated later

# # Solving the issue of manually having to create build dir to avoid random errors 
# # Specify the directory path
# buid_dir_exits = Path("./build")
# # Check if the build dir exists
# if not buid_dir_exits.exists():
#     # Create the build dir
#     buid_dir_exits.mkdir(parents=True, exist_ok=True)
#     print(f"Directory '{buid_dir_exits}' created.")
# else:
#     print(f"Directory '{buid_dir_exits}' already exists.")


# ########################### Get arguments ###########################
# parser = argparse.ArgumentParser( prog = 'configure', description='Parse arguments and build project')
# parser.add_argument('--example_dir', action='store', help='Specify the target project directory') 
# parser.add_argument('--example', action='store', help='Specify the target project') 
# parser.add_argument('--build_dir', action='store',help='Specify the build directory') 
# parser.add_argument('--board', action='store',help='Target board - use the short name (e.g. artya35t)') 
# parser.add_argument('--device', action='store',help='Target device (fpga)') # use glob to get parent directory of board
# parser.add_argument('--tool', action='store',help='Target tool') 
# parser.add_argument('--src', action='store',help='main file (optional for fpga)') 
# parser.add_argument('-v', action='store_true', help='Print debug information')
# parser.add_argument('-v_build', action='store_true', help='Print build debug information')
# args = parser.parse_args()

########################### Get arguments ###########################
parser = argparse.ArgumentParser(
    prog="configure", description="Parse arguments and build project"
)
parser.add_argument("--example_dir", default=DEFAULT_EXAMPLE_DIR, help="Target project directory")
parser.add_argument("--example", default=DEFAULT_EXAMPLE, help="Target project")
parser.add_argument("--build_dir", help="Build directory (default: auto-generate)")
parser.add_argument("--board", default=DEFAULT_BOARD, help="Target board (short name)")
parser.add_argument("--device", default=DEFAULT_DEVICE, help="Target FPGA device")
parser.add_argument("--tool", default=DEFAULT_TOOL, help="Target tool")
parser.add_argument("--src", default=DEFAULT_SRC, help="Main source file")
parser.add_argument("--prebuild_var", action="append", default=[],
                    metavar="STEP:NAME=VALUE",
                    help="Extra NAME=VALUE argument for one [PREBUILD] step, e.g. "
                         "riscv_firmware:DEBUG=1. Repeatable; overrides that step's "
                         "VARS for the same name.")
parser.add_argument("--rtl-seed", type=int, default=None, metavar="N",
                    dest="rtl_seed",
                    help="RTL build seed. Overrides [DESCRIPTION] BUILD_SEED in "
                         "system.tml. Bakes a DONT_TOUCH register chain whose LENGTH "
                         "is derived from N into the design BEFORE synthesis, so the "
                         "placer is given a different netlist and produces a different "
                         "layout. 0 (the default) adds nothing at all, so a seed-0 "
                         "build is byte-identical to one built without this feature.")
parser.add_argument("--seed", type=int, default=0, metavar="N",
                    help="Implementation seed: an integer that selects a different "
                         "placement/routing ALGORITHM. 0 is the Vivado default. "
                         "Vivado has no RNG seed, so each value picks a distinct "
                         "set of directives instead -- see SEED_TABLE in this file. "
                         "Same seed always gives the same result.")
parser.add_argument("--skip_prebuild", action="store_true",
                    help="Skip every [PREBUILD] step in system.tml (e.g. no cross-toolchain installed)")
parser.add_argument("--project_root", default="",
                    help="Root that ${PROJECT_ROOT} in a system.tml MEM_INIT path resolves to "
                         "(e.g. the consuming project's checkout). Defaults to this disl-core root.")
parser.add_argument("-v", action="store_true", help="Print debug information")
parser.add_argument("-v_build", action="store_true", help="Print build debug information")

args = parser.parse_args()

# Seed range check up front: the table itself is defined much later in the flow,
# and failing there means the prebuild steps have already run for nothing.
# SEED_COUNT must match len(SEED_TABLE) below; asserted when the table is built.
SEED_COUNT = 18
if args.seed < 0 or args.seed >= SEED_COUNT:
    print(f"Error! --seed {args.seed} is out of range. Valid seeds are 0..{SEED_COUNT - 1}.")
    print("       Seed 0 is the Vivado default; each other seed selects a different")
    print("       placement/routing algorithm. See SEED_TABLE in configure.py.")
    sys.exit(1)

########################### Auto-generate build dir ###########################
if args.build_dir:
    build_dir = args.build_dir
else:
    timestamp = datetime.now().strftime("%Y_%m_%d")
    build_dir = f"./build/build_{timestamp}_{args.example}"

########################### Initializations ###########################
example = args.example
example_dir = args.example_dir
board = args.board
device = args.device
tool = args.tool
src = args.src
project_root = args.project_root
verbose = 1 if args.v else 0
build_verbose = 1 if args.v_build else 0

########################### Initializations ###########################
# build_dir= str(args.build_dir) if args.build_dir else ("./build")  
# example= str(args.example) if args.example else "edgetestbed"
# # example_dir = str(args.example_dir) if args.example_dir else "./edgetestbed"
# example_dir = str(args.example_dir) if args.example_dir else "./examples/edgetestbed"
# board= str(args.board) if args.board else "artya735t"
# device = str(args.device) if args.device else "fpga"
# tool = str(args.tool) if args.tool else ""
# src = str(args.src) if args.src else "cpu_test.c"
# verbose= 1 if args.v else 0
# build_verbose= 1 if args.v_build else 0
# # sys.exit(f"build_verbose = {build_verbose}\n args.v_build = {args.v_build}\n  ")
########################## Define Logger and error handler ##########################
def logger(msg):
    global verbose
    if verbose:
        print(msg)
def error(msg):
    print("Error! " + msg)
    print ("Exiting")
    exit()
####################### Log build arguments ###########################
if not example:
    error("No example specified")
logger("System: " + example_dir + "/" + example)
logger ("Build Dir: " + build_dir)
logger ("Board: " + board)
logger ("Verbose: " + str(verbose))
####################### Open example###########################
try:
    with open(f"./{example_dir}/{example}/system.tml", "rb") as f2:
        debug = tomllib.load(f2)
except tomllib.TOMLDecodeError as e:
    print(f"Error decoding system.tml TOML file by tomllib: {e}")

try:
    print(f"Example path is {example_dir}/{example}")
    with open(f"./{example_dir}/{example}/system.tml") as f:
        print(f"Opening tml file at {example_dir}/{example}/system.tml")
        system = toml.load(f)
# except:
#     error("Example not found")
except toml.TomlDecodeError as e:
    print(f"Error decoding TOML file: {e}")
except FileNotFoundError:
    print("Error: File not found.")
except Exception as e:
    print(f"An error occurred: {e}")
####################### Check if board is supported ###################
if board not in system["REQUIREMENTS"]["BOARDS"]:
    error(f"Error: The {board} board is not supported by {example}\n" +  "Valid boards are: " + str(system["REQUIREMENTS"]["BOARDS"]))
else:
    logger("Board supported - continuing")
####################### Open board###########################
try:
    with open(f"./{device}/{tool}/boards/{board}/config/board.tml", "rb") as f2:
        debug2 = tomllib.load(f2)
except tomllib.TOMLDecodeError as e:
    print(f"Error decoding {board} ./{device}/{tool}/boards/{board}/config/board.tml TOML file by tomllib: {e}")

try:
    with open(f"./{device}/{tool}/boards/{board}/config/board.tml") as f:
        board = toml.load(f)
except toml.TomlDecodeError as e:
    print(f"Error decoding {board} TOML file: {e}")
except FileNotFoundError:
    print(f"Error: Board File {board} not found.")
except Exception as e:
    print(f"An error occurred while parsing TOML FILE: {e}")
# except:
#     error("Board not found")
######################## Create build directory #################
os.makedirs(build_dir, exist_ok=True)
######################## Generate system files #######################
logger("Generating system and copying files")


# print(f'printing stuff: \n deive = {device} \n tool = {tool} \n python ./{device}/{tool}/system_builder/build.py ./{example_dir}/{example}/system.tml \n board["DESCRIPTION"]["DIRECTORY"] = {board["DESCRIPTION"]["DIRECTORY"]} \n {build_dir}/ {src} {tool}')
# sys.exit("Exiting")
    # printing stuff: 
    # deive = fpga 
    # tool =  
    # python ./fpga//system_builder/build.py ././examples/edgetestbed/edgetestbed_jtag_uartprog_no_dram_random_module_test_arty100t/system.tml 
    # board["DESCRIPTION"]["DIRECTORY"] = artya7100t 
    # ./build/build_2024_9_9_edgetestbed_jtag_uartprog_no_dram_onlySwLedsFunction_arty100_v2/ cpu_test.c 
    # Exiting

# sys.exit("Manual Exit")
#
# build.py is invoked with an explicit argv list rather than an interpolated
# shell string. The previous `os.system(f"... {src} {tool} {build_verbose}")`
# form was quietly fragile: `tool` and `project_root` can both legitimately be
# empty, an empty value collapses when the shell splits on whitespace, and every
# argument after it shifts down a slot. That only ever worked because `tool` is
# empty in practice, which happened to line `build_verbose` up with the argv
# index build.py reads. Passing a list means no shell, no word splitting, no
# quoting rules, and paths containing spaces work.
#
# build.py reads exactly five positionals (system, board, build_dir, src,
# build_verbose) and has never read `tool` at all -- it is only used here to
# locate build.py itself -- so it is deliberately not passed.
build_py = os.path.join(".", device, tool, "system_builder", "build.py")
build_cmd = [
    sys.executable,                                    # same interpreter, not whatever `python` resolves to
    build_py,
    f"./{example_dir}/{example}/system.tml",
    board["DESCRIPTION"]["DIRECTORY"],
    f"{build_dir}/",
    src,
    str(build_verbose),
]
if project_root:
    build_cmd.append(f"--project-root={project_root}")
if args.skip_prebuild:
    build_cmd.append("--skip-prebuild")
for _pv in args.prebuild_var:
    build_cmd.append(f"--prebuild-var={_pv}")

logger("Running: " + " ".join(build_cmd))
build_rc = subprocess.run(build_cmd).returncode
if build_rc != 0:
    error(f"build.py failed with exit code {build_rc} - see the traceback above. "
           "Not generating TCL scripts.")

###################### RTL build seed ######################
# Two different, complementary knobs exist in this flow:
#
#   --seed N      picks a different placement/routing ALGORITHM (directives).
#                 Nothing about the design changes; the tool is told to try a
#                 different strategy on the same netlist.
#
#   --rtl-seed N  changes the NETLIST ITSELF, before synthesis, by adding a
#                 DONT_TOUCH register chain whose LENGTH is derived from N.
#                 The placer is then solving a different problem, so the whole
#                 layout is reshuffled. This is the knob that behaves most like
#                 a classic fitter seed.
#
# Why the length and not just the value: a register's INIT is a cell property.
# Changing only INIT leaves the cell count and connectivity identical, and the
# placer would very likely produce the same layout. Varying the CHAIN LENGTH
# changes how many flip-flops exist, which genuinely changes the placement
# problem. DONT_TOUCH on both the module and the register keeps synthesis from
# optimising the whole thing away, which is the usual failure mode for a seed
# register that drives nothing.
#
# The seed is a TOML parameter so it travels with the example and can be pinned
# per design; --rtl-seed overrides it for a one-off build.
_rtl_seed = args.rtl_seed
if _rtl_seed is None:
    _rtl_seed = int(system.get("DESCRIPTION", {}).get("BUILD_SEED", 0))
if _rtl_seed < 0:
    print(f"Error! --rtl-seed {_rtl_seed} must be >= 0.")
    sys.exit(1)

if device == "fpga" and _rtl_seed != 0:
    _top = build_dir + "/top.v"
    with open(_top) as f:
        _topsrc = f.read()
    # Clock for the chain. Every example instantiates a cpu, so module_cpu_clk
    # always exists and is already a buffered internal clock.
    _clk = "module_cpu_clk"
    if _clk not in _topsrc:
        print(f"Error! --rtl-seed needs a clock net; '{_clk}' not found in top.v.")
        sys.exit(1)
    # 8..64 flip-flops: enough to move the placer, negligible on a 100T/200T.
    # Spread adjacent seeds apart. A plain (seed * k) % n maps 3 and 11 to 29
    # and 28 FFs -- almost the same netlist. Knuth multiplicative hashing gives
    # neighbouring seeds very different chain lengths AND tap positions, so the
    # connectivity changes, not merely the cell count.
    _h = (_rtl_seed * 2654435761) & 0xFFFFFFFF
    _chain = 8 + (_h >> 7) % 57
    _tap = 1 + (_h >> 19) % (_chain - 2)
    with open(build_dir + "/build_seed.v", "w") as f:
        f.write(f"""// GENERATED by configure.py -- do not edit.
// RTL build seed {_rtl_seed}: a DONT_TOUCH register chain of {_chain} flip-flops (tap {_tap}),
// inserted before synthesis so the placer sees a different netlist and produces
// a different layout. It is deliberately functionless -- nothing reads it and it
// drives no output. DONT_TOUCH is what stops synthesis from deleting it.
(* DONT_TOUCH = "true" *)
module build_seed #(
    parameter integer SEED  = {_rtl_seed},
    parameter integer CHAIN = {_chain},
    parameter integer TAP   = {_tap}
) (
    input wire clk
);
    (* DONT_TOUCH = "true" *) reg [CHAIN-1:0] seed_chain = (SEED | 1);
    always @(posedge clk) begin
        seed_chain <= {{seed_chain[CHAIN-2:0], seed_chain[CHAIN-1] ^ seed_chain[TAP]}};
    end
endmodule
""")
    _inst = (f"\n// RTL build seed {_rtl_seed} ({_chain} FFs) -- see build_seed.v\n"
             f"build_seed #(.SEED({_rtl_seed}), .CHAIN({_chain}), .TAP({_tap})) build_seed_inst (.clk({_clk}));\n\n")
    assert _topsrc.rstrip().endswith("endmodule"), "top.v does not end with endmodule"
    _cut = _topsrc.rstrip()[: -len("endmodule")]
    with open(_top, "w") as f:
        f.write(_cut + _inst + "endmodule\n")
    print(f"RTL build seed {_rtl_seed}: inserted a {_chain}-FF DONT_TOUCH chain (tap {_tap}) on {_clk}")

# sys.exit("Manual Exit")
###################### Generate additional tcl scripts ######################
if device == "fpga":
    project_tcl = ""
    project_tcl += f"create_project -force {example} ./{example}/ -part " + board["DESCRIPTION"]["PART"]["LONG"] + "\n"
    project_tcl +=  "\nadd_files -fileset constrs_1 ./constraints.xdc\nadd_files -scan_for_includes .\nupdate_compile_order -fileset sources_1\nset_property top top [current_fileset]\nupdate_compile_order -fileset sources_1\n"
    with open(build_dir + "/ip.tcl",'r') as f:
        project_tcl += f.read()
    with open(build_dir + "/create_project.tcl",'w') as f:
        f.write(project_tcl)

    # ------------------------------------------------------------------
    # IMPLEMENTATION SEEDS
    #
    # Vivado has NO random seed. Verified against this install: no -seed option
    # on place_design/phys_opt_design/route_design, and no property matching
    # *SEED* on a run. Implementation is deterministic -- identical inputs give
    # bit-identical output, so re-running a timing failure unchanged reproduces
    # it exactly.
    #
    # What DOES change the result is the DIRECTIVE: a different placement or
    # routing ALGORITHM, hence a different layout, hence different slack. That
    # is the same practical effect a seed sweep has in toolchains that do have
    # an RNG seed (Quartus, for one), and it is better in one respect -- each
    # seed here is reproducible rather than a lottery ticket.
    #
    # So: a "seed" in this project is an index into the table below. Seed 0 is
    # the Vivado default. Every other seed is a distinct combination. To add
    # your own, append a row -- the index is the seed number.
    #
    # Fields: (synth, opt, place, phys_opt, route, post_route_physopt, auto_idx)
    #   "" means leave that step at the tool default.
    #   auto_idx uses `place_design -directive Auto -auto_directive_index N`,
    #   where Vivado ranks its own directives by predicted timing improvement
    #   and N picks the Nth. Xilinx recommends N <= 3. This is the single knob
    #   in the whole tool that behaves most like a seed.
    #
    # Seeds 1-13 change implementation only, so synthesis can be reused.
    # Seeds 14+ also change synthesis -- a much larger perturbation, but they
    # cost a full re-synthesis.
    #
    # Directive names verified against this install with
    #   list_property_value STEPS.<STEP>.ARGS.DIRECTIVE [get_runs impl_1]
    # SSI_* and RQS are deliberately absent: SSI_* is for multi-die parts (the
    # 100T and 200T are single-die) and RQS needs a QoR-suggestions file.
    SEED_TABLE = [
        # synth               opt                place                    phys_opt                     route                  postPO auto
        ("",                  "",                "",                      "",                          "",                    False, 0),  # 0 Vivado default
        ("",                  "Explore",         "Explore",               "Explore",                   "Explore",             False, 0),  # 1
        ("",                  "Explore",         "Explore",               "AggressiveExplore",         "AggressiveExplore",   True,  0),  # 2
        ("",                  "",                "ExtraTimingOpt",        "Explore",                   "Explore",             True,  0),  # 3
        ("",                  "",                "ExtraPostPlacementOpt", "Explore",                   "NoTimingRelaxation",  True,  0),  # 4
        ("",                  "",                "",                      "Explore",                   "Explore",             False, 2),  # 5 auto-rank 2
        ("",                  "",                "",                      "Explore",                   "Explore",             False, 3),  # 6 auto-rank 3
        ("",                  "",                "ExtraNetDelay_high",    "AggressiveExplore",         "MoreGlobalIterations",True,  0),  # 7
        ("",                  "",                "ExtraNetDelay_low",     "Explore",                   "HigherDelayCost",     False, 0),  # 8
        ("",                  "",                "AltSpreadLogic_high",   "Explore",                   "AlternateCLBRouting", False, 0),  # 9
        ("",                  "",                "AltSpreadLogic_medium", "AlternateReplication",      "Explore",             False, 0),  # 10
        ("",                  "",                "WLDrivenBlockPlacement","AggressiveFanoutOpt",       "AdvancedSkewModeling",False, 0),  # 11
        ("",                  "ExploreWithRemap","Explore",               "AddRetime",                 "Explore",             True,  0),  # 12
        ("",                  "Explore",         "EarlyBlockPlacement",   "ExploreWithHoldFix",        "Explore",             False, 0),  # 13
        ("PerformanceOptimized", "",             "Explore",               "Explore",                   "Explore",             True,  0),  # 14
        ("AlternateRoutability", "",             "ExtraTimingOpt",        "AggressiveExplore",         "AggressiveExplore",   True,  0),  # 15
        ("FewerCarryChains",  "",                "Explore",               "AlternateFlowWithRetiming", "Explore",             False, 0),  # 16
        ("LogicCompaction",   "",                "ExtraPostPlacementOpt", "AggressiveExplore",         "NoTimingRelaxation",  True,  0),  # 17
    ]
    assert len(SEED_TABLE) == SEED_COUNT, (
        f"SEED_COUNT ({SEED_COUNT}) must equal len(SEED_TABLE) ({len(SEED_TABLE)})")
    _seed = args.seed
    _sy, _opt, _pl, _po, _rt, _postpo, _auto = SEED_TABLE[_seed]

    def _seed_tcl(run_impl="impl_1", run_synth="synth_1", seed=None):
        """Property assignments that put one seed's directives onto the runs.

        seed=None uses the seed this build was configured with; the sweep passes
        an explicit index so every sweep point comes from the same table, and a
        sweep hit can be reproduced later with `vebpf-mc build --seed <n>`.
        """
        _sy, _opt, _pl, _po, _rt, _postpo, _auto = (
            SEED_TABLE[seed] if seed is not None else SEED_TABLE[_seed])
        t = ""
        if _sy:
            t += f"set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE {_sy} [get_runs {run_synth}]\n"
        for step, val in (("OPT_DESIGN", _opt), ("PHYS_OPT_DESIGN", _po),
                          ("ROUTE_DESIGN", _rt)):
            if val:
                t += f"set_property STEPS.{step}.ARGS.DIRECTIVE {val} [get_runs {run_impl}]\n"
        if _auto:
            # -auto_directive_index is only meaningful with -directive Auto.
            t += f"set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Auto [get_runs {run_impl}]\n"
            t += ("set_property {STEPS.PLACE_DESIGN.ARGS.MORE OPTIONS} "
                  f"{{-auto_directive_index {_auto}}} [get_runs {run_impl}]\n")
        elif _pl:
            t += f"set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE {_pl} [get_runs {run_impl}]\n"
        if _postpo:
            t += f"set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs {run_impl}]\n"
            t += (f"set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore "
                  f"[get_runs {run_impl}]\n")
        return t

    # Record which seed built this, so a bitstream can be traced back to it.
    with open(build_dir + "/seed.txt", "w") as f:
        f.write(f"rtl_seed={_rtl_seed}\n")
        f.write(f"seed={_seed}\nsynth={_sy or 'Default'}\nopt={_opt or 'Default'}\n"
                f"place={_pl or ('Auto/' + str(_auto)) if (_pl or _auto) else 'Default'}\n"
                f"phys_opt={_po or 'Default'}\nroute={_rt or 'Default'}\n"
                f"post_route_phys_opt={_postpo}\n")

    compile_tcl = ""
    compile_tcl += f"open_project  ./{example}/{example}.xpr\n"
    compile_tcl += "update_compile_order -fileset sources_1\n"
    compile_tcl += "reset_run synth_1\n"
    # Vivado parallel jobs. This was hardcoded at 24, which assumes a large build
    # server. On a 4-core / 9 GB machine it forks 24 workers for no speedup and
    # six times the memory, and a 200T synthesis gets OOM-killed part way through
    # "Cross Boundary and Area Optimization". Derive it from the actual machine;
    # override with VIVADO_JOBS when you do have the cores to spare.
    _jobs = os.environ.get("VIVADO_JOBS")
    _jobs = int(_jobs) if _jobs else max(1, min(8, os.cpu_count() or 4))
    compile_tcl += _seed_tcl()
    compile_tcl += f"launch_runs synth_1 -jobs {_jobs} \n"
    compile_tcl += "wait_on_run synth_1\n"
    compile_tcl += "set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]\n"
    # TIMING GATE, part 1: stop at route_design. The bitstream is written by a
    # separate step, and only once timing has been checked. Vivado will happily
    # emit a bitstream for a design that misses timing, and such a bitstream runs
    # outside its constraints -- any throughput or latency measured on it is not
    # trustworthy. Writing it unconditionally is how this project shipped numbers
    # from timing-failing builds.
    # Run the implementation chain exactly as Vivado does by default, straight
    # through write_bitstream. Splitting the bitstream into a SECOND launch on an
    # already-complete run makes Vivado re-run DRC under the stricter default
    # ruledeck, which turns this design's long-standing LUTLP-1 combinational-loop
    # WARNING into a hard ERROR and blocks bitgen entirely. Measured both ways on
    # the same routed netlist: single launch writes the bitstream (LUTLP-1 warning
    # x3), split launch does not (same warnings, plus one ERROR).
    #
    # The gate must not quietly change which designs Vivado will build; it only
    # decides whether a bitstream is allowed to SURVIVE. So the bitstream is
    # written normally and then quarantined below if timing was not met.
    compile_tcl += f"launch_runs -to_step write_bitstream impl_1 -jobs {_jobs}\n"
    compile_tcl += "wait_on_run impl_1\n"
    compile_tcl += "open_run impl_1\n"
    compile_tcl += "report_timing_summary -quiet -warn_on_violation -file ./timing_gate.rpt\n"
    with open(build_dir + "/compile_project.tcl",'w') as f:
        f.write(compile_tcl)

    # The bitstream step on its own, so it can run after the gate passes or be
    # forced by hand afterwards.
    bit_tcl  = f"open_project  ./{example}/{example}.xpr\n"
    bit_tcl += "set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]\n"
    # Fallback path only (nothing quarantined). A second launch on a complete run
    # re-runs DRC strictly, so reset first and let the chain run through normally.
    bit_tcl += "reset_run impl_1\n"
    bit_tcl += f"launch_runs -to_step write_bitstream impl_1 -jobs {_jobs}\n"
    bit_tcl += "wait_on_run impl_1\n"
    with open(build_dir + "/write_bitstream.tcl",'w') as f:
        f.write(bit_tcl)

    ###################### Generate bash script ######################
    # TIMING GATE, part 2. report_timing_summary prints exactly one of two
    # verdicts; anything else (truncated or missing report) is treated as a
    # failure rather than waved through.
    # Quarantine, not deletion: move the bitstream out of the glob path that the
    # tooling searches, so a timing-failing build yields no usable .bit, while
    # `force_bitstream.sh` can hand it back instantly instead of paying for a
    # 15-minute re-implementation.
    quarantine = [
        'quarantine_bitstream() {',
        '    local moved=0',
        '    while IFS= read -r b; do',
        '        [ -f "$b" ] || continue',
        '        mv "$b" "$b.timing_failed"',
        '        moved=1',
        '    done < <(find . -name "*.bit" -o -name "*.bin" 2>/dev/null)',
        '    [ "$moved" = 1 ] && echo "TIMING GATE: bitstream quarantined as *.timing_failed" >&2',
        '    return 0',
        '}',
    ]
    gate_lines = quarantine + [
        'if [ ! -f ./timing_gate.rpt ]; then',
        '    echo "TIMING GATE: no timing report produced -- implementation did not complete." >&2',
        '    quarantine_bitstream',
        '    exit 2',
        'fi',
        'if grep -q "Timing constraints are not met" ./timing_gate.rpt; then',
        '    echo "" >&2',
        '    echo "=====================================================================" >&2',
        '    echo " TIMING NOT MET -- bitstream quarantined, not usable." >&2',
        '    grep -A4 "WNS(ns)" ./timing_gate.rpt | head -6 >&2',
        '    echo "" >&2',
        '    echo " A bitstream from a design that misses timing runs outside its" >&2',
        '    echo " constraints; results measured on it are not trustworthy." >&2',
        '    echo " To build one anyway, for bring-up or debug only:" >&2',
        '    echo "     bash ./force_bitstream.sh          (in this build directory)" >&2',
        '    echo "     ./vebpf-mc bitstream --force       (from the repo root)" >&2',
        '    echo "     task build:force                   (same, via Task)" >&2',
        '    echo "=====================================================================" >&2',
        '    quarantine_bitstream',
        '    exit 2',
        'fi',
        'if ! grep -q "All user specified timing constraints are met" ./timing_gate.rpt; then',
        '    echo "TIMING GATE: could not confirm timing from the report -- quarantining the bitstream." >&2',
        '    quarantine_bitstream',
        '    exit 2',
        'fi',
        'echo "TIMING GATE: all user specified timing constraints are met."',
    ]
    run = "vivado -nojournal -nolog -mode batch -source ./create_project.tcl \n"
    run += "vivado -nojournal -nolog -mode batch -source ./compile_project.tcl \n"
    run += "\n".join(gate_lines) + "\n"
    with open(build_dir + "/run.sh",'w') as f:
        f.write(run)

    # Escape hatch: the same bitstream step with no gate. Deliberately a separate
    # file so it cannot be reached by accident.
    force_lines = [
        '#!/usr/bin/env bash',
        '# Write a bitstream from this build REGARDLESS of timing.',
        '#',
        '# For bring-up and debug only. If timing was not met the device is being run',
        '# outside its constraints: behaviour is not guaranteed, and any throughput or',
        '# latency measured from it must not be reported as a result.',
        'set -e',
        'echo "force_bitstream: writing a bitstream WITHOUT a timing check." >&2',
        'if [ -f ./timing_gate.rpt ] && grep -q "Timing constraints are not met" ./timing_gate.rpt; then',
        '    grep -A4 "WNS(ns)" ./timing_gate.rpt | head -6 >&2',
        'fi',
        'restored=0',
        'while IFS= read -r q; do',
        '    [ -f "$q" ] || continue',
        '    mv "$q" "${q%.timing_failed}"',
        '    echo "force_bitstream: restored ${q%.timing_failed}" >&2',
        '    restored=1',
        'done < <(find . -name "*.bit.timing_failed" -o -name "*.bin.timing_failed" 2>/dev/null)',
        'if [ "$restored" = 1 ]; then exit 0; fi',
        'echo "force_bitstream: nothing quarantined; re-running implementation." >&2',
        'vivado -nojournal -nolog -mode batch -source ./write_bitstream.tcl',
    ]
    with open(build_dir + "/force_bitstream.sh",'w') as f:
        f.write("\n".join(force_lines) + "\n")

    ###################### Implementation sweep ######################
    # Vivado has no placer/router SEED. Verified against this install: there is
    # no -seed option on place_design/phys_opt_design/route_design, and no
    # property matching *SEED* on a run. Implementation is deterministic -- the
    # same netlist, constraints, directives and tool version give bit-identical
    # results every time. (Measured: two builds of identical RTL both landed on
    # WNS -3.743 exactly.)
    #
    # What Vivado offers instead is DIRECTIVE variation. Each directive is a
    # different placement/routing algorithm, so a design that misses timing
    # under one can meet it under another -- the same practical effect a seed
    # sweep has in Quartus, reached by a different route. Two knobs:
    #
    #   * named strategies -- bundles of place/phys_opt/route directives
    #   * place_design -directive Auto -auto_directive_index N
    #     Vivado ranks its own directives by predicted timing improvement and N
    #     picks the Nth. This is the closest thing to a seed: one integer, and
    #     each value is a genuinely different placement. Xilinx recommends
    #     N <= 3 (5 is the practical ceiling).
    #
    # Every point reuses synth_1 via -parent_run, so synthesis runs ONCE for the
    # whole sweep and each point costs only implementation.
    #
    # Points run one at a time, not in parallel: concurrent implementation runs
    # multiply peak memory, and this flow has already been OOM-killed once on a
    # 200T by over-parallelising (see VIVADO_JOBS above). The sweep stops at the
    # first point that meets every constraint, so an early hit costs one run.
    # The sweep is just "try seeds 1,2,3,... in order", so it shares SEED_TABLE
    # above rather than keeping a second list that could drift out of step.
    # Implementation-only seeds first (1-13) because they reuse synthesis; the
    # synthesis-varying ones (14+) cost a full re-synth per point.
    # Only the implementation-only seeds belong in a sweep. Every point shares
    # one synth_1 via -parent_run, so a seed that also changes the SYNTHESIS
    # directive would mark that shared run out of date and silently force a
    # re-synthesis part way through -- changing the netlist under the points
    # already measured. Seeds with a synth directive (14+) are `--seed`
    # territory: they need their own full build.
    _sweep_default = [(f"seed{i}", i) for i in range(1, len(SEED_TABLE))
                      if not SEED_TABLE[i][0]]
    _n = os.environ.get("VIVADO_SWEEP_POINTS")
    _points = _sweep_default[:int(_n)] if _n else _sweep_default

    sw  = f"open_project  ./{example}/{example}.xpr\n"
    sw += "update_compile_order -fileset sources_1\n"
    sw += "# synthesis is shared by every point; run it only if it is not already done\n"
    sw += "if {[get_property PROGRESS [get_runs synth_1]] ne \"100%\"} {\n"
    sw += f"    launch_runs synth_1 -jobs {_jobs}\n"
    sw += "    wait_on_run synth_1\n"
    sw += "}\n"
    sw += "set winner \"\"\n"
    sw += "set rows {}\n"
    for name, seed_idx in _points:
        rn = "impl_sw_" + name
        sw += f"\nif {{$winner eq \"\"}} {{\n"
        sw += f"  puts \"SWEEP: ==== {name} ====\"\n"
        sw += f"  if {{[llength [get_runs -quiet {rn}]]}} {{ delete_run {rn} -quiet }}\n"
        sw += f"  create_run {rn} -parent_run synth_1 -flow {{Vivado Implementation 2021}}\n"
        # Same table the --seed flag uses, so a sweep hit is reproducible later
        # with `vebpf-mc build --seed <n>`.
        sw += "".join("  " + ln + "\n"
                      for ln in _seed_tcl(run_impl=rn, seed=seed_idx).split("\n") if ln)
        sw += f"  set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs {rn}]\n"
        sw += f"  launch_runs -to_step route_design {rn} -jobs {_jobs}\n"
        sw += f"  wait_on_run {rn}\n"
        sw += f"  if {{[get_property PROGRESS [get_runs {rn}]] eq \"100%\"}} {{\n"
        sw += f"    open_run {rn}\n"
        sw += f"    report_timing_summary -quiet -warn_on_violation -file ./sweep_{name}.rpt\n"
        # A missing or unreadable report counts as NOT met -- same rule as the gate.
        sw += "    set met 0\n"
        sw += f"    if {{![catch {{set fh [open ./sweep_{name}.rpt r]}}]}} {{\n"
        sw += "      set txt [read $fh]; close $fh\n"
        sw += "      set met [expr {[string first \"All user specified timing constraints are met\" $txt] >= 0}]\n"
        sw += "    }\n"
        sw += f"    set wns [get_property STATS.WNS [get_runs {rn}]]\n"
        sw += f"    set whs [get_property STATS.WHS [get_runs {rn}]]\n"
        sw += f"    set tns [get_property STATS.TNS [get_runs {rn}]]\n"
        sw += ("    lappend rows [format \"  %-14s WNS %8s  WHS %8s  TNS %10s  %s\" "
               f"\"{name}\"" " $wns $whs $tns [expr {$met ? \"MET\" : \"not met\"}]]\n")
        sw += f"    puts \"SWEEP_POINT|{name}|$wns|$whs|$tns|$met\"\n"
        sw += "    close_design\n"
        # Keep the report, drop the run dir of a point that did not close: ten
        # routed 200T runs are ~500 MB and this often runs on a near-full disk.
        sw += f"    if {{$met}} {{ set winner {rn} }} else {{ delete_run {rn} -quiet }}\n"
        sw += "  } else {\n"
        sw += f"    puts \"SWEEP_POINT|{name}|ERROR|-|-|0\"\n"
        sw += f"    lappend rows [format \"  %-14s run did not complete\" \"{name}\"]\n"
        sw += "  }\n"
        sw += "}\n"

    sw += "\nputs \"\\nSWEEP SUMMARY\"\n"
    sw += "foreach r $rows { puts $r }\n"
    sw += "if {$winner ne \"\"} {\n"
    sw += "  puts \"SWEEP_WINNER|$winner\"\n"
    sw += f"  launch_runs -to_step write_bitstream $winner -jobs {_jobs}\n"
    sw += "  wait_on_run $winner\n"
    sw += "  puts \"SWEEP: bitstream written from $winner\"\n"
    sw += "} else {\n"
    sw += "  puts \"SWEEP_WINNER|NONE\"\n"
    sw += "}\n"
    with open(build_dir + "/sweep.tcl",'w') as f:
        f.write(sw)

    sweep_sh = [
        '#!/usr/bin/env bash',
        '# Implementation directive sweep -- Vivado has no seed; see sweep.tcl.',
        '# Re-implements the SAME synthesised netlist under different placement and',
        '# routing algorithms and keeps the first that meets every constraint.',
        'set -o pipefail',
        'vivado -nojournal -nolog -mode batch -source ./sweep.tcl 2>&1 | tee ./sweep.log',
        'if grep -q "^SWEEP_WINNER|NONE" ./sweep.log; then',
        '    echo "" >&2',
        '    echo "SWEEP: no directive met every timing constraint. Best points:" >&2',
        '    grep "^SWEEP_POINT|" ./sweep.log | sort -t"|" -k3 -g -r | head -3 >&2',
        '    exit 2',
        'fi',
        'grep "^SWEEP_WINNER|" ./sweep.log',
    ]
    with open(build_dir + "/sweep.sh",'w') as f:
        f.write("\n".join(sweep_sh) + "\n")

with open(build_dir + "/configure_options.tml", 'w') as f:
    toml.dump({"build_dir": build_dir, "exmaple": example, "example_dir": example_dir, "board": board["DESCRIPTION"]["NAME"], "device": device, "src": src, "project_root": project_root, "verbose": verbose},f)

print ("Done")