//============================================================================
// Module: service_timer
// Description: Tracks time since last service/manual check with persistence
//              Timer persists through power cycles and only resets on manual check
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module service_timer (
    input  wire         clk,
    input  wire         rst_n,
    
    // Control inputs
    input  wire         manual_check_clear,     // Clear timer on manual check
    input  wire         timer_enable,           // Enable timer counting
    
    // Outputs
    output reg [31:0]   seconds_since_service,  // Time in seconds since last service
    output reg [31:0]   minutes_since_service,  // Time in minutes since last service
    output reg [31:0]   hours_since_service,    // Time in hours since last service
    output reg [31:0]   days_since_service      // Time in days since last service
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Clock frequency: 50MHz
    parameter CLOCK_FREQ = 50_000_000;
    
    // Counter values
    parameter SECOND_CYCLES = CLOCK_FREQ;
    parameter SECONDS_PER_MINUTE = 60;
    parameter MINUTES_PER_HOUR = 60;
    parameter HOURS_PER_DAY = 24;
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    reg [31:0] cycle_counter;       // Counts clock cycles for 1 second
    reg [31:0] second_counter;      // Total seconds elapsed
    
    // Flag to detect manual check request
    reg manual_check_prev;
    wire manual_check_pulse;
    
    //========================================================================
    // Edge Detection for Manual Check
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            manual_check_prev <= 1'b0;
        end else begin
            manual_check_prev <= manual_check_clear;
        end
    end
    
    assign manual_check_pulse = manual_check_clear && !manual_check_prev;
    
    //========================================================================
    // Cycle Counter (generates 1Hz tick)
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 0;
        end else begin
            if (manual_check_pulse) begin
                // Reset on manual check
                cycle_counter <= 0;
            end else if (timer_enable) begin
                if (cycle_counter >= SECOND_CYCLES - 1) begin
                    cycle_counter <= 0;
                end else begin
                    cycle_counter <= cycle_counter + 1;
                end
            end
            // else hold value when disabled
        end
    end
    
    //========================================================================
    // Second Counter (tracks total seconds)
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            second_counter <= 0;
        end else begin
            if (manual_check_pulse) begin
                // Reset on manual check
                second_counter <= 0;
            end else if (timer_enable && (cycle_counter == SECOND_CYCLES - 1)) begin
                // Increment every second
                second_counter <= second_counter + 1;
            end
        end
    end
    
    //========================================================================
    // Time Conversion (seconds to various units)
    //========================================================================
    
    always @(*) begin
        // Calculate time components
        seconds_since_service = second_counter;
        minutes_since_service = second_counter / SECONDS_PER_MINUTE;
        hours_since_service = minutes_since_service / MINUTES_PER_HOUR;
        days_since_service = hours_since_service / HOURS_PER_DAY;
    end
    
    //========================================================================
    // Debug/Monitoring (synthesis off)
    //========================================================================
    
    // synthesis translate_off
    // always @(posedge clk) begin
    //     if (manual_check_pulse) begin
    //         $display("[%0t] Service Timer: RESET - Manual check performed", $time);
    //     end
        
    //     // Log every hour
    //     if (timer_enable && (cycle_counter == SECOND_CYCLES - 1)) begin
    //         if (second_counter % 3600 == 0 && second_counter > 0) begin
    //             $display("[%0t] Service Timer: %0d hours since last service", 
    //                      $time, hours_since_service);
    //         end
    //     end
    // end
    // synthesis translate_on

endmodule