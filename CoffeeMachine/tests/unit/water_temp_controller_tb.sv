//============================================================================
// Module: water_temp_controller_tb
// Description: Unit test for water temperature controller
//              Specifically tests the override functionality fix
// Author: Gabriel DiMartino (Generated for debugging)
// Date: November 2025
//============================================================================

`timescale 1ns/1ps

module water_temp_controller_tb;
    parameter CLK_PERIOD = 20;  // 50MHz
    
    // DUT signals
    logic clk, rst_n;
    logic heating_enable;
    logic brewing_active;
    logic [1:0] target_temp_mode;
    logic water_temp_override;
    logic water_pressure_ok;
    logic pressure_override;
    
    logic heater_enable;
    logic temp_ready;
    logic pressure_ready;
    logic water_system_ok;
    logic [7:0] current_temp;
    logic [7:0] target_temp;
    logic overheat_error;
    
    // Instantiate DUT with FAST parameters for testing
    water_temp_controller #(
        .HEATING_CYCLE_TIME(100),         // Update every 2us
        .PRESSURE_CHECK_TIME(50_000),     // Check every 1ms
        .TEMP_COLD(8'd25),
        .TEMP_STANDBY(8'd80),
        .TEMP_BREWING(8'd100),
        .TEMP_EXTRA_HOT(8'd120),
        .HEAT_RATE(8'd5),                 // Heat 5x faster
        .COOL_RATE(8'd2),                 // Cool 2x faster
        .HEAT_UPDATE_DIV(16'd10),         // Update every 10 cycles instead of 86
        .COOL_UPDATE_DIV(16'd1000)        // Much faster cooling for testing
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .heating_enable(heating_enable),
        .brewing_active(brewing_active),
        .target_temp_mode(target_temp_mode),
        .water_temp_override(water_temp_override),
        .water_pressure_ok(water_pressure_ok),
        .pressure_override(pressure_override),
        .heater_enable(heater_enable),
        .temp_ready(temp_ready),
        .pressure_ready(pressure_ready),
        .water_system_ok(water_system_ok),
        .current_temp(current_temp),
        .target_temp(target_temp),
        .overheat_error(overheat_error)
    );
    
    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Test sequence
    initial begin
        $display("========================================");
        $display("Water Temperature Controller Unit Test");
        $display("Testing Override Functionality Fix");
        $display("========================================\n");
        
        // Initialize
        rst_n = 0;
        heating_enable = 0;
        brewing_active = 0;
        target_temp_mode = 2'b01;  // Brewing mode
        water_temp_override = 0;
        water_pressure_ok = 1;
        pressure_override = 0;
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        $display("[%0t] System reset complete", $time);
        $display("[%0t] Initial state: temp=%0d, temp_ready=%b, target=%0d\n", 
                 $time, current_temp, temp_ready, target_temp);
        
        //====================================================================
        // Test 1: Override ENABLED - Should instantly set temp_ready
        //====================================================================
        $display("--- Test 1: Override Enabled (Critical Fix) ---");
        
        water_temp_override = 1;  // ENABLE override (SW10=1)
        heating_enable = 1;
        
        repeat(100) @(posedge clk);  // Wait 2us
        
        $display("[%0t] Override enabled", $time);
        $display("  current_temp = %0d (should be %0d = target)", current_temp, target_temp);
        $display("  temp_ready = %b (should be 1)", temp_ready);
        $display("  water_system_ok = %b (should be 1)", water_system_ok);
        $display("  heater_enable = %b", heater_enable);
        
        if (temp_ready === 1'b1) begin
            $display("  ✓ PASS: temp_ready asserted with override");
        end else begin
            $display("  ✗ FAIL: temp_ready NOT asserted with override");
        end
        
        if (current_temp == target_temp) begin
            $display("  ✓ PASS: current_temp set to target");
        end else begin
            $display("  ✗ FAIL: current_temp=%0d, expected=%0d", current_temp, target_temp);
        end
        
        if (water_system_ok === 1'b1) begin
            $display("  ✓ PASS: water_system_ok asserted");
        end else begin
            $display("  ✗ FAIL: water_system_ok NOT asserted");
        end
        
        //====================================================================
        // Test 2: Override DISABLED - Normal heating
        //====================================================================
        $display("\n--- Test 2: Override Disabled - Normal Heating ---");
        
        water_temp_override = 0;  // DISABLE override
        heating_enable = 0;
        repeat(100) @(posedge clk);
        
        // Should cool down to cold
        repeat(5000) @(posedge clk);  // Wait 100us
        
        $display("[%0t] Override disabled, system reset", $time);
        $display("  current_temp = %0d (should be ~25)", current_temp);
        $display("  temp_ready = %b (should be 0)", temp_ready);
        
        if (temp_ready === 1'b0) begin
            $display("  ✓ PASS: temp_ready cleared without override");
        end else begin
            $display("  ✗ FAIL: temp_ready still asserted");
        end
        
        // Now enable heating
        heating_enable = 1;
        
        $display("[%0t] Heating enabled, monitoring...", $time);
        
        // Wait for temperature to rise
        repeat(50000) begin
            @(posedge clk);
            if (current_temp >= (target_temp - 5)) break;
        end
        
        $display("[%0t] Heating progress:", $time);
        $display("  current_temp = %0d", current_temp);
        $display("  target_temp = %0d", target_temp);
        $display("  heater_enable = %b", heater_enable);
        
        // Wait for temp_ready
        repeat(50000) begin
            @(posedge clk);
            if (temp_ready) break;
        end
        
        if (temp_ready === 1'b1) begin
            $display("  ✓ PASS: temp_ready asserted after normal heating");
            $display("    Final temp: %0d", current_temp);
        end else begin
            $display("  ✗ FAIL: temp_ready not asserted after heating");
            $display("    Current temp: %0d, Target: %0d", current_temp, target_temp);
        end
        
        //====================================================================
        // Test 3: Pressure Override
        //====================================================================
        $display("\n--- Test 3: Pressure Override ---");
        
        pressure_override = 1;  // Force pressure error
        repeat(100000) @(posedge clk);  // Wait for pressure check (1ms)
        
        $display("[%0t] Pressure override enabled", $time);
        $display("  pressure_ready = %b (should be 0)", pressure_ready);
        $display("  water_system_ok = %b (should be 0)", water_system_ok);
        
        if (pressure_ready === 1'b0) begin
            $display("  ✓ PASS: pressure_ready cleared with override");
        end else begin
            $display("  ✗ FAIL: pressure_ready still asserted");
        end
        
        if (water_system_ok === 1'b0) begin
            $display("  ✓ PASS: water_system_ok cleared (no pressure)");
        end else begin
            $display("  ✗ FAIL: water_system_ok still asserted");
        end
        
        pressure_override = 0;
        repeat(100000) @(posedge clk);
        
        //====================================================================
        // Test 4: Override while heating
        //====================================================================
        $display("\n--- Test 4: Toggle Override During Operation ---");
        
        // Start with override off, system heating
        water_temp_override = 0;
        heating_enable = 1;
        target_temp_mode = 2'b01;
        
        repeat(1000) @(posedge clk);
        
        $display("[%0t] Before override: temp=%0d, ready=%b", 
                 $time, current_temp, temp_ready);
        
        // Enable override mid-operation
        water_temp_override = 1;
        repeat(100) @(posedge clk);
        
        $display("[%0t] After override enabled:", $time);
        $display("  temp_ready = %b (should be 1)", temp_ready);
        $display("  current_temp = %0d (should be %0d)", current_temp, target_temp);
        
        if (temp_ready === 1'b1 && current_temp == target_temp) begin
            $display("  ✓ PASS: Override takes effect immediately");
        end else begin
            $display("  ✗ FAIL: Override not working correctly");
        end
        
        //====================================================================
        // Summary
        //====================================================================
        $display("\n========================================");
        $display("Water Controller Unit Test Complete");
        $display("========================================");
        
        #1000;
        $finish;
    end
    
    // Monitor for debugging
    always @(posedge clk) begin
        if (water_temp_override && !temp_ready) begin
            $display("[%0t] ERROR: Override enabled but temp_ready=0!", $time);
        end
    end
    
    // VCD dump
    initial begin
        $dumpfile("water_temp_controller_tb.vcd");
        $dumpvars(0, water_temp_controller_tb);
    end
    
endmodule