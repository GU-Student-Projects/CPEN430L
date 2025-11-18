//============================================================================
// Error Handler Diagnostic - Why is critical_error HIGH?
//============================================================================

`timescale 1ns/1ps

module error_diagnostic;
    reg clk, rst_n;
    reg [17:0] switches;
    
    // Error handler outputs
    wire critical_error;
    wire error_present;
    wire [3:0] error_count;
    wire [3:0] warning_count;
    
    // Individual error flags
    wire err_no_water;
    wire err_no_paper;
    wire err_no_coffee;
    wire err_temp_fault;
    wire err_pressure_fault;
    wire err_system_fault;
    
    // Individual warning flags
    wire warn_paper_low;
    wire warn_bin0_low;
    wire warn_bin1_low;
    wire warn_creamer_low;
    wire warn_chocolate_low;
    wire warn_temp_heating;
    
    // Consumable status
    wire bin0_empty, bin1_empty, paper_empty;
    wire creamer_empty, chocolate_empty;
    wire temp_ready, pressure_ready, water_system_ok;
    wire can_make_coffee;
    
    coffee_machine_top dut (
        .CLOCK_50(clk),
        .KEY0(1'b1), .KEY1(1'b1), .KEY2(1'b1), .KEY3(1'b1),
        .SW0(switches[0]), .SW1(switches[1]), .SW2(switches[2]), .SW3(switches[3]),
        .SW4(switches[4]), .SW5(switches[5]), .SW6(switches[6]), .SW7(switches[7]),
        .SW8(switches[8]), .SW9(switches[9]), .SW10(switches[10]), .SW11(switches[11]),
        .SW12(switches[12]), .SW13(switches[13]), .SW14(switches[14]), .SW15(switches[15]),
        .SW16(switches[16]), .SW17(switches[17]),
        .LEDR0(), .LEDR1(), .LEDR2(), .LEDR3(), .LEDR4(), .LEDR5(), .LEDR6(), .LEDR7(),
        .LEDR8(), .LEDR9(), .LEDR10(), .LEDR11(), .LEDR12(), .LEDR13(), .LEDR14(), .LEDR15(),
        .LEDR16(), .LEDR17(),
        .LEDG0(), .LEDG1(), .LEDG2(), .LEDG3(), .LEDG4(), .LEDG5(), .LEDG6(), .LEDG7(), .LEDG8(),
        .LCD_ON(), .LCD_BLON(), .LCD_EN(), .LCD_RS(), .LCD_RW(), .LCD_DATA(),
        .HEX0(), .HEX1(), .HEX2(), .HEX3(), .HEX4(), .HEX5(), .HEX6(), .HEX7()
    );
    
    // Tap into error handler
    assign critical_error = dut.critical_error;
    assign error_present = dut.error_present;
    assign error_count = dut.error_count;
    assign warning_count = dut.warning_count;
    
    assign err_no_water = dut.err_no_water;
    assign err_no_paper = dut.err_no_paper;
    assign err_no_coffee = dut.err_no_coffee;
    assign err_temp_fault = dut.err_temp_fault;
    assign err_pressure_fault = dut.err_pressure_fault;
    assign err_system_fault = dut.err_system_fault;
    
    assign warn_paper_low = dut.warn_paper_low;
    assign warn_bin0_low = dut.warn_bin0_low;
    assign warn_bin1_low = dut.warn_bin1_low;
    assign warn_creamer_low = dut.warn_creamer_low;
    assign warn_chocolate_low = dut.warn_chocolate_low;
    assign warn_temp_heating = dut.warn_temp_heating;
    
    assign bin0_empty = dut.bin0_empty;
    assign bin1_empty = dut.bin1_empty;
    assign paper_empty = dut.paper_empty;
    assign creamer_empty = dut.creamer_empty;
    assign chocolate_empty = dut.chocolate_empty;
    
    assign temp_ready = dut.temp_ready;
    assign pressure_ready = dut.pressure_ready;
    assign water_system_ok = dut.water_system_ok;
    assign can_make_coffee = dut.can_make_coffee;
    
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    task test_config;
        input [17:0] sw;
        input string description;
        begin
            $display("\n========================================");
            $display("TEST: %s", description);
            $display("========================================");
            switches = sw;
            #1000;
            
            $display("\nSwitch Configuration:");
            $display("  SW[11:10] Pressure: %b%b", switches[11], switches[10]);
            $display("  SW[12] Temp Override: %b", switches[12]);
            $display("  SW[13] System Fault: %b", switches[13]);
            $display("  SW[9:8] Chocolate: %b%b", switches[9], switches[8]);
            $display("  SW[7:6] Creamer: %b%b", switches[7], switches[6]);
            $display("  SW[5:4] Bin1: %b%b", switches[5], switches[4]);
            $display("  SW[3:2] Bin0: %b%b", switches[3], switches[2]);
            $display("  SW[1:0] Paper: %b%b", switches[1], switches[0]);
            
            $display("\nConsumable Status:");
            $display("  bin0_empty: %b", bin0_empty);
            $display("  bin1_empty: %b", bin1_empty);
            $display("  paper_empty: %b", paper_empty);
            $display("  creamer_empty: %b", creamer_empty);
            $display("  chocolate_empty: %b", chocolate_empty);
            $display("  can_make_coffee: %b", can_make_coffee);
            
            $display("\nWater System:");
            $display("  temp_ready: %b", temp_ready);
            $display("  pressure_ready: %b", pressure_ready);
            $display("  water_system_ok: %b", water_system_ok);
            
            $display("\nERROR FLAGS:");
            $display("  err_no_water: %b", err_no_water);
            $display("  err_no_paper: %b", err_no_paper);
            $display("  err_no_coffee: %b", err_no_coffee);
            $display("  err_temp_fault: %b", err_temp_fault);
            $display("  err_pressure_fault: %b", err_pressure_fault);
            $display("  err_system_fault: %b", err_system_fault);
            
            $display("\nWARNING FLAGS:");
            $display("  warn_paper_low: %b", warn_paper_low);
            $display("  warn_bin0_low: %b", warn_bin0_low);
            $display("  warn_bin1_low: %b", warn_bin1_low);
            $display("  warn_creamer_low: %b", warn_creamer_low);
            $display("  warn_chocolate_low: %b", warn_chocolate_low);
            $display("  warn_temp_heating: %b", warn_temp_heating);
            
            $display("\nSUMMARY:");
            $display("  critical_error: %b ← THIS IS THE KEY", critical_error);
            $display("  error_present: %b", error_present);
            $display("  error_count: %0d", error_count);
            $display("  warning_count: %0d", warning_count);
            
            if (critical_error) begin
                $display("\n!!! CRITICAL ERROR DETECTED !!!");
                $display("Reason(s):");
                if (err_no_water) $display("  - No water / pressure fault");
                if (err_no_paper) $display("  - No paper");
                if (err_no_coffee) $display("  - No coffee");
                if (err_temp_fault) $display("  - Temperature fault");
                if (err_pressure_fault) $display("  - Pressure fault");
                if (err_system_fault) $display("  - System fault flag set");
            end else begin
                $display("\n✓ No critical errors - system can brew");
            end
        end
    endtask
    
    initial begin
        $display("\n=== ERROR HANDLER DIAGNOSTIC ===\n");
        
        rst_n = 1;
        switches = 18'h0;
        
        // Reset
        switches[17] = 1;
        #100;
        switches[17] = 0;
        #100;
        
        // Test 1: Your original config (pressure = 11)
        test_config(18'b0_00_0_11_11_11_11_11_11, "Original (pressure=11)");
        
        // Test 2: Pressure = 10
        test_config(18'b0_00_0_10_11_11_11_11_11, "Pressure=10");
        
        // Test 3: Pressure = 01
        test_config(18'b0_00_0_01_11_11_11_11_11, "Pressure=01");
        
        // Test 4: Pressure = 00
        test_config(18'b0_00_0_00_11_11_11_11_11, "Pressure=00");
        
        // Test 5: With temp override
        test_config(18'b0_01_0_10_11_11_11_11_11, "Pressure=10 + Temp Override");
        
        $display("\n\n=== RECOMMENDATION ===");
        $display("Use the configuration that shows:");
        $display("  - critical_error = 0");
        $display("  - water_system_ok = 1");
        $display("  - can_make_coffee = 1");
        $display("\nThat configuration will allow the FSM to exit ERROR_CYCLE!\n");
        
        $finish;
    end
endmodule