.text
.align  2
_start:
	li  sp,0x00000000+0x10000000
	j main
_hw_shutdown:
	jal _hw_shutdown