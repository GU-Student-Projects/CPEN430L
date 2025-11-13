//============================================================================
// Module: coffee_machine_core_tb
// Description: Integration test for complete coffee machine system
//              Tests all modules working together (excluding display interfaces)
// Author: Gabriel DiMartino
// Date: November 2025
//============================================================================

`timescale 1ns/1ps

module coffee_machine_core_tb;
    parameter CLK_PERIOD = 20;
    parameter SIM_TIME = 64'd300_000_000;  // 300ms should be plenty
    
    //========================================================================
    // Common signals
    //========================================================================
    logic clk, rst_n;
    
    //========================================================================
    // User Interface (simulated buttons)
    //========================================================================
    logic btn_left, btn_right, btn_select, btn_back;
    
    //========================================================================
    // Sensor Inputs (simulated hardware)
    //========================================================================
    logic sw_paper_filter;
    logic [7:0] sw_bin0_fill, sw_bin1_fill;
    logic [7:0] sw_creamer_fill, sw_chocolate_fill;
    
    //========================================================================
    // System Status Outputs
    //========================================================================
    logic system_ready, system_active, system_fault;
    logic brewing_complete, brewing_active;
    logic [7:0] brew_progress;
    
    //========================================================================
    // Actuator Outputs (LED indicators in hardware)
    //========================================================================
    logic led_heater, led_water_pour, led_water_direct;
    logic led_grinder0, led_grinder1, led_paper_motor;
    
    //========================================================================
    // Error/Warning Indicators
    //========================================================================
    logic critical_error, error_present;
    logic [3:0] warning_count, error_count;
    
    //========================================================================
    // Internal signals between modules
    //========================================================================
    
    // Menu Navigator -> Main FSM
    logic [3:0] menu_state;
    logic start_brewing_cmd;
    logic [2:0] selected_coffee_type;
    logic [2:0] selected_drink_type;
    logic [1:0] selected_size;
    
    // Main FSM -> Recipe Engine
    logic recipe_start_brewing, recipe_abort_brewing;
    logic recipe_brewing_active, recipe_brewing_complete, recipe_valid;
    
    // Main FSM -> Water Controller
    logic water_heating_enable;
    logic [1:0] water_target_temp_mode;
    logic water_temp_ready, water_pressure_ready, water_system_ok;
    
    // Recipe Engine -> Consumable Manager
    logic consume_enable;
    logic [7:0] consume_bin0_amount, consume_bin1_amount;
    logic [7:0] consume_creamer_amount, consume_chocolate_amount;
    logic consume_paper_filter;
    
    // Consumable Manager outputs
    logic [7:0] coffee_bin0_level, coffee_bin1_level;
    logic [7:0] creamer_level, chocolate_level;
    logic [7:0] paper_filter_count;
    logic can_make_coffee;
    logic bin0_empty, bin0_low, bin1_empty, bin1_low;
    logic creamer_empty, creamer_low, chocolate_empty, chocolate_low;
    logic paper_empty, paper_low;
    
    // Derive paper_filter_present from paper_empty
    assign paper_filter_present = !paper_empty;
    
    // Recipe Engine -> Actuator Control
    logic grinder0_cmd, grinder1_cmd;
    logic water_pour_cmd, water_direct_cmd;
    logic paper_motor_cmd;
    
    // Water Controller -> Actuator Control
    logic heater_cmd;
    
    // Actuator Control outputs
    logic actuators_active;
    logic [5:0] active_actuator_count;
    
    // Error Handler outputs
    logic err_no_water, err_no_paper, err_no_coffee;
    logic err_temp_fault, err_pressure_fault, err_system_fault;
    logic warn_paper_low, warn_bin0_low, warn_bin1_low;
    logic warn_creamer_low, warn_chocolate_low, warn_temp_heating;
    
    // Main FSM outputs
    logic emergency_stop;

    // Connect recipe brewing status to top-level signals
    assign brewing_active = recipe_brewing_active;
    assign brewing_complete = recipe_brewing_complete;
    
    //========================================================================
    // Module Instantiations (with FAST timing for testing)
    //========================================================================
    
    // Menu Navigator (with FAST debounce)
    menu_navigator #(
        .DEBOUNCE_TIME(1),           // 1ms instead of 20ms
        .DEBOUNCE_CYCLES(50_000)     // 50k cycles @ 50MHz = 1ms
    ) menu_nav (
        .clk(clk),
        .rst_n(rst_n),
        .btn_cancel(btn_back),           // FIX: btn_back -> btn_cancel
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_select(btn_select),
        .system_ready(system_ready),
        .brewing_active(brewing_active),
        .error_present(critical_error),  // FIX: critical_error -> error_present
        .warning_count(warning_count),
        .recipe_valid(recipe_valid),     // FIX: Added recipe_valid
        .can_make_coffee(can_make_coffee),
        .current_menu_state(menu_state), // FIX: menu_state -> current_menu_state
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        .start_brewing_cmd(start_brewing_cmd), // FIX: start_brewing -> start_brewing_cmd
        .enter_settings_mode(),
        .display_refresh()
    );
    
    // Main FSM (system orchestrator with FAST timing, debug OFF)
    main_fsm #(
        .INIT_DELAY(32'd100_000),         // 2ms instead of 1s
        .COOLDOWN_TIME(32'd50_000),       // 1ms instead of 2s
        .ERROR_RETRY_TIME(32'd250_000)    // 5ms instead of 5s
    ) fsm (
        .clk(clk),
        .rst_n(rst_n),
        .menu_state(menu_state),
        .start_brewing_cmd(start_brewing_cmd),
        .enter_settings_mode(1'b0),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        .recipe_start_brewing(recipe_start_brewing),
        .recipe_abort_brewing(recipe_abort_brewing),
        .recipe_brewing_active(recipe_brewing_active),
        .recipe_brewing_complete(recipe_brewing_complete),
        .recipe_valid(recipe_valid),
        .water_heating_enable(water_heating_enable),
        .water_target_temp_mode(water_target_temp_mode),
        .water_temp_ready(water_temp_ready),
        .water_pressure_ready(water_pressure_ready),
        .water_system_ok(water_system_ok),
        .can_make_coffee(can_make_coffee),
        .paper_filter_present(paper_filter_present),
        .critical_error(critical_error),
        .warning_count(warning_count),
        .system_fault(system_fault),
        .system_ready(system_ready),
        .system_active(system_active),
        .emergency_stop(emergency_stop)
    );
    
    // Disable FSM debug output by adding +define+SYNTHESIS to compilation
    
    // Recipe Engine (with FAST timing for testing)
    recipe_engine #(
        .TIME_GRIND(32'd1_000_000),
        .TIME_POUR(32'd1_500_000),
        .TIME_PAPER_FEED(32'd250_000),
        .TIME_SETTLE(32'd250_000)
    ) recipe (
        .clk(clk),
        .rst_n(rst_n),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        .start_brewing(recipe_start_brewing),
        .abort_brewing(recipe_abort_brewing),
        .consume_enable(consume_enable),
        .consume_bin0_amount(consume_bin0_amount),
        .consume_bin1_amount(consume_bin1_amount),
        .consume_creamer_amount(consume_creamer_amount),
        .consume_chocolate_amount(consume_chocolate_amount),
        .consume_paper_filter(consume_paper_filter),
        .coffee_bin0_level(coffee_bin0_level),
        .coffee_bin1_level(coffee_bin1_level),
        .creamer_level(creamer_level),
        .chocolate_level(chocolate_level),
        .paper_filter_present(paper_filter_present),
        .grinder0_enable(grinder0_cmd),
        .grinder1_enable(grinder1_cmd),
        .water_pour_enable(water_pour_cmd),
        .water_direct_enable(water_direct_cmd),
        .paper_motor_enable(paper_motor_cmd),
        .brewing_active(recipe_brewing_active),
        .brewing_complete(recipe_brewing_complete),
        .brew_progress(brew_progress),
        .recipe_valid(recipe_valid)
    );
    
    // Consumable Manager
    consumable_manager consumables (
        .clk(clk),
        .rst_n(rst_n),
        .consume_enable(consume_enable),
        .consume_bin0_amount(consume_bin0_amount),
        .consume_bin1_amount(consume_bin1_amount),
        .consume_creamer_amount(consume_creamer_amount),
        .consume_chocolate_amount(consume_chocolate_amount),
        .consume_paper_filter(consume_paper_filter),
        .sensor_bin0_level(sw_bin0_fill),
        .sensor_bin1_level(sw_bin1_fill),
        .sensor_creamer_level(sw_creamer_fill),
        .sensor_chocolate_level(sw_chocolate_fill),
        .paper_filter_present(sw_paper_filter),  // Input
        .coffee_bin0_level(coffee_bin0_level),
        .coffee_bin1_level(coffee_bin1_level),
        .creamer_level(creamer_level),
        .chocolate_level(chocolate_level),
        .paper_filter_count(paper_filter_count),
        // NOTE: paper_filter_present is also an OUTPUT from consumables
        // But looking at the module, it only has it as INPUT, not OUTPUT
        // The module checks paper_filter_present input to manage paper_filter_count
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
        .can_make_coffee(can_make_coffee),
        .can_add_creamer(),
        .can_add_chocolate()
    );
    
    // Water Temperature Controller (FAST for testing)
    water_temp_controller #(
        .HEATING_CYCLE_TIME(100),         // Update every 2us instead of 1ms
        .PRESSURE_CHECK_TIME(50_000),     // Check every 1ms instead of 50ms
        .TEMP_COLD(8'd25),
        .TEMP_STANDBY(8'd80),             // Lower targets for faster testing
        .TEMP_BREWING(8'd100),
        .TEMP_EXTRA_HOT(8'd120),
        .HEAT_RATE(8'd5),                 // Heat 5x faster
        .COOL_RATE(8'd2)                  // Cool 2x faster
    ) water_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .heating_enable(water_heating_enable),
        .brewing_active(brewing_active),
        .target_temp_mode(water_target_temp_mode),
        .water_temp_override(1'b0),      // FIX: temp_override -> water_temp_override
        .water_pressure_ok(1'b1),        // FIX: Added water_pressure_ok input
        .pressure_override(1'b0),
        .heater_enable(heater_cmd),
        .current_temp(),
        .target_temp(),
        .temp_ready(water_temp_ready),
        .pressure_ready(water_pressure_ready),
        .water_system_ok(water_system_ok)
    );
    
    // Actuator Control
    actuator_control actuators (
        .clk(clk),
        .rst_n(rst_n),
        .grinder0_cmd(grinder0_cmd),
        .grinder1_cmd(grinder1_cmd),
        .water_pour_cmd(water_pour_cmd),
        .water_direct_cmd(water_direct_cmd),
        .paper_motor_cmd(paper_motor_cmd),
        .heater_cmd(heater_cmd),
        .temp_ready(water_temp_ready),
        .pressure_ready(water_pressure_ready),
        .water_system_ok(water_system_ok),
        .system_fault(system_fault),
        .paper_filter_present(paper_filter_present),
        .brewing_active(brewing_active),
        .emergency_stop(emergency_stop),
        .led_heater(led_heater),
        .led_water_pour(led_water_pour),
        .led_water_direct(led_water_direct),
        .led_grinder0(led_grinder0),
        .led_grinder1(led_grinder1),
        .led_paper_motor(led_paper_motor),
        .actuators_active(actuators_active),
        .active_count(active_actuator_count)
    );
    
    // Error Handler
    error_handler errors (
        .clk(clk),
        .rst_n(rst_n),
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
        .temp_ready(water_temp_ready),
        .pressure_ready(water_pressure_ready),
        .water_system_ok(water_system_ok),
        .system_fault_flag(system_fault),
        .actuator_timeout(1'b0),
        .recipe_valid(recipe_valid),
        .can_make_coffee(can_make_coffee),
        .critical_error(critical_error),
        .error_present(error_present),
        .warning_count(warning_count),
        .error_count(error_count),
        .err_no_water(err_no_water),
        .err_no_paper(err_no_paper),
        .err_no_coffee(err_no_coffee),
        .err_temp_fault(err_temp_fault),
        .err_pressure_fault(err_pressure_fault),
        .err_system_fault(err_system_fault),
        .warn_paper_low(warn_paper_low),
        .warn_bin0_low(warn_bin0_low),
        .warn_bin1_low(warn_bin1_low),
        .warn_creamer_low(warn_creamer_low),
        .warn_chocolate_low(warn_chocolate_low),
        .warn_temp_heating(warn_temp_heating)
    );
    
    //========================================================================
    // Clock Generation
    //========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    //========================================================================
    // Timeout
    //========================================================================
    initial begin
        #SIM_TIME;
        $display("\n========================================");
        $display("Integration Test TIMEOUT");
        $display("========================================");
        $finish;
    end
    
    //========================================================================
    // Button Press Task (handles debounce timing)
    //========================================================================
    task press_button(input int button_num);
        begin
            case (button_num)
                0: begin 
                    btn_left = 1; 
                    repeat(60_000) @(posedge clk);  // Hold for 1.2ms
                    btn_left = 0;
                    repeat(100_000) @(posedge clk); // Wait 2ms for debounce to clear
                end
                1: begin 
                    btn_right = 1; 
                    repeat(60_000) @(posedge clk);
                    btn_right = 0;
                    repeat(100_000) @(posedge clk);
                end
                2: begin 
                    btn_select = 1; 
                    repeat(60_000) @(posedge clk);
                    btn_select = 0;
                    repeat(100_000) @(posedge clk);
                end
                3: begin 
                    btn_back = 1; 
                    repeat(60_000) @(posedge clk);
                    btn_back = 0;
                    repeat(100_000) @(posedge clk);
                end
            endcase
        end
    endtask
    
    //========================================================================
    // Main Test Sequence
    //========================================================================
    initial begin
        $display("========================================");
        $display("Coffee Machine Integration Test");
        $display("========================================");
        $display("Testing complete system integration");
        $display("(All modules except display interfaces)");
        $display("========================================\n");
        
        // Initialize all inputs
        rst_n = 0;
        btn_left = 0;
        btn_right = 0;
        btn_select = 0;
        btn_back = 0;
        
        // Initialize sensors (full levels)
        sw_paper_filter = 1;
        sw_bin0_fill = 8'd255;
        sw_bin1_fill = 8'd255;
        sw_creamer_fill = 8'd255;
        sw_chocolate_fill = 8'd255;
        
        // Reset sequence
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(20) @(posedge clk);
        
        $display("[%0t] System reset complete", $time);
        
        // Wait for FSM INIT to complete (INIT_DELAY = 100_000 cycles = 2ms)
        $display("[%0t] Waiting for FSM initialization...", $time);
        repeat(150_000) @(posedge clk);  // Wait 3ms
        $display("[%0t] System initialized\n", $time);
        
        //====================================================================
        // Test 1: System Initialization and Idle State
        //====================================================================
        $display("--- Test 1: System Initialization ---");
        
        // Wait a bit for everything to stabilize
        repeat(10_000) @(posedge clk);  // 200us
        
        if (!system_ready && !critical_error) begin
            $display("[%0t] PASS: System in idle/init state", $time);
        end else begin
            $display("[%0t] FAIL: Unexpected system state", $time);
        end
        
        //====================================================================
        // Test 2: User Navigation and Water Heating
        //====================================================================
        $display("\n--- Test 2: Navigation and Heating ---");
        
        // User presses SELECT to start
        $display("[%0t] User: Pressing SELECT to begin", $time);
        press_button(2);  // SELECT
        
        // Navigate to coffee selection
        repeat(10_000) @(posedge clk);  // 200us
        
        // Check water heating started
        repeat(5_000) @(posedge clk);  // 100us
        if (led_heater) begin
            $display("[%0t] PASS: Water heater activated", $time);
        end else begin
            $display("[%0t] FAIL: Heater not on", $time);
        end
        
        // Wait for water to be ready (should be ~10-20ms with fast timing)
        $display("[%0t] Waiting for water system ready...", $time);
        repeat(2_000_000) begin  // 40ms timeout
            @(posedge clk);
            if (water_system_ok && system_ready) break;
        end
        
        if (system_ready) begin
            $display("[%0t] PASS: System ready to brew", $time);
        end else begin
            $display("[%0t] FAIL: System not ready", $time);
        end
        
        //====================================================================
        // Test 3: Complete Brew Cycle - Black Coffee
        //====================================================================
        $display("\n--- Test 3: Complete Black Coffee Brew ---");
        
        // Select coffee type (default bin 0)
        $display("[%0t] User: Selecting coffee type", $time);
        $display("[%0t] Current menu state: %0d", $time, menu_state);
        press_button(2);  // SELECT coffee type
        repeat(50_000) @(posedge clk);  // Wait for menu transition
        $display("[%0t] After coffee select, menu state: %0d", $time, menu_state);
        
        // Select drink type (black coffee = 0)
        $display("[%0t] User: Selecting black coffee", $time);
        press_button(2);  // SELECT drink
        repeat(50_000) @(posedge clk);  // Wait for menu transition
        $display("[%0t] After drink select, menu state: %0d", $time, menu_state);
        
        // Select size (12oz = 1)
        $display("[%0t] User: Selecting 12oz", $time);
        press_button(2);  // SELECT size
        repeat(50_000) @(posedge clk);  // Wait for menu transition
        $display("[%0t] After size select, menu state: %0d", $time, menu_state);
        
        // Confirm and start brewing
        $display("[%0t] User: Entering confirm screen", $time);
        $display("[%0t] Before confirm, menu state: %0d, recipe_valid: %b", $time, menu_state, recipe_valid);
        press_button(2);  // SELECT to enter confirm state
        
        // Wait for menu transition
        repeat(100_000) @(posedge clk);  // Wait 2ms for FSM
        $display("[%0t] After entering confirm, menu state: %0d", $time, menu_state);
        
        // Now actually START the brew
        $display("[%0t] User: Pressing START to begin brewing", $time);
        press_button(2);  // SELECT again to START brewing
        
        // Wait for FSM to process start command
        repeat(100_000) @(posedge clk);  // Wait 2ms for FSM
        $display("[%0t] After start command, menu state: %0d", $time, menu_state);
        
        // Monitor brewing
        $display("[%0t] Monitoring brew cycle...", $time);
        $display("[%0t] Menu state: %0d, start_brewing_cmd: %b", $time, menu_state, start_brewing_cmd);
        $display("[%0t] recipe_start_brewing: %b, brewing_active: %b", $time, recipe_start_brewing, brewing_active);
        
        // Wait for brewing to become active
        repeat(100_000) begin  // 2ms timeout
            @(posedge clk);
            if (brewing_active) break;
        end
        
        if (brewing_active) begin
            $display("[%0t] PASS: Brewing started", $time);
        end else begin
            $display("[%0t] FAIL: Brewing not started", $time);
        end
        
        // Monitor actuators during brew
        begin
            automatic int saw_paper;
            automatic int saw_grinder;
            automatic int saw_water;
            
            saw_paper = 0;
            saw_grinder = 0;
            saw_water = 0;
            
            // Monitor for completion (with timeout) - recipe takes ~75ms with fast timing
            repeat(5_000_000) begin  // 100ms timeout
                @(posedge clk);
                
                if (led_paper_motor) saw_paper = 1;
                if (led_grinder0 || led_grinder1) saw_grinder = 1;
                if (led_water_pour) saw_water = 1;
                
                if (brewing_complete) break;
            end
            
            if (brewing_complete) begin
                $display("[%0t] PASS: Brew completed successfully", $time);
            end else begin
                $display("[%0t] FAIL: Brew did not complete", $time);
            end
            
            if (saw_paper && saw_grinder && saw_water) begin
                $display("[%0t] PASS: All actuators activated correctly", $time);
            end else begin
                $display("[%0t] FAIL: Missing actuators (P:%0d G:%0d W:%0d)", 
                         $time, saw_paper, saw_grinder, saw_water);
            end
        end
        
        // Check consumables were consumed
        if (coffee_bin0_level < 8'd255) begin
            $display("[%0t] PASS: Coffee consumed (%0d units used)", 
                     $time, 8'd255 - coffee_bin0_level);
        end else begin
            $display("[%0t] FAIL: Coffee not consumed", $time);
        end
        
        repeat(100) @(posedge clk);
        
        //====================================================================
        // Test 4: Low Consumable Warning
        //====================================================================
        $display("\n--- Test 4: Low Consumable Warnings ---");
        
        // Set coffee to low level
        sw_bin0_fill = 8'd40;  // Below LOW_THRESHOLD
        repeat(10_000) @(posedge clk);  // 200us
        
        if (warn_bin0_low) begin
            $display("[%0t] PASS: Low coffee warning triggered", $time);
        end else begin
            $display("[%0t] FAIL: No low coffee warning", $time);
        end
        
        if (warning_count > 0) begin
            $display("[%0t] PASS: Warning count = %0d", $time, warning_count);
        end
        
        // Restore level
        sw_bin0_fill = 8'd255;
        repeat(100) @(posedge clk);
        
        //====================================================================
        // Test 5: Empty Consumable Error
        //====================================================================
        $display("\n--- Test 5: Empty Consumable Error ---");
        
        // Empty the paper
        sw_paper_filter = 0;
        repeat(10_000) @(posedge clk);  // 200us
        
        $display("[%0t] Paper filter removed, checking error state...", $time);
        
        // Check if error is detected
        repeat(50_000) @(posedge clk);  // Wait 1ms for error detection
        
        if (critical_error || err_no_paper || paper_empty) begin
            $display("[%0t] PASS: Paper empty error detected", $time);
        end else begin
            $display("[%0t] FAIL: No paper error (critical:%b, err_no_paper:%b, paper_empty:%b)", 
                     $time, critical_error, err_no_paper, paper_empty);
        end
        
        // Verify brewing is blocked (don't actually try to brew, just check flag)
        if (!can_make_coffee || !recipe_valid || paper_empty) begin
            $display("[%0t] PASS: Brewing blocked by error", $time);
        end else begin
            $display("[%0t] FAIL: Brewing not blocked", $time);
        end
        
        // Restore paper
        sw_paper_filter = 1;
        repeat(50_000) @(posedge clk);  // Wait for recovery
        
        //====================================================================
        // Test 6: Mocha with Multiple Ingredients
        //====================================================================
        $display("\n--- Test 6: Mocha (Multi-Ingredient) ---");
        
        // Navigate from wherever we are back to ready state
        $display("[%0t] Navigating to coffee selection...", $time);
        press_button(2);  // SELECT to wake up / start
        repeat(100_000) @(posedge clk);  // Wait for system ready
        
        // Now navigate: Coffee -> Drink (Mocha=3) -> Size -> Confirm -> Start
        $display("[%0t] Selecting coffee bin 0", $time);
        press_button(2);  // SELECT coffee type (bin 0)
        repeat(50_000) @(posedge clk);
        
        $display("[%0t] Navigating to Mocha (drink type 3)", $time);
        press_button(1);  // RIGHT to drink 1
        repeat(50_000) @(posedge clk);
        press_button(1);  // RIGHT to drink 2
        repeat(50_000) @(posedge clk);
        press_button(1);  // RIGHT to drink 3 (Mocha)
        repeat(50_000) @(posedge clk);
        press_button(2);  // SELECT Mocha
        repeat(50_000) @(posedge clk);
        
        $display("[%0t] Selecting size", $time);
        press_button(2);  // SELECT size (12oz)
        repeat(50_000) @(posedge clk);
        
        $display("[%0t] Confirming selection", $time);
        press_button(2);  // Enter CONFIRM state
        repeat(50_000) @(posedge clk);
        
        $display("[%0t] Starting Mocha brew", $time);
        press_button(2);  // START brewing
        repeat(100_000) @(posedge clk);  // Wait for brew to start
        
        // Wait for brew to complete (Mocha takes ~35ms with fast timing)
        $display("[%0t] Waiting for Mocha to complete...", $time);
        repeat(3_000_000) begin  // 60ms timeout
            @(posedge clk);
            if (brewing_complete) break;
        end
        
        if (brewing_complete) begin
            $display("[%0t] Mocha brew completed", $time);
        end else begin
            $display("[%0t] WARNING: Mocha brew timed out", $time);
        end
        
        repeat(50_000) @(posedge clk);  // Let everything settle
        
        // Check multiple ingredients consumed
        if (coffee_bin0_level < 8'd255 && 
            creamer_level < 8'd255 && 
            chocolate_level < 8'd255) begin
            $display("[%0t] PASS: Mocha ingredients consumed", $time);
            $display("         Coffee: %0d, Creamer: %0d, Chocolate: %0d",
                     8'd255 - coffee_bin0_level,
                     8'd255 - creamer_level,
                     8'd255 - chocolate_level);
        end else begin
            $display("[%0t] FAIL: Not all ingredients consumed", $time);
            $display("         Coffee: %0d/%0d, Creamer: %0d/%0d, Chocolate: %0d/%0d",
                     coffee_bin0_level, 8'd255,
                     creamer_level, 8'd255,
                     chocolate_level, 8'd255);
        end
        
        //====================================================================
        // Summary
        //====================================================================
        $display("\n========================================");
        $display("Integration Test Complete!");
        $display("========================================");
        $display("Final System State:");
        $display("  System Ready:     %0d", system_ready);
        $display("  Critical Errors:  %0d", critical_error);
        $display("  Warnings:         %0d", warning_count);
        $display("  Coffee Bin 0:     %0d", coffee_bin0_level);
        $display("  Creamer:          %0d", creamer_level);
        $display("  Chocolate:        %0d", chocolate_level);
        $display("  Paper Filters:    %0d", paper_filter_count);
        $display("========================================");
        
        #100_000;
        $finish;
    end
    
    // VCD dump
    initial begin
        $dumpfile("coffee_machine_integration_tb.vcd");
        $dumpvars(0, coffee_machine_core_tb);
    end
    
endmodule