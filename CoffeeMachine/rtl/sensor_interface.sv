//============================================================================
// Module: sensor_interface
// Description: Sensor interface with 2-bit level encoding
//              Converts switch positions to consumable levels (0-255)
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module sensor_interface (
    input  wire         clk,
    input  wire         rst_n,
    
    //========================================================================
    // Switch Inputs (DE2-115 SW[17:0])
    //========================================================================
    // Paper Filter Level [1:0]
    input  wire         SW0,
    input  wire         SW1,
    
    // Coffee Bin 0 Level [1:0]
    input  wire         SW2,
    input  wire         SW3,
    
    // Coffee Bin 1 Level [1:0]
    input  wire         SW4,
    input  wire         SW5,
    
    // Creamer Level [1:0]
    input  wire         SW6,
    input  wire         SW7,
    
    // Chocolate Level [1:0]
    input  wire         SW8,
    input  wire         SW9,
    
    // Water Pressure [1:0]
    input  wire         SW10,
    input  wire         SW11,
    
    // System Controls
    input  wire         SW12,               // Temperature override
    input  wire         SW13,               // System fault simulation
    input  wire         SW14,               // Reserved
    input  wire         SW15,               // Reserved
    input  wire         SW16,               // Reserved
    input  wire         SW17,               // Reset (handled in top module)
    
    //========================================================================
    // Consumable Level Outputs (8-bit values for consumable_manager)
    //========================================================================
    output reg [7:0]    sensor_bin0_level,
    output reg [7:0]    sensor_bin1_level,
    output reg [7:0]    sensor_creamer_level,
    output reg [7:0]    sensor_chocolate_level,
    output reg          paper_filter_present,
    
    //========================================================================
    // Water System Outputs
    //========================================================================
    output reg [1:0]    water_pressure,         // Raw pressure reading
    output reg          pressure_ready,         // Pressure OK flag
    output reg          temp_override,          // Temperature override
    
    //========================================================================
    // System Status Outputs
    //========================================================================
    output reg          system_fault_flag       // Simulated system fault
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Level encoding (2-bit switch values)
    parameter LEVEL_EMPTY = 2'b00;           // Empty - ERROR
    parameter LEVEL_LOW = 2'b01;             // Low - WARNING
    parameter LEVEL_FULL = 2'b10;            // Full - NORMAL
    parameter LEVEL_INFINITE = 2'b11;        // Infinite (for testing)
    
    // Corresponding 8-bit levels for consumable_manager
    parameter VALUE_EMPTY = 8'd0;
    parameter VALUE_LOW = 8'd30;             // Just above empty threshold
    parameter VALUE_FULL = 8'd200;           // Well above low threshold
    parameter VALUE_INFINITE = 8'd255;       // Maximum
    
    // Water pressure encoding
    parameter PRESSURE_LOW = 2'b00;          // Low - WARNING
    parameter PRESSURE_OK = 2'b01;           // OK - NORMAL
    parameter PRESSURE_HIGH = 2'b10;         // High - ERROR
    parameter PRESSURE_ERROR = 2'b11;        // Error - ERROR
    
    //========================================================================
    // Internal Wire Signals
    //========================================================================
    
    wire [1:0] paper_level;
    wire [1:0] bin0_level;
    wire [1:0] bin1_level;
    wire [1:0] creamer_level;
    wire [1:0] chocolate_level;
    wire [1:0] pressure_level;
    
    //========================================================================
    // Combine Switch Inputs
    //========================================================================
    
    assign paper_level = {SW1, SW0};
    assign bin0_level = {SW3, SW2};
    assign bin1_level = {SW5, SW4};
    assign creamer_level = {SW7, SW6};
    assign chocolate_level = {SW9, SW8};
    assign pressure_level = {SW11, SW10};
    
    //========================================================================
    // Convert Paper Level to Boolean (for paper_filter_present)
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            paper_filter_present <= 1'b1;  // Default: paper present
        end else begin
            // Paper is present if not empty (00)
            paper_filter_present <= (paper_level != LEVEL_EMPTY);
        end
    end
    
    //========================================================================
    // Convert 2-bit Levels to 8-bit Values
    //========================================================================
    
    function automatic [7:0] level_to_value;
        input [1:0] level;
        begin
            case (level)
                LEVEL_EMPTY:    level_to_value = VALUE_EMPTY;
                LEVEL_LOW:      level_to_value = VALUE_LOW;
                LEVEL_FULL:     level_to_value = VALUE_FULL;
                LEVEL_INFINITE: level_to_value = VALUE_INFINITE;
                default:        level_to_value = VALUE_EMPTY;
            endcase
        end
    endfunction
    
    //========================================================================
    // Register Consumable Levels
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sensor_bin0_level <= VALUE_FULL;
            sensor_bin1_level <= VALUE_FULL;
            sensor_creamer_level <= VALUE_FULL;
            sensor_chocolate_level <= VALUE_FULL;
        end else begin
            sensor_bin0_level <= level_to_value(bin0_level);
            sensor_bin1_level <= level_to_value(bin1_level);
            sensor_creamer_level <= level_to_value(creamer_level);
            sensor_chocolate_level <= level_to_value(chocolate_level);
        end
    end
    
    //========================================================================
    // Water Pressure Processing
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            water_pressure <= PRESSURE_OK;
            pressure_ready <= 1'b1;
        end else begin
            water_pressure <= pressure_level;
            
            // Pressure is ready only if OK
            case (pressure_level)
                PRESSURE_LOW:   pressure_ready <= 1'b0;  // Not ready (warning)
                PRESSURE_OK:    pressure_ready <= 1'b1;  // Ready
                PRESSURE_HIGH:  pressure_ready <= 1'b0;  // Not ready (error)
                PRESSURE_ERROR: pressure_ready <= 1'b0;  // Not ready (error)
                default:        pressure_ready <= 1'b0;
            endcase
        end
    end
    
    //========================================================================
    // System Control Signals
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_override <= 1'b0;
            system_fault_flag <= 1'b0;
        end else begin
            temp_override <= SW12;
            system_fault_flag <= ~SW13;  // Inverted: SW13=0 means fault
        end
    end
    
    //========================================================================
    // Debug/Monitoring (synthesis off)
    //========================================================================
    
    // synthesis translate_off
    // reg [1:0] paper_level_prev;
    // reg [1:0] bin0_level_prev;
    // reg [1:0] bin1_level_prev;
    // reg [1:0] pressure_level_prev;
    
    // always @(posedge clk) begin
    //     if (rst_n) begin
    //         // Track previous values for change detection
    //         paper_level_prev <= paper_level;
    //         bin0_level_prev <= bin0_level;
    //         bin1_level_prev <= bin1_level;
    //         pressure_level_prev <= pressure_level;
            
    //         // Log level changes
    //         if (paper_level != paper_level_prev) begin
    //             $display("[%0t] Sensor: Paper level changed to %0d -> value %0d", 
    //                      $time, paper_level, level_to_value(paper_level));
    //         end
            
    //         if (bin0_level != bin0_level_prev) begin
    //             $display("[%0t] Sensor: Bin 0 level changed to %0d -> value %0d", 
    //                      $time, bin0_level, sensor_bin0_level);
    //         end
            
    //         if (bin1_level != bin1_level_prev) begin
    //             $display("[%0t] Sensor: Bin 1 level changed to %0d -> value %0d", 
    //                      $time, bin1_level, sensor_bin1_level);
    //         end
            
    //         if (pressure_level != pressure_level_prev) begin
    //             case (pressure_level)
    //                 PRESSURE_LOW:   $display("[%0t] Sensor: Pressure LOW (WARNING)", $time);
    //                 PRESSURE_OK:    $display("[%0t] Sensor: Pressure OK", $time);
    //                 PRESSURE_HIGH:  $display("[%0t] Sensor: Pressure HIGH (ERROR)", $time);
    //                 PRESSURE_ERROR: $display("[%0t] Sensor: Pressure ERROR", $time);
    //             endcase
    //         end
            
    //         // Log system fault changes
    //         if (system_fault_flag && !($past(system_fault_flag, 1))) begin
    //             $display("[%0t] Sensor: SYSTEM FAULT DETECTED", $time);
    //         end else if (!system_fault_flag && $past(system_fault_flag, 1)) begin
    //             $display("[%0t] Sensor: System fault cleared", $time);
    //         end
    //     end
    // end
    // synthesis translate_on

endmodule