//============================================================================
// Module: coffee_machine_top
// Description: Top-level integration module for FPGA coffee machine controller
//              Integrates all subsystems and provides DE2-115 board interface
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//
// Target Board: Altera DE2-115 (Cyclone IV EP4CE115)
// Clock: 50 MHz
//============================================================================

`timescale 1ns/1ps

module coffee_machine_top (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         CLOCK_50,               // 50 MHz clock from board
    input  wire         KEY0,                   // Reset button (active-low)
    
    //========================================================================
    // Push Buttons (DE2-115 KEY[3:0])
    //========================================================================
    input  wire         KEY1,                   // KEY[1]: Cancel/Back button
    input  wire         KEY2,                   // KEY[2]: Left button
    input  wire         KEY3,                   // KEY[3]: Right button
    // Note: KEY[0] is used as reset
    // We'll use SW[17] as Select/Start button (more accessible)
    
    //========================================================================
    // Switches (DE2-115 SW[17:0])
    //========================================================================
    input  wire         SW0,                    // Paper filter present
    input  wire         SW1,                    // Coffee bin 0 level bit 0
    input  wire         SW2,                    // Coffee bin 0 level bit 1
    input  wire         SW3,                    // Coffee bin 1 level bit 0
    input  wire         SW4,                    // Coffee bin 1 level bit 1
    input  wire         SW5,                    // Creamer level bit 0
    input  wire         SW6,                    // Creamer level bit 1
    input  wire         SW7,                    // Chocolate level bit 0
    input  wire         SW8,                    // Chocolate level bit 1
    input  wire         SW9,                    // Water pressure override
    input  wire         SW10,                   // Water temp override
    input  wire         SW11,                   // System error simulation
    // SW[12-16] reserved
    input  wire         SW17,                   // Select/Start button
    
    //========================================================================
    // LEDs (DE2-115 LEDR[17:0] and LEDG[8:0])
    //========================================================================
    // Status LEDs (LEDR)
    output wire         LEDR0,                  // Paper filter status
    output wire         LEDR1,                  // Coffee bin 0 status
    output wire         LEDR2,                  // Coffee bin 1 status
    output wire         LEDR3,                  // Creamer status
    output wire         LEDR4,                  // Chocolate status
    output wire         LEDR5,                  // Water pressure status
    output wire         LEDR6,                  // Water temperature status
    output wire         LEDR7,                  // System error status
    
    // Actuator LEDs (LEDR)
    output wire         LEDR8,                  // Heater enable
    output wire         LEDR9,                  // Pour-over water valve
    output wire         LEDR10,                 // Direct water valve
    output wire         LEDR11,                 // Grinder 0
    output wire         LEDR12,                 // Grinder 1
    output wire         LEDR13,                 // Paper motor
    
    // System status LEDs (LEDR)
    output wire         LEDR14,                 // System ready
    output wire         LEDR15,                 // System active
    output wire         LEDR16,                 // System fault
    output wire         LEDR17,                 // Emergency stop
    
    // Green LEDs (LEDG) - Additional status
    output wire         LEDG0,                  // Brewing active
    output wire         LEDG1,                  // Temperature ready
    output wire         LEDG2,                  // Pressure ready
    output wire         LEDG3,                  // Recipe valid
    output wire         LEDG4,                  // Can make coffee
    output wire         LEDG5,                  // Warning indicator
    output wire         LEDG6,                  // Error indicator
    output wire         LEDG7,                  // Brewing complete
    // LEDG8 reserved
    
    //========================================================================
    // LCD Display Interface (DE2-115 16x2 Character LCD)
    //========================================================================
    output wire         LCD_ON,                 // LCD power control
    output wire         LCD_BLON,               // LCD backlight control
    output wire         LCD_EN,                 // LCD enable
    output wire         LCD_RS,                 // LCD register select
    output wire         LCD_RW,                 // LCD read/write
    output wire [7:0]   LCD_DATA,               // LCD data bus
    
    //========================================================================
    // 7-Segment Displays (DE2-115 HEX7-HEX0)
    //========================================================================
    output wire [6:0]   HEX0,                   // Brew progress ones digit
    output wire [6:0]   HEX1,                   // Brew progress tens digit
    output wire [6:0]   HEX2,                   // Brew progress hundreds digit
    output wire [6:0]   HEX3,                   // Current temperature ones
    output wire [6:0]   HEX4,                   // Current temperature tens
    output wire [6:0]   HEX5,                   // Current temperature hundreds
    output wire [6:0]   HEX6,                   // Error count
    output wire [6:0]   HEX7                    // Warning count
);

    //========================================================================
    // Internal Signals - Clock and Reset
    //========================================================================
    
    wire clk;
    wire rst_n;
    
    // Clock is direct from board
    assign clk = CLOCK_50;
    
    // Reset is active-low button (KEY0) - debounced
    reg [19:0] reset_counter;
    reg reset_sync1, reset_sync2;
    
    always @(posedge clk) begin
        reset_sync1 <= KEY0;
        reset_sync2 <= reset_sync1;
    end
    
    always @(posedge clk) begin
        if (!reset_sync2) begin
            reset_counter <= 20'd0;
        end else if (reset_counter < 20'd1_000_000) begin
            reset_counter <= reset_counter + 1;
        end
    end
    
    assign rst_n = (reset_counter == 20'd1_000_000);
    
    //========================================================================
    // Internal Signals - Menu Navigator
    //========================================================================
    
    wire [3:0] menu_state;
    wire [2:0] selected_coffee_type;
    wire [2:0] selected_drink_type;
    wire [1:0] selected_size;
    wire start_brewing_cmd;
    wire enter_settings_mode;
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
    
    wire paper_filter_present;
    wire [7:0] sensor_bin0_level;
    wire [7:0] sensor_bin1_level;
    wire [7:0] sensor_creamer_level;
    wire [7:0] sensor_chocolate_level;
    wire sensor_water_pressure_ok;
    wire sensor_water_temp_ready;
    wire sensor_system_fault;
    
    // LED outputs from sensor interface
    wire led_paper_filter;
    wire led_coffee_bin0;
    wire led_coffee_bin1;
    wire led_creamer;
    wire led_chocolate;
    wire led_water_pressure;
    wire led_water_temp;
    wire led_system_error;
    
    //========================================================================
    // Internal Signals - Water Temperature Controller
    //========================================================================
    
    wire heater_enable;
    wire temp_ready;
    wire pressure_ready;
    wire water_system_ok;
    wire [7:0] current_temp;
    wire [7:0] target_temp;
    
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
    
    wire led_heater;
    wire led_water_pour;
    wire led_water_direct;
    wire led_grinder0;
    wire led_grinder1;
    wire led_paper_motor;
    wire actuators_active;
    wire [5:0] active_count;
    
    //========================================================================
    // Internal Signals - Message Manager
    //========================================================================
    
    wire [127:0] line1_text;
    wire [127:0] line2_text;
    wire message_updated;
    
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
        
        // Switch inputs
        .sw_paper_filter(SW0),
        .sw_coffee_bin0({SW2, SW1}),
        .sw_coffee_bin1({SW4, SW3}),
        .sw_creamer({SW6, SW5}),
        .sw_chocolate({SW8, SW7}),
        .sw_water_pressure_ovr(SW9),
        .sw_water_temp_ovr(SW10),
        .sw_system_error(SW11),
        
        // LED outputs
        .led_paper_filter(led_paper_filter),
        .led_coffee_bin0(led_coffee_bin0),
        .led_coffee_bin1(led_coffee_bin1),
        .led_creamer(led_creamer),
        .led_chocolate(led_chocolate),
        .led_water_pressure(led_water_pressure),
        .led_water_temp(led_water_temp),
        .led_system_error(led_system_error),
        
        // Debounced outputs
        .paper_filter_present(paper_filter_present),
        .coffee_bin0_level(sensor_bin0_level),
        .coffee_bin1_level(sensor_bin1_level),
        .creamer_level(sensor_creamer_level),
        .chocolate_level(sensor_chocolate_level),
        .water_pressure_ok(sensor_water_pressure_ok),
        .water_temp_ready(sensor_water_temp_ready),
        .system_fault(sensor_system_fault)
    );
    
    //------------------------------------------------------------------------
    // Menu Navigator
    //------------------------------------------------------------------------
    menu_navigator menu_navigator_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Button inputs (active-low)
        .btn_cancel(~KEY1),
        .btn_left(~KEY2),
        .btn_right(~KEY3),
        .btn_select(SW17),
        
        // System status
        .system_ready(system_ready),
        .brewing_active(recipe_brewing_active),
        .error_present(error_present),
        .warning_count(warning_count),
        
        // Recipe validation
        .recipe_valid(recipe_valid),
        .can_make_coffee(can_make_coffee),
        
        // Menu state outputs
        .current_menu_state(menu_state),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        
        // Control outputs
        .start_brewing_cmd(start_brewing_cmd),
        .enter_settings_mode(enter_settings_mode),
        .display_refresh(display_refresh)
    );
    
    //------------------------------------------------------------------------
    // Main FSM Controller
    //------------------------------------------------------------------------
    main_fsm main_fsm_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Menu navigator interface
        .menu_state(menu_state),
        .start_brewing_cmd(start_brewing_cmd),
        .enter_settings_mode(enter_settings_mode),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        
        // Recipe engine interface
        .recipe_start_brewing(recipe_start_brewing),
        .recipe_abort_brewing(recipe_abort_brewing),
        .recipe_brewing_active(recipe_brewing_active),
        .recipe_brewing_complete(recipe_brewing_complete),
        .recipe_valid(recipe_valid),
        
        // Water controller interface
        .water_heating_enable(water_heating_enable),
        .water_target_temp_mode(water_target_temp_mode),
        .water_temp_ready(temp_ready),
        .water_pressure_ready(pressure_ready),
        .water_system_ok(water_system_ok),
        
        // Consumable manager interface
        .can_make_coffee(can_make_coffee),
        .paper_filter_present(paper_filter_present),
        
        // Error handler interface
        .critical_error(critical_error),
        .warning_count(warning_count),
        .system_fault(system_fault),
        
        // System status outputs
        .system_ready(system_ready),
        .system_active(system_active),
        .emergency_stop(emergency_stop)
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
        
        // Brewing control
        .start_brewing(recipe_start_brewing),
        .abort_brewing(recipe_abort_brewing),
        
        // Consumable manager interface
        .consume_enable(consume_enable),
        .consume_bin0_amount(consume_bin0_amount),
        .consume_bin1_amount(consume_bin1_amount),
        .consume_creamer_amount(consume_creamer_amount),
        .consume_chocolate_amount(consume_chocolate_amount),
        .consume_paper_filter(consume_paper_filter),
        
        // Ingredient availability
        .coffee_bin0_level(coffee_bin0_level),
        .coffee_bin1_level(coffee_bin1_level),
        .creamer_level(creamer_level),
        .chocolate_level(chocolate_level),
        .paper_filter_present(paper_filter_present),
        
        // Actuator outputs
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
    // Consumable Manager
    //------------------------------------------------------------------------
    consumable_manager consumable_manager_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Sensor interface inputs
        .sensor_bin0_level(sensor_bin0_level),
        .sensor_bin1_level(sensor_bin1_level),
        .sensor_creamer_level(sensor_creamer_level),
        .sensor_chocolate_level(sensor_chocolate_level),
        .paper_filter_present(paper_filter_present),
        
        // Recipe engine consumption
        .consume_enable(consume_enable),
        .consume_bin0_amount(consume_bin0_amount),
        .consume_bin1_amount(consume_bin1_amount),
        .consume_creamer_amount(consume_creamer_amount),
        .consume_chocolate_amount(consume_chocolate_amount),
        .consume_paper_filter(consume_paper_filter),
        
        // Managed levels
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
    // Water Temperature Controller
    //------------------------------------------------------------------------
    water_temp_controller water_temp_controller_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Sensor interface
        .water_pressure_ok(sensor_water_pressure_ok),
        .water_temp_override(SW10),
        .pressure_override(SW9),
        
        // Control interface
        .heating_enable(water_heating_enable),
        .brewing_active(recipe_brewing_active),
        .target_temp_mode(water_target_temp_mode),
        
        // Actuator output
        .heater_enable(heater_enable),
        
        // Status outputs
        .temp_ready(temp_ready),
        .pressure_ready(pressure_ready),
        .water_system_ok(water_system_ok),
        .current_temp(current_temp),
        .target_temp(target_temp)
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
        
        // System status
        .system_fault_flag(system_fault),
        .actuator_timeout(1'b0),  // TODO: Connect from actuator_control
        .recipe_valid(recipe_valid),
        .can_make_coffee(can_make_coffee),
        
        // Error outputs
        .critical_error(critical_error),
        .error_present(error_present),
        .warning_count(warning_count),
        .error_count(error_count),
        
        // Specific errors
        .err_no_water(err_no_water),
        .err_no_paper(err_no_paper),
        .err_no_coffee(err_no_coffee),
        .err_temp_fault(err_temp_fault),
        .err_pressure_fault(err_pressure_fault),
        .err_system_fault(err_system_fault),
        
        // Specific warnings
        .warn_paper_low(warn_paper_low),
        .warn_bin0_low(warn_bin0_low),
        .warn_bin1_low(warn_bin1_low),
        .warn_creamer_low(warn_creamer_low),
        .warn_chocolate_low(warn_chocolate_low),
        .warn_temp_heating(warn_temp_heating)
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
        
        // System status
        .brew_progress(brew_progress),
        .warning_count(warning_count),
        .error_present(error_present),
        
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
        .line1_text(line1_text),
        .line2_text(line2_text),
        .message_updated(message_updated)
    );
    
    //------------------------------------------------------------------------
    // LCD Controller
    //------------------------------------------------------------------------
    lcd_controller lcd_controller_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // String interface
        .line1_data(line1_text),
        .line2_data(line2_text),
        .update_display(message_updated | display_refresh),
        
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
    assign LEDR9 = led_water_pour;
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
    assign LEDG0 = recipe_brewing_active;
    assign LEDG1 = temp_ready;
    assign LEDG2 = pressure_ready;
    assign LEDG3 = recipe_valid;
    assign LEDG4 = can_make_coffee;
    assign LEDG5 = (warning_count > 0);
    assign LEDG6 = error_present;
    assign LEDG7 = recipe_brewing_complete;
    
    //========================================================================
    // 7-Segment Display Drivers
    //========================================================================
    
    // Brew progress (HEX2, HEX1, HEX0) - shows 0-100%
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
    
    // Current temperature (HEX5, HEX4, HEX3) - shows 0-255
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
    
    // Error and warning counts (HEX7, HEX6)
    seven_seg_decoder hex6_decoder (
        .digit(error_count),
        .segments(HEX6)
    );
    
    seven_seg_decoder hex7_decoder (
        .digit(warning_count),
        .segments(HEX7)
    );

endmodule