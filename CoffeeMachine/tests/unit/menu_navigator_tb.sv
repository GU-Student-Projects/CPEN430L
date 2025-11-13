//============================================================================
// Module: menu_navigator_tb
// Description: Unit test for menu_navigator module
//              Tests button navigation, state transitions, and selection logic
// Author: Gabriel DiMartino
// Date: November 2025
//============================================================================

`timescale 1ns/1ps

module menu_navigator_tb;

    //========================================================================
    // Testbench Parameters
    //========================================================================
    parameter CLK_PERIOD = 20;  // 50 MHz clock
    parameter SIM_TIME = 500_000_000;  // 500ms simulation
    
    //========================================================================
    // DUT Signals
    //========================================================================
    logic clk;
    logic rst_n;
    
    // Button inputs
    logic btn_cancel;
    logic btn_left;
    logic btn_right;
    logic btn_select;
    
    // System status
    logic       system_ready;
    logic       brewing_active;
    logic       error_present;
    logic [3:0] warning_count;
    logic       recipe_valid;
    logic       can_make_coffee;
    
    // Outputs
    logic [3:0] current_menu_state;
    logic [2:0] selected_coffee_type;
    logic [2:0] selected_drink_type;
    logic [1:0] selected_size;
    logic       start_brewing_cmd;
    logic       enter_settings_mode;
    logic       display_refresh;
    
    //========================================================================
    // DUT Instantiation
    //========================================================================
    menu_navigator dut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_cancel(btn_cancel),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_select(btn_select),
        .system_ready(system_ready),
        .brewing_active(brewing_active),
        .error_present(error_present),
        .warning_count(warning_count),
        .recipe_valid(recipe_valid),
        .can_make_coffee(can_make_coffee),
        .current_menu_state(current_menu_state),
        .selected_coffee_type(selected_coffee_type),
        .selected_drink_type(selected_drink_type),
        .selected_size(selected_size),
        .start_brewing_cmd(start_brewing_cmd),
        .enter_settings_mode(enter_settings_mode),
        .display_refresh(display_refresh)
    );
    
    //========================================================================
    // Clock Generation
    //========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //========================================================================
    // Timeout Watchdog
    //========================================================================
    initial begin
        #SIM_TIME;
        $display("========================================");
        $display("Menu Navigator Test Complete!");
        $display("========================================");
        $finish;
    end
    
    //========================================================================
    // Test Utilities
    //========================================================================
    
    task reset_dut();
        begin
            $display("[%0t] Applying reset...", $time);
            rst_n = 0;
            
            // Initialize inputs
            btn_cancel = 0;
            btn_left = 0;
            btn_right = 0;
            btn_select = 0;
            system_ready = 1;
            brewing_active = 0;
            error_present = 0;
            warning_count = 0;
            recipe_valid = 1;
            can_make_coffee = 1;
            
            repeat(10) @(posedge clk);
            rst_n = 1;
            repeat(5) @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask
    
    task press_button(input int button_num);
        begin
            // Wait for debounce to clear
            #25_000_000;
            
            case (button_num)
                0: btn_cancel = 1;
                1: btn_left = 1;
                2: btn_right = 1;
                3: btn_select = 1;
            endcase
            
            #25_000_000;  // Hold button (25ms)
            
            case (button_num)
                0: btn_cancel = 0;
                1: btn_left = 0;
                2: btn_right = 0;
                3: btn_select = 0;
            endcase
            
            #10_000_000;  // Wait for processing
        end
    endtask
    
    task check_state(input [3:0] expected);
        begin
            if (current_menu_state == expected) begin
                $display("[%0t] PASS: State = %0d", $time, current_menu_state);
            end else begin
                $display("[%0t] ERROR: State mismatch! Expected=%0d, Got=%0d", 
                         $time, expected, current_menu_state);
            end
        end
    endtask
    
    //========================================================================
    // Main Test Sequence
    //========================================================================
    initial begin
        $display("========================================");
        $display("Menu Navigator Unit Test");
        $display("========================================");
        
        reset_dut();
        
        //--------------------------------------------------------------------
        // Test 1: Initial State (SPLASH)
        //--------------------------------------------------------------------
        $display("\n--- Test 1: Initial State ---");
        check_state(4'd0);  // SPLASH
        
        //--------------------------------------------------------------------
        // Test 2: Navigate to Coffee Selection
        //--------------------------------------------------------------------
        $display("\n--- Test 2: Navigate to Coffee Select ---");
        press_button(3);  // SELECT
        check_state(4'd1);  // CHECK_ERRORS
        
        #10_000_000;
        check_state(4'd2);  // COFFEE_SELECT
        
        //--------------------------------------------------------------------
        // Test 3: Coffee Selection (Left/Right)
        //--------------------------------------------------------------------
        $display("\n--- Test 3: Coffee Selection ---");
        $display("[%0t] Initial coffee type: %0d", $time, selected_coffee_type);
        
        press_button(2);  // RIGHT
        $display("[%0t] After RIGHT: %0d", $time, selected_coffee_type);
        
        press_button(1);  // LEFT
        $display("[%0t] After LEFT: %0d", $time, selected_coffee_type);
        
        //--------------------------------------------------------------------
        // Test 4: Navigate to Drink Selection
        //--------------------------------------------------------------------
        $display("\n--- Test 4: Navigate to Drink Select ---");
        press_button(3);  // SELECT
        check_state(4'd3);  // DRINK_SELECT
        
        //--------------------------------------------------------------------
        // Test 5: Drink Selection (Wrap-around)
        //--------------------------------------------------------------------
        $display("\n--- Test 5: Drink Selection Wrap-around ---");
        $display("[%0t] Initial drink: %0d", $time, selected_drink_type);
        
        // Cycle through all drinks
        for (int i = 0; i < 6; i++) begin
            press_button(2);  // RIGHT
            $display("[%0t] Drink after press %0d: %0d", $time, i+1, selected_drink_type);
        end
        
        //--------------------------------------------------------------------
        // Test 6: Navigate to Size Selection
        //--------------------------------------------------------------------
        $display("\n--- Test 6: Navigate to Size Select ---");
        press_button(3);  // SELECT
        check_state(4'd4);  // SIZE_SELECT
        
        //--------------------------------------------------------------------
        // Test 7: Size Selection
        //--------------------------------------------------------------------
        $display("\n--- Test 7: Size Selection ---");
        $display("[%0t] Initial size: %0d", $time, selected_size);
        
        press_button(2);  // RIGHT
        $display("[%0t] After RIGHT: %0d", $time, selected_size);
        
        press_button(2);  // RIGHT
        $display("[%0t] After RIGHT: %0d", $time, selected_size);
        
        press_button(2);  // RIGHT (should wrap)
        $display("[%0t] After RIGHT (wrap): %0d", $time, selected_size);
        
        //--------------------------------------------------------------------
        // Test 8: Navigate to Confirm
        //--------------------------------------------------------------------
        $display("\n--- Test 8: Navigate to Confirm ---");
        press_button(3);  // SELECT
        check_state(4'd5);  // CONFIRM
        
        //--------------------------------------------------------------------
        // Test 9: Start Brewing
        //--------------------------------------------------------------------
        $display("\n--- Test 9: Start Brewing ---");
        press_button(3);  // SELECT (start)
        
        if (start_brewing_cmd) begin
            $display("[%0t] PASS: Start brewing command issued", $time);
        end
        
        check_state(4'd6);  // BREWING
        
        // Simulate brewing
        brewing_active = 1;
        #50_000_000;  // 50ms
        brewing_active = 0;
        
        #10_000_000;
        check_state(4'd7);  // COMPLETE
        
        //--------------------------------------------------------------------
        // Test 10: Return to Splash
        //--------------------------------------------------------------------
        $display("\n--- Test 10: Return to Splash ---");
        press_button(3);  // Any button
        check_state(4'd0);  // SPLASH
        
        //--------------------------------------------------------------------
        // Test 11: Back Navigation (Cancel)
        //--------------------------------------------------------------------
        $display("\n--- Test 11: Back Navigation ---");
        
        // Navigate forward
        press_button(3);  // SELECT - to CHECK_ERRORS
        #10_000_000;
        press_button(3);  // SELECT - to DRINK_SELECT (skips COFFEE_SELECT if already selected)
        
        // Navigate back
        press_button(0);  // CANCEL
        $display("[%0t] After CANCEL, state=%0d", $time, current_menu_state);
        
        //--------------------------------------------------------------------
        // Test 12: Settings Mode (Special Combo)
        //--------------------------------------------------------------------
        $display("\n--- Test 12: Settings Mode (3-button combo) ---");
        
        // Press all three buttons simultaneously
        btn_left = 1;
        btn_right = 1;
        btn_select = 1;
        
        #2_100_000_000;  // Hold for 2.1 seconds
        
        btn_left = 0;
        btn_right = 0;
        btn_select = 0;
        
        #50_000_000;
        
        if (enter_settings_mode) begin
            $display("[%0t] PASS: Settings mode command issued", $time);
        end
        
        //--------------------------------------------------------------------
        // Test 13: Error State Handling
        //--------------------------------------------------------------------
        $display("\n--- Test 13: Error State ---");
        
        error_present = 1;
        #10_000_000;
        
        press_button(3);  // Try to navigate
        #10_000_000;
        
        if (current_menu_state == 4'd9) begin  // ERROR state
            $display("[%0t] PASS: In error state", $time);
        end
        
        // Clear error
        error_present = 0;
        #10_000_000;
        
        //--------------------------------------------------------------------
        // Test 14: Display Refresh Signal
        //--------------------------------------------------------------------
        $display("\n--- Test 14: Display Refresh ---");
        
        begin
            automatic int refresh_count;
            refresh_count = 0;
            
            // Monitor refreshes during navigation
            fork
                begin
                    repeat(100000) begin
                        @(posedge clk);
                        if (display_refresh) refresh_count++;
                    end
                end
            join_none
            
            press_button(1);  // LEFT
            press_button(2);  // RIGHT
            press_button(3);  // SELECT
            
            #10_000_000;
            $display("[%0t] Display refreshes detected: %0d", $time, refresh_count);
        end
        
        //--------------------------------------------------------------------
        // Test Complete
        //--------------------------------------------------------------------
        $display("\n========================================");
        $display("Menu Navigator Unit Test Complete!");
        $display("========================================");
        
        #10_000;
        $finish;
    end
    
    //========================================================================
    // State Monitor
    //========================================================================
    always @(current_menu_state) begin
        case (current_menu_state)
            4'd0: $display("[%0t] State: SPLASH", $time);
            4'd1: $display("[%0t] State: CHECK_ERRORS", $time);
            4'd2: $display("[%0t] State: COFFEE_SELECT", $time);
            4'd3: $display("[%0t] State: DRINK_SELECT", $time);
            4'd4: $display("[%0t] State: SIZE_SELECT", $time);
            4'd5: $display("[%0t] State: CONFIRM", $time);
            4'd6: $display("[%0t] State: BREWING", $time);
            4'd7: $display("[%0t] State: COMPLETE", $time);
            4'd8: $display("[%0t] State: SETTINGS", $time);
            4'd9: $display("[%0t] State: ERROR", $time);
        endcase
    end
    
    //========================================================================
    // Waveform Dump
    //========================================================================
    initial begin
        $dumpfile("menu_navigator_tb.vcd");
        $dumpvars(0, menu_navigator_tb);
    end

endmodule