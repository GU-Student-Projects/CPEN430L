//============================================================================
// Module: message_manager_tb
// Description: Unit test for message_manager module
//              Tests LCD message generation for all menu states
// Author: Gabriel DiMartino
// Date: November 2025
//============================================================================

`timescale 1ns/1ps

module message_manager_tb;

    parameter CLK_PERIOD = 20;
    parameter SIM_TIME = 50_000_000;
    
    logic clk, rst_n;
    logic [3:0] current_menu_state;
    logic [2:0] selected_coffee_type, selected_drink_type;
    logic [1:0] selected_size;
    logic [7:0] brew_progress;
    logic [3:0] warning_count;
    logic error_present;
    logic bin0_empty, bin0_low, bin1_empty, bin1_low;
    logic creamer_empty, creamer_low, chocolate_empty, chocolate_low;
    logic paper_empty, paper_low;
    logic temp_ready, pressure_ready;
    logic [127:0] line1_text, line2_text;
    logic message_updated;
    
    message_manager dut (.*);
    
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    initial begin
        #SIM_TIME;
        $display("Message Manager Test Complete!");
        $finish;
    end
    
    function [8*16-1:0] decode_line;
        input [127:0] line;
        integer i;
        begin
            for (i = 0; i < 16; i++) begin
                decode_line[8*i +: 8] = line[8*i +: 8];
            end
        end
    endfunction
    
    initial begin
        $display("========================================");
        $display("Message Manager Unit Test");
        $display("========================================");
        
        // Reset
        rst_n = 0;
        current_menu_state = 0;
        selected_coffee_type = 0;
        selected_drink_type = 0;
        selected_size = 1;
        brew_progress = 0;
        warning_count = 0;
        error_present = 0;
        bin0_empty = 0; bin0_low = 0;
        bin1_empty = 0; bin1_low = 0;
        creamer_empty = 0; creamer_low = 0;
        chocolate_empty = 0; chocolate_low = 0;
        paper_empty = 0; paper_low = 0;
        temp_ready = 1; pressure_ready = 1;
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test all menu states
        $display("\n--- Testing SPLASH ---");
        current_menu_state = 0;
        repeat(10) @(posedge clk);
        $display("Line 1: %s", decode_line(line1_text));
        $display("Line 2: %s", decode_line(line2_text));
        
        $display("\n--- Testing COFFEE_SELECT ---");
        current_menu_state = 2;
        selected_coffee_type = 0;
        repeat(10) @(posedge clk);
        $display("Line 1: %s", decode_line(line1_text));
        $display("Line 2: %s", decode_line(line2_text));
        
        $display("\n--- Testing DRINK_SELECT ---");
        current_menu_state = 3;
        selected_drink_type = 3;  // Mocha
        repeat(10) @(posedge clk);
        $display("Line 1: %s", decode_line(line1_text));
        $display("Line 2: %s", decode_line(line2_text));
        
        $display("\n--- Testing SIZE_SELECT ---");
        current_menu_state = 4;
        selected_size = 2;  // 16oz
        repeat(10) @(posedge clk);
        $display("Line 1: %s", decode_line(line1_text));
        $display("Line 2: %s", decode_line(line2_text));
        
        $display("\n--- Testing BREWING ---");
        current_menu_state = 6;
        brew_progress = 50;
        repeat(10) @(posedge clk);
        $display("Line 1: %s", decode_line(line1_text));
        $display("Line 2: %s", decode_line(line2_text));
        
        $display("\n--- Testing COMPLETE ---");
        current_menu_state = 7;
        repeat(10) @(posedge clk);
        $display("Line 1: %s", decode_line(line1_text));
        $display("Line 2: %s", decode_line(line2_text));
        
        $display("\n--- Testing ERROR (No Paper) ---");
        current_menu_state = 9;
        paper_empty = 1;
        repeat(10) @(posedge clk);
        $display("Line 1: %s", decode_line(line1_text));
        $display("Line 2: %s", decode_line(line2_text));
        
        $display("\nMessage Manager Test Complete!");
        #10_000;
        $finish;
    end
    
    initial begin
        $dumpfile("message_manager_tb.vcd");
        $dumpvars(0, message_manager_tb);
    end

endmodule