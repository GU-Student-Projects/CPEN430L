//============================================================================
// Module: message_manager
// Description: LCD message generation and formatting for coffee machine UI
//              Generates appropriate messages based on menu state and system status
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
// Updated: Added SystemVerilog string handling for cleaner, more readable code
//============================================================================

`timescale 1ns/1ps

module message_manager (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,                    // 50 MHz system clock
    input  wire         rst_n,                  // Active-low reset
    
    //========================================================================
    // Menu State Inputs (from menu_navigator)
    //========================================================================
    input  wire [3:0]   current_menu_state,     // Current menu state
    input  wire [2:0]   selected_coffee_type,   // Selected coffee bin
    input  wire [2:0]   selected_drink_type,    // Selected drink type
    input  wire [1:0]   selected_size,          // Selected size
    
    //========================================================================
    // System Status Inputs
    //========================================================================
    input  wire [7:0]   brew_progress,          // Brewing progress 0-100%
    input  wire [3:0]   warning_count,          // Number of warnings
    input  wire         error_present,          // Critical error flag
    
    //========================================================================
    // Consumable Status (from consumable_manager)
    //========================================================================
    input  wire         bin0_empty,
    input  wire         bin0_low,
    input  wire         bin1_empty,
    input  wire         bin1_low,
    input  wire         creamer_empty,
    input  wire         creamer_low,
    input  wire         chocolate_empty,
    input  wire         chocolate_low,
    input  wire         paper_empty,
    input  wire         paper_low,
    
    //========================================================================
    // Water System Status (from water_temp_controller)
    //========================================================================
    input  wire         temp_ready,
    input  wire         pressure_ready,
    
    //========================================================================
    // LCD Display Output Interface
    //========================================================================
    output reg [127:0]  line1_text,             // Line 1 text (16 chars * 8 bits)
    output reg [127:0]  line2_text,             // Line 2 text (16 chars * 8 bits)
    output reg          message_updated         // Pulse when message changes
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Menu states (must match menu_navigator)
    parameter STATE_SPLASH = 4'd0;
    parameter STATE_CHECK_ERRORS = 4'd1;
    parameter STATE_COFFEE_SELECT = 4'd2;
    parameter STATE_DRINK_SELECT = 4'd3;
    parameter STATE_SIZE_SELECT = 4'd4;
    parameter STATE_CONFIRM = 4'd5;
    parameter STATE_BREWING = 4'd6;
    parameter STATE_COMPLETE = 4'd7;
    parameter STATE_SETTINGS = 4'd8;
    parameter STATE_ERROR = 4'd9;
    
    // Drink names (must match recipe_engine)
    parameter DRINK_BLACK_COFFEE = 3'd0;
    parameter DRINK_COFFEE_CREAM = 3'd1;
    parameter DRINK_LATTE = 3'd2;
    parameter DRINK_MOCHA = 3'd3;
    parameter DRINK_HOT_CHOCOLATE = 3'd4;
    
    // Size names
    parameter SIZE_8OZ = 2'd0;
    parameter SIZE_12OZ = 2'd1;
    parameter SIZE_16OZ = 2'd2;
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    reg [127:0] line1_text_next;
    reg [127:0] line2_text_next;
    reg [3:0] prev_menu_state;
    
    // Progress bar characters
    reg [7:0] progress_bar [0:15];  // 16 character progress bar
    
    //========================================================================
    // Helper Function: LCD String Converter
    // Converts a string literal to 128-bit LCD format with automatic padding
    //========================================================================
    
    function automatic [127:0] lcd_str;
        input string s;
        int i;
        byte unsigned c;
        begin
            // Initialize with spaces (ASCII 0x20)
            lcd_str = {16{8'h20}};
            
            // Copy string characters (up to 16 chars)
            for (i = 0; i < 16 && i < s.len(); i++) begin
                c = s[i];
                lcd_str[127-(i*8) -: 8] = c;
            end
        end
    endfunction
    
    //========================================================================
    // Helper Function: Convert number to ASCII
    //========================================================================
    
    function [7:0] num_to_ascii;
        input [7:0] num;
        begin
            if (num < 10)
                num_to_ascii = 8'h30 + num;  // '0' + num
            else
                num_to_ascii = 8'h20;  // Space if out of range
        end
    endfunction
    
    //========================================================================
    // Progress Bar Generator
    //========================================================================
    
    always @(*) begin
        integer i;
        integer filled_blocks;
        
        // Calculate how many blocks to fill (0-16)
        filled_blocks = (brew_progress * 16) / 100;
        
        // Generate progress bar
        for (i = 0; i < 16; i = i + 1) begin
            if (i < filled_blocks) begin
                progress_bar[i] = 8'h23;  // '#' character
            end else begin
                progress_bar[i] = 8'h2D;  // '-' character
            end
        end
    end
    
    //========================================================================
    // Message Generation Logic
    //========================================================================
    
    always @(*) begin
        // Default: blank lines
        line1_text_next = lcd_str("");
        line2_text_next = lcd_str("");
        
        case (current_menu_state)
            
            //================================================================
            // SPLASH Screen
            //================================================================
            STATE_SPLASH: begin
                line1_text_next = lcd_str("Press Start");
                
                // Show warning count or "Ready"
                if (warning_count > 0) begin
                    line2_text_next = lcd_str($sformatf("Warnings: %0d", warning_count));
                end else begin
                    line2_text_next = lcd_str("Ready");
                end
            end
            
            //================================================================
            // CHECK ERRORS
            //================================================================
            STATE_CHECK_ERRORS: begin
                line1_text_next = lcd_str("Checking...");
                line2_text_next = lcd_str("Please wait");
            end
            
            //================================================================
            // COFFEE SELECT
            //================================================================
            STATE_COFFEE_SELECT: begin
                // Show which coffee bin is selected
                if (selected_coffee_type == 0) begin
                    line1_text_next = lcd_str("Coffee: [1]");
                    
                    // Show availability status
                    if (bin0_empty) begin
                        line2_text_next = lcd_str("Empty!");
                    end else if (bin0_low) begin
                        line2_text_next = lcd_str("Low");
                    end else begin
                        line2_text_next = lcd_str("<-> Select");
                    end
                end else begin
                    line1_text_next = lcd_str("Coffee: [2]");
                    
                    if (bin1_empty) begin
                        line2_text_next = lcd_str("Empty!");
                    end else if (bin1_low) begin
                        line2_text_next = lcd_str("Low");
                    end else begin
                        line2_text_next = lcd_str("<-> Select");
                    end
                end
            end
            
            //================================================================
            // DRINK SELECT
            //================================================================
            STATE_DRINK_SELECT: begin
                case (selected_drink_type)
                    DRINK_BLACK_COFFEE: begin
                        line1_text_next = lcd_str("Drink: [Black]");
                    end
                    DRINK_COFFEE_CREAM: begin
                        line1_text_next = lcd_str("Drink: [Cream]");
                    end
                    DRINK_LATTE: begin
                        line1_text_next = lcd_str("Drink: [Latte]");
                    end
                    DRINK_MOCHA: begin
                        line1_text_next = lcd_str("Drink: [Mocha]");
                    end
                    DRINK_HOT_CHOCOLATE: begin
                        line1_text_next = lcd_str("Drink: [HotChoco");
                    end
                    default: begin
                        line1_text_next = lcd_str("Drink: ?");
                    end
                endcase
                
                line2_text_next = lcd_str("<-> Select");
            end
            
            //================================================================
            // SIZE SELECT
            //================================================================
            STATE_SIZE_SELECT: begin
                case (selected_size)
                    SIZE_8OZ: begin
                        line1_text_next = lcd_str("Size: [8oz]");
                    end
                    SIZE_12OZ: begin
                        line1_text_next = lcd_str("Size: [12oz]");
                    end
                    SIZE_16OZ: begin
                        line1_text_next = lcd_str("Size: [16oz]");
                    end
                    default: begin
                        line1_text_next = lcd_str("Size: ?");
                    end
                endcase
                
                line2_text_next = lcd_str("<-> Select");
            end
            
            //================================================================
            // CONFIRM
            //================================================================
            STATE_CONFIRM: begin
                // Line 1: Brief drink name and size
                case (selected_drink_type)
                    DRINK_BLACK_COFFEE: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("Black 8oz");
                            SIZE_12OZ: line1_text_next = lcd_str("Black 12oz");
                            SIZE_16OZ: line1_text_next = lcd_str("Black 16oz");
                            default:   line1_text_next = lcd_str("Black ?oz");
                        endcase
                    end
                    DRINK_COFFEE_CREAM: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("Cream 8oz");
                            SIZE_12OZ: line1_text_next = lcd_str("Cream 12oz");
                            SIZE_16OZ: line1_text_next = lcd_str("Cream 16oz");
                            default:   line1_text_next = lcd_str("Cream ?oz");
                        endcase
                    end
                    DRINK_LATTE: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("Latte 8oz");
                            SIZE_12OZ: line1_text_next = lcd_str("Latte 12oz");
                            SIZE_16OZ: line1_text_next = lcd_str("Latte 16oz");
                            default:   line1_text_next = lcd_str("Latte ?oz");
                        endcase
                    end
                    DRINK_MOCHA: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("Mocha 8oz");
                            SIZE_12OZ: line1_text_next = lcd_str("Mocha 12oz");
                            SIZE_16OZ: line1_text_next = lcd_str("Mocha 16oz");
                            default:   line1_text_next = lcd_str("Mocha ?oz");
                        endcase
                    end
                    DRINK_HOT_CHOCOLATE: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("HotChoco 8oz");
                            SIZE_12OZ: line1_text_next = lcd_str("HotChoco 12oz");
                            SIZE_16OZ: line1_text_next = lcd_str("HotChoco 16oz");
                            default:   line1_text_next = lcd_str("HotChoco ?oz");
                        endcase
                    end
                    default: begin
                        line1_text_next = lcd_str("??? ???");
                    end
                endcase
                
                // Line 2: Confirmation prompt
                line2_text_next = lcd_str("Start? Cancel?");
            end
            
            //================================================================
            // BREWING
            //================================================================
            STATE_BREWING: begin
                line1_text_next = lcd_str("Brewing...");
                
                // Line 2: Progress bar (needs special handling)
                line2_text_next = {progress_bar[0], progress_bar[1], progress_bar[2], progress_bar[3],
                                 progress_bar[4], progress_bar[5], progress_bar[6], progress_bar[7],
                                 progress_bar[8], progress_bar[9], progress_bar[10], progress_bar[11],
                                 progress_bar[12], progress_bar[13], progress_bar[14], progress_bar[15]};
            end
            
            //================================================================
            // COMPLETE
            //================================================================
            STATE_COMPLETE: begin
                line1_text_next = lcd_str("Enjoy!");
                line2_text_next = lcd_str("Press any key");
            end
            
            //================================================================
            // SETTINGS
            //================================================================
            STATE_SETTINGS: begin
                line1_text_next = lcd_str("Settings Mode");
                line2_text_next = lcd_str("Cancel to exit");
            end
            
            //================================================================
            // ERROR
            //================================================================
            STATE_ERROR: begin
                // Line 1: Error type
                if (!temp_ready) begin
                    line1_text_next = lcd_str("WATER TEMP!");
                end else if (!pressure_ready) begin
                    line1_text_next = lcd_str("WATER ERROR!");
                end else if (paper_empty) begin
                    line1_text_next = lcd_str("NO PAPER!");
                end else if (bin0_empty && bin1_empty) begin
                    line1_text_next = lcd_str("NO COFFEE!");
                end else begin
                    line1_text_next = lcd_str("SYSTEM FAULT!");
                end
                
                // Line 2: Instruction
                line2_text_next = lcd_str("Fix & restart");
            end
            
            //================================================================
            // DEFAULT
            //================================================================
            default: begin
                line1_text_next = lcd_str("ERROR");
                line2_text_next = lcd_str("");
            end
            
        endcase
    end
    
    //========================================================================
    // Register Outputs and Detect Changes
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line1_text <= lcd_str("");
            line2_text <= lcd_str("");
            prev_menu_state <= STATE_SPLASH;
            message_updated <= 1'b0;
        end else begin
            line1_text <= line1_text_next;
            line2_text <= line2_text_next;
            prev_menu_state <= current_menu_state;
            
            // Pulse message_updated when text changes
            message_updated <= (line1_text != line1_text_next) || 
                             (line2_text != line2_text_next);
        end
    end
    
    //========================================================================
    // Debug/Monitoring (Optional - synthesis directives handle sim vs synth)
    //========================================================================
    
    // synthesis translate_off
    // function string ascii_to_string;
    //     input [127:0] ascii_data;
    //     integer i;
    //     byte c;
    //     begin
    //         ascii_to_string = "";
    //         for (i = 0; i < 16; i = i + 1) begin
    //             c = ascii_data[127-(i*8) -: 8];
    //             ascii_to_string = {ascii_to_string, string'(c)};
    //         end
    //     end
    // endfunction
    
    // always @(posedge clk) begin
    //     if (message_updated) begin
    //         $display("[%0t] LCD Update:", $time);
    //         $display("  Line 1: %s", ascii_to_string(line1_text));
    //         $display("  Line 2: %s", ascii_to_string(line2_text));
    //     end
    // end
    // synthesis translate_on
    
endmodule