//============================================================================
// Module: consumable_manager
// Description: Manages consumable ingredient levels with automatic depletion
//              and refill control for coffee machine system
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module consumable_manager (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,                // 50 MHz system clock
    input  wire         rst_n,              // Active-low reset
    
    //========================================================================
    // Sensor Interface Inputs (from sensor_interface module)
    //========================================================================
    input  wire [7:0]   sensor_bin0_level,      // Current bin 0 sensor reading
    input  wire [7:0]   sensor_bin1_level,      // Current bin 1 sensor reading
    input  wire [7:0]   sensor_creamer_level,   // Current creamer sensor reading
    input  wire [7:0]   sensor_chocolate_level, // Current chocolate sensor reading
    input  wire         paper_filter_present,   // Paper filter sensor
    
    //========================================================================
    // Recipe Engine Interface (consumption requests)
    //========================================================================
    input  wire         consume_enable,         // Enable consumption this cycle
    input  wire [7:0]   consume_bin0_amount,    // Amount to consume from bin 0
    input  wire [7:0]   consume_bin1_amount,    // Amount to consume from bin 1
    input  wire [7:0]   consume_creamer_amount, // Amount to consume creamer
    input  wire [7:0]   consume_chocolate_amount, // Amount to consume chocolate
    input  wire         consume_paper_filter,   // Consume one paper filter
    
    //========================================================================
    // Managed Consumable Levels (outputs to system)
    //========================================================================
    output reg [7:0]    coffee_bin0_level,      // Managed bin 0 level
    output reg [7:0]    coffee_bin1_level,      // Managed bin 1 level
    output reg [7:0]    creamer_level,          // Managed creamer level
    output reg [7:0]    chocolate_level,        // Managed chocolate level
    output reg [7:0]    paper_filter_count,     // Paper filter count
    
    //========================================================================
    // Status Flags (for error handling and UI)
    //========================================================================
    output wire         bin0_empty,             // Bin 0 is empty
    output wire         bin0_low,               // Bin 0 is low
    output wire         bin1_empty,             // Bin 1 is empty
    output wire         bin1_low,               // Bin 1 is low
    output wire         creamer_empty,          // Creamer is empty
    output wire         creamer_low,            // Creamer is low
    output wire         chocolate_empty,        // Chocolate is empty
    output wire         chocolate_low,          // Chocolate is low
    output wire         paper_empty,            // No paper filters
    output wire         paper_low,              // Paper filters low
    
    //========================================================================
    // Availability Flags (recipe validation)
    //========================================================================
    output wire         can_make_coffee,        // At least one bin has coffee
    output wire         can_add_creamer,        // Creamer available
    output wire         can_add_chocolate       // Chocolate available
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Level thresholds
    parameter LEVEL_FULL = 255;
    parameter LEVEL_LOW_THRESHOLD = 50;
    parameter LEVEL_EMPTY_THRESHOLD = 10;
    
    // Paper filter thresholds
    parameter PAPER_LOW_THRESHOLD = 5;
    parameter PAPER_MAX = 255;
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    // Consumption state machine
    typedef enum logic [1:0] {
        IDLE,
        CONSUMING,
        DONE
    } consume_state_t;
    
    consume_state_t consume_state;
    
    //========================================================================
    // Level Management Logic
    //========================================================================
    
    // Coffee Bin 0 level management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coffee_bin0_level <= LEVEL_FULL;
            consume_state <= IDLE;
        end else begin
            // Check if sensor is forcing empty
            if (sensor_bin0_level == 0) begin
                coffee_bin0_level <= 0;
            // Allow consumption
            end else if (consume_enable && consume_bin0_amount > 0) begin
                if (coffee_bin0_level >= consume_bin0_amount) begin
                    coffee_bin0_level <= coffee_bin0_level - consume_bin0_amount;
                end else begin
                    coffee_bin0_level <= 0;
                end
            // Update from sensor only if sensor changed AND no consumption happening
            end else if (!consume_enable && sensor_bin0_level != coffee_bin0_level && sensor_bin0_level != 0) begin
                coffee_bin0_level <= sensor_bin0_level;
            end
        end
    end
    
    // Coffee Bin 1 level management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coffee_bin1_level <= LEVEL_FULL;
        end else begin
            if (sensor_bin1_level == 0) begin
                coffee_bin1_level <= 0;
            end else if (consume_enable && consume_bin1_amount > 0) begin
                if (coffee_bin1_level >= consume_bin1_amount) begin
                    coffee_bin1_level <= coffee_bin1_level - consume_bin1_amount;
                end else begin
                    coffee_bin1_level <= 0;
                end
            end else if (!consume_enable && sensor_bin1_level != coffee_bin1_level && sensor_bin1_level != 0) begin
                coffee_bin1_level <= sensor_bin1_level;
            end
        end
    end
    
    // Creamer level management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            creamer_level <= LEVEL_FULL;
        end else begin
            if (sensor_creamer_level == 0) begin
                creamer_level <= 0;
            end else if (consume_enable && consume_creamer_amount > 0) begin
                if (creamer_level >= consume_creamer_amount) begin
                    creamer_level <= creamer_level - consume_creamer_amount;
                end else begin
                    creamer_level <= 0;
                end
            end else if (!consume_enable && sensor_creamer_level != creamer_level && sensor_creamer_level != 0) begin
                creamer_level <= sensor_creamer_level;
            end
        end
    end
    
    // Chocolate level management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chocolate_level <= LEVEL_FULL;
        end else begin
            if (sensor_chocolate_level == 0) begin
                chocolate_level <= 0;
            end else if (consume_enable && consume_chocolate_amount > 0) begin
                if (chocolate_level >= consume_chocolate_amount) begin
                    chocolate_level <= chocolate_level - consume_chocolate_amount;
                end else begin
                    chocolate_level <= 0;
                end
            end else if (!consume_enable && sensor_chocolate_level != chocolate_level && sensor_chocolate_level != 0) begin
                chocolate_level <= sensor_chocolate_level;
            end
        end
    end
    
    // Paper filter count management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            paper_filter_count <= PAPER_MAX;
        end else begin
            // Refill when sensor shows paper present after being absent
            if (paper_filter_present && paper_filter_count == 0) begin
                paper_filter_count <= PAPER_MAX; // Refill to max
            end else if (consume_enable && consume_paper_filter) begin
                // Consume one paper filter
                if (paper_filter_count > 0) begin
                    paper_filter_count <= paper_filter_count - 1;
                end
            end
        end
    end
    
    //========================================================================
    // Status Flag Generation (Combinational)
    //========================================================================
    
    // Coffee Bin 0 status
    assign bin0_empty = (coffee_bin0_level <= LEVEL_EMPTY_THRESHOLD);
    assign bin0_low = (coffee_bin0_level > LEVEL_EMPTY_THRESHOLD) && 
                      (coffee_bin0_level <= LEVEL_LOW_THRESHOLD);
    
    // Coffee Bin 1 status
    assign bin1_empty = (coffee_bin1_level <= LEVEL_EMPTY_THRESHOLD);
    assign bin1_low = (coffee_bin1_level > LEVEL_EMPTY_THRESHOLD) && 
                      (coffee_bin1_level <= LEVEL_LOW_THRESHOLD);
    
    // Creamer status
    assign creamer_empty = (creamer_level <= LEVEL_EMPTY_THRESHOLD);
    assign creamer_low = (creamer_level > LEVEL_EMPTY_THRESHOLD) && 
                         (creamer_level <= LEVEL_LOW_THRESHOLD);
    
    // Chocolate status
    assign chocolate_empty = (chocolate_level <= LEVEL_EMPTY_THRESHOLD);
    assign chocolate_low = (chocolate_level > LEVEL_EMPTY_THRESHOLD) && 
                           (chocolate_level <= LEVEL_LOW_THRESHOLD);
    
    // Paper filter status
    assign paper_empty = (paper_filter_count == 0);
    assign paper_low = (paper_filter_count > 0) && 
                       (paper_filter_count <= PAPER_LOW_THRESHOLD);
    
    //========================================================================
    // Availability Flag Generation (Combinational)
    //========================================================================
    
    // Can make coffee if at least one bin is not empty
    assign can_make_coffee = !bin0_empty || !bin1_empty;
    
    // Can add creamer if creamer is not empty
    assign can_add_creamer = !creamer_empty;
    
    // Can add chocolate if chocolate is not empty
    assign can_add_chocolate = !chocolate_empty;
    
    //========================================================================
    // Debug/Monitoring (Optional - can be removed for synthesis)
    //========================================================================
    
    // Synthesis translate_off
    // always @(posedge clk) begin
    //     if (consume_enable) begin
    //         if (consume_bin0_amount > 0) begin
    //             $display("[%0t] Consuming %0d units from Bin 0 (level: %0d)", 
    //                      $time, consume_bin0_amount, coffee_bin0_level);
    //         end
    //         if (consume_bin1_amount > 0) begin
    //             $display("[%0t] Consuming %0d units from Bin 1 (level: %0d)", 
    //                      $time, consume_bin1_amount, coffee_bin1_level);
    //         end
    //         if (consume_creamer_amount > 0) begin
    //             $display("[%0t] Consuming %0d units of creamer (level: %0d)", 
    //                      $time, consume_creamer_amount, creamer_level);
    //         end
    //         if (consume_chocolate_amount > 0) begin
    //             $display("[%0t] Consuming %0d units of chocolate (level: %0d)", 
    //                      $time, consume_chocolate_amount, chocolate_level);
    //         end
    //         if (consume_paper_filter) begin
    //             $display("[%0t] Consuming paper filter (count: %0d)", 
    //                      $time, paper_filter_count);
    //         end
    //     end
        
    //     // Warning messages for low levels
    //     if (bin0_low && !bin0_empty) begin
    //         $display("[%0t] WARNING: Coffee Bin 0 is low (level: %0d)", 
    //                  $time, coffee_bin0_level);
    //     end
    //     if (bin1_low && !bin1_empty) begin
    //         $display("[%0t] WARNING: Coffee Bin 1 is low (level: %0d)", 
    //                  $time, coffee_bin1_level);
    //     end
    //     if (creamer_low && !creamer_empty) begin
    //         $display("[%0t] WARNING: Creamer is low (level: %0d)", 
    //                  $time, creamer_level);
    //     end
    //     if (chocolate_low && !chocolate_empty) begin
    //         $display("[%0t] WARNING: Chocolate is low (level: %0d)", 
    //                  $time, chocolate_level);
    //     end
    //     if (paper_low && !paper_empty) begin
    //         $display("[%0t] WARNING: Paper filters are low (count: %0d)", 
    //                  $time, paper_filter_count);
    //     end
        
    //     // Error messages for empty levels
    //     if (bin0_empty && bin1_empty) begin
    //         $display("[%0t] ERROR: All coffee bins are empty!", $time);
    //     end
    //     if (paper_empty) begin
    //         $display("[%0t] ERROR: No paper filters available!", $time);
    //     end
    // end
    // Synthesis translate_on
    
endmodule