ENTRY(_start)
SECTIONS
{
    . = 0x0;
    .text : { *(.text.start) *(.text*) }
    . = 0x10000000;
    .rodata : { *(.rodata*) *(.srodata*) }
    .data : { *(.data*) *(.sdata*) }
    .bss : { *(.sbss*) *(.bss*) *(COMMON) }
}
