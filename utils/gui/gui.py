import toml
from base import *
from flask import Flask, render_template, request, render_template_string, jsonify, Response
import json
import graphviz
import pydot
import copy
import os
import shutil
import subprocess
import threading
import cv2

app = Flask(__name__)

lock = 0
guidir = os.getcwd()
active_process = None
examples_dir = "../../examples"
build_dir = "./demos"
project_name = "temp"
board_list = ["artya735t", "cmoda735t"] # TODO - read this from fpga/boards directory
softcore_modules = ["picorv32_axi"] # TODO - read this from fpga/common/config/modules.tml
external_io_list = ["clk_i","sw","led","ddr","uart_tx","uart_rx", "spi", "i2c"] # TODO - read this from fpga/board/<board>/config/board.tml
external_io_list_directions = {"clk_i" : "SOURCE","sw" : "SOURCE","led" : "SINK","ddr" : "SINK","uart_tx" : "SINK","uart_rx" : "SOURCE", "spi": "SINK", "i2c": "SINK"} # TODO - read this from fpga/board/<board>/config/board.tml
external_io_list_types = {"clk_i" : "CLOCK","sw" : "GENERAL","led" : "GENERAL","ddr" : "DDR","uart_tx" : "GENERAL","uart_rx" : "GENERAL", "spi": "SPI", "i2c": "I2C"} # TODO - read this from fpga/board/<board>/config/board.tml
valid_connections = [ ["CLOCK"], ["GENERAL"], ["SIMPLE","STREAM", "AXIMML", "CONFIGURATION"], ["DDR"], ["PCPI"], ["SPI"], ["I2C"] ] # TODO - derive this directly from handshake types
mmu_interfaces = ["AXIMML", "SIMPLE", "STREAM", "CONFIGURATION"]
ccu_interfaces = ["PCPI"]
programmers = ["progloader_axi"]

with open("../../fpga/common/config/definitions.tml") as f:
    definitions = toml.load(f)
with open("../../fpga/common/config/modules.tml") as f:
    modules = toml.load(f)
with open("../../fpga/common/config/defaults.tml") as f:
    common_defaults = toml.load(f)
with open("../../fpga/boards/" + board_list[0] + "/config/defaults.tml") as f:
    board_defaults = toml.load(f)


softcore_defaults = {}
softcore_defaults["ARCH"] = "rv32i"
softcore_defaults["ABI"] = "ilp32"
softcore_defaults["CROSS"] = "riscv64-linux-gnu-"
softcore_defaults["CROSSCFLAGS"] = "-O3 -Wno-int-conversion -ffreestanding -nostdlib"
softcore_defaults["CROSSLDFLAGS"] = "-ffreestanding -nostdlib  -Wl,-M"
softcore_defaults["LINKER_REQUIREMENTS"] = ["muldi3.S", "div.S", "riscv-asm.h"]
softcore_defaults["MEMORY"] = ""
###############################################################################

config = {}
config["DESCRIPTION"] = {"NAME": ""}
config["REQUIREMENTS"] = {"TOOLS": [], "BOARDS": [board_list[0]]}
config["EXTERNAL_IO"] = {"PORTS": []}
config["INSTANTIATIONS"] = {}

###############################################################################

def update_config():
    global config
    global lock
    global examples_dir
    global filename
    if not lock:
        with open(examples_dir + "/" + project_name + "/system.tml",'w') as f:
            toml.dump(config,f)
 

     

@app.route('/')
def render():
    global config 
    global guidir
    os.system('rm -rf ./static/*.jpeg')
    return render_template_string(html_head + generate_sysinfo_form(config, board_list,external_io_list, modules, mmu_interfaces, ccu_interfaces, softcore_modules, programmers) + generate_modules_form(config, modules) + generate_softcores_form(config, softcore_defaults) +  generate_customsig_form(config, definitions) + generate_connections_form(config, definitions)  +  generate_overrides_form(config, modules) + generate_build_form() + generate_application_input_form() + generate_run_demo_1_form() + generate_run_demo_2_form() + generate_run_demo_3_form() + generate_run_demo_4_form() + generate_run_demo_5_form() + generate_run_demo_6_form()  + generate_html_footer(guidir))


@app.route('/rundemo6', methods=['POST'])
def rundemo6():
    global active_process
    global build_dir
    global project_name
    code = request.form.get('code')
    cwd = os.getcwd()
    try:
        source_dir = "demos/demo6"
        destination_dir = '../../' + build_dir + '/' + project_name
        for filename in os.listdir(source_dir):
            source_file = os.path.join(source_dir, filename)
            destination_file = os.path.join(destination_dir, filename)
            if os.path.exists(destination_file):
                os.remove(destination_file)
            shutil.copy2(source_file, destination_file)
        os.chdir('../../' + build_dir + '/' + project_name)
        with open("cpu_test.c", 'w') as f:
            f.write(code)
        command = 'make all'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        while process.poll() is None:
            continue
        command = 'python -u test.py'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        active_process = process
        os.chdir(cwd)
        while process.poll() is None:
            stdout_line = process.stdout.readline()
            print(stdout_line, end='')
        for stdout_line in process.stdout:
            print(stdout_line, end='')
    except:        
        os.chdir(cwd)
    return 'SUCCESS'


@app.route('/rundemo5', methods=['POST'])
def rundemo5():
    global active_process
    global build_dir
    global project_name
    code = request.form.get('code')
    cwd = os.getcwd()
    try:
        source_dir = "demos/demo5"
        destination_dir = '../../' + build_dir + '/' + project_name
        for filename in os.listdir(source_dir):
            source_file = os.path.join(source_dir, filename)
            destination_file = os.path.join(destination_dir, filename)
            if os.path.exists(destination_file):
                os.remove(destination_file)
            shutil.copy2(source_file, destination_file)
        os.chdir('../../' + build_dir + '/' + project_name)
        with open("cpu_test.c", 'w') as f:
            f.write(code)
        command = 'make all'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        while process.poll() is None:
            continue
        command = 'python -u test.py'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        active_process = process
        os.chdir(cwd)
        while process.poll() is None:
            stdout_line = process.stdout.readline()
            print(stdout_line, end='')
        for stdout_line in process.stdout:
            print(stdout_line, end='')
    except:        
        os.chdir(cwd)
    return 'SUCCESS'

@app.route('/rundemo4', methods=['POST'])
def rundemo4():
    global active_process
    global build_dir
    global project_name
    code = request.form.get('code')
    cwd = os.getcwd()
    try:
        source_dir = "demos/demo4"
        destination_dir = '../../' + build_dir + '/' + project_name
        for filename in os.listdir(source_dir):
            source_file = os.path.join(source_dir, filename)
            destination_file = os.path.join(destination_dir, filename)
            if os.path.exists(destination_file):
                os.remove(destination_file)
            shutil.copy2(source_file, destination_file)
        os.chdir('../../' + build_dir + '/' + project_name)
        with open("cpu_test.c", 'w') as f:
            f.write(code)
        command = 'make all'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        while process.poll() is None:
            continue
        command = 'python -u test.py'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        active_process = process
        os.chdir(cwd)
        while process.poll() is None:
            stdout_line = process.stdout.readline()
            print(stdout_line, end='')
        for stdout_line in process.stdout:
            print(stdout_line, end='')
    except:        
        os.chdir(cwd)
    return 'SUCCESS'

@app.route('/rundemo3', methods=['POST'])
def rundemo3():
    global active_process
    global build_dir
    global project_name
    code = request.form.get('code')
    cwd = os.getcwd()
    try:
        source_dir = "demos/demo3"
        destination_dir = '../../' + build_dir + '/' + project_name
        for filename in os.listdir(source_dir):
            source_file = os.path.join(source_dir, filename)
            destination_file = os.path.join(destination_dir, filename)
            if os.path.exists(destination_file):
                os.remove(destination_file)
            shutil.copy2(source_file, destination_file)
        os.chdir('../../' + build_dir + '/' + project_name)
        with open("cpu_test.c", 'w') as f:
            f.write(code)
        command = 'make all'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        while process.poll() is None:
            continue
        command = 'python -u test.py'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        active_process = process
        os.chdir(cwd)
        while process.poll() is None:
            stdout_line = process.stdout.readline()
            print(stdout_line, end='')
        for stdout_line in process.stdout:
            print(stdout_line, end='')
    except:        
        os.chdir(cwd)
    return 'SUCCESS'


@app.route('/rundemo2', methods=['POST'])
def rundemo2():
    global active_process
    global build_dir
    global project_name
    code = request.form.get('code')
    cwd = os.getcwd()
    try:
        source_dir = "demos/demo2"
        destination_dir = '../../' + build_dir + '/' + project_name
        for filename in os.listdir(source_dir):
            source_file = os.path.join(source_dir, filename)
            destination_file = os.path.join(destination_dir, filename)
            if os.path.exists(destination_file):
                os.remove(destination_file)
            shutil.copy2(source_file, destination_file)
        os.chdir('../../' + build_dir + '/' + project_name)
        with open("cpu_test.c", 'w') as f:
            f.write(code)
        command = 'make all'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        while process.poll() is None:
            continue

        if "capture_and_transmit(EDGE_HW_BINARY" in code:
            command = 'python -u test_binary.py'
        elif "capture_and_transmit(JPEG" in code:
            command = 'python -u test_jpeg.py'
        else:
            command = 'python -u test_raw.py'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        active_process = process
        os.chdir(cwd)
        while process.poll() is None:
            stdout_line = process.stdout.readline()
            print(stdout_line, end='')
        for stdout_line in process.stdout:
            print(stdout_line, end='')
    except:        
        os.chdir(cwd)
    return 'SUCCESS'

@app.route('/rundemo1', methods=['POST'])
def rundemo1():
    global lines_read2
    global terminal2
    global active_process
    cwd = os.getcwd()
    code = request.form.get('code')
    try:
        terminal2 = []
        lines_read2 = 0
        os.chdir('../../' + build_dir + '/' + project_name)
        with open("test.py", 'w') as f:
            f.write(code)
        command = 'python -u test.py'
        print("Starting process")
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,  bufsize=1)
        active_process = process
        os.chdir(cwd)
        while process.poll() is None:
            stdout_line = process.stdout.readline()
            if stdout_line:
                terminal2.append(stdout_line.strip())
        for stdout_line in process.stdout:
            terminal2.append(stdout_line.strip())  
    except:
        os.chdir(cwd)    
    return 'ERROR'


@app.route('/checkifcodeexists', methods=['POST'])
def checkifcodeexists():
    global build_dir
    global project_name
    filepath = '../../' + build_dir + '/' + project_name + '/cpu_test.c'
    if os.path.exists(filepath):
        with open('../../' + build_dir + '/' + project_name + '/cpu_test.c') as f:
            file = f.read()
        return [{'filecontents': file}]
    else:
        return []


@app.route('/stopprocess', methods=['POST'])
def stopprocess():
    global active_process
    os.system('rm -rf ./static/*.jpeg')
    subprocess.run(['pkill', '-f', 'vivado'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if active_process:
        active_process.terminate()
        active_process = None
        return 'Process stopped'
    else:
        return 'No active process to stop'

@app.route('/stopdemo1', methods=['POST'])
def stopdemo1():
    return stopprocess()

@app.route('/stopdemo2', methods=['POST'])
def stopdemo2():
    return stopprocess()

@app.route('/stopdemo3', methods=['POST'])
def stopdemo3():
    return stopprocess()

@app.route('/stopdemo4', methods=['POST'])
def stopdemo4():
    return stopprocess()

@app.route('/stopdemo5', methods=['POST'])
def stopdemo5():
    return stopprocess()

@app.route('/stopdemo6', methods=['POST'])
def stopdemo6():
    return stopprocess()

@app.route('/gensys', methods=['POST'])
def gensys():
    global config
    global build_dir
    global project_name
    global examples_dir
    cwd = os.getcwd()
    try:
        os.chdir('../..')
        command = 'python configure.py -v --build_dir ' + build_dir + '/' + project_name + ' --board ' + config["REQUIREMENTS"]["BOARDS"][0] + ' --example ' + project_name
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        os.chdir(cwd)
        if process.returncode == 0:
            return stdout.decode('utf-8').split('\n')
        else:
            return stderr.decode('utf-8').split('\n')
    except:
        os.chdir(cwd)
    return 'ERROR'

terminal = []
lines_read = 0
terminal2 = []
lines_read2 = 0

@app.route('/pollterminal', methods=['POST'])
def pollterminal():
    global lines_read
    global terminal
    l = len(terminal)
    lr = lines_read
    if l > lines_read:
        lines_read = l
        return terminal[lr:l]
    else:
        return []

@app.route('/pollterminaldemo1', methods=['POST'])
def pollterminaldemo1():
    global lines_read2
    global terminal2
    l = len(terminal2)
    lr = lines_read2
    if l > lines_read2:
        lines_read2 = l
        return [x for x in terminal2[lr:l] if x]
    else:
        return []

@app.route('/synthandpnr', methods=['POST'])
def synthandpnr():
    global lines_read
    global terminal
    cwd = os.getcwd()
    try:
        terminal = []
        lines_read = 0
        os.chdir('../../' + build_dir + '/' + project_name)
        command = 'bash run.sh'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,  bufsize=1)
        while process.poll() is None:
            stdout_line = process.stdout.readline()
            if stdout_line:
                terminal.append(stdout_line.strip())
        for stdout_line in process.stdout:
            terminal.append(stdout_line.strip())
        shutil.copyfile('./' + project_name + "/" + project_name + ".runs/impl_1/top.bin", 'top.bin')
        os.chdir(cwd)
    except:
        os.chdir(cwd)    
    return 'ERROR'

@app.route('/saveapplicationcode', methods=['POST'])
def saveapplicationcode():
    code = request.form.get('code')
    cwd = os.getcwd()
    try:
        os.chdir('../../' + build_dir + '/' + project_name)
        with open("cpu_test.c", 'w') as f:
            f.write(code)
        command = 'make all'
        process = subprocess.Popen(command.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        os.chdir(cwd)
        if process.returncode == 0:
            return stdout.split('\n')
        else:
            return stderr.split('\n') 
    except:        
        os.chdir(cwd)
        return []

@app.route('/manuallyupdatesystemconfig', methods=['POST'])
def manuallyupdatesystemconfig():
    global config
    config = json.loads(request.form.get('code'))
    update_config()
    update_interconnect_graph()
    return 'SUCCESS'

@app.route('/displaysystemconfig', methods=['POST'])
def displaysystemconfig():
    global config
    return config


def getoverides():
    global config
    ret = []
    if "INTERCONNECT" in config.keys():
        if "OVERRIDES" in config["INTERCONNECT"].keys():
            for o in config["INTERCONNECT"]["OVERRIDES"]:
                ret.append(o[1] + " -> " + o[0])
    return ret

@app.route('/scanallmodulesignals', methods=['POST'])
def scanallmodulesignals():
    global config
    global modules
    global definitions
    global external_io_list_types
    ret = []
    if "INSTANTIATIONS" in config.keys():
        for instance in config["INSTANTIATIONS"].keys():
            m = config["INSTANTIATIONS"][instance]["MODULE"]
            for interface in modules[m]["INTERFACES"].keys():
                typee = modules[m]["INTERFACES"][interface]["TYPE"]
                if typee == "GENERAL":
                    ret.append({"type": "signal", "text" : "MODULE:" + instance + ":" + interface})
                elif typee != "CLOCK":
                    for signal in definitions["PROTOCOLS"][typee]["WIDTHS"].keys():
                        ret.append({"type": "signal", "text" : "MODULE:" + instance + ":" + interface + ":" + signal})
    for boardio in config["EXTERNAL_IO"]["PORTS"]:
        typee = external_io_list_types[boardio]
        if typee == "GENERAL":
            ret.append({"type": "override", "text" : "BOARD:" + boardio})
        elif typee != "CLOCK":
            for signal in definitions["PROTOCOLS"][typee]["WIDTHS"].keys():
                ret.append({"type": "override", "text" : "BOARD:" + boardio + ":" + signal})
    if "INTRINSICS" in config.keys():
        for i in config["INTRINSICS"].keys():
            for k in config["INTRINSICS"][i]:
                if "CUSTOM_SIGNAL_NAME" in k.keys():
                    ret.append({"type": "override", "text" : k["CUSTOM_SIGNAL_NAME"]})

    ret.append({"type": "override", "text" : "0"})
    ret.append({"type": "override", "text" : "1"})
    ret2 = getoverides()
    for r in ret2:
        ret.append({"type" : "added", "text" : r})

    return ret


@app.route('/addoverride', methods=['POST'])
def addoverride():
    global config
    signal = request.form.get('signal')
    override = request.form.get('override')
    if ("CUSTOM" not in signal) and ("BOARD" not in signal):
        if "INTERCONNECT" not in config.keys():
            config["INTERCONNECT"] = {}
        if "OVERRIDES" not in config["INTERCONNECT"].keys():
            config["INTERCONNECT"]["OVERRIDES"] = []
        check = 1
        for o in config["INTERCONNECT"]["OVERRIDES"]:
            if signal == o[0]:
                check = 0
        if check:
            config["INTERCONNECT"]["OVERRIDES"].append([signal,override])
        update_config()
    return getoverides()


@app.route('/removeoverride', methods=['POST'])
def removeoverride():
    global config
    name = request.form.get('name')
    signal = name.split(" -> ")[1]
    override = name.split(" -> ")[0]
    config["INTERCONNECT"]["OVERRIDES"] = [x for x in config["INTERCONNECT"]["OVERRIDES"] if ((x[0] != signal) or (x[1] != override))]
    update_config()
    return getoverides()



def updatesoftcoreinterconnects():
    # lots of assumptions here, so will need to revisit this function
    global config
    global softcore_modules
    global common_defaults
    if "INSTANTIATIONS" in config.keys():
        for instance in config["INSTANTIATIONS"].keys():
            i = config["INSTANTIATIONS"][instance]
            module = i["MODULE"]
            if module in softcore_modules:
                for file in i["LINKER_REQUIREMENTS"]:
                    shutil.copyfile(guidir + "/includes/" + file, examples_dir + "/" + project_name + "/includes/" + file)
                shutil.copyfile(guidir + "/includes/Makefile", examples_dir + "/" + project_name + "/includes/Makefile")
                shutil.copyfile(guidir + "/includes/utils.h", examples_dir + "/" + project_name + "/includes/utils.h")
                shutil.copyfile(guidir + "/includes/utils.py", examples_dir + "/" + project_name + "/includes/utils.py")
                mm = copy.deepcopy(i["MAP"])
                for m in mm.keys():
                    if mm[m]["ORIGIN"] == "0x00000000":
                        cache = m
                mm.pop(cache)
                if "INTERCONNECT" not in config.keys():
                    config["INTERCONNECT"] = {}
                if "DYNAMIC" not in config["INTERCONNECT"].keys():
                    config["INTERCONNECT"]["DYNAMIC"] = {}
                instance_name = "MODULE:" + instance + ":mem"
                config["INTERCONNECT"]["DYNAMIC"][instance_name] = {}
                config["INTERCONNECT"]["DYNAMIC"][instance_name]["GROUP_SELECT"] = ""
                config["INTERCONNECT"]["DYNAMIC"][instance_name]["HANDSHAKES"] = ["WRITE_ADDRESS", "WRITE_DATA", "READ_ADDRESS", "READ_DATA"]
                config["INTERCONNECT"]["DYNAMIC"][instance_name]["GROUPS"] = []
                address_map = []
                for m in mm.keys():
                    address_map.append("SYSTEM:INSTANTIATIONS." + instance + ".MAP." + m + " MODULE:" + m + ":a")
                handshake_map = []
                handshake_map.append("WRITE_ADDRESS MODULE:" + instance + ":mem:axi_awaddr")
                handshake_map.append("READ_ADDRESS MODULE:" + instance + ":mem:axi_araddr")
                handshake_map.append("WRITE_DATA CUSTOM:" + instance + "_axi_awaddr")
                handshake_map.append("READ_DATA CUSTOM:" + instance + "_axi_araddr")
                config["INTERCONNECT"]["DYNAMIC"][instance_name]["GROUPS"].append({"INTERCONNECT_TYPE": "ONE_TO_MANY", "ADDRESS_MAP": address_map, "HANDSHAKE_MAP": handshake_map})
                for m in mm.keys():
                    mname = "MODULE:" + m + ":a"
                    config["INTERCONNECT"]["DYNAMIC"][mname] = {"GROUP_SELECT": "", "HANDSHAKES": ["WRITE_ADDRESS", "WRITE_DATA", "READ_ADDRESS", "READ_DATA"], "GROUPS": [{"INTERCONNECT_TYPE": "ONE_TO_ONE", "INTERFACE": instance_name, "SELECT_VALUE": "Memory Mapped"}]}
                if "INTRINSICS" not in config.keys():
                    config["INTRINSICS"] = {}    
                if "COMBINATIONAL" not in config["INTRINSICS"].keys():
                    config["INTRINSICS"]["COMBINATIONAL"] = []  
                if "SEQUENTIAL_HOLD" not in config["INTRINSICS"].keys():
                    config["INTRINSICS"]["SEQUENTIAL_HOLD"] = [] 
                if "SEQUENTIAL_IFELSEIF" not in config["INTRINSICS"].keys():
                    config["INTRINSICS"]["SEQUENTIAL_IFELSEIF"] = [] 
                for m in mm.keys():
                    config["INTRINSICS"]["COMBINATIONAL"].append({"CUSTOM_SIGNAL_WIDTH": "PARAMETER:" + m + ":ADDR_WIDTH", "CUSTOM_SIGNAL_NAME" : "CUSTOM:" + m + "_a_axi_awaddr", "INPUT_SIGNAL_1" :  "MODULE:" + m + ":a:axi_awaddr", "OPERATION" : "-",  "INPUT_SIGNAL_2" :  "SYSTEM:INSTANTIATIONS." + instance + ".MAP." + m + ".ORIGIN"})
                    config["INTRINSICS"]["COMBINATIONAL"].append({"CUSTOM_SIGNAL_WIDTH": "PARAMETER:" + m + ":ADDR_WIDTH", "CUSTOM_SIGNAL_NAME" : "CUSTOM:" + m + "_a_axi_araddr", "INPUT_SIGNAL_1" :  "MODULE:" + m + ":a:axi_araddr", "OPERATION" : "-",  "INPUT_SIGNAL_2" :  "SYSTEM:INSTANTIATIONS." + instance + ".MAP." + m + ".ORIGIN"})
 
                config["INTRINSICS"]["COMBINATIONAL"].append({"CUSTOM_SIGNAL_WIDTH" : 1, "CUSTOM_SIGNAL_NAME" : "CUSTOM:" + instance + "_mem_wvalid_and_wready", "INPUT_SIGNAL_1" :  "MODULE:" + instance + ":mem:axi_wvalid", "OPERATION" : "&", "INPUT_SIGNAL_2" :  "MODULE:" + instance + ":mem:axi_wready"})
                config["INTRINSICS"]["COMBINATIONAL"].append({"CUSTOM_SIGNAL_WIDTH" : 1, "CUSTOM_SIGNAL_NAME" : "CUSTOM:" + instance + "_mem_wvalid_and_wready_resetn", "INPUT_SIGNAL_1" :  "CUSTOM:" + instance + "_mem_wvalid_and_wready", "OPERATION" : "&", "INPUT_SIGNAL_2" :  "CUSTOM:" + instance + "_resetn"})
                config["INTRINSICS"]["SEQUENTIAL_HOLD"].append({"CUSTOM_SIGNAL_WIDTH" : "PARAMETER:" + instance + ":ADDR_WIDTH", "CUSTOM_SIGNAL_NAME" : "CUSTOM:" + instance + "_axi_araddr", "INTERNAL_SIGNAL_NAME" : "INTERNAL:CUSTOM:" + instance + "_axi_araddr", "CUSTOM_SIGNAL_DEFAULT_VALUE" : 0, "CLOCK" : "MODULE:" + instance + ":clk", "TRIGGER" : "MODULE:" + instance + ":mem:axi_arvalid", "HOLD_VALUE" : "MODULE:" + instance + ":mem:axi_araddr"})
                config["INTRINSICS"]["SEQUENTIAL_HOLD"].append({"CUSTOM_SIGNAL_WIDTH" : "PARAMETER:" + instance + ":ADDR_WIDTH", "CUSTOM_SIGNAL_NAME" : "CUSTOM:" + instance + "_axi_awaddr", "INTERNAL_SIGNAL_NAME" : "INTERNAL:CUSTOM:" + instance + "_axi_awaddr", "CUSTOM_SIGNAL_DEFAULT_VALUE" :  0, "CLOCK" : "MODULE:" + instance + ":clk", "TRIGGER" : "MODULE:" + instance + ":mem:axi_awvalid", "HOLD_VALUE" : "MODULE:" + instance + ":mem:axi_awaddr"})
                config["INTRINSICS"]["SEQUENTIAL_IFELSEIF"].append({"CUSTOM_SIGNAL_WIDTH" : 1, "CUSTOM_SIGNAL_NAME" : "CUSTOM:" + instance + "_mem_b_valid", "CUSTOM_SIGNAL_DEFAULT_VALUE" :  0, "CLOCK" : "MODULE:" + instance + ":clk", "CONDITION_1" : "CUSTOM:" + instance + "_mem_wvalid_and_wready_resetn", "ASSIGNMENT_IF_CONDITION_1_TRUE" : "1", "CONDITION_2" : "MODULE:" + instance + ":mem:b_ready", "ASSIGNMENT_IF_CONDITION_2_TRUE" : "0"})
                config["INTRINSICS"]["COMBINATIONAL"].append({"CUSTOM_SIGNAL_WIDTH" : 1, "CUSTOM_SIGNAL_NAME" : "CUSTOM:" + instance + "_resetn", "INPUT_SIGNAL_1" :  "1'd1", "OPERATION" : "^", "INPUT_SIGNAL_2" :  "CUSTOM:reprogram"})
                if "OVERRIDES" not in config["INTERCONNECT"].keys():
                    config["INTERCONNECT"]["OVERRIDES"] = []
                for m in mm.keys():
                    config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:" + m + ":a:axi_awaddr","CUSTOM:" + m + "_a_axi_awaddr"])
                    config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:" + m + ":a:axi_araddr","CUSTOM:" + m + "_a_axi_araddr"])
                config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:" + instance + ":irq", "0"])
                config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:" + instance + ":mem:b_valid","CUSTOM:" + instance + "_mem_b_valid"])
                config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:" + instance + ":mem:b_response", "0"])
                if "STATIC" not in config["INTERCONNECT"].keys():
                    config["INTERCONNECT"]["STATIC"] = []
                config["INTERCONNECT"]["STATIC"].append([ "CUSTOM:" + instance + "_resetn", "MODULE:" + instance + ":resetn"])

                config["INTERCONNECT"]["DYNAMIC"][instance_name]["GROUPS"][0]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS." + instance + ".MAP." + cache + " MODULE:" + cache + ":cpu")
                cache_name = "MODULE:" + cache + ":cpu"
                if cache_name not in config["INTERCONNECT"]["DYNAMIC"].keys():
                    config["INTERCONNECT"]["DYNAMIC"][cache_name] = {"GROUP_SELECT": "", "HANDSHAKES": ["WRITE_ADDRESS", "WRITE_DATA", "READ_ADDRESS", "READ_DATA"], "GROUPS": [{"INTERCONNECT_TYPE": "ONE_TO_ONE", "INTERFACE": instance_name, "SELECT_VALUE" : 0}]}
                else:
                    config["INTERCONNECT"]["DYNAMIC"][cache_name]["GROUPS"].append({"INTERCONNECT_TYPE": "ONE_TO_ONE", "INTERFACE": instance_name, "SELECT_VALUE" : 0})
    update_config()

@app.route('/scancustomsignals', methods=['POST'])
def scancustomsignals():
    global config
    ret = []
    if "INTRINSICS" in config.keys():
        for i in config["INTRINSICS"].keys():
            for k in config["INTRINSICS"][i]:
                if "CUSTOM_SIGNAL_NAME" in k.keys():
                    ret.append(k["CUSTOM_SIGNAL_NAME"])
    return ret

@app.route('/addcustomsignal', methods=['POST'])
def addcustomsignal():
    global config
    mp = request.form.get('map')
    mp = json.loads(mp)
    intrinsic_type = mp["INTRINSIC"]
    mp.pop("INTRINSIC")
    for k in mp.keys():
        if k == "CUSTOM_SIGNAL_NAME":
            if "CUSTOM:" not in mp[k]:
                mp[k] = "CUSTOM:" + mp[k] 
    if "INTRINSICS" not in config.keys():
        config["INTRINSICS"] = {}
    if intrinsic_type not in config["INTRINSICS"].keys():
        config["INTRINSICS"][intrinsic_type] = []
    config["INTRINSICS"][intrinsic_type].append(copy.deepcopy(mp))
    update_config()
    update_interconnect_graph()
    return scancustomsignals()

@app.route('/removecustomsignal', methods=['POST'])
def removecustomsignal():
    global config
    name = request.form.get('name')
    ret = []
    for i in config["INTRINSICS"].keys():
        config["INTRINSICS"][i] = [x for x in config["INTRINSICS"][i] if x["CUSTOM_SIGNAL_NAME"] != name]
    update_config()
    update_interconnect_graph()
    return scancustomsignals()

def getinterconnectconnectivity():
    global config
    ret = []
    if "STATIC" in config["INTERCONNECT"].keys():
        for i in range(len(config["INTERCONNECT"]["STATIC"])):
            conn = config["INTERCONNECT"]["STATIC"][i]
            so = conn[0]
            for j in range(1, len(conn)):
                si = conn[j]
                ret.append(so + " -> " + si)
    if "DYNAMIC" in config["INTERCONNECT"].keys():
        for i in config["INTERCONNECT"]["DYNAMIC"].keys():
            s = i.split(":")
            if len(s) == 2:
                direction = external_io_list_directions[s[1]]
            else:
                direction = modules[config["INSTANTIATIONS"][s[1]]["MODULE"]]["INTERFACES"][s[2]]["DIRECTION"]
            conn = config["INTERCONNECT"]["DYNAMIC"][i]
            sel = conn["GROUP_SELECT"]
            ext_blocks = ""
            for j in range(len(conn["GROUPS"])):
                if conn["GROUPS"][j]["INTERCONNECT_TYPE"] == "ONE_TO_ONE":
                    if ext_blocks:
                        ext_blocks += " " + conn["GROUPS"][j]["INTERFACE"]
                    else:
                        ext_blocks += conn["GROUPS"][j]["INTERFACE"]
                else:
                    for address_map in conn["GROUPS"][j]["ADDRESS_MAP"]:
                        if ext_blocks:
                            ext_blocks += " " + address_map.split(' ')[1]
                        else:
                            ext_blocks += address_map.split(' ')[1]
            ext_blocks = ' '.join(list(set(ext_blocks.split(' '))))                
            if direction == "SOURCE":
                ret.append(i + "  ->  " + ext_blocks)
            else:
                ret.append(ext_blocks + "  ->  " + i)
    ret = list(set(ret))
    return ret

@app.route('/removeinterconnect', methods=['POST'])
def removeinterconnect():
    global config
    name = request.form.get('interconnect')
    s = name.split(" ")[0]
    isdynamic = 0
    if "CUSTOM" not in name:
        if "DYNAMIC" in config["INTERCONNECT"].keys():
            if s in config["INTERCONNECT"]["DYNAMIC"].keys():
                isdynamic = 1
    if isdynamic:
        so = name.split(' -> ')[0]
        si = name.split(' -> ')[1]
        so = so.split(' ')
        si = si.split(' ')
        so = [x for x in so if (":" in x)]
        si = [x for x in si if (":" in x)]
        for s in so:
            conn = config["INTERCONNECT"]["DYNAMIC"][s]
            conn["GROUPS"] = [x for x in conn["GROUPS"] if x["INTERFACE"] not in si]
            if len(conn["GROUPS"]) == 0:
                config["INTERCONNECT"]["DYNAMIC"].pop(s)
        for s in si:
            conn = config["INTERCONNECT"]["DYNAMIC"][s]
            conn["GROUPS"] = [x for x in conn["GROUPS"] if x["INTERFACE"] not in so]
            if len(conn["GROUPS"]) == 0:
                config["INTERCONNECT"]["DYNAMIC"].pop(s)
    else:
        so = name.split(' -> ')[0]
        si = name.split(' -> ')[1]
        print(name)
        for i in range(len(config["INTERCONNECT"]["STATIC"])):
            conn = config["INTERCONNECT"]["STATIC"][i]
            if so in conn and si in conn:
                config["INTERCONNECT"]["STATIC"][i].remove(si)
                if len(conn) == 1:
                    config["INTERCONNECT"]["STATIC"][i].remove(so)
        print(config["INTERCONNECT"]["STATIC"])
        print(so)
        print(si)
        config["INTERCONNECT"]["STATIC"] = [x for x in config["INTERCONNECT"]["STATIC"] if x!=[]]
    update_config()
    update_interconnect_graph()
    return getinterconnectconnectivity()


@app.route('/addinterconnect', methods=['POST'])
def addinterconnect():
    global config
    name = request.form.get('source')
    if not name:
        update_interconnect_graph()
        return 'FAIL'
    so_i_name = name.split("->")[0]
    so_i = name.split("->")[1]
    so_type = "" if (so_i_name == "BOARD" or so_i_name == "CUSTOM") else "MODULE:"
    so = so_type + so_i_name + ":" + so_i
    name = request.form.get('sink')
    if not name:
        update_interconnect_graph()
        return 'FAIL'
    si_i_name = name.split("->")[0]
    si_i = name.split("->")[1]
    si_type = "" if (si_i_name == "BOARD" or si_i_name == "CUSTOM") else "MODULE:"
    si = si_type + si_i_name + ":" + si_i
    name = request.form.get('dsel')
    if not name:
        if "INTERCONNECT" not in config.keys():
            config["INTERCONNECT"] = {}
        if "STATIC" not in config["INTERCONNECT"].keys():
            config["INTERCONNECT"]["STATIC"] = []
        check = 0
        for i in range(len(config["INTERCONNECT"]["STATIC"])):
            if so in config["INTERCONNECT"]["STATIC"][i]:
                if si not in config["INTERCONNECT"]["STATIC"][i]:
                    config["INTERCONNECT"]["STATIC"][i].append(si)
                check = 1
        if not check:
            config["INTERCONNECT"]["STATIC"].append([so, si])
        update_config()
        update_interconnect_graph()
    else:
        gs_i_name = name.split("->")[0]
        gs_i = name.split("->")[1]
        gs_type = "" if (gs_i_name == "BOARD" or gs_i_name == "CUSTOM") else "MODULE:"
        gs = gs_type + gs_i_name + ":" + gs_i
        if "INTERCONNECT" not in config.keys():
            config["INTERCONNECT"] = {}
        if "DYNAMIC" not in config["INTERCONNECT"].keys():
            config["INTERCONNECT"]["DYNAMIC"] = {}
        if so not in config["INTERCONNECT"]["DYNAMIC"].keys():
            config["INTERCONNECT"]["DYNAMIC"][so] = {"GROUP_SELECT": gs, "HANDSHAKES": ["WRITE_ADDRESS", "WRITE_DATA", "READ_ADDRESS", "READ_DATA"], "GROUPS": []}
        if si not in config["INTERCONNECT"]["DYNAMIC"].keys():
            config["INTERCONNECT"]["DYNAMIC"][si] = {"GROUP_SELECT": gs, "HANDSHAKES": ["WRITE_ADDRESS", "WRITE_DATA", "READ_ADDRESS", "READ_DATA"], "GROUPS": []}
        if not  config["INTERCONNECT"]["DYNAMIC"][si]["GROUP_SELECT"]:
            config["INTERCONNECT"]["DYNAMIC"][so]["GROUP_SELECT"] = gs
        if not  config["INTERCONNECT"]["DYNAMIC"][si]["GROUP_SELECT"]:
            config["INTERCONNECT"]["DYNAMIC"][si]["GROUP_SELECT"] = gs
        config["INTERCONNECT"]["DYNAMIC"][so]["GROUPS"].append({"SELECT_VALUE": int(request.form.get('dval')), "INTERCONNECT_TYPE": "ONE_TO_ONE", "INTERFACE" : si})
        config["INTERCONNECT"]["DYNAMIC"][si]["GROUPS"].append({"SELECT_VALUE": int(request.form.get('dval')), "INTERCONNECT_TYPE": "ONE_TO_ONE", "INTERFACE" : so})
        update_config()
        update_interconnect_graph()
    return getinterconnectconnectivity()


@app.route('/scanformodulesforpossiblesinks', methods=['POST'])
def scanformodulesforpossiblesinks():
    global config
    global external_io_list
    global external_io_list_directions
    global external_io_list_types
    global valid_connections
    global modules
    name = request.form.get('source')
    instance_name = name.split("->")[0]
    interface = name.split("->")[1]
    if instance_name == "BOARD":
        typee = external_io_list_types[interface]
    elif instance_name == "CUSTOM":
        typee = "GENERAL"
    else:    
        module = config["INSTANTIATIONS"][instance_name]["MODULE"]
        typee = modules[module]["INTERFACES"][interface]["TYPE"]
    possible_interconnects = []
    for possiblity in valid_connections:
        if typee in possiblity:
            possible_interconnects = possiblity
            break
    ret = []
    for boardio in config["EXTERNAL_IO"]["PORTS"]:
        if external_io_list_directions[boardio] == "SINK":
            if external_io_list_types[boardio] in possible_interconnects:
                name = "BOARD->" + boardio
                ret.append(name)
    for inst in config["INSTANTIATIONS"].keys():
        module = config["INSTANTIATIONS"][inst]["MODULE"]
        for interface in modules[module]["INTERFACES"].keys():
            ifc = modules[module]["INTERFACES"][interface]
            if ifc["DIRECTION"] == "SINK":
                if ifc["TYPE"] in possible_interconnects:
                    name = inst + "->" + interface
                    ret.append(name)
    return ret


@app.route('/scanformodulesforpossiblesources', methods=['POST'])
def scanformodulesforpossiblesources():
    global config
    global external_io_list
    global external_io_list_directions
    global external_io_list_types
    global modules
    ret = []
    for boardio in config["EXTERNAL_IO"]["PORTS"]:
        if external_io_list_directions[boardio] == "SOURCE":
            name = "BOARD->" + boardio
            ret.append({'type': 'source', 'name': name})
    for inst in config["INSTANTIATIONS"].keys():
        module = config["INSTANTIATIONS"][inst]["MODULE"]
        for interface in modules[module]["INTERFACES"].keys():
            ifc = modules[module]["INTERFACES"][interface]
            if ifc["DIRECTION"] == "SOURCE":
                name = inst + "->" + interface
                ret.append({'type': 'source', 'name': name})
    if "INTRINSICS" in config.keys():
        for i in config["INTRINSICS"].keys():
            for k in config["INTRINSICS"][i]:
                if "CUSTOM_SIGNAL_NAME" in k.keys():
                    s = k["CUSTOM_SIGNAL_NAME"]
                    s = s.split(":")[1]
                    name = "CUSTOM->" + s 
                    ret.append({'type': 'source', 'name': name})
    if "INTRINSICS" in config.keys():
        for i in config["INTRINSICS"].keys():
            for k in config["INTRINSICS"][i]:
                if "CUSTOM_SIGNAL_NAME" in k.keys():
                    s = k["CUSTOM_SIGNAL_NAME"]
                    s = s.split(":")[1]
                    name = "CUSTOM->" + s 
                    ret.append({'type': 'select', 'name': name})

    for boardio in config["EXTERNAL_IO"]["PORTS"]:
        if external_io_list_directions[boardio] == "SOURCE":
            if external_io_list_types[boardio] == "GENERAL":
                name = "BOARD->" + boardio
                ret.append({'type': 'select', 'name': name})
    for inst in config["INSTANTIATIONS"].keys():
        module = config["INSTANTIATIONS"][inst]["MODULE"]
        for interface in modules[module]["INTERFACES"].keys():
            ifc = modules[module]["INTERFACES"][interface]
            if ifc["DIRECTION"] == "SOURCE":
                if ifc["TYPE"] == "GENERAL":
                    name = inst + "->" + interface
                    ret.append({'type': 'select', 'name': name})

    if "INTERCONNECT" in config.keys():
        ret2 = getinterconnectconnectivity()
        for r in ret2:
            ret.append({'type': 'curr', 'name' : r})
    if ret:
        name = ret[0]["name"]
        instance_name = name.split("->")[0]
        interface = name.split("->")[1]
        if instance_name == "BOARD":
            typee = external_io_list_types[interface]
        else:    
            module = config["INSTANTIATIONS"][instance_name]["MODULE"]
            typee = modules[module]["INTERFACES"][interface]["TYPE"]
        possible_interconnects = []
        for possiblity in valid_connections:
            if typee in possiblity:
                possible_interconnects = possiblity
                break
        for boardio in config["EXTERNAL_IO"]["PORTS"]:
            if external_io_list_directions[boardio] == "SINK":
                if external_io_list_types[boardio] in possible_interconnects:
                    name = "BOARD->" + boardio
                    ret.append({'type': 'sink', 'name': name})
        for inst in config["INSTANTIATIONS"].keys():
            module = config["INSTANTIATIONS"][inst]["MODULE"]
            for interface in modules[module]["INTERFACES"].keys():
                ifc = modules[module]["INTERFACES"][interface]
                if ifc["DIRECTION"] == "SINK":
                    if ifc["TYPE"] in possible_interconnects:
                        name = inst + "->" + interface
                        ret.append({'type': 'sink', 'name': name})                
    update_interconnect_graph()
    return ret


def update_interconnect_graph():
    global config
    global modules
    global external_io_list
    global external_io_list_directions
    global external_io_list_types
    graph = pydot.Dot("my_graph", graph_type="digraph", bgcolor="white", strict=True, rankdir='TB', width='0.5')
    n = pydot.Node(name="BOARD", label="BOARD", style="filled", shape='box', fillcolor='lightblue1')
    graph.add_node(n)  
    for boardio in config["EXTERNAL_IO"]["PORTS"]:
        k = "BOARD-" + boardio
        n = pydot.Node(name=k, label=boardio + "\n(" + external_io_list_types[boardio] + ")")
        graph.add_node(n)  
        if external_io_list_directions[boardio] == "SOURCE":
            graph.add_edge(pydot.Edge("BOARD", k))
        else:
            graph.add_edge(pydot.Edge(k,"BOARD"))
    for inst in config["INSTANTIATIONS"].keys():
        module = config["INSTANTIATIONS"][inst]["MODULE"]
        n = pydot.Node(name=inst, label=inst + "\n(" + module + ")", style="filled", shape='box', fillcolor='lightblue1') 
        graph.add_node(n)  
        for interface in modules[module]["INTERFACES"].keys():
            ifc = modules[module]["INTERFACES"][interface]
            k = inst + "-" + interface
            n = pydot.Node(name=k, label=interface + "\n(" + ifc["TYPE"] + ")" )
            graph.add_node(n)
            if ifc["DIRECTION"] == "SOURCE":
                graph.add_edge(pydot.Edge(inst, k))
            else:
                graph.add_edge(pydot.Edge(k,inst))
    if "INTERCONNECT" in config.keys():
        if "STATIC" in config["INTERCONNECT"].keys():
            for i in range(len(config["INTERCONNECT"]["STATIC"])):
                conn = config["INTERCONNECT"]["STATIC"][i]
                so = conn[0].split(":")
                so_name = so[1] if (len(so) == 3) else so[0]
                so_intfc = so[2] if (len(so) == 3) else so[1]
                so = so_name + "-" + so_intfc
                for j in range(1,len(conn)):
                    si = conn[j].split(":")
                    si_name = si[1] if (len(si) == 3) else si[0]
                    si_intfc = si[2] if (len(si) == 3) else si[1]
                    si = si_name + "-" + si_intfc
                    graph.add_edge(pydot.Edge(so,si))
        if "DYNAMIC" in config["INTERCONNECT"].keys():
            for i in config["INTERCONNECT"]["DYNAMIC"].keys():
                s = i.split(":")
                s_name = s[1] if (len(s) == 3) else s[0]
                s_intfc = s[2] if (len(s) == 3) else s[1]
                if len(s) == 2:
                    direction = external_io_list_directions[s[1]]
                else:
                    direction = modules[config["INSTANTIATIONS"][s[1]]["MODULE"]]["INTERFACES"][s[2]]["DIRECTION"]
                s = s_name + "-" + s_intfc
                conn = config["INTERCONNECT"]["DYNAMIC"][i]
                sel = conn["GROUP_SELECT"]
                for j in range(len(conn["GROUPS"])):
                    if conn["GROUPS"][j]["INTERCONNECT_TYPE"] == "ONE_TO_ONE":
                        t =  conn["GROUPS"][j]["INTERFACE"].split(":")
                        t_name = t[1] if (len(t) == 3) else t[0]
                        t_intfc = t[2] if (len(t) == 3) else t[1]
                        t = t_name + "-" + t_intfc
                        try:
                            label = ((sel + " = ") if sel else "") + str(conn["GROUPS"][j]["SELECT_VALUE"])
                            if direction == "SOURCE":
                                graph.add_edge(pydot.Edge(s,t, label=label))
                            else:
                                graph.add_edge(pydot.Edge(t,s, label=label)) 
                        except:
                            continue   
                    else:
                        for address_map in conn["GROUPS"][j]["ADDRESS_MAP"]:
                            t =  address_map.split(' ')[1].split(":")
                            t_name = t[1] if (len(t) == 3) else t[0]
                            t_intfc = t[2] if (len(t) == 3) else t[1]
                            t = t_name + "-" + t_intfc
                            origin = config["INSTANTIATIONS"][s_name]["MAP"][t_name]["ORIGIN"]
                            length = config["INSTANTIATIONS"][s_name]["MAP"][t_name]["LENGTH"]
                            label = "ORIGIN: " + origin + ", LENGTH: " + length
                        if direction == "SOURCE":
                            graph.add_edge(pydot.Edge(s,t, label=label))
                        else:
                            graph.add_edge(pydot.Edge(t,s, label=label))   
    graph.write_svg(guidir + "/static/graph_output.svg")

    return



@app.route('/updatememorymap', methods=['POST'])
def updatememorymap():
    name = request.form.get('softcore')
    mp = request.form.get('map')
    mp = json.loads(mp)
    config["INSTANTIATIONS"][name]["MAP"] = {}
    mlist = list(mp.keys())
    for i in range(10):
        if mp[mlist[i*3+1]] and mp[mlist[i*3+2]]:
            config["INSTANTIATIONS"][name]["MAP"][mp[mlist[i*3+0]]] = {"ORIGIN": mp[mlist[i*3+1]], "LENGTH": mp[mlist[i*3+2]]} 
    update_config()
    updatesoftcoreinterconnects()
    return "SUCCESS"


@app.route('/loadmemorymap', methods=['POST'])
def loadmemorymap():
    global softcore_modules
    name = request.form.get('softcore')
    ret = []
    counter = 0
    if "MAP" in config["INSTANTIATIONS"][name].keys():
        for mp in config["INSTANTIATIONS"][name]["MAP"].keys():
            mpp = config["INSTANTIATIONS"][name]["MAP"][mp]
            ret.append({'m': mp, 'o': mpp["ORIGIN"], 'l': mpp["LENGTH"], 'i': counter})
            for m in config["INSTANTIATIONS"].keys():
                if config["INSTANTIATIONS"][m]["MODULE"] not in softcore_modules:
                    if m != mp:
                        ret.append({'m': m, 'o': mpp["ORIGIN"], 'l': mpp["LENGTH"], 'i': counter})
            counter += 1
    for i in range(counter, 10):
        for m in config["INSTANTIATIONS"].keys():
            if config["INSTANTIATIONS"][m]["MODULE"] not in softcore_modules:
                ret.append({'m': m, 'o': "", 'l': "", 'i': i})
    return ret

@app.route('/updatesoftcoreparameters', methods=['POST'])
def updatesoftcoreparameters():
    global config
    global common_defaults
    name = request.form.get('softcore')
    data = request.form.get('values')
    data = json.loads(data)
    for k in data.keys():
        config["INSTANTIATIONS"][name]["PARAMETERS"][k] = data[k]
    update_config()
    updatesoftcoreinterconnects()
    return 'SUCCESS'

@app.route('/loadsoftcoreparameters', methods=['POST'])
def loadsoftcoreparameters():
    global softcore_defaults
    ret = {}
    name = request.form.get('softcore')
    params = config["INSTANTIATIONS"][name]
    for k in softcore_defaults.keys():
        ret[k] = params[k]
    return ret

@app.route('/scanforsoftcores', methods=['POST'])
def scanforsoftcores():
    global softcore_modules
    ret = []
    for k in config["INSTANTIATIONS"].keys():
        if config["INSTANTIATIONS"][k]["MODULE"] in softcore_modules:
            ret.append({'item': k})
    updatesoftcoreinterconnects()
    return ret

@app.route('/updatemoduleparamvalue', methods=['POST'])
def updatemoduleparamvalue():
    name = request.form.get('module')
    param = request.form.get('param')
    value = request.form.get('value')
    if isinstance(common_defaults["MODULES"][config["INSTANTIATIONS"][name]["MODULE"]][param],int):
       value = int(value)

    if "PARAMETERS" not in config["INSTANTIATIONS"][name].keys():
        config["INSTANTIATIONS"][name]["PARAMETERS"] = {param: value}
    else:
        config["INSTANTIATIONS"][name]["PARAMETERS"][param] = value
    update_config()
    updatesoftcoreinterconnects()
    return 'SUCCESS'

@app.route('/loadparameters', methods=['POST'])
def loadparameters():
    name  = request.form.get('moduleselect')
    module = config["INSTANTIATIONS"][name]["MODULE"]
    p = {}
    if module in common_defaults["MODULES"].keys():
        for k in common_defaults["MODULES"][module].keys():
            if (not isinstance(common_defaults["MODULES"][module][k], dict)) and (not isinstance(common_defaults["MODULES"][module][k], list)):
                p[k] = common_defaults["MODULES"][module][k]
    
    if module in board_defaults["MODULES"].keys():
        for k in board_defaults["MODULES"][module].keys():
            if (not isinstance(board_defaults["MODULES"][module][k], dict)) and (not isinstance(board_defaults["MODULES"][module][k], list)):
                p[k] = board_defaults["MODULES"][module][k]
    if "PARAMETERS" in config["INSTANTIATIONS"][name].keys():
        for k in config["INSTANTIATIONS"][name]["PARAMETERS"].keys():
            if k in p.keys():
                p[k] = config["INSTANTIATIONS"][name]["PARAMETERS"][k]
    ret = []
    for k in p.keys():
        ret.append({'item': k, 'value': p[k]})
    return ret

@app.route('/instantiatemodule', methods=['POST'])
def instantiatemodule():
    global softcore_modules
    global softcore_defaults
    name  = request.form.get('instance')
    if (name) and (' ' not in name) and (name not in config["INSTANTIATIONS"].keys()):
        config["INSTANTIATIONS"][name] = {"MODULE": request.form.get('moduleselect')}
        if request.form.get('moduleselect') in softcore_modules:
            config["INSTANTIATIONS"][name]["PARAMETERS"] = {}
            for param in softcore_defaults.keys():
                config["INSTANTIATIONS"][name][param] = softcore_defaults[param]
        update_config()
        updatesoftcoreinterconnects()
    return 'SUCCESS'

@app.route('/removemodule', methods=['POST'])
def removemodule():
    name = request.form.get('moduleselect')
    config["INSTANTIATIONS"].pop(name)
    update_config()
    updatesoftcoreinterconnects()
    return 'SUCCESS'


@app.route('/updateaddedmodule', methods=['GET'])
def updateaddedmodule():
    inst = list(config["INSTANTIATIONS"])
    items = []
    for i in inst:
        items.append({'value':i, 'text': i})
    return items


@app.route('/scanformodules', methods=['POST'])
def scanformodules():
    global config
    ret = []
    for k in config["INSTANTIATIONS"].keys():
        ret.append({'item': k})
    updatesoftcoreinterconnects()
    return ret

@app.route('/checksysinfo', methods=['POST'])
def checksysinfo():
    global config
    global examples_dir
    global project_name
    ret = []
    project_name = request.form.get("project_name")
    try:
        with open(examples_dir + "/" + project_name + "/system.tml") as f:
            config = toml.load(f)
        ret.append({"name": "board" , "value" : config["REQUIREMENTS"]["BOARDS"][0]})
        for io in external_io_list:
            ret.append({"name" : io , "value" : 'y' if io in config["EXTERNAL_IO"]["PORTS"] else 'n'})
    except:
        os.mkdir(examples_dir + "/" + project_name)
        os.mkdir(examples_dir + "/" + project_name + "/includes")
        shutil.copyfile("includes/ftdi.py", examples_dir + "/" + project_name + "/includes/ftdi.py")
        shutil.copyfile("includes/jtag.py", examples_dir + "/" + project_name + "/includes/jtag.py")
        ret.append({"name": "board" , "value" : config["REQUIREMENTS"]["BOARDS"][0]})
        for io in external_io_list:
            ret.append({"name" : io , "value" : 'n'})
        update_config()
    return ret

@app.route('/sysinfosave', methods=['POST'])
def sysinfosave():
    global config
    global board_defaults
    config["DESCRIPTION"]["NAME"] = request.form.get('projectname')
    config["REQUIREMENTS"]["BOARDS"] = [request.form.get('boardselect')]
    config["EXTERNAL_IO"]["PORTS"] = []
    for external_io in external_io_list:
        if request.form.get("var_" + external_io) == 'true':
            config["EXTERNAL_IO"]["PORTS"].append(external_io)
    with open("../../fpga/boards/" + request.form.get('boardselect') + "/config/defaults.tml") as f:
        board_defaults = toml.load(f)
    update_config()
    return 'Success'


@app.route('/generatesoc', methods=['POST'])
def generatesoc():
    global config
    global examples_dir
    global modules
    global definitions
    global softcore_defaults
    global programmers
    global project_name

    name = request.form.get('name')
    board = request.form.get('board')
    softcore = request.form.get('softcore')
    ccu = request.form.get('ccu')
    freq = request.form.get('freq')
    cache = request.form.get('cache')
    cache_size = request.form.get('cache_size')
    i2c = request.form.get('i2c')
    uart = request.form.get('uart')
    spi = request.form.get('spi')
    mmu = request.form.get('mmu')
    mmu = json.loads(mmu)


    # name = "soc"
    # board = "cmoda735t"
    # mmu = {'cache': False, 'cache_line_builder': False, 'ddr_controller': False, 'gpio_axi': True, 'timer_axi': True, 'uart_axi': True, 'i2c_axi': True, 'spi_axi': True, 'progloader_axi': True, 'jtag_chip_manager': False, 'bram': True, 'mm_crossover_axi': False}
    # freq = "12"
    # cache = "bram"
    # cache_size = "32768"
    # i2c = "100"
    # uart = "921600"
    # spi = "2"

    project_name = name
    try:
        os.mkdir(examples_dir + "/" + project_name)
        os.mkdir(examples_dir + "/" + project_name + "/includes")
    except:
        pass
    shutil.copyfile("includes/ftdi.py", examples_dir + "/" + project_name + "/includes/ftdi.py")
    shutil.copyfile("includes/jtag.py", examples_dir + "/" + project_name + "/includes/jtag.py")
    for file in softcore_defaults["LINKER_REQUIREMENTS"]:
        shutil.copyfile("./includes/" + file, examples_dir + "/" + project_name + "/includes/" + file)
    shutil.copyfile("./includes/Makefile", examples_dir + "/" + project_name + "/includes/Makefile")
    shutil.copyfile("includes/utils.h", examples_dir + "/" + project_name + "/includes/utils.h")
    shutil.copyfile("includes/utils.py", examples_dir + "/" + project_name + "/includes/utils.py")

    config = {"DESCRIPTION": {"NAME" :name}, 
                "REQUIREMENTS": {"BOARDS" : [board]}, "EXTERNAL_IO": {"PORTS": ["clk_i", "uart_rx"]}, 
                "INSTANTIATIONS" : {
                    "cpu": {
                        "MODULE": softcore, 
                        "MEMORY" : "cache",
                        "ARCH" : "rv32i",
                        "ABI": "ilp32",
                        "CROSS": "riscv32-unknown-elf-",
                        "CROSSCFLAGS": "-O3 -Wno-int-conversion -ffreestanding -nostdlib",
                        "CROSSLDFLAGS": "-ffreestanding -nostdlib  -Wl,-M",
                        "LINKER_REQUIREMENTS": ["muldi3.S", "div.S", "riscv-asm.h"],
                        "PARAMETERS":{
                            "ENABLE_INTERRUPTS": 0,
                            "ENABLE_PCPI": 1,
                            "INSTRUCTION_MEMORY_STARTING_ADDRESS": 0,
                            "INTERRUPT_HANDLER_STARTING_ADDRESS": 16,
                            "INSTRUCTION_AND_DATA_MEMORY_SIZE_BYTES": int(cache_size)
                        },
                        "MAP":{
                            "cache": {"ORIGIN": "0x00000000", "LENGTH": f"0x{(int(cache_size)<<3):08X}"
                            }
                        }
                    }, 
                    "programmer": {
                        "MODULE": programmers[0],
                        "PARAMETERS": {
                            "CLOCK_FREQ_MHZ": int(freq),
                            "UART_BAUD_RATE_BPS": int(uart)
                        }
                    }, 
                    "chip_manager": {"MODULE" : "jtag_chip_manager"}, 
                    "cache": {
                        "MODULE": cache, 
                        "PARAMETERS": {
                            "MEMORY_SIZE": int(cache_size) >> 7
                        }
                    }
                }, 
                "INTRINSICS": {
                    "ASSIGNMENT": [
                    {
                        "CUSTOM_SIGNAL_NAME": "CUSTOM:jtag_reset",
                        "CUSTOM_SIGNAL_WIDTH": 1,
                        "INPUT_SIGNAL": "MODULE:chip_manager:control",
                        "SIGNAL_BITS": "[0]"
                    },
                    {
                        "CUSTOM_SIGNAL_NAME": "CUSTOM:reprogram",
                        "CUSTOM_SIGNAL_WIDTH": 1,
                        "INPUT_SIGNAL": "MODULE:chip_manager:control",
                        "SIGNAL_BITS": "[1]"
                    }
                    ],
                    "COMBINATIONAL": [
                        {
                            "CUSTOM_SIGNAL_NAME": "CUSTOM:cpu_resetn",
                            "CUSTOM_SIGNAL_WIDTH": 1,
                            "INPUT_SIGNAL_1": "1'd1",
                            "INPUT_SIGNAL_2": "CUSTOM:reprogram",
                            "OPERATION": "^"
                        },
                        {
                            "CUSTOM_SIGNAL_NAME": "CUSTOM:cpu_mem_wvalid_and_wready",
                            "CUSTOM_SIGNAL_WIDTH": 1,
                            "INPUT_SIGNAL_1": "MODULE:cpu:mem:axi_wvalid",
                            "INPUT_SIGNAL_2": "MODULE:cpu:mem:axi_wready",
                            "OPERATION": "&"
                        },
                        {
                            "CUSTOM_SIGNAL_NAME": "CUSTOM:cpu_mem_wvalid_and_wready_resetn",
                            "CUSTOM_SIGNAL_WIDTH": 1,
                            "INPUT_SIGNAL_1": "CUSTOM:cpu_mem_wvalid_and_wready",
                            "INPUT_SIGNAL_2": "CUSTOM:cpu_resetn",
                            "OPERATION": "&"
                        }
                    ],
                    "SEQUENTIAL_HOLD": [
                        {
                            "CLOCK": "MODULE:cpu:clk",
                            "CUSTOM_SIGNAL_DEFAULT_VALUE": 0,
                            "CUSTOM_SIGNAL_NAME": "CUSTOM:cpu_axi_araddr",
                            "CUSTOM_SIGNAL_WIDTH": "PARAMETER:cpu:ADDR_WIDTH",
                            "HOLD_VALUE": "MODULE:cpu:mem:axi_araddr",
                            "INTERNAL_SIGNAL_NAME": "INTERNAL:CUSTOM:cpu_axi_araddr",
                            "TRIGGER": "MODULE:cpu:mem:axi_arvalid"
                        },
                        {
                            "CLOCK": "MODULE:cpu:clk",
                            "CUSTOM_SIGNAL_DEFAULT_VALUE": 0,
                            "CUSTOM_SIGNAL_NAME": "CUSTOM:cpu_axi_awaddr",
                            "CUSTOM_SIGNAL_WIDTH": "PARAMETER:cpu:ADDR_WIDTH",
                            "HOLD_VALUE": "MODULE:cpu:mem:axi_awaddr",
                            "INTERNAL_SIGNAL_NAME": "INTERNAL:CUSTOM:cpu_axi_awaddr",
                            "TRIGGER": "MODULE:cpu:mem:axi_awvalid"
                        }
                    ],
                    "SEQUENTIAL_IFELSEIF": [
                        {
                            "ASSIGNMENT_IF_CONDITION_1_TRUE": "1",
                            "ASSIGNMENT_IF_CONDITION_2_TRUE": "0",
                            "CLOCK": "MODULE:cpu:clk",
                            "CONDITION_1": "CUSTOM:cpu_mem_wvalid_and_wready_resetn",
                            "CONDITION_2": "MODULE:cpu:mem:b_ready",
                            "CUSTOM_SIGNAL_DEFAULT_VALUE": 0,
                            "CUSTOM_SIGNAL_NAME": "CUSTOM:cpu_mem_b_valid",
                            "CUSTOM_SIGNAL_WIDTH": 1
                        }
                    ]
                }, 
                "INTERCONNECT": {
                    "STATIC": [
                        ["CUSTOM:jtag_reset" , "MODULE:chip_manager:rst", "MODULE:cache:rst"],
                        ["CUSTOM:reprogram", "MODULE:programmer:reprogram"],
                        ["CUSTOM:cpu_resetn","MODULE:cpu:resetn"],
                        ["BOARD:uart_rx" , "MODULE:programmer:urx"],
                        ["BOARD:clk_i", "MODULE:cpu:clk","MODULE:cache:clk","MODULE:chip_manager:clk","MODULE:programmer:clk"]
                    ], 
                    "OVERRIDES": [
                                    ["MODULE:cpu:mem:b_valid","CUSTOM:cpu_mem_b_valid"],
                                    ["MODULE:cpu:mem:b_response", "0"],
                                    ["MODULE:chip_manager:a:b_response", "0"],
                                    ["MODULE:chip_manager:a:b_valid", "1"],
                                    ["MODULE:programmer:a:b_response", "0"],
                                    ["MODULE:programmer:a:b_valid", "1"],
                                    ["MODULE:cpu:irq", "0"],
                                    ["MODULE:chip_manager:a:axi_rvalid","0"],
                                    ["MODULE:chip_manager:a:axi_arready","0"],
                                    ["MODULE:chip_manager:a:axi_awready","0"],
                                    ["MODULE:chip_manager:a:axi_wready","0"],
                                    ["MODULE:chip_manager:a:b_valid","0"]
                    ], 
                    "DYNAMIC": {
                        "MODULE:cpu:mem": {       
                            "GROUP_SELECT" : "CUSTOM:reprogram",
                            "HANDSHAKES" : ["WRITE_ADDRESS", "WRITE_DATA", "READ_ADDRESS", "READ_DATA"],
                            "GROUPS":[
                                {
                                    "INTERCONNECT_TYPE" : "ONE_TO_MANY",
                                    "SELECT_VALUE" : 0,
                                    "ADDRESS_MAP": [
                                        "SYSTEM:INSTANTIATIONS.cpu.MAP.cache MODULE:cache:cpu"
                                    ],
                                    "HANDSHAKE_MAP" : [
                                                "WRITE_ADDRESS MODULE:cpu:mem:axi_awaddr",
                                                "READ_ADDRESS MODULE:cpu:mem:axi_araddr",
                                                "WRITE_DATA CUSTOM:cpu_axi_awaddr",
                                                "READ_DATA CUSTOM:cpu_axi_araddr"
                                    ]
                                },
                                {
                                    "INTERCONNECT_TYPE": "ONE_TO_MANY",
                                    "SELECT_VALUE": 1,
                                    "ADDRESS_MAP": [],
                                    "HANDSHAKE_MAP": [
                                                "WRITE_ADDRESS MODULE:cpu:mem:axi_awaddr",
                                                "READ_ADDRESS MODULE:cpu:mem:axi_araddr",
                                                "WRITE_DATA CUSTOM:cpu_axi_awaddr",
                                                "READ_DATA CUSTOM:cpu_axi_araddr"
                                    ]
                                }
                            ]
                        },
                        "MODULE:programmer:a": {
                            "GROUP_SELECT": "",
                            "HANDSHAKES": ["WRITE_ADDRESS","WRITE_DATA"],
                            "GROUPS": [{
                                "INTERCONNECT_TYPE": "ONE_TO_ONE",
                                "INTERFACE": "MODULE:cache:cpu"
                            }]
                        },
                        "MODULE:cache:cpu": {
                            "GROUP_SELECT": "CUSTOM:reprogram",
                            "HANDSHAKES": ["WRITE_ADDRESS","WRITE_DATA","READ_ADDRESS","READ_DATA"],
                            "GROUPS": [
                                {"INTERCONNECT_TYPE": "ONE_TO_ONE","INTERFACE": "MODULE:cpu:mem","SELECT_VALUE": 0},
                                { "INTERCONNECT_TYPE": "ONE_TO_ONE","INTERFACE": "MODULE:programmer:a","SELECT_VALUE": 1}
                            ],
                        }
                    }
                }}
    


    mmap = int(cache_size) << 3
    if mmu["gpio_axi"]:
        config["EXTERNAL_IO"]["PORTS"].append('sw')
        config["EXTERNAL_IO"]["PORTS"].append('led')
        config["INSTANTIATIONS"]["cpu"]["MAP"]["gpio"] = {"ORIGIN": f"0x{(int(mmap)):08X}", "LENGTH": "0x00000004"}
        config["INSTANTIATIONS"]["gpio"] = {"MODULE": "gpio_axi"}
        mmap += 4
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:gpio_a_axi_awaddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:gpio:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:gpio:a:axi_awaddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.gpio.ORIGIN",
                "OPERATION": "-"
            })
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:gpio_a_axi_araddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:gpio:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:gpio:a:axi_araddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.gpio.ORIGIN",
                "OPERATION": "-"
            })
        for i in range(len(config["INTERCONNECT"]["STATIC"])):
            conn = config["INTERCONNECT"]["STATIC"][i]
            if "CUSTOM:reprogram" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:gpio:rst")
            if "BOARD:clk_i" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:gpio:clk")
        config["INTERCONNECT"]["STATIC"].append(["BOARD:led" ,"MODULE:gpio:led"])
        config["INTERCONNECT"]["STATIC"].append(["BOARD:sw" , "MODULE:gpio:sw"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:gpio:a:axi_awaddr","CUSTOM:gpio_a_axi_awaddr"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:gpio:a:axi_araddr","CUSTOM:gpio_a_axi_araddr"])
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:gpio:a"] =  {"GROUPS": [{"INTERCONNECT_TYPE": "ONE_TO_ONE","INTERFACE": "MODULE:cpu:mem","SELECT_VALUE": "Memory Mapped"}],"GROUP_SELECT": "","HANDSHAKES": ["WRITE_ADDRESS","WRITE_DATA","READ_ADDRESS","READ_DATA"]}
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][0]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.gpio MODULE:gpio:a")
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][1]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.gpio MODULE:gpio:a")

    if mmu["uart_axi"]:
        config["EXTERNAL_IO"]["PORTS"].append('uart_tx')
        config["INSTANTIATIONS"]["cpu"]["MAP"]["debug"] = {"ORIGIN": f"0x{(int(mmap)):08X}", "LENGTH": "0x00000004"}
        mmap += 4
        config["INSTANTIATIONS"]["debug"] = {"MODULE": "uart_axi", "PARAMETERS": {"CLOCK_FREQ_MHZ": int(freq), "UART_BAUD_RATE_BPS": int(uart), "DATA_WIDTH": 32}}
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:debug_a_axi_awaddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:debug:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:debug:a:axi_awaddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.debug.ORIGIN",
                "OPERATION": "-"
            })
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:debug_a_axi_araddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:debug:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:debug:a:axi_araddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.debug.ORIGIN",
                "OPERATION": "-"
            })
        for i in range(len(config["INTERCONNECT"]["STATIC"])):
            conn = config["INTERCONNECT"]["STATIC"][i]
            if "CUSTOM:reprogram" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:debug:rst")
            if "BOARD:clk_i" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:debug:clk")
            if "BOARD:uart_rx" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:debug:urx")
        config["INTERCONNECT"]["STATIC"].append(["BOARD:uart_tx" , "MODULE:debug:utx"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:debug:a:axi_awaddr","CUSTOM:debug_a_axi_awaddr"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:debug:a:axi_araddr","CUSTOM:debug_a_axi_araddr"])
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:debug:a"] =  {"GROUPS": [{"INTERCONNECT_TYPE": "ONE_TO_ONE","INTERFACE": "MODULE:cpu:mem","SELECT_VALUE": "Memory Mapped"}],"GROUP_SELECT": "","HANDSHAKES": ["WRITE_ADDRESS","WRITE_DATA","READ_ADDRESS","READ_DATA"]}
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][0]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.debug MODULE:debug:a")
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][1]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.debug MODULE:debug:a")

    

    if mmu["timer_axi"]:
        config["INSTANTIATIONS"]["cpu"]["MAP"]["timer"] = {"ORIGIN": f"0x{(int(mmap)):08X}", "LENGTH": "0x00000004"}
        mmap += 4
        config["INSTANTIATIONS"]["timer"] = {"MODULE": "timer_axi", "PARAMETERS": {"CLOCK_FREQ_MHZ": int(freq)}}
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:timer_a_axi_awaddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:timer:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:timer:a:axi_awaddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.timer.ORIGIN",
                "OPERATION": "-"
            })
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:timer_a_axi_araddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:timer:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:timer:a:axi_araddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.timer.ORIGIN",
                "OPERATION": "-"
            })
        for i in range(len(config["INTERCONNECT"]["STATIC"])):
            conn = config["INTERCONNECT"]["STATIC"][i]
            if "CUSTOM:reprogram" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:timer:rst")
            if "BOARD:clk_i" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:timer:clk")
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:timer:a:axi_awaddr","CUSTOM:timer_a_axi_awaddr"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:timer:a:axi_araddr","CUSTOM:timer_a_axi_araddr"])
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:timer:a"] =  {"GROUPS": [{"INTERCONNECT_TYPE": "ONE_TO_ONE","INTERFACE": "MODULE:cpu:mem","SELECT_VALUE": "Memory Mapped"}],"GROUP_SELECT": "","HANDSHAKES": ["WRITE_ADDRESS","WRITE_DATA","READ_ADDRESS","READ_DATA"]}
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][0]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.timer MODULE:timer:a")
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][1]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.timer MODULE:timer:a")


    if mmu["i2c_axi"]:
        config["EXTERNAL_IO"]["PORTS"].append('i2c')
        config["INSTANTIATIONS"]["cpu"]["MAP"]["i2cbus"] = {"ORIGIN": f"0x{(int(mmap)):08X}", "LENGTH": "0x00000004"}
        mmap += 4
        config["INSTANTIATIONS"]["i2cbus"] = {"MODULE": "i2c_axi", "PARAMETERS": {"CLOCK_FREQ_MHZ": int(freq)}}
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:i2cbus_a_axi_awaddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:i2cbus:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:i2cbus:a:axi_awaddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.i2cbus.ORIGIN",
                "OPERATION": "-"
            })
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:i2cbus_a_axi_araddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:i2cbus:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:i2cbus:a:axi_araddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.i2cbus.ORIGIN",
                "OPERATION": "-"
            })
        for i in range(len(config["INTERCONNECT"]["STATIC"])):
            conn = config["INTERCONNECT"]["STATIC"][i]
            if "CUSTOM:reprogram" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:i2cbus:rst")
            if "BOARD:clk_i" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:i2cbus:clk")
        config["INTERCONNECT"]["STATIC"].append(["BOARD:i2c","MODULE:i2cbus:i2c"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:i2cbus:a:axi_awaddr","CUSTOM:i2cbus_a_axi_awaddr"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:i2cbus:a:axi_araddr","CUSTOM:i2cbus_a_axi_araddr"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:i2cbus:a:b_ready","1"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:i2cbus:i2c:sda","BOARD:i2c:sda"])
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:i2cbus:a"] =  {"GROUPS": [{"INTERCONNECT_TYPE": "ONE_TO_ONE","INTERFACE": "MODULE:cpu:mem","SELECT_VALUE": "Memory Mapped"}],"GROUP_SELECT": "","HANDSHAKES": ["WRITE_ADDRESS","WRITE_DATA","READ_ADDRESS","READ_DATA"]}
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][0]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.i2cbus MODULE:i2cbus:a")
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][1]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.i2cbus MODULE:i2cbus:a")


    if mmu["spi_axi"]:
        config["EXTERNAL_IO"]["PORTS"].append('spi')
        config["INSTANTIATIONS"]["cpu"]["MAP"]["spibus"] = {"ORIGIN": f"0x{(int(mmap)):08X}", "LENGTH": "0x00000004"}
        mmap += 4
        config["INSTANTIATIONS"]["spibus"] = {"MODULE": "spi_axi", "PARAMETERS": {"CLOCK_FREQ_MHZ": int(freq),"SPI_FREQ_MHZ": int(spi)}}
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:spibus_a_axi_awaddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:spibus:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:spibus:a:axi_awaddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.spibus.ORIGIN",
                "OPERATION": "-"
            })
        config["INTRINSICS"]["COMBINATIONAL"].append(
            {
                "CUSTOM_SIGNAL_NAME": "CUSTOM:spibus_a_axi_araddr",
                "CUSTOM_SIGNAL_WIDTH": "PARAMETER:spibus:ADDR_WIDTH",
                "INPUT_SIGNAL_1": "MODULE:spibus:a:axi_araddr",
                "INPUT_SIGNAL_2": "SYSTEM:INSTANTIATIONS.cpu.MAP.spibus.ORIGIN",
                "OPERATION": "-"
            })
        for i in range(len(config["INTERCONNECT"]["STATIC"])):
            conn = config["INTERCONNECT"]["STATIC"][i]
            if "CUSTOM:reprogram" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:spibus:rst")
            if "BOARD:clk_i" == conn[0]:
                config["INTERCONNECT"]["STATIC"][i].append("MODULE:spibus:clk")
        config["INTERCONNECT"]["STATIC"].append(["BOARD:spi","MODULE:spibus:spi"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:spibus:a:axi_awaddr","CUSTOM:spibus_a_axi_awaddr"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:spibus:a:axi_araddr","CUSTOM:spibus_a_axi_araddr"])
        config["INTERCONNECT"]["OVERRIDES"].append(["MODULE:spibus:a:b_ready","1"])
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:spibus:a"] =  {"GROUPS": [{"INTERCONNECT_TYPE": "ONE_TO_ONE","INTERFACE": "MODULE:cpu:mem","SELECT_VALUE": "Memory Mapped"}],"GROUP_SELECT": "","HANDSHAKES": ["WRITE_ADDRESS","WRITE_DATA","READ_ADDRESS","READ_DATA"]}
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][0]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.spibus MODULE:spibus:a")
        config["INTERCONNECT"]["DYNAMIC"]["MODULE:cpu:mem"]["GROUPS"][1]["ADDRESS_MAP"].append("SYSTEM:INSTANTIATIONS.cpu.MAP.spibus MODULE:spibus:a")

    update_config()
    return 'SUCCESS'


app.run(host='localhost', port=8088)






