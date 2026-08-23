MEMORY {
	.cache (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00040000
	.gpio (rwx) : ORIGIN = 0x00040000, LENGTH = 0x00000004
	.debug (rwx) : ORIGIN = 0x00040004, LENGTH = 0x00000004
	.timer (rwx) : ORIGIN = 0x00040008, LENGTH = 0x00000004
	.i2cbus (rwx) : ORIGIN = 0x0004000C, LENGTH = 0x00000004
	.spibus (rwx) : ORIGIN = 0x00040010, LENGTH = 0x00000004
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
	.gpio 0x00040000: {PROVIDE(GPIO = .);}
	.debug 0x00040004: {PROVIDE(DEBUG = .);}
	.timer 0x00040008: {PROVIDE(TIMER = .);}
	.i2cbus 0x0004000C: {PROVIDE(I2CBUS = .);}
	.spibus 0x00040010: {PROVIDE(SPIBUS = .);}
}

ENTRY(main)