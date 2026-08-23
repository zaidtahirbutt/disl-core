CPU_NAME = cpu_firmware
SOURCE = cpu_test
CONFIG = rv32i
ABI = ilp32
CROSS = ./build/bin/riscv32-unknown-elf-
CROSSCFLAGS = -O3 -Wno-int-conversion -march=$(CONFIG) -mabi=$(ABI) -ffreestanding #-nostdlib  
CROSSLDFLAGS = -march=$(CONFIG) -mabi=$(ABI) -ffreestanding #-nostdlib  
MODEL = stories15M.bin

.PHONY: all clean toolchain
all: $(CPU_NAME).hex
	
$(CPU_NAME).elf: $(SOURCE).c $(MODEL)
	$(CROSS)gcc $(CROSSCFLAGS) -c  -o     cpu_reset_handler.o cpu_reset_handler.S
	$(CROSS)gcc $(CROSSLDFLAGS) -Wl,-T cpu_linker.ld -o $@     $<  muldi3.S div.S
	
$(CPU_NAME).hex: $(CPU_NAME).elf
	$(CROSS)objcopy -O verilog $< /dev/stdout > $@
	$(CROSS)objdump -S $(CPU_NAME).elf | less > $(CPU_NAME).elf.dump

$(MODEL):
	wget https://huggingface.co/karpathy/tinyllamas/resolve/main/stories15M.bin

clean:
	-rm $(CPU_NAME).elf
	-rm $(CPU_NAME).hex

toolchain:
	git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
	cd riscv-gnu-toolchain && git checkout f62900f19330b0279a74af48366eb2863a9c9196 && ./configure --prefix=$(PWD)/build --with-arch=rv32i  --with-abi=ilp32  && make -j4 && make install