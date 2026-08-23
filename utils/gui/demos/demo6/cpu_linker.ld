MEMORY {
	.cache (rwx) : ORIGIN = 0x00000000, LENGTH = 0x10000000
	.gpio (rwx) : ORIGIN = 0x10000000, LENGTH = 0x00000004
	.debug (rwx) : ORIGIN = 0x10000004, LENGTH = 0x00000004
	.timer (rwx) : ORIGIN = 0x10000008, LENGTH = 0x00000004
	.i2cbus (rwx) : ORIGIN = 0x1000000C, LENGTH = 0x00000004
	.spibus (rwx) : ORIGIN = 0x10000010, LENGTH = 0x00000004
	.cache_config (rwx) : ORIGIN = 0x80000000, LENGTH = 0x00000004
	.dram_config (rwx) : ORIGIN = 0x80000004, LENGTH = 0x10000000
}

SECTIONS {
	.cache : {
		. = 0x0;
		cpu_reset_handler.o;
		start*(.text);
		*(.text);
		*(*);
		end = .;
	}
	.gpio 0x10000000: {PROVIDE(GPIO = .);}
	.debug 0x10000004: {PROVIDE(DEBUG = .);}
	.timer 0x10000008: {PROVIDE(TIMER = .);}
	.i2cbus 0x1000000C: {PROVIDE(I2CBUS = .);}
	.spibus 0x10000010: {PROVIDE(SPIBUS = .);}
	.cache_config 0x80000000: {PROVIDE(CACHE_CONFIG = .);}
	.dram_config 0x80000004: {PROVIDE(DRAM_CONFIG = .);}
}

ENTRY(main)