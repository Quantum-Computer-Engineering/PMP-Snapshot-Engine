###############################################################################
#  RTOS_PMP_FI.do – Questa/ModelSim automated PMP corruption campaign (design imported from Vivado)
#
#  Usage      :  vsim -c -do RTOS_PMP_FI.do
#  Pre-Requis.:  - QuestaSim-64 (2021.3_2)
#
#  Output     :  - results.csv   
#                - iter_XXXX.wlf 
###############################################################################

# User-controlled flag: 1 = use SIM_ROOT_PSE, 0 = use SIM_ROOT_NO_PSE
quietly set USE_PSE 1
quietly set CORRUPT_PSE_SLOT_2 1
quietly set DEACTIVATE_PSE_FI_DETECTION 0


# ---------- 0. Absolute project paths ----------------------------------------
quietly set PROJ_ROOT [file normalize ..]
quietly set SIM_ROOT_NO_PSE  $PROJ_ROOT/Questa_Simulation_Environment/exported_simulation_no_pse/questa
quietly set SIM_ROOT_PSE  $PROJ_ROOT/Questa_Simulation_Environment/exported_simulation_with_pse/questa
quietly set RESULT_DIR $PROJ_ROOT/Questa_Simulation_Environment/results
quietly set CHECKPOINT_FILE     [file normalize rtos_pre_switch.cpt]
quietly set XLNX_LIBS $PROJ_ROOT/Questa_Simulation_Environment/compiled_xilinx_libs
quietly set ITERATIONS 100000

# Time to run before taking the checkpoint. The times here are empirical.
if {$USE_PSE} {
    quietly set SIM_ROOT $SIM_ROOT_PSE
	quietly set CHECKPOINT_TIME "4820 us"
} else {
    quietly set SIM_ROOT $SIM_ROOT_NO_PSE
	quietly set CHECKPOINT_TIME "3700 us"
}

# Time to record before the corruption/FI for more insights
quietly set PRE_CORRUPTION_CONTEXT_TIME "100 us"

# Test-bench file(s) and its top-level unit
quietly set TB_SRCS [list \
    "$PROJ_ROOT/project_1/project_1.srcs/sources_1/design_database/TOP_LEVEL/SECURE_PLATFORM_RI5CY/tb/SSP_tb.v"]
quietly set TB_TOP  tb
quit -sim

# For Questasim it is necessary to export the simulation from Vivado first.
# This is because the project uses some AMD IP cores (e.g. Block Memory Generator)
# Before do in SIM_ROOT: export_simulation -simulator questa -directory exported_simulation_no_or_with_pse -absolute_path -force
if {![file exists $SIM_ROOT/compile.do]} {
    echo "Vivado export_simulation not found - aborting."; quit -f
}

# Seed the RNG (rand()) for reproducible results
set RAND_SEED 42
expr {srand($RAND_SEED)}


# ---------- 1.  cd into sim_questa/questa and stay there ---------------------
cd $SIM_ROOT

# a) design libraries from Vivado
if {[catch {vlib questa_lib}]} { }
do compile.do -lib_map_path $XLNX_LIBS

# b) stand-alone work library for your TB
if {![file exists work]} { vlib work }

# c) compile the TB
foreach f $TB_SRCS {
    if {![file exists $f]} { echo "ERROR: $f missing"; quit -f }
    vlog -sv +acc -work work  $f
}

# ---------- 2. Elaborate (all libs now reachable by relative paths) ----------

# --- map the pre-compiled Xilinx sim-libs ------------------------------
vmap unisims_ver   $XLNX_LIBS/unisims_ver
vmap unimacro_ver  $XLNX_LIBS/unimacro_ver
vmap secureip      $XLNX_LIBS/secureip        ;# keep this – it’s mixed-lang

# optional but harmless, if they exist:
if {[file isdirectory $XLNX_LIBS/unifast_ver]} {
    vmap unifast_ver $XLNX_LIBS/unifast_ver
}

# global set/reset model
set GLBLFILE "/opt/apps/xilinx/Vivado/2024.2/data/verilog/src/glbl.v"
vlog $GLBLFILE -work work          ;# any library is fine – work is simplest

vsim -classdebug -voptargs=+acc \
     -modelsimini modelsim.ini \
     -L xil_defaultlib -L xpm \
     -L unisims_ver -L unimacro_ver -L secureip \
     -L blk_mem_gen_v8_4_9 -L xlconstant_v1_1_9 \
     -L xlconcat_v2_1_6   -L xlslice_v1_0_4 \
     work.$TB_TOP work.glbl

# ---------- 3. One-time waveform setup ---------------------------------------
# Does not work for an unknown reason, but can be used to copy and paste into the console in questasim
log -r /*
add wave -label priv_level /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/privlvl_user/priv_lvl_i/rdata_q
add wave -label pc /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/ex_stage_i/ex_wb_pipe_o.pc
add wave -label rdata /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/ex_stage_i/ex_wb_pipe_o.instr.bus_resp.rdata
add wave -label csr_pmp_o /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pmp_o
add wave -label done_sig /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/AHB2DUMP_0/FI_SIM_DONE_SIG
add wave -label pass_sig /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/AHB2DUMP_0/FI_SIM_PASS_SIG
if {$USE_PSE} {
	add wave -label pse_parity_invalid /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pse/csr_pmp_snapshot_storage_0/parity_invalid 							   
	add wave -label pse_comparison_fault /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pse/csr_pmp_snapshot_storage_0/comparison_fault 
	add wave -label pse_error /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pse/csr_pmp_snapshot_storage_0/rd_error_o 
	add wave -label pse_comparison_fault /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pse/csr_pmp_snapshot_storage_0/comparison_fault 
	add wave -label snapshot_mem /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pse/csr_pmp_snapshot_storage_0/snapshot_regions_mem
}
add wave -label alert_major /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/alert_major_o 
add wave -label mcause /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/mcause.exception_code 




# --------- 4. Run until the checkpoint time and take a warm restore checkpoint ----
echo "Running until checkpoint time: $CHECKPOINT_TIME"
run $CHECKPOINT_TIME
echo "Saving warm restore checkpoint: $CHECKPOINT_FILE"
checkpoint $CHECKPOINT_FILE


# ---------- 5. Helper procs ---------------------------------------------------
proc rand32 {} { format 0x%08X [expr {int(rand()*0x100000000)}] }

proc read_hex32_unsigned {sig} {
    set p [string trimright $sig "/"]
    

    # Get as binary string
    if {[catch {examine -radix binary $p} bv]} {
        if {[catch {examine -radix binary ${p}\[31:0\]} bv]} {
            return "NA"
        }
    }

    # Check for X or Z before converting
    if {[regexp {[xX]} $bv]} {
        return "X"
    }
  	if {[regexp {[zZ]} $bv]} {
        return "Z"
    }

	# try direct; fall back to [31:0] slice if needed
    if {[catch {examine -radix unsigned $p} v]} {
        if {[catch {examine -radix unsigned ${p}\[31:0\]} v]} { return "NA" }
    }

    set v32 [expr {$v & 0xFFFFFFFF}]
    return [format 0x%08X $v32]
}

proc read_slice_dec {sig hi lo} {
    set p [string trimright $sig "/"]
	echo $p
    set target [format {%s\[%d:%d\]} $p $hi $lo]   ;# escape [ ]
    if {[catch {examine -radix dec $sig} v]} { return "NA" }
    if {![string is integer -strict $v]}         { return "NA" }
    return $v
}

# Return the bit width of a memory *element* at <mem_path>[index]
proc mem_elem_width_bits {mem_path} {
    if {[catch {mem list $mem_path} out]} { return -1 }
    
    # Matches either "x 816 w" or "width = 816"
    if {[regexp {x\s+([0-9]+)\s+w} $out -> w]}        { return $w }
    if {[regexp {width\s*=\s*([0-9]+)}     $out -> w]} { return $w }
    return -1
}

# Make a random hex string with exactly <nhex> hex digits (no 0x prefix)
proc rand_hex_len {nhex} {
    set s ""; set pairs [expr {$nhex/2}]
    for {set i 0} {$i < $pairs} {incr i} { append s [format %02X [expr {int(rand()*256)}]] }
    if {$nhex % 2} { append s [format %1X [expr {int(rand()*16)}]] }
    return $s
}

# Returns the number of hex digits required to represent the memory element at the given index of the specified memory path.
proc determine_number_of_hex_digits_for_mem {mem_path index} {
    set lst [mem display -format hex -startaddress $index -endaddress $index $mem_path]
    if {[llength $lst] < 2} { return -1 }
    return [string length [lindex $lst 1]]
}

# random byte as two hex digits, no prefix (“B4”)
proc randByteHex {} { format %02X [expr {int(rand()*256)}] }


# Main simulation function for one run
proc run_one {iter cpt done_sig pass_sig log_dir log_file} {

    # 1) restore the warm checkpoint
    restore $cpt

    # 2) start a fresh wave database by clearing the default “sim” dataset
    dataset clear                          ;# empties all waveform data

	# --- PRE-CORRUPTION CONTEXT ---
    # Record some activity before any randomization
    run $::PRE_CORRUPTION_CONTEXT_TIME

    # If requested, deactivate the FI detection of the PSE from within the simulation
	if {$::DEACTIVATE_PSE_FI_DETECTION} {
    	# Suppress FI detection of PSE
		set FI_DETECTION_SIG "/tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pse/csr_pmp_snapshot_storage_0/rd_error_o"
		force -freeze $FI_DETECTION_SIG 1'b0
	}    

	# Path to the pmpconfig memory array
	set pathToPmpConfigCsrs "/tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/pmpncfg_q"

	# Lists to log the written values
    set cfg_written   {}   ;# list of 16 bytes as "B4 59 ..."
    set addr_written  {}   ;# list of 16 words as "0xDEADBEEF ..."

    # ---- Inject the fault ----

    # Attack (2): Randomize PSE slot 2
	if { $::CORRUPT_PSE_SLOT_2 } {
		echo "Executing Attack (2)"

    	# Corrupt snapshot_regions_mem[2]
    	set pse_mem_path "/tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pse/csr_pmp_snapshot_storage_0/snapshot_regions_mem"
    	set slot_index 2

		# Query the exact bit-width of this memory element
		set width_bits [mem_elem_width_bits $pse_mem_path]
		if {$width_bits < 1} {
				puts "WARN: couldn't determine width for ${pse_mem_path}\[$slot_index]; defaulting to 816"
				echo "Size of snapshot_regions_mem could not be determined - aborting."; quit -f
		}

        # Generate a random hex string of the right length
        set nhex  [determine_number_of_hex_digits_for_mem $pse_mem_path $slot_index]   ;# e.g. ceil(691/4)=173
     	set corrupted_pse_slot_value_in_hex [rand_hex_len $nhex]

        # Mask off any excess bits in the MS nibble
        set nbits [expr {$nhex*4}]                       ;# 692 here
        set rem   [expr {($nbits - $width_bits)}]        ;# extra bits in MS nibble (1)
        if {$rem > 0} {
            set ms [string index $corrupted_pse_slot_value_in_hex 0]
            scan $ms %x d
            set d  [expr {$d & ((1 << (4-$rem)) - 1)}]    ;# keep low (4-rem) bits
            set corrupted_pse_slot_value_in_hex "[format %X $d][string range $corrupted_pse_slot_value_in_hex 1 end]"
        }

		# Write it into address [1]
		mem load \
		    -format       hex	 \
		    -filltype     value \
		    -filldata     $corrupted_pse_slot_value_in_hex \
		    -startaddress $slot_index \
		    -endaddress   $slot_index \
		    $pse_mem_path

	} else {
        # Attack (1): Randomize all PMP-CSRs

		echo "Executing Attack (1)"

		# 3b) randomise all PMP-CSR address registers	
		for {set i 0} {$i < 16} {incr i} {

			# Read current byte
			lassign [mem display -format hex -startaddress $i -endaddress $i $pathToPmpConfigCsrs] _ old_value

			# New random byte for pmpcfgx
			set new [randByteHex]          ;# e.g. "B4"

			# Write it back
			mem load -format hex -filltype value -filldata $new -startaddress $i -endaddress $i $pathToPmpConfigCsrs

            # Log it 
			lappend cfg_written $new
		}

		# 3b) randomise all PMP-CSR address registers 
        # (Writing is different from pmpcfgs because of different data type)
		for {set i 0} {$i < 16} {incr i} {

            # Read current addr value
			set old_value [examine -radix hex /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/pmp_addr_q\[$i\]]   

            # Write a new random 32-bit value into pmp_addr_q[i]
		    force -deposit /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/pmp_addr_q\[$i\] [rand32] -freeze
	   
            # Read back the value and log
			set new [examine -radix hex /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/pmp_addr_q\[$i\]]   
			lappend addr_written $new
	 	}
	}
    
    # 4) ----------- run until the test-bench sets DONE_SIG or we hit a timeout -----------

	set max_loops 10
	set loops 0
	set done 0
	
    # Wait until done_sig is 1 or we hit the loop limit
	while {([examine -radix dec $done_sig] == 0) && ($loops < $max_loops)} {
		run 100 us
		incr loops
	}

	# DNF only if we hit the loop limit AND done is still 0
	set dnf [expr {$loops >= $max_loops && $done == 0}]

    # 5) copy this iteration’s waves to an individual WLF file
    set wlfname [format "%s/iter_%04d.wlf" $log_dir $iter]
    dataset save sim $wlfname              ;# creates the WLF file
    #wlf2vcd -o $wlfname.vcd $wlfname 

    # 6) grade the result and append to CSV

	if { !$dnf } {
    	set verdict [expr {[examine -radix dec $pass_sig] != 0 ? "PASS" : "FAIL"}]
	} else {
	    set verdict "DNF"
    }

	# If the PSE slot has been corrupted, retrieve the PMP-CSR values now
    # Before, they had not been applied, so now is the time.
	if { $::CORRUPT_PSE_SLOT_2 } {
		
		for {set i 0} {$i < 16} {incr i} {
	   
			# PMP addresses
			set new_addr [examine -radix hex /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/pmp_addr_q\[$i\]]   
			lappend addr_written $new_addr
			
			# PMP configs
			lassign [mem display -format hex -startaddress $i -endaddress $i $pathToPmpConfigCsrs] _ new_conf 
			lappend cfg_written $new_conf
	 	}
	}

	set code_dec [read_slice_dec $::MCAUSE_CODE_SIG 10 0]
	set irq_dec  0

	if {$code_dec eq "NA"} {
		set mcause_hex "NA"
	} else {
		set mcause_hex [format 0x%08X [expr {($irq_dec<<31) | ($code_dec & 0x7FF)}]]
	}

	# mepc as 32-bit hex
	set mepc_hex [read_hex32_unsigned $::MEPC_SIG]

	# ---- stringify the lists for CSV (quote them so spaces are preserved) -----
    set cfg_str  [join $cfg_written  " "]            ;# e.g. "B4 59 0A ..."
    set addr_str [join $addr_written " "]            ;# e.g. "0xDEAD... 0xBEEF..."

	set comp_fault [read_hex32_unsigned $::COMP_FAULT_SIG]
	set par_inval [read_hex32_unsigned $::PAR_INVAL_SIG]

	if {$::CORRUPT_PSE_SLOT_2} {
        set pmp_string_complete " (snapshot_regions_mem\[2]: $corrupted_pse_slot_value_in_hex),"
	} else {
		set	pmp_string_complete ""
	}

    set fp [open $log_file a+]
    puts $fp "$iter,[clock format [clock seconds] -format %Y%m%d_%H%M%S],$wlfname,$verdict,mcause:$mcause_hex,mepc:$mepc_hex, pmpconfigs(0-15): $cfg_str, pmpaddrs(0-15): $addr_str,$pmp_string_complete comparison_fault: $comp_fault, parity_invalid: $par_inval"
    close $fp
}

# ---------- 5. Main campaign loop --------------------------------------------
file mkdir logs

# ---- signals that the test-bench drives ----
set DONE_SIG "/tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/AHB2DUMP_0/FI_SIM_DONE_SIG"
set PASS_SIG "/tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/AHB2DUMP_0/FI_SIM_PASS_SIG"
set COMP_FAULT_SIG /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pse/csr_pmp_snapshot_storage_0/comparison_fault 
set PAR_INVAL_SIG /tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/csr_pse/csr_pmp_snapshot_storage_0/parity_invalid 		


# ---- CSR signals to log ----------------------------------------------------
set MEPC_SIG   "/tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/cs_registers_i/mepc_csr_i/rdata_q"
set MCAUSE_CODE_SIG  "tb/CV32E40S_SoC_with_Caches/E40S_with_Caches_i/RISCV_CORE/inst/u_cv32e40s_core/mcause.exception_code"


# 1. Remove result files created by earlier runs
if {[file isdirectory $RESULT_DIR]} {
    # -nocomplain keeps Tcl quiet when glob matches nothing
    file delete -force {*}[glob -nocomplain -directory $RESULT_DIR *.wlf *.vcd *.csv]
} else {
    file mkdir $RESULT_DIR
}

set CSV_FILE [file join $RESULT_DIR results.csv]

# Run experiments
for {set i 0} {$i < $ITERATIONS} {incr i} { run_one $i $CHECKPOINT_FILE $DONE_SIG $PASS_SIG $RESULT_DIR $CSV_FILE }

quit -f
