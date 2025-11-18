//============================================================================
// Testbench: coffee_machine_core_tb
// Description: Comprehensive testbench for coffee machine brewing sequence
//              Tests full flow from power-on through brewing completion
// Author: Gabriel DiMartino
// Date: November 2025
//============================================================================

`define SIMULATION
`timescale 1ns/1ps

module coffee_machine_core_tb;

    //========================================================================
    // Clock and Reset
    //========================================================================
    reg clk;
    reg rst_n;
    
    //========================================================================
    // Push Buttons (active low on board, inverted in top module)
    //========================================================================
    reg KEY0;  // Right button
    reg KEY1;  // Cancel/Back button
    reg KEY2;  // Left button  
    reg KEY3;  // Select/Start button
    
    //========================================================================
    // Switches
    //========================================================================
    reg SW0, SW1;    // Paper [1:0]
    reg SW2, SW3;    // Bin0 [1:0]
    reg SW4, SW5;    // Bin1 [1:0]
    reg SW6, SW7;    // Creamer [1:0]
    reg SW8, SW9;    // Chocolate [1:0]
    reg SW10, SW11;  // Pressure [1:0]
    reg SW12;        // Temp override
    reg SW13;        // System fault
    reg SW14, SW15, SW16;  // Reserved
    reg SW17;        // Reset
    
    //========================================================================
    // LEDs
    //========================================================================
    wire LEDR0, LEDR1, LEDR2, LEDR3, LEDR4, LEDR5, LEDR6, LEDR7;
    wire LEDR8, LEDR9, LEDR10, LEDR11, LEDR12, LEDR13, LEDR14, LEDR15;
    wire LEDR16, LEDR17;
    wire LEDG0, LEDG1, LEDG2, LEDG3, LEDG4, LEDG5, LEDG6, LEDG7, LEDG8;
    
    //========================================================================
    // LCD Display Interface
    //========================================================================
    wire LCD_ON, LCD_BLON, LCD_EN, LCD_RS, LCD_RW;
    wire [7:0] LCD_DATA;
    
    //========================================================================
    // 7-Segment Displays
    //========================================================================
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;
    
    //========================================================================
    // DUT Instantiation
    //========================================================================
    coffee_machine_top dut (
        .CLOCK_50(clk),
        .KEY0(KEY0), .KEY1(KEY1), .KEY2(KEY2), .KEY3(KEY3),
        .SW0(SW0), .SW1(SW1), .SW2(SW2), .SW3(SW3),
        .SW4(SW4), .SW5(SW5), .SW6(SW6), .SW7(SW7),
        .SW8(SW8), .SW9(SW9), .SW10(SW10), .SW11(SW11),
        .SW12(SW12), .SW13(SW13), .SW14(SW14), .SW15(SW15),
        .SW16(SW16), .SW17(SW17),
        .LEDR0(LEDR0), .LEDR1(LEDR1), .LEDR2(LEDR2), .LEDR3(LEDR3),
        .LEDR4(LEDR4), .LEDR5(LEDR5), .LEDR6(LEDR6), .LEDR7(LEDR7),
        .LEDR8(LEDR8), .LEDR9(LEDR9), .LEDR10(LEDR10), .LEDR11(LEDR11),
        .LEDR12(LEDR12), .LEDR13(LEDR13), .LEDR14(LEDR14), .LEDR15(LEDR15),
        .LEDR16(LEDR16), .LEDR17(LEDR17),
        .LEDG0(LEDG0), .LEDG1(LEDG1), .LEDG2(LEDG2), .LEDG3(LEDG3),
        .LEDG4(LEDG4), .LEDG5(LEDG5), .LEDG6(LEDG6), .LEDG7(LEDG7),
        .LEDG8(LEDG8),
        .LCD_ON(LCD_ON), .LCD_BLON(LCD_BLON), .LCD_EN(LCD_EN),
        .LCD_RS(LCD_RS), .LCD_RW(LCD_RW), .LCD_DATA(LCD_DATA),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3),
        .HEX4(HEX4), .HEX5(HEX5), .HEX6(HEX6), .HEX7(HEX7)
    );
    
    //========================================================================
    // Clock Generation - 50MHz
    //========================================================================
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 50MHz = 20ns period
    end
    
    //========================================================================
    // Helper Tasks
    //========================================================================
    
    // Press and release a button
    task press_button;
        input [3:0] button_num;
        begin
            case (button_num)
                0: begin  // Right (KEY0)
                    KEY0 = 0;
                    #500_000;  // Hold for 500us
                    KEY0 = 1;
                end
                1: begin  // Cancel (KEY1)
                    KEY1 = 0;
                    #500_000;
                    KEY1 = 1;
                end
                2: begin  // Left (KEY2)
                    KEY2 = 0;
                    #500_000;
                    KEY2 = 1;
                end
                3: begin  // Select (KEY3)
                    KEY3 = 0;
                    #500_000;
                    KEY3 = 1;
                end
            endcase
            #1_000_000;  // Wait 1ms after release
        end
    endtask
    
    // Display current state information
    task display_state;
        input string label;
        begin
            $display("\n========================================");
            $display("TIME: %0t ns | %s", $time, label);
            $display("========================================");
            $display("Main FSM State: %0d", dut.main_fsm_inst.current_state);
            $display("Menu State: %0d", dut.menu_state);
            $display("Recipe State: %0d", dut.recipe_engine_inst.brew_state);
            $display("----------------------------------------");
            $display("system_active: %b", dut.system_active);
            $display("system_ready: %b", dut.system_ready);
            $display("recipe_brewing_active: %b", dut.recipe_brewing_active);
            $display("recipe_brewing_complete: %b", dut.recipe_brewing_complete);
            $display("----------------------------------------");
            $display("temp_ready: %b", dut.temp_ready);
            $display("pressure_ready: %b", dut.pressure_ready);
            $display("current_temp: %0d", dut.current_temp);
            $display("----------------------------------------");
            $display("LEDs: LEDG0(brew)=%b LEDG1(temp)=%b LEDG7(complete)=%b", 
                     LEDG0, LEDG1, LEDG7);
            $display("      LEDR14(ready)=%b LEDR15(active)=%b", LEDR14, LEDR15);
            $display("========================================\n");
        end
    endtask
    
    // Monitor key signals continuously
    reg [3:0] prev_main_state;
    reg [3:0] prev_menu_state_mon;
    reg [3:0] prev_recipe_state;
    
    initial begin
        prev_main_state = 0;
        prev_menu_state_mon = 0;
        prev_recipe_state = 0;
        
        forever begin
            @(posedge clk);
            
            // Detect state changes
            if (dut.main_fsm_inst.current_state != prev_main_state) begin
                $display("[%0t] MAIN FSM: %0d -> %0d", $time, 
                         prev_main_state, 
                         dut.main_fsm_inst.current_state);
                prev_main_state = dut.main_fsm_inst.current_state;
            end
            
            // Detect menu state changes
            if (dut.menu_state != prev_menu_state_mon) begin
                $display("[%0t] MENU: %0d -> %0d", $time,
                         prev_menu_state_mon,
                         dut.menu_state);
                prev_menu_state_mon = dut.menu_state;
            end
            
            // Detect recipe state changes
            if (dut.recipe_engine_inst.brew_state != prev_recipe_state) begin
                $display("[%0t] RECIPE: %0d -> %0d", $time,
                         prev_recipe_state,
                         dut.recipe_engine_inst.brew_state);
                prev_recipe_state = dut.recipe_engine_inst.brew_state;
            end
            
            // Detect brewing signals
            if (dut.recipe_start_brewing) begin
                $display("[%0t] *** RECIPE START BREWING PULSE ***", $time);
            end
            
            if (dut.recipe_brewing_complete) begin
                $display("[%0t] *** BREWING COMPLETE ***", $time);
            end
        end
    end
    
    //========================================================================
    // Test Sequence
    //========================================================================
    initial begin
        $display("\n");
        $display("================================================================================");
        $display("  COFFEE MACHINE CORE TESTBENCH");
        $display("  Testing: Full brew sequence with heating phase");
        $display("================================================================================\n");
        
        // Initialize all inputs
        rst_n = 1;
        KEY0 = 1;  // Buttons inactive (active low)
        KEY1 = 1;
        KEY2 = 1;
        KEY3 = 1;
        
        // Set all consumables to INFINITE (11)
        SW0 = 1; SW1 = 1;   // Paper infinite
        SW2 = 1; SW3 = 1;   // Bin0 infinite
        SW4 = 1; SW5 = 1;   // Bin1 infinite
        SW6 = 1; SW7 = 1;   // Creamer infinite
        SW8 = 1; SW9 = 1;   // Chocolate infinite
        
        // Pressure OK (01)
        SW10 = 1; SW11 = 0;
        
        // No overrides/faults
        SW12 = 0;  // No temp override
        SW13 = 1;  // No fault (inverted - 1=OK, 0=FAULT)
        SW14 = 0;
        SW15 = 0;
        SW16 = 0;
        SW17 = 0;  // Not in reset
        
        // Apply reset
        $display("[%0t] Applying reset...", $time);
        SW17 = 1;
        #100_000;  // Hold reset for 100us
        SW17 = 0;
        #100_000;  // Wait for system to stabilize
        
        display_state("After Reset");
        
        // Wait for splash screen
        $display("[%0t] Waiting for splash screen...", $time);
        #5_000_000;  // Wait 5ms
        
        display_state("Splash Screen");
        
        //====================================================================
        // Test 1: Navigate to coffee selection
        //====================================================================
        $display("\n[%0t] TEST 1: Starting coffee selection...", $time);
        
        // Press SELECT to start (KEY3)
        $display("[%0t] Pressing SELECT to start...", $time);
        press_button(3);
        
        display_state("After START press");
        
        // Should now be in coffee selection - press SELECT to choose Bin0
        $display("[%0t] Pressing SELECT to choose coffee bin...", $time);
        press_button(3);
        
        display_state("After Coffee Selection");
        
        // Should now be in drink selection - default is Black Coffee
        $display("[%0t] Pressing SELECT to choose Black Coffee...", $time);
        press_button(3);
        
        display_state("After Drink Selection");
        
        // Should now be in size selection - default is 12oz
        $display("[%0t] Pressing SELECT to choose 12oz...", $time);
        press_button(3);
        
        display_state("After Size Selection");
        
        // Should now be at confirm screen
        $display("[%0t] At confirmation screen...", $time);
        #2_000_000;  // Wait 2ms to see confirmation
        
        display_state("Confirmation Screen");
        
        //====================================================================
        // Test 2: Start brewing and monitor
        //====================================================================
        $display("\n[%0t] TEST 2: Starting brew sequence...", $time);
        
        // Press SELECT to confirm and start brewing (KEY3)
        $display("[%0t] Pressing SELECT to START BREWING...", $time);
        press_button(3);
        
        #1_000_000;  // Wait 1ms
        display_state("IMMEDIATELY After Brew Start");
        
        // Check if we jumped to complete immediately
        if (dut.menu_state == 7) begin  // STATE_COMPLETE = 7
            $display("\n*** ERROR: Menu jumped to COMPLETE immediately! ***");
            $display("This indicates the brewing_active signal is not working correctly.\n");
        end else begin
            $display("\n*** GOOD: Menu did NOT jump to complete immediately ***\n");
        end
        
        // Monitor heating phase
        $display("[%0t] Monitoring heating phase...", $time);
        fork
            begin
                // Monitor for 100ms or until temp ready
                repeat (100) begin
                    #1_000_000;  // Check every 1ms
                    if (dut.temp_ready) begin
                        $display("[%0t] Temperature ready detected!", $time);
                        break;
                    end
                end
            end
        join
        
        display_state("During Heating");
        
        // Wait for brewing to actually start
        $display("[%0t] Waiting for brewing to start...", $time);
        wait (LEDG0 == 1);  // Wait for brewing_active LED
        
        display_state("Brewing Started");
        
        // Monitor brewing progress
        $display("[%0t] Monitoring brewing progress...", $time);
        fork
            begin
                integer last_progress;
                last_progress = 0;
                
                repeat (1000) begin
                    #1_000_000;  // Check every 1ms
                    
                    // Display progress when it changes significantly
                    if (dut.brew_progress != last_progress && 
                        (dut.brew_progress % 10 == 0)) begin
                        $display("[%0t] Brew Progress: %0d%%", $time, dut.brew_progress);
                        last_progress = dut.brew_progress;
                    end
                    
                    // Check if complete
                    if (dut.recipe_brewing_complete) begin
                        $display("[%0t] Brewing complete signal detected!", $time);
                        break;
                    end
                end
            end
        join
        
        display_state("After Brewing");
        
        // Wait a bit more to see completion screen
        #10_000_000;  // 10ms
        
        display_state("Final State");
        
        //====================================================================
        // Summary
        //====================================================================
        $display("\n");
        $display("================================================================================");
        $display("  TEST SUMMARY");
        $display("================================================================================");
        $display("Final Menu State: %0d (7=COMPLETE expected)", dut.menu_state);
        $display("Final Main FSM State: %0d", dut.main_fsm_inst.current_state);
        $display("Final Recipe State: %0d (0=IDLE expected)", dut.recipe_engine_inst.brew_state);
        $display("================================================================================\n");
        
        // End simulation
        #1_000_000;
        $display("[%0t] Simulation complete.", $time);
        $finish;
    end
    
    //========================================================================
    // Timeout Watchdog
    //========================================================================
    initial begin
        #2_000_000_000;  // 2 seconds timeout
        $display("\n*** ERROR: Simulation timeout! ***");
        $display("Simulation exceeded 2 seconds - likely stuck in a state.\n");
        display_state("TIMEOUT");
        $finish;
    end

endmodule