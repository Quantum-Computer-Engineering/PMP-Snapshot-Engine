## PMP Snapshot Engine (PSE) — Secure RTOS Context Switch Accelerator

This repository contains a hardware/firmware platform for accelerating task switching in secure RTOSes using the PMP Snapshot Engine (PSE), while protecting it from FI attacks at the same time. The hardware is a Vivado project embedding a CV32E40S RISC‑V core enhanced with the PSE, a minimal bare‑metal RTOS demo to exercise context switches and PMP settings, and a Questa/ModelSim simulation suite that performs randomized fault injection (FI) to demonstrate PSE’s fault detection.

- Target core: CV32E40S (RISC‑V RV32IMAC)
- RTOS demo: minimal preemptive scheduler + PMP isolation
- PSE: Can write the PMP configuration for all regions in one cycle, and is able to detect corruptions of the PMP registers
- FI suite: automated campaign with warm checkpoints and randomized CSR/memory corruptions


## Repository layout

- `Vivado_PSE_Project/` — Vivado project (`project_1.xpr`) with the SoC design and testbench
  - `project_1.srcs/sources_1/design_database/IP/Misc/` — contains the PSE consisting of `csr_pmp_snapshot_storage.sv` and `pse_parity_unit.sv`
  - `project_1.srcs/sources_1/design_database/TOP_LEVEL/SECURE_PLATFORM_RI5CY/rtl/` — top‑level RTL
  - `project_1.srcs/sources_1/design_database/TOP_LEVEL/SECURE_PLATFORM_RI5CY/tb/SSP_tb.v` — testbench
- `riscv-bare-metal-rtos-demo/` — firmware for the demo RTOS (builds .elf/.bin/.srec and .coe)
  - `src/rtos_config.h` — switches for FPGA vs. FI sim, PSE on/off, experiment behavior
  - `scripts/` — helpers to convert images to `.dat`/`.coe` for BRAM init
- `Questa_Simulation_Environment/` — FI simulation environment and precompiled Xilinx libs
  - `RTOS_PMP_FI.do` — main automated FI campaign script (Questa/ModelSim)
  - `exported_simulation_with_pse/` and `exported_simulation_no_pse/` — Vivado export_simulation outputs (Questa)
  - `compiled_xilinx_libs/` — modelsim.ini and precompiled Xilinx libraries mapping
- `coe-files/` — ready‑to‑use BRAM init files and bitstream(s)
  - `fpga_demo_2_tasks.bit` — bitstream for the two‑task demo (Genesys2); see notes below
  - `FI_setup_with_pse.coe`, `FI_setup_no_pse.coe`, `fpga_demo_2_tasks.coe` — prebuilt BRAM images
  - `README.txt` — quick context and the relevant `rtos_config.h` settings


## Prerequisites

Hardware/FPGA
- AMD/Xilinx Vivado (project created with 2024.2; adjust paths if using a different version)
- A compatible FPGA board (the included bitstream targets a Genesys2 board)

Toolchains and simulators
- RISC‑V GCC bare‑metal toolchain (rv32): `riscv32-unknown-elf-gcc` and friends
  - The demo Makefile defaults to a toolchain in `~/.riscv` (override with `RISCV_PREFIX` or `CROSS`)
- QuestaSim/ModelSim 64‑bit (script notes 2021.3_2); other versions may work with minor path updates

OS and shells
- Linux, bash (used in build scripts)


## Generate AMD/Xilinx simulation libraries (Questa/ModelSim)

For the FI simulation, it is necessary to compile the AMD/Xilinx simulation libraries for your installed Vivado and Questa versions.

Output location (recommended in this repo)
- `Questa_Simulation_Environment/compiled_xilinx_libs/`

Compile it using the Vivado Tcl (CLI)

```
compile_simlib  \
    -simulator  questa \
    -family     all \
    -language   all \
    -library    all \
    -directory  ./Questa_Simulation_Environment/compiled_xilinx_libs/ \
    -log        ./Questa_Simulation_Environment/compile_simlib.log
exit
TCL
```

Notes
- If Vivado can’t find your Questa installation, add `-simulator_exec_path /path/to/questa/bin` to the command or put `vsim` on your PATH.
- The resulting directory should contain mapped libraries such as `unisims_ver`, `unimacro_ver`, `secureip`, and `xpm`, plus a `modelsim.ini`.
- In `Questa_Simulation_Environment/RTOS_PMP_FI.do`, the variable `XLNX_LIBS` points to this folder and the script uses `vmap` accordingly. If you generated libs elsewhere, update that variable.


## Build the bare‑metal RTOS demo firmware

The RTOS demo lives in `riscv-bare-metal-rtos-demo/` and produces firmware images plus `.coe` files suitable for BRAM initialization in Vivado.

1) Configure experiment switches (optional)
- Edit `riscv-bare-metal-rtos-demo/src/rtos_config.h`:
  - `FI_VIVADO_SIMULATION_SETUP` = 0 for FPGA; 1 for FI simulation
  - `FI_EXPERIMENT_SETUP` = 0 for nominal run; 1 to trigger cross‑task access attempt during FI sim
  - `PSE_ACTIVATED` = 1 to enable the PMP Snapshot Engine in firmware; 0 to disable
  - Timing is adapted for FPGA vs. sim via `CPU_CLOCK_HZ` and `TICK_RATE_HZ`

2) Build
- From `riscv-bare-metal-rtos-demo/` run:

```bash
make
```

This generates outputs in `build/img/`:
- `firmware.elf`, `.bin`, `.lst`, `.srec`
- `code_and_data.coe` (via `scripts/srec2dat.sh` and `scripts/dat2coe.sh`) for Vivado BRAM init


## Running on FPGA

Option A — Use the provided bitstream
- Program `coe-files/fpga_demo_2_tasks.bit` to a Genesys2 board.
- Open a UART terminal connected to the board to observe task messages.

Option B — Regenerate a bitstream with your firmware
- Open `Vivado_PSE_Project/project_1.xpr` in Vivado.
- Point the BRAM/memory init of the design to the generated `.coe` from `riscv-bare-metal-rtos-demo/build/img/`.
- Synthesize, implement, and generate a new bitstream.
- Program the FPGA and connect a UART terminal to view output.

Notes for UART
- The UART-peripheral of supports two baud rates when running at 50MHz:  9600 and 19200. We ran the system at 20MHz resulting in a baudrate of 7680 (= 20MHz/50MHz * 19200).
- We used the BitMagic Basic Logic Analyzer (v1) which is sigrok compatible. For reading the UART messages we used the following command: 
```
sigrok-cli -d fx2lafw -c samplerate=12m --continuous -P uart:baudrate=7680:rx=D0:format=ascii -B uart=rx -O ascii
```
- The pinout check the constraint file `genesys2.xdc`.


## Running in QEMU (no PSE support)

The bare‑metal RTOS demo also runs under QEMU for quick functional checks, but QEMU does not emulate the PSE. Use the simulation timing (10 MHz) and disable PSE in firmware.

Configuration
- In `riscv-bare-metal-rtos-demo/src/rtos_config.h` set:
  - `FI_VIVADO_SIMULATION_SETUP = 1`  (sets `CPU_CLOCK_HZ = 10 MHz`, `TICK_RATE_HZ = 100 Hz`)
  - `PSE_ACTIVATED = 0`               (QEMU does not support the PSE)

Run (example)

```bash
qemu-system-riscv32 \
    -gdb tcp::1234 \
    -M virt \
    -bios none \
    -nographic \
    -cpu rv32,mmu=off \
    -kernel ./build/img/firmware.elf \
    -device loader,addr=0x80010000,cpu-num=0 \
    -S
```
The options `-gdb tcp::1234` and `-S` are optional, allowing for a debugger to attach with the settings in `.gdbinit`.

```
riscv32-unknown-elf-gdb ./build/img/firmware.elf 
```


Notes
- Any PSE‑dependent features are unavailable in QEMU; keep `PSE_ACTIVATED=0`.


## Fault Injection (FI) simulation campaign with Questa

The automated campaign is driven by `Questa_Simulation_Environment/RTOS_PMP_FI.do` and relies on a Vivado “exported simulation” of the project.

1) Ensure Vivado simulation export exists
- From Vivado, run: Export Simulation → Questa → absolute paths → output directory set to `Questa_Simulation_Environment/exported_simulation_with_pse` (and/or `.../exported_simulation_no_pse`).
- The `.do` expects a `questa/compile.do` inside the chosen export folder; it will abort if not found.

Vivado Tcl (exact command)

```tcl
# Concrete examples for this repo (run in Vivado with the project open)
export_simulation -simulator questa -directory ./Questa_Simulation_Environment/exported_simulation_with_pse -absolute_path -force
export_simulation -simulator questa -directory ./Questa_Simulation_Environment/exported_simulation_no_pse   -absolute_path -force
```

2) Adjust paths if needed
- `RTOS_PMP_FI.do` compiles a testbench from the project tree. In this repo the testbench is at:
  - `Vivado_PSE_Project/project_1.srcs/sources_1/design_database/TOP_LEVEL/SECURE_PLATFORM_RI5CY/tb/SSP_tb.v`
- If your Vivado export or folder name differs, update `TB_SRCS` accordingly inside `RTOS_PMP_FI.do`.
- Update `GLBLFILE` path if your Vivado install is not at `/opt/apps/xilinx/Vivado/2024.2/...`.

3) Choose scenario and toggles (inside `RTOS_PMP_FI.do`)
- `USE_PSE` = 1 uses `exported_simulation_with_pse`; 0 uses `..._no_pse`
- `CORRUPT_PSE_SLOT_2` = 1 randomly corrupts PSE snapshot slot 2; 0 randomly corrupts PMP CSRs directly
- `DEACTIVATE_PSE_FI_DETECTION` = 1 suppresses PSE’s FI detection signal for experiments
- `ITERATIONS` controls the number of randomized runs (default 100000)
- `CHECKPOINT_TIME` differs for PSE/no‑PSE to align with the context‑switch moment; adjust if you change software timing

4) Run Questa in batch mode from the simulation environment directory

```bash
cd Questa_Simulation_Environment/
vsim -c -do RTOS_PMP_FI.do
```

Outputs
- `Questa_Simulation_Environment/results/results.csv` — one line per iteration:
  - iteration, timestamp, wavefile path, verdict (PASS/FAIL/DNF), `mcause`, `mepc`, PMP configs (0–15), PMP addrs (0–15)
  - when corrupting PSE slot 2: the full hex image of `snapshot_regions_mem[2]`
  - PSE diagnostics: `comparison_fault`, `parity_invalid`
- `iter_XXXX.wlf` — per‑iteration wave databases (saved under `Questa_Simulation_Environment/results/`). Can be viewed with: 

```
vsim -view ./results/iter_XXXX.wlf
```

Verdicts
- PASS: Task 2 successfully accessed the secret data of Task 1
- FAIL: access violation was properly detected
- DNF: did not finish within the scripted timeout window (typically due to a corrupted PMP configuration that even prohibits the execution of the exception handler in M-Mode which is possible with a set Lock-bit in the PMP configurations)


## Firmware configuration reference (`rtos_config.h`)

Key switches used across FPGA and FI simulation:
- `FI_VIVADO_SIMULATION_SETUP`
  - 0 = FPGA run: `CPU_CLOCK_HZ=20 MHz`, `TICK_RATE_HZ=1 Hz`
  - 1 = FI simulation: `CPU_CLOCK_HZ=10 MHz`, `TICK_RATE_HZ=100 Hz`
- `SKIP_UART_PRINT` — suppress UART prints during FI sims to speed up runs (tied to `FI_VIVADO_SIMULATION_SETUP`)
- `FI_EXPERIMENT_SETUP` — 1 lets Task 2 attempt to access Task 1’s data (to exercise PMP violations)
- `PSE_ACTIVATED` — 1 enables PSE duplication/checking of PMP settings
- Other parameters: `MAX_TASKS`, `TASK_STACK_SIZE`, `N_PMP_REGIONS`, MTIME/MTIMECMP base addresses

For ready‑made BRAM images/bitstream and the exact “for FPGA vs. for FI” `rtos_config.h` values, see `coe-files/README.txt`.



## Notes and acknowledgments

- CV32E40S is a RISC‑V core by OpenHW Group (https://github.com/openhwgroup/cv32e40s, commit 3cec6d3); this project integrates it with a PSE extension and peripheral system.  Parts of the RTL are located in `Vivado_PSE_Project/project_1.srcs/sources_1/design_database/IP/cv32e40s_core/` and modifications to each file are marked in the header of the file.


## Citation

If you use this work in academic or industrial research, please cite it as "tba".


## Licensing

- Software (C sources, scripts, Makefiles, Python utilities): Apache License 2.0 — see `LICENSES/Apache-2.0.txt`.
- Hardware/HDL (RTL, block designs, constraints and PSE sources): Solderpad Hardware License v0.51 — see `LICENSES/Solderpad-0.51.txt`.
