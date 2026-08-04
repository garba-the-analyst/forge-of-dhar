# Dhar Compiler - Master Build Script
# Architecture: x86_64 Linux

# Toolchain definitions
AS = nasm
LD = ld

# Flags
# -f elf64 : Targets 64-bit Linux executable format
# -g -F dwarf : Generates debug symbols for GDB
ASFLAGS = -f elf64 -g -F dwarf
LDFLAGS = -m elf_x86_64

# Directories
SRC_DIR = src
BUILD_DIR = build

# Source and Object files
# Currently targeting the lexer, this will expand as we build the parser
SOURCES = $(SRC_DIR)/lexer.asm
OBJECTS = $(BUILD_DIR)/lexer.o

# Final Executable Name
EXECUTABLE = $(BUILD_DIR)/dharc

# Default build target
all: clean setup $(EXECUTABLE)

# Create build directory if it doesn't exist
setup:
	mkdir -p $(BUILD_DIR)

# Link the object files into the final executable
$(EXECUTABLE): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $(OBJECTS)

# Compile Assembly source into object files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm
	$(AS) $(ASFLAGS) $< -o $@

# Run the compiled binary
run: all
	./$(EXECUTABLE)

# Clean the build directory
clean:
	rm -rf $(BUILD_DIR)/*

# Declare phony targets to prevent conflicts with file names
.PHONY: all setup run clean