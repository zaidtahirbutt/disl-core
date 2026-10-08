import toml
import re
import json
import sys
import math
import copy
import shutil
import subprocess
import os
import sys
import inspect
# import tomllib
if sys.version_info >= (3, 11):
    import tomllib  # Python 3.11+
else:
    import tomli as tomllib  # Use tomli for older versions


def verilog_literal(value):
    """Render a TOML-sourced parameter value as a Verilog literal.

    Historically every parameter in this project was numeric and was
    emitted with a bare str(). String parameters are needed for memory
    initialization file paths (see BUILD.resolve_mem_init), which must
    reach the RTL quoted; booleans are mapped to 1/0 because str(True)
    would emit "True", which is not valid Verilog. Numeric behaviour is
    unchanged.
    """
    if isinstance(value, bool):            # must precede int: bool IS an int
        return "1" if value else "0"
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return str(value)


class BUILD:
    def __init__(self, system, board, build_dir, build_verbose, project_root=None,
                 prebuild_vars=None):
        def config_load(system):
            with open(system) as f:
                if ".tml" in system:
                    try:
                        with open(system, "rb") as f2:
                            data = tomllib.load(f2)
                    except tomllib.TOMLDecodeError as e:
                        print(f"Error decoding {system} TOML: {e}")
                    return toml.load(f)
                else:
                    return json.load(f)
        self.build_dir = build_dir
        self.build_verbose = build_verbose
        # Anchors for resolving MEM_INIT paths. Derived from this file's own
        # location rather than the CWD so they stay correct no matter where
        # build.py is invoked from.
        self.disl_root = os.path.dirname(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))))
        self.system_dir = os.path.abspath(system.split("/system.tml")[0])
        self.project_root = os.path.abspath(project_root) if project_root else self.disl_root
        # Extra NAME=VALUE arguments for individual PREBUILD steps, supplied on the
        # command line as --prebuild-var=<step>:<NAME>=<VALUE>. Scoped per step on
        # purpose: a value meant for one step must not leak into the others.
        self.prebuild_vars = prebuild_vars or {}
        self.system = config_load(system)
        self.modules = config_load('./fpga/common/config/modules.tml')
        self.definitions = config_load("./fpga/common/config/definitions.tml")
        self.common_defaults = config_load("./fpga/common/config/defaults.tml")
        self.board = config_load("./fpga/boards/" + board + "/config/board.tml")
        self.board_defaults = config_load("./fpga/boards/" + board + "/config/defaults.tml")
        self.params = {}
        self.interconnects = {}
        self.bus_contentions = {}
        self.top = "top"
        self.verilog = []

#####################################################################

    def evaluate_independent_parameters(self, instance_name, module):
        output_params = {}
        board_defaults = {}
        common_defaults = {}
        if module in self.board_defaults["MODULES"].keys():
            board_defaults = copy.deepcopy(self.board_defaults["MODULES"][module])
        if module in self.common_defaults["MODULES"].keys():
            common_defaults = copy.deepcopy(self.common_defaults["MODULES"][module])
            
            if (self.build_verbose):
                print(f'for module = {module} \n self.common_defaults["MODULES"][module] = {self.common_defaults["MODULES"][module]}')

        if "GLOBAL_PARAMETERS" in self.system.keys():
            for parameter in self.system["GLOBAL_PARAMETERS"].keys():
                if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
                    if parameter not in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                        if parameter in board_defaults.keys() or parameter in common_defaults.keys():
                            self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter] = self.system["GLOBAL_PARAMETERS"][parameter]
                if "PARAMETERS" not in self.system["INSTANTIATIONS"][instance_name].keys():
                    if parameter in board_defaults.keys() or parameter in common_defaults.keys():
                        self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"] = {}
                        self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter] = self.system["GLOBAL_PARAMETERS"][parameter]
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in board_defaults.keys():
                    board_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
                elif parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
                elif parameter in self.modules[module]["PARAMETERS"]:
                    output_params[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        for parameter in self.modules[module]["PARAMETERS"]:
            if parameter in board_defaults.keys():
                output_params[parameter] = board_defaults[parameter]
            elif parameter in common_defaults.keys():
                output_params[parameter] = common_defaults[parameter]
        return output_params

    def evaluate_uart_axi(self, instance_name, params):
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["uart_axi"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        output_params["CLKS_PER_BIT"] = math.floor((common_defaults["CLOCK_FREQ_MHZ"]*1000000)/common_defaults["UART_BAUD_RATE_BPS"])         
        return output_params
        
    def evaluate_i2c_axi(self, instance_name, params):
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["i2c_axi"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        output_params["CLOCK_DIVISOR"] = int(math.ceil(math.log2(common_defaults["CLOCK_FREQ_MHZ"]*1000000/100000)))   
        return output_params
        
    def evaluate_spi_axi(self, instance_name, params):
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["spi_axi"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        target_freq = common_defaults["SPI_FREQ_MHZ"]
        clock_freq = common_defaults["CLOCK_FREQ_MHZ"]
        clock_freq = math.ceil(clock_freq/4)
        output_params["CLOCK_DIVISOR"] = 0
        while (target_freq < clock_freq):
            output_params["CLOCK_DIVISOR"] += 1
            clock_freq = math.ceil(clock_freq/2)
        return output_params


    def evaluate_progloader_axi(self, instance_name, params):
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["uart_axi"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        output_params["CLKS_PER_BIT"] = math.floor((common_defaults["CLOCK_FREQ_MHZ"]*1000000)/common_defaults["UART_BAUD_RATE_BPS"])         
        return output_params
    
    def evaluate_progloader_riscv_vebpf_v2(self, instance_name, params):
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["uart_axi"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        output_params["CLKS_PER_BIT"] = math.floor((common_defaults["CLOCK_FREQ_MHZ"]*1000000)/common_defaults["UART_BAUD_RATE_BPS"])         
        return output_params
        
    def evaluate_timer_axi(self, instance_name, params):
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["uart_axi"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        output_params["TCKS_PER_US"] = common_defaults["CLOCK_FREQ_MHZ"]   
        return output_params
        
    def evaluate_bram(self, instance_name, params):
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["bram"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        output_params["ADDR_WIDTH"] = math.ceil(math.log2(common_defaults["MEMORY_SIZE"]*1024))        
        return output_params

    def evaluate_laplacian_rgb565_rv32_pcpi_full(self, instance_name, params):
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["laplacian_rgb565_rv32_pcpi_full"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        target_freq = common_defaults["SPI_FREQ_MHZ"]
        clock_freq = common_defaults["CLOCK_FREQ_MHZ"]
        clock_freq = math.ceil(clock_freq/2)
        output_params["SPI_CLOCK_DIVISOR"] = 0
        while (target_freq < clock_freq):
            output_params["SPI_CLOCK_DIVISOR"] += 1
            clock_freq = math.ceil(clock_freq/2)  
        output_params["UART_TX_CLKS_PER_BIT"] = math.floor((common_defaults["CLOCK_FREQ_MHZ"]*1000000)/common_defaults["UART_BAUD_RATE_BPS"])  
        return output_params
        
    def evaluate_picorv32_axi(self, instance_name, params):
        
        # check where is the function being called from
        caller_frame = inspect.stack()[1]

        # Extract relevant information
        caller_function = caller_frame.function       # Caller function name
        caller_line_no = caller_frame.lineno          # Line number where it was called
        caller_file = caller_frame.filename           # File name

        # Print caller information
        # print(f"Function called from: {caller_function} in {caller_file} at line {caller_line_no}")
        # Function called from: generate_parameters in /home/zaidt/projects/Git_synched_repos/DISL_latest_v_may2024/DISL/./fpga//system_builder/build.py at line 668

        # so riscv linker and reset handler are populated by MAP fileds of the riscv address map in the system.tml file. The cache depth is not translated to the linker or reset handler.
        # the user has to manually specify cache depth separately and has to make sure that the cache depth/memory length of the riscv address map can fit into the cache (bram, etc) being
        # instantiated separately.

        # sys.exit("Entered evaluate picorv32 axi.. Exiting")
    
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["picorv32_axi"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        output_params["STACKADDR"] = common_defaults["INSTRUCTION_AND_DATA_MEMORY_SIZE_BYTES"]
        output_params["LATCHED_IRQ"] = common_defaults["INSTRUCTION_AND_DATA_MEMORY_SIZE_BYTES"]
        output_params["PROGADDR_RESET"] = common_defaults["INSTRUCTION_MEMORY_STARTING_ADDRESS"]
        output_params["PROGADDR_IRQ"] = common_defaults["INTERRUPT_HANDLER_STARTING_ADDRESS"]
        output_params["ENABLE_IRQ"] = common_defaults["ENABLE_INTERRUPTS"]
        linker = ""
        linker += "MEMORY {\n"
        for connection in self.system["INSTANTIATIONS"][instance_name]["MAP"].keys():
            linker += "\t." + connection + " (rwx) : ORIGIN = " + self.system["INSTANTIATIONS"][instance_name]["MAP"][connection]["ORIGIN"] + ", LENGTH = " + self.system["INSTANTIATIONS"][instance_name]["MAP"][connection]["LENGTH"] + "\n"
        linker += "}\n\n"
        linker += "SECTIONS {\n"
        mem = self.system["INSTANTIATIONS"][instance_name]["MEMORY"]
        linker += "\t." + mem + " : {\n\t\t. = 0x0;\n\t\t" + instance_name + "_reset_handler.o;\n\t\tstart*(.text);\n\t\t*(.text);\n\t\t*(*);\n\t\tend = .;\n\t}\n"
        for connection in self.system["INSTANTIATIONS"][instance_name]["MAP"].keys():
            if connection == mem: continue
            linker += "\t." + connection + " " +  self.system["INSTANTIATIONS"][instance_name]["MAP"][connection]["ORIGIN"] + ": {PROVIDE(" + connection.upper() + " = .);}\n"
        linker += "}\n\n"
        linker += "ENTRY(main)"
        with open(self.build_dir + instance_name + "_linker.ld", "w") as f:
            f.write(linker)
        reset_handler_w_interrupts = """#define regnum_q0   0\n#define regnum_q1   1\n#define regnum_q2   2\n#define regnum_q3   3\n
            \r#define regnum_x0   0\n#define regnum_x1   1\n#define regnum_x2   2\n#define regnum_x3   3\n#define regnum_x4   4\n#define regnum_x5   5\n#define regnum_x6   6\n#define regnum_x7   7\n#define regnum_x8   8\n#define regnum_x9   9\n#define regnum_x10 10\n#define regnum_x11 11\n#define regnum_x12 12\n#define regnum_x13 13\n#define regnum_x14 14\n#define regnum_x15 15\n#define regnum_x16 16\n#define regnum_x17 17\n#define regnum_x18 18\n#define regnum_x19 19\n#define regnum_x20 20\n#define regnum_x21 21\n#define regnum_x22 22\n#define regnum_x23 23\n#define regnum_x24 24\n#define regnum_x25 25\n#define regnum_x26 26\n#define regnum_x27 27\n#define regnum_x28 28\n#define regnum_x29 29\n#define regnum_x30 30\n#define regnum_x31 31\n
            \r#define regnum_zero 0\n#define regnum_ra   1\n#define regnum_sp   2\n#define regnum_gp   3\n#define regnum_tp   4\n#define regnum_t0   5\n#define regnum_t1   6\n#define regnum_t2   7\n#define regnum_s0   8\n#define regnum_s1   9\n#define regnum_a0  10\n#define regnum_a1  11\n#define regnum_a2  12\n#define regnum_a3  13\n#define regnum_a4  14\n#define regnum_a5  15\n#define regnum_a6  16\n#define regnum_a7  17\n#define regnum_s2  18\n#define regnum_s3  19\n#define regnum_s4  20\n#define regnum_s5  21\n#define regnum_s6  22\n#define regnum_s7  23\n#define regnum_s8  24\n#define regnum_s9  25\n#define regnum_s10 26\n#define regnum_s11 27\n#define regnum_t3  28\n#define regnum_t4  29\n#define regnum_t5  30\n#define regnum_t6  31\n
            \r#define regnum_fp   8\n
            \r#define r_type_insn(_f7, _rs2, _rs1, _f3, _rd, _opc) \\\n.word (((_f7) << 25) | ((_rs2) << 20) | ((_rs1) << 15) | ((_f3) << 12) | ((_rd) << 7) | ((_opc) << 0))
            \r#define retirq_insn() \\\nr_type_insn(0b0000010, 0, 0, 0b000, 0, 0b0001011)
            \r#define maskirq_insn(_rd, _rs) \\\nr_type_insn(0b0000011, 0, regnum_ ## _rs, 0b110, regnum_ ## _rd, 0b0001011)
            \r#define waitirq_insn(_rd) \\\nr_type_insn(0b0000100, 0, 0, 0b100, regnum_ ## _rd, 0b0001011)
            \r.text
            \r.align  2
            \r_start:
            \rli  sp,""" + str(self.system["INSTANTIATIONS"][instance_name]["MAP"][mem]["ORIGIN"]) + "+" + str(self.system["INSTANTIATIONS"][instance_name]["MAP"][mem]["LENGTH"]) + """
            \rmaskirq_insn(zero, zero)
            \rjal main
            \r.balign """ +  str(common_defaults["INTERRUPT_HANDLER_STARTING_ADDRESS"]) + """
            \r_irq:
            \rsw gp,   0*4+0x200(zero)\nsw x1,   1*4+0x200(zero)\nsw x2,   2*4+0x200(zero)\nsw x3,   3*4+0x200(zero)\nsw x4,   4*4+0x200(zero)\nsw x5,   5*4+0x200(zero)\nsw x6,   6*4+0x200(zero)\nsw x7,   7*4+0x200(zero)\nsw x8,   8*4+0x200(zero)\nsw x9,   9*4+0x200(zero)\nsw x10, 10*4+0x200(zero)\nsw x11, 11*4+0x200(zero)\nsw x12, 12*4+0x200(zero)\nsw x13, 13*4+0x200(zero)\nsw x14, 14*4+0x200(zero)\nsw x15, 15*4+0x200(zero)\nsw x16, 16*4+0x200(zero)\nsw x17, 17*4+0x200(zero)\nsw x18, 18*4+0x200(zero)\nsw x19, 19*4+0x200(zero)\nsw x20, 20*4+0x200(zero)\nsw x21, 21*4+0x200(zero)\nsw x22, 22*4+0x200(zero)\nsw x23, 23*4+0x200(zero)\nsw x24, 24*4+0x200(zero)\nsw x25, 25*4+0x200(zero)\nsw x26, 26*4+0x200(zero)\nsw x27, 27*4+0x200(zero)\nsw x28, 28*4+0x200(zero)\nsw x29, 29*4+0x200(zero)\nsw x30, 30*4+0x200(zero)\nsw x31, 31*4+0x200(zero)   
            \rjal ra, irq 
            \rlw x1,   1*4+0x200(zero)\nlw x2,   2*4+0x200(zero)\nlw x3,   3*4+0x200(zero)\nlw x4,   4*4+0x200(zero)\nlw x5,   5*4+0x200(zero)\nlw x6,   6*4+0x200(zero)\nlw x7,   7*4+0x200(zero)\nlw x8,   8*4+0x200(zero)\nlw x9,   9*4+0x200(zero)\nlw x10, 10*4+0x200(zero)\nlw x11, 11*4+0x200(zero)\nlw x12, 12*4+0x200(zero)\nlw x13, 13*4+0x200(zero)\nlw x14, 14*4+0x200(zero)\nlw x15, 15*4+0x200(zero)\nlw x16, 16*4+0x200(zero)\nlw x17, 17*4+0x200(zero)\nlw x18, 18*4+0x200(zero)\nlw x19, 19*4+0x200(zero)\nlw x20, 20*4+0x200(zero)\nlw x21, 21*4+0x200(zero)\nlw x22, 22*4+0x200(zero)\nlw x23, 23*4+0x200(zero)\nlw x24, 24*4+0x200(zero)\nlw x25, 25*4+0x200(zero)\nlw x26, 26*4+0x200(zero)\nlw x27, 27*4+0x200(zero)\nlw x28, 28*4+0x200(zero)\nlw x29, 29*4+0x200(zero)\nlw x30, 30*4+0x200(zero)\nlw x31, 31*4+0x200(zero)
            \rretirq_insn()
            \r_hw_shutdown:
            \rjal _hw_shutdown
            \r.balign 0x200
            \rirq_regs:
            \r// registers are saved to this memory region during interrupt handling
            \r// the program counter is saved as register 0
            \r.fill 32,4
            \r// stack for the interrupt handler
            \r.fill 128,4
            \rirq_stack:
        """
        reset_handler_w_o_interrupts = """.text\n.align  2\n_start:\n\tli  sp,""" + str(self.system["INSTANTIATIONS"][instance_name]["MAP"][mem]["ORIGIN"]) + "+" + str(self.system["INSTANTIATIONS"][instance_name]["MAP"][mem]["LENGTH"])  + """\n\tjal main\n_hw_shutdown:\n\tjal _hw_shutdown"""
        reset_handler = reset_handler_w_interrupts if common_defaults["ENABLE_INTERRUPTS"] else reset_handler_w_o_interrupts
        with open(self.build_dir + instance_name + "_reset_handler.S", "w") as f:
            f.write(reset_handler)
        return output_params

    def evaluate_picorv32_hydra_axi(self, instance_name, params):
        # sys.exit("Entered evaluate evaluate_picorv32_hydra_axi.. Exiting")
        return self.evaluate_picorv32_axi(instance_name, params)

    def evaluate_vexriscv_murax_simple(self, instance_name, params):
        output_params = params
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["vexriscv_murax_simple"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        linker = ""
        linker += "MEMORY {\n"
        for connection in self.system["INSTANTIATIONS"][instance_name]["MAP"].keys():
            linker += "\t." + connection + " (rwx) : ORIGIN = " + self.system["INSTANTIATIONS"][instance_name]["MAP"][connection]["ORIGIN"] + ", LENGTH = " + self.system["INSTANTIATIONS"][instance_name]["MAP"][connection]["LENGTH"] + "\n"
        linker += "}\n\n"
        linker += "SECTIONS {\n"
        mem = self.system["INSTANTIATIONS"][instance_name]["MEMORY"]
        linker += "\t." + mem + " : {\n\t\t. = 0x0;\n\t\t" + instance_name + "_reset_handler.o;\n\t\tstart*(.text);\n\t\t*(.text);\n\t\t*(*);\n\t\tend = .;\n\t}\n"
        for connection in self.system["INSTANTIATIONS"][instance_name]["MAP"].keys():
            if connection == mem: continue
            linker += "\t." + connection + " " +  self.system["INSTANTIATIONS"][instance_name]["MAP"][connection]["ORIGIN"] + ": {PROVIDE(" + connection.upper() + " = .);}\n"
        linker += "}\n\n"
        linker += "ENTRY(main)"
        with open(self.build_dir + instance_name + "_linker.ld", "w") as f:
            f.write(linker)
        reset_handler_w_o_interrupts = """.text\n.align  2\n_start:\n\tli  sp,""" + str(self.system["INSTANTIATIONS"][instance_name]["MAP"][mem]["ORIGIN"]) + "+" + str(self.system["INSTANTIATIONS"][instance_name]["MAP"][mem]["LENGTH"])  + """\n\tjal main\n_hw_shutdown:\n\tjal _hw_shutdown"""
        reset_handler = reset_handler_w_o_interrupts
        with open(self.build_dir + instance_name + "_reset_handler.S", "w") as f:
            f.write(reset_handler)
        return output_params
        
        
    def evaluate_ddr_controller(self, instance_name, params):
        output_params = params
        encodings = self.modules["ddr_controller"]["ENCODINGS"]
        common_defaults = copy.deepcopy(self.common_defaults["MODULES"]["ddr_controller"])
        board_defaults = copy.deepcopy(self.board_defaults["MODULES"]["ddr_controller"])
        if "PARAMETERS" in self.system["INSTANTIATIONS"][instance_name].keys():
            for parameter in self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"].keys():
                if parameter in board_defaults.keys():
                    board_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
                elif parameter in common_defaults.keys():
                    common_defaults[parameter] = self.system["INSTANTIATIONS"][instance_name]["PARAMETERS"][parameter]
        # Derive remaining parameters not associated with config address space

        output_params["COMMAND_WORD"] = 0
        for signal in encodings["controller_command_word"].keys():
            output_params["COMMAND_WORD"] = max(output_params["COMMAND_WORD"], max(encodings["controller_command_word"][signal]["BITS"]))
        output_params["COMMAND_WORD"] += 1
        max_timer_id = 0
        for parameter in output_params.keys():
            if "TIMERID_" in parameter:
                max_timer_id  = max(max_timer_id, output_params[parameter])
        if max_timer_id > 1:
            output_params["TIMER_BITS"]= int(math.ceil(math.log2(max_timer_id)))
        else:
            output_params["TIMER_BITS"]= 1
        output_params["NUM_SLOTS"] = int(output_params["BURST_SIZE"]/2)
        chip_command_db = {}
        for cmd in board_defaults["CHIP_COMMANDS"]["COMMANDS"].keys():
            chip_command_word = 0
            for i in range(len(board_defaults["CHIP_COMMANDS"]["COMMANDS"][cmd])):
                chip_command_word += encodings["chip_command_word"][board_defaults["CHIP_COMMANDS"]["ENCODING"][i]][board_defaults["CHIP_COMMANDS"]["COMMANDS"][cmd][i]]
            chip_command_db[cmd] = chip_command_word
        output_params["CMD_READ"] = chip_command_db["READ"]
        output_params["CMD_WRITE"] = chip_command_db["WRITE"]
        output_params["CMD_ACTIVATE"] = chip_command_db["ACTIVATE"]
        output_params["CMD_PRECHARGE"] = chip_command_db["PRECHARGE"]
        largest_macro_size = 0
        for macro in common_defaults["MACRO_ENCODINGS"].keys():
            largest_macro_size = max (largest_macro_size , len(common_defaults["MACRO_ENCODINGS"][macro]["COMMANDS"]))
        largest_macro_size_bits = int(math.ceil(math.log2(largest_macro_size))) + (largest_macro_size*(output_params["TIMER_BITS"] + int(math.ceil(math.log2(output_params["NUM_SLOTS"]))) + output_params["COMMAND_WORD"]))
        output_params["MACRO_WORD"] = 8*(int(math.ceil(largest_macro_size_bits/8)))
        output_params["MACRO_COUNT_BITS"] = output_params["MACRO_WORD"] - (largest_macro_size*(output_params["TIMER_BITS"] + int(math.ceil(math.log2(output_params["NUM_SLOTS"]))) + output_params["COMMAND_WORD"]))
        # Evaluate configuration addresses
        def eval_config(modules, config_block, output_params):        
            size = modules["ddr_controller"]["INTERFACES"]["config"]["LAYOUT"][config_block]["SIZE"]
            if type(size) != int:
                size = size.split(" ")
                for i in range(len(size)):
                    if size[i] in output_params.keys():
                        size[i] = str(output_params[size[i]])
                size = eval(" ".join(size))
            return size

        output_params["MACRO_CONFIG_WORDS_NEEDED"] = math.ceil(output_params["MACRO_WORD"]/output_params["CONFIGURATION_DATA_BITS"]);
        output_params["MACRO_CONFIG_BITS_NEEDED"] = math.ceil(math.log2(output_params["MACRO_CONFIG_WORDS_NEEDED"]))
        output_params["CONFIGADDR_START_ADDRESS_FORMAT"] = 0
        output_params["CONFIGADDR_END_ADDRESS_FORMAT"] = output_params["CONFIGADDR_START_ADDRESS_FORMAT"] + eval_config(self.modules,"ddr_address_map", output_params) - 1
        output_params["CONFIGADDR_START_TIMERS"] = output_params["CONFIGADDR_END_ADDRESS_FORMAT"] + 1
        output_params["CONFIGADDR_END_TIMERS"] = output_params["CONFIGADDR_START_TIMERS"] + eval_config(self.modules,"ddr_timer_db", output_params) - 1
        output_params["CONFIGADDR_START_PERFTUNER"] = output_params["CONFIGADDR_END_TIMERS"] + 1
        output_params["CONFIGADDR_END_PERFTUNER"] = output_params["CONFIGADDR_START_PERFTUNER"] + eval_config(self.modules,"ddr_perftuner", output_params) - 1
        output_params["CONFIGADDR_START_REFRESH_RULES"] = output_params["CONFIGADDR_END_PERFTUNER"] + 1
        output_params["CONFIGADDR_END_REFRESH_RULES"] = output_params["CONFIGADDR_START_REFRESH_RULES"] + eval_config(self.modules,"ddr_refresh", output_params) - 1
        output_params["CONFIGADDR_START_RUNTIME_RULES"] = output_params["CONFIGADDR_END_REFRESH_RULES"] + 1
        output_params["CONFIGADDR_END_RUNTIME_RULES"] = output_params["CONFIGADDR_START_RUNTIME_RULES"] + eval_config(self.modules,"ddr_runtime_rules", output_params) - 1
        output_params["CONFIGADDR_START_ARBITER"] = output_params["CONFIGADDR_END_RUNTIME_RULES"] + 1
        output_params["CONFIGADDR_END_ARBITER"] = output_params["CONFIGADDR_START_ARBITER"] + eval_config(self.modules,"ddr_arbiter", output_params) - 1
        output_params["REFRESH_RULES_INIT_HEX"] = "\"" + instance_name + "_refresh_rules.hex\""
        output_params["RUNTIME_RULES_INIT_HEX"] = "\"" + instance_name + "_runtime_rules.hex\""
        output_params["ARBITER_RULES_INIT_HEX"] = "\"" + instance_name + "_arbiter_rules.hex\""
        #Generate Rules
        arbiter_rules = []
        banks = 2**output_params["DDR_BA_WIDTH"]
        if (common_defaults["BANK_ARBITRATION_POLICY"] == 'ROUNDROBIN'):
            for request in range (2**banks):
                for last_granted in range (banks):
                    if (request == 0):
                        arbiter_rules.append(last_granted)
                    else:
                        base = last_granted+1
                        for i in range(banks):
                            if (base >= banks):
                                base = 0
                            if (request & (1 << base)):
                                arbiter_rules.append(base)
                                break
                            else:
                                base = base + 1
        if (common_defaults["BANK_ARBITRATION_POLICY"] == 'STICKY'):
            for request in range (2**banks):
                for last_granted in range (banks):
                    if (request == 0):
                        arbiter_rules.append(last_granted)
                    else:
                        if (request & (1 << last_granted)):
                            arbiter_rules.append(last_granted)
                        else:         
                            base = last_granted+1
                            for i in range(banks):
                                if (base >= banks):
                                    base = 0
                                if (request & (1 << base)):
                                    arbiter_rules.append(base)
                                    break
                                else:
                                    base = base + 1    
        with open(self.build_dir + output_params["ARBITER_RULES_INIT_HEX"][1:-1], 'w') as f:
            for bank in arbiter_rules:
                f.write(format(bank, 'x'))
                f.write("\n")    
        # Build command databased for refresh and runtime rules
        command_db = {}
        for cmd in board_defaults["CONTROLLER_COMMANDS"]["COMMANDS"].keys():
            chip_command_word = chip_command_db[board_defaults["CONTROLLER_COMMANDS"]["COMMANDS"][cmd][board_defaults["CONTROLLER_COMMANDS"]["ENCODING"].index("chip_command_word")]]
            command_value = encodings["controller_command_word"]["chip_command_word"][str(chip_command_word)]
            for i in range(len(board_defaults["CONTROLLER_COMMANDS"]["COMMANDS"][cmd])):
                if "chip_command_word" == board_defaults["CONTROLLER_COMMANDS"]["ENCODING"][i]: continue
                command_value += encodings["controller_command_word"][  board_defaults["CONTROLLER_COMMANDS"]["ENCODING"][i]  ][board_defaults["CONTROLLER_COMMANDS"]["COMMANDS"][cmd][i]]
            command_db[cmd] = command_value
        # Generate refresh rules
        refresh_rules = []
        for command in board_defaults["REFRESH_COMMANDS"]:
            command_value = command_db[command]
            refresh_rules.append(command_value)
        digits = math.ceil(output_params["COMMAND_WORD"]/4)
        with open(self.build_dir + output_params["REFRESH_RULES_INIT_HEX"][1:-1], 'w') as f:
            for command in refresh_rules:
                f.write(str(format(command ,'x')).zfill(digits))
                f.write("\n")
        # Generate runtime rules        
        macro_db = {}
        slot_bits = int(math.ceil(math.log2(output_params["NUM_SLOTS"])))
        timer_bits = output_params["TIMER_BITS"]
        command_bits = output_params["COMMAND_WORD"] 
        macro_word = output_params["MACRO_WORD"]
        digits = math.ceil(macro_word/4)
        command_values_db = {}
        for macro in common_defaults["MACRO_ENCODINGS"].keys():
            command_values_db[macro] = []
            for command in common_defaults["MACRO_ENCODINGS"][macro]["COMMANDS"]:
                command_values_db[macro].append(command_db[command])            
            command_values = list(command_values_db[macro])
            command_slots = list(common_defaults["MACRO_ENCODINGS"][macro]["COMMAND_SLOTS"])
            command_timers = list(common_defaults["MACRO_ENCODINGS"][macro]["TIMERS"])
            idx_slot = encodings["macro_word"]["ENCODING"].index("COMMAND_SLOT")
            idx_timer = encodings["macro_word"]["ENCODING"].index("TIMER")
            idx_command = encodings["macro_word"]["ENCODING"].index("RUNTIME_COMMAND")
            idx = {}
            idx[str(idx_command)] = command_bits
            idx[str(idx_timer)] = timer_bits
            idx[str(idx_slot)] = slot_bits
            slot_offset = 0
            command_offset = 0
            timer_offset = 0
            start = 0
            while (start < idx_slot):
                slot_offset += idx[str(start)]
                start += 1
            start = 0
            while (start < idx_timer):
                timer_offset += idx[str(start)]
                start += 1
            start = 0
            while (start < idx_command):
                command_offset += idx[str(start)]
                start += 1
            values = []
            for (value, slot, timer) in zip(command_values, command_slots, command_timers):
                values.append((2**slot_offset)*slot + (2**timer_offset)*output_params["TIMERID_"+timer] + (2**command_offset)*value)
            value = len(values)*(2**(largest_macro_size*(slot_bits+timer_bits+command_bits)))
            for i in range(len(values)):
                value = value + (2**(i*(slot_bits+timer_bits+command_bits)))*values[i]
            macro_db[macro] = value
        runtime_rules = []
        for macro in common_defaults["MACROS"]:
            runtime_rules.append(macro_db[macro])
        with open(self.build_dir + output_params["RUNTIME_RULES_INIT_HEX"][1:-1], 'w') as f:
            for macro in runtime_rules:
                f.write(str(format( macro  ,'x')).zfill(digits))
                f.write("\n")  
        return output_params

    def get_signal_direction(self, interface_type, interface_direction, interface_signal):
            definition = self.definitions["PROTOCOLS"][interface_type] 
            assert interface_signal in definition["WIDTHS"] , "The signal \"" + interface_signal + "\" does not exist in interface \"" +interface_type + "\""
            signal_origin = ""
            for handshake in definition["HANDSHAKES"].keys():
                if handshake == "NONE":
                    if interface_signal in definition["HANDSHAKES"]["NONE"]["REQUEST"]:
                        signal_origin = "SOURCE"
                    elif interface_signal in definition["HANDSHAKES"]["NONE"]["RESPONSE"]:
                        signal_origin = "SINK"
                    else:
                        signal_origin = "BIDIR"
                else:
                    if interface_signal == definition["HANDSHAKES"][handshake]["READY"]:
                        signal_origin = "SINK" if  definition["HANDSHAKES"][handshake]["DIRECTION"] == "REQUEST" else "SOURCE"
                        break
                    if interface_signal == definition["HANDSHAKES"][handshake]["VALID"]:
                        signal_origin = "SOURCE" if  definition["HANDSHAKES"][handshake]["DIRECTION"] == "REQUEST" else "SINK"
                        break
                    if interface_signal in definition["HANDSHAKES"][handshake]["FRAME"]:
                        signal_origin = "SOURCE" if  definition["HANDSHAKES"][handshake]["DIRECTION"] == "REQUEST" else "SINK"
                        break
            assert signal_origin, "The direction of signal \"" + interface_signal + "\" in interface \"" + interface_type + "\" could not be determined"
            if signal_origin == "BIDIR":
                return "BIDIR"
            elif interface_direction == "SOURCE" and signal_origin == "SOURCE":
                return "SOURCE"
            elif interface_direction == "SOURCE" and signal_origin == "SINK":
                return "SINK"
            elif interface_direction == "SINK" and signal_origin == "SOURCE":
                return"SINK"
            else:
                return "SOURCE"


    def decode_constant_signal(self, name):
        signal = {}
        namespace = name[0]
        signal["NAMESPACE"] = namespace    
        signal["NAME"] = name[1]
        signal["DIRECTION"] = "SOURCE"
        signal["SIGNAL"] = name[1]
        signal["INTERFACE_TYPE"] = "GENERAL"
        return signal

    def decode_system_signal(self, name):
        signal = {}
        namespace = name[0]
        signal["NAMESPACE"] = namespace  
        signal["INTERFACE_TYPE"] = "GENERAL"
        keys = name[1].split(".")
        signal["NAME"] = self.system[keys[0]]
        for idx in range(len(keys)-1): 
            signal["NAME"] = signal["NAME"][keys[idx+1]]
        signal["NAME"] = str(signal["NAME"])
        if "0" == signal["NAME"][0] and "x" == signal["NAME"][1]:
            signal["NAME"] = str(4*(len(signal["NAME"])-2)) + "'h" + str(format( int(signal["NAME"],16)  ,'x')).zfill(len(signal["NAME"])-2)
        signal["DIRECTION"] = "SOURCE"
        return signal

    def decode_custom_signal(self,name):
        signal = {}
        namespace = name[0]
        signal["NAMESPACE"] = namespace    
        signal["NAME"] = "custom_" + name[1]
        signal["DIRECTION"] = "SOURCE"
        signal["SIGNAL"] = name[1]
        signal["INTERFACE_TYPE"] = "GENERAL"
        return signal

    def decode_parameter_signal(self,name):
        signal = {}
        namespace = name[0]
        signal["NAMESPACE"] = namespace    
        signal["NAME"] = "PARAMETER_" + name[1].upper() + "_" + name[2]
        signal["DIRECTION"] = "SOURCE"
        signal["INTERFACE_TYPE"] = "GENERAL"
        return signal

    def decode_module_signal(self, name):
        signal = {}
        namespace = name[0]
        module = self.system["INSTANTIATIONS"][name[1]]["MODULE"]
        interface = self.modules[module]["INTERFACES"][name[2]]
        params = self.params[name[1]]
        signal["NAMESPACE"] = namespace
        signal["MODULE_INST"] =  name[1]
        signal["INTERFACE_NAME"] = name[2]
        signal["INTERFACE_TYPE"] = interface["TYPE"]
        signal["WIDTH"] = ""
        signal["DIRECTION"] = interface["DIRECTION"]
        signal["NAME"] = "module_" + name[1] + "_" + name[2]
        signal["SIGNAL"] = ""
        if interface["TYPE"] == "GENERAL":
            signal["SIGNAL"] = name[2]
            signal["DIRECTION"] = interface["DIRECTION"]
            width = str(interface["WIDTH"])
            if width in params.keys():
                signal["WIDTH"] = self.decode_signal("PARAMETER:" + signal["MODULE_INST"]  + ":" + width)["NAME"]
            elif " " in str(width):
                width = width.split(" ")
                for i in range(len(width)):
                    if width[i] in params.keys():
                        width[i] = self.decode_signal("PARAMETER:" + signal["MODULE_INST"]  + ":" + width[i])["NAME"]
                width = " ".join(width)
                signal["WIDTH"] = "(" +str(width) + ")"
            else:
                signal["WIDTH"] = str(width)
        elif interface["TYPE"] in ["CLOCK"]:
            signal["SIGNAL"] = name[2]
            signal["DIRECTION"] = interface["DIRECTION"]
            signal["WIDTH"] = "1"
        elif len(name) == 4:
            signal["SIGNAL"] = name[3]
            signal["NAME"] += "_" + name[3]
            interface_signal = name[3]
            signal["DIRECTION"] = self.get_signal_direction(interface["TYPE"], interface["DIRECTION"], interface_signal)
            width = str(self.definitions["PROTOCOLS"][interface["TYPE"]]["WIDTHS"][interface_signal])
            if not width.isnumeric():
                width = self.modules[module]["INTERFACES"][signal["INTERFACE_NAME"]][width]
            if width in params.keys():
                signal["WIDTH"] = self.decode_signal("PARAMETER:" + signal["MODULE_INST"]  + ":" + width)["NAME"]
            elif " " in str(width):
                width = width.split(" ")
                for i in range(len(width)):
                    if width[i] in params.keys():
                        width[i] = self.decode_signal("PARAMETER:" + signal["MODULE_INST"]  + ":" + width[i])["NAME"]
                width = " ".join(width)
                signal["WIDTH"] = "(" +str(width) + ")"
            else:
                signal["WIDTH"] = str(width)
        return signal

    def decode_board_signal(self,name):
        signal = {}
        namespace = name[0]
        io = self.board["IO"][name[1]] 
        signal["NAMESPACE"] = namespace
        signal["INTERFACE_NAME"] = name[1]
        signal["NAME"] = name[1]
        signal["DIRECTION"] = io["DIRECTION"]
        signal["INTERFACE_TYPE"] = io["INTERFACE_TYPE"]
        signal["SIGNAL"] = ""
        if "WIDTH" in io.keys():
            signal["DIRECTION"] = io["DIRECTION"]
            signal["WIDTH"] = str(io["WIDTH"])
            signal["SIGNAL"] = name[1]        
            signal["IO_DIRECTION"] = "input" if signal["DIRECTION"] == "SOURCE" else ("output" if signal["DIRECTION"] == "SINK" else "inout") 
        elif len(name) == 3:
            assert name[2] in io["SIGNALS"].keys(), f"Signal \"{name[2]}\" is not a valid external io port"
            signal["INTERFACE_TYPE"] = io["INTERFACE_TYPE"]
            signal["SIGNAL"] = name[2]
            signal["DIRECTION"] = self.get_signal_direction(io["INTERFACE_TYPE"], io["DIRECTION"], name[2])
            signal["WIDTH"] = str(io["SIGNALS"][name[2]]["WIDTH"])
            signal["IO_DIRECTION"] = "input" if signal["DIRECTION"] == "SOURCE" else ("output" if signal["DIRECTION"] == "SINK" else "inout") 
            signal["NAME"] += "_" + name[2]
        return signal

    def decode_internal_signal(self, name):
        # placeholder function, not actually needed
        signal = {}
        namespace = name[0]
        signal["NAMESPACE"] = namespace    
        signal["NAME"] = "internal_" 
        if name[1] == "CUSTOM":
            signal["NAME"] += self.decode_custom_signal(name[1:])["NAME"]
        elif name[1] == "BOARD":
            signal["NAME"] += self.decode_board_signal(name[1:])["NAME"]
        elif name[1] == "MODULE":
            signal["NAME"] += self.decode_module_signal(name[1:])["NAME"]
        else:
            assert 0, f"\"{name[1]}\" is not a valid namespace for internal signals"
        return signal

    def decode_buscontention_signal(self, name):
        signal = {}
        namespace = name[0]
        signal["NAMESPACE"] = namespace  
        signal["HANDSHAKE"] = name[1]
        signal["SIGNAL"] = self.decode_module_signal(name[2:])
        signal["NAME"] = "bus_contention_" + name[1] + "_" + self.decode_module_signal(name[2:])["NAME"]
        return signal


    def decode_signal(self, name):
        signal = {}
        namespace = name.split(":")[0]
        if namespace == "CONSTANT":
            signal =  self.decode_constant_signal(name.split(":"))
        elif namespace == "CUSTOM":
            signal =  self.decode_custom_signal(name.split(":"))
        elif namespace == "PARAMETER":
            signal =  self.decode_parameter_signal(name.split(":"))
        elif namespace == "BOARD":
            signal =  self.decode_board_signal(name.split(":"))
        elif namespace == "MODULE":
            signal =  self.decode_module_signal(name.split(":"))
        elif namespace == "INTERNAL":
            signal =  self.decode_internal_signal(name.split(":"))
        elif namespace == "SYSTEM":
            signal =  self.decode_system_signal(name.split(":"))
        elif namespace == "BUSCONTENTION":
            signal =  self.decode_buscontention_signal(name.split(":"))
        elif str(name).isnumeric():
            signal["NAME"] =  str(name)
        else:
            assert 0, f"\"{namespace}\" is not a valid namespace"
        signal["REFERENCE"] = name
        return signal
    
    def anchors(self):
        """Path anchors usable in system.tml. Deliberately explicit rather than
        relative `../` counting, which is what silently broke when this tree was
        vendored into a consuming project."""
        return {
            "${PROJECT_ROOT}": self.project_root,
            "${DISL_ROOT}": self.disl_root,
            "${EXAMPLE_DIR}": self.system_dir,
        }

    def prebuild_effective(self, step):
        """The values a PREBUILD step will actually be invoked with.

        DIR plus every VARS entry, with any --prebuild-var override applied on
        top. Computed independently of whether the step actually runs, because
        --skip-prebuild must still resolve a ${PREBUILD:...} reference to the
        same path the step would have produced.
        """
        spec = (self.system.get("PREBUILD") or {}).get(step)
        if spec is None:
            known = ", ".join((self.system.get("PREBUILD") or {}).keys()) or "(none)"
            raise ValueError(f"${{PREBUILD:{step}:...}} names no such step. "
                             f"Declared steps: {known}")
        values = {}
        if spec.get("DIR"):
            values["DIR"] = self.resolve_path(spec["DIR"])
        for k, v in (spec.get("VARS") or {}).items():
            values[k] = str(v)
        values.update(self.prebuild_vars.get(step) or {})   # CLI wins
        return values

    def expand(self, raw):
        """Substitute path anchors in a string, failing on an unknown one.

        Besides the plain path anchors there is ${PREBUILD:<step>:<NAME>}, which
        resolves to what that PREBUILD step will be invoked with -- its DIR or
        any of its VARS, after --prebuild-var overrides. That lets a MEM_INIT
        path be *derived* from the step that produces the file instead of
        repeating it, so the two cannot drift apart. Without it, changing which
        firmware a system builds means editing two places, and editing only one
        silently loads a stale image.
        """
        out = str(raw)
        for token, value in self.anchors().items():
            out = out.replace(token, value)
        for m in set(re.findall(r"\$\{PREBUILD:([^:}]+):([^}]+)\}", out)):
            step, key = m
            values = self.prebuild_effective(step)
            if key not in values:
                raise ValueError(
                    f"${{PREBUILD:{step}:{key}}}: step '{step}' has no '{key}'. "
                    f"Available: {', '.join(sorted(values)) or '(none)'}")
            out = out.replace(f"${{PREBUILD:{step}:{key}}}", values[key])
        if "${" in out:
            raise ValueError(
                f"unresolved anchor in system.tml value: {out}\n"
                f"  known anchors: {', '.join(self.anchors().keys())}, "
                f"${{PREBUILD:<step>:<NAME>}}")
        return out

    def resolve_path(self, raw):
        """Expand anchors and make absolute (relative paths resolve against the
        example directory, not the CWD)."""
        out = self.expand(raw)
        return os.path.abspath(out if os.path.isabs(out)
                                else os.path.join(self.system_dir, out))

    def emit_address_map_header(self):
        """Emit / verify a C header for the RISC-V address map from [ADDRESS_MAP_HEADER].

        The problem this solves: the same address map has to be known by both the
        hardware (which disl-core generates from [INSTANTIATIONS.<cpu>.MAP]) and the
        C firmware (which historically had its own hand-maintained
        riscv_subsystem/config/address_map.h). Nothing connected the two, so they
        could silently drift apart.

            [ADDRESS_MAP_HEADER]
                MODE     = "off" | "check" | "generate"
                STRICT   = false          # check: also fail on one-sided entries
                INSTANCE = "cpu"          # whose MAP to read
                PATH     = "${PROJECT_ROOT}/.../riscv_subsystem/config/address_map.h"
                [ADDRESS_MAP_HEADER.NAMES]
                    cache = "MEM"         # hardware MAP key -> C macro name
                    debug = "UART"
                [ADDRESS_MAP_HEADER.EXTRA]
                    CONFIG = "0x80000000" # in the C header but not in the hardware MAP

        off      (default) do nothing -- fully backward compatible
        check    generate, compare against PATH, and FAIL on any difference
        generate generate and overwrite PATH so the firmware compiles against
                 the hardware's map (this dirties that file's working tree)

        A copy always goes to <build_dir>/gen/address_map.h for provenance.

        NAMES matters more than it looks: a MAP key called `debug` would otherwise
        emit `#define DEBUG 0x...`, colliding with the DEBUG build flag the firmware
        already uses. Mapping it to UART -- which is what that address actually is --
        avoids that.
        """
        spec = self.system.get("ADDRESS_MAP_HEADER")
        if not spec:
            return
        mode = str(spec.get("MODE", "off")).lower()
        if mode == "off":
            return
        if mode not in ("check", "generate"):
            raise ValueError(f"ADDRESS_MAP_HEADER.MODE must be off/check/generate, got '{mode}'")

        instance = spec.get("INSTANCE")
        if not instance:
            raise ValueError("ADDRESS_MAP_HEADER needs INSTANCE (which instantiation's MAP to use)")
        if instance not in self.system["INSTANTIATIONS"]:
            raise ValueError(f"ADDRESS_MAP_HEADER.INSTANCE '{instance}' is not an instantiation")
        amap = self.system["INSTANTIATIONS"][instance].get("MAP")
        if not amap:
            raise ValueError(f"instantiation '{instance}' has no MAP table")

        names = spec.get("NAMES", {}) or {}
        extra = spec.get("EXTRA", {}) or {}

        defines = {}
        for key, entry in amap.items():
            macro = names.get(key, key.upper())
            defines[macro] = entry["ORIGIN"]
        for macro, value in extra.items():
            defines[macro] = value

        guard = "DISL_GENERATED_ADDRESS_MAP_H"
        body = ["// Generated by disl-core from " + f"[INSTANTIATIONS.{instance}.MAP]" + " in system.tml.",
                "// Do not edit by hand -- change the MAP in system.tml instead, so the",
                "// hardware and this header cannot drift apart.",
                "",
                f"#ifndef {guard}",
                f"#define {guard}",
                ""]
        width = max((len(m) for m in defines), default=1)
        for macro in defines:
            body.append(f"#define  {macro.ljust(width)}  {defines[macro]}")
        # Include guard: this header is pulled in from more than one place
        # (riscv_subsystem/sw/utils.h and the firmware's own board.h), and the
        # generated file must be safe to include twice.
        body.append("")
        body.append(f"#endif  // {guard}")
        body.append("")
        generated = "\n".join(body)

        gen_dir = os.path.join(self.build_dir, "gen")
        os.makedirs(gen_dir, exist_ok=True)
        with open(os.path.join(gen_dir, "address_map.h"), "w") as f:
            f.write(generated)

        raw_path = spec.get("PATH")
        if not raw_path:
            print(f"ADDRESS_MAP_HEADER: wrote {gen_dir}/address_map.h (no PATH given, nothing compared)")
            return
        target = self.resolve_path(raw_path)

        def parse_defines(text):
            found = {}
            for line in text.splitlines():
                parts = line.split()
                if len(parts) >= 3 and parts[0] == "#define":
                    found[parts[1]] = parts[2]
            return found

        def as_int(token):
            """Parse a C integer literal, or None if it is not a plain one.

            Returns None rather than raising for things like `(1<<3)`, a macro
            referencing another macro, or anything else a real C header may
            legitimately contain -- a header *checker* must not crash on a
            define it was never asked to compare. int(.., 0) accepts 0x/0o/0b
            and decimal; C integer suffixes are stripped first."""
            try:
                return int(str(token).rstrip("uUlL"), 0)
            except (ValueError, TypeError):
                return None

        if mode == "generate":
            existing = open(target).read() if os.path.isfile(target) else None
            if existing == generated:
                print(f"ADDRESS_MAP_HEADER: {target} already matches the hardware map")
            else:
                with open(target, "w") as f:
                    f.write(generated)
                print(f"ADDRESS_MAP_HEADER: WROTE {target} from [INSTANTIATIONS.{instance}.MAP]")
                print( "  note: this modifies that file in its own repository's working tree")
            return

        # mode == "check"
        if not os.path.isfile(target):
            raise FileNotFoundError(
                f"ADDRESS_MAP_HEADER.MODE=check but the header does not exist:\n  {target}")
        have = parse_defines(open(target).read())
        want = parse_defines(generated)

        # Severity split. A macro defined on both sides with DIFFERENT addresses is
        # the dangerous case -- hardware and software disagreeing silently -- and
        # always fails. An entry present on only one side usually just means the C
        # code does not use that peripheral (or uses a different addressing scheme
        # through the crossbar), so it warns unless STRICT is set.
        strict = bool(spec.get("STRICT", False))
        conflicts, gaps, unparsed = [], [], []
        for macro, value in want.items():
            if macro not in have:
                gaps.append(f"  {macro}: in the hardware map ({value}) but not defined in the header")
                continue
            lhs, rhs = as_int(have[macro]), as_int(value)
            if lhs is None or rhs is None:
                # Compared by value, not by spelling -- but only when both sides
                # actually are integer literals.
                unparsed.append(f"  {macro}: not a plain integer literal on one side "
                                 f"(header={have[macro]}, map={value}) -- not compared")
            elif lhs != rhs:
                conflicts.append(f"  {macro}: hardware map says {value}, header says {have[macro]}")
        for macro in have:
            if macro not in want:
                gaps.append(f"  {macro}: defined in the header ({have[macro]}) but not in the hardware map"
                             f" -- add it under [ADDRESS_MAP_HEADER.EXTRA] if intentional")

        if conflicts or (strict and gaps):
            raise ValueError(
                "ADDRESS_MAP_HEADER.MODE=check found the C header and the hardware address map "
                f"out of sync.\n  header : {target}\n  map    : [INSTANTIATIONS.{instance}.MAP]\n"
                + "\n".join(conflicts + (gaps if strict else []))
                + "\n  Fix system.tml or the header, or set MODE=\"generate\" to overwrite the header.")

        for u in unparsed:
            print(f"WARNING: ADDRESS_MAP_HEADER:{u}")
        if gaps:
            print(f"ADDRESS_MAP_HEADER: check -- no address conflicts, but {len(gaps)} entr(y/ies) "
                  f"exist on only one side (set STRICT = true to make this fail):")
            for g in gaps:
                print(f"WARNING: {g}")
        shared = len(set(have) & set(want))
        print(f"ADDRESS_MAP_HEADER: check OK -- {shared} shared entr(y/ies) agree between "
              f"{os.path.basename(target)} and [INSTANTIATIONS.{instance}.MAP]")

    def run_prebuild(self, skip=False):
        """Run the build steps declared in [PREBUILD.<name>] before generating anything.

        This is what lets one `configure.py` invocation build the firmware AND the
        system, instead of requiring the firmware to be built by hand first. It is
        deliberately generic -- disl-core learns "run these declared commands",
        not anything about RISC-V, make targets or eBPF:

            [PREBUILD.riscv_firmware]
                DIR      = "${PROJECT_ROOT}/.../fw/vebpf_network_packet_processing"
                COMMAND  = "make"
                ARGS     = ["APP=vebpf_firewall_sim"]
                VARS     = { SIMULATION_TESTING = 1, DEBUG = 0 }
                OPTIONAL = false

        VARS are appended as NAME=VALUE arguments, which is how the firmware
        Makefile takes its SIMULATION_TESTING / DEBUG flags -- so a system.tml can
        select simulation-vs-synthesis firmware behaviour alongside everything else
        it already describes.

        OPTIONAL = true downgrades a missing tool or a failed step to a warning, so
        someone without (say) a RISC-V toolchain can still generate and synthesize a
        design whose memory images already exist. If a MEM_INIT then depends on a
        missing output, that fails loudly with a clear message anyway.
        """
        spec = self.system.get("PREBUILD")
        if not spec:
            return
        if skip:
            print(f"PREBUILD: skipping {len(spec)} step(s) (--skip_prebuild)")
            return

        for name, step in spec.items():
            command = step.get("COMMAND")
            if not command:
                raise ValueError(f"PREBUILD.{name} has no COMMAND")
            optional = bool(step.get("OPTIONAL", False))
            workdir = self.resolve_path(step["DIR"]) if step.get("DIR") else os.getcwd()

            if not os.path.isdir(workdir):
                msg = f"PREBUILD.{name}: DIR does not exist: {workdir}"
                if optional:
                    print(f"WARNING: {msg} -- skipping (OPTIONAL)"); continue
                raise FileNotFoundError(msg)

            if shutil.which(command) is None:
                msg = (f"PREBUILD.{name}: '{command}' not found on PATH."
                        f" Is the required toolchain installed?")
                if optional:
                    print(f"WARNING: {msg} -- skipping (OPTIONAL)"); continue
                raise FileNotFoundError(msg)

            argv = [command]
            argv += [self.expand(a) for a in (step.get("ARGS") or [])]
            # Built from the same effective-values table that ${PREBUILD:...}
            # resolves against, so what a step is invoked with and what a MEM_INIT
            # path derives from can never disagree. A CLI override REPLACES the
            # declared value rather than being appended after it -- `make` would
            # honour a duplicate NAME=VALUE either way, but a command line showing
            # the same variable twice is a poor thing to have to read in a log.
            _effective = self.prebuild_effective(name)
            argv += [f"{k}={v}" for k, v in _effective.items() if k != "DIR"]

            print(f"PREBUILD.{name}: {' '.join(argv)}   (cwd={workdir})")
            # argv list, never shell=True -- a config file should not be able to
            # inject shell syntax.
            rc = subprocess.call(argv, cwd=workdir)
            if rc != 0:
                msg = f"PREBUILD.{name} failed with exit code {rc}"
                if optional:
                    print(f"WARNING: {msg} -- continuing (OPTIONAL)"); continue
                raise RuntimeError(msg)
            print(f"PREBUILD.{name}: ok")

    def resolve_mem_init(self):
        """Resolve, stage and parameterize every [INSTANTIATIONS.<inst>.MEM_INIT.<PARAM>] block.

        Motivation: memory images (RISC-V firmware, compiled eBPF rules)
        used to be named by hardcoded relative paths inside the RTL itself
        -- paths that encoded one particular repository layout and silently
        resolved into a different checkout once the project moved. Declaring
        them here instead means the path is (a) visible in the system config
        rather than buried in a `$readmemh` call, (b) resolved against an
        explicit anchor rather than by counting `../` levels, and (c) usable
        by BOTH simulation and synthesis, unlike $value$plusargs which only
        exists at simulator runtime.

        For each block:
          FILE          path, may use ${PROJECT_ROOT} / ${DISL_ROOT} / ${EXAMPLE_DIR}
          PAD_TO_DEPTH  optional bool: zero-fill up to DEPTH_WORDS
          DEPTH_WORDS   required when padding: the depth the RTL declares
          WORD_BITS     required when padding: bits per word (32, 64, ...)

        The resolved file is copied into <build_dir>/mem/ so the build
        directory is self-contained and archivable, and the *absolute* path
        of that staged copy is injected as the named Verilog parameter.
        Absolute, because the simulator runs from <build_dir>/tb_cocotb/
        while Vivado synthesis runs from <build_dir>/<example>/<example>.runs/synth_1/
        -- no single relative path is correct for both.
        """
        anchors = self.anchors()
        mem_dir = os.path.join(self.build_dir, "mem")
        manifest = {"anchors": anchors, "images": []}

        for instance_name in self.system["INSTANTIATIONS"].keys():
            spec = self.system["INSTANTIATIONS"][instance_name].get("MEM_INIT")
            if not spec:
                continue
            for parameter, entry in spec.items():
                raw = entry.get("FILE")
                if not raw:
                    raise ValueError(
                        f"MEM_INIT for instance '{instance_name}' parameter "
                        f"'{parameter}' has no FILE field")

                # One substitution implementation, shared with everything else in
                # this file. This block used to re-implement it, which meant the
                # ${PREBUILD:<step>:<NAME>} anchor -- the thing that keeps a
                # MEM_INIT path and the step that produces the file from drifting
                # -- resolved everywhere except here, the one place it matters.
                try:
                    resolved = self.resolve_path(raw)
                except ValueError as exc:
                    raise ValueError(
                        f"MEM_INIT FILE for '{instance_name}.{parameter}': {exc}")

                # Fail loudly. Previously a missing memory image produced only a
                # mid-simulation $readmemh warning that was easy to miss entirely.
                if not os.path.isfile(resolved):
                    raise FileNotFoundError(
                        f"MEM_INIT file for '{instance_name}.{parameter}' does not exist.\n"
                        f"  declared : {raw}\n"
                        f"  resolved : {resolved}\n"
                        f"  ${{PROJECT_ROOT}} = {self.project_root}\n"
                        f"  ${{DISL_ROOT}}    = {self.disl_root}\n"
                        f"  ${{EXAMPLE_DIR}}  = {self.system_dir}\n"
                        f"  If this is firmware or a rule set, build it first.")

                os.makedirs(mem_dir, exist_ok=True)
                staged = os.path.join(mem_dir, f"{instance_name}.{parameter}.hex")

                words = []
                with open(resolved) as src:
                    for line in src:
                        stripped = line.split("//", 1)[0].split()
                        words.extend(stripped)

                if entry.get("PAD_TO_DEPTH"):
                    depth = entry.get("DEPTH_WORDS")
                    word_bits = entry.get("WORD_BITS")
                    if not depth or not word_bits:
                        raise ValueError(
                            f"MEM_INIT for '{instance_name}.{parameter}' sets PAD_TO_DEPTH "
                            f"but is missing DEPTH_WORDS and/or WORD_BITS")
                    if len(words) > depth:
                        raise ValueError(
                            f"MEM_INIT file for '{instance_name}.{parameter}' has {len(words)} "
                            f"words, more than the declared DEPTH_WORDS={depth}:\n  {resolved}")
                    zero = "0" * (word_bits // 4)
                    padding = depth - len(words)
                    words.extend([zero] * padding)
                    if self.build_verbose or padding:
                        print(f"MEM_INIT {instance_name}.{parameter}: {len(words) - padding} words "
                              f"from {os.path.basename(resolved)}, zero-padded to {depth}")
                else:
                    print(f"MEM_INIT {instance_name}.{parameter}: {len(words)} words "
                          f"from {os.path.basename(resolved)} (not padded)")

                with open(staged, "w") as dst:
                    dst.write("\n".join(words) + "\n")

                self.params.setdefault(instance_name, {})[parameter] = os.path.abspath(staged)
                manifest["images"].append({
                    "instance": instance_name,
                    "parameter": parameter,
                    "declared": raw,
                    "source": resolved,
                    "staged": os.path.abspath(staged),
                    "words": len(words),
                    "padded_to_depth": bool(entry.get("PAD_TO_DEPTH")),
                    "depth_words": entry.get("DEPTH_WORDS"),
                    "word_bits": entry.get("WORD_BITS"),
                })

        # Provenance record: exactly which file on disk each image came from, so
        # a later check can verify the declared path resolved where it was meant
        # to rather than into some other checkout that happened to be present.
        if manifest["images"]:
            with open(os.path.join(mem_dir, "manifest.json"), "w") as f:
                json.dump(manifest, f, indent=2)

    # this function runs all the evaluate functions
    def generate_parameters(self):
        self.params = {}
        for instance_name in self.system["INSTANTIATIONS"].keys():
            module = self.system["INSTANTIATIONS"][instance_name]["MODULE"]
            func = getattr(self, "evaluate_independent_parameters")
            self.params[instance_name] = func(instance_name, module)
            if hasattr(self, "evaluate_" + module):
                func = getattr(self, "evaluate_" + module)
                self.params[instance_name] = func(instance_name, self.params[instance_name])
        self.resolve_mem_init()
        with open(self.build_dir + "/parameters.vh",'w') as f:
            for instance_name in self.params.keys():
                for parameter in self.params[instance_name].keys():
                    f.write("parameter PARAMETER_" + instance_name.upper() + "_" + parameter + " = " + verilog_literal(self.params[instance_name][parameter]) + ";\n")
    
    def instantiate_signal(self, signal):
        declaration = ""
        #if signal["WIDTH"].isnumeric():
        if signal["NAMESPACE"] == "BOARD":
            declaration = signal["IO_DIRECTION"] + " "
            if not signal["WIDTH"].isnumeric():
                declaration += "[" + signal["WIDTH"] + "-1:0] "
            else:
                if int(signal["WIDTH"]) > 1:
                    declaration += "[" 
                    declaration += str(int(signal["WIDTH"])-1)
                    declaration += ":0] "
        elif signal["NAMESPACE"] == "MODULE":
            declaration = "wire "
            if not signal["WIDTH"].isnumeric():
                declaration += "[" + signal["WIDTH"] + "-1:0] "
            else:
                if int(signal["WIDTH"]) > 1:
                    declaration += "[" 
                    declaration += str(int(signal["WIDTH"])-1)
                    declaration += ":0] "
        elif signal["NAMESPACE"] == "BUSCONTENTION":
            declaration = "wire "
            if not signal["SIGNAL"]["WIDTH"].isnumeric():
                declaration += "[" + signal["SIGNAL"]["WIDTH"] + "-1:0] "
            else:
                if int(signal["SIGNAL"]["WIDTH"]) > 1:
                    declaration += "[" 
                    declaration += str(int(signal["SIGNAL"]["WIDTH"])-1)
                    declaration += ":0] "
        else:
            assert 0, "\"" + signal["NAMESPACE"] + "\" is not a supported namespace for instantiations"
        declaration += signal["NAME"] +";"
        return declaration


    def generate_top(self):
        # Define top module interface
        self.verilog.append("module " + self.top + " (")
        external_io = []
        for io in self.system["EXTERNAL_IO"]["PORTS"]:
            if "WIDTH" in self.board["IO"][io].keys():
                external_io.append(io)
            else:
                for bus in self.board["IO"][io]["SIGNALS"].keys():
                    external_io.append(io + "_" + bus)
        self.verilog.append(",".join(external_io))
        self.verilog.append(");")
        
        # Generate parameters and write to verilog header file
        self.generate_parameters()
        self.verilog.append("`include \"parameters.vh\"")

        # Instantiate ports
        for io in self.system["EXTERNAL_IO"]["PORTS"]:
            if "WIDTH" in self.board["IO"][io].keys():
                self.verilog.append(self.instantiate_signal(self.decode_signal("BOARD:" + io)))
            else:
                for io_signal in self.board["IO"][io]["SIGNALS"].keys():
                    self.verilog.append(self.instantiate_signal(self.decode_signal("BOARD:" + io + ":" + io_signal)))
        
        # Declare module signals
        for instance in self.system["INSTANTIATIONS"].keys():
            module = self.system["INSTANTIATIONS"][instance]["MODULE"]
            self.verilog.append("//" + instance + f"\t({module})")
            for interface in self.modules[module]["INTERFACES"].keys():
                protocol = self.modules[module]["INTERFACES"][interface]["TYPE"]
                if protocol in ["GENERAL","CLOCK"]:
                    self.verilog.append(self.instantiate_signal(self.decode_signal("MODULE:" + instance + ":" + interface)))
                elif protocol in self.definitions["PROTOCOLS"].keys():
                    for sig in self.definitions["PROTOCOLS"][protocol]["WIDTHS"].keys():
                        self.verilog.append(self.instantiate_signal(self.decode_signal("MODULE:" + instance + ":" + interface + ":" + sig)))
                else:
                    assert 0, f"\"{protocol}\" is not a valid interface type"
            self.verilog.append("\n")
        self.verilog.append("\n")

        # Declare intrinsics signals
        for intrinsic_type in self.system["INTRINSICS"].keys():
            for intrinsic in self.system["INTRINSICS"][intrinsic_type]:
                template = self.definitions["INTRINSICS"][intrinsic_type]
                for param in intrinsic.keys():
                    value =  intrinsic[param]
                    if ":" in str(value):
                        value = self.decode_signal(value)["NAME"]
                    template = template.replace("%{"+param+"}",str(value))
                self.verilog.append(template)
        self.verilog.append("\n")

        # Generate static connections - only valid between interfaces with the same protocol
        for connections in self.system["INTERCONNECT"]["STATIC"]:
            # find the source
            source = []
            for connection in connections:
                signal = self.decode_signal(connection)
                if signal["DIRECTION"] == "SOURCE":
                    source.append(signal)
            assert len(source) == 1, "The static connection " + str(connections) + " is invalid - " + ("too many sources" if len(source) else "no sources")
            source = source[0]
            for connection in connections:
                if source["REFERENCE"] == connection: continue
                if source["SIGNAL"]: # this is one or more signal-signal connections
                    sink = self.decode_signal(connection)
                    assert sink["SIGNAL"], "Cannot connect a signal " + source["REFERENCE"] + " with an interface " + sink["REFERENCE"] + " in interconnect " + str(connections)
                    self.verilog.append("assign " + sink["NAME"] + " = " + source["NAME"] + ";")
                else:    # this is one or more interface-interface connections
                    sink = self.decode_signal(connection)
                    assert sink["INTERFACE_TYPE"] == source ["INTERFACE_TYPE"], "Inteface type mismatch between " + source["REFERENCE"] + " and " + sink["REFERENCE"]+ " in interconnect " + str(connections)
                    interface_signals = self.definitions["PROTOCOLS"][source["INTERFACE_TYPE"]]["WIDTHS"].keys()
                    for sig in interface_signals: # might need to revisit this for handing BIDIR signals
                        source_signal = self.decode_signal(source["REFERENCE"] + ":" + sig)
                        sink_signal = self.decode_signal(sink["REFERENCE"] + ":" + sig)
                        assert (sink_signal["DIRECTION"] !=  "SOURCE") or (len(connections) <= 2), "Multiple SINK interfaces in " + str(connections) + " have a SOURCE signal"
                        if sink_signal["DIRECTION"] ==  "SOURCE":
                            self.verilog.append("assign " + source_signal["NAME"] + " = " + sink_signal["NAME"] + ";")
                        else:
                            self.verilog.append("assign " + sink_signal["NAME"] + " = " + source_signal["NAME"] + ";")
        self.verilog.append("\n")

        # Decode dynamic connections
        self.interconnects["INTERFACES"] = {}
        self.interconnects["CONNECTIVITY"] = {}
        self.interconnects["CONNECTIVITY"]["SINKS"] = {}
        for interface in self.system["INTERCONNECT"]["DYNAMIC"].keys():
            group_select = self.system["INTERCONNECT"]["DYNAMIC"][interface]["GROUP_SELECT"]
            groups = self.system["INTERCONNECT"]["DYNAMIC"][interface]["GROUPS"]
            interface_type = self.decode_signal(interface)["INTERFACE_TYPE"]
            self.interconnects["INTERFACES"][interface] = {}
            for handshake in self.system["INTERCONNECT"]["DYNAMIC"][interface]["HANDSHAKES"]:
                self.interconnects["INTERFACES"][interface][handshake] = {}
                frame = []
                for sig in self.definitions["PROTOCOLS"][interface_type]["HANDSHAKES"][handshake]["FRAME"]:
                    frame.append(interface + ":" + str(sig))
                valid = str(self.definitions["PROTOCOLS"][interface_type]["HANDSHAKES"][handshake]["VALID"])
                if valid not in ["0", "1", ""]:
                    valid = interface + ":" + str(valid)
                ready = str(self.definitions["PROTOCOLS"][interface_type]["HANDSHAKES"][handshake]["READY"])
                if ready not in ["0", "1", ""]:
                    ready = interface + ":" + str(ready)
                self.interconnects["INTERFACES"][interface][handshake]["FRAME"] = frame
                self.interconnects["INTERFACES"][interface][handshake]["VALID"] = valid
                self.interconnects["INTERFACES"][interface][handshake]["READY"] = ready 
                if self.decode_signal(interface)["DIRECTION"] == "SOURCE" and self.definitions["PROTOCOLS"][interface_type]["HANDSHAKES"][handshake]["DIRECTION"] == "REQUEST":
                    self.interconnects["INTERFACES"][interface][handshake]["DIRECTION"] =  "SOURCE"
                elif self.decode_signal(interface)["DIRECTION"] == "SINK" and self.definitions["PROTOCOLS"][interface_type]["HANDSHAKES"][handshake]["DIRECTION"] == "REQUEST":
                    self.interconnects["INTERFACES"][interface][handshake]["DIRECTION"] =  "SINK"
                elif self.decode_signal(interface)["DIRECTION"] == "SOURCE" and self.definitions["PROTOCOLS"][interface_type]["HANDSHAKES"][handshake]["DIRECTION"] == "RESPONSE":
                    self.interconnects["INTERFACES"][interface][handshake]["DIRECTION"] =  "SINK"
                else:
                    self.interconnects["INTERFACES"][interface][handshake]["DIRECTION"] =  "SOURCE"

        for interface in self.interconnects["INTERFACES"].keys():
            self.interconnects["CONNECTIVITY"]["SINKS"][interface] = {}
            for handshake in self.interconnects["INTERFACES"][interface].keys():
                if self.interconnects["INTERFACES"][interface][handshake]["DIRECTION"] == "SINK":
                    self.interconnects["CONNECTIVITY"]["SINKS"][interface][handshake] = []
                    groups = self.system["INTERCONNECT"]["DYNAMIC"][interface]["GROUPS"]
                    group_select = self.system["INTERCONNECT"]["DYNAMIC"][interface]["GROUP_SELECT"] if (len(groups) > 1) else "1'b1"   
                    for group in groups:
                        if group["INTERCONNECT_TYPE"] == "ONE_TO_ONE":
                            select = "(" + group_select + ")" if (group_select == "1'b1") else "(" + self.decode_signal(group_select)["NAME"]  + " == " + str(group["SELECT_VALUE"]) + ")"
                            source = group["INTERFACE"]
                            source_groups = self.system["INTERCONNECT"]["DYNAMIC"][source]["GROUPS"]
                            source_group_select = self.system["INTERCONNECT"]["DYNAMIC"][source]["GROUP_SELECT"] if (len(source_groups) > 1) else "1'b1"      
                            for source_group in source_groups:
                                if source_group["INTERCONNECT_TYPE"] == "ONE_TO_ONE":
                                    if source_group["INTERFACE"] == interface:
                                        connectivity = {}
                                        connectivity["SELECT"] = select + ("" if  (source_group_select == "1'b1") else (" && (" + self.decode_signal(source_group_select)["NAME"]  + " == " + str(source_group["SELECT_VALUE"]) + ") "))
                                        connectivity["SOURCE"] = source
                                        self.interconnects["CONNECTIVITY"]["SINKS"][interface][handshake].append(connectivity)
                                elif source_group["INTERCONNECT_TYPE"] == "ONE_TO_MANY":
                                    source_select_signal = ""
                                    for source_handshake_map in source_group["HANDSHAKE_MAP"]:
                                        if source_handshake_map.split(" ")[0] == handshake:
                                            source_select_signal = source_handshake_map.split(" ")[1]
                                    assert source_select_signal, "Could not find a valid select signal for handshake " + handshake + " for interface " + source
                                    for source_address_map in source_group["ADDRESS_MAP"]:
                                        if interface == source_address_map.split(" ")[1]:
                                            connectivity = {}
                                            connectivity["SELECT"] = select + " && (" + self.decode_signal(source_select_signal)["NAME"]  + " >= " + self.decode_signal(source_address_map.split(" ")[0] + ".ORIGIN")["NAME"] + ") && (" + self.decode_signal(source_select_signal)["NAME"]  + " < (" + self.decode_signal(source_address_map.split(" ")[0] + ".ORIGIN")["NAME"] + "+" + self.decode_signal(source_address_map.split(" ")[0] + ".LENGTH")["NAME"] + "))"
                                            connectivity["SOURCE"] = source
                                            self.interconnects["CONNECTIVITY"]["SINKS"][interface][handshake].append(connectivity) 
                                else:
                                    assert 0, "Unsupport interconnect type: " + source_group["INTERCONNECT_TYPE"]
                        elif group["INTERCONNECT_TYPE"] == "ONE_TO_MANY":
                            select_signal = ""
                            for handshake_map in group["HANDSHAKE_MAP"]:
                                if handshake_map.split(" ")[0] == handshake:
                                    select_signal = handshake_map.split(" ")[1]
                            assert select_signal, "Could not find a valid select signal for handshake " + handshake + " for interface " + interface
                            for address_map in group["ADDRESS_MAP"]:
                                source = address_map.split(" ")[1]
                                select = "(" + group_select + ")" if (group_select == "1'b1") else "(" + self.decode_signal(group_select)["NAME"] + " == " + str(group["SELECT_VALUE"]) + ")"
                                select = select + " && (" + self.decode_signal(select_signal)["NAME"] + " >= " + self.decode_signal(address_map.split(" ")[0] + ".ORIGIN")["NAME"] + ") && (" + self.decode_signal(select_signal)["NAME"]  + " < (" + self.decode_signal(address_map.split(" ")[0] + ".ORIGIN")["NAME"] + "+" + self.decode_signal(address_map.split(" ")[0] + ".LENGTH")["NAME"] + "))"
                                # print(f"Printing source = {source}")
                                # print(f"Printing address_map  in group[ADDRESS_MAP] = {address_map}")
                                source_groups = self.system["INTERCONNECT"]["DYNAMIC"][source]["GROUPS"]
                                # print(f"Printing source_groups = {source_groups}")
                                source_group_select = self.system["INTERCONNECT"]["DYNAMIC"][source]["GROUP_SELECT"] if (len(source_groups) > 1) else "1'b1"      
                                for source_group in source_groups:
                                    if source_group["INTERCONNECT_TYPE"] == "ONE_TO_ONE":
                                        connectivity = {}
                                        connectivity["SELECT"] = select
                                        connectivity["SOURCE"] = source
                                        self.interconnects["CONNECTIVITY"]["SINKS"][interface][handshake].append(connectivity)
                                    elif source_group["INTERCONNECT_TYPE"] == "ONE_TO_MANY":
                                        source_select_signal = ""
                                        for source_handshake_map in source_group["HANDSHAKE_MAP"]:
                                            if source_handshake_map.split(" ")[0] == handshake:
                                                source_select_signal = source_handshake_map.split(" ")[1]
                                        assert source_select_signal, "Could not find a valid select signal for handshake " + handshake + " for interface " + source
                                        for source_address_map in source_group["ADDRESS_MAP"]:
                                            if interface == source_address_map.split(" ")[1]:
                                                connectivity = {}
                                                connectivity["SELECT"] = select + " && (" + self.decode_signal(source_select_signal)["NAME"] + " >= " + self.decode_signal(source_address_map.split(" ")[0] + ".ORIGIN")["NAME"] + ") && (" + self.decode_signal(source_select_signal)["NAME"]  + " < (" + self.decode_signal(source_address_map.split(" ")[0] + ".ORIGIN")["NAME"] + "+" + self.decode_signal(source_address_map.split(" ")[0] + ".LENGTH")["NAME"] + "))"
                                                connectivity["SOURCE"] = source
                                                self.interconnects["CONNECTIVITY"]["SINKS"][interface][handshake].append(connectivity) 
                                    else:
                                        # print(f"\nHELLO this is being printed :3\n")
                                        assert 0, "Unsupport interconnect type: " + source_group["INTERCONNECT_TYPE"]
                        else:
                            assert 0, "Unsupport interconnect type: " + group["INTERCONNECT_TYPE"]
        
        self.interconnects["CONNECTIVITY"]["SOURCES"] = {}
        for interface in self.interconnects["CONNECTIVITY"]["SINKS"].keys():
            for handshake in self.interconnects["CONNECTIVITY"]["SINKS"][interface].keys():
                for connection in self.interconnects["CONNECTIVITY"]["SINKS"][interface][handshake]:
                    source = connection["SOURCE"]
                    if source.split(":")[0] != "MODULE": continue
                    if source not in self.interconnects["CONNECTIVITY"]["SOURCES"].keys():
                        self.interconnects["CONNECTIVITY"]["SOURCES"][source] = {}
                    if handshake not in self.interconnects["CONNECTIVITY"]["SOURCES"][source].keys():
                        self.interconnects["CONNECTIVITY"]["SOURCES"][source][handshake] = []
                    self.interconnects["CONNECTIVITY"]["SOURCES"][source][handshake].append({"SELECT": connection["SELECT"], "SINK": interface})
        
        # Replace contending bus signals for valid and frame   
        for interface in self.interconnects["CONNECTIVITY"]["SINKS"].keys():
            signal_occurances = {}
            for handshake in self.interconnects["CONNECTIVITY"]["SINKS"][interface].keys():
                if handshake not in self.interconnects["INTERFACES"][interface].keys(): continue
                handshake_signals = []
                if self.interconnects["INTERFACES"][interface][handshake]["VALID"]:
                    handshake_signals.append(self.interconnects["INTERFACES"][interface][handshake]["VALID"])
                for frame_signal in self.interconnects["INTERFACES"][interface][handshake]["FRAME"]:
                    if frame_signal:
                        handshake_signals.append(frame_signal)
                for handshake_signal in handshake_signals:        
                    if handshake_signal not in signal_occurances.keys():
                        signal_occurances[handshake_signal] = [handshake]
                    elif handshake in signal_occurances[handshake_signal]:
                        assert 0, f"Handshake {handshake} of Interface {interface} has multiple assignments to the same signal: {handshake_signal}"
                    else:
                        signal_occurances[handshake_signal].append(handshake)
            bus_contentions = {}
            for handshake_signal in signal_occurances.keys():
                if len(signal_occurances[handshake_signal]) == 1: continue
                bus_contentions[handshake_signal] = signal_occurances[handshake_signal]
                for handshake in bus_contentions[handshake_signal]:
                    if self.interconnects["INTERFACES"][interface][handshake]["VALID"] == handshake_signal:
                        self.interconnects["INTERFACES"][interface][handshake]["VALID"] = "BUSCONTENTION:" + handshake + ":" + self.interconnects["INTERFACES"][interface][handshake]["VALID"]
                        self.verilog.append(self.instantiate_signal(self.decode_signal(self.interconnects["INTERFACES"][interface][handshake]["VALID"])))
                    for idx in range(len(self.interconnects["INTERFACES"][interface][handshake]["FRAME"])):
                        if self.interconnects["INTERFACES"][interface][handshake]["FRAME"][idx] == handshake_signal:
                            self.interconnects["INTERFACES"][interface][handshake]["FRAME"][idx] = "BUSCONTENTION:" + handshake + ":" + self.interconnects["INTERFACES"][interface][handshake]["FRAME"][idx]
                            self.verilog.append(self.instantiate_signal(self.decode_signal(self.interconnects["INTERFACES"][interface][handshake]["FRAME"][idx])))
            if bus_contentions:
                self.bus_contentions[interface] = bus_contentions

        # Replace contending bus signals for ready   
        for interface in self.interconnects["CONNECTIVITY"]["SOURCES"].keys():
            signal_occurances = {}
            for handshake in self.interconnects["CONNECTIVITY"]["SOURCES"][interface].keys():
                handshake_signals = []
                if handshake not in self.interconnects["INTERFACES"][interface].keys(): continue
                if self.interconnects["INTERFACES"][interface][handshake]["READY"]:
                    handshake_signal = self.interconnects["INTERFACES"][interface][handshake]["READY"]      
                    if handshake_signal not in signal_occurances.keys():
                        signal_occurances[handshake_signal] = [handshake]
                    elif handshake in signal_occurances[handshake_signal]:
                        assert 0, f"Handshake {handshake} of Interface {interface} has multiple assignments to the same signal: {handshake_signal}"
                    else:
                        signal_occurances[handshake_signal].append(handshake)
            bus_contentions = {}
            for handshake_signal in signal_occurances.keys():
                if len(signal_occurances[handshake_signal]) == 1: continue
                bus_contentions[handshake_signal] = signal_occurances[handshake_signal]
                for handshake in bus_contentions[handshake_signal]:
                    if self.interconnects["INTERFACES"][interface][handshake]["READY"] == handshake_signal:
                        self.interconnects["INTERFACES"][interface][handshake]["READY"] = "BUSCONTENTION:" + handshake + ":" + self.interconnects["INTERFACES"][interface][handshake]["READY"]
                        self.verilog.append(self.instantiate_signal(self.decode_signal(self.interconnects["INTERFACES"][interface][handshake]["READY"])))
            if bus_contentions:
                self.bus_contentions[interface] = bus_contentions

        # resolve bus contentions
        for interface in self.bus_contentions.keys():
            for handshake_signal in self.bus_contentions[interface].keys():
                resolution = ""
                decoded_handshake_signal = self.decode_signal(handshake_signal)
                if decoded_handshake_signal["SIGNAL"] not in self.definitions["PROTOCOLS"][decoded_handshake_signal["INTERFACE_TYPE"]]["BUS_CONTENTION"].keys():
                    assert 0, "No rules found for resolving bus contention for the signal " + decoded_handshake_signal["SIGNAL"] + " in the protocol: " + decoded_handshake_signal["INTERFACE_TYPE"]
                for rule in self.definitions["PROTOCOLS"][decoded_handshake_signal["INTERFACE_TYPE"]]["BUS_CONTENTION"][decoded_handshake_signal["SIGNAL"]]:
                    list1 = rule["HANDSHAKES"]
                    list2 =  self.bus_contentions[interface][handshake_signal]
                    if len(list1) == len(list2):
                        match = 1
                        for item in list1:
                            if item not in list2:
                                match = 0
                                break
                    if match == 0: continue
                    resolution = rule["RESOLUTION"]
                    break
                assert resolution, "Valid rule not defined for resolving bus contention for the signal " + decoded_handshake_signal["SIGNAL"] + " in the protocol: " + decoded_handshake_signal["INTERFACE_TYPE"]
                inputs = []
                variable = ""
                state = 0
                for c in resolution:
                    if c == '%' and state == 0:
                        state = 1
                    elif c == '{' and state == 1:
                        state = 2
                    elif c != "}" and state == 2:
                        variable += c
                    elif c == "}" and state == 2:
                        inputs.append(variable)
                        variable = ""
                        state = 0
                    elif c != "%" and state == 0:
                        continue
                    else:
                        assert 0, f"Incorrect formatting for bus contention resolution rule: {resolution}"
                for variable in inputs:
                    handshake = ""
                    sig = variable
                    if ":" in variable:
                        handshake = variable.split(":")[0]
                        sig = variable.split(":")[1]
                    if handshake == "":
                        resolution = resolution.replace("%{"+variable+"}",self.decode_signal(interface + ":" + sig)["NAME"])
                    else:
                        resolution = resolution.replace("%{"+variable+"}",self.decode_signal("BUSCONTENTION:" + handshake + ":" + interface + ":" + sig)["NAME"])
                self.verilog.append(resolution)

        # Connect valids and frames
        for interface in self.interconnects["CONNECTIVITY"]["SINKS"].keys():
            for handshake in self.interconnects["CONNECTIVITY"]["SINKS"][interface].keys():
                if handshake not in self.interconnects["INTERFACES"][interface].keys(): continue
                if self.interconnects["INTERFACES"][interface][handshake]["VALID"].isnumeric(): continue
                if self.interconnects["INTERFACES"][interface][handshake]["VALID"] == "": continue
                statement = "assign " + self.decode_signal(self.interconnects["INTERFACES"][interface][handshake]["VALID"])["NAME"] + " = "
                end = ""
                for connection in self.interconnects["CONNECTIVITY"]["SINKS"][interface][handshake]:
                    if handshake not in self.interconnects["INTERFACES"][connection["SOURCE"]].keys(): continue
                    statement += connection["SELECT"] + " ? " + self.decode_signal(self.interconnects["INTERFACES"][connection["SOURCE"]][handshake]["VALID"])["NAME"] + " :\n\t("
                    end += ")"
                statement += "0" + end + ";"
                self.verilog.append(statement)
                statement = "assign " + "{" + ",".join([self.decode_signal(x)["NAME"] for x in self.interconnects["INTERFACES"][interface][handshake]["FRAME"]]) + "} = "
                end = ""
                for connection in self.interconnects["CONNECTIVITY"]["SINKS"][interface][handshake]:
                    if handshake not in self.interconnects["INTERFACES"][connection["SOURCE"]].keys(): continue
                    statement += connection["SELECT"] + " ?  {" + ",".join([self.decode_signal(x)["NAME"] for x in self.interconnects["INTERFACES"][connection["SOURCE"]][handshake]["FRAME"]]) + "} :\n\t("
                    end += ")"
                statement += "0" + end + ";"
                self.verilog.append(statement)

        # Connect readys
        for interface in self.interconnects["CONNECTIVITY"]["SOURCES"].keys():
            for handshake in self.interconnects["CONNECTIVITY"]["SOURCES"][interface].keys():
                if handshake not in self.interconnects["INTERFACES"][interface].keys(): continue
                if self.interconnects["INTERFACES"][interface][handshake]["READY"].isnumeric(): continue
                if self.interconnects["INTERFACES"][interface][handshake]["READY"] == "": continue
                statement = "assign " + self.decode_signal(self.interconnects["INTERFACES"][interface][handshake]["READY"])["NAME"] + " = "
                end = ""
                for connection in self.interconnects["CONNECTIVITY"]["SOURCES"][interface][handshake]:
                    if handshake not in self.interconnects["INTERFACES"][connection["SINK"]].keys(): continue
                    statement += connection["SELECT"] + " ? " + self.decode_signal(self.interconnects["INTERFACES"][connection["SINK"]][handshake]["READY"])["NAME"] + " :\n\t ("
                    end += ")"
                statement += "0" + end + ";"
                self.verilog.append(statement)
        self.verilog.append("\n")

        # Instantiate modules
        self.verilog.append("\n\n")
        for instance_name in self.system["INSTANTIATIONS"].keys():
            module = self.system["INSTANTIATIONS"][instance_name]["MODULE"]
            self.verilog.append(module)
            if len(self.params[instance_name]):
                self.verilog.append("#(")
            parameters =  list(self.params[instance_name].keys())
            for idx in range(len(parameters)):
                parameter = parameters[idx]
                self.verilog.append("." + parameter + "(" + "PARAMETER_" + instance_name.upper() + "_" + parameter + ")" + ("," if idx <(len(parameters)-1) else ""))
            if len(self.params[instance_name]):
                self.verilog.append(")")
            self.verilog.append(instance_name)
            self.verilog.append("(")
            interfaces = list(self.modules[module]["INTERFACES"].keys())
            for idx in range(len(interfaces)):
                interface = interfaces[idx]
                protocol = self.modules[module]["INTERFACES"][interface]["TYPE"]
                if protocol in ["GENERAL","CLOCK"]:
                    signal = "MODULE:" + instance_name + ":" + interface
                    for override in self.system["INTERCONNECT"]["OVERRIDES"]:
                        if signal == override[0]:
                            signal  = override[1]
                            break
                    self.verilog.append( "." + interface + "(" + (signal if signal.isnumeric() else self.decode_signal(signal)["NAME"] )+ ")" + ("," if idx <(len(interfaces)-1) else ""))
                elif protocol in self.definitions["PROTOCOLS"].keys():
                    sigs = list(self.definitions["PROTOCOLS"][protocol]["WIDTHS"].keys())
                    for iidx in range(len(sigs)):
                        sig = sigs[iidx]
                        signal = "MODULE:" + instance_name + ":" + interface + ":" + sig
                        for override in self.system["INTERCONNECT"]["OVERRIDES"]:
                            if signal == override[0]:
                                signal  = override[1]
                                break
                        self.verilog.append("." + interface + "_" + sig + "(" + (signal if signal.isnumeric() else self.decode_signal(signal)["NAME"]) + ")" + ("," if ((idx <(len(interfaces)-1)) or (iidx <(len(sigs)-1))) else ""))
                else:
                    assert 0, f"\"{protocol}\" is not a valid interface type"
            self.verilog.append(");")
            self.verilog.append("\n")

        # End top module definition
        self.verilog.append("endmodule")

        with open(self.build_dir + "top.v","w") as f:
            for line in self.verilog:
                f.write(line + "\n")

    def generate_constraints(self):
        constraints = ""
        for port in self.system["EXTERNAL_IO"]["PORTS"]:
            constraints += self.board["CONSTRAINTS"][port] + "\n"
        with open(self.build_dir + "constraints.xdc",'w') as f:
            f.write(constraints)

    def generate_ip_tcl(self):
        all_board_files = []
        for instance_name in self.system["INSTANTIATIONS"].keys():
            module = self.system["INSTANTIATIONS"][instance_name]["MODULE"]
            board_files = self.modules[module]["REQUIREMENTS"]["INCLUDES"]["BOARD"]
            if len(board_files) == 0: continue
            for file in board_files:
                if file not in all_board_files:
                    all_board_files.append(file)
        ips = "set PROJECT " + self.system["DESCRIPTION"]["NAME"] + "\n"
        for file in all_board_files:
            if file in self.board["REQUIREMENTS"]["IP"].keys():
                for ip in self.board["REQUIREMENTS"]["IP"][file].keys():
                    ips += self.board["REQUIREMENTS"]["IP"][file][ip] + "\n"
        with open(self.build_dir + "ip.tcl",'w') as f:
            f.write(ips)

    def get_required_files(self, system_dir):
        all_board_files = []
        all_common_files = []
        all_common_folders_subsystem_files = []
        all_common_folders_subsystem_files_fullpaths = []
        for instance_name in self.system["INSTANTIATIONS"].keys():
            module = self.system["INSTANTIATIONS"][instance_name]["MODULE"]
            board_files = self.modules[module]["REQUIREMENTS"]["INCLUDES"]["BOARD"]
            common_files = self.modules[module]["REQUIREMENTS"]["INCLUDES"]["COMMON"]
            common_folders_containing_subsystem_files = self.modules[module]["REQUIREMENTS"]["INCLUDES"]["COMMON_FOLDER"]

            # if (self.build_verbose):
            #     print(f'instance_name = {instance_name}:\nmodule = {module}\nboard_files = {board_files}\common_files = {common_files}')

            if len(board_files):
                for file in board_files:
                    if file not in all_board_files:
                        all_board_files.append(file)
                        # meaning any additional files not already in default imports (default.tml)
                        if (self.build_verbose):
                            print(f'\nNon-default board_files file = {file}\n')

            if len(common_files):
                for file in common_files:
                    if file not in all_common_files:
                        all_common_files.append(file)
                        if (self.build_verbose):
                            print(f'\nNon-default common_files file = {file}\n')

            if len(common_folders_containing_subsystem_files):

                if (self.build_verbose):
                    print(f'\ncommon_folders_containing_subsystem_files = {common_folders_containing_subsystem_files}\n')

                # go recursively the that folder and folders within that folder and import any verilog or system verilog files
                for folder in common_folders_containing_subsystem_files:
                    
                    # if (self.build_verbose):
                    #     print(f'\nfolders = {folder}\n')

                    # sys.exit("exiting before os-walk")
                    
                    # Walk through the directory recursively
                    for root, dirs, files in os.walk("./fpga/common/hdl/" + folder):
                        # if (self.build_verbose):
                        #    print(f'\n root = {root} \n dirs = {dirs} \n files = {files} \n')
                        for file in files:
                            # Check if the file is a Verilog (.v) or SystemVerilog (.sv) file
                            if file.endswith('.v'):
                                # Append the full file path
                                all_common_folders_subsystem_files_fullpaths.append(os.path.join(root, file))
                                # Append the full file name
                                all_common_folders_subsystem_files.append(file)
                                # if (self.build_verbose):
                                #     print(f'\nNon-default COMMON_FOLDERS subsystem files added for subsystem folder = {folder} and file = {file}\n')
                            elif file.endswith('.sv'):
                                 # Append the full file path
                                all_common_folders_subsystem_files_fullpaths.append(os.path.join(root, file))
                                # Append the full file name
                                all_common_folders_subsystem_files.append(file)
                                # if (self.build_verbose):
                                #     print(f'\nNon-default COMMON_FOLDERS subsystem files added for subsystem folder = {folder} and file = {file}\n')
                
                # writing custom folder subsystem files
                use_specific_files = self.modules[module]["REQUIREMENTS"]["INCLUDES"]["USE_SPECIFIC_FILES_FROM_COMMON_FOLDER"]
                common_folder_files_for_appending = []
                common_folder_files_for_appending_full_path = []
                if "yes" in use_specific_files:
                    common_folder_files = self.modules[module]["REQUIREMENTS"]["INCLUDES"]["COMMON_FOLDER_FILES"]
                    if (self.build_verbose):
                        print(f'\nuse_specific_files == yes, common_folder_files for subsystem folder = {common_folder_files}\n')
                    seen = set()
                    for name in common_folder_files:
                        if name in seen:
                            raise ValueError(f"Duplicate name found in COMMON_FOLDER_FILES : {name}")
                        seen.add(name)
                    seen.clear()
                    validate_names(common_folder_files, all_common_folders_subsystem_files)
                    # if (self.build_verbose):
                    #         print(f'\nuse_specific_files == yes, common_folder_files = {common_folder_files} \n\n all_common_folders_subsystem_files = {all_common_folders_subsystem_files} \n\n all_common_folders_subsystem_files_fullpaths = {all_common_folders_subsystem_files_fullpaths} \n\n')
                    
                    # go recursively the that folder and folders within that folder and import any verilog or system verilog files that are mentioned in commmon_folder_files list
                    for folder in common_folders_containing_subsystem_files:
                        
                        # if (self.build_verbose):
                        #     print(f'\nfolders = {folder}\n')

                        # sys.exit("exiting before os-walk")
                        
                        # Walk through the directory recursively
                        for root, dirs, files in os.walk("./fpga/common/hdl/" + folder):
                            # if (self.build_verbose):
                            #     print(f'\n root = {root} \n dirs = {dirs} \n files = {files} \n')
                            for file in files:
                                # Check if the file is a Verilog (.v) or SystemVerilog (.sv) file and if it exists in common_folder_files list
                                if file.endswith('.v'):
                                    if file in common_folder_files:
                                        # Append the full file path
                                        common_folder_files_for_appending_full_path.append(os.path.join(root, file))
                                        # Append the full file name
                                        common_folder_files_for_appending.append(file)
                                        # if (self.build_verbose):
                                        #     print(f'\nNon-default COMMON_FOLDERS subsystem files added for subsystem folder = {folder} and file = {file}\n')
                                elif file.endswith('.sv'):
                                    if file in common_folder_files:
                                        # Append the full file path
                                        common_folder_files_for_appending_full_path.append(os.path.join(root, file))
                                        # Append the full file name
                                        common_folder_files_for_appending.append(file)
                                    # if (self.build_verbose):
                                    #     print(f'\nNon-default COMMON_FOLDERS subsystem files added for subsystem folder = {folder} and file = {file}\n')
                    
                    if (self.build_verbose):
                        print(f'\nuse_specific_files == yes, common_folder_files_for_appending = {common_folder_files_for_appending} \n\n common_folder_files_for_appending_full_path = {common_folder_files_for_appending_full_path} \n\n')
                    
                    
                    for file, file_full_path in zip(common_folder_files_for_appending, common_folder_files_for_appending_full_path):
                        if (self.build_verbose):
                            print(f'\nCopying use_specific_files. file = {file} \n file_full_path = {file_full_path}\n')
                        shutil.copyfile(file_full_path, self.build_dir + file)
                else:
                    raise ValueError(f"Mention exact files needed in modules.tml for this module; {module}")
                    # if (self.build_verbose):
                    #        print(f'WARNING: Change this and add specific files you need included')
                    # for file, file_full_path in zip(all_common_folders_subsystem_files, all_common_folders_subsystem_files_fullpaths):
                    #     shutil.copyfile(file_full_path, self.build_dir + file)



        all_ip_files = []
        for file in all_board_files:
            if file in self.board["REQUIREMENTS"]["FILES"].keys():
                for board_file in self.board["REQUIREMENTS"]["FILES"][file]["HDL"]:
                    if board_file not in all_board_files:
                        all_board_files.append(board_file)
                for ip_file in self.board["REQUIREMENTS"]["FILES"][file]["IP"]:
                    if ip_file not in all_ip_files:
                        all_ip_files.append(ip_file)

        src_path = os.path.join(system_dir, "src")

        # writing custom folder subsystem file
        # for file, file_full_path in zip(all_common_folders_subsystem_files, all_common_folders_subsystem_files_fullpaths):
        #     shutil.copyfile(file_full_path, self.build_dir + file)
        for file in all_common_files:
            shutil.copyfile("./fpga/common/hdl/" + file, self.build_dir + file)
        for file in all_board_files:
            shutil.copyfile("./fpga/boards/" + self.board["DESCRIPTION"]["DIRECTORY"] + "/src/hdl/" + file, self.build_dir + file)
        for file in all_ip_files:
            shutil.copyfile("./fpga/boards/" + self.board["DESCRIPTION"]["DIRECTORY"] + "/src/ip/" + file, self.build_dir + file)
        # for file in os.listdir(system_dir + "/src"):
        #     shutil.copy(system_dir + "/src/" + file, self.build_dir + file)
        for item in os.listdir(src_path):
            s = os.path.join(src_path, item)
            d = os.path.join(self.build_dir, item)
            if os.path.isdir(s):
                if os.path.exists(d):
                    raise ValueError(f"Directory {s} already exists in destination {d}")
                else:
                    shutil.copytree(s, d)
            else:
                shutil.copy2(s, d)
        shutil.copy(system_dir + "/system.tml", self.build_dir + "system.tml")

def validate_names(small_list, big_list):
    missing_names = set(small_list) - set(big_list)  # Find names in small_list but not in big_list
    if missing_names:
        raise ValueError(f"Missing file in common folder that has been mentioned in module: {', '.join(missing_names)}")
 

######################## Main ##############################

system = sys.argv[1]
board = sys.argv[2]
build_dir = sys.argv[3]
argv4 = sys.argv[4]
build_verbose = int(sys.argv[5])
# Optional: root that ${PROJECT_ROOT} in a MEM_INIT path resolves to. Supplied by
# configure.py --project_root; defaults to the disl-core checkout root when a
# consuming project doesn't set one.
# argv[1..5] stay positional for backward compatibility. Anything after that is
# a named flag: several of the positional values (tool, project_root) can legitimately
# be empty, and an empty positional collapses in the shell and silently shifts every
# later argument, so new options must not be positional.
project_root = None
skip_prebuild = False
prebuild_vars = {}
for _arg in sys.argv[6:]:
    if _arg.startswith("--project-root="):
        project_root = _arg.split("=", 1)[1] or None
    elif _arg == "--skip-prebuild":
        skip_prebuild = True
    elif _arg.startswith("--prebuild-var="):
        # --prebuild-var=<step>:<NAME>=<VALUE>
        _spec = _arg.split("=", 1)[1]
        if ":" not in _spec or "=" not in _spec.split(":", 1)[1]:
            sys.exit(f"error: --prebuild-var needs <step>:<NAME>=<VALUE>, got '{_spec}'")
        _step, _kv = _spec.split(":", 1)
        _k, _v = _kv.split("=", 1)
        prebuild_vars.setdefault(_step, {})[_k] = _v
    elif _arg:
        print(f"WARNING: build.py ignoring unrecognized argument '{_arg}'")


if (build_verbose):
    print(f'\n\nPrinting build_verbose stuff build_verbose = {build_verbose} \n\n')

# print(f'printing stuff in build: \n system = sys.argv[1] = {sys.argv[1]}\nboard = sys.argv[2]= {sys.argv[2]}\nbuild_dir = sys.argv[3] =  {sys.argv[3]}\nargv4 = {sys.argv[4]}\nbuild_verbose = sys.argv[5] =  {sys.argv[5]}')
# print(f'printing stuff in build: \n system = {system}\nboard = {board}\nbuild_dir = {build_dir}\nargv4 = {argv4}\nbuild_verbose = {build_verbose}')
# sys.exit("exiting build")
#     printing stuff in build: 
#     system = ././examples/edgetestbed/edgetestbed_jtag_uartprog_no_dram_random_module_test_arty100t/system.tml
#     board = artya7100t
#     build_dir = ./build/build_2024_9_9_edgetestbed_jtag_uartprog_no_dram_onlySwLedsFunction_arty100_v2/
#     argv4 = cpu_test.c

# so riscv linker and reset handler are populated by MAP fileds of the riscv address map in the system.tml file. The cache depth is not translated to the linker or reset handler.
# the user has to manually specify cache depth separately and has to make sure that the cache depth/memory length of the riscv address map can fit into the cache (bram, etc) being
# instantiated separately.

builder = BUILD(system, board, build_dir, build_verbose, project_root, prebuild_vars)
# Order matters: emit/verify the address-map header first so a PREBUILD step that
# compiles firmware sees the current map, then run PREBUILD so its outputs exist
# before MEM_INIT (inside generate_top) tries to resolve them.
builder.emit_address_map_header()
builder.run_prebuild(skip=skip_prebuild)
builder.generate_top()
builder.generate_constraints()
builder.generate_ip_tcl()
builder.get_required_files(system.split("/system.tml")[0])
