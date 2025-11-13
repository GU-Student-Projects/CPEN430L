//============================================================================
// Module: coffee_machine_core_tb_fast
// Description: FAST integration test - essential tests only
// Author: Gabriel DiMartino
// Runtime: ~5 seconds
//============================================================================

`timescale 1ns/1ps

module coffee_machine_core_tb_fast;
    parameter CLK_PERIOD = 20;
    parameter SIM_TIME = 64'd200_000_000;  // 200ms total
    
    logic clk, rst_n;
    logic btn_select, btn_cancel, btn_left, btn_right;
    logic [3:0] menu_state;
    logic system_ready, brewing_active, brewing_complete;
    logic [7:0] coffee_bin0_level, coffee_bin1_level;
    
    // Simplified connections - just what we need
    logic [2:0] selected_coffee_type, selected_drink_type;
    logic [1:0] selected_size;
    logic start_brewing_cmd;
    logic water_heating_enable, water_system_ok;
    logic recipe_start_brewing, recipe_brewing_active, recipe_brewing_complete;
    logic can_make_coffee, recipe_valid, critical_error;
    logic led_heater, led_grinder0, led_water_pour;
    
    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Timeout
    initial begin
        #SIM_TIME;
        $display("\n========================================");
        $display("FAST Integration Test Complete!");
        $display("========================================");
        $finish;
    end
    
    // Connect signals
    assign brewing_active = recipe_brewing_active;
    assign brewing_complete = recipe_brewing_complete;
    
    //========================================================================
    // Minimal Module Set
    //========================================================================
    
    menu_navigator #(
        .DEBOUNCE_TIME(1),
        .DEBOUNCE_CYCLES(50_000)
    ) menu (
        .clk(clk), .rst_n(rst_n),
        .btn_cancel(btn_cancel), .btn_left(btn_left),
        .btn_right(btn_right), .btn_select(btn_select),
        .system_ready(system_ready), .brewing_active(brewing_active),
        .error_present(critical_error), .warning_count(4'd0),
        .recipe_valid(recipe_valid), .can_make_coffee(can_make_coffee),
        .current_menu_state(menu_state),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        .start_brewing_cmd(start_brewing_cmd),
        .enter_settings_mode(), .display_refresh()
    );
    
    main_fsm #(
        .INIT_DELAY(32'd50_000),      // 1ms
        .COOLDOWN_TIME(32'd25_000),
        .ERROR_RETRY_TIME(32'd100_000)
    ) fsm (
        .clk(clk), .rst_n(rst_n),
        .menu_state(menu_state),
        .start_brewing_cmd(start_brewing_cmd),
        .enter_settings_mode(1'b0),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        .recipe_start_brewing(recipe_start_brewing),
        .recipe_abort_brewing(),
        .recipe_brewing_active(recipe_brewing_active),
        .recipe_brewing_complete(recipe_brewing_complete),
        .recipe_valid(recipe_valid),
        .water_heating_enable(water_heating_enable),
        .water_target_temp_mode(),
        .water_temp_ready(water_system_ok),
        .water_pressure_ready(1'b1),
        .water_system_ok(water_system_ok),
        .can_make_coffee(can_make_coffee),
        .paper_filter_present(1'b1),
        .critical_error(critical_error),
        .warning_count(4'd0),
        .system_fault(),
        .system_ready(system_ready),
        .system_active(),
        .emergency_stop()
    );
    
    recipe_engine #(
        .TIME_GRIND(32'd500_000),      // 10ms
        .TIME_POUR(32'd750_000),       // 15ms
        .TIME_PAPER_FEED(32'd125_000), // 2.5ms
        .TIME_SETTLE(32'd125_000)      // 2.5ms
    ) recipe (
        .clk(clk), .rst_n(rst_n),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        .start_brewing(recipe_start_brewing),
        .abort_brewing(1'b0),
        .consume_enable(),
        .consume_bin0_amount(),
        .consume_bin1_amount(),
        .consume_creamer_amount(),
        .consume_chocolate_amount(),
        .consume_paper_filter(),
        .coffee_bin0_level(8'd255),
        .coffee_bin1_level(8'd255),
        .creamer_level(8'd255),
        .chocolate_level(8'd255),
        .paper_filter_present(1'b1),
        .grinder0_enable(led_grinder0),
        .grinder1_enable(),
        .water_pour_enable(led_water_pour),
        .water_direct_enable(),
        .paper_motor_enable(),
        .brewing_active(recipe_brewing_active),
        .brewing_complete(recipe_brewing_complete),
        .brew_progress(),
        .recipe_valid(recipe_valid)
    );
    
    // Simplified water controller - just goes ready immediately
    assign water_system_ok = water_heating_enable;
    assign led_heater = water_heating_enable;
    assign can_make_coffee = 1'b1;
    assign critical_error = 1'b0;
    
    //========================================================================
    // Button Press Helper
    //========================================================================
    task press_select();
        begin
            btn_select = 1;
            repeat(60_000) @(posedge clk);  // Hold for 1.2ms
            btn_select = 0;
            repeat(100_000) @(posedge clk); // Wait 2ms for debounce to clear
        end
    endtask
    
    //========================================================================
    // Test Sequence
    //========================================================================
    initial begin
        $display("========================================");
        $display("FAST Integration Test");
        $display("========================================\n");
        
        rst_n = 0;
        btn_select = 0; btn_cancel = 0; btn_left = 0; btn_right = 0;
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        
        // Wait for init
        repeat(100_000) @(posedge clk);
        
        $display("[%0t] Test 1: Press button and navigate", $time);
        press_select();
        
        if (menu_state != 0) begin
            $display("[%0t] PASS: Menu transitioned (state=%0d)", $time, menu_state);
        end
        
        $display("\n[%0t] Test 2: Wait for system ready", $time);
        repeat(50_000) @(posedge clk);
        
        if (system_ready) begin
            $display("[%0t] PASS: System ready", $time);
        end else begin
            $display("[%0t] FAIL: System not ready", $time);
        end
        
        $display("\n[%0t] Test 3: Navigate to brew", $time);
        press_select();  // Select coffee
        $display("[%0t] After coffee, menu state: %0d", $time, menu_state);
        repeat(50_000) @(posedge clk);  // Wait 1ms between presses
        
        press_select();  // Select drink
        $display("[%0t] After drink, menu state: %0d", $time, menu_state);
        repeat(50_000) @(posedge clk);
        
        press_select();  // Select size
        $display("[%0t] After size, menu state: %0d", $time, menu_state);
        repeat(50_000) @(posedge clk);
        
        press_select();  // Confirm
        $display("[%0t] After confirm, menu state: %0d", $time, menu_state);
        repeat(50_000) @(posedge clk);
        
        press_select();  // START
        $display("[%0t] After START, menu state: %0d", $time, menu_state);
        repeat(50_000) @(posedge clk);
        
        $display("[%0t] Final menu state: %0d", $time, menu_state);
        
        // Wait for brew with timeout
        repeat(5_000_000) begin
            @(posedge clk);
            if (brewing_complete) break;
        end
        
        if (brewing_complete) begin
            $display("[%0t] PASS: Brew completed!", $time);
        end else if (brewing_active) begin
            $display("[%0t] PARTIAL: Brewing started but not complete", $time);
        end else begin
            $display("[%0t] FAIL: Brew never started", $time);
        end
        
        $display("\n========================================");
        $display("Test Summary:");
        $display("  System Ready: %b", system_ready);
        $display("  Brew Complete: %b", brewing_complete);
        $display("========================================");
        
        #10_000;
        $finish;
    end
    
endmodule