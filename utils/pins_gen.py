import sys
import os
import toml

board_file = sys.argv[1]
dest_dir = sys.argv[2]


file = []

with open (board_file) as f:
    board = toml.load(f)

for k in board.keys():
    if isinstance(board[k], dict):
        if "pin" in board[k].keys():
            for pin in board[k]["pin"].keys():
                pin_loc = pin
                pin_name = board[k]["pin"][pin]["name"]
                pin_iostandard = board[k]["pin"][pin]["iostandard"]
                file.append("set_property -dict { PACKAGE_PIN " + pin_loc + "  IOSTANDARD " + pin_iostandard + " } [get_ports { " + pin_name + " }]\n")
                
with open(dest_dir + "constraints/pins.xdc", 'w') as f:
    f.writelines(file)
    
                

