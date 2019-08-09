import targets

class P1Hart(targets.Hart):
    xlen = 32
    ram = 0x80000000
    ram_size = 1024 * 1024 * 1024
    instruction_hardware_breakpoint_count = 2
    # misa = 0x40001105
    link_script_path = "p1.lds"

class P1(targets.Target):
    openocd_config_path = "ssith_gfe.cfg"
    harts = [P1Hart()]
