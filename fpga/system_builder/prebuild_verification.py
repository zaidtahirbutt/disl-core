
#ddr_controller
# Verifying that the user specified address, data and mask bits are valid (i.e. they must be greater than (generate warning) or equal to this number, but not smaller)
#all_params["USER_ADDR_WIDTH"] = all_params["DDR_BA_WIDTH"] + all_params["DDR_ROW_WIDTH"] + all_params["DDR_COL_WIDTH"]
#all_params["USER_DATA_WIDTH"] = all_params["BURST_SIZE"] * all_params["DQ_BITS"]
#all_params["USER_MASK_WIDTH"] = int(all_params["USER_DATA_WIDTH"]/8)