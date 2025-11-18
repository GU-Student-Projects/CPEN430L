# ModelSim Makefile for Coffee Machine FPGA Project - Unit Tests
# SystemVerilog Support
# Author: Gabriel DiMartino
# Date: November 2025

# ============================================================================
# Configuration
# ============================================================================

# Project Configuration
PROJECT_NAME = coffee_machine
WORK_LIB = work

# ModelSim Executables
VLIB = vlib
VMAP = vmap
VLOG = vlog
VSIM = vsim

# Compiler Flags
VLOG_FLAGS = -sv -work $(WORK_LIB)
VLOG_FLAGS += +acc
VLOG_FLAGS += -timescale 1ns/1ps

# Simulator Flags
VSIM_FLAGS = -lib $(WORK_LIB)
VSIM_FLAGS += -c
VSIM_FLAGS += -do "run -all; quit -f"
VSIM_FLAGS += -voptargs=+acc

# ============================================================================
# Source Files
# ============================================================================

# RTL Source Files
RTL_SOURCES = \
	rtl/sensor_interface.sv \
	rtl/consumable_manager.sv \
	rtl/water_temp_controller.sv \
	rtl/recipe_engine.sv \
	rtl/error_handler.sv \
	rtl/menu_navigator.sv \
	rtl/message_manager.sv \
	rtl/actuator_control.sv \
	rtl/main_fsm.sv

# Unit Test Files
UNIT_TESTS = \
	tests/unit/sensor_interface_tb.sv \
	tests/unit/consumable_manager_tb.sv \
	tests/unit/water_temp_controller_tb.sv \
	tests/unit/recipe_engine_tb.sv \
	tests/unit/menu_navigator_tb.sv \
	tests/unit/message_manager_tb.sv \
	tests/unit/remaining_tests.sv

# ============================================================================
# Targets
# ============================================================================

.PHONY: all clean help setup check
.PHONY: test_all test_sensor test_consumable test_water test_recipe 
.PHONY: test_menu test_message test_actuator test_error test_fsm

# Default target
all: help

# Display help information
help:
	@echo "================================================================"
	@echo "Coffee Machine FPGA - Unit Test Suite"
	@echo "================================================================"
	@echo ""
	@echo "Setup:"
	@echo "  make setup         - Create work library"
	@echo "  make clean         - Remove generated files"
	@echo ""
	@echo "Run All Tests:"
	@echo "  make test_all      - Run all 9 unit tests"
	@echo ""
	@echo "Individual Tests (recommended order):"
	@echo "  make test_message  - Test message_manager (fastest)"
	@echo "  make test_sensor   - Test sensor_interface"
	@echo "  make test_consumable - Test consumable_manager"
	@echo "  make test_water    - Test water_temp_controller"
	@echo "  make test_menu     - Test menu_navigator"
	@echo "  make test_error    - Test error_handler"
	@echo "  make test_actuator - Test actuator_control"
	@echo "  make test_fsm      - Test main_fsm"
	@echo "  make test_recipe   - Test recipe_engine (slowest ~10s)"
	@echo ""
	@echo "Utility:"
	@echo "  make check         - Check syntax only"
	@echo "================================================================"

# Setup work library
setup:
	@echo "Creating work library..."
	@if exist $(WORK_LIB) rmdir /S /Q $(WORK_LIB)
	$(VLIB) $(WORK_LIB)
	$(VMAP) work $(WORK_LIB)
	@echo "Setup complete!"

# ============================================================================
# Individual Unit Tests
# ============================================================================

test_sensor: setup
	@echo "========================================"
	@echo "Testing: Sensor Interface"
	@echo "========================================"
	$(VLOG) $(VLOG_FLAGS) rtl/sensor_interface.sv tests/unit/sensor_interface_tb.sv
	$(VSIM) $(VSIM_FLAGS) sensor_interface_tb

test_consumable: setup
	@echo "========================================"
	@echo "Testing: Consumable Manager"
	@echo "========================================"
	$(VLOG) $(VLOG_FLAGS) rtl/consumable_manager.sv tests/unit/consumable_manager_tb.sv
	$(VSIM) $(VSIM_FLAGS) consumable_manager_tb

test_water: setup
	@echo "========================================"
	@echo "Testing: Water Temperature Controller"
	@echo "========================================"
	$(VLOG) $(VLOG_FLAGS) rtl/water_temp_controller.sv tests/unit/water_temp_controller_tb.sv
	$(VSIM) $(VSIM_FLAGS) water_temp_controller_tb

test_recipe: setup
	@echo "========================================"
	@echo "Testing: Recipe Engine (~10 seconds)"
	@echo "========================================"
	$(VLOG) $(VLOG_FLAGS) rtl/recipe_engine.sv tests/unit/recipe_engine_tb.sv
	$(VSIM) $(VSIM_FLAGS) recipe_engine_tb

test_menu: setup
	@echo "========================================"
	@echo "Testing: Menu Navigator"
	@echo "========================================"
	$(VLOG) $(VLOG_FLAGS) rtl/menu_navigator.sv tests/unit/menu_navigator_tb.sv
	$(VSIM) $(VSIM_FLAGS) menu_navigator_tb

test_message: setup
	@echo "========================================"
	@echo "Testing: Message Manager"
	@echo "========================================"
	$(VLOG) $(VLOG_FLAGS) rtl/message_manager.sv tests/unit/message_manager_tb.sv
	$(VSIM) $(VSIM_FLAGS) message_manager_tb

test_actuator: setup
	@echo "========================================"
	@echo "Testing: Actuator Control"
	@echo "========================================"
	$(VLOG) $(VLOG_FLAGS) rtl/actuator_control.sv tests/unit/actuator_control_tb.sv
	$(VSIM) $(VSIM_FLAGS) actuator_control_tb

test_error: setup
	@echo "========================================"
	@echo "Testing: Error Handler"
	@echo "========================================"
	$(VLOG) $(VLOG_FLAGS) rtl/error_handler.sv tests/unit/error_handler_tb.sv
	$(VSIM) $(VSIM_FLAGS) error_handler_tb

test_fsm: setup
	@echo "========================================"
	@echo "Testing: Main FSM"
	@echo "========================================"
	$(VLOG) $(VLOG_FLAGS) rtl/main_fsm.sv tests/unit/main_fsm_tb.sv
	$(VSIM) $(VSIM_FLAGS) main_fsm_tb

# ============================================================================
# Run All Unit Tests
# ============================================================================

test_all: setup
	@echo "========================================"
	@echo "Running Complete Unit Test Suite"
	@echo "========================================"
	@echo ""
	@echo "[1/9] Message Manager..."
	@$(VLOG) $(VLOG_FLAGS) rtl/message_manager.sv tests/unit/message_manager_tb.sv
	@$(VSIM) $(VSIM_FLAGS) message_manager_tb
	@echo ""
	@echo "[2/9] Sensor Interface..."
	@$(VLOG) $(VLOG_FLAGS) rtl/sensor_interface.sv tests/unit/sensor_interface_tb.sv
	@$(VSIM) $(VSIM_FLAGS) sensor_interface_tb
	@echo ""
	@echo "[3/9] Consumable Manager..."
	@$(VLOG) $(VLOG_FLAGS) rtl/consumable_manager.sv tests/unit/consumable_manager_tb.sv
	@$(VSIM) $(VSIM_FLAGS) consumable_manager_tb
	@echo ""
	@echo "[4/9] Water Temperature Controller..."
	@$(VLOG) $(VLOG_FLAGS) rtl/water_temp_controller.sv tests/unit/water_temp_controller_tb.sv
	@$(VSIM) $(VSIM_FLAGS) water_temp_controller_tb
	@echo ""
	@echo "[5/9] Menu Navigator..."
	@$(VLOG) $(VLOG_FLAGS) rtl/menu_navigator.sv tests/unit/menu_navigator_tb.sv
	@$(VSIM) $(VSIM_FLAGS) menu_navigator_tb
	@echo ""
	@echo "[6/9] Error Handler..."
	@$(VLOG) $(VLOG_FLAGS) rtl/error_handler.sv tests/unit/error_handler_tb.sv
	@$(VSIM) $(VSIM_FLAGS) error_handler_tb
	@echo ""
	@echo "[7/9] Actuator Control..."
	@$(VLOG) $(VLOG_FLAGS) rtl/actuator_control.sv tests/unit/actuator_control_tb.sv
	@$(VSIM) $(VSIM_FLAGS) actuator_control_tb
	@echo ""
	@echo "[8/9] Main FSM..."
	@$(VLOG) $(VLOG_FLAGS) rtl/main_fsm.sv tests/unit/main_fsm_tb.sv
	@$(VSIM) $(VSIM_FLAGS) main_fsm_tb
	@echo ""
	@echo "[9/9] Recipe Engine (this takes ~10 seconds)..."
	@$(VLOG) $(VLOG_FLAGS) rtl/recipe_engine.sv tests/unit/recipe_engine_tb.sv
	@$(VSIM) $(VSIM_FLAGS) recipe_engine_tb
	@echo ""
	@echo "========================================"
	@echo "All Unit Tests Complete!"
	@echo "========================================"
	@echo "Check transcript for results"

# ============================================================================
# Integration Tests
# ============================================================================

test_integration:
	vlog -sv -work work +acc -timescale 1ns/1ps \
		rtl/menu_navigator.sv \
		rtl/main_fsm.sv \
		rtl/recipe_engine.sv \
		rtl/consumable_manager.sv \
		rtl/water_temp_controller.sv \
		rtl/actuator_control.sv \
		rtl/error_handler.sv \
		rtl/coffee_machine_top.sv \
		rtl/error_message_cycler.sv \
		rtl/service_timer.sv \
		rtl/sensor_interface.sv \
		rtl/message_manager.sv \
		rtl/lcd_controller.sv \
		rtl/lcd_driver.sv \
		rtl/seven_seg_decoder.sv \
		tests/integration/coffee_machine_core_tb.sv
	vsim -lib work -c -do "run -all; quit -f" coffee_machine_core_tb

test_integration_fast:
	vlog -sv -work work +acc -timescale 1ns/1ps \
		rtl/menu_navigator.sv \
		rtl/main_fsm.sv \
		rtl/recipe_engine.sv \
		tests/integration/coffee_machine_core_tb_fast.sv
	vsim -lib work -c -do "run -all; quit -f" coffee_machine_core_tb_fast
	
# ============================================================================
# Utility Targets
# ============================================================================

# Check syntax only (no simulation)
check: setup
	@echo "Checking syntax..."
	$(VLOG) $(VLOG_FLAGS) -lint $(RTL_SOURCES)
	$(VLOG) $(VLOG_FLAGS) -lint $(UNIT_TESTS)
	@echo "Syntax check complete!"

# Clean all generated files
clean:
	@echo "Cleaning generated files..."
	@if exist $(WORK_LIB) rmdir /S /Q $(WORK_LIB)
	@if exist transcript del /F transcript
	@if exist vsim.wlf del /F vsim.wlf
	@if exist *.vstf del /F *.vstf
	@if exist *.vcd del /F *.vcd
	@echo "Clean complete!"