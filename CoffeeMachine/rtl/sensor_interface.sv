//============================================================================
// Module: sensor_interface
// Description: Sensor interface with switch debouncing and LED control
//              Simulates coffee machine sensors using DE2-115 switches/LEDs
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module sensor_interface (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,            // 50 MHz system clock
    input  wire         rst_n,          // Active-low reset
    
    //========================================================================
    // Switch Inputs (Raw - from DE2-115 board)
    //========================================================================
    input  wire         sw_paper_filter,        // SW[0]: Paper filter present
    input  wire [1:0]   sw_coffee_bin0,         // SW[1-2]: Coffee bin 0 control
    input  wire [1:0]   sw_coffee_bin1,         // SW[3-4]: Coffee bin 1 control
    input  wire [1:0]   sw_creamer,             // SW[5-6]: Creamer control
    input  wire [1:0]   sw_chocolate,           // SW[7-8]: Chocolate control
    input  wire         sw_water_pressure_ovr,  // SW[9]: Water pressure override
    input  wire         sw_water_temp_ovr,      // SW[10]: Water temp override
    input  wire         sw_system_error,        // SW[11]: System error simulation
    
    //========================================================================
    // LED Outputs (Status indicators)
    //========================================================================
    output reg          led_paper_filter,       // LED[0]: Paper filter status
    output reg          led_coffee_bin0,        // LED[1]: Coffee bin 0 status
    output reg          led_coffee_bin1,        // LED[2]: Coffee bin 1 status
    output reg          led_creamer,            // LED[3]: Creamer status
    output reg          led_chocolate,          // LED[4]: Chocolate status
    output reg          led_water_pressure,     // LED[5]: Water pressure status
    output reg          led_water_temp,         // LED[6]: Water temp status
    output reg          led_system_error,       // LED[7]: System error status
    
    //========================================================================
    // Debounced Sensor Outputs (to system)
    //========================================================================
    output reg          paper_filter_present,   // Debounced paper filter sensor
    output reg [7:0]    coffee_bin0_level,      // Coffee bin 0 level (0-255)
    output reg [7:0]    coffee_bin1_level,      // Coffee bin 1 level (0-255)
    output reg [7:0]    creamer_level,          // Creamer level (0-255)
    output reg [7:0]    chocolate_level,        // Chocolate level (0-255)
    output reg          water_pressure_ok,      // Water pressure in range
    output reg          water_temp_ready,       // Water temperature ready
    output reg          system_fault            // Hardware fault detected
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Debouncing parameters
    parameter DEBOUNCE_TIME = 20;  // 20ms debounce time
    parameter DEBOUNCE_CYCLES = (DEBOUNCE_TIME * 50_000); // 50MHz clock
    
    // Consumable level thresholds
    parameter LEVEL_FULL = 255;
    parameter LEVEL_LOW_THRESHOLD = 50;
    parameter LEVEL_EMPTY = 0;
    
    // LED blink rate for warnings (2Hz)
    parameter BLINK_CYCLES = 25_000_000;  // 0.5 second at 50MHz
    
    //========================================================================
    // Internal Signals
    //========================================================================
    
    // Debounce counters
    reg [19:0] debounce_cnt_paper;
    reg [19:0] debounce_cnt_bin0_fill;
    reg [19:0] debounce_cnt_bin0_empty;
    reg [19:0] debounce_cnt_bin1_fill;
    reg [19:0] debounce_cnt_bin1_empty;
    reg [19:0] debounce_cnt_cream_fill;
    reg [19:0] debounce_cnt_cream_empty;
    reg [19:0] debounce_cnt_choc_fill;
    reg [19:0] debounce_cnt_choc_empty;
    reg [19:0] debounce_cnt_pressure;
    reg [19:0] debounce_cnt_temp;
    reg [19:0] debounce_cnt_error;
    
    // Debounced switch values
    reg paper_filter_db;
    reg bin0_fill_db, bin0_empty_db;
    reg bin1_fill_db, bin1_empty_db;
    reg cream_fill_db, cream_empty_db;
    reg choc_fill_db, choc_empty_db;
    reg pressure_ovr_db;
    reg temp_ovr_db;
    reg system_error_db;
    
    // LED blink control
    reg [24:0] blink_counter;
    reg blink_state;
    
    //========================================================================
    // LED Blink Generator (2Hz for warning indicators)
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            blink_counter <= 0;
            blink_state <= 0;
        end else begin
            if (blink_counter >= BLINK_CYCLES - 1) begin
                blink_counter <= 0;
                blink_state <= ~blink_state;
            end else begin
                blink_counter <= blink_counter + 1;
            end
        end
    end
    
    //========================================================================
    // Switch Debouncing Logic
    //========================================================================
    
    // Paper filter debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_paper <= 0;
            paper_filter_db <= 0;
        end else begin
            if (sw_paper_filter == paper_filter_db) begin
                debounce_cnt_paper <= 0;
            end else begin
                if (debounce_cnt_paper >= DEBOUNCE_CYCLES - 1) begin
                    paper_filter_db <= sw_paper_filter;
                    debounce_cnt_paper <= 0;
                end else begin
                    debounce_cnt_paper <= debounce_cnt_paper + 1;
                end
            end
        end
    end
    
    // Coffee Bin 0 - Fill switch debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_bin0_fill <= 0;
            bin0_fill_db <= 0;
        end else begin
            if (sw_coffee_bin0[0] == bin0_fill_db) begin
                debounce_cnt_bin0_fill <= 0;
            end else begin
                if (debounce_cnt_bin0_fill >= DEBOUNCE_CYCLES - 1) begin
                    bin0_fill_db <= sw_coffee_bin0[0];
                    debounce_cnt_bin0_fill <= 0;
                end else begin
                    debounce_cnt_bin0_fill <= debounce_cnt_bin0_fill + 1;
                end
            end
        end
    end
    
    // Coffee Bin 0 - Empty switch debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_bin0_empty <= 0;
            bin0_empty_db <= 0;
        end else begin
            if (sw_coffee_bin0[1] == bin0_empty_db) begin
                debounce_cnt_bin0_empty <= 0;
            end else begin
                if (debounce_cnt_bin0_empty >= DEBOUNCE_CYCLES - 1) begin
                    bin0_empty_db <= sw_coffee_bin0[1];
                    debounce_cnt_bin0_empty <= 0;
                end else begin
                    debounce_cnt_bin0_empty <= debounce_cnt_bin0_empty + 1;
                end
            end
        end
    end
    
    // Coffee Bin 1 - Fill switch debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_bin1_fill <= 0;
            bin1_fill_db <= 0;
        end else begin
            if (sw_coffee_bin1[0] == bin1_fill_db) begin
                debounce_cnt_bin1_fill <= 0;
            end else begin
                if (debounce_cnt_bin1_fill >= DEBOUNCE_CYCLES - 1) begin
                    bin1_fill_db <= sw_coffee_bin1[0];
                    debounce_cnt_bin1_fill <= 0;
                end else begin
                    debounce_cnt_bin1_fill <= debounce_cnt_bin1_fill + 1;
                end
            end
        end
    end
    
    // Coffee Bin 1 - Empty switch debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_bin1_empty <= 0;
            bin1_empty_db <= 0;
        end else begin
            if (sw_coffee_bin1[1] == bin1_empty_db) begin
                debounce_cnt_bin1_empty <= 0;
            end else begin
                if (debounce_cnt_bin1_empty >= DEBOUNCE_CYCLES - 1) begin
                    bin1_empty_db <= sw_coffee_bin1[1];
                    debounce_cnt_bin1_empty <= 0;
                end else begin
                    debounce_cnt_bin1_empty <= debounce_cnt_bin1_empty + 1;
                end
            end
        end
    end
    
    // Creamer - Fill switch debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_cream_fill <= 0;
            cream_fill_db <= 0;
        end else begin
            if (sw_creamer[0] == cream_fill_db) begin
                debounce_cnt_cream_fill <= 0;
            end else begin
                if (debounce_cnt_cream_fill >= DEBOUNCE_CYCLES - 1) begin
                    cream_fill_db <= sw_creamer[0];
                    debounce_cnt_cream_fill <= 0;
                end else begin
                    debounce_cnt_cream_fill <= debounce_cnt_cream_fill + 1;
                end
            end
        end
    end
    
    // Creamer - Empty switch debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_cream_empty <= 0;
            cream_empty_db <= 0;
        end else begin
            if (sw_creamer[1] == cream_empty_db) begin
                debounce_cnt_cream_empty <= 0;
            end else begin
                if (debounce_cnt_cream_empty >= DEBOUNCE_CYCLES - 1) begin
                    cream_empty_db <= sw_creamer[1];
                    debounce_cnt_cream_empty <= 0;
                end else begin
                    debounce_cnt_cream_empty <= debounce_cnt_cream_empty + 1;
                end
            end
        end
    end
    
    // Chocolate - Fill switch debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_choc_fill <= 0;
            choc_fill_db <= 0;
        end else begin
            if (sw_chocolate[0] == choc_fill_db) begin
                debounce_cnt_choc_fill <= 0;
            end else begin
                if (debounce_cnt_choc_fill >= DEBOUNCE_CYCLES - 1) begin
                    choc_fill_db <= sw_chocolate[0];
                    debounce_cnt_choc_fill <= 0;
                end else begin
                    debounce_cnt_choc_fill <= debounce_cnt_choc_fill + 1;
                end
            end
        end
    end
    
    // Chocolate - Empty switch debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_choc_empty <= 0;
            choc_empty_db <= 0;
        end else begin
            if (sw_chocolate[1] == choc_empty_db) begin
                debounce_cnt_choc_empty <= 0;
            end else begin
                if (debounce_cnt_choc_empty >= DEBOUNCE_CYCLES - 1) begin
                    choc_empty_db <= sw_chocolate[1];
                    debounce_cnt_choc_empty <= 0;
                end else begin
                    debounce_cnt_choc_empty <= debounce_cnt_choc_empty + 1;
                end
            end
        end
    end
    
    // Water pressure override debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_pressure <= 0;
            pressure_ovr_db <= 0;
        end else begin
            if (sw_water_pressure_ovr == pressure_ovr_db) begin
                debounce_cnt_pressure <= 0;
            end else begin
                if (debounce_cnt_pressure >= DEBOUNCE_CYCLES - 1) begin
                    pressure_ovr_db <= sw_water_pressure_ovr;
                    debounce_cnt_pressure <= 0;
                end else begin
                    debounce_cnt_pressure <= debounce_cnt_pressure + 1;
                end
            end
        end
    end
    
    // Water temperature override debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_temp <= 0;
            temp_ovr_db <= 0;
        end else begin
            if (sw_water_temp_ovr == temp_ovr_db) begin
                debounce_cnt_temp <= 0;
            end else begin
                if (debounce_cnt_temp >= DEBOUNCE_CYCLES - 1) begin
                    temp_ovr_db <= sw_water_temp_ovr;
                    debounce_cnt_temp <= 0;
                end else begin
                    debounce_cnt_temp <= debounce_cnt_temp + 1;
                end
            end
        end
    end
    
    // System error debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_error <= 0;
            system_error_db <= 0;
        end else begin
            if (sw_system_error == system_error_db) begin
                debounce_cnt_error <= 0;
            end else begin
                if (debounce_cnt_error >= DEBOUNCE_CYCLES - 1) begin
                    system_error_db <= sw_system_error;
                    debounce_cnt_error <= 0;
                end else begin
                    debounce_cnt_error <= debounce_cnt_error + 1;
                end
            end
        end
    end
    
    //========================================================================
    // Sensor Output Logic
    //========================================================================
    
    // Paper filter sensor (simple binary)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            paper_filter_present <= 1'b0;
        end else begin
            paper_filter_present <= paper_filter_db;
        end
    end
    
    // Coffee Bin 0 level management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coffee_bin0_level <= LEVEL_FULL;
        end else begin
            if (bin0_fill_db) begin
                coffee_bin0_level <= LEVEL_FULL;  // Fill maintains max level
            end else if (bin0_empty_db) begin
                coffee_bin0_level <= LEVEL_EMPTY;  // Empty forces zero
            end
            // Note: Natural depletion will be handled by consumable_manager
        end
    end
    
    // Coffee Bin 1 level management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coffee_bin1_level <= LEVEL_FULL;
        end else begin
            if (bin1_fill_db) begin
                coffee_bin1_level <= LEVEL_FULL;
            end else if (bin1_empty_db) begin
                coffee_bin1_level <= LEVEL_EMPTY;
            end
        end
    end
    
    // Creamer level management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            creamer_level <= LEVEL_FULL;
        end else begin
            if (cream_fill_db) begin
                creamer_level <= LEVEL_FULL;
            end else if (cream_empty_db) begin
                creamer_level <= LEVEL_EMPTY;
            end
        end
    end
    
    // Chocolate level management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chocolate_level <= LEVEL_FULL;
        end else begin
            if (choc_fill_db) begin
                chocolate_level <= LEVEL_FULL;
            end else if (choc_empty_db) begin
                chocolate_level <= LEVEL_EMPTY;
            end
        end
    end
    
    // Water pressure status (override forces error)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            water_pressure_ok <= 1'b1;  // Default: OK
        end else begin
            water_pressure_ok <= ~pressure_ovr_db;  // Override forces NOT OK
        end
    end
    
    // Water temperature status (override forces cold)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            water_temp_ready <= 1'b1;  // Default: Ready
        end else begin
            water_temp_ready <= ~temp_ovr_db;  // Override forces NOT ready
        end
    end
    
    // System fault detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            system_fault <= 1'b0;
        end else begin
            system_fault <= system_error_db;
        end
    end
    
    //========================================================================
    // LED Control Logic
    //========================================================================
    
    // Paper filter LED (binary: ON=present, OFF=absent)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_paper_filter <= 1'b0;
        end else begin
            led_paper_filter <= paper_filter_present;
        end
    end
    
    // Coffee Bin 0 LED (OFF=Full, BLINK=Low, SOLID=Empty)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_coffee_bin0 <= 1'b0;
        end else begin
            if (coffee_bin0_level == LEVEL_EMPTY || coffee_bin0_level < LEVEL_LOW_THRESHOLD) begin
                led_coffee_bin0 <= 1'b1;  // Solid ON for empty
            end else if (coffee_bin0_level < 200) begin
                led_coffee_bin0 <= blink_state;  // Blink for low
            end else begin
                led_coffee_bin0 <= 1'b0;  // OFF for full
            end
        end
    end
    
    // Coffee Bin 1 LED (OFF=Full, BLINK=Low, SOLID=Empty)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_coffee_bin1 <= 1'b0;
        end else begin
            if (coffee_bin1_level == LEVEL_EMPTY || coffee_bin1_level < LEVEL_LOW_THRESHOLD) begin
                led_coffee_bin1 <= 1'b1;
            end else if (coffee_bin1_level < 200) begin
                led_coffee_bin1 <= blink_state;
            end else begin
                led_coffee_bin1 <= 1'b0;
            end
        end
    end
    
    // Creamer LED (OFF=Full, BLINK=Low, SOLID=Empty)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_creamer <= 1'b0;
        end else begin
            if (creamer_level == LEVEL_EMPTY || creamer_level < LEVEL_LOW_THRESHOLD) begin
                led_creamer <= 1'b1;
            end else if (creamer_level < 200) begin
                led_creamer <= blink_state;
            end else begin
                led_creamer <= 1'b0;
            end
        end
    end
    
    // Chocolate LED (OFF=Full, BLINK=Low, SOLID=Empty)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_chocolate <= 1'b0;
        end else begin
            if (chocolate_level == LEVEL_EMPTY || chocolate_level < LEVEL_LOW_THRESHOLD) begin
                led_chocolate <= 1'b1;
            end else if (chocolate_level < 200) begin
                led_chocolate <= blink_state;
            end else begin
                led_chocolate <= 1'b0;
            end
        end
    end
    
    // Water pressure LED (ON=error)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_water_pressure <= 1'b0;
        end else begin
            led_water_pressure <= ~water_pressure_ok;
        end
    end
    
    // Water temperature LED (ON=not ready)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_water_temp <= 1'b0;
        end else begin
            led_water_temp <= ~water_temp_ready;
        end
    end
    
    // System error LED (ON=fault)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_system_error <= 1'b0;
        end else begin
            led_system_error <= system_fault;
        end
    end

endmodule