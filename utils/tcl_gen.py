import sys
import os
import toml

example = sys.argv[1]
src_file = sys.argv[2]
board_file = sys.argv[3]
dest_dir = sys.argv[4]

with open(src_file) as f:
	config = toml.load(f)

with open(board_file) as f:
	board = toml.load(f)

tcl = {"create_project": [], "add_files": [], "add_ip": [], "compile": []}

tcl["create_project"].append("create_project -force " + example + " " + dest_dir + "project/ " + "-part " + board["description"]["part_name_long"] + "\n")

for file in tcl.keys():
	with open(dest_dir + "tcl/" + file + ".tcl", 'w') as f:
		f.writelines(tcl[file])