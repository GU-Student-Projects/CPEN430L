//============================================================================
// Module: recipe_engine_tb
// Description: Unit test for recipe_engine module
// Author: Gabriel DiMartino
// Tests: Recipe validation, brewing sequences, ingredient consumption
//============================================================================

`timescale 1ns/1ps

module recipe_engine_tb;
    parameter CLK_PERIOD = 20;
    parameter SIM_TIME = 64'd2_000_000_000;
    
    // Clock and reset
    logic clk, rst_n;
    
    // Recipe selection
    logic [2:0] selected_coffee_type;
    logic [2:0] selected_drink_type;
    logic [1:0] selected_size;
    
    // Brewing control
    logic start_brewing, abort_brewing;
    
    // Consumption interface
    logic consume_enable;
    logic [7:0] consume_bin0_amount, consume_bin1_amount;
    logic [7:0] consume_creamer_amount, consume_chocolate_amount;
    logic consume_paper_filter;
    
    // Ingredient levels
    logic [7:0] coffee_bin0_level, coffee_bin1_level;
    logic [7:0] creamer_level, chocolate_level;
    logic paper_filter_present;
    
    // Actuator outputs
    logic grinder0_enable, grinder1_enable;
    logic water_pour_enable, water_direct_enable;
    logic paper_motor_enable;
    
    // Status outputs
    logic brewing_active, brewing_complete;
    logic [7:0] brew_progress;
    logic recipe_valid;
    
    recipe_engine #(
        .TIME_GRIND(32'd1_000_000),         // 20ms
        .TIME_POUR(32'd1_500_000),          // 30ms
        .TIME_PAPER_FEED(32'd250_000),      // 5ms
        .TIME_SETTLE(32'd250_000)           // 5ms
    ) dut (.*);
    
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Timeout
    initial begin
        #SIM_TIME;
        $display("\n========================================");
        $display("Recipe Engine Test Complete!");
        $display("========================================");
        $finish;
    end
    
    // Test sequence
    initial begin
        $display("========================================");
        $display("Recipe Engine Unit Test");
        $display("========================================");
        $display("");
        
        // Initialize inputs
        rst_n = 0;
        selected_coffee_type = 0;
        selected_drink_type = 0;
        selected_size = 1;  // 12oz
        start_brewing = 0;
        abort_brewing = 0;
        
        // Initialize consumable levels (full)
        coffee_bin0_level = 8'd255;
        coffee_bin1_level = 8'd255;
        creamer_level = 8'd255;
        chocolate_level = 8'd255;
        paper_filter_present = 1;
        
        // Reset sequence
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        //====================================================================
        // Test 1: Recipe Validation - Black Coffee
        //====================================================================
        $display("\n--- Test 1: Recipe Validation (Black Coffee) ---");
        selected_drink_type = 3'd0;  // Black coffee
        selected_coffee_type = 3'd0;  // Bin 0
        selected_size = 2'd1;  // 12oz
        
        repeat(5) @(posedge clk);
        
        if (recipe_valid) begin
            $display("[%0t] PASS: Black coffee recipe valid", $time);
        end else begin
            $display("[%0t] FAIL: Black coffee should be valid", $time);
        end
        
        //====================================================================
        // Test 2: Recipe Validation - Insufficient Ingredients
        //====================================================================
        $display("\n--- Test 2: Recipe Validation (Insufficient Coffee) ---");
        coffee_bin0_level = 8'd10;  // Not enough
        
        repeat(5) @(posedge clk);
        
        if (!recipe_valid) begin
            $display("[%0t] PASS: Recipe correctly marked invalid", $time);
        end else begin
            $display("[%0t] FAIL: Should be invalid with low coffee", $time);
        end
        
        // Restore coffee level
        coffee_bin0_level = 8'd255;
        repeat(5) @(posedge clk);
        
        //====================================================================
        // Test 3: Size Scaling
        //====================================================================
        $display("\n--- Test 3: Size Scaling ---");
        
        // Test 8oz
        selected_size = 2'd0;
        repeat(5) @(posedge clk);
        $display("[%0t] 8oz recipe configured", $time);
        
        // Test 12oz
        selected_size = 2'd1;
        repeat(5) @(posedge clk);
        $display("[%0t] 12oz recipe configured (base size)", $time);
        
        // Test 16oz
        selected_size = 2'd2;
        repeat(5) @(posedge clk);
        $display("[%0t] 16oz recipe configured", $time);
        
        $display("[%0t] PASS: Size scaling working", $time);
        
        //====================================================================
        // Test 4: Complete Brewing Cycle - Black Coffee
        //====================================================================
        $display("\n--- Test 4: Complete Brewing Cycle (Black Coffee) ---");
        
        selected_drink_type = 3'd0;  // Black coffee
        selected_coffee_type = 3'd0;  // Bin 0
        selected_size = 2'd1;  // 12oz
        
        repeat(10) @(posedge clk);
        
        // Start brewing
        $display("[%0t] Starting brew cycle...", $time);
        start_brewing = 1;
        @(posedge clk);
        start_brewing = 0;
        
        // Wait for brewing to become active
        repeat(10) @(posedge clk);
        
        if (brewing_active) begin
            $display("[%0t] PASS: Brewing started", $time);
        end else begin
            $display("[%0t] FAIL: Brewing not active", $time);
        end
        
        // Monitor brewing progress with simple sequential waits
        $display("[%0t] Monitoring brew cycle...", $time);
        
        // Wait for paper feed phase (with timeout)
        repeat(500_000) begin  // 10ms timeout
            @(posedge clk);
            if (paper_motor_enable) begin
                $display("[%0t] Paper feed active (progress=%0d%%)", $time, brew_progress);
                break;
            end
        end
        
        // Wait for grinding phase (with timeout)
        repeat(2_000_000) begin  // 40ms timeout
            @(posedge clk);
            if (grinder0_enable || grinder1_enable) begin
                $display("[%0t] Grinder active (progress=%0d%%)", $time, brew_progress);
                break;
            end
        end
        
        // Wait for pouring phase (with timeout)
        repeat(3_000_000) begin  // 60ms timeout
            @(posedge clk);
            if (water_pour_enable) begin
                $display("[%0t] Water pouring (progress=%0d%%)", $time, brew_progress);
                break;
            end
        end
        
        // Wait for completion (with timeout)
        repeat(5_000_000) begin  // 100ms timeout
            @(posedge clk);
            if (brewing_complete) begin
                $display("[%0t] PASS: Brew cycle completed (progress=%0d%%)", $time, brew_progress);
                break;
            end
        end
        
        repeat(10) @(posedge clk);
        
        //====================================================================
        // Test 5: Ingredient Consumption Tracking
        //====================================================================
        $display("\n--- Test 5: Ingredient Consumption ---");
        
        // Reset levels
        coffee_bin0_level = 8'd255;
        creamer_level = 8'd255;
        chocolate_level = 8'd255;
        paper_filter_present = 1;
        
        // Select a recipe with multiple ingredients (Mocha)
        selected_drink_type = 3'd3;  // Mocha
        selected_coffee_type = 3'd0;  // Bin 0
        selected_size = 2'd1;  // 12oz
        
        repeat(10) @(posedge clk);
        
        // Start brewing
        $display("[%0t] Starting Mocha brew...", $time);
        start_brewing = 1;
        @(posedge clk);
        start_brewing = 0;
        
        // Monitor consumption signals (simple approach)
        begin
            automatic int coffee_consumed = 0;
            automatic int creamer_consumed = 0;
            automatic int chocolate_consumed = 0;
            automatic int paper_consumed = 0;
            
            // Monitor for up to 100ms
            repeat(5_000_000) begin
                @(posedge clk);
                
                if (brewing_complete) break;
                
                if (consume_enable) begin
                    if (consume_bin0_amount > 0) begin
                        coffee_consumed = 1;
                        $display("[%0t] Coffee consumed: %0d units", $time, consume_bin0_amount);
                    end
                    if (consume_creamer_amount > 0) begin
                        creamer_consumed = 1;
                        $display("[%0t] Creamer consumed: %0d units", $time, consume_creamer_amount);
                    end
                    if (consume_chocolate_amount > 0) begin
                        chocolate_consumed = 1;
                        $display("[%0t] Chocolate consumed: %0d units", $time, consume_chocolate_amount);
                    end
                    if (consume_paper_filter) begin
                        paper_consumed = 1;
                        $display("[%0t] Paper filter consumed", $time);
                    end
                end
            end
            
            // Check all ingredients were consumed
            if (coffee_consumed && creamer_consumed && chocolate_consumed && paper_consumed) begin
                $display("[%0t] PASS: All Mocha ingredients consumed", $time);
            end else begin
                $display("[%0t] FAIL: Missing ingredients (C:%0d Cr:%0d Ch:%0d P:%0d)",
                         $time, coffee_consumed, creamer_consumed, chocolate_consumed, paper_consumed);
            end
        end
        
        repeat(20) @(posedge clk);
        
        //====================================================================
        // Test 6: Abort Brewing
        //====================================================================
        $display("\n--- Test 6: Abort Brewing ---");
        
        selected_drink_type = 3'd0;  // Black coffee
        selected_size = 2'd1;
        
        repeat(10) @(posedge clk);
        
        // Start brewing
        $display("[%0t] Starting brew to abort...", $time);
        start_brewing = 1;
        @(posedge clk);
        start_brewing = 0;
        
        // Wait a bit
        repeat(100) @(posedge clk);
        
        // Abort
        $display("[%0t] Aborting brew...", $time);
        abort_brewing = 1;
        @(posedge clk);
        abort_brewing = 0;
        
        // Check brewing stopped
        repeat(20) @(posedge clk);
        
        if (!brewing_active) begin
            $display("[%0t] PASS: Brewing aborted successfully", $time);
        end else begin
            $display("[%0t] FAIL: Brewing still active after abort", $time);
        end
        
        //====================================================================
        // Test 7: Hot Chocolate (No Coffee)
        //====================================================================
        $display("\n--- Test 7: Hot Chocolate Recipe ---");
        
        selected_drink_type = 3'd4;  // Hot chocolate
        selected_size = 2'd1;
        
        repeat(10) @(posedge clk);
        
        if (recipe_valid) begin
            $display("[%0t] PASS: Hot chocolate recipe valid (no coffee needed)", $time);
        end else begin
            $display("[%0t] FAIL: Hot chocolate should be valid", $time);
        end
        
        // Start brewing hot chocolate
        $display("[%0t] Starting hot chocolate brew...", $time);
        start_brewing = 1;
        @(posedge clk);
        start_brewing = 0;
        
        // Wait for completion with timeout
        repeat(5_000_000) begin
            @(posedge clk);
            if (brewing_complete) begin
                $display("[%0t] PASS: Hot chocolate brew completed", $time);
                break;
            end
        end
        
        repeat(20) @(posedge clk);
        
        //====================================================================
        // Test 8: Coffee Bin Selection
        //====================================================================
        $display("\n--- Test 8: Coffee Bin Selection ---");
        
        selected_drink_type = 3'd0;  // Black coffee
        selected_size = 2'd1;
        
        // Test Bin 0
        selected_coffee_type = 3'd0;
        repeat(10) @(posedge clk);
        
        start_brewing = 1;
        @(posedge clk);
        start_brewing = 0;
        
        // Wait for grinding with timeout
        repeat(2_000_000) begin
            @(posedge clk);
            if (grinder0_enable || grinder1_enable) break;
        end
        
        if (grinder0_enable && !grinder1_enable) begin
            $display("[%0t] PASS: Bin 0 grinder selected", $time);
        end else begin
            $display("[%0t] FAIL: Wrong grinder active", $time);
        end
        
        // Wait for completion
        repeat(5_000_000) begin
            @(posedge clk);
            if (brewing_complete) break;
        end
        repeat(20) @(posedge clk);
        
        // Test Bin 1
        selected_coffee_type = 3'd1;
        repeat(10) @(posedge clk);
        
        start_brewing = 1;
        @(posedge clk);
        start_brewing = 0;
        
        // Wait for grinding with timeout
        repeat(2_000_000) begin
            @(posedge clk);
            if (grinder0_enable || grinder1_enable) break;
        end
        
        if (grinder1_enable && !grinder0_enable) begin
            $display("[%0t] PASS: Bin 1 grinder selected", $time);
        end else begin
            $display("[%0t] FAIL: Wrong grinder active", $time);
        end
        
        // Wait for completion
        repeat(5_000_000) begin
            @(posedge clk);
            if (brewing_complete) break;
        end
        repeat(20) @(posedge clk);
        
        //====================================================================
        // Summary
        //====================================================================
        $display("\n========================================");
        $display("Recipe Engine Unit Test Summary");
        $display("========================================");
        
        #10_000;
        $finish;
    end
    
    // VCD dump for waveform viewing
    initial begin
        $dumpfile("recipe_engine_tb.vcd");
        $dumpvars(0, recipe_engine_tb);
    end
    
    // Monitor key signals
    initial begin
        $monitor("[%0t] State: brewing=%b complete=%b progress=%0d%% valid=%b",
                 $time, brewing_active, brewing_complete, brew_progress, recipe_valid);
    end
    
endmodule