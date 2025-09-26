# Linker file
LD_SCRIPT   ?= linker/link.common.ld

# Toolchain prefix
CROSS       ?= riscv32-unknown-elf-

# This assumes that the RISC-V toolchain is located in ~/.riscv
RISCV           ?= $(HOME)/.riscv
RISCV_PREFIX	?= $(RISCV)/bin/riscv32-unknown-elf-
CC               = $(RISCV_PREFIX)gcc
AS               = $(RISCV_PREFIX)gcc
OBJCOPY          = $(RISCV_PREFIX)objcopy
OBJDUMP          = $(RISCV_PREFIX)objdump
SIZE             = $(RISCV_PREFIX)size

# Flags
CFLAGS +=   -march=rv32imac     # I (Base), M (Multiply), A (Atomic) and C (Compressed instructions) extensions
CFLAGS +=   -mabi=ilp32         # int/long/pointer are 32 bit
CFLAGS +=   -nostartfiles       # Prevents injecting its own crt0.S file (leads to multiple declaration of _start)
CFLAGS +=   -ffreestanding      # This code stands on its own; don’t expect main or libc
CFLAGS +=   -O3                 # Optimization level
    
ASFLAGS += $(CFLAGS)            # Apply all flags used for C compilation
ASFLAGS += -Wall                # Enable all common warnings (normally, only the most serious diagnostics would be reported)
ASFLAGS += -Werror              # Treat every warning as an error
   
# -Wl, means “pass the following, comma-separated items directly to the linker.”
# The commas just let GCC bundle several linker switches into the single argument that -Wl expects.         
LDFLAGS += -T$(LD_SCRIPT)       # Use own linker script instead of ld's built-in default
LDFLAGS += -Wl,--gc-sections    # Garbage-collect unused sections
LDFLAGS += -Wl,-Map,$(BUILD)/main.map   # Produces a map file showing every symbol, its address, and which input section it came from
                     
# Build directories
BUILD := build
OBJ   := $(BUILD)/obj
IMG   := $(BUILD)/img

# Source lists
CSRCS   := $(wildcard src/*.c drivers/src/*.c)
OBJS    := $(addprefix $(OBJ)/,$(notdir $(CSRCS:.c=.o))) \
           $(OBJ)/crt0.o \
           $(OBJ)/context_switching.o \
		   $(OBJ)/vectors.o

.PHONY: all clean

all: $(IMG)/firmware.elf
	$(OBJCOPY) -O binary $< $(IMG)/firmware.bin
	$(OBJDUMP) --source --all-headers --demangle --line-numbers --wide --prefix-addresses --full-contents  $< > $(IMG)/firmware.lst
	$(OBJCOPY) -O srec $< $(IMG)/firmware.srec
	bash ./scripts/srec2dat.sh
	bash ./scripts/dat2coe.sh
	@echo "Built $@"

# Compile C
$(OBJ)/%.o: src/%.c | $(OBJ)
	$(CC) $(CFLAGS) -Iinclude -Idrivers/include -Ilibs/string_lib/inc -Ilibs/sys_lib/inc -Icrt -c $< -o $@
	
# Compile drivers
$(OBJ)/%.o: drivers/src/%.c | $(OBJ)
	$(CC) $(CFLAGS) -Iinclude -Idrivers/include -Ilibs/string_lib/inc -c $< -o $@

# Compile crt0 (assembler-with-cpp)
$(OBJ)/crt0.o: crt/crt0.S | $(OBJ)
	$(AS) $(ASFLAGS) -Icrt -c $< -o $@

$(OBJ)/vectors.o: src/vectors.S | $(OBJ)
	$(AS) $(ASFLAGS) -Icrt -c $< -o $@

$(OBJ)/context_switching.o: src/context_switching.S | $(OBJ)
	$(AS) $(ASFLAGS) -Icrt -c $< -o $@

# Link
$(IMG)/firmware.elf: $(OBJS) | $(IMG)
	$(CC) $(CFLAGS) $(OBJS) $(LDFLAGS) -o $@

# Create output dirs if needed
$(OBJ) $(IMG):
	mkdir -p $@

clean:
	rm -rf $(BUILD)
