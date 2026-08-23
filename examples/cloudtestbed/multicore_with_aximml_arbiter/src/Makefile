CPU_NAME = cpu
SOURCE = cpu_test
CONFIG = rv32i
ABI = ilp32
CROSS = riscv64-linux-gnu-
CROSSCFLAGS = -O3 -Wno-int-conversion -march=$(CONFIG) -mabi=$(ABI) -ffreestanding -nostdlib  
CROSSLDFLAGS = -march=$(CONFIG) -mabi=$(ABI) -ffreestanding -nostdlib  

.PHONY: all
all: $(CPU_NAME).hex
	
$(CPU_NAME).elf: $(SOURCE).c
	$(CROSS)gcc $(CROSSCFLAGS) -c  -o     $(CPU_NAME)_reset_handler.o $(CPU_NAME)_reset_handler.S
	$(CROSS)gcc $(CROSSLDFLAGS) -Wl,-T $(CPU_NAME)_linker.ld -o $@     $<  muldi3.S div.S
	
$(CPU_NAME).hex: $(CPU_NAME).elf
	$(CROSS)objcopy -O verilog $< /dev/stdout > $@
	$(CROSS)objdump -S $(CPU_NAME).elf | less > $(CPU_NAME).elf.dump
