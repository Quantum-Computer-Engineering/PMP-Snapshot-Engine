# .gdbinit (keep it next to the ELF or in $HOME)
set arch riscv:rv32
set disassemble-next-line on
set confirm off
set pagination off

# Connect to GDB
target remote :1234
