//============================================================================
// Module: message_manager
// Description: LCD message generation and formatting for coffee machine UI
//              Generates appropriate messages based on menu state and system status
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
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
    
    // ASCII space character
    parameter SPACE = 8'h20;
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    reg [127:0] line1_text_next;
    reg [127:0] line2_text_next;
    reg [3:0] prev_menu_state;
    
    // Progress bar characters
    reg [7:0] progress_bar [0:15];  // 16 character progress bar
    
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
    // Helper Function: Create string (pack into 128 bits)
    //========================================================================
    
    function [127:0] create_string;
        input [8*16-1:0] str;  // 16 characters
        begin
            create_string = str;
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
        line1_text_next = {16{SPACE}};
        line2_text_next = {16{SPACE}};
        
        case (current_menu_state)
            
            //================================================================
            // SPLASH Screen
            //================================================================
            STATE_SPLASH: begin
                // Line 1: "Press Start"
                line1_text_next = {"P", "r", "e", "s", "s", " ", "S", "t", 
                                 "a", "r", "t", " ", " ", " ", " ", " "};
                
                // Line 2: Warning count or "Ready"
                if (warning_count > 0) begin
                    line2_text_next = {"W", "a", "r", "n", "i", "n", "g", "s", 
                                     ":", " ", num_to_ascii(warning_count), " ", 
                                     " ", " ", " ", " "};
                end else begin
                    line2_text_next = {"R", "e", "a", "d", "y", " ", " ", " ",
                                     " ", " ", " ", " ", " ", " ", " ", " "};
                end
            end
            
            //================================================================
            // CHECK ERRORS
            //================================================================
            STATE_CHECK_ERRORS: begin
                line1_text_next = {"C", "h", "e", "c", "k", "i", "n", "g", 
                                 ".", ".", ".", " ", " ", " ", " ", " "};
                line2_text_next = {"P", "l", "e", "a", "s", "e", " ", "w",
                                 "a", "i", "t", " ", " ", " ", " ", " "};
            end
            
            //================================================================
            // COFFEE SELECT
            //================================================================
            STATE_COFFEE_SELECT: begin
                // Line 1: "Coffee: [X]"
                if (selected_coffee_type == 0) begin
                    line1_text_next = {"C", "o", "f", "f", "e", "e", ":", " ",
                                     "[", "1", "]", " ", " ", " ", " ", " "};
                    
                    // Line 2: Show if unavailable
                    if (bin0_empty) begin
                        line2_text_next = {"E", "m", "p", "t", "y", "!", " ", " ",
                                         " ", " ", " ", " ", " ", " ", " ", " "};
                    end else if (bin0_low) begin
                        line2_text_next = {"L", "o", "w", " ", " ", " ", " ", " ",
                                         " ", " ", " ", " ", " ", " ", " ", " "};
                    end else begin
                        line2_text_next = {"<", "-", ">", " ", "S", "e", "l", "e",
                                         "c", "t", " ", " ", " ", " ", " ", " "};
                    end
                end else begin
                    line1_text_next = {"C", "o", "f", "f", "e", "e", ":", " ",
                                     "[", "2", "]", " ", " ", " ", " ", " "};
                    
                    if (bin1_empty) begin
                        line2_text_next = {"E", "m", "p", "t", "y", "!", " ", " ",
                                         " ", " ", " ", " ", " ", " ", " ", " "};
                    end else if (bin1_low) begin
                        line2_text_next = {"L", "o", "w", " ", " ", " ", " ", " ",
                                         " ", " ", " ", " ", " ", " ", " ", " "};
                    end else begin
                        line2_text_next = {"<", "-", ">", " ", "S", "e", "l", "e",
                                         "c", "t", " ", " ", " ", " ", " ", " "};
                    end
                end
            end
            
            //================================================================
            // DRINK SELECT
            //================================================================
            STATE_DRINK_SELECT: begin
                line1_text_next = {"D", "r", "i", "n", "k", ":", " ", " ",
                                 " ", " ", " ", " ", " ", " ", " ", " "};
                
                case (selected_drink_type)
                    DRINK_BLACK_COFFEE: begin
                        line1_text_next = {"D", "r", "i", "n", "k", ":", " ", "[",
                                         "B", "l", "a", "c", "k", "]", " ", " "};
                    end
                    DRINK_COFFEE_CREAM: begin
                        line1_text_next = {"D", "r", "i", "n", "k", ":", " ", "[",
                                         "C", "r", "e", "a", "m", "]", " ", " "};
                    end
                    DRINK_LATTE: begin
                        line1_text_next = {"D", "r", "i", "n", "k", ":", " ", "[",
                                         "L", "a", "t", "t", "e", "]", " ", " "};
                    end
                    DRINK_MOCHA: begin
                        line1_text_next = {"D", "r", "i", "n", "k", ":", " ", "[",
                                         "M", "o", "c", "h", "a", "]", " ", " "};
                    end
                    DRINK_HOT_CHOCOLATE: begin
                        line1_text_next = {"D", "r", "i", "n", "k", ":", " ", "[",
                                         "H", "o", "t", "C", "h", "o", "c", "o"};
                    end
                    default: begin
                        line1_text_next = {"D", "r", "i", "n", "k", ":", " ", "?",
                                         " ", " ", " ", " ", " ", " ", " ", " "};
                    end
                endcase
                
                line2_text_next = {"<", "-", ">", " ", "S", "e", "l", "e",
                                 "c", "t", " ", " ", " ", " ", " ", " "};
            end
            
            //================================================================
            // SIZE SELECT
            //================================================================
            STATE_SIZE_SELECT: begin
                case (selected_size)
                    SIZE_8OZ: begin
                        line1_text_next = {"S", "i", "z", "e", ":", " ", "[", "8",
                                         "o", "z", "]", " ", " ", " ", " ", " "};
                    end
                    SIZE_12OZ: begin
                        line1_text_next = {"S", "i", "z", "e", ":", " ", "[", "1",
                                         "2", "o", "z", "]", " ", " ", " ", " "};
                    end
                    SIZE_16OZ: begin
                        line1_text_next = {"S", "i", "z", "e", ":", " ", "[", "1",
                                         "6", "o", "z", "]", " ", " ", " ", " "};
                    end
                    default: begin
                        line1_text_next = {"S", "i", "z", "e", ":", " ", "?", " ",
                                         " ", " ", " ", " ", " ", " ", " ", " "};
                    end
                endcase
                
                line2_text_next = {"<", "-", ">", " ", "S", "e", "l", "e",
                                 "c", "t", " ", " ", " ", " ", " ", " "};
            end
            
            //================================================================
            // CONFIRM
            //================================================================
            STATE_CONFIRM: begin
                // Line 1: Brief drink name and size
                case (selected_drink_type)
                    DRINK_BLACK_COFFEE: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = {"B", "l", "a", "c", "k", " ", "8", "o", "z", " ", " ", " ", " ", " ", " ", " "};
                            SIZE_12OZ: line1_text_next = {"B", "l", "a", "c", "k", " ", "1", "2", "o", "z", " ", " ", " ", " ", " ", " "};
                            SIZE_16OZ: line1_text_next = {"B", "l", "a", "c", "k", " ", "1", "6", "o", "z", " ", " ", " ", " ", " ", " "};
                        endcase
                    end
                    DRINK_COFFEE_CREAM: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = {"C", "r", "e", "a", "m", " ", "8", "o", "z", " ", " ", " ", " ", " ", " ", " "};
                            SIZE_12OZ: line1_text_next = {"C", "r", "e", "a", "m", " ", "1", "2", "o", "z", " ", " ", " ", " ", " ", " "};
                            SIZE_16OZ: line1_text_next = {"C", "r", "e", "a", "m", " ", "1", "6", "o", "z", " ", " ", " ", " ", " ", " "};
                        endcase
                    end
                    DRINK_LATTE: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = {"L", "a", "t", "t", "e", " ", "8", "o", "z", " ", " ", " ", " ", " ", " ", " "};
                            SIZE_12OZ: line1_text_next = {"L", "a", "t", "t", "e", " ", "1", "2", "o", "z", " ", " ", " ", " ", " ", " "};
                            SIZE_16OZ: line1_text_next = {"L", "a", "t", "t", "e", " ", "1", "6", "o", "z", " ", " ", " ", " ", " ", " "};
                        endcase
                    end
                    DRINK_MOCHA: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = {"M", "o", "c", "h", "a", " ", "8", "o", "z", " ", " ", " ", " ", " ", " ", " "};
                            SIZE_12OZ: line1_text_next = {"M", "o", "c", "h", "a", " ", "1", "2", "o", "z", " ", " ", " ", " ", " ", " "};
                            SIZE_16OZ: line1_text_next = {"M", "o", "c", "h", "a", " ", "1", "6", "o", "z", " ", " ", " ", " ", " ", " "};
                        endcase
                    end
                    DRINK_HOT_CHOCOLATE: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = {"H", "o", "t", "C", "h", "o", "c", "o", " ", "8", "o", "z", " ", " ", " ", " "};
                            SIZE_12OZ: line1_text_next = {"H", "o", "t", "C", "h", "o", "c", "o", " ", "1", "2", "o", "z", " ", " ", " "};
                            SIZE_16OZ: line1_text_next = {"H", "o", "t", "C", "h", "o", "c", "o", " ", "1", "6", "o", "z", " ", " ", " "};
                        endcase
                    end
                endcase
                
                // Line 2: "Start? Cancel?"
                line2_text_next = {"S", "t", "a", "r", "t", "?", " ", "C",
                                 "a", "n", "c", "e", "l", "?", " ", " "};
            end
            
            //================================================================
            // BREWING
            //================================================================
            STATE_BREWING: begin
                // Line 1: "Brewing..."
                line1_text_next = {"B", "r", "e", "w", "i", "n", "g", ".",
                                 ".", ".", " ", " ", " ", " ", " ", " "};
                
                // Line 2: Progress bar
                line2_text_next = {progress_bar[0], progress_bar[1], progress_bar[2], progress_bar[3],
                                 progress_bar[4], progress_bar[5], progress_bar[6], progress_bar[7],
                                 progress_bar[8], progress_bar[9], progress_bar[10], progress_bar[11],
                                 progress_bar[12], progress_bar[13], progress_bar[14], progress_bar[15]};
            end
            
            //================================================================
            // COMPLETE
            //================================================================
            STATE_COMPLETE: begin
                // Line 1: "Enjoy!"
                line1_text_next = {"E", "n", "j", "o", "y", "!", " ", " ",
                                 " ", " ", " ", " ", " ", " ", " ", " "};
                
                // Line 2: "Press any key"
                line2_text_next = {"P", "r", "e", "s", "s", " ", "a", "n",
                                 "y", " ", "k", "e", "y", " ", " ", " "};
            end
            
            //================================================================
            // SETTINGS
            //================================================================
            STATE_SETTINGS: begin
                // Line 1: "Settings Mode"
                line1_text_next = {"S", "e", "t", "t", "i", "n", "g", "s",
                                 " ", "M", "o", "d", "e", " ", " ", " "};
                
                // Line 2: "Cancel to exit"
                line2_text_next = {"C", "a", "n", "c", "e", "l", " ", "t",
                                 "o", " ", "e", "x", "i", "t", " ", " "};
            end
            
            //================================================================
            // ERROR
            //================================================================
            STATE_ERROR: begin
                // Line 1: Error type
                if (!temp_ready) begin
                    line1_text_next = {"W", "A", "T", "E", "R", " ", "T", "E",
                                     "M", "P", "!", " ", " ", " ", " ", " "};
                end else if (!pressure_ready) begin
                    line1_text_next = {"W", "A", "T", "E", "R", " ", "E", "R",
                                     "R", "O", "R", "!", " ", " ", " ", " "};
                end else if (paper_empty) begin
                    line1_text_next = {"N", "O", " ", "P", "A", "P", "E", "R",
                                     "!", " ", " ", " ", " ", " ", " ", " "};
                end else if (bin0_empty && bin1_empty) begin
                    line1_text_next = {"N", "O", " ", "C", "O", "F", "F", "E",
                                     "E", "!", " ", " ", " ", " ", " ", " "};
                end else begin
                    line1_text_next = {"S", "Y", "S", "T", "E", "M", " ", "F",
                                     "A", "U", "L", "T", "!", " ", " ", " "};
                end
                
                // Line 2: "Fix and restart"
                line2_text_next = {"F", "i", "x", " ", "&", " ", "r", "e",
                                 "s", "t", "a", "r", "t", " ", " ", " "};
            end
            
            //================================================================
            // DEFAULT
            //================================================================
            default: begin
                line1_text_next = {"E", "R", "R", "O", "R", " ", " ", " ",
                                 " ", " ", " ", " ", " ", " ", " ", " "};
                line2_text_next = {16{SPACE}};
            end
            
        endcase
    end
    
    //========================================================================
    // Register Outputs and Detect Changes
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line1_text <= {16{SPACE}};
            line2_text <= {16{SPACE}};
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
    // Debug/Monitoring (Optional - removed during synthesis)
    //========================================================================
    
    // Synthesis translate_off
    // function [8*16-1:0] ascii_to_string;
    //     input [127:0] ascii_data;
    //     integer i;
    //     begin
    //         for (i = 0; i < 16; i = i + 1) begin
    //             ascii_to_string[8*i +: 8] = ascii_data[8*i +: 8];
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
    // Synthesis translate_on
    
endmodule