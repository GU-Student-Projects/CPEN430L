//============================================================================
// Module: error_handler_tb
// Description: Unit test for error_handler module
//============================================================================

module error_handler_tb;
    parameter CLK_PERIOD = 20;
    parameter SIM_TIME = 200_000_000;
    
    logic clk, rst_n;
    logic bin0_empty, bin0_low, bin1_empty, bin1_low;
    logic creamer_empty, creamer_low, chocolate_empty, chocolate_low;
    logic paper_empty, paper_low;
    logic temp_ready, pressure_ready, water_system_ok;
    logic system_fault_flag, actuator_timeout, recipe_valid, can_make_coffee;
    logic critical_error, error_present;
    logic [3:0] warning_count, error_count;
    logic err_no_water, err_no_paper, err_no_coffee, err_temp_fault, err_pressure_fault, err_system_fault;
    logic warn_paper_low, warn_bin0_low, warn_bin1_low, warn_creamer_low, warn_chocolate_low, warn_temp_heating;
    
    error_handler dut (.*);
    
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    initial begin
        #SIM_TIME;
        $display("Error Handler Test Complete!");
        $finish;
    end
    
    initial begin
        $display("========================================");
        $display("Error Handler Unit Test");
        $display("========================================");
        
        rst_n = 0;
        bin0_empty = 0; bin0_low = 0; bin1_empty = 0; bin1_low = 0;
        creamer_empty = 0; creamer_low = 0; chocolate_empty = 0; chocolate_low = 0;
        paper_empty = 0; paper_low = 0;
        temp_ready = 1; pressure_ready = 1; water_system_ok = 1;
        system_fault_flag = 0; actuator_timeout = 0;
        recipe_valid = 1; can_make_coffee = 1;
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("\n--- Test 1: No Errors Initially ---");
        if (!critical_error && !error_present)
            $display("PASS: No errors on startup");
        
        $display("\n--- Test 2: Paper Empty Error ---");
        paper_empty = 1;
        #55_000_000;  // Wait for debounce
        if (err_no_paper && critical_error)
            $display("PASS: Paper empty detected as critical");
        paper_empty = 0;
        #55_000_000;
        
        $display("\n--- Test 3: Both Coffee Bins Empty ---");
        can_make_coffee = 0;
        #55_000_000;
        if (err_no_coffee && critical_error)
            $display("PASS: No coffee detected as critical");
        can_make_coffee = 1;
        #55_000_000;
        
        $display("\n--- Test 4: Low Level Warnings ---");
        bin0_low = 1;
        creamer_low = 1;
        repeat(100) @(posedge clk);
        $display("Warning count: %0d", warning_count);
        if (warning_count >= 2)
            $display("PASS: Warnings counted correctly");
        
        $display("\n--- Test 5: Water System Fault ---");
        water_system_ok = 0;
        #55_000_000;
        if (err_no_water && critical_error)
            $display("PASS: Water fault detected");
        
        $display("\nError Handler Test Complete!");
        #10_000;
        $finish;
    end
    
    initial begin
        $dumpfile("error_handler_tb.vcd");
        $dumpvars(0, error_handler_tb);
    end
endmodule