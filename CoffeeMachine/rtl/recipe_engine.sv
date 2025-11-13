//============================================================================
// Module: recipe_engine
// Description: Recipe storage and execution engine for coffee machine
//              Stores 5 drink recipes and generates timing/ingredient sequences
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//
//============================================================================

`timescale 1ns/1ps

module recipe_engine (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,                    // 50 MHz system clock
    input  wire         rst_n,                  // Active-low reset
    
    //========================================================================
    // Recipe Selection Interface (from main FSM)
    //========================================================================
    input  wire [2:0]   selected_coffee_type,   // Coffee type: 0=Bin0, 1=Bin1
    input  wire [2:0]   selected_drink_type,    // Drink type: 0-4
                                                // 0: Black Coffee
                                                // 1: Coffee with Cream
                                                // 2: Latte
                                                // 3: Mocha
                                                // 4: Hot Chocolate
    input  wire [1:0]   selected_size,          // Size: 0=8oz, 1=12oz, 2=16oz
    
    //========================================================================
    // Brewing Control Interface
    //========================================================================
    input  wire         start_brewing,          // Start brewing pulse
    input  wire         abort_brewing,          // Abort current brew
    
    //========================================================================
    // Consumable Manager Interface (ingredient consumption)
    //========================================================================
    output reg          consume_enable,         // Pulse to consume ingredients
    output reg [7:0]    consume_bin0_amount,    // Bin 0 consumption
    output reg [7:0]    consume_bin1_amount,    // Bin 1 consumption
    output reg [7:0]    consume_creamer_amount, // Creamer consumption
    output reg [7:0]    consume_chocolate_amount, // Chocolate consumption
    output reg          consume_paper_filter,   // Paper filter consumption
    
    //========================================================================
    // Ingredient Availability (from consumable_manager)
    //========================================================================
    input  wire [7:0]   coffee_bin0_level,      // Current bin 0 level
    input  wire [7:0]   coffee_bin1_level,      // Current bin 1 level
    input  wire [7:0]   creamer_level,          // Current creamer level
    input  wire [7:0]   chocolate_level,        // Current chocolate level
    input  wire         paper_filter_present,   // Paper filter available
    
    //========================================================================
    // Actuator Control Outputs
    //========================================================================
    output reg          grinder0_enable,        // Coffee bin 0 grinder
    output reg          grinder1_enable,        // Coffee bin 1 grinder
    output reg          water_pour_enable,      // Pour-over water valve
    output reg          water_direct_enable,    // Direct water valve (dilution)
    output reg          paper_motor_enable,     // Paper feed motor
    
    //========================================================================
    // Status Outputs
    //========================================================================
    output reg          brewing_active,         // Currently brewing
    output reg          brewing_complete,       // Brew cycle complete
    output reg [7:0]    brew_progress,          // Progress 0-100%
    output wire         recipe_valid            // Selected recipe is valid
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Drink type definitions
    parameter DRINK_BLACK_COFFEE = 3'd0;
    parameter DRINK_COFFEE_CREAM = 3'd1;
    parameter DRINK_LATTE = 3'd2;
    parameter DRINK_MOCHA = 3'd3;
    parameter DRINK_HOT_CHOCOLATE = 3'd4;
    
    // Size definitions
    parameter SIZE_8OZ = 2'd0;
    parameter SIZE_12OZ = 2'd1;
    parameter SIZE_16OZ = 2'd2;
    
    // Coffee type definitions
    parameter COFFEE_BIN0 = 3'd0;
    parameter COFFEE_BIN1 = 3'd1;
    
    // Base ingredient amounts (scaled by size)
    parameter BASE_COFFEE = 8'd30;      // Base coffee amount
    parameter BASE_CREAMER = 8'd15;     // Base creamer amount
    parameter BASE_CHOCOLATE = 8'd20;   // Base chocolate amount
    parameter BASE_WATER = 8'd50;       // Base water amount
    
    // Size multipliers (fixed point: multiply by 10, divide by 10)
    parameter SIZE_8OZ_MULT = 8'd8;     // 0.8x
    parameter SIZE_12OZ_MULT = 8'd10;   // 1.0x
    parameter SIZE_16OZ_MULT = 8'd13;   // 1.3x
    
    // Timing parameters (in clock cycles at 50MHz)
    `ifdef SIMULATION
        // Fast simulation times
        parameter TIME_GRIND = 32'd100_000;         // 2ms in simulation
        parameter TIME_POUR = 32'd150_000;          // 3ms in simulation
        parameter TIME_PAPER_FEED = 32'd25_000;     // 0.5ms in simulation
        parameter TIME_SETTLE = 32'd25_000;         // 0.5ms in simulation
    `else
        // Real hardware times
        parameter TIME_GRIND = 32'd100_000_000;     // 2 seconds grinding
        parameter TIME_POUR = 32'd150_000_000;      // 3 seconds pouring
        parameter TIME_PAPER_FEED = 32'd25_000_000; // 0.5 seconds paper feed
        parameter TIME_SETTLE = 32'd25_000_000;     // 0.5 seconds settling
    `endif
    
    //========================================================================
    // Recipe Storage (ROM-like structure)
    //========================================================================
    
    // Recipe structure packed into registers
    // [coffee_needed, creamer_needed, chocolate_needed, water_needed]
    reg [7:0] recipe_coffee [0:4];
    reg [7:0] recipe_creamer [0:4];
    reg [7:0] recipe_chocolate [0:4];
    reg [7:0] recipe_water [0:4];
    
    // Initialize recipes
    initial begin
        // Black Coffee
        recipe_coffee[DRINK_BLACK_COFFEE] = BASE_COFFEE;
        recipe_creamer[DRINK_BLACK_COFFEE] = 8'd0;
        recipe_chocolate[DRINK_BLACK_COFFEE] = 8'd0;
        recipe_water[DRINK_BLACK_COFFEE] = BASE_WATER;
        
        // Coffee with Cream
        recipe_coffee[DRINK_COFFEE_CREAM] = BASE_COFFEE;
        recipe_creamer[DRINK_COFFEE_CREAM] = BASE_CREAMER;
        recipe_chocolate[DRINK_COFFEE_CREAM] = 8'd0;
        recipe_water[DRINK_COFFEE_CREAM] = BASE_WATER;
        
        // Latte (more creamer, less coffee)
        recipe_coffee[DRINK_LATTE] = BASE_COFFEE / 2;
        recipe_creamer[DRINK_LATTE] = BASE_CREAMER * 2;
        recipe_chocolate[DRINK_LATTE] = 8'd0;
        recipe_water[DRINK_LATTE] = BASE_WATER;
        
        // Mocha (coffee + chocolate + creamer)
        recipe_coffee[DRINK_MOCHA] = BASE_COFFEE;
        recipe_creamer[DRINK_MOCHA] = BASE_CREAMER;
        recipe_chocolate[DRINK_MOCHA] = BASE_CHOCOLATE;
        recipe_water[DRINK_MOCHA] = BASE_WATER;
        
        // Hot Chocolate (no coffee, lots of chocolate and creamer)
        recipe_coffee[DRINK_HOT_CHOCOLATE] = 8'd0;
        recipe_creamer[DRINK_HOT_CHOCOLATE] = BASE_CREAMER;
        recipe_chocolate[DRINK_HOT_CHOCOLATE] = BASE_CHOCOLATE * 2;
        recipe_water[DRINK_HOT_CHOCOLATE] = BASE_WATER;
    end
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    // Scaled recipe amounts (after size adjustment)
    reg [7:0] scaled_coffee;
    reg [7:0] scaled_creamer;
    reg [7:0] scaled_chocolate;
    reg [7:0] scaled_water;
    
    // Brewing state machine
    typedef enum logic [3:0] {
        IDLE,
        VALIDATE,
        FEED_PAPER,
        GRINDING,
        POURING,
        DISPENSING,
        SETTLING,
        COMPLETE,
        ABORT
    } brew_state_t;
    
    brew_state_t brew_state, next_brew_state;
    brew_state_t prev_brew_state;
    
    // Timing counters
    reg [31:0] brew_timer;
    reg [31:0] brew_timer_target;
    reg [31:0] total_brew_time;
    reg [31:0] elapsed_brew_time;
    
    // Recipe validation flags
    reg recipe_has_enough_coffee;
    reg recipe_has_enough_creamer;
    reg recipe_has_enough_chocolate;
    reg recipe_has_paper;
    
    //========================================================================
    // Recipe Scaling (Size Adjustment)
    //========================================================================
    
    always @(*) begin
        case (selected_size)
            SIZE_8OZ: begin
                scaled_coffee = (recipe_coffee[selected_drink_type] * SIZE_8OZ_MULT) / 10;
                scaled_creamer = (recipe_creamer[selected_drink_type] * SIZE_8OZ_MULT) / 10;
                scaled_chocolate = (recipe_chocolate[selected_drink_type] * SIZE_8OZ_MULT) / 10;
                scaled_water = (recipe_water[selected_drink_type] * SIZE_8OZ_MULT) / 10;
            end
            SIZE_12OZ: begin
                scaled_coffee = (recipe_coffee[selected_drink_type] * SIZE_12OZ_MULT) / 10;
                scaled_creamer = (recipe_creamer[selected_drink_type] * SIZE_12OZ_MULT) / 10;
                scaled_chocolate = (recipe_chocolate[selected_drink_type] * SIZE_12OZ_MULT) / 10;
                scaled_water = (recipe_water[selected_drink_type] * SIZE_12OZ_MULT) / 10;
            end
            SIZE_16OZ: begin
                scaled_coffee = (recipe_coffee[selected_drink_type] * SIZE_16OZ_MULT) / 10;
                scaled_creamer = (recipe_creamer[selected_drink_type] * SIZE_16OZ_MULT) / 10;
                scaled_chocolate = (recipe_chocolate[selected_drink_type] * SIZE_16OZ_MULT) / 10;
                scaled_water = (recipe_water[selected_drink_type] * SIZE_16OZ_MULT) / 10;
            end
            default: begin
                scaled_coffee = recipe_coffee[selected_drink_type];
                scaled_creamer = recipe_creamer[selected_drink_type];
                scaled_chocolate = recipe_chocolate[selected_drink_type];
                scaled_water = recipe_water[selected_drink_type];
            end
        endcase
    end
    
    //========================================================================
    // Recipe Validation
    //========================================================================
    
    always @(*) begin
        // Check if enough coffee (consider which bin is selected)
        if (scaled_coffee == 0) begin
            recipe_has_enough_coffee = 1'b1;  // No coffee needed
        end else if (selected_coffee_type == COFFEE_BIN0) begin
            recipe_has_enough_coffee = (coffee_bin0_level >= scaled_coffee);
        end else begin
            recipe_has_enough_coffee = (coffee_bin1_level >= scaled_coffee);
        end
        
        // Check other ingredients
        recipe_has_enough_creamer = (scaled_creamer == 0) || (creamer_level >= scaled_creamer);
        recipe_has_enough_chocolate = (scaled_chocolate == 0) || (chocolate_level >= scaled_chocolate);
        recipe_has_paper = paper_filter_present;
    end
    
    // Recipe is valid if all required ingredients are available
    assign recipe_valid = recipe_has_enough_coffee && 
                         recipe_has_enough_creamer && 
                         recipe_has_enough_chocolate && 
                         recipe_has_paper;
    
    //========================================================================
    // Total Brew Time Calculation (for progress)
    //========================================================================
    
    always @(*) begin
        // Calculate total time based on recipe requirements
        total_brew_time = TIME_PAPER_FEED + TIME_SETTLE;  // Always need paper and settle
        
        if (scaled_coffee > 0) begin
            total_brew_time = total_brew_time + TIME_GRIND + TIME_POUR;
        end else begin
            total_brew_time = total_brew_time + TIME_POUR;  // Still pour even without coffee
        end
        
        if (scaled_creamer > 0 || scaled_chocolate > 0) begin
            total_brew_time = total_brew_time + (TIME_POUR / 2);  // Dispensing time
        end
    end
    
    //========================================================================
    // Brewing State Machine
    //========================================================================
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            brew_state <= IDLE;
            prev_brew_state <= IDLE;
        end else begin
            prev_brew_state <= brew_state;
            brew_state <= next_brew_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_brew_state = brew_state;
        
        case (brew_state)
            IDLE: begin
                if (start_brewing) begin
                    next_brew_state = VALIDATE;
                end
            end
            
            VALIDATE: begin
                if (recipe_valid) begin
                    next_brew_state = FEED_PAPER;
                end else begin
                    next_brew_state = ABORT;
                end
            end
            
            FEED_PAPER: begin
                if (brew_timer >= brew_timer_target) begin
                    next_brew_state = GRINDING;
                end else if (abort_brewing) begin
                    next_brew_state = ABORT;
                end
            end
            
            GRINDING: begin
                if (brew_timer >= brew_timer_target) begin
                    next_brew_state = POURING;
                end else if (abort_brewing) begin
                    next_brew_state = ABORT;
                end
            end
            
            POURING: begin
                if (brew_timer >= brew_timer_target) begin
                    next_brew_state = DISPENSING;
                end else if (abort_brewing) begin
                    next_brew_state = ABORT;
                end
            end
            
            DISPENSING: begin
                if (brew_timer >= brew_timer_target) begin
                    next_brew_state = SETTLING;
                end else if (abort_brewing) begin
                    next_brew_state = ABORT;
                end
            end
            
            SETTLING: begin
                if (brew_timer >= brew_timer_target) begin
                    next_brew_state = COMPLETE;
                end else if (abort_brewing) begin
                    next_brew_state = ABORT;
                end
            end
            
            COMPLETE: begin
                next_brew_state = IDLE;
            end
            
            ABORT: begin
                next_brew_state = IDLE;
            end
            
            default: begin
                next_brew_state = IDLE;
            end
        endcase
    end
    
    //========================================================================
    // Brewing Timer
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            brew_timer <= 0;
        end else begin
            if (brew_state == IDLE || brew_state == VALIDATE || brew_state == COMPLETE || brew_state == ABORT) begin
                brew_timer <= 0;
            end else if (brew_state != prev_brew_state) begin
                // State transition - reset timer
                brew_timer <= 0;
            end else begin
                brew_timer <= brew_timer + 1;
            end
        end
    end
    
    //========================================================================
    // Elapsed Time Tracking (for smooth progress)
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            elapsed_brew_time <= 0;
        end else begin
            if (brew_state == IDLE || brew_state == VALIDATE || brew_state == ABORT) begin
                elapsed_brew_time <= 0;
            end else if (brewing_active) begin
                elapsed_brew_time <= elapsed_brew_time + 1;
            end
        end
    end
    
    //========================================================================
    // Output Control Logic
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Actuator outputs
            grinder0_enable <= 1'b0;
            grinder1_enable <= 1'b0;
            water_pour_enable <= 1'b0;
            water_direct_enable <= 1'b0;
            paper_motor_enable <= 1'b0;
            
            // Consumption outputs
            consume_enable <= 1'b0;
            consume_bin0_amount <= 8'd0;
            consume_bin1_amount <= 8'd0;
            consume_creamer_amount <= 8'd0;
            consume_chocolate_amount <= 8'd0;
            consume_paper_filter <= 1'b0;
            
            // Status outputs
            brewing_active <= 1'b0;
            brewing_complete <= 1'b0;
            brew_progress <= 8'd0;
            
            // Internal tracking
            brew_timer_target <= 0;
            
        end else begin
            grinder0_enable <= 1'b0;
            grinder1_enable <= 1'b0;
            water_pour_enable <= 1'b0;
            water_direct_enable <= 1'b0;
            paper_motor_enable <= 1'b0;
            consume_enable <= 1'b0;
            brewing_complete <= 1'b0;
            
            consume_bin0_amount <= 8'd0;
            consume_bin1_amount <= 8'd0;
            consume_creamer_amount <= 8'd0;
            consume_chocolate_amount <= 8'd0;
            consume_paper_filter <= 1'b0;
            
            case (brew_state)
                IDLE: begin
                    brewing_active <= 1'b0;
                    brew_progress <= 8'd0;
                end
                
                VALIDATE: begin
                    brewing_active <= 1'b1;
                    brew_progress <= 8'd0;
                end
                
                FEED_PAPER: begin
                    brewing_active <= 1'b1;
                    paper_motor_enable <= 1'b1;
                    brew_timer_target <= TIME_PAPER_FEED;
                    
                    if (prev_brew_state != FEED_PAPER) begin
                        consume_enable <= 1'b1;
                        consume_paper_filter <= 1'b1;
                    end
                    
                    // Smooth progress calculation
                    if (total_brew_time > 0) begin
                        brew_progress <= (elapsed_brew_time * 100) / total_brew_time;
                    end else begin
                        brew_progress <= 8'd10;
                    end
                end
                
                GRINDING: begin
                    brewing_active <= 1'b1;
                    brew_timer_target <= TIME_GRIND;
                    
                    // FIX: Consume coffee ONLY on state entry
                    if (prev_brew_state != GRINDING) begin
                        consume_enable <= 1'b1;
                        if (selected_coffee_type == COFFEE_BIN0) begin
                            consume_bin0_amount <= scaled_coffee;
                        end else begin
                            consume_bin1_amount <= scaled_coffee;
                        end
                    end
                    
                    // Activate appropriate grinder
                    if (selected_coffee_type == COFFEE_BIN0) begin
                        grinder0_enable <= 1'b1;
                    end else begin
                        grinder1_enable <= 1'b1;
                    end
                    
                    // Smooth progress
                    if (total_brew_time > 0) begin
                        brew_progress <= (elapsed_brew_time * 100) / total_brew_time;
                    end else begin
                        brew_progress <= 8'd30;
                    end
                end
                
                POURING: begin
                    brewing_active <= 1'b1;
                    brew_timer_target <= TIME_POUR;
                    water_pour_enable <= 1'b1;
                    
                    // Smooth progress
                    if (total_brew_time > 0) begin
                        brew_progress <= (elapsed_brew_time * 100) / total_brew_time;
                    end else begin
                        brew_progress <= 8'd60;
                    end
                end
                
                DISPENSING: begin
                    brewing_active <= 1'b1;
                    brew_timer_target <= TIME_POUR / 2;
                    
                    if (prev_brew_state != DISPENSING) begin
                        if (scaled_creamer > 0 || scaled_chocolate > 0) begin
                            consume_enable <= 1'b1;
                            consume_creamer_amount <= scaled_creamer;
                            consume_chocolate_amount <= scaled_chocolate;
                        end
                    end
                    
                    // Dispense creamer and chocolate if needed
                    if (scaled_creamer > 0 || scaled_chocolate > 0) begin
                        water_direct_enable <= 1'b1;
                    end
                    
                    // Smooth progress
                    if (total_brew_time > 0) begin
                        brew_progress <= (elapsed_brew_time * 100) / total_brew_time;
                    end else begin
                        brew_progress <= 8'd80;
                    end
                end
                
                SETTLING: begin
                    brewing_active <= 1'b1;
                    brew_timer_target <= TIME_SETTLE;
                    
                    // Smooth progress
                    if (total_brew_time > 0) begin
                        brew_progress <= (elapsed_brew_time * 100) / total_brew_time;
                    end else begin
                        brew_progress <= 8'd95;
                    end
                end
                
                COMPLETE: begin
                    brewing_active <= 1'b0;
                    brewing_complete <= 1'b1;
                    brew_progress <= 8'd100;
                end
                
                ABORT: begin
                    brewing_active <= 1'b0;
                    brew_progress <= 8'd0;
                end
                
            endcase
        end
    end
    
    //========================================================================
    // Debug/Monitoring (Optional - removed during synthesis)
    //========================================================================
    
    // Synthesis translate_off
    // always @(posedge clk) begin
    //     // Log state transitions
    //     if (brew_state != prev_brew_state) begin
    //         case (brew_state)
    //             IDLE: $display("[%0t] Recipe Engine: IDLE", $time);
    //             VALIDATE: $display("[%0t] Recipe Engine: VALIDATE", $time);
    //             FEED_PAPER: $display("[%0t] Recipe Engine: FEED_PAPER", $time);
    //             GRINDING: $display("[%0t] Recipe Engine: GRINDING", $time);
    //             POURING: $display("[%0t] Recipe Engine: POURING", $time);
    //             DISPENSING: $display("[%0t] Recipe Engine: DISPENSING", $time);
    //             SETTLING: $display("[%0t] Recipe Engine: SETTLING", $time);
    //             COMPLETE: $display("[%0t] Recipe Engine: COMPLETE", $time);
    //             ABORT: $display("[%0t] Recipe Engine: ABORT", $time);
    //         endcase
    //     end
        
    //     // Log consumption events (only on state entry)
    //     if (consume_enable) begin
    //         $display("[%0t] Recipe Engine: Consuming - Coffee B0:%0d, B1:%0d, Creamer:%0d, Chocolate:%0d, Paper:%b",
    //                  $time, consume_bin0_amount, consume_bin1_amount, 
    //                  consume_creamer_amount, consume_chocolate_amount, consume_paper_filter);
    //     end
        
    //     // Log recipe selection
    //     if (brew_state == VALIDATE && prev_brew_state != VALIDATE) begin
    //         $display("[%0t] Recipe: Type=%0d, Size=%0d, Coffee=%0d units, Creamer=%0d, Chocolate=%0d",
    //                  $time, selected_drink_type, selected_size, scaled_coffee, scaled_creamer, scaled_chocolate);
    //     end
    // end
    // Synthesis translate_on
    
endmodule