# usage : python display_modules.py

import toml 
import os
import re
import copy
import sys
import math
from tkinter import *
from tkinter import ttk
from tkinter import filedialog as fd


# Class definitions
class nav:
	def update_listbox(self):
		self.lb["listbox"].delete(0,END)
		self.lb["display_list"] = []
		if self.lb["name"] == "IO":
			for entry in self.lb["parent"]:
				self.lb["display_list"].append(str(entry["id"]) + " " + entry["name"] + " (" + entry["type"] + ")")
		else:
			if isinstance(self.lb["parent"], str):
				self.lb["display_list"].append(self.lb["parent"].keys())
			elif isinstance(self.lb["parent"], list):
				self.lb["display_list"].extend(self.lb["parent"])
			else:
				self.lb["display_list"].extend(list(self.lb["parent"].keys()))

		for idx in range(len(self.lb["display_list"])):
			self.lb["listbox"].insert(idx+1, self.lb["display_list"][idx])

	def on_select(self,evt):
		global prop_type
		global prop_description
		global prop_width
		global prop_direction
		global prop_datawidth
		global prop_addresswidth
		global prop_map
		w = evt.widget
		index = int(w.curselection()[0])
		value = w.get(index)
		if self.lb["name"] == "IO":
			prop_type.e["Textbox"].delete("1.0","end")
			prop_description.e["Textbox"].delete("1.0","end")
			prop_width.e["Textbox"].delete("1.0","end")
			prop_direction.e["Textbox"].delete("1.0","end")
			prop_datawidth.e["Textbox"].delete("1.0","end")
			prop_addresswidth.e["Textbox"].delete("1.0","end")
			prop_map.e["Textbox"].delete("1.0","end")
			for entry in self.lb["parent"]:
				if value ==  (str(entry["id"]) + " " + entry["name"] + " (" + entry["type"] + ")"):
					iomap = entry
					break
			prop_type.e["Textbox"].insert(END, iomap["type"])
			prop_direction.e["Textbox"].insert(END, iomap["direction"])
			if ("description" in iomap.keys()): prop_description.e["Textbox"].insert(END, iomap["description"])
			if ("data_width" in iomap.keys()): prop_datawidth.e["Textbox"].insert(END, iomap["data_width"])
			if ("address_width" in iomap.keys()): prop_addresswidth.e["Textbox"].insert(END, iomap["address_width"])
			if ("width" in iomap.keys()): prop_width.e["Textbox"].insert(END, iomap["width"])
			if ("map" in iomap.keys()): 
				for m in iomap["map"].keys():
					prop_map.e["Textbox"].insert(END, m + " -> " + iomap["map"][m] + "\n")
			else:
				prop_map.e["Textbox"].insert(END, iomap["name"] + " -> " + iomap["name"] + "\n")
		else:
			if self.lb["child"]:
				self.lb["selected"] = value
				self.lb["child"].lb["parent"] = self.lb["parent"][value]
				self.lb["child"].update_listbox()
				prop_type.e["Textbox"].delete("1.0","end")
				prop_description.e["Textbox"].delete("1.0","end")
				prop_width.e["Textbox"].delete("1.0","end")
				prop_direction.e["Textbox"].delete("1.0","end")
				prop_datawidth.e["Textbox"].delete("1.0","end")
				prop_addresswidth.e["Textbox"].delete("1.0","end")
				prop_map.e["Textbox"].delete("1.0","end")
				child_ptr = self.lb["child"].lb["child"]
				while child_ptr:
					child_ptr.lb["listbox"].delete(0,END)
					child_ptr = child_ptr.lb["child"]

	def draw(self, x,y):
		self.lb["listbox"].place(x=x, y=y)
		self.lb["Label"].place(x=x,y=y-22)
		
	def __init__(self, name, parent, child, tk_root):
		self.lb = {}
		self.lb["name"] = name
		self.lb["listbox"] = Listbox(tk_root, selectmode=SINGLE)
		self.lb["scrollbar"] = Scrollbar(tk_root)
		self.lb["listbox"].config(yscrollcommand = self.lb["scrollbar"].set)
		self.lb["scrollbar"].config(command = self.lb["listbox"].yview)
		self.lb["parent"] = parent
		self.lb["child"] = child
		self.lb["selected"] = ""
		self.lb["listbox"].bind('<<ListboxSelect>>', self.on_select)
		self.lb["Label"] = Label(root, text = name, anchor = 'center', relief=FLAT, font='Helvetica 12 bold')



class details:
	def __init__(self, label, x1, y1, w1, h1, x2, y2, w2, h2, tk_root):
		self.e = {}
		self.e["label"] = Label(root, text = label, width=w1, anchor = 'e', font='Helvetica 12 bold')
		self.e["Textbox"] = Text(root,  width=w2, height=h2)
		self.e["label"].place(x=x1, y=y1)
		self.e["Textbox"].place(x=x2, y=y2)


# Function definitions
def load_tml():
	global subsystem
	global file_path
	global hdl
	global tml_file
	try:
		tml_file = file_path.get()
		with open(tml_file) as f:
			hdl = toml.load(f)
		child_ptr = subsystem.lb["child"]
		while child_ptr:
			child_ptr.lb["listbox"].delete(0,END)
			child_ptr = child_ptr.lb["child"]
		subsystem.lb["parent"] = hdl
		subsystem.update_listbox()
	except:
		print("Invalid file")
		
def browse_tml():
	global tml_file
	global file_path
	tml_file = fd.askopenfilename()
	file_path.delete(0,END)
	file_path.insert(END, tml_file)
	load_tml()

def save_tml():
	global file_path
	global hdl
	save_file = file_path.get()
	try:
		with open(save_file, 'w') as f:
			toml.dump(hdl, f)

	except:
		print ("Write failed")


# Generate canvas and initialize variables
hdl = {}
tml_file = ""
root = Tk()
root.geometry("750x900")
root.update()
width = root.winfo_width()
height = root.winfo_height()
root.title("Module Display Tool")



# Instantiate and draw listboxes and property text widgets
io = nav("IO", hdl, "", root)
propertee = nav("Properties", hdl, io, root)
module = nav("Modules", hdl, propertee, root)
file = nav("Files", hdl, module, root)
subsystem = nav("Subsystems", hdl, file, root)
lb_offset_w = -130
lb_offset_h = 230
subsystem.draw(lb_offset_w + width*2/9,80)
file.draw(lb_offset_w + width*4/9,80)
module.draw(lb_offset_w + width*6/9,80)
propertee.draw(lb_offset_w + width*8/9,80)
io.draw(lb_offset_w + width*2/9,lb_offset_h + 100)
prop_description = details("Description:", 		lb_offset_w*4/5 + width*4/9,	lb_offset_h + 100, 15, 1, 	lb_offset_w +  width*6/9,	lb_offset_h + 100, 41, 1,root)
prop_type = details("Type:", 							lb_offset_w*4/5 + width*4/9,	lb_offset_h + 140, 15, 1, 	lb_offset_w +  width*6/9,	lb_offset_h + 140, 41, 1,root)
prop_width = details("Signal Width:", 				lb_offset_w*4/5 + width*4/9,	lb_offset_h + 180, 15, 1, 	lb_offset_w +  width*6/9,	lb_offset_h + 180, 41, 1,root)
prop_direction = details("Direction:", 				lb_offset_w*4/5 + width*4/9,	lb_offset_h + 220, 15, 1, 	lb_offset_w +  width*6/9,	lb_offset_h + 220, 41, 1,root)
prop_datawidth = details("Data Width:", 			lb_offset_w*4/5 + width*4/9,	lb_offset_h + 260, 15, 1, 	lb_offset_w +  width*6/9,	lb_offset_h + 260, 41, 1,root)
prop_addresswidth = details("Address Width:", 	lb_offset_w*4/5 + width*4/9,	lb_offset_h + 300, 15, 1, 	lb_offset_w +  width*6/9,	lb_offset_h + 300, 41, 1,root)
prop_map = details("IO Map:", 							lb_offset_w*4/5 + width*4/9,	lb_offset_h + 455, 15, 1, 	lb_offset_w +  width*6/9,	lb_offset_h + 340, 41, 15,root)



# Browse, load and save TOML file


file_path = Entry(root, width=60) 
file_path.place(x= lb_offset_w +width*3/9, y=14)
load_button = Button(root, text='Load', command=load_tml)
load_button.place(x=lb_offset_w +width*2/9, y=10)
browse_button = Button(root, text='Browse', command=browse_tml)
browse_button.place(x=lb_offset_w+10 +width*9/9, y=10)
save_button = Button(root, text='Browse', command=browse_tml)
save_button.place(x=lb_offset_w+10 +width*9/9, y=10)




subsystem.update_listbox()
root.mainloop()
