//============================================================================
// Module: coffee_machine_top
// Description: Top-level integration with maintenance menu and error cycling
//              Integrates all subsystems including new features
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module coffee_machine_top (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         CLOCK_50,
    
    //========================================================================
    // Push Buttons (DE2-115 KEY[3:0])
    //========================================================================
    input  wire         KEY0,                   // Right button
    input  wire         KEY1,                   // Cancel/Back button
    input  wire         KEY2,                   // Left button
    input  wire         KEY3,                   // Select/Start button
    
    //========================================================================
    // Switches (DE2-115 SW[17:0])
    //========================================================================
    input  wire         SW0,  input  wire SW1,  // Paper [1:0]
    input  wire         SW2,  input  wire SW3,  // Bin0 [1:0]
    input  wire         SW4,  input  wire SW5,  // Bin1 [1:0]
    input  wire         SW6,  input  wire SW7,  // Creamer [1:0]
    input  wire         SW8,  input  wire SW9,  // Chocolate [1:0]
    input  wire         SW10, input  wire SW11, // Pressure [1:0]
    input  wire         SW12,                   // Temp override
    input  wire         SW13,                   // System fault
    input  wire         SW14,                   // Reserved
    input  wire         SW15,                   // Reserved
    input  wire         SW16,                   // Reserved
    input  wire         SW17,                   // RESET
    
    //========================================================================
    // LEDs
    //========================================================================
    output wire         LEDR0,  LEDR1,  LEDR2,  LEDR3,
    output wire         LEDR4,  LEDR5,  LEDR6,  LEDR7,
    output wire         LEDR8,  LEDR9,  LEDR10, LEDR11,
    output wire         LEDR12, LEDR13, LEDR14, LEDR15,
    output wire         LEDR16, LEDR17,
    
    output wire         LEDG0,  LEDG1,  LEDG2,  LEDG3,
    output wire         LEDG4,  LEDG5,  LEDG6,  LEDG7,
    output wire         LEDG8,
    
    //========================================================================
    // LCD Display Interface
    //========================================================================
    output wire         LCD_ON,
    output wire         LCD_BLON,
    output wire         LCD_EN,
    output wire         LCD_RS,
    output wire         LCD_RW,
    output wire [7:0]   LCD_DATA,
    
    //========================================================================
    // 7-Segment Displays (HEX7-HEX0)
    //========================================================================
    output wire [6:0]   HEX0, HEX1, HEX2, HEX3,
    output wire [6:0]   HEX4, HEX5, HEX6, HEX7
);

    //========================================================================
    // Internal Signals - Clock and Reset
    //========================================================================
    
    wire clk;
    wire rst_n;
    
    assign clk = CLOCK_50;
    
    // Reset synchronizer
    reg reset_sync1, reset_sync2;
    
    always @(posedge clk) begin
        reset_sync1 <= ~SW17;
        reset_sync2 <= reset_sync1;
    end
    
    assign rst_n = reset_sync2;
    
    //========================================================================
    // Internal Signals - Menu Navigator
    //========================================================================
    
    wire [3:0] menu_state;
    wire [2:0] selected_coffee_type;
    wire [2:0] selected_drink_type;
    wire [1:0] selected_size;
    wire [1:0] selected_maint_option;
    wire start_brewing_cmd;
    wire enter_settings_mode;
    wire enter_maintenance_mode;
    wire manual_check_requested;
    wire display_refresh;
    
    //========================================================================
    // Internal Signals - Main FSM
    //========================================================================
    
    wire recipe_start_brewing;
    wire recipe_abort_brewing;
    wire water_heating_enable;
    wire [1:0] water_target_temp_mode;
    wire system_fault;
    wire system_ready;
    wire system_active;
    wire emergency_stop;
    wire [2:0] brew_stage;
    
    // Error cycling and service timer
    wire error_cycle_enable;
    wire service_timer_enable;
    wire manual_check_clear;
    
    //========================================================================
    // Internal Signals - Recipe Engine
    //========================================================================
    
    wire consume_enable;
    wire [7:0] consume_bin0_amount;
    wire [7:0] consume_bin1_amount;
    wire [7:0] consume_creamer_amount;
    wire [7:0] consume_chocolate_amount;
    wire consume_paper_filter;
    
    wire grinder0_enable;
    wire grinder1_enable;
    wire water_pour_enable;
    wire water_direct_enable;
    wire paper_motor_enable;
    
    wire recipe_brewing_active;
    wire recipe_brewing_complete;
    wire [7:0] brew_progress;
    wire recipe_valid;
    
    //========================================================================
    // Internal Signals - Consumable Manager
    //========================================================================
    
    wire [7:0] coffee_bin0_level;
    wire [7:0] coffee_bin1_level;
    wire [7:0] creamer_level;
    wire [7:0] chocolate_level;
    wire [7:0] paper_filter_count;
    
    wire bin0_empty, bin0_low;
    wire bin1_empty, bin1_low;
    wire creamer_empty, creamer_low;
    wire chocolate_empty, chocolate_low;
    wire paper_empty, paper_low;
    
    wire can_make_coffee;
    wire can_add_creamer;
    wire can_add_chocolate;
    
    //========================================================================
    // Internal Signals - Sensor Interface
    //========================================================================
    
    wire [7:0] sensor_bin0_level;
    wire [7:0] sensor_bin1_level;
    wire [7:0] sensor_creamer_level;
    wire [7:0] sensor_chocolate_level;
    wire paper_filter_present;
    wire [1:0] water_pressure;
    wire pressure_ready;
    wire pressure_ready_sensor;
    wire temp_override;
    wire system_fault_flag;
    
    //========================================================================
    // Internal Signals - Water Temperature Controller
    //========================================================================
    
    wire heater_enable;
    wire [7:0] current_temp;
    wire [7:0] target_temp;
    wire temp_ready;
    wire water_system_ok;
    
    //========================================================================
    // Internal Signals - Error Handler
    //========================================================================
    
    wire critical_error;
    wire error_present;
    wire [3:0] warning_count;
    wire [3:0] error_count;
    
    wire err_no_water, err_no_paper, err_no_coffee;
    wire err_temp_fault, err_pressure_fault, err_system_fault;
    wire warn_paper_low, warn_bin0_low, warn_bin1_low;
    wire warn_creamer_low, warn_chocolate_low, warn_temp_heating;
    
    //========================================================================
    // Internal Signals - Actuator Control
    //========================================================================
    
    wire led_heater, led_water_pour, led_water_direct;
    wire led_grinder0, led_grinder1, led_paper_motor;
    wire actuators_active;
    wire [2:0] active_count;
    
    //========================================================================
    // Internal Signals - Message Manager
    //========================================================================
    
    wire [127:0] msg_line1_text;
    wire [127:0] msg_line2_text;
    wire message_updated;
    
    //========================================================================
    // Internal Signals - Error Message Cycler
    //========================================================================
    
    wire [127:0] error_line1_text;
    wire [127:0] error_line2_text;
    wire error_message_updated;
    wire [3:0] current_error_message_index;
    
    //========================================================================
    // Internal Signals - Service Timer
    //========================================================================
    
    wire [31:0] seconds_since_service;
    wire [31:0] minutes_since_service;
    wire [31:0] hours_since_service;
    wire [31:0] days_since_service;
    
    //========================================================================
    // Internal Signals - LCD Multiplexing
    //========================================================================
    
    wire [127:0] final_line1;
    wire [127:0] final_line2;
    wire final_message_updated;
    
    // FSM state for LCD mux decision
    wire [4:0] fsm_current_state;  // From main FSM
    
    //========================================================================
    // Internal Signals - LED Status
    //========================================================================
    
    wire led_paper_filter;
    wire led_coffee_bin0;
    wire led_coffee_bin1;
    wire led_creamer;
    wire led_chocolate;
    wire led_water_pressure;
    wire led_water_temp;
    wire led_system_error;
    
    // Generate status LEDs
    assign led_paper_filter = !paper_empty;
    assign led_coffee_bin0 = !bin0_empty;
    assign led_coffee_bin1 = !bin1_empty;
    assign led_creamer = !creamer_empty;
    assign led_chocolate = !chocolate_empty;
    assign led_water_pressure = pressure_ready;
    assign led_water_temp = temp_ready;
    assign led_system_error = system_fault_flag;
    
    //========================================================================
    // Internal Signals - LCD Controller
    //========================================================================
    
    wire lcd_ready;
    wire lcd_busy;
    
    //========================================================================
    // Module Instantiations
    //========================================================================
    
    //------------------------------------------------------------------------
    // Sensor Interface
    //------------------------------------------------------------------------
    sensor_interface sensor_interface_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Switch inputs (2-bit encoding)
        .SW0(SW0), .SW1(SW1),       // Paper
        .SW2(SW2), .SW3(SW3),       // Bin0
        .SW4(SW4), .SW5(SW5),       // Bin1
        .SW6(SW6), .SW7(SW7),       // Creamer
        .SW8(SW8), .SW9(SW9),       // Chocolate
        .SW10(SW10), .SW11(SW11),   // Pressure
        .SW12(SW12),                // Temp override
        .SW13(SW13),                // System fault
        .SW14(SW14),
        .SW15(SW15),
        .SW16(SW16),
        .SW17(SW17),
        
        // Outputs
        .sensor_bin0_level(sensor_bin0_level),
        .sensor_bin1_level(sensor_bin1_level),
        .sensor_creamer_level(sensor_creamer_level),
        .sensor_chocolate_level(sensor_chocolate_level),
        .paper_filter_present(paper_filter_present),
        .water_pressure(water_pressure),
        .pressure_ready(pressure_ready_sensor),
        .temp_override(temp_override),
        .system_fault_flag(system_fault_flag)
    );
    
    //------------------------------------------------------------------------
    // Consumable Manager
    //------------------------------------------------------------------------
    consumable_manager consumable_manager_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Sensor inputs
        .sensor_bin0_level(sensor_bin0_level),
        .sensor_bin1_level(sensor_bin1_level),
        .sensor_creamer_level(sensor_creamer_level),
        .sensor_chocolate_level(sensor_chocolate_level),
        .paper_filter_present(paper_filter_present),
        
        // Consumption from recipe engine
        .consume_enable(consume_enable),
        .consume_bin0_amount(consume_bin0_amount),
        .consume_bin1_amount(consume_bin1_amount),
        .consume_creamer_amount(consume_creamer_amount),
        .consume_chocolate_amount(consume_chocolate_amount),
        .consume_paper_filter(consume_paper_filter),
        
        // Level outputs
        .coffee_bin0_level(coffee_bin0_level),
        .coffee_bin1_level(coffee_bin1_level),
        .creamer_level(creamer_level),
        .chocolate_level(chocolate_level),
        .paper_filter_count(paper_filter_count),
        
        // Status flags
        .bin0_empty(bin0_empty),
        .bin0_low(bin0_low),
        .bin1_empty(bin1_empty),
        .bin1_low(bin1_low),
        .creamer_empty(creamer_empty),
        .creamer_low(creamer_low),
        .chocolate_empty(chocolate_empty),
        .chocolate_low(chocolate_low),
        .paper_empty(paper_empty),
        .paper_low(paper_low),
        
        // Availability flags
        .can_make_coffee(can_make_coffee),
        .can_add_creamer(can_add_creamer),
        .can_add_chocolate(can_add_chocolate)
    );
    
    //------------------------------------------------------------------------
    // Error Handler
    //------------------------------------------------------------------------
    error_handler error_handler_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Consumable status
        .bin0_empty(bin0_empty),
        .bin0_low(bin0_low),
        .bin1_empty(bin1_empty),
        .bin1_low(bin1_low),
        .creamer_empty(creamer_empty),
        .creamer_low(creamer_low),
        .chocolate_empty(chocolate_empty),
        .chocolate_low(chocolate_low),
        .paper_empty(paper_empty),
        .paper_low(paper_low),
        
        // Water system status
        .temp_ready(temp_ready),
        .pressure_ready(pressure_ready),
        .water_system_ok(water_system_ok),
        .brewing_active(recipe_brewing_active),
        
        // System status
        .system_fault_flag(system_fault_flag),
        .actuator_timeout(1'b0),
        .recipe_valid(recipe_valid),
        .can_make_coffee(can_make_coffee),
        
        // Error outputs
        .critical_error(critical_error),
        .error_present(error_present),
        .warning_count(warning_count),
        .error_count(error_count),
        
        // Individual error flags
        .err_no_water(err_no_water),
        .err_no_paper(err_no_paper),
        .err_no_coffee(err_no_coffee),
        .err_temp_fault(err_temp_fault),
        .err_pressure_fault(err_pressure_fault),
        .err_system_fault(err_system_fault),
        
        // Individual warning flags
        .warn_paper_low(warn_paper_low),
        .warn_bin0_low(warn_bin0_low),
        .warn_bin1_low(warn_bin1_low),
        .warn_creamer_low(warn_creamer_low),
        .warn_chocolate_low(warn_chocolate_low),
        .warn_temp_heating(warn_temp_heating)
    );
    
    //------------------------------------------------------------------------
    // Error Message Cycler
    //------------------------------------------------------------------------
    error_message_cycler error_cycler_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Control
        .cycle_enable(error_cycle_enable),
        
        // Error flags
        .err_no_water(err_no_water),
        .err_no_paper(err_no_paper),
        .err_no_coffee(err_no_coffee),
        .err_temp_fault(err_temp_fault),
        .err_pressure_fault(err_pressure_fault),
        .err_system_fault(err_system_fault),
        
        // Warning flags
        .warn_paper_low(warn_paper_low),
        .warn_bin0_low(warn_bin0_low),
        .warn_bin1_low(warn_bin1_low),
        .warn_creamer_low(warn_creamer_low),
        .warn_chocolate_low(warn_chocolate_low),
        .warn_temp_heating(warn_temp_heating),
        
        // Consumable info
        .bin0_empty(bin0_empty),
        .bin1_empty(bin1_empty),
        
        // Outputs
        .line1_text(error_line1_text),
        .line2_text(error_line2_text),
        .message_updated(error_message_updated),
        .current_message_index(current_error_message_index)
    );
    
    //------------------------------------------------------------------------
    // Service Timer
    //------------------------------------------------------------------------
    service_timer service_timer_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Control
        .manual_check_clear(manual_check_clear),
        .timer_enable(service_timer_enable),
        
        // Outputs
        .seconds_since_service(seconds_since_service),
        .minutes_since_service(minutes_since_service),
        .hours_since_service(hours_since_service),
        .days_since_service(days_since_service)
    );
    
    //------------------------------------------------------------------------
    // Water Temperature Controller
    //------------------------------------------------------------------------
    water_temp_controller water_temp_controller_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Control inputs
        .heating_enable(water_heating_enable),
        .target_temp_mode(water_target_temp_mode),
        .water_temp_override(temp_override),
        .water_pressure_ok(pressure_ready_sensor),
        .brewing_active(recipe_brewing_active),
        .pressure_override(1'b0),
        
        // Outputs
        .heater_enable(heater_enable),
        .current_temp(current_temp),
        .target_temp(target_temp),
        .temp_ready(temp_ready),
        .pressure_ready(pressure_ready),
        .water_system_ok(water_system_ok),
        .overheat_error()
    );
    
    //------------------------------------------------------------------------
    // Recipe Engine
    //------------------------------------------------------------------------
    recipe_engine recipe_engine_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Recipe selection
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        
        // Consumable levels
        .coffee_bin0_level(coffee_bin0_level),
        .coffee_bin1_level(coffee_bin1_level),
        .creamer_level(creamer_level),
        .chocolate_level(chocolate_level),
        .paper_filter_count(paper_filter_count),
        
        // Control
        .start_brewing(recipe_start_brewing),
        .abort_brewing(recipe_abort_brewing),
        
        // Consumption outputs
        .consume_enable(consume_enable),
        .consume_bin0_amount(consume_bin0_amount),
        .consume_bin1_amount(consume_bin1_amount),
        .consume_creamer_amount(consume_creamer_amount),
        .consume_chocolate_amount(consume_chocolate_amount),
        .consume_paper_filter(consume_paper_filter),
        
        // Actuator control
        .grinder0_enable(grinder0_enable),
        .grinder1_enable(grinder1_enable),
        .water_pour_enable(water_pour_enable),
        .water_direct_enable(water_direct_enable),
        .paper_motor_enable(paper_motor_enable),
        
        // Status outputs
        .brewing_active(recipe_brewing_active),
        .brewing_complete(recipe_brewing_complete),
        .brew_progress(brew_progress),
        .recipe_valid(recipe_valid)
    );
    
    //------------------------------------------------------------------------
    // Menu Navigator
    //------------------------------------------------------------------------
    menu_navigator menu_navigator_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Button inputs (active low from board)
        .btn_cancel(~KEY1),
        .btn_left(~KEY3),
        .btn_right(~KEY0),
        .btn_select(~KEY2),
        
        // System status
        .system_ready(system_ready),
        .brewing_active(recipe_brewing_active),
        .error_present(error_present),
        .warning_count(warning_count),
        .error_count(error_count),
        
        // Recipe validation
        .recipe_valid(recipe_valid),
        .can_make_coffee(can_make_coffee),
        
        // Water system
        .temp_ready(temp_ready),
        .pressure_ready(pressure_ready),
        
        // Service timer (NEW)
        .hours_since_service(hours_since_service),
        .days_since_service(days_since_service),
        
        // Outputs
        .current_menu_state(menu_state),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        .start_brewing_cmd(start_brewing_cmd),
        .enter_settings_mode(enter_settings_mode),
        .enter_maintenance_mode(enter_maintenance_mode),
        .manual_check_requested(manual_check_requested),
        .display_refresh(display_refresh)
    );
    
    //------------------------------------------------------------------------
    // Main FSM
    //------------------------------------------------------------------------
    main_fsm main_fsm_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Menu interface
        .menu_state(menu_state),
        .start_brewing_cmd(start_brewing_cmd),
        .enter_settings_mode(enter_settings_mode),
        .enter_maintenance_mode(enter_maintenance_mode),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        
        // Recipe engine interface
        .recipe_start_brewing(recipe_start_brewing),
        .recipe_abort_brewing(recipe_abort_brewing),
        .recipe_brewing_active(recipe_brewing_active),
        .recipe_brewing_complete(recipe_brewing_complete),
        .recipe_valid(recipe_valid),
        
        // Water system interface
        .water_heating_enable(water_heating_enable),
        .water_target_temp_mode(water_target_temp_mode),
        .water_temp_ready(temp_ready),
        .water_pressure_ready(pressure_ready),
        .water_system_ok(water_system_ok),
        
        // Consumables
        .can_make_coffee(can_make_coffee),
        .paper_filter_present(paper_filter_present),
        
        // Error handler
        .critical_error(critical_error),
        .warning_count(warning_count),
        .error_count(error_count),
        .system_fault(system_fault),
        
        // Service timer (NEW)
        .manual_check_clear(manual_check_clear),
        .service_timer_enable(service_timer_enable),
        
        // Error cycling (NEW)
        .error_cycle_enable(error_cycle_enable),
        
        // Status outputs
        .system_ready(system_ready),
        .system_active(system_active),
        .emergency_stop(emergency_stop),
        .brew_stage(brew_stage)
    );
    
    
    //------------------------------------------------------------------------
    // Actuator Control
    //------------------------------------------------------------------------
    actuator_control actuator_control_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Recipe engine commands
        .grinder0_cmd(grinder0_enable),
        .grinder1_cmd(grinder1_enable),
        .water_pour_cmd(water_pour_enable),
        .water_direct_cmd(water_direct_enable),
        .paper_motor_cmd(paper_motor_enable),
        
        // Water system
        .heater_cmd(heater_enable),
        .temp_ready(temp_ready),
        .pressure_ready(pressure_ready),
        .water_system_ok(water_system_ok),
        
        // System status
        .system_fault(system_fault),
        .paper_filter_present(paper_filter_present),
        .brewing_active(recipe_brewing_active),
        .emergency_stop(emergency_stop),
        
        // LED outputs
        .led_heater(led_heater),
        .led_water_pour(led_water_pour),
        .led_water_direct(led_water_direct),
        .led_grinder0(led_grinder0),
        .led_grinder1(led_grinder1),
        .led_paper_motor(led_paper_motor),
        
        // Status
        .actuators_active(actuators_active),
        .active_count(active_count)
    );
    
    //------------------------------------------------------------------------
    // Message Manager
    //------------------------------------------------------------------------
    message_manager message_manager_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Menu state
        .current_menu_state(menu_state),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        .selected_maint_option(selected_maint_option),
        
        // System status
        .brew_progress(brew_progress),
        .warning_count(warning_count),
        .error_count(error_count),
        .error_present(error_present),
        
        // Service timer (NEW)
        .hours_since_service(hours_since_service),
        .days_since_service(days_since_service),
        
        // Consumable status
        .bin0_empty(bin0_empty),
        .bin0_low(bin0_low),
        .bin1_empty(bin1_empty),
        .bin1_low(bin1_low),
        .creamer_empty(creamer_empty),
        .creamer_low(creamer_low),
        .chocolate_empty(chocolate_empty),
        .chocolate_low(chocolate_low),
        .paper_empty(paper_empty),
        .paper_low(paper_low),
        
        // Water system
        .temp_ready(temp_ready),
        .pressure_ready(pressure_ready),
        
        // LCD output
        .line1_text(msg_line1_text),
        .line2_text(msg_line2_text),
        .message_updated(message_updated)
    );
    
    //------------------------------------------------------------------------
    // LCD Display Multiplexing
    //------------------------------------------------------------------------
    // When in error cycling state, show error messages
    // Otherwise show normal menu messages
    assign final_line1 = error_cycle_enable ? error_line1_text : msg_line1_text;
    assign final_line2 = error_cycle_enable ? error_line2_text : msg_line2_text;
    assign final_message_updated = error_cycle_enable ? error_message_updated : message_updated;
    
    //------------------------------------------------------------------------
    // LCD Controller
    //------------------------------------------------------------------------
    lcd_controller lcd_controller_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // String interface
        .line1_data(final_line1),
        .line2_data(final_line2),
        .update_display(final_message_updated | display_refresh),
        
        // LCD hardware interface
        .LCD_ON(LCD_ON),
        .LCD_BLON(LCD_BLON),
        .LCD_EN(LCD_EN),
        .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW),
        .LCD_DATA(LCD_DATA),
        
        // Status
        .ready(lcd_ready),
        .busy(lcd_busy)
    );
    
    //========================================================================
    // LED Assignments
    //========================================================================
    
    // Status LEDs (LEDR[7:0])
    assign LEDR0 = led_paper_filter;
    assign LEDR1 = led_coffee_bin0;
    assign LEDR2 = led_coffee_bin1;
    assign LEDR3 = led_creamer;
    assign LEDR4 = led_chocolate;
    assign LEDR5 = led_water_pressure;
    assign LEDR6 = led_water_temp;
    assign LEDR7 = led_system_error;
    
    // Actuator LEDs (LEDR[13:8])
    assign LEDR8 = led_heater;
    assign LEDR9 = led_water_pour; //
    assign LEDR10 = led_water_direct;
    assign LEDR11 = led_grinder0;
    assign LEDR12 = led_grinder1;
    assign LEDR13 = led_paper_motor;
    
    // System status LEDs (LEDR[17:14])
    assign LEDR14 = system_ready;
    assign LEDR15 = system_active;
    assign LEDR16 = system_fault;
    assign LEDR17 = emergency_stop;
    
    // Green LEDs (LEDG[7:0])
    assign LEDG0 = recipe_brewing_active; //
    assign LEDG1 = temp_ready;
    assign LEDG2 = pressure_ready;
    assign LEDG3 = recipe_valid;
    assign LEDG4 = can_make_coffee;
    assign LEDG5 = (warning_count > 0);        // Warning indicator
    assign LEDG6 = error_present;              // Error indicator
    assign LEDG7 = recipe_brewing_complete;
    assign LEDG8 = 1'b0;
    
    //========================================================================
    // 7-Segment Display Drivers
    //========================================================================
    
    // Determine what to show based on state
    wire show_errors_warnings;
    assign show_errors_warnings = error_cycle_enable;  // Show during error cycling
    
    // Brew progress (HEX2, HEX1, HEX0)
    wire [3:0] progress_hundreds;
    wire [3:0] progress_tens;
    wire [3:0] progress_ones;
    
    assign progress_hundreds = (brew_progress >= 100) ? 4'd1 : 4'd0;
    assign progress_tens = ((brew_progress % 100) / 10);
    assign progress_ones = (brew_progress % 10);
    
    seven_seg_decoder hex0_decoder (
        .digit(progress_ones),
        .segments(HEX0)
    );
    
    seven_seg_decoder hex1_decoder (
        .digit(progress_tens),
        .segments(HEX1)
    );
    
    seven_seg_decoder hex2_decoder (
        .digit(progress_hundreds),
        .segments(HEX2)
    );
    
    // Temperature or brew stage (HEX5, HEX4, HEX3)
    wire [3:0] temp_hundreds;
    wire [3:0] temp_tens;
    wire [3:0] temp_ones;
    
    assign temp_hundreds = (current_temp / 100);
    assign temp_tens = ((current_temp % 100) / 10);
    assign temp_ones = (current_temp % 10);
    
    seven_seg_decoder hex3_decoder (
        .digit(temp_ones),
        .segments(HEX3)
    );
    
    seven_seg_decoder hex4_decoder (
        .digit(temp_tens),
        .segments(HEX4)
    );
    
    seven_seg_decoder hex5_decoder (
        .digit(temp_hundreds),
        .segments(HEX5)
    );
    
    // Error and warning counts (HEX7, HEX6) - show during splash/error states
    wire [3:0] hex7_value;
    wire [3:0] hex6_value;
    
    assign hex7_value = show_errors_warnings ? warning_count : 4'd0;
    assign hex6_value = show_errors_warnings ? error_count : 4'd0;
    
    seven_seg_decoder hex6_decoder (
        .digit(hex6_value),
        .segments(HEX6)
    );
    
    seven_seg_decoder hex7_decoder (
        .digit(hex7_value),
        .segments(HEX7)
    );

endmodule