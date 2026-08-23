.text
.align  2
_start:
	li  sp,0x00000000+0x00040000
	jal main
_hw_shutdown:
	jal _hw_shutdown