This directory is intentionally empty in version control.

Reason
- AMD/Xilinx simulation libraries (e.g., unisims_ver, unimacro_ver, secureip, xpm) are large and subject to vendor EULAs that typically prohibit redistribution.
- Please generate them locally with your installed Vivado and Questa/ModelSim.

How to generate (Vivado Tcl)
    vivado -mode tcl -nojournal -nolog -notrace <<'TCL'
    compile_simlib \
      -simulator       questa \
      -directory       ./Questa_Simulation_Environment/compiled_xilinx_libs \
      -family          all \
      -language        all \
      -library         all \
      -force
    exit
    TCL

Notes
- If Vivado cannot locate your Questa installation, add `-simulator_exec_path /path/to/questa/bin` or ensure `vsim` is on PATH.
- Do not commit the generated contents of this folder.
- The FI script `Questa_Simulation_Environment/RTOS_PMP_FI.do` expects this path; update its `XLNX_LIBS` variable if you place the libs elsewhere.

See also
- Top-level README section: "Generate AMD/Xilinx simulation libraries (Questa/ModelSim)"