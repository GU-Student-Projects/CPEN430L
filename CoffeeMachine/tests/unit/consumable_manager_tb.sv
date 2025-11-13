//============================================================================
// Module: consumable_manager_tb
// Description: Unit test for consumable_manager module
//              Tests ingredient tracking, consumption, and status flags
// Author: Gabriel DiMartino
// Date: November 2025
//============================================================================

`timescale 1ns/1ps

module consumable_manager_tb;

    //========================================================================
    // Testbench Parameters
    //========================================================================
    parameter CLK_PERIOD = 20;  // 50 MHz clock
    parameter SIM_TIME = 100_000_000;  // 100ms simulation
    
    //========================================================================
    // DUT Signals
    //========================================================================
    logic clk;
    logic rst_n;
    
    // Sensor inputs
    logic [7:0] sensor_bin0_level;
    logic [7:0] sensor_bin1_level;
    logic [7:0] sensor_creamer_level;
    logic [7:0] sensor_chocolate_level;
    logic       paper_filter_present;
    
    // Consumption interface
    logic       consume_enable;
    logic [7:0] consume_bin0_amount;
    logic [7:0] consume_bin1_amount;
    logic [7:0] consume_creamer_amount;
    logic [7:0] consume_chocolate_amount;
    logic       consume_paper_filter;
    
    // Managed levels
    logic [7:0] coffee_bin0_level;
    logic [7:0] coffee_bin1_level;
    logic [7:0] creamer_level;
    logic [7:0] chocolate_level;
    logic [7:0] paper_filter_count;
    
    // Status flags
    logic bin0_empty, bin0_low;
    logic bin1_empty, bin1_low;
    logic creamer_empty, creamer_low;
    logic chocolate_empty, chocolate_low;
    logic paper_empty, paper_low;
    logic can_make_coffee, can_add_creamer, can_add_chocolate;
    
    //========================================================================
    // DUT Instantiation
    //========================================================================
    consumable_manager dut (
        .clk(clk),
        .rst_n(rst_n),
        .sensor_bin0_level(sensor_bin0_level),
        .sensor_bin1_level(sensor_bin1_level),
        .sensor_creamer_level(sensor_creamer_level),
        .sensor_chocolate_level(sensor_chocolate_level),
        .paper_filter_present(paper_filter_present),
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
        .paper_filter_count(paper_filter_count),
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
        .can_add_creamer(can_add_creamer),
        .can_add_chocolate(can_add_chocolate)
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
        $display("ERROR: Simulation timeout!");
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
            sensor_bin0_level = 8'd255;
            sensor_bin1_level = 8'd255;
            sensor_creamer_level = 8'd255;
            sensor_chocolate_level = 8'd255;
            paper_filter_present = 1;
            consume_enable = 0;
            consume_bin0_amount = 0;
            consume_bin1_amount = 0;
            consume_creamer_amount = 0;
            consume_chocolate_amount = 0;
            consume_paper_filter = 0;
            
            repeat(10) @(posedge clk);
            rst_n = 1;
            repeat(5) @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask
    
    task consume_ingredients(
        input [7:0] bin0, bin1, cream, choc,
        input paper
    );
        begin
            @(posedge clk);
            consume_enable = 1;
            consume_bin0_amount = bin0;
            consume_bin1_amount = bin1;
            consume_creamer_amount = cream;
            consume_chocolate_amount = choc;
            consume_paper_filter = paper;
            @(posedge clk);
            consume_enable = 0;
            consume_bin0_amount = 0;
            consume_bin1_amount = 0;
            consume_creamer_amount = 0;
            consume_chocolate_amount = 0;
            consume_paper_filter = 0;
            repeat(5) @(posedge clk);
        end
    endtask
    
    task check_level(input string name, input [7:0] actual, input [7:0] expected);
        begin
            if (actual !== expected) begin
                $display("[%0t] ERROR: %s mismatch! Expected: %0d, Got: %0d", 
                         $time, name, expected, actual);
            end else begin
                $display("[%0t] PASS: %s = %0d", $time, name, actual);
            end
        end
    endtask
    
    task check_flag(input string name, input actual, input expected);
        begin
            if (actual !== expected) begin
                $display("[%0t] ERROR: %s mismatch! Expected: %b, Got: %b", 
                         $time, name, expected, actual);
            end else begin
                $display("[%0t] PASS: %s = %b", $time, name, actual);
            end
        end
    endtask
    
    //========================================================================
    // Main Test Sequence
    //========================================================================
    initial begin
        $display("========================================");
        $display("Consumable Manager Unit Test");
        $display("========================================");
        
        reset_dut();
        
        //--------------------------------------------------------------------
        // Test 1: Initial State (All Full)
        //--------------------------------------------------------------------
        $display("\n--- Test 1: Initial State ---");
        check_level("Bin0", coffee_bin0_level, 8'd255);
        check_level("Bin1", coffee_bin1_level, 8'd255);
        check_level("Creamer", creamer_level, 8'd255);
        check_level("Chocolate", chocolate_level, 8'd255);
        check_level("Paper", paper_filter_count, 8'd255);
        
        check_flag("bin0_empty", bin0_empty, 1'b0);
        check_flag("bin0_low", bin0_low, 1'b0);
        check_flag("can_make_coffee", can_make_coffee, 1'b1);
        
        //--------------------------------------------------------------------
        // Test 2: Consume from Bin 0
        //--------------------------------------------------------------------
        $display("\n--- Test 2: Consume from Bin 0 ---");
        consume_ingredients(8'd30, 8'd0, 8'd0, 8'd0, 1'b0);
        check_level("Bin0", coffee_bin0_level, 8'd225);  // 255 - 30
        
        //--------------------------------------------------------------------
        // Test 3: Consume from Bin 1
        //--------------------------------------------------------------------
        $display("\n--- Test 3: Consume from Bin 1 ---");
        consume_ingredients(8'd0, 8'd40, 8'd0, 8'd0, 1'b0);
        check_level("Bin1", coffee_bin1_level, 8'd215);  // 255 - 40
        
        //--------------------------------------------------------------------
        // Test 4: Consume Creamer
        //--------------------------------------------------------------------
        $display("\n--- Test 4: Consume Creamer ---");
        consume_ingredients(8'd0, 8'd0, 8'd15, 8'd0, 1'b0);
        check_level("Creamer", creamer_level, 8'd240);  // 255 - 15
        
        //--------------------------------------------------------------------
        // Test 5: Consume Chocolate
        //--------------------------------------------------------------------
        $display("\n--- Test 5: Consume Chocolate ---");
        consume_ingredients(8'd0, 8'd0, 8'd0, 8'd20, 1'b0);
        check_level("Chocolate", chocolate_level, 8'd235);  // 255 - 20
        
        //--------------------------------------------------------------------
        // Test 6: Consume Paper Filter
        //--------------------------------------------------------------------
        $display("\n--- Test 6: Consume Paper Filter ---");
        consume_ingredients(8'd0, 8'd0, 8'd0, 8'd0, 1'b1);
        check_level("Paper", paper_filter_count, 8'd254);  // 255 - 1
        
        //--------------------------------------------------------------------
        // Test 7: Multiple Ingredients at Once
        //--------------------------------------------------------------------
        $display("\n--- Test 7: Multiple Ingredients ---");
        consume_ingredients(8'd30, 8'd0, 8'd15, 8'd20, 1'b1);
        check_level("Bin0", coffee_bin0_level, 8'd195);  // 225 - 30
        check_level("Creamer", creamer_level, 8'd225);  // 240 - 15
        check_level("Chocolate", chocolate_level, 8'd215);  // 235 - 20
        check_level("Paper", paper_filter_count, 8'd253);  // 254 - 1
        
        //--------------------------------------------------------------------
        // Test 8: Deplete to Low Level
        //--------------------------------------------------------------------
        $display("\n--- Test 8: Deplete to Low Level ---");
        
        // Consume until bin0 is low (< 50)
        repeat(5) begin
            consume_ingredients(8'd30, 8'd0, 8'd0, 8'd0, 1'b0);
        end
        
        $display("[%0t] Bin0 level after depletion: %0d", $time, coffee_bin0_level);
        check_flag("bin0_low", bin0_low, 1'b1);
        check_flag("bin0_empty", bin0_empty, 1'b0);
        check_flag("can_make_coffee", can_make_coffee, 1'b1);  // Still have bin1
        
        //--------------------------------------------------------------------
        // Test 9: Deplete to Empty
        //--------------------------------------------------------------------
        $display("\n--- Test 9: Deplete to Empty ---");
        
        // Consume remaining bin0
        repeat(3) begin
            consume_ingredients(8'd20, 8'd0, 8'd0, 8'd0, 1'b0);
        end
        
        $display("[%0t] Bin0 level after emptying: %0d", $time, coffee_bin0_level);
        check_flag("bin0_empty", bin0_empty, 1'b1);
        check_flag("can_make_coffee", can_make_coffee, 1'b1);  // Still have bin1
        
        //--------------------------------------------------------------------
        // Test 10: Sensor Refill
        //--------------------------------------------------------------------
        $display("\n--- Test 10: Sensor Refill ---");
        
        sensor_bin0_level = 8'd255;  // Simulate refill
        repeat(5) @(posedge clk);
        check_level("Bin0", coffee_bin0_level, 8'd255);
        check_flag("bin0_empty", bin0_empty, 1'b0);
        check_flag("bin0_low", bin0_low, 1'b0);
        
        //--------------------------------------------------------------------
        // Test 11: Sensor Empty Override
        //--------------------------------------------------------------------
        $display("\n--- Test 11: Sensor Empty Override ---");
        
        sensor_bin1_level = 8'd0;  // Simulate empty
        repeat(5) @(posedge clk);
        check_level("Bin1", coffee_bin1_level, 8'd0);
        check_flag("bin1_empty", bin1_empty, 1'b1);
        
        //--------------------------------------------------------------------
        // Test 12: Both Bins Empty
        //--------------------------------------------------------------------
        $display("\n--- Test 12: Both Bins Empty ---");
        
        sensor_bin0_level = 8'd0;
        repeat(5) @(posedge clk);
        check_flag("can_make_coffee", can_make_coffee, 1'b0);
        
        //--------------------------------------------------------------------
        // Test 13: Underflow Protection
        //--------------------------------------------------------------------
        $display("\n--- Test 13: Underflow Protection ---");
        
        // Refill bin0
        sensor_bin0_level = 8'd255;
        repeat(5) @(posedge clk);
        
        // Set to low level
        repeat(8) begin
            consume_ingredients(8'd25, 8'd0, 8'd0, 8'd0, 1'b0);
        end
        
        $display("[%0t] Bin0 after many consumptions: %0d", $time, coffee_bin0_level);
        
        // Try to consume more than available
        consume_ingredients(8'd100, 8'd0, 8'd0, 8'd0, 1'b0);
        
        if (coffee_bin0_level == 0) begin
            $display("[%0t] PASS: Underflow protection working", $time);
        end else begin
            $display("[%0t] ERROR: Level went negative!", $time);
        end
        
        //--------------------------------------------------------------------
        // Test 14: Paper Filter Refill
        //--------------------------------------------------------------------
        $display("\n--- Test 14: Paper Filter Refill ---");
        
        // Deplete paper
        repeat(254) begin
            consume_ingredients(8'd0, 8'd0, 8'd0, 8'd0, 1'b1);
        end
        
        check_level("Paper", paper_filter_count, 8'd0);
        check_flag("paper_empty", paper_empty, 1'b1);
        
        // Simulate paper refill
        paper_filter_present = 1;
        repeat(5) @(posedge clk);
        check_level("Paper", paper_filter_count, 8'd255);
        check_flag("paper_empty", paper_empty, 1'b0);
        
        //--------------------------------------------------------------------
        // Test 15: Availability Flags
        //--------------------------------------------------------------------
        $display("\n--- Test 15: Availability Flags ---");
        
        // Refill everything
        sensor_bin0_level = 8'd255;
        sensor_bin1_level = 8'd255;
        sensor_creamer_level = 8'd255;
        sensor_chocolate_level = 8'd255;
        repeat(5) @(posedge clk);
        
        check_flag("can_make_coffee", can_make_coffee, 1'b1);
        check_flag("can_add_creamer", can_add_creamer, 1'b1);
        check_flag("can_add_chocolate", can_add_chocolate, 1'b1);
        
        // Empty creamer
        sensor_creamer_level = 8'd0;
        repeat(5) @(posedge clk);
        check_flag("can_add_creamer", can_add_creamer, 1'b0);
        
        // Empty chocolate
        sensor_chocolate_level = 8'd0;
        repeat(5) @(posedge clk);
        check_flag("can_add_chocolate", can_add_chocolate, 1'b0);
        
        //--------------------------------------------------------------------
        // Test Complete
        //--------------------------------------------------------------------
        $display("\n========================================");
        $display("Consumable Manager Unit Test Complete!");
        $display("========================================");
        
        #10_000;
        $finish;
    end
    
    //========================================================================
    // Waveform Dump
    //========================================================================
    initial begin
        $dumpfile("consumable_manager_tb.vcd");
        $dumpvars(0, consumable_manager_tb);
    end

endmodule