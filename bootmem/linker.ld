SECTIONS
{
    ROM_BASE = 0x44000000;

    . = ROM_BASE;
    .text : { *(.text.*) }
    .data : { *(.data.*) }
}
