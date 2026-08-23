openocd_riscv:
	cp patch/configure openocd_riscv/configure && cp patch/configure.ac openocd_riscv/configure.ac && cp patch/interfaces.c openocd_riscv/src/jtag/interfaces.c && cp patch/commands.h openocd_riscv/src/jtag/commands.h  && cp patch/tcl.c openocd_riscv/src/jtag/tcl.c  && cp patch/Makefile.am openocd_riscv/src/jtag/drivers/Makefile.am && cp patch/emulate.c openocd_riscv/src/jtag/drivers/emulate.c  && cd openocd_riscv && ./bootstrap && ./configure --prefix=$(DIR) --enable-ftdi --enable-dummy  --enable-emulate && make -j8 && make install
	

.PHONY: openocd_riscv
