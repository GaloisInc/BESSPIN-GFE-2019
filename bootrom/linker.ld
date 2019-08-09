SECTIONS
{
    ROM_BASE = 0x70000000;

    . = ROM_BASE;
    .text : { *(.text.*) }
    .data : { *(.data.*) }
}
