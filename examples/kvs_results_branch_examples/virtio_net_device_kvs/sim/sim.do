vlib libraries


vlog +acc=npr -64 -incr \
"../../../fpga/common/hdl/bram_simple.v" \
"../../../fpga/common/hdl/bram_axi.v" \
"../../../fpga/common/hdl/crc16.v" \


vlog +acc=npr -64 -incr -sv \
"../../../fpga/common/hdl/defines_pkg.sv" \
"../../../fpga/common/hdl/kvs.sv" \
"../tb/tb_kvs.sv" \



set TOP_LEVEL_NAME tb_kvs

vsim -voptargs=+acc work.tb_kvs

# add wave -depth 1 *
# view structure
# view signals
# run 1000ns
