CPU_NAME = cpu_firmware
SOURCE = cpu_test
CONFIG = rv32iv_zicsr
ABI = ilp32
CROSS = riscv64-linux-gnu-
CROSSCFLAGS = -O3 -Wno-int-conversion -march=$(CONFIG) -mabi=$(ABI) -ffreestanding -nostdlib  
CROSSLDFLAGS = -march=$(CONFIG) -mabi=$(ABI) -ffreestanding -nostdlib  

.PHONY: all clean toolchain
all: $(CPU_NAME).hex
	
$(CPU_NAME).elf: $(SOURCE).c
	$(CROSS)gcc $(CROSSCFLAGS) -c  -o     cpu_reset_handler.o cpu_reset_handler.S
	$(CROSS)gcc $(CROSSLDFLAGS) -Wl,-T cpu_linker.ld -o $@     $<  muldi3.S div.S
	
$(CPU_NAME).hex: $(CPU_NAME).elf
	$(CROSS)objcopy -O verilog $< /dev/stdout > $@
	$(CROSS)objdump -S $(CPU_NAME).elf | less > $(CPU_NAME).elf.dump

clean:
	-rm $(CPU_NAME).elf
	-rm $(CPU_NAME).hex