//============================================================================
// Module: consumable_manager
// Description: Manages consumable ingredient levels with automatic depletion
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
    
    // Level thresholds (aligned with smallest recipe: 8oz Latte = ~12 units)
    parameter LEVEL_FULL = 255;
    parameter LEVEL_LOW_THRESHOLD = 50;
    parameter LEVEL_EMPTY_THRESHOLD = 12;  // Must have at least 12 units to make smallest drink
    
    // Paper filter thresholds
    parameter PAPER_LOW_THRESHOLD = 5;
    parameter PAPER_MAX = 255;
    
    // Startup stabilization time
    parameter STARTUP_CYCLES = 32'd100_000;  // 2ms at 50MHz for sensors to stabilize
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    // Startup counter to ignore sensor glitches
    reg [31:0] startup_counter;
    reg        startup_complete;
    
    // Previous sensor values for change detection
    reg [7:0] sensor_bin0_prev;
    reg [7:0] sensor_bin1_prev;
    reg [7:0] sensor_creamer_prev;
    reg [7:0] sensor_chocolate_prev;
    
    //========================================================================
    // Startup Stabilization
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            startup_counter <= 0;
            startup_complete <= 1'b0;
        end else begin
            if (startup_counter >= STARTUP_CYCLES) begin
                startup_complete <= 1'b1;
            end else begin
                startup_counter <= startup_counter + 1;
            end
        end
    end
    
    //========================================================================
    // Sensor Change Detection
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sensor_bin0_prev <= LEVEL_FULL;
            sensor_bin1_prev <= LEVEL_FULL;
            sensor_creamer_prev <= LEVEL_FULL;
            sensor_chocolate_prev <= LEVEL_FULL;
        end else begin
            sensor_bin0_prev <= sensor_bin0_level;
            sensor_bin1_prev <= sensor_bin1_level;
            sensor_creamer_prev <= sensor_creamer_level;
            sensor_chocolate_prev <= sensor_chocolate_level;
        end
    end
    
    // Detect when sensor values change
    wire bin0_sensor_changed = (sensor_bin0_level != sensor_bin0_prev);
    wire bin1_sensor_changed = (sensor_bin1_level != sensor_bin1_prev);
    wire creamer_sensor_changed = (sensor_creamer_level != sensor_creamer_prev);
    wire chocolate_sensor_changed = (sensor_chocolate_level != sensor_chocolate_prev);
    
    //========================================================================
    // Level Management Logic - Coffee Bin 0
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coffee_bin0_level <= LEVEL_FULL;
        end else begin
            // Check if in INFINITE mode (sensor = 255)
            if (sensor_bin0_level == 8'd255) begin
                // INFINITE MODE: Always stay at 255, ignore consumption
                coffee_bin0_level <= 8'd255;
            // Priority 1: Consumption (depletion)
            end else if (consume_enable && consume_bin0_amount > 0) begin
                if (coffee_bin0_level >= consume_bin0_amount) begin
                    coffee_bin0_level <= coffee_bin0_level - consume_bin0_amount;
                end else begin
                    coffee_bin0_level <= 0;
                end
            // Priority 2: Sensor update ONLY when sensor changes (refill/empty commands)
            end else if (startup_complete && bin0_sensor_changed) begin
                coffee_bin0_level <= sensor_bin0_level;
            end
            // Otherwise: Hold current value (natural depletion tracking)
        end
    end
    
    //========================================================================
    // Level Management Logic - Coffee Bin 1
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coffee_bin1_level <= LEVEL_FULL;
        end else begin
            // Check if in INFINITE mode (sensor = 255)
            if (sensor_bin1_level == 8'd255) begin
                // INFINITE MODE: Always stay at 255, ignore consumption
                coffee_bin1_level <= 8'd255;
            end else if (consume_enable && consume_bin1_amount > 0) begin
                if (coffee_bin1_level >= consume_bin1_amount) begin
                    coffee_bin1_level <= coffee_bin1_level - consume_bin1_amount;
                end else begin
                    coffee_bin1_level <= 0;
                end
            end else if (startup_complete && bin1_sensor_changed) begin
                coffee_bin1_level <= sensor_bin1_level;
            end
        end
    end
    
    //========================================================================
    // Level Management Logic - Creamer
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            creamer_level <= LEVEL_FULL;
        end else begin
            // Check if in INFINITE mode (sensor = 255)
            if (sensor_creamer_level == 8'd255) begin
                // INFINITE MODE: Always stay at 255, ignore consumption
                creamer_level <= 8'd255;
            end else if (consume_enable && consume_creamer_amount > 0) begin
                if (creamer_level >= consume_creamer_amount) begin
                    creamer_level <= creamer_level - consume_creamer_amount;
                end else begin
                    creamer_level <= 0;
                end
            end else if (startup_complete && creamer_sensor_changed) begin
                creamer_level <= sensor_creamer_level;
            end
        end
    end
    
    //========================================================================
    // Level Management Logic - Chocolate
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chocolate_level <= LEVEL_FULL;
        end else begin
            // Check if in INFINITE mode (sensor = 255)
            if (sensor_chocolate_level == 8'd255) begin
                // INFINITE MODE: Always stay at 255, ignore consumption
                chocolate_level <= 8'd255;
            end else if (consume_enable && consume_chocolate_amount > 0) begin
                if (chocolate_level >= consume_chocolate_amount) begin
                    chocolate_level <= chocolate_level - consume_chocolate_amount;
                end else begin
                    chocolate_level <= 0;
                end
            end else if (startup_complete && chocolate_sensor_changed) begin
                chocolate_level <= sensor_chocolate_level;
            end
        end
    end
    
    //========================================================================
    // Level Management Logic - Paper Filter
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            paper_filter_count <= PAPER_MAX;
        end else begin
            if (consume_enable && consume_paper_filter) begin
                if (paper_filter_count > 0) begin
                    // Only decrement if not at PAPER_MAX (infinite mode)
                    // If at PAPER_MAX and sensor present, assume infinite
                    if (paper_filter_count == PAPER_MAX && paper_filter_present) begin
                        paper_filter_count <= PAPER_MAX;  // Stay at max (infinite)
                    end else begin
                        paper_filter_count <= paper_filter_count - 1;
                    end
                end
            end else if (startup_complete) begin
                // Update paper count from sensor
                if (paper_filter_present) begin
                    // If sensor sees paper and count is low, assume refill
                    if (paper_filter_count < PAPER_LOW_THRESHOLD) begin
                        paper_filter_count <= PAPER_MAX;
                    end
                end else begin
                    // If sensor says no paper, set to 0
                    paper_filter_count <= 0;
                end
            end
        end
    end
    
    //========================================================================
    // Status Flag Generation
    //========================================================================
    
    assign bin0_empty = (coffee_bin0_level <= LEVEL_EMPTY_THRESHOLD);
    assign bin0_low = (coffee_bin0_level <= LEVEL_LOW_THRESHOLD) && !bin0_empty;
    
    assign bin1_empty = (coffee_bin1_level <= LEVEL_EMPTY_THRESHOLD);
    assign bin1_low = (coffee_bin1_level <= LEVEL_LOW_THRESHOLD) && !bin1_empty;
    
    assign creamer_empty = (creamer_level <= LEVEL_EMPTY_THRESHOLD);
    assign creamer_low = (creamer_level <= LEVEL_LOW_THRESHOLD) && !creamer_empty;
    
    assign chocolate_empty = (chocolate_level <= LEVEL_EMPTY_THRESHOLD);
    assign chocolate_low = (chocolate_level <= LEVEL_LOW_THRESHOLD) && !chocolate_empty;
    
    assign paper_empty = (paper_filter_count == 0);
    assign paper_low = (paper_filter_count <= PAPER_LOW_THRESHOLD) && !paper_empty;
    
    //========================================================================
    // Availability Flag Generation
    //========================================================================
    
    assign can_make_coffee = !bin0_empty || !bin1_empty;
    assign can_add_creamer = !creamer_empty;
    assign can_add_chocolate = !chocolate_empty;

endmodule