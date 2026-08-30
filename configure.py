#Example: python configure.py -example edgetestbed -build_dir ./build -board artya735t -v
# Tested with Vivado 2020.1
# Known issue with MIG IP generation in 2021.2

import os
import sys
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
DEFAULT_EXAMPLE = "2025_6_3_edgetestbed_jtag_uartprog_no_dram_network_subsystem_test1_arty100t_SIM"
DEFAULT_EXAMPLE_DIR = "./examples/edgetestbed"
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
parser.add_argument("--project_root", default="",
                    help="Root that ${PROJECT_ROOT} in a system.tml MEM_INIT path resolves to "
                         "(e.g. the consuming project's checkout). Defaults to this disl-core root.")
parser.add_argument("-v", action="store_true", help="Print debug information")
parser.add_argument("-v_build", action="store_true", help="Print build debug information")

args = parser.parse_args()

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
build_rc = os.system(f"python ./{device}/{tool}/system_builder/build.py ./{example_dir}/{example}/system.tml " + board["DESCRIPTION"]["DIRECTORY"] + f" {build_dir}/ {src} {tool} {build_verbose} {project_root}")
if build_rc != 0:
    error("build.py failed - see the traceback above. Not generating TCL scripts.")
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

    compile_tcl = ""
    compile_tcl += f"open_project  ./{example}/{example}.xpr\n"
    compile_tcl += "update_compile_order -fileset sources_1\n"
    compile_tcl += "reset_run synth_1\n"
    compile_tcl += "launch_runs synth_1 -jobs 24 \n"
    compile_tcl += "wait_on_run synth_1\n"
    compile_tcl += "set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]\n"
    compile_tcl += "launch_runs -to_step write_bitstream impl_1 -jobs 24\n"
    compile_tcl += "wait_on_run impl_1\n"
    with open(build_dir + "/compile_project.tcl",'w') as f:
        f.write(compile_tcl)
    ###################### Generate bash script ######################
    run = "vivado -nojournal -nolog -mode batch -source ./create_project.tcl \n"
    run += "vivado -nojournal -nolog -mode batch -source ./compile_project.tcl \n"
    with open(build_dir + "/run.sh",'w') as f: 
        f.write(run)

with open(build_dir + "/configure_options.tml", 'w') as f:
    toml.dump({"build_dir": build_dir, "exmaple": example, "example_dir": example_dir, "board": board["DESCRIPTION"]["NAME"], "device": device, "src": src, "project_root": project_root, "verbose": verbose},f)

print ("Done")