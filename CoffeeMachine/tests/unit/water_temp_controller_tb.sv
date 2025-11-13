//============================================================================
// Module: water_temp_controller_tb
// Description: Unit test for water_temp_controller module
//              Tests autonomous temperature control and safety interlocks
// Author: Gabriel DiMartino
// Date: November 2025
//============================================================================

`timescale 1ns/1ps

module water_temp_controller_tb;

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
    
    // Sensor inputs
    logic water_pressure_ok;
    logic water_temp_override;
    logic pressure_override;
    
    // Control inputs
    logic       heating_enable;
    logic       brewing_active;
    logic [1:0] target_temp_mode;
    
    // Outputs
    logic       heater_enable;
    logic       temp_ready;
    logic       pressure_ready;
    logic       water_system_ok;
    logic [7:0] current_temp;
    logic [7:0] target_temp;
    
    //========================================================================
    // DUT Instantiation
    //========================================================================
    water_temp_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .water_pressure_ok(water_pressure_ok),
        .water_temp_override(water_temp_override),
        .pressure_override(pressure_override),
        .heating_enable(heating_enable),
        .brewing_active(brewing_active),
        .target_temp_mode(target_temp_mode),
        .heater_enable(heater_enable),
        .temp_ready(temp_ready),
        .pressure_ready(pressure_ready),
        .water_system_ok(water_system_ok),
        .current_temp(current_temp),
        .target_temp(target_temp)
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
        $display("Water Temperature Controller Test Complete!");
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
            water_pressure_ok = 1;
            water_temp_override = 0;
            pressure_override = 0;
            heating_enable = 0;
            brewing_active = 0;
            target_temp_mode = 2'b00;  // Standby
            
            repeat(10) @(posedge clk);
            rst_n = 1;
            repeat(5) @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask
    
    task wait_for_temp_ready(input int timeout_cycles);
        automatic int count;
        begin
            count = 0;
            while (!temp_ready && count < timeout_cycles) begin
                @(posedge clk);
                count++;
            end
            if (temp_ready) begin
                $display("[%0t] Temperature ready reached (temp=%0d)", $time, current_temp);
            end else begin
                $display("[%0t] WARNING: Timeout waiting for temp_ready", $time);
            end
        end
    endtask
    
    task check_temp_in_range(input [7:0] target, input [7:0] tolerance);
        begin
            if (current_temp >= (target - tolerance) && current_temp <= (target + tolerance)) begin
                $display("[%0t] PASS: Temperature in range [%0d ±%0d], current=%0d", 
                         $time, target, tolerance, current_temp);
            end else begin
                $display("[%0t] ERROR: Temperature out of range! Target=%0d, Current=%0d", 
                         $time, target, current_temp);
            end
        end
    endtask
    
    //========================================================================
    // Main Test Sequence
    //========================================================================
    initial begin
        $display("========================================");
        $display("Water Temperature Controller Unit Test");
        $display("========================================");
        
        reset_dut();
        
        //--------------------------------------------------------------------
        // Test 1: Initial State (Cold)
        //--------------------------------------------------------------------
        $display("\n--- Test 1: Initial State ---");
        $display("[%0t] Current temp: %0d", $time, current_temp);
        $display("[%0t] Heater enable: %b", $time, heater_enable);
        $display("[%0t] Temp ready: %b", $time, temp_ready);
        
        if (current_temp == 8'd25) begin  // Room temperature
            $display("[%0t] PASS: Starts at room temperature", $time);
        end
        
        if (!temp_ready) begin
            $display("[%0t] PASS: Not ready when cold", $time);
        end
        
        //--------------------------------------------------------------------
        // Test 2: Heating to Standby Temperature
        //--------------------------------------------------------------------
        $display("\n--- Test 2: Heat to Standby (150) ---");
        
        target_temp_mode = 2'b00;  // Standby
        heating_enable = 1;
        
        $display("[%0t] Enabling heater, target mode: STANDBY", $time);
        repeat(10) @(posedge clk);
        
        if (heater_enable) begin
            $display("[%0t] PASS: Heater turned on", $time);
        end
        
        // Wait for temperature to rise
        wait_for_temp_ready(20_000_000);  // Wait up to 400ms
        
        check_temp_in_range(8'd150, 8'd5);
        
        //--------------------------------------------------------------------
        // Test 3: Change to Brewing Temperature
        //--------------------------------------------------------------------
        $display("\n--- Test 3: Heat to Brewing (200) ---");
        
        target_temp_mode = 2'b01;  // Brewing
        
        $display("[%0t] Changing target to BREWING", $time);
        
        // Wait for new temperature
        wait_for_temp_ready(10_000_000);  // Wait up to 200ms
        
        check_temp_in_range(8'd200, 8'd5);
        
        //--------------------------------------------------------------------
        // Test 4: Extra Hot Mode
        //--------------------------------------------------------------------
        $display("\n--- Test 4: Heat to Extra Hot (230) ---");
        
        target_temp_mode = 2'b10;  // Extra hot
        
        $display("[%0t] Changing target to EXTRA HOT", $time);
        
        // Wait for new temperature
        wait_for_temp_ready(10_000_000);
        
        check_temp_in_range(8'd230, 8'd5);
        
        //--------------------------------------------------------------------
        // Test 5: Cooling Down
        //--------------------------------------------------------------------
        $display("\n--- Test 5: Cooling Down ---");
        
        heating_enable = 0;
        
        $display("[%0t] Disabling heater", $time);
        repeat(10) @(posedge clk);
        
        if (!heater_enable) begin
            $display("[%0t] PASS: Heater turned off", $time);
        end
        
        // Wait and observe temperature decrease
        $display("[%0t] Starting temp: %0d", $time, current_temp);
        #50_000_000;  // Wait 50ms
        $display("[%0t] After 50ms: %0d", $time, current_temp);
        
        if (current_temp < 8'd230) begin
            $display("[%0t] PASS: Temperature is cooling", $time);
        end
        
        //--------------------------------------------------------------------
        // Test 6: Temperature Override
        //--------------------------------------------------------------------
        $display("\n--- Test 6: Temperature Override ---");
        
        heating_enable = 1;
        target_temp_mode = 2'b01;  // Brewing
        
        // Wait to heat up first
        wait_for_temp_ready(20_000_000);
        
        $display("[%0t] Temp before override: %0d, ready: %b", $time, current_temp, temp_ready);
        
        // Activate override
        water_temp_override = 1;
        repeat(100) @(posedge clk);
        
        $display("[%0t] Temp after override: %0d, ready: %b", $time, current_temp, temp_ready);
        
        if (current_temp == 8'd25) begin
            $display("[%0t] PASS: Override forces cold temperature", $time);
        end
        
        if (!temp_ready) begin
            $display("[%0t] PASS: Override forces NOT ready", $time);
        end
        
        // Clear override
        water_temp_override = 0;
        
        //--------------------------------------------------------------------
        // Test 7: Pressure Monitoring
        //--------------------------------------------------------------------
        $display("\n--- Test 7: Pressure Monitoring ---");
        
        pressure_override = 0;
        repeat(10) @(posedge clk);
        
        if (pressure_ready) begin
            $display("[%0t] PASS: Pressure OK by default", $time);
        end
        
        // Activate pressure override
        pressure_override = 1;
        repeat(100) @(posedge clk);
        
        if (!pressure_ready) begin
            $display("[%0t] PASS: Pressure override forces error", $time);
        end
        
        if (!water_system_ok) begin
            $display("[%0t] PASS: Water system reports NOT OK", $time);
        end
        
        // Clear override
        pressure_override = 0;
        
        //--------------------------------------------------------------------
        // Test 8: Water System OK Flag
        //--------------------------------------------------------------------
        $display("\n--- Test 8: Water System OK ---");
        
        // Clear all overrides
        water_temp_override = 0;
        pressure_override = 0;
        heating_enable = 1;
        target_temp_mode = 2'b01;  // Brewing
        
        // Wait for system to be ready
        wait_for_temp_ready(20_000_000);
        repeat(1000) @(posedge clk);
        
        if (temp_ready && pressure_ready && water_system_ok) begin
            $display("[%0t] PASS: Water system fully OK", $time);
        end else begin
            $display("[%0t] ERROR: Water system not OK (temp_ready=%b, pressure_ready=%b, system_ok=%b)", 
                     $time, temp_ready, pressure_ready, water_system_ok);
        end
        
        //--------------------------------------------------------------------
        // Test 9: Temperature Hysteresis
        //--------------------------------------------------------------------
        $display("\n--- Test 9: Temperature Hysteresis ---");
        
        begin
            // System should maintain temperature without excessive cycling
            automatic int heater_toggles;
            automatic logic prev_heater;
            
            heater_toggles = 0;
            prev_heater = heater_enable;
            
            repeat(50000) begin
                @(posedge clk);
                if (heater_enable != prev_heater) begin
                    heater_toggles++;
                    prev_heater = heater_enable;
                end
            end
            
            $display("[%0t] Heater toggles in 1ms: %0d", $time, heater_toggles);
            
            if (heater_toggles < 10) begin
                $display("[%0t] PASS: Hysteresis working (low toggle count)", $time);
            end else begin
                $display("[%0t] WARNING: High heater toggle count (possible oscillation)", $time);
            end
        end
        
        //--------------------------------------------------------------------
        // Test 10: Multiple Mode Changes
        //--------------------------------------------------------------------
        $display("\n--- Test 10: Multiple Mode Changes ---");
        
        // Cycle through modes
        target_temp_mode = 2'b00;  // Standby
        wait_for_temp_ready(10_000_000);
        $display("[%0t] Standby mode: temp=%0d", $time, current_temp);
        
        target_temp_mode = 2'b01;  // Brewing
        wait_for_temp_ready(10_000_000);
        $display("[%0t] Brewing mode: temp=%0d", $time, current_temp);
        
        target_temp_mode = 2'b10;  // Extra hot
        wait_for_temp_ready(10_000_000);
        $display("[%0t] Extra hot mode: temp=%0d", $time, current_temp);
        
        target_temp_mode = 2'b00;  // Back to standby
        #20_000_000;
        $display("[%0t] Back to standby: temp=%0d", $time, current_temp);
        
        //--------------------------------------------------------------------
        // Test Complete
        //--------------------------------------------------------------------
        $display("\n========================================");
        $display("Water Temperature Controller Test Complete!");
        $display("========================================");
        
        #10_000;
        $finish;
    end
    
    //========================================================================
    // Temperature Monitor (Continuous Display)
    //========================================================================
    initial begin
        // Display temperature every 10ms
        forever begin
            #10_000_000;
            $display("[%0t] Temp=%0d, Target=%0d, Heater=%b, Ready=%b", 
                     $time, current_temp, target_temp, heater_enable, temp_ready);
        end
    end
    
    //========================================================================
    // Waveform Dump
    //========================================================================
    initial begin
        $dumpfile("water_temp_controller_tb.vcd");
        $dumpvars(0, water_temp_controller_tb);
    end

endmodule