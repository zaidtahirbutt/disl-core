# usage : python hdl_module_listgen <path_to_hdl_folder> <path_to_tml> <path_to_protocols> -f <FULL RESCAN> -s <SKIP_EXISTING> -v <DEBUG>

import toml 
import os
import re
import copy
import sys
import argparse

parser = argparse.ArgumentParser( prog = 'hdl_module_listgen', description='Parse HDL files and generate Verilog module descriptions')
parser.add_argument('path_to_hdl_folder') 
parser.add_argument('-f', action='store_true',help='Erase output file and recan all modules again') 
parser.add_argument('-o', action='store', help='Path to output TOML file') 
parser.add_argument('-p', action='store',help='Path to file with protocol TOML file') 
parser.add_argument('-s', action='store_true', help='Scan for new modules only')
parser.add_argument('-v', action='store_true', help='Print debug information')

args = parser.parse_args()
HDL_DIR = args.path_to_hdl_folder

FULL_RESCAN = 1 if args.f else 0 
SKIP_EXISTING = 1 if args.s else 0
DEBUG = 1 if args.v else 0
SKIP_PROTOCOLS = 0 if args.p else 1


if not FULL_RESCAN:
	if (DEBUG): print(f"Reading existing configuration - "+ ("will" if SKIP_EXISTING else "will NOT") + " overwrite exsting configuration")
	try:
		if (args.o):
			with open(args.o) as f:
				hdl = toml.load(f)
		else:
			hdl = {}
	except:
		hdl = {}
else:
	if (DEBUG): print(f"Doing a full rescan")
	hdl = {}


if(DEBUG): print("Getting a list of subsystems")
subsystem_list =  [x for x in os.listdir(HDL_DIR) if os.path.isdir(HDL_DIR + x)]
if(DEBUG): print(str(len(subsystem_list)) + " subsystem(s) found")



# Regex patterns 
EXTENSION_REGEX = "\.[0-9A-Za-z]+" 
MODULE_REGEX = r"module ([A-Za-z]+[^\s^\()]*)\s*"
PARAMETER_REGEX = r"parameter\s+([A-Za-z]+[^\s]*)\s*"
INPUT_SCALAR_REGEX = r"input\s+([A-Za-z]+[^\s^\;^\,]*)"
INOUT_SCALAR_REGEX = r"inout\s+([A-Za-z]+[^\s^\;^\,]*)"
OUTPUT_SCALAR_REGEX = r"output\s*r?e?g?\s+([A-Za-z]+[^\s^\;^\,]*)"
INPUT_VECTOR_REGEX = r"input\s+\[\s*([A-Za-z0-9]+[^\s]*)\:\s*([A-Za-z0-9]+[^\s]*)\]\s+([A-Za-z]+[^\s^\;^\,]*)"
INOUT_VECTOR_REGEX = r"inout\s+\[\s*([A-Za-z0-9]+[^\s]*)\:\s*([A-Za-z0-9]+[^\s]*)\]\s+([A-Za-z]+[^\s^\;^\,]*)"
OUTPUT_VECTOR_REGEX = r"output\s*r?e?g?\s+\[\s*([A-Za-z0-9]+[^\s]*)\:\s*([A-Za-z0-9]+[^\s]*)\]\s+([A-Za-z]+[^\s^\;^\,]*)"
CLOCK_REGEX = r"posedge\s+([A-Za-z0-9]+[^\s^\)]*)"



print(f"Generating configuration")

for subsystem in subsystem_list:

	if subsystem not in hdl.keys():
		hdl[subsystem] = {}

	if(DEBUG): print(f"\tGetting files in the {subsystem} directory")
	file_list_with_extension = os.listdir(HDL_DIR + subsystem)

	try:
		if (args.p):
			if (DEBUG): print(f"\tReading protocols")
			with open(args.p) as f:
				protocols = toml.load(f)
	except:
		protocols = {}
		SKIP_PROTOCOLS = 1

	if (DEBUG): print(f"\tStarting configuration generation")
	for idx in range(len(file_list_with_extension)):

		if (DEBUG): print(f"\tProcessing file: {file_list_with_extension[idx]}")
		file_with_extension = file_list_with_extension[idx]
		file_name = re.sub(EXTENSION_REGEX, "", file_with_extension)

		if file_name not in hdl[subsystem].keys():
			hdl[subsystem][file_name] = {}
			if (DEBUG): print(f"\t\tFile not found in existing configuration - creating new entry")

		if (DEBUG): print(f"\t\tReading file")
		with open(HDL_DIR + subsystem + "/" + file_with_extension) as f:
			file = f.readlines()


		if (DEBUG): print(f"\t\tIsolating modules")
		module_name = []
		modules = {}
		for line in file:
			if not module_name:
				module_name = re.findall(MODULE_REGEX, line)
			if module_name and "endmodule" in line:
				modules[module_name[0]].append(line)
				module_name = []
			if module_name and SKIP_EXISTING:
				if module_name[0] in list(hdl[subsystem][file_name].keys()):
					print (f"Skipped:\tModule [{module_name[0]}]\tFile [{file_with_extension}]")
					module_name = []
			if module_name:
				if module_name[0] not in list(modules.keys()):
					modules[module_name[0]] = []
				modules[module_name[0]].append(line)
		
		if (DEBUG): print(f"\t\tFound {len(modules.keys())} module(s): " + ",".join(list(modules.keys())))

		for module in modules.keys():
			if (DEBUG): print(f"\t\tProcessing module: {module}")
			file_str = "".join(modules[module])
			hdl[subsystem][file_name][module] = {"description": "", "parameters": re.findall(PARAMETER_REGEX,file_str), "IO": []}
			input_scalars = re.findall(INPUT_SCALAR_REGEX, file_str)
			inout_scalars = re.findall(INOUT_SCALAR_REGEX, file_str)
			output_scalars = re.findall(OUTPUT_SCALAR_REGEX, file_str)
			output_scalars = [x for x in output_scalars if x != "reg"]
			input_vectors = re.findall(INPUT_VECTOR_REGEX, file_str)
			inout_vectors = re.findall(INOUT_VECTOR_REGEX, file_str)
			output_vectors = re.findall(OUTPUT_VECTOR_REGEX, file_str)
			clocks = list(set(re.findall(CLOCK_REGEX, file_str) ))
			if (DEBUG): print(f"\t\t\tFound " + str(len(hdl[subsystem][file_name][module]["parameters"])) + " parameter(s): " + ",".join(hdl[subsystem][file_name][module]["parameters"]))
			if (DEBUG): print(f"\t\t\tFound " + str(len(input_scalars)) + " scalar input(s): " + ",".join(input_scalars))
			if (DEBUG): print(f"\t\t\tFound " + str(len(input_vectors)) + " vector input(s): " +",".join([x[2] for x in input_vectors]))
			if (DEBUG): print(f"\t\t\tFound " + str(len(inout_scalars)) + " scalar inout(s): " + ",".join(inout_scalars))
			if (DEBUG): print(f"\t\t\tFound " + str(len(inout_vectors)) + " vector inout(s): " + ",".join([x[2] for x in inout_vectors]))
			if (DEBUG): print(f"\t\t\tFound " + str(len(output_scalars)) + " scalar output(s): " + ",".join(output_scalars))
			if (DEBUG): print(f"\t\t\tFound " + str(len(output_vectors)) + " vector output(s): " + ",".join([x[2] for x in output_vectors]))
			if (DEBUG): print(f"\t\t\tFound " + str(len(clocks)) + " possible clock(s): " + ",".join(clocks))			

			try:
				if not SKIP_PROTOCOLS:
					if (DEBUG): print(f"\t\t\tSearching for protocols")
					all_signals = []
					all_signals.extend(input_scalars)
					all_signals.extend(output_scalars)
					all_signals.extend([x[2] for x in input_vectors])
					all_signals.extend([x[2] for x in output_vectors])
					possible_protocol_signals = {}
					for signal in all_signals:
						for protocol in protocols:
							for k in protocols[protocol]["Ports"].keys():
								if k in signal:
									if k == signal:
										prefix = ""
									else:
										prefix = signal.split(k)[0]
									if protocol not in possible_protocol_signals.keys():
										possible_protocol_signals[protocol] = {"Prefixes": [], "Signal Tuples": []}
									if prefix not in possible_protocol_signals[protocol]["Prefixes"]:
										possible_protocol_signals[protocol]["Prefixes"].append(prefix)
									if (prefix,signal) not in possible_protocol_signals[protocol]["Signal Tuples"]:
										possible_protocol_signals[protocol]["Signal Tuples"].append((prefix,signal))

					if (DEBUG): print(f"\t\t\t Found " + str(len(possible_protocol_signals.keys())) + " possible protocol(s)")
					if (DEBUG): print(f"\t\t\t Attempting to remove invalid protocol search results")

					detected_protocols = {}
					for protocol in possible_protocol_signals:
						for prefix in possible_protocol_signals[protocol]["Prefixes"]:
							signals = []
							for signal_tuple in possible_protocol_signals[protocol]["Signal Tuples"]:
								if signal_tuple[0] == prefix:
									signals.append(copy.deepcopy(signal_tuple[1]))
							skip = 0
							for k in protocols[protocol]["Ports"]:
								for signal in signals:
									if k in signal:
										skip -=1
										break
								skip += 1
							if skip <= protocols[protocol]["Protocol_Skip_Threshold"]:
								if protocol not in detected_protocols.keys():
									detected_protocols[protocol] = []
								detected_protocols[protocol].append({"Prefix": prefix, "Signals": copy.deepcopy(signals)}) 

					if (DEBUG): print(f"\t\t\t Completed - " + str(len(detected_protocols.keys())) + " protocol(s) remaining")
					if (DEBUG): print(f"\t\t\tGenerating protocol based IO configuration")

					for protocol in detected_protocols.keys():
						for group in detected_protocols[protocol]:
							prefix = group["Prefix"] 
							IO = {"id": 0, "name": prefix, "type": protocol, "direction": "" , "data_width": "", "address_width": "", "map": {}}
							for signal in protocols[protocol]["Ports"].keys():
								IO["map"][signal] = ""
								for signal_full in group["Signals"]:
									if signal in signal_full:
										IO["map"][signal] = signal_full
							for signal in IO["map"].keys():
								if IO["map"][signal] == "": continue
								if IO["direction"]: continue
								if (prefix+signal in input_scalars) or (prefix+signal in [x[2] for x in input_vectors]):
									if protocols[protocol]["Ports"][signal] == protocols[protocol]["SignalMap"]["Input"]["From_Module"]:
										IO["direction"] = "From_Module"
									else:
										IO["direction"] = "To_Module"
								else:						
									if protocols[protocol]["Ports"][signal] == protocols[protocol]["SignalMap"]["Output"]["From_Module"]:
										IO["direction"] = "From_Module"
									else:
										IO["direction"] = "To_Module"

							for signal in IO["map"].keys():
								if IO["map"][signal] == "": continue
								if IO["address_width"]: continue
								if signal not in protocols[protocol]["SignalMap"]["Address"]: continue
								if IO["direction"] == "To_Module":
									if (prefix+signal in input_scalars):
										IO["address_width"] = 1
									else:
										vector = [x for x in input_vectors if (x[2] == prefix+signal)][0]
										IO["address_width"] = str(vector[0]) + "+1-" + str(vector[1])
								else:
									if (prefix+signal in output_scalars):
										IO["address_width"] = 1
									else:
										vector = [x for x in output_vectors if (x[2] == prefix+signal)][0]
										IO["address_width"] = str(vector[0]) + "+1-" + str(vector[1])

							for signal in IO["map"].keys():
								if IO["map"][signal] == "": continue
								if IO["data_width"]: continue
								if signal not in protocols[protocol]["SignalMap"]["Data"]: continue
								if (prefix+signal in input_scalars):
									IO["data_width"] = 1
								elif (prefix+signal in [x[2] for x in input_vectors]):
									vector = [x for x in input_vectors if (x[2] == prefix+signal)][0]
									IO["data_width"] = str(vector[0]) + "+1-" + str(vector[1])
								elif (prefix+signal in output_scalars):
									IO["data_width"] = 1
								else:
									vector = [x for x in output_vectors if (x[2] == prefix+signal)][0]
									IO["data_width"] = str(vector[0]) + "+1-" + str(vector[1])

							hdl[subsystem][file_name][module]["IO"].append(copy.deepcopy(IO))


					if (DEBUG): print(f"\t\t\tCompleted successfully - removing protocol signal redundancy")
					for protocol in detected_protocols.keys():
						for group in detected_protocols[protocol]:
							prefix = group["Prefix"]
							for signal in group["Signals"]:
								input_scalars = [x for x in input_scalars if (x != signal)]
								output_scalars = [x for x in output_scalars if (x != signal)]
								input_vectors = [x for x in input_vectors if (x[2] != signal)]
								output_vectors = [x for x in output_vectors if (x[2] != signal)]
								clocks = [x for x in clocks if (x != signal)]
					if (DEBUG): print(f"\t\t\tWriting remaining signals")

			except Exception as e: 
				if (DEBUG): print(f"\t\t\tError:", end=" ")
				if (DEBUG): print(e)
				if (DEBUG): print("\t\t\tTreating all signals as General")

			for scalar in input_scalars:
				hdl[subsystem][file_name][module]["IO"].append({"id": 0, "name": scalar, "type": "General" if not scalar in clocks else "Clock", "width": 1, "direction": "To_Module", "description": ""})
			for scalar in inout_scalars:
				hdl[subsystem][file_name][module]["IO"].append({"id": 0, "name": scalar, "type": "General", "width": 1, "direction": "BiDir", "description": ""})
			for scalar in output_scalars:
				hdl[subsystem][file_name][module]["IO"].append({"id": 0, "name": scalar, "type": "General" if not scalar in clocks else "Clock", "width": 1, "direction": "From_Module", "description": ""})
			for vector in input_vectors:
				hdl[subsystem][file_name][module]["IO"].append({"id": 0, "name": vector[2], "type": "General", "width": str(vector[0]) + "+1-" + str(vector[1]), "direction": "To_Module", "description": ""})
			for vector in inout_vectors:
				hdl[subsystem][file_name][module]["IO"].append({"id": 0, "name": vector[2], "type": "General", "width": str(vector[0]) + "+1-" + str(vector[1]), "direction": "BiDir", "description": ""})
			for vector in output_vectors:
				hdl[subsystem][file_name][module]["IO"].append({"id": 0, "name": vector[2], "type": "General", "width": str(vector[0]) + "+1-" + str(vector[1]), "direction": "From_Module", "description": ""})

			id_counter = 0
			for io in hdl[subsystem][file_name][module]["IO"]:
				io["id"] = id_counter
				id_counter += 1
				if io["name"] == "":
					io["name"] = "<unnamed>"
			if (DEBUG): print(f"\t\t\tModule configuration generated successfully")
			


print(f"Writing updated configuration to file")
if (args.o):
	with open(args.o, 'w') as f:
		toml.dump(hdl, f)
else:
	with open('./hdl.tml', 'w') as f:
		toml.dump(hdl, f)


print(f"Done!")