//============================================================================
// Module: actuator_control_tb
// Description: Unit test for actuator_control module
// Author: Gabriel DiMartino
// FIXED: Sized large time literals as 64-bit
//============================================================================

`timescale 1ns/1ps

module actuator_control_tb;
    parameter CLK_PERIOD = 20;
    parameter SIM_TIME = 64'd400_000_000;  // FIX: Size as 64-bit
    
    logic clk, rst_n;
    logic grinder0_cmd, grinder1_cmd, water_pour_cmd, water_direct_cmd, paper_motor_cmd;
    logic heater_cmd, temp_ready, pressure_ready, water_system_ok;
    logic system_fault, paper_filter_present, brewing_active, emergency_stop;
    logic led_heater, led_water_pour, led_water_direct, led_grinder0, led_grinder1, led_paper_motor;
    logic actuators_active;
    logic [5:0] active_count;
    
    actuator_control dut (.*);
    
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    initial begin
        #SIM_TIME;
        $display("Actuator Control Test Complete!");
        $finish;
    end
    
    initial begin
        $display("========================================");
        $display("Actuator Control Unit Test");
        $display("========================================");
        
        rst_n = 0;
        grinder0_cmd = 0; grinder1_cmd = 0;
        water_pour_cmd = 0; water_direct_cmd = 0;
        paper_motor_cmd = 0; heater_cmd = 0;
        temp_ready = 1; pressure_ready = 1;
        water_system_ok = 1;
        system_fault = 0; paper_filter_present = 1;
        brewing_active = 0; emergency_stop = 0;
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("\n--- Test 1: Heater Control ---");
        heater_cmd = 1;
        repeat(100) @(posedge clk);
        if (led_heater) $display("PASS: Heater enabled");
        heater_cmd = 0;
        repeat(100) @(posedge clk);
        
        $display("\n--- Test 2: Grinder Control ---");
        grinder0_cmd = 1;
        repeat(100) @(posedge clk);
        if (led_grinder0) $display("PASS: Grinder 0 enabled");
        grinder0_cmd = 0;
        
        $display("\n--- Test 3: Water Pour with Safety Interlock ---");
        temp_ready = 0;
        water_pour_cmd = 1;
        repeat(100) @(posedge clk);
        if (!led_water_pour) $display("PASS: Water blocked without temp ready");
        
        temp_ready = 1;
        repeat(100) @(posedge clk);
        if (led_water_pour) $display("PASS: Water enabled with temp ready");
        water_pour_cmd = 0;
        
        $display("\n--- Test 4: Emergency Stop ---");
        grinder0_cmd = 1;
        heater_cmd = 1;
        repeat(100) @(posedge clk);
        
        emergency_stop = 1;
        repeat(100) @(posedge clk);
        if (!led_grinder0 && !led_heater) 
            $display("PASS: Emergency stop disabled all actuators");
        emergency_stop = 0;
        
        $display("\n--- Test 5: Timeout Protection ---");
        grinder0_cmd = 1;
        $display("Running grinder for 5+ seconds...");
        repeat(51) #100_000_000;  // 51 * 100ms = 5.1 seconds
        if (!led_grinder0)
            $display("PASS: Grinder timeout protection worked");
        
        $display("\nActuator Control Test Complete!");
        #10_000;
        $finish;
    end
    
    initial begin
        $dumpfile("actuator_control_tb.vcd");
        $dumpvars(0, actuator_control_tb);
    end
endmodule