//============================================================================
// Module: sensor_interface_tb
// Description: Unit test for sensor_interface module
//              Tests switch debouncing, level management, and LED control
// Author: Gabriel DiMartino
// Date: November 2025
//============================================================================

`timescale 1ns/1ps

module sensor_interface_tb;

    //========================================================================
    // Testbench Parameters
    //========================================================================
    parameter CLK_PERIOD = 20;  // 50 MHz clock
    parameter SIM_TIME = 200_000_000;  // 200ms simulation
    
    //========================================================================
    // DUT Signals
    //========================================================================
    logic clk;
    logic rst_n;
    
    // Switch inputs
    logic       sw_paper_filter;
    logic [1:0] sw_coffee_bin0;
    logic [1:0] sw_coffee_bin1;
    logic [1:0] sw_creamer;
    logic [1:0] sw_chocolate;
    logic       sw_water_pressure_ovr;
    logic       sw_water_temp_ovr;
    logic       sw_system_error;
    
    // LED outputs
    logic led_paper_filter;
    logic led_coffee_bin0;
    logic led_coffee_bin1;
    logic led_creamer;
    logic led_chocolate;
    logic led_water_pressure;
    logic led_water_temp;
    logic led_system_error;
    
    // Sensor outputs
    logic       paper_filter_present;
    logic [7:0] coffee_bin0_level;
    logic [7:0] coffee_bin1_level;
    logic [7:0] creamer_level;
    logic [7:0] chocolate_level;
    logic       water_pressure_ok;
    logic       water_temp_ready;
    logic       system_fault;
    
    //========================================================================
    // DUT Instantiation
    //========================================================================
    sensor_interface dut (
        .clk(clk),
        .rst_n(rst_n),
        .sw_paper_filter(sw_paper_filter),
        .sw_coffee_bin0(sw_coffee_bin0),
        .sw_coffee_bin1(sw_coffee_bin1),
        .sw_creamer(sw_creamer),
        .sw_chocolate(sw_chocolate),
        .sw_water_pressure_ovr(sw_water_pressure_ovr),
        .sw_water_temp_ovr(sw_water_temp_ovr),
        .sw_system_error(sw_system_error),
        .led_paper_filter(led_paper_filter),
        .led_coffee_bin0(led_coffee_bin0),
        .led_coffee_bin1(led_coffee_bin1),
        .led_creamer(led_creamer),
        .led_chocolate(led_chocolate),
        .led_water_pressure(led_water_pressure),
        .led_water_temp(led_water_temp),
        .led_system_error(led_system_error),
        .paper_filter_present(paper_filter_present),
        .coffee_bin0_level(coffee_bin0_level),
        .coffee_bin1_level(coffee_bin1_level),
        .creamer_level(creamer_level),
        .chocolate_level(chocolate_level),
        .water_pressure_ok(water_pressure_ok),
        .water_temp_ready(water_temp_ready),
        .system_fault(system_fault)
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
            
            // Initialize all switches to safe state
            sw_paper_filter = 0;
            sw_coffee_bin0 = 2'b00;
            sw_coffee_bin1 = 2'b00;
            sw_creamer = 2'b00;
            sw_chocolate = 2'b00;
            sw_water_pressure_ovr = 0;
            sw_water_temp_ovr = 0;
            sw_system_error = 0;
            
            repeat(10) @(posedge clk);
            rst_n = 1;
            repeat(5) @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask
    
    task wait_debounce();
        begin
            // Wait for debounce time (20ms + margin)
            #25_000_000;
        end
    endtask
    
    task check_paper_sensor(input expected);
        begin
            if (paper_filter_present !== expected) begin
                $display("[%0t] ERROR: Paper sensor mismatch! Expected: %b, Got: %b", 
                         $time, expected, paper_filter_present);
            end else begin
                $display("[%0t] PASS: Paper sensor = %b", $time, paper_filter_present);
            end
        end
    endtask
    
    task check_level(input string name, input [7:0] actual, input [7:0] expected);
        begin
            if (actual !== expected) begin
                $display("[%0t] ERROR: %s level mismatch! Expected: %0d, Got: %0d", 
                         $time, name, expected, actual);
            end else begin
                $display("[%0t] PASS: %s level = %0d", $time, name, actual);
            end
        end
    endtask
    
    //========================================================================
    // Main Test Sequence
    //========================================================================
    initial begin
        $display("========================================");
        $display("Sensor Interface Unit Test");
        $display("========================================");
        
        reset_dut();
        
        //--------------------------------------------------------------------
        // Test 1: Paper Filter Sensor
        //--------------------------------------------------------------------
        $display("\n--- Test 1: Paper Filter Sensor ---");
        
        sw_paper_filter = 0;
        wait_debounce();
        check_paper_sensor(1'b0);
        
        sw_paper_filter = 1;
        wait_debounce();
        check_paper_sensor(1'b1);
        
        sw_paper_filter = 0;
        wait_debounce();
        check_paper_sensor(1'b0);
        
        //--------------------------------------------------------------------
        // Test 2: Coffee Bin 0 - Fill Control
        //--------------------------------------------------------------------
        $display("\n--- Test 2: Coffee Bin 0 Fill Control ---");
        
        sw_coffee_bin0 = 2'b01;  // Fill switch
        wait_debounce();
        check_level("Bin0", coffee_bin0_level, 8'd255);
        
        sw_coffee_bin0 = 2'b00;  // Release
        wait_debounce();
        check_level("Bin0", coffee_bin0_level, 8'd255);  // Should stay full
        
        //--------------------------------------------------------------------
        // Test 3: Coffee Bin 0 - Empty Control
        //--------------------------------------------------------------------
        $display("\n--- Test 3: Coffee Bin 0 Empty Control ---");
        
        sw_coffee_bin0 = 2'b10;  // Empty switch
        wait_debounce();
        check_level("Bin0", coffee_bin0_level, 8'd0);
        
        sw_coffee_bin0 = 2'b00;  // Release
        wait_debounce();
        check_level("Bin0", coffee_bin0_level, 8'd0);  // Should stay empty
        
        //--------------------------------------------------------------------
        // Test 4: Coffee Bin 1 - Fill and Empty
        //--------------------------------------------------------------------
        $display("\n--- Test 4: Coffee Bin 1 Control ---");
        
        sw_coffee_bin1 = 2'b01;  // Fill
        wait_debounce();
        check_level("Bin1", coffee_bin1_level, 8'd255);
        
        sw_coffee_bin1 = 2'b10;  // Empty
        wait_debounce();
        check_level("Bin1", coffee_bin1_level, 8'd0);
        
        //--------------------------------------------------------------------
        // Test 5: Creamer Control
        //--------------------------------------------------------------------
        $display("\n--- Test 5: Creamer Control ---");
        
        sw_creamer = 2'b01;  // Fill
        wait_debounce();
        check_level("Creamer", creamer_level, 8'd255);
        
        sw_creamer = 2'b10;  // Empty
        wait_debounce();
        check_level("Creamer", creamer_level, 8'd0);
        
        //--------------------------------------------------------------------
        // Test 6: Chocolate Control
        //--------------------------------------------------------------------
        $display("\n--- Test 6: Chocolate Control ---");
        
        sw_chocolate = 2'b01;  // Fill
        wait_debounce();
        check_level("Chocolate", chocolate_level, 8'd255);
        
        sw_chocolate = 2'b10;  // Empty
        wait_debounce();
        check_level("Chocolate", chocolate_level, 8'd0);
        
        //--------------------------------------------------------------------
        // Test 7: LED Status Indicators
        //--------------------------------------------------------------------
        $display("\n--- Test 7: LED Status Indicators ---");
        
        // Fill all consumables
        sw_coffee_bin0 = 2'b01;
        sw_coffee_bin1 = 2'b01;
        sw_creamer = 2'b01;
        sw_chocolate = 2'b01;
        wait_debounce();
        
        $display("[%0t] Checking LED states (all full - LEDs should be OFF)", $time);
        if (led_coffee_bin0 == 0 && led_coffee_bin1 == 0 && 
            led_creamer == 0 && led_chocolate == 0) begin
            $display("[%0t] PASS: All LEDs OFF when full", $time);
        end else begin
            $display("[%0t] ERROR: LEDs not in expected state", $time);
        end
        
        // Empty all consumables
        sw_coffee_bin0 = 2'b10;
        sw_coffee_bin1 = 2'b10;
        sw_creamer = 2'b10;
        sw_chocolate = 2'b10;
        wait_debounce();
        
        $display("[%0t] Checking LED states (all empty - LEDs should be ON)", $time);
        // Note: Need to wait a bit for LED logic to update
        repeat(100) @(posedge clk);
        if (led_coffee_bin0 == 1 && led_coffee_bin1 == 1 && 
            led_creamer == 1 && led_chocolate == 1) begin
            $display("[%0t] PASS: All LEDs ON when empty", $time);
        end else begin
            $display("[%0t] ERROR: LEDs not in expected state", $time);
        end
        
        //--------------------------------------------------------------------
        // Test 8: Water Pressure Override
        //--------------------------------------------------------------------
        $display("\n--- Test 8: Water Pressure Override ---");
        
        sw_water_pressure_ovr = 0;
        wait_debounce();
        if (water_pressure_ok == 1) begin
            $display("[%0t] PASS: Pressure OK when override off", $time);
        end else begin
            $display("[%0t] ERROR: Pressure should be OK", $time);
        end
        
        sw_water_pressure_ovr = 1;
        wait_debounce();
        if (water_pressure_ok == 0) begin
            $display("[%0t] PASS: Pressure NOT OK when override on", $time);
        end else begin
            $display("[%0t] ERROR: Pressure should be NOT OK", $time);
        end
        
        //--------------------------------------------------------------------
        // Test 9: Water Temperature Override
        //--------------------------------------------------------------------
        $display("\n--- Test 9: Water Temperature Override ---");
        
        sw_water_temp_ovr = 0;
        wait_debounce();
        if (water_temp_ready == 1) begin
            $display("[%0t] PASS: Temp ready when override off", $time);
        end else begin
            $display("[%0t] ERROR: Temp should be ready", $time);
        end
        
        sw_water_temp_ovr = 1;
        wait_debounce();
        if (water_temp_ready == 0) begin
            $display("[%0t] PASS: Temp NOT ready when override on", $time);
        end else begin
            $display("[%0t] ERROR: Temp should be NOT ready", $time);
        end
        
        //--------------------------------------------------------------------
        // Test 10: System Error
        //--------------------------------------------------------------------
        $display("\n--- Test 10: System Error ---");
        
        sw_system_error = 0;
        wait_debounce();
        if (system_fault == 0) begin
            $display("[%0t] PASS: No system fault", $time);
        end else begin
            $display("[%0t] ERROR: System fault should be clear", $time);
        end
        
        sw_system_error = 1;
        wait_debounce();
        if (system_fault == 1) begin
            $display("[%0t] PASS: System fault detected", $time);
        end else begin
            $display("[%0t] ERROR: System fault should be set", $time);
        end
        
        //--------------------------------------------------------------------
        // Test 11: Debounce Verification (Glitch Rejection)
        //--------------------------------------------------------------------
        $display("\n--- Test 11: Debounce Glitch Rejection ---");
        
        sw_paper_filter = 0;
        wait_debounce();
        
        // Create short glitch (< 20ms)
        sw_paper_filter = 1;
        #1_000_000;  // 1ms glitch
        sw_paper_filter = 0;
        
        // Wait and check - should still be 0
        #25_000_000;
        if (paper_filter_present == 0) begin
            $display("[%0t] PASS: Glitch rejected by debounce", $time);
        end else begin
            $display("[%0t] ERROR: Glitch should have been rejected", $time);
        end
        
        //--------------------------------------------------------------------
        // Test Complete
        //--------------------------------------------------------------------
        $display("\n========================================");
        $display("Sensor Interface Unit Test Complete!");
        $display("========================================");
        
        #10_000;
        $finish;
    end
    
    //========================================================================
    // Waveform Dump
    //========================================================================
    initial begin
        $dumpfile("sensor_interface_tb.vcd");
        $dumpvars(0, sensor_interface_tb);
    end

endmodule