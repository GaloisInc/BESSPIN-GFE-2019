
################################################################
# This is a generated script based on design: design_1
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2017.4
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_msg_id "BD_TCL-109" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source design_1_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcvu9p-flga2104-2L-e
   set_property BOARD_PART xilinx.com:vcu118:part0:2.0 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name design_1

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_msg_id "BD_TCL-001" "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_msg_id "BD_TCL-002" "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_msg_id "BD_TCL-003" "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_msg_id "BD_TCL-004" "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_msg_id "BD_TCL-005" "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_msg_id "BD_TCL-114" "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
Galois:user:iobuf:1.0\
ssith:user:ssith_processor:1.0\
ssith:user:xilinx_jtag:1.0\
xilinx.com:ip:axi_bram_ctrl:4.0\
xilinx.com:ip:axi_clock_converter:2.1\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:axi_ethernet:7.1\
xilinx.com:ip:axi_gpio:2.0\
xilinx.com:ip:axi_quad_spi:3.2\
xilinx.com:ip:axi_uart16550:2.0\
xilinx.com:ip:blk_mem_gen:8.4\
xilinx.com:ip:ddr4:2.2\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:xlslice:1.0\
xilinx.com:ip:clk_wiz:5.4\
bluespec:user:ibufds_gte4:1.0\
bluespec:user:mkSVF_Bridge:1.0\
xilinx.com:ip:pcie4_uscale_plus:1.3\
user.org:user:param_iobuf:1.0\
xilinx.com:ip:axi_iic:2.0\
"

   set list_ips_missing ""
   common::send_msg_id "BD_TCL-006" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_msg_id "BD_TCL-115" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_msg_id "BD_TCL-1003" "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: axi_quad_spi1
proc create_hier_cell_axi_quad_spi1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_axi_quad_spi1() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 AXI_LITE

  # Create pins
  create_bd_pin -dir O -type intr ip2intc_irpt
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir IO spi_miso
  create_bd_pin -dir IO spi_mosi
  create_bd_pin -dir IO spi_sck
  create_bd_pin -dir IO spi_ss

  # Create instance: axi_quad_spi_1, and set properties
  set axi_quad_spi_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi_1 ]
  set_property -dict [ list \
   CONFIG.C_FIFO_DEPTH {0} \
   CONFIG.C_SCK_RATIO {16} \
   CONFIG.FIFO_INCLUDED {0} \
   CONFIG.Multiples16 {31} \
 ] $axi_quad_spi_1

  # Create instance: iobuf_0, and set properties
  set iobuf_0 [ create_bd_cell -type ip -vlnv Galois:user:iobuf:1.0 iobuf_0 ]

  # Create instance: iobuf_1, and set properties
  set iobuf_1 [ create_bd_cell -type ip -vlnv Galois:user:iobuf:1.0 iobuf_1 ]

  # Create instance: iobuf_2, and set properties
  set iobuf_2 [ create_bd_cell -type ip -vlnv Galois:user:iobuf:1.0 iobuf_2 ]

  # Create instance: iobuf_3, and set properties
  set iobuf_3 [ create_bd_cell -type ip -vlnv Galois:user:iobuf:1.0 iobuf_3 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins AXI_LITE] [get_bd_intf_pins axi_quad_spi_1/AXI_LITE]

  # Create port connections
  connect_bd_net -net Net [get_bd_pins spi_mosi] [get_bd_pins iobuf_0/io]
  connect_bd_net -net Net1 [get_bd_pins spi_miso] [get_bd_pins iobuf_1/io]
  connect_bd_net -net Net2 [get_bd_pins spi_sck] [get_bd_pins iobuf_2/io]
  connect_bd_net -net Net3 [get_bd_pins spi_ss] [get_bd_pins iobuf_3/io]
  connect_bd_net -net axi_quad_spi_1_io0_o [get_bd_pins axi_quad_spi_1/io0_o] [get_bd_pins iobuf_0/data_i]
  connect_bd_net -net axi_quad_spi_1_io0_t [get_bd_pins axi_quad_spi_1/io0_t] [get_bd_pins iobuf_0/data_t]
  connect_bd_net -net axi_quad_spi_1_io1_o [get_bd_pins axi_quad_spi_1/io1_o] [get_bd_pins iobuf_1/data_i]
  connect_bd_net -net axi_quad_spi_1_io1_t [get_bd_pins axi_quad_spi_1/io1_t] [get_bd_pins iobuf_1/data_t]
  connect_bd_net -net axi_quad_spi_1_ip2intc_irpt [get_bd_pins ip2intc_irpt] [get_bd_pins axi_quad_spi_1/ip2intc_irpt]
  connect_bd_net -net axi_quad_spi_1_sck_o [get_bd_pins axi_quad_spi_1/sck_o] [get_bd_pins iobuf_2/data_i]
  connect_bd_net -net axi_quad_spi_1_sck_t [get_bd_pins axi_quad_spi_1/sck_t] [get_bd_pins iobuf_2/data_t]
  connect_bd_net -net axi_quad_spi_1_ss_o [get_bd_pins axi_quad_spi_1/ss_o] [get_bd_pins iobuf_3/data_i]
  connect_bd_net -net axi_quad_spi_1_ss_t [get_bd_pins axi_quad_spi_1/ss_t] [get_bd_pins iobuf_3/data_t]
  connect_bd_net -net iobuf_0_data_o [get_bd_pins axi_quad_spi_1/io0_i] [get_bd_pins iobuf_0/data_o]
  connect_bd_net -net iobuf_1_data_o [get_bd_pins axi_quad_spi_1/io1_i] [get_bd_pins iobuf_1/data_o]
  connect_bd_net -net iobuf_2_data_o [get_bd_pins axi_quad_spi_1/sck_i] [get_bd_pins iobuf_2/data_o]
  connect_bd_net -net iobuf_3_data_o [get_bd_pins axi_quad_spi_1/ss_i] [get_bd_pins iobuf_3/data_o]
  connect_bd_net -net s_axi_aclk_1 [get_bd_pins s_axi_aclk] [get_bd_pins axi_quad_spi_1/ext_spi_clk] [get_bd_pins axi_quad_spi_1/s_axi_aclk]
  connect_bd_net -net s_axi_aresetn_1 [get_bd_pins s_axi_aresetn] [get_bd_pins axi_quad_spi_1/s_axi_aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: axi_iic0
proc create_hier_cell_axi_iic0 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_axi_iic0() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI

  # Create pins
  create_bd_pin -dir I -type clk ACLK
  create_bd_pin -dir I -type rst ARESETN
  create_bd_pin -dir IO iic0_scl
  create_bd_pin -dir IO iic0_sda
  create_bd_pin -dir O -type intr iic2intc_irpt

  # Create instance: axi_iic_0, and set properties
  set axi_iic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.0 axi_iic_0 ]

  # Create instance: iobuf_0, and set properties
  set iobuf_0 [ create_bd_cell -type ip -vlnv Galois:user:iobuf:1.0 iobuf_0 ]

  # Create instance: iobuf_1, and set properties
  set iobuf_1 [ create_bd_cell -type ip -vlnv Galois:user:iobuf:1.0 iobuf_1 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_iic_0/S_AXI]

  # Create port connections
  connect_bd_net -net ACLK_1 [get_bd_pins ACLK] [get_bd_pins axi_iic_0/s_axi_aclk]
  connect_bd_net -net ARESETN_1 [get_bd_pins ARESETN] [get_bd_pins axi_iic_0/s_axi_aresetn]
  connect_bd_net -net Net [get_bd_pins iic0_scl] [get_bd_pins iobuf_0/io]
  connect_bd_net -net Net1 [get_bd_pins iic0_sda] [get_bd_pins iobuf_1/io]
  connect_bd_net -net axi_iic_0_iic2intc_irpt [get_bd_pins iic2intc_irpt] [get_bd_pins axi_iic_0/iic2intc_irpt]
  connect_bd_net -net axi_iic_0_scl_o [get_bd_pins axi_iic_0/scl_o] [get_bd_pins iobuf_0/data_i]
  connect_bd_net -net axi_iic_0_scl_t [get_bd_pins axi_iic_0/scl_t] [get_bd_pins iobuf_0/data_t]
  connect_bd_net -net axi_iic_0_sda_o [get_bd_pins axi_iic_0/sda_o] [get_bd_pins iobuf_1/data_i]
  connect_bd_net -net axi_iic_0_sda_t [get_bd_pins axi_iic_0/sda_t] [get_bd_pins iobuf_1/data_t]
  connect_bd_net -net iobuf_0_data_o [get_bd_pins axi_iic_0/scl_i] [get_bd_pins iobuf_0/data_o]
  connect_bd_net -net iobuf_1_data_o [get_bd_pins axi_iic_0/sda_i] [get_bd_pins iobuf_1/data_o]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: axi_gpio1
proc create_hier_cell_axi_gpio1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_axi_gpio1() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI

  # Create pins
  create_bd_pin -dir I -type clk ACLK
  create_bd_pin -dir I -type rst ARESETN
  create_bd_pin -dir IO -from 7 -to 0 gpio
  create_bd_pin -dir O -from 7 -to 0 gpio_led

  # Create instance: axi_gpio_1, and set properties
  set axi_gpio_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_1 ]
  set_property -dict [ list \
   CONFIG.C_ALL_INPUTS {0} \
   CONFIG.C_ALL_OUTPUTS {0} \
   CONFIG.C_ALL_OUTPUTS_2 {1} \
   CONFIG.C_GPIO2_WIDTH {8} \
   CONFIG.C_GPIO_WIDTH {8} \
   CONFIG.C_IS_DUAL {1} \
   CONFIG.GPIO2_BOARD_INTERFACE {led_8bits} \
 ] $axi_gpio_1

  # Create instance: param_iobuf_0, and set properties
  set param_iobuf_0 [ create_bd_cell -type ip -vlnv user.org:user:param_iobuf:1.0 param_iobuf_0 ]
  set_property -dict [ list \
   CONFIG.WIDTH {8} \
 ] $param_iobuf_0

  # Create interface connections
  connect_bd_intf_net -intf_net axi_interconnect_0_M12_AXI [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_gpio_1/S_AXI]

  # Create port connections
  connect_bd_net -net ARESETN_1 [get_bd_pins ARESETN] [get_bd_pins axi_gpio_1/s_axi_aresetn]
  connect_bd_net -net Net [get_bd_pins gpio] [get_bd_pins param_iobuf_0/io]
  connect_bd_net -net axi_gpio_1_gpio2_io_o [get_bd_pins gpio_led] [get_bd_pins axi_gpio_1/gpio2_io_o]
  connect_bd_net -net axi_gpio_1_gpio_io_o [get_bd_pins axi_gpio_1/gpio_io_o] [get_bd_pins param_iobuf_0/data_i]
  connect_bd_net -net axi_gpio_1_gpio_io_t [get_bd_pins axi_gpio_1/gpio_io_t] [get_bd_pins param_iobuf_0/data_t]
  connect_bd_net -net ddr4_0_addn_ui_clkout1 [get_bd_pins ACLK] [get_bd_pins axi_gpio_1/s_axi_aclk]
  connect_bd_net -net param_iobuf_0_data_o [get_bd_pins axi_gpio_1/gpio_io_i] [get_bd_pins param_iobuf_0/data_o]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: svf_pcie_bridge
proc create_hier_cell_svf_pcie_bridge { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_svf_pcie_bridge() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 axi_in
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie4_mgt_0
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk

  # Create pins
  create_bd_pin -dir I -type clk CLK
  create_bd_pin -dir I -type rst RST_N
  create_bd_pin -dir I -type rst pcie_perstn

  # Create instance: clk_wiz_1, and set properties
  set clk_wiz_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:5.4 clk_wiz_1 ]
  set_property -dict [ list \
   CONFIG.CLKIN1_JITTER_PS {40.0} \
   CONFIG.CLKOUT1_JITTER {106.624} \
   CONFIG.CLKOUT1_PHASE_ERROR {85.285} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} \
   CONFIG.CLKOUT2_JITTER {98.122} \
   CONFIG.CLKOUT2_PHASE_ERROR {79.008} \
   CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100.000} \
   CONFIG.CLKOUT2_USED {false} \
   CONFIG.MMCM_CLKFBOUT_MULT_F {9.625} \
   CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
   CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
   CONFIG.MMCM_CLKOUT0_DIVIDE_F {9.625} \
   CONFIG.MMCM_CLKOUT1_DIVIDE {1} \
   CONFIG.MMCM_DIVCLK_DIVIDE {2} \
   CONFIG.NUM_OUT_CLKS {1} \
   CONFIG.PRIM_IN_FREQ {250.000} \
   CONFIG.USE_LOCKED {false} \
   CONFIG.USE_RESET {false} \
 ] $clk_wiz_1

  # Create instance: ibufds_gte4_0, and set properties
  set ibufds_gte4_0 [ create_bd_cell -type ip -vlnv bluespec:user:ibufds_gte4:1.0 ibufds_gte4_0 ]

  # Create instance: mkSVF_Bridge_0, and set properties
  set mkSVF_Bridge_0 [ create_bd_cell -type ip -vlnv bluespec:user:mkSVF_Bridge:1.0 mkSVF_Bridge_0 ]

  # Create instance: pcie4_uscale_plus_0, and set properties
  set pcie4_uscale_plus_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:pcie4_uscale_plus:1.3 pcie4_uscale_plus_0 ]
  set_property -dict [ list \
   CONFIG.MSI_X_OPTIONS {MSI-X_External} \
   CONFIG.PCIE_BOARD_INTERFACE {Custom} \
   CONFIG.PF0_CLASS_CODE {070000} \
   CONFIG.PF0_DEVICE_ID {B100} \
   CONFIG.PF0_LINK_STATUS_SLOT_CLOCK_CONFIG {false} \
   CONFIG.PF0_MSIX_CAP_PBA_OFFSET {00005000} \
   CONFIG.PF0_MSIX_CAP_TABLE_OFFSET {00004000} \
   CONFIG.PF0_MSIX_CAP_TABLE_SIZE {004} \
   CONFIG.PF0_SUBSYSTEM_ID {A118} \
   CONFIG.PF0_SUBSYSTEM_VENDOR_ID {1BE7} \
   CONFIG.PF0_Use_Class_Code_Lookup_Assistant {false} \
   CONFIG.PF2_DEVICE_ID {9018} \
   CONFIG.PF3_DEVICE_ID {9018} \
   CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH {X8} \
   CONFIG.REF_CLK_FREQ {100_MHz} \
   CONFIG.RX_PPM_OFFSET {600} \
   CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn} \
   CONFIG.axisten_freq {250} \
   CONFIG.axisten_if_enable_client_tag {true} \
   CONFIG.extended_tag_field {false} \
   CONFIG.mode_selection {Advanced} \
   CONFIG.pf0_bar0_size {32} \
   CONFIG.pf0_base_class_menu {Simple_communication_controllers} \
   CONFIG.pf0_class_code_base {07} \
   CONFIG.pf0_class_code_sub {00} \
   CONFIG.pf0_dev_cap_max_payload {512_bytes} \
   CONFIG.pf0_msi_enabled {false} \
   CONFIG.pf0_msix_enabled {true} \
   CONFIG.pf0_sub_class_interface_menu {Generic_XT_compatible_serial_controller} \
   CONFIG.pf1_bar0_size {32} \
   CONFIG.pf1_vendor_id {1BE7} \
   CONFIG.pf2_bar0_size {32} \
   CONFIG.pf2_vendor_id {1BE7} \
   CONFIG.pf3_bar0_size {32} \
   CONFIG.pf3_vendor_id {1BE7} \
   CONFIG.vendor_id {1BE7} \
 ] $pcie4_uscale_plus_0

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins pcie4_mgt_0] [get_bd_intf_pins pcie4_uscale_plus_0/pcie4_mgt]
  connect_bd_intf_net -intf_net mkSVF_Bridge_0_m_axis_cc [get_bd_intf_pins mkSVF_Bridge_0/m_axis_cc] [get_bd_intf_pins pcie4_uscale_plus_0/s_axis_cc]
  connect_bd_intf_net -intf_net mkSVF_Bridge_0_m_axis_rq [get_bd_intf_pins mkSVF_Bridge_0/m_axis_rq] [get_bd_intf_pins pcie4_uscale_plus_0/s_axis_rq]
  connect_bd_intf_net -intf_net pcie4_uscale_plus_0_m_axis_cq [get_bd_intf_pins mkSVF_Bridge_0/s_axis_cq] [get_bd_intf_pins pcie4_uscale_plus_0/m_axis_cq]
  connect_bd_intf_net -intf_net pcie4_uscale_plus_0_m_axis_rc [get_bd_intf_pins mkSVF_Bridge_0/s_axis_rc] [get_bd_intf_pins pcie4_uscale_plus_0/m_axis_rc]
  connect_bd_intf_net -intf_net pcie4_uscale_plus_0_pcie4_cfg_fc [get_bd_intf_pins mkSVF_Bridge_0/cfg_fc] [get_bd_intf_pins pcie4_uscale_plus_0/pcie4_cfg_fc]
  connect_bd_intf_net -intf_net pcie4_uscale_plus_0_pcie4_cfg_mesg_rcvd [get_bd_intf_pins mkSVF_Bridge_0/cfg_mesg_rcvd] [get_bd_intf_pins pcie4_uscale_plus_0/pcie4_cfg_mesg_rcvd]
  connect_bd_intf_net -intf_net pcie4_uscale_plus_0_pcie4_cfg_mesg_tx [get_bd_intf_pins mkSVF_Bridge_0/cfg_mesg_tx] [get_bd_intf_pins pcie4_uscale_plus_0/pcie4_cfg_mesg_tx]
  connect_bd_intf_net -intf_net pcie_refclk_1 [get_bd_intf_pins pcie_refclk] [get_bd_intf_pins ibufds_gte4_0/ref_clk]
  connect_bd_intf_net -intf_net ssith_processor_0_tv_verifier_info_tx [get_bd_intf_pins axi_in] [get_bd_intf_pins mkSVF_Bridge_0/axi_in]

  # Create port connections
  connect_bd_net -net CLK_1 [get_bd_pins CLK] [get_bd_pins mkSVF_Bridge_0/CLK_aclk]
  connect_bd_net -net clk_wiz_1_clk_out1 [get_bd_pins clk_wiz_1/clk_out1] [get_bd_pins mkSVF_Bridge_0/CLK_user_clk_half]
  connect_bd_net -net ibufds_gte4_0_o [get_bd_pins ibufds_gte4_0/o] [get_bd_pins pcie4_uscale_plus_0/sys_clk_gt]
  connect_bd_net -net ibufds_gte4_0_odiv2 [get_bd_pins ibufds_gte4_0/odiv2] [get_bd_pins pcie4_uscale_plus_0/sys_clk]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_config_space_enable [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_config_space_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_config_space_enable]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_ds_bus_number [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_ds_bus_number] [get_bd_pins pcie4_uscale_plus_0/cfg_ds_bus_number]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_ds_device_number [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_ds_device_number] [get_bd_pins pcie4_uscale_plus_0/cfg_ds_device_number]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_ds_port_number [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_ds_port_number] [get_bd_pins pcie4_uscale_plus_0/cfg_ds_port_number]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_dsn [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_dsn] [get_bd_pins pcie4_uscale_plus_0/cfg_dsn]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_err_cor_in [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_err_cor_in] [get_bd_pins pcie4_uscale_plus_0/cfg_err_cor_in]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_err_uncor_in [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_err_uncor_in] [get_bd_pins pcie4_uscale_plus_0/cfg_err_uncor_in]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_flr_done [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_flr_done] [get_bd_pins pcie4_uscale_plus_0/cfg_flr_done]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_hot_reset_in [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_hot_reset_in] [get_bd_pins pcie4_uscale_plus_0/cfg_hot_reset_in]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_link_training_enable [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_link_training_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_link_training_enable]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_power_state_change_ack [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_power_state_change_ack] [get_bd_pins pcie4_uscale_plus_0/cfg_power_state_change_ack]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_control_req_pm_transition_l23_ready [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_req_pm_transition_l23_ready] [get_bd_pins pcie4_uscale_plus_0/cfg_req_pm_transition_l23_ready]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_external_msix_msi_function_number [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msi_function_number] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_function_number]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_external_msix_msix_address [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msix_address] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msix_address]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_external_msix_msix_data [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msix_data] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msix_data]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_external_msix_msix_intrpt [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msix_intrpt] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msix_int]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_external_msix_msix_vec_pending [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msix_vec_pending] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msix_vec_pending]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_interrupt_intrpt [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_interrupt_intrpt] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_int]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_interrupt_pending [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_interrupt_pending] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_pending]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_mgmt_addr [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_mgmt_addr] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_addr]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_mgmt_byte_enable [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_mgmt_byte_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_byte_enable]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_mgmt_debug_access [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_mgmt_debug_access] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_debug_access]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_mgmt_function_number [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_mgmt_function_number] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_function_number]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_mgmt_read [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_mgmt_read] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_read]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_mgmt_write [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_mgmt_write] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_write]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_mgmt_write_data [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_mgmt_write_data] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_write_data]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_pm_aspm_l1_entry_reject [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_pm_aspm_l1_entry_reject] [get_bd_pins pcie4_uscale_plus_0/cfg_pm_aspm_l1_entry_reject]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_pm_aspm_tx_10s_entry_disable [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_pm_aspm_tx_10s_entry_disable] [get_bd_pins pcie4_uscale_plus_0/cfg_pm_aspm_tx_l0s_entry_disable]
  connect_bd_net -net mkSVF_Bridge_0_pcie4_cfg_status_pcie_cq_np_req [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_pcie_cq_np_req] [get_bd_pins pcie4_uscale_plus_0/pcie_cq_np_req]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_bus_number [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_bus_number] [get_bd_pins pcie4_uscale_plus_0/cfg_bus_number]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_current_speed [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_current_speed] [get_bd_pins pcie4_uscale_plus_0/cfg_current_speed]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_err_cor_out [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_err_cor_out] [get_bd_pins pcie4_uscale_plus_0/cfg_err_cor_out]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_err_fatal_out [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_err_fatal_out] [get_bd_pins pcie4_uscale_plus_0/cfg_err_fatal_out]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_err_nonfatal_out [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_err_nonfatal_out] [get_bd_pins pcie4_uscale_plus_0/cfg_err_nonfatal_out]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_flr_in_process [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_flr_in_process] [get_bd_pins pcie4_uscale_plus_0/cfg_flr_in_process]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_function_power_state [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_funstion_power_state] [get_bd_pins pcie4_uscale_plus_0/cfg_function_power_state]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_function_status [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_function_status] [get_bd_pins pcie4_uscale_plus_0/cfg_function_status]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_hot_reset_out [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_hot_reset_out] [get_bd_pins pcie4_uscale_plus_0/cfg_hot_reset_out]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msi_fail [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msi_fail] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msi_fail]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msix_enable [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msix_msix_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msix_enable]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msix_mask [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msix_msix_mask] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msix_mask]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msix_vec_pending_status [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msix_vec_pending_status] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msix_vec_pending_status]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msix_vf_enable [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msix_vf_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msix_vf_enable]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_msix_vf_mask [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_external_msix_msix_vf_mask] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_msix_vf_mask]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_interrupt_sent [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_interrupt_sent] [get_bd_pins pcie4_uscale_plus_0/cfg_interrupt_sent]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_link_power_state [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_link_power_state] [get_bd_pins pcie4_uscale_plus_0/cfg_link_power_state]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_local_error_out [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_local_error_out] [get_bd_pins pcie4_uscale_plus_0/cfg_local_error_out]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_local_error_valid [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_local_error_valid] [get_bd_pins pcie4_uscale_plus_0/cfg_local_error_valid]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_ltssm_state [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_ltssm_state] [get_bd_pins pcie4_uscale_plus_0/cfg_ltssm_state]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_max_payload [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_max_payload] [get_bd_pins pcie4_uscale_plus_0/cfg_max_payload]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_max_read_req [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_max_read_req] [get_bd_pins pcie4_uscale_plus_0/cfg_max_read_req]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_mgmt_read_data [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_mgmt_read_data] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_read_data]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_mgmt_read_write_done [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_mgmt_read_write_done] [get_bd_pins pcie4_uscale_plus_0/cfg_mgmt_read_write_done]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_negotiated_width [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_negotiated_width] [get_bd_pins pcie4_uscale_plus_0/cfg_negotiated_width]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_obff_enable [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_obff_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_obff_enable]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_phy_link_down [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_phy_link_down] [get_bd_pins pcie4_uscale_plus_0/cfg_phy_link_down]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_phy_link_status [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_phy_link_status] [get_bd_pins pcie4_uscale_plus_0/cfg_phy_link_status]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_pl_status_change [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_pl_status_change] [get_bd_pins pcie4_uscale_plus_0/cfg_pl_status_change]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_power_state_change_interrupt [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_power_state_change_interrupt] [get_bd_pins pcie4_uscale_plus_0/cfg_power_state_change_interrupt]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_rcb_status [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rcb_status] [get_bd_pins pcie4_uscale_plus_0/cfg_rcb_status]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_rx_pm_state [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rx_pm_state] [get_bd_pins pcie4_uscale_plus_0/cfg_rx_pm_state]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_tph_requester_enable [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_tph_requester_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_tph_requester_enable]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_tph_st_mode [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_tph_st_mode] [get_bd_pins pcie4_uscale_plus_0/cfg_tph_st_mode]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_tx_pm_state [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_tx_pm_state] [get_bd_pins pcie4_uscale_plus_0/cfg_tx_pm_state]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_vf_flr_in_process [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_control_vf_flr_in_process] [get_bd_pins pcie4_uscale_plus_0/cfg_vf_flr_in_process]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_vf_power_state [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_vf_power_state] [get_bd_pins pcie4_uscale_plus_0/cfg_vf_power_state]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_vf_status [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_vf_status] [get_bd_pins pcie4_uscale_plus_0/cfg_vf_status]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_vf_tph_requester_enable [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_vf_tph_requester_enable] [get_bd_pins pcie4_uscale_plus_0/cfg_vf_tph_requester_enable]
  connect_bd_net -net pcie4_uscale_plus_0_cfg_vf_tph_st_mode [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_vf_tph_st_mode] [get_bd_pins pcie4_uscale_plus_0/cfg_vf_tph_st_mode]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_cq_np_req_count [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_pcie_cq_np_req_count] [get_bd_pins pcie4_uscale_plus_0/pcie_cq_np_req_count]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_rq_seq_num0 [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rq_seq_num0] [get_bd_pins pcie4_uscale_plus_0/pcie_rq_seq_num0]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_rq_seq_num1 [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rq_seq_num1] [get_bd_pins pcie4_uscale_plus_0/pcie_rq_seq_num1]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_rq_seq_num_vld0 [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rq_seq_num_vld0] [get_bd_pins pcie4_uscale_plus_0/pcie_rq_seq_num_vld0]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_rq_seq_num_vld1 [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rq_seq_num_vld1] [get_bd_pins pcie4_uscale_plus_0/pcie_rq_seq_num_vld1]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_rq_tag0 [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rq_tag0] [get_bd_pins pcie4_uscale_plus_0/pcie_rq_tag0]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_rq_tag1 [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rq_tag1] [get_bd_pins pcie4_uscale_plus_0/pcie_rq_tag1]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_rq_tag_av [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rq_tag_av] [get_bd_pins pcie4_uscale_plus_0/pcie_rq_tag_av]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_rq_tag_vld0 [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rq_tag_vld0] [get_bd_pins pcie4_uscale_plus_0/pcie_rq_tag_vld0]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_rq_tag_vld1 [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_rq_tag_vld1] [get_bd_pins pcie4_uscale_plus_0/pcie_rq_tag_vld1]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_tfc_npd_av [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_tfc_npd_av] [get_bd_pins pcie4_uscale_plus_0/pcie_tfc_npd_av]
  connect_bd_net -net pcie4_uscale_plus_0_pcie_tfc_nph_av [get_bd_pins mkSVF_Bridge_0/pcie4_cfg_status_tfc_nph_av] [get_bd_pins pcie4_uscale_plus_0/pcie_tfc_nph_av]
  connect_bd_net -net pcie4_uscale_plus_0_phy_rdy_out [get_bd_pins mkSVF_Bridge_0/pcie4_phy_rdy_out] [get_bd_pins pcie4_uscale_plus_0/phy_rdy_out]
  connect_bd_net -net pcie4_uscale_plus_0_user_clk [get_bd_pins clk_wiz_1/clk_in1] [get_bd_pins mkSVF_Bridge_0/CLK_user_clk] [get_bd_pins pcie4_uscale_plus_0/user_clk]
  connect_bd_net -net pcie4_uscale_plus_0_user_lnk_up [get_bd_pins mkSVF_Bridge_0/pcie4_user_link_up] [get_bd_pins pcie4_uscale_plus_0/user_lnk_up]
  connect_bd_net -net pcie4_uscale_plus_0_user_reset [get_bd_pins mkSVF_Bridge_0/RST_N_user_reset] [get_bd_pins pcie4_uscale_plus_0/user_reset]
  connect_bd_net -net pcie_perstn_1 [get_bd_pins pcie_perstn] [get_bd_pins pcie4_uscale_plus_0/sys_reset]
  connect_bd_net -net util_vector_logic_0_Res [get_bd_pins RST_N] [get_bd_pins mkSVF_Bridge_0/RST_N_aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: gfe_subsystem
proc create_hier_cell_gfe_subsystem { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_gfe_subsystem() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S00_AXI
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S01_AXI
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c1
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_250mhz_clk1
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:mdio_io:1.0 eth_mdio
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:sgmii_rtl:1.0 sgmii_lvds
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sgmii_phyclk

  # Create pins
  create_bd_pin -dir O -type clk ACLK
  create_bd_pin -dir O -from 0 -to 0 -type rst ARESETN
  create_bd_pin -dir O -type rst c0_ddr4_ui_clk_sync_rst
  create_bd_pin -dir IO -from 7 -to 0 gpio
  create_bd_pin -dir O -from 7 -to 0 gpio_led
  create_bd_pin -dir IO iic0_scl
  create_bd_pin -dir IO iic0_sda
  create_bd_pin -dir O -from 15 -to 0 interrupt
  create_bd_pin -dir O -from 0 -to 0 -type rst phy_reset_out
  create_bd_pin -dir I -type rst reset
  create_bd_pin -dir I rs232_uart_cts
  create_bd_pin -dir O rs232_uart_rts
  create_bd_pin -dir I rs232_uart_rxd
  create_bd_pin -dir O rs232_uart_txd
  create_bd_pin -dir IO spi_miso
  create_bd_pin -dir IO spi_mosi
  create_bd_pin -dir IO spi_sck
  create_bd_pin -dir IO spi_ss
  create_bd_pin -dir I uart1_rx
  create_bd_pin -dir O uart1_tx

  # Create instance: axi_bram_ctrl_0, and set properties
  set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.0 axi_bram_ctrl_0 ]
  set_property -dict [ list \
   CONFIG.SINGLE_PORT_BRAM {1} \
 ] $axi_bram_ctrl_0

  # Create instance: axi_clock_converter_0, and set properties
  set axi_clock_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 axi_clock_converter_0 ]
  set_property USER_COMMENTS.comment_0 "This CDC forces an asynchronous CDC between
the interconnect and DDR. Depending on the design, the
interconnect would not place an asynchronous CDC
here on its own." [get_bd_cells /gfe_subsystem/axi_clock_converter_0]
  set_property -dict [ list \
   CONFIG.ACLK_ASYNC {1} \
 ] $axi_clock_converter_0

  # Create instance: axi_dma_0, and set properties
  set axi_dma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0 ]
  set_property -dict [ list \
   CONFIG.c_addr_width {64} \
   CONFIG.c_include_mm2s_dre {1} \
   CONFIG.c_include_s2mm_dre {1} \
   CONFIG.c_m_axi_mm2s_data_width {32} \
   CONFIG.c_mm2s_burst_size {16} \
   CONFIG.c_sg_length_width {16} \
   CONFIG.c_sg_use_stsapp_length {1} \
 ] $axi_dma_0

  # Create instance: axi_ethernet_0, and set properties
  set axi_ethernet_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_ethernet:7.1 axi_ethernet_0 ]
  set_property -dict [ list \
   CONFIG.DIFFCLK_BOARD_INTERFACE {sgmii_phyclk} \
   CONFIG.ETHERNET_BOARD_INTERFACE {sgmii_lvds} \
   CONFIG.MDIO_BOARD_INTERFACE {mdio_mdc} \
   CONFIG.PHYADDR {1} \
   CONFIG.PHYRST_BOARD_INTERFACE {phy_reset_out} \
   CONFIG.PHY_TYPE {SGMII} \
   CONFIG.RXCSUM {Full} \
   CONFIG.RXVLAN_STRP {false} \
   CONFIG.RXVLAN_TRAN {false} \
   CONFIG.TXCSUM {Full} \
   CONFIG.TXVLAN_STRP {false} \
   CONFIG.TXVLAN_TRAN {false} \
   CONFIG.axiliteclkrate {100} \
   CONFIG.axisclkrate {100} \
 ] $axi_ethernet_0

  # Create instance: axi_gpio1
  create_hier_cell_axi_gpio1 $hier_obj axi_gpio1

  # Create instance: axi_gpio_0, and set properties
  set axi_gpio_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0 ]
  set_property -dict [ list \
   CONFIG.C_ALL_INPUTS {0} \
   CONFIG.C_ALL_OUTPUTS {1} \
   CONFIG.C_IS_DUAL {0} \
   CONFIG.C_TRI_DEFAULT {0xFFFFFFFF} \
 ] $axi_gpio_0

  # Create instance: axi_iic0
  create_hier_cell_axi_iic0 $hier_obj axi_iic0

  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
  set_property -dict [ list \
   CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
   CONFIG.M00_HAS_REGSLICE {4} \
   CONFIG.M01_HAS_REGSLICE {4} \
   CONFIG.M02_HAS_REGSLICE {4} \
   CONFIG.M03_HAS_REGSLICE {4} \
   CONFIG.M04_HAS_REGSLICE {4} \
   CONFIG.M05_HAS_REGSLICE {4} \
   CONFIG.M06_HAS_REGSLICE {4} \
   CONFIG.M07_HAS_REGSLICE {4} \
   CONFIG.M08_HAS_REGSLICE {4} \
   CONFIG.M09_HAS_REGSLICE {4} \
   CONFIG.M10_HAS_REGSLICE {4} \
   CONFIG.M11_HAS_REGSLICE {4} \
   CONFIG.M12_HAS_REGSLICE {4} \
   CONFIG.M13_HAS_REGSLICE {4} \
   CONFIG.NUM_MI {12} \
   CONFIG.NUM_SI {5} \
   CONFIG.S00_HAS_REGSLICE {4} \
   CONFIG.S01_HAS_REGSLICE {4} \
   CONFIG.S02_HAS_REGSLICE {4} \
   CONFIG.S03_HAS_REGSLICE {4} \
   CONFIG.S04_HAS_REGSLICE {4} \
 ] $axi_interconnect_0

  # Create instance: axi_quad_spi1
  create_hier_cell_axi_quad_spi1 $hier_obj axi_quad_spi1

  # Create instance: axi_quad_spi_0, and set properties
  set axi_quad_spi_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi_0 ]
  set_property -dict [ list \
   CONFIG.C_DUAL_QUAD_MODE {0} \
   CONFIG.C_FIFO_DEPTH {16} \
   CONFIG.C_NUM_SS_BITS {1} \
   CONFIG.C_SCK_RATIO {2} \
   CONFIG.C_SPI_MEMORY {2} \
   CONFIG.C_SPI_MEM_ADDR_BITS {32} \
   CONFIG.C_SPI_MODE {2} \
   CONFIG.C_TYPE_OF_AXI4_INTERFACE {1} \
   CONFIG.C_USE_STARTUP {1} \
   CONFIG.C_USE_STARTUP_INT {1} \
   CONFIG.C_XIP_MODE {1} \
 ] $axi_quad_spi_0

  # Create instance: axi_uart16550_0, and set properties
  set axi_uart16550_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uart16550:2.0 axi_uart16550_0 ]

  # Create instance: axi_uart16550_1, and set properties
  set axi_uart16550_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uart16550:2.0 axi_uart16550_1 ]

  # Create instance: blk_mem_gen_0, and set properties
  set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0 ]
  set_property -dict [ list \
   CONFIG.Coe_File {../../../../../../../../bootrom/bootrom.coe} \
   CONFIG.Load_Init_File {true} \
   CONFIG.Memory_Type {Single_Port_ROM} \
   CONFIG.Port_A_Write_Rate {0} \
   CONFIG.Use_Byte_Write_Enable {false} \
 ] $blk_mem_gen_0

  # Create instance: ddr4_0, and set properties
  set ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0 ]
  set_property -dict [ list \
   CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {50} \
   CONFIG.C0_CLOCK_BOARD_INTERFACE {default_250mhz_clk1} \
   CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c1} \
   CONFIG.RESET_BOARD_INTERFACE {reset} \
 ] $ddr4_0

  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]
  set_property -dict [ list \
   CONFIG.C_AUX_RESET_HIGH {1} \
   CONFIG.C_AUX_RST_WIDTH {4} \
   CONFIG.C_EXT_RST_WIDTH {4} \
   CONFIG.C_NUM_BUS_RST {1} \
 ] $proc_sys_reset_0

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]
  set_property -dict [ list \
   CONFIG.C_AUX_RESET_HIGH {1} \
   CONFIG.C_AUX_RST_WIDTH {4} \
   CONFIG.C_EXT_RST_WIDTH {4} \
   CONFIG.C_NUM_BUS_RST {1} \
 ] $proc_sys_reset_1

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [ list \
   CONFIG.IN8_WIDTH {8} \
   CONFIG.IN9_WIDTH {7} \
   CONFIG.NUM_PORTS {9} \
 ] $xlconcat_0

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
 ] $xlconstant_0

  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]

  # Create instance: xlconstant_2, and set properties
  set xlconstant_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_2 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {8} \
 ] $xlconstant_2

  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins sgmii_lvds] [get_bd_intf_pins axi_ethernet_0/sgmii]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins sgmii_phyclk] [get_bd_intf_pins axi_ethernet_0/lvds_clk]
  connect_bd_intf_net -intf_net S00_AXI_1 [get_bd_intf_pins S00_AXI] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net S01_AXI_1 [get_bd_intf_pins S01_AXI] [get_bd_intf_pins axi_interconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net S_AXI_1 [get_bd_intf_pins axi_gpio1/S_AXI] [get_bd_intf_pins axi_interconnect_0/M11_AXI]
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
  connect_bd_intf_net -intf_net axi_clock_converter_0_M_AXI [get_bd_intf_pins axi_clock_converter_0/M_AXI] [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_CNTRL [get_bd_intf_pins axi_dma_0/M_AXIS_CNTRL] [get_bd_intf_pins axi_ethernet_0/s_axis_txc]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins axi_ethernet_0/s_axis_txd]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_0/S03_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_S2MM [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_0/S04_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_SG [get_bd_intf_pins axi_dma_0/M_AXI_SG] [get_bd_intf_pins axi_interconnect_0/S02_AXI]
  connect_bd_intf_net -intf_net axi_ethernet_0_m_axis_rxd [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM] [get_bd_intf_pins axi_ethernet_0/m_axis_rxd]
  connect_bd_intf_net -intf_net axi_ethernet_0_m_axis_rxs [get_bd_intf_pins axi_dma_0/S_AXIS_STS] [get_bd_intf_pins axi_ethernet_0/m_axis_rxs]
  connect_bd_intf_net -intf_net axi_ethernet_0_mdio [get_bd_intf_pins eth_mdio] [get_bd_intf_pins axi_ethernet_0/mdio]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_clock_converter_0/S_AXI] [get_bd_intf_pins axi_interconnect_0/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M01_AXI [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_uart16550_0/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M02_AXI [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] [get_bd_intf_pins axi_interconnect_0/M02_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M03_AXI [get_bd_intf_pins axi_ethernet_0/s_axi] [get_bd_intf_pins axi_interconnect_0/M03_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M04_AXI [get_bd_intf_pins axi_dma_0/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_0/M04_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M05_AXI [get_bd_intf_pins axi_interconnect_0/M05_AXI] [get_bd_intf_pins axi_quad_spi_0/AXI_FULL]
  connect_bd_intf_net -intf_net axi_interconnect_0_M06_AXI [get_bd_intf_pins axi_gpio_0/S_AXI] [get_bd_intf_pins axi_interconnect_0/M06_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M07_AXI [get_bd_intf_pins axi_interconnect_0/M07_AXI] [get_bd_intf_pins axi_quad_spi_0/AXI_LITE]
  connect_bd_intf_net -intf_net axi_interconnect_0_M08_AXI [get_bd_intf_pins axi_interconnect_0/M08_AXI] [get_bd_intf_pins axi_uart16550_1/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M09_AXI [get_bd_intf_pins axi_iic0/S_AXI] [get_bd_intf_pins axi_interconnect_0/M09_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M10_AXI [get_bd_intf_pins axi_interconnect_0/M10_AXI] [get_bd_intf_pins axi_quad_spi1/AXI_LITE]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_pins ddr4_sdram_c1] [get_bd_intf_pins ddr4_0/C0_DDR4]
  connect_bd_intf_net -intf_net default_250mhz_clk1_1 [get_bd_intf_pins default_250mhz_clk1] [get_bd_intf_pins ddr4_0/C0_SYS_CLK]

  # Create port connections
  connect_bd_net -net ARESETN_1 [get_bd_pins ARESETN] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins axi_clock_converter_0/s_axi_aresetn] [get_bd_pins axi_dma_0/axi_resetn] [get_bd_pins axi_ethernet_0/s_axi_lite_resetn] [get_bd_pins axi_gpio1/ARESETN] [get_bd_pins axi_gpio_0/s_axi_aresetn] [get_bd_pins axi_iic0/ARESETN] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/M01_ARESETN] [get_bd_pins axi_interconnect_0/M02_ARESETN] [get_bd_pins axi_interconnect_0/M03_ARESETN] [get_bd_pins axi_interconnect_0/M04_ARESETN] [get_bd_pins axi_interconnect_0/M05_ARESETN] [get_bd_pins axi_interconnect_0/M06_ARESETN] [get_bd_pins axi_interconnect_0/M07_ARESETN] [get_bd_pins axi_interconnect_0/M08_ARESETN] [get_bd_pins axi_interconnect_0/M09_ARESETN] [get_bd_pins axi_interconnect_0/M10_ARESETN] [get_bd_pins axi_interconnect_0/M11_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/S01_ARESETN] [get_bd_pins axi_interconnect_0/S02_ARESETN] [get_bd_pins axi_interconnect_0/S03_ARESETN] [get_bd_pins axi_interconnect_0/S04_ARESETN] [get_bd_pins axi_quad_spi1/s_axi_aresetn] [get_bd_pins axi_quad_spi_0/s_axi4_aresetn] [get_bd_pins axi_quad_spi_0/s_axi_aresetn] [get_bd_pins axi_uart16550_0/s_axi_aresetn] [get_bd_pins axi_uart16550_1/s_axi_aresetn] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
  connect_bd_net -net Net [get_bd_pins axi_clock_converter_0/m_axi_aresetn] [get_bd_pins ddr4_0/c0_ddr4_aresetn] [get_bd_pins proc_sys_reset_1/interconnect_aresetn]
  connect_bd_net -net Net1 [get_bd_pins iic0_scl] [get_bd_pins axi_iic0/iic0_scl]
  connect_bd_net -net Net2 [get_bd_pins iic0_sda] [get_bd_pins axi_iic0/iic0_sda]
  connect_bd_net -net Net3 [get_bd_pins spi_mosi] [get_bd_pins axi_quad_spi1/spi_mosi]
  connect_bd_net -net Net4 [get_bd_pins spi_miso] [get_bd_pins axi_quad_spi1/spi_miso]
  connect_bd_net -net Net5 [get_bd_pins spi_sck] [get_bd_pins axi_quad_spi1/spi_sck]
  connect_bd_net -net Net6 [get_bd_pins spi_ss] [get_bd_pins axi_quad_spi1/spi_ss]
  connect_bd_net -net Net7 [get_bd_pins gpio] [get_bd_pins axi_gpio1/gpio]
  connect_bd_net -net S00_ACLK_1 [get_bd_pins axi_clock_converter_0/m_axi_aclk] [get_bd_pins ddr4_0/c0_ddr4_ui_clk] [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
  connect_bd_net -net axi_dma_0_mm2s_cntrl_reset_out_n [get_bd_pins axi_dma_0/mm2s_cntrl_reset_out_n] [get_bd_pins axi_ethernet_0/axi_txc_arstn]
  connect_bd_net -net axi_dma_0_mm2s_introut [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net axi_dma_0_mm2s_prmry_reset_out_n [get_bd_pins axi_dma_0/mm2s_prmry_reset_out_n] [get_bd_pins axi_ethernet_0/axi_txd_arstn]
  connect_bd_net -net axi_dma_0_s2mm_introut [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins xlconcat_0/In3]
  connect_bd_net -net axi_dma_0_s2mm_prmry_reset_out_n [get_bd_pins axi_dma_0/s2mm_prmry_reset_out_n] [get_bd_pins axi_ethernet_0/axi_rxd_arstn]
  connect_bd_net -net axi_dma_0_s2mm_sts_reset_out_n [get_bd_pins axi_dma_0/s2mm_sts_reset_out_n] [get_bd_pins axi_ethernet_0/axi_rxs_arstn]
  connect_bd_net -net axi_ethernet_0_interrupt [get_bd_pins axi_ethernet_0/interrupt] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net axi_ethernet_0_phy_rst_n [get_bd_pins phy_reset_out] [get_bd_pins axi_ethernet_0/phy_rst_n]
  connect_bd_net -net axi_gpio_0_gpio_io_o [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins xlslice_0/Din]
  connect_bd_net -net axi_gpio_1_gpio2_io_o [get_bd_pins gpio_led] [get_bd_pins axi_gpio1/gpio_led]
  connect_bd_net -net axi_iic0_iic2intc_irpt [get_bd_pins axi_iic0/iic2intc_irpt] [get_bd_pins xlconcat_0/In6]
  connect_bd_net -net axi_quad_spi1_ip2intc_irpt [get_bd_pins axi_quad_spi1/ip2intc_irpt] [get_bd_pins xlconcat_0/In7]
  connect_bd_net -net axi_quad_spi_0_ip2intc_irpt [get_bd_pins axi_quad_spi_0/ip2intc_irpt] [get_bd_pins xlconcat_0/In4]
  connect_bd_net -net axi_uart16550_0_ip2intc_irpt [get_bd_pins axi_uart16550_0/ip2intc_irpt] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net axi_uart16550_0_sout [get_bd_pins rs232_uart_txd] [get_bd_pins axi_uart16550_0/sout]
  connect_bd_net -net axi_uart16550_1_ip2intc_irpt [get_bd_pins axi_uart16550_1/ip2intc_irpt] [get_bd_pins xlconcat_0/In5]
  connect_bd_net -net axi_uart16550_1_sout [get_bd_pins uart1_tx] [get_bd_pins axi_uart16550_1/sout]
  connect_bd_net -net ddr4_0_addn_ui_clkout1 [get_bd_pins ACLK] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins axi_clock_converter_0/s_axi_aclk] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] [get_bd_pins axi_dma_0/m_axi_sg_aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins axi_ethernet_0/axis_clk] [get_bd_pins axi_ethernet_0/s_axi_lite_clk] [get_bd_pins axi_gpio1/ACLK] [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins axi_iic0/ACLK] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/M01_ACLK] [get_bd_pins axi_interconnect_0/M02_ACLK] [get_bd_pins axi_interconnect_0/M03_ACLK] [get_bd_pins axi_interconnect_0/M04_ACLK] [get_bd_pins axi_interconnect_0/M05_ACLK] [get_bd_pins axi_interconnect_0/M06_ACLK] [get_bd_pins axi_interconnect_0/M07_ACLK] [get_bd_pins axi_interconnect_0/M08_ACLK] [get_bd_pins axi_interconnect_0/M09_ACLK] [get_bd_pins axi_interconnect_0/M10_ACLK] [get_bd_pins axi_interconnect_0/M11_ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/S01_ACLK] [get_bd_pins axi_interconnect_0/S02_ACLK] [get_bd_pins axi_interconnect_0/S03_ACLK] [get_bd_pins axi_interconnect_0/S04_ACLK] [get_bd_pins axi_quad_spi1/s_axi_aclk] [get_bd_pins axi_quad_spi_0/ext_spi_clk] [get_bd_pins axi_quad_spi_0/s_axi4_aclk] [get_bd_pins axi_quad_spi_0/s_axi_aclk] [get_bd_pins axi_uart16550_0/s_axi_aclk] [get_bd_pins axi_uart16550_1/s_axi_aclk] [get_bd_pins ddr4_0/addn_ui_clkout1] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk_sync_rst [get_bd_pins c0_ddr4_ui_clk_sync_rst] [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst]
  connect_bd_net -net proc_sys_reset_0_peripheral_reset [get_bd_pins proc_sys_reset_0/mb_reset] [get_bd_pins proc_sys_reset_1/aux_reset_in] [get_bd_pins proc_sys_reset_1/ext_reset_in]
  connect_bd_net -net reset_1 [get_bd_pins reset] [get_bd_pins ddr4_0/sys_rst] [get_bd_pins proc_sys_reset_0/ext_reset_in]
  connect_bd_net -net rs232_uart_rxd_1 [get_bd_pins rs232_uart_rxd] [get_bd_pins axi_uart16550_0/sin]
  connect_bd_net -net uart1_rx_1 [get_bd_pins uart1_rx] [get_bd_pins axi_uart16550_1/sin]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins interrupt] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins axi_quad_spi_0/gsr] [get_bd_pins axi_quad_spi_0/gts] [get_bd_pins axi_quad_spi_0/usrcclkts] [get_bd_pins axi_uart16550_0/freeze] [get_bd_pins axi_uart16550_1/freeze] [get_bd_pins proc_sys_reset_0/mb_debug_sys_rst] [get_bd_pins proc_sys_reset_1/mb_debug_sys_rst] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins axi_quad_spi_0/keyclearb] [get_bd_pins axi_quad_spi_0/usrdoneo] [get_bd_pins axi_quad_spi_0/usrdonets] [get_bd_pins proc_sys_reset_0/dcm_locked] [get_bd_pins proc_sys_reset_1/dcm_locked] [get_bd_pins xlconstant_1/dout]
  connect_bd_net -net xlconstant_2_dout [get_bd_pins xlconcat_0/In8] [get_bd_pins xlconstant_2/dout]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins proc_sys_reset_0/aux_reset_in] [get_bd_pins xlslice_0/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set ddr4_sdram_c1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c1 ]
  set default_250mhz_clk1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_250mhz_clk1 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   ] $default_250mhz_clk1
  set pcie4_mgt_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie4_mgt_0 ]
  set pcie_refclk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {100000000} \
   ] $pcie_refclk
  set sgmii_lvds [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:sgmii_rtl:1.0 sgmii_lvds ]
  set sgmii_phyclk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sgmii_phyclk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {625000000} \
   ] $sgmii_phyclk

  # Create ports
  set gpio [ create_bd_port -dir IO -from 7 -to 0 gpio ]
  set gpio_led [ create_bd_port -dir O -from 7 -to 0 gpio_led ]
  set iic0_scl [ create_bd_port -dir IO iic0_scl ]
  set iic0_sda [ create_bd_port -dir IO iic0_sda ]
  set mdio_io [ create_bd_port -dir IO mdio_io ]
  set mdio_mdc [ create_bd_port -dir O -type clk mdio_mdc ]
  set pcie_perstn [ create_bd_port -dir I -type rst pcie_perstn ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $pcie_perstn
  set phy_reset_out [ create_bd_port -dir O -from 0 -to 0 -type rst phy_reset_out ]
  set reset [ create_bd_port -dir I -type rst reset ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $reset
  set rs232_uart_cts [ create_bd_port -dir I rs232_uart_cts ]
  set rs232_uart_rts [ create_bd_port -dir O rs232_uart_rts ]
  set rs232_uart_rxd [ create_bd_port -dir I rs232_uart_rxd ]
  set rs232_uart_txd [ create_bd_port -dir O rs232_uart_txd ]
  set spi_miso [ create_bd_port -dir IO spi_miso ]
  set spi_mosi [ create_bd_port -dir IO spi_mosi ]
  set spi_sck [ create_bd_port -dir IO spi_sck ]
  set spi_ss [ create_bd_port -dir IO spi_ss ]
  set uart1_rx [ create_bd_port -dir I uart1_rx ]
  set uart1_tx [ create_bd_port -dir O uart1_tx ]

  # Create instance: gfe_subsystem
  create_hier_cell_gfe_subsystem [current_bd_instance .] gfe_subsystem

  # Create instance: iobuf_0, and set properties
  set iobuf_0 [ create_bd_cell -type ip -vlnv Galois:user:iobuf:1.0 iobuf_0 ]

  # Create instance: ssith_processor_0, and set properties
  set ssith_processor_0 [ create_bd_cell -type ip -vlnv ssith:user:ssith_processor:1.0 ssith_processor_0 ]

  # Create instance: svf_pcie_bridge
  create_hier_cell_svf_pcie_bridge [current_bd_instance .] svf_pcie_bridge

  # Create instance: xilinx_jtag_0, and set properties
  set xilinx_jtag_0 [ create_bd_cell -type ip -vlnv ssith:user:xilinx_jtag:1.0 xilinx_jtag_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXI_1 [get_bd_intf_pins gfe_subsystem/S00_AXI] [get_bd_intf_pins ssith_processor_0/master0]
  connect_bd_intf_net -intf_net S01_AXI_1 [get_bd_intf_pins gfe_subsystem/S01_AXI] [get_bd_intf_pins ssith_processor_0/master1]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports ddr4_sdram_c1] [get_bd_intf_pins gfe_subsystem/ddr4_sdram_c1]
  connect_bd_intf_net -intf_net default_250mhz_clk1_1 [get_bd_intf_ports default_250mhz_clk1] [get_bd_intf_pins gfe_subsystem/default_250mhz_clk1]
  connect_bd_intf_net -intf_net gfe_subsystem_sgmii_lvds [get_bd_intf_ports sgmii_lvds] [get_bd_intf_pins gfe_subsystem/sgmii_lvds]
  connect_bd_intf_net -intf_net pcie_refclk_1 [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins svf_pcie_bridge/pcie_refclk]
  connect_bd_intf_net -intf_net sgmii_phyclk_1 [get_bd_intf_ports sgmii_phyclk] [get_bd_intf_pins gfe_subsystem/sgmii_phyclk]
  connect_bd_intf_net -intf_net ssith_processor_0_tv_verifier_info_tx [get_bd_intf_pins ssith_processor_0/tv_verifier_info_tx] [get_bd_intf_pins svf_pcie_bridge/axi_in]
  connect_bd_intf_net -intf_net svf_pcie_bridge_pcie4_mgt_0 [get_bd_intf_ports pcie4_mgt_0] [get_bd_intf_pins svf_pcie_bridge/pcie4_mgt_0]

  # Create port connections
  connect_bd_net -net Net [get_bd_ports mdio_io] [get_bd_pins iobuf_0/io]
  connect_bd_net -net Net1 [get_bd_ports iic0_scl] [get_bd_pins gfe_subsystem/iic0_scl]
  connect_bd_net -net Net2 [get_bd_ports iic0_sda] [get_bd_pins gfe_subsystem/iic0_sda]
  connect_bd_net -net Net3 [get_bd_ports spi_mosi] [get_bd_pins gfe_subsystem/spi_mosi]
  connect_bd_net -net Net4 [get_bd_ports spi_miso] [get_bd_pins gfe_subsystem/spi_miso]
  connect_bd_net -net Net5 [get_bd_ports spi_sck] [get_bd_pins gfe_subsystem/spi_sck]
  connect_bd_net -net Net6 [get_bd_ports spi_ss] [get_bd_pins gfe_subsystem/spi_ss]
  connect_bd_net -net Net7 [get_bd_ports gpio] [get_bd_pins gfe_subsystem/gpio]
  connect_bd_net -net ddr4_0_addn_ui_clkout1 [get_bd_pins gfe_subsystem/ACLK] [get_bd_pins ssith_processor_0/CLK] [get_bd_pins svf_pcie_bridge/CLK] [get_bd_pins xilinx_jtag_0/clk]
  connect_bd_net -net eth_mdio_mdio_i_1 [get_bd_pins gfe_subsystem/eth_mdio_mdio_i] [get_bd_pins iobuf_0/data_o]
  connect_bd_net -net gfe_subsystem_eth_mdio_mdc [get_bd_ports mdio_mdc] [get_bd_pins gfe_subsystem/eth_mdio_mdc]
  connect_bd_net -net gfe_subsystem_eth_mdio_mdio_o [get_bd_pins gfe_subsystem/eth_mdio_mdio_o] [get_bd_pins iobuf_0/data_i]
  connect_bd_net -net gfe_subsystem_eth_mdio_mdio_t [get_bd_pins gfe_subsystem/eth_mdio_mdio_t] [get_bd_pins iobuf_0/data_t]
  connect_bd_net -net gfe_subsystem_gpio_led [get_bd_ports gpio_led] [get_bd_pins gfe_subsystem/gpio_led]
  connect_bd_net -net gfe_subsystem_interrupt [get_bd_pins gfe_subsystem/interrupt] [get_bd_pins ssith_processor_0/cpu_external_interrupt_req]
  connect_bd_net -net gfe_subsystem_phy_reset_out [get_bd_ports phy_reset_out] [get_bd_pins gfe_subsystem/phy_reset_out]
  connect_bd_net -net gfe_subsystem_rs232_uart_rts [get_bd_ports rs232_uart_rts] [get_bd_pins gfe_subsystem/rs232_uart_rts]
  connect_bd_net -net gfe_subsystem_rs232_uart_txd [get_bd_ports rs232_uart_txd] [get_bd_pins gfe_subsystem/rs232_uart_txd]
  connect_bd_net -net gfe_subsystem_uart1_tx [get_bd_ports uart1_tx] [get_bd_pins gfe_subsystem/uart1_tx]
  connect_bd_net -net pcie_perstn_1 [get_bd_ports pcie_perstn] [get_bd_pins svf_pcie_bridge/pcie_perstn]
  connect_bd_net -net reset_1 [get_bd_ports reset] [get_bd_pins gfe_subsystem/reset]
  connect_bd_net -net rs232_uart_cts_1 [get_bd_ports rs232_uart_cts] [get_bd_pins gfe_subsystem/rs232_uart_cts]
  connect_bd_net -net rs232_uart_rxd_1 [get_bd_ports rs232_uart_rxd] [get_bd_pins gfe_subsystem/rs232_uart_rxd]
  connect_bd_net -net ssith_processor_0_jtag_tdo [get_bd_pins ssith_processor_0/jtag_tdo] [get_bd_pins xilinx_jtag_0/tdo]
  connect_bd_net -net uart1_rx_1 [get_bd_ports uart1_rx] [get_bd_pins gfe_subsystem/uart1_rx]
  connect_bd_net -net util_vector_logic_0_Res [get_bd_pins gfe_subsystem/ARESETN] [get_bd_pins ssith_processor_0/RST_N] [get_bd_pins svf_pcie_bridge/RST_N] [get_bd_pins xilinx_jtag_0/rst_n]
  connect_bd_net -net xilinx_jtag_0_tck [get_bd_pins ssith_processor_0/jtag_tclk] [get_bd_pins xilinx_jtag_0/tck]
  connect_bd_net -net xilinx_jtag_0_tdi [get_bd_pins ssith_processor_0/jtag_tdi] [get_bd_pins xilinx_jtag_0/tdi]
  connect_bd_net -net xilinx_jtag_0_tms [get_bd_pins ssith_processor_0/jtag_tms] [get_bd_pins xilinx_jtag_0/tms]

  # Create address segments
  create_bd_addr_seg -range 0x00001000 -offset 0x70000000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_bram_ctrl_0/S_AXI/Mem0] SEG_axi_bram_ctrl_0_Mem0
  create_bd_addr_seg -range 0x00001000 -offset 0x70000000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_bram_ctrl_0/S_AXI/Mem0] SEG_axi_bram_ctrl_0_Mem0
  create_bd_addr_seg -range 0x00010000 -offset 0x62200000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_dma_0/S_AXI_LITE/Reg] SEG_axi_dma_0_Reg
  create_bd_addr_seg -range 0x00010000 -offset 0x62200000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_dma_0/S_AXI_LITE/Reg] SEG_axi_dma_0_Reg
  create_bd_addr_seg -range 0x00040000 -offset 0x62100000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_ethernet_0/s_axi/Reg0] SEG_axi_ethernet_0_Reg0
  create_bd_addr_seg -range 0x00040000 -offset 0x62100000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_ethernet_0/s_axi/Reg0] SEG_axi_ethernet_0_Reg0
  create_bd_addr_seg -range 0x00010000 -offset 0x6FFF0000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_gpio_0/S_AXI/Reg] SEG_axi_gpio_0_Reg
  create_bd_addr_seg -range 0x00010000 -offset 0x6FFF0000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_gpio_0/S_AXI/Reg] SEG_axi_gpio_0_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62330000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_gpio1/axi_gpio_1/S_AXI/Reg] SEG_axi_gpio_1_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62330000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_gpio1/axi_gpio_1/S_AXI/Reg] SEG_axi_gpio_1_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62310000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_iic0/axi_iic_0/S_AXI/Reg] SEG_axi_iic_0_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62310000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_iic0/axi_iic_0/S_AXI/Reg] SEG_axi_iic_0_Reg
  create_bd_addr_seg -range 0x10000000 -offset 0x40000000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/aximm/MEM0] SEG_axi_quad_spi_0_MEM0
  create_bd_addr_seg -range 0x10000000 -offset 0x40000000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/aximm/MEM0] SEG_axi_quad_spi_0_MEM0
  create_bd_addr_seg -range 0x00001000 -offset 0x62400000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/AXI_LITE/Reg] SEG_axi_quad_spi_0_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62400000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/AXI_LITE/Reg] SEG_axi_quad_spi_0_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62320000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_quad_spi1/axi_quad_spi_1/AXI_LITE/Reg] SEG_axi_quad_spi_1_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62320000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_quad_spi1/axi_quad_spi_1/AXI_LITE/Reg] SEG_axi_quad_spi_1_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62300000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_uart16550_0/S_AXI/Reg] SEG_axi_uart16550_0_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62300000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_uart16550_0/S_AXI/Reg] SEG_axi_uart16550_0_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62340000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/axi_uart16550_1/S_AXI/Reg] SEG_axi_uart16550_1_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0x62340000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/axi_uart16550_1/S_AXI/Reg] SEG_axi_uart16550_1_Reg
  create_bd_addr_seg -range 0x80000000 -offset 0x80000000 [get_bd_addr_spaces ssith_processor_0/master0] [get_bd_addr_segs gfe_subsystem/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] SEG_ddr4_0_C0_DDR4_ADDRESS_BLOCK
  create_bd_addr_seg -range 0x80000000 -offset 0x80000000 [get_bd_addr_spaces ssith_processor_0/master1] [get_bd_addr_segs gfe_subsystem/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] SEG_ddr4_0_C0_DDR4_ADDRESS_BLOCK
  create_bd_addr_seg -range 0x80000000 -offset 0x80000000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] SEG_ddr4_0_C0_DDR4_ADDRESS_BLOCK
  create_bd_addr_seg -range 0x80000000 -offset 0x80000000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] SEG_ddr4_0_C0_DDR4_ADDRESS_BLOCK
  create_bd_addr_seg -range 0x80000000 -offset 0x80000000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] SEG_ddr4_0_C0_DDR4_ADDRESS_BLOCK

  # Exclude Address Segments
  create_bd_addr_seg -range 0x00001000 -offset 0x70000000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_bram_ctrl_0/S_AXI/Mem0] SEG_axi_bram_ctrl_0_Mem0
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_bram_ctrl_0_Mem0]

  create_bd_addr_seg -range 0x00010000 -offset 0x62200000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_dma_0/S_AXI_LITE/Reg] SEG_axi_dma_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_dma_0_Reg]

  create_bd_addr_seg -range 0x00040000 -offset 0x62100000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_ethernet_0/s_axi/Reg0] SEG_axi_ethernet_0_Reg0
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_ethernet_0_Reg0]

  create_bd_addr_seg -range 0x00010000 -offset 0x6FFF0000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_gpio_0/S_AXI/Reg] SEG_axi_gpio_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_gpio_0_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62330000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_gpio1/axi_gpio_1/S_AXI/Reg] SEG_axi_gpio_1_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_gpio_1_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62310000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_iic0/axi_iic_0/S_AXI/Reg] SEG_axi_iic_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_iic_0_Reg]

  create_bd_addr_seg -range 0x00010000 -offset 0x40000000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/aximm/MEM0] SEG_axi_quad_spi_0_MEM0
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_quad_spi_0_MEM0]

  create_bd_addr_seg -range 0x00001000 -offset 0x62400000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/AXI_LITE/Reg] SEG_axi_quad_spi_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_quad_spi_0_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62320000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_quad_spi1/axi_quad_spi_1/AXI_LITE/Reg] SEG_axi_quad_spi_1_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_quad_spi_1_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62300000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_uart16550_0/S_AXI/Reg] SEG_axi_uart16550_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_uart16550_0_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62340000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_MM2S] [get_bd_addr_segs gfe_subsystem/axi_uart16550_1/S_AXI/Reg] SEG_axi_uart16550_1_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_MM2S/SEG_axi_uart16550_1_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x70000000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_bram_ctrl_0/S_AXI/Mem0] SEG_axi_bram_ctrl_0_Mem0
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_bram_ctrl_0_Mem0]

  create_bd_addr_seg -range 0x00010000 -offset 0x62200000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_dma_0/S_AXI_LITE/Reg] SEG_axi_dma_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_dma_0_Reg]

  create_bd_addr_seg -range 0x00040000 -offset 0x62100000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_ethernet_0/s_axi/Reg0] SEG_axi_ethernet_0_Reg0
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_ethernet_0_Reg0]

  create_bd_addr_seg -range 0x00010000 -offset 0x6FFF0000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_gpio_0/S_AXI/Reg] SEG_axi_gpio_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_gpio_0_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62330000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_gpio1/axi_gpio_1/S_AXI/Reg] SEG_axi_gpio_1_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_gpio_1_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62310000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_iic0/axi_iic_0/S_AXI/Reg] SEG_axi_iic_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_iic_0_Reg]

  create_bd_addr_seg -range 0x00010000 -offset 0x40000000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/aximm/MEM0] SEG_axi_quad_spi_0_MEM0
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_quad_spi_0_MEM0]

  create_bd_addr_seg -range 0x00001000 -offset 0x62400000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/AXI_LITE/Reg] SEG_axi_quad_spi_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_quad_spi_0_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62320000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_quad_spi1/axi_quad_spi_1/AXI_LITE/Reg] SEG_axi_quad_spi_1_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_quad_spi_1_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62300000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_uart16550_0/S_AXI/Reg] SEG_axi_uart16550_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_uart16550_0_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62340000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_S2MM] [get_bd_addr_segs gfe_subsystem/axi_uart16550_1/S_AXI/Reg] SEG_axi_uart16550_1_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_S2MM/SEG_axi_uart16550_1_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x70000000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_bram_ctrl_0/S_AXI/Mem0] SEG_axi_bram_ctrl_0_Mem0
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_bram_ctrl_0_Mem0]

  create_bd_addr_seg -range 0x00010000 -offset 0x62200000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_dma_0/S_AXI_LITE/Reg] SEG_axi_dma_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_dma_0_Reg]

  create_bd_addr_seg -range 0x00040000 -offset 0x62100000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_ethernet_0/s_axi/Reg0] SEG_axi_ethernet_0_Reg0
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_ethernet_0_Reg0]

  create_bd_addr_seg -range 0x00010000 -offset 0x6FFF0000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_gpio_0/S_AXI/Reg] SEG_axi_gpio_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_gpio_0_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62330000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_gpio1/axi_gpio_1/S_AXI/Reg] SEG_axi_gpio_1_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_gpio_1_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62310000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_iic0/axi_iic_0/S_AXI/Reg] SEG_axi_iic_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_iic_0_Reg]

  create_bd_addr_seg -range 0x00010000 -offset 0x40000000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/aximm/MEM0] SEG_axi_quad_spi_0_MEM0
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_quad_spi_0_MEM0]

  create_bd_addr_seg -range 0x00001000 -offset 0x62400000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_quad_spi_0/AXI_LITE/Reg] SEG_axi_quad_spi_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_quad_spi_0_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62320000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_quad_spi1/axi_quad_spi_1/AXI_LITE/Reg] SEG_axi_quad_spi_1_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_quad_spi_1_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62300000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_uart16550_0/S_AXI/Reg] SEG_axi_uart16550_0_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_uart16550_0_Reg]

  create_bd_addr_seg -range 0x00001000 -offset 0x62340000 [get_bd_addr_spaces gfe_subsystem/axi_dma_0/Data_SG] [get_bd_addr_segs gfe_subsystem/axi_uart16550_1/S_AXI/Reg] SEG_axi_uart16550_1_Reg
  exclude_bd_addr_seg [get_bd_addr_segs gfe_subsystem/axi_dma_0/Data_SG/SEG_axi_uart16550_1_Reg]



  # Restore current instance
  current_bd_instance $oldCurInst

  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


