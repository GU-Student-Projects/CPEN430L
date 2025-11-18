//============================================================================
// Module: error_message_cycler
// Description: Cycles through error and warning messages with codes
//              Displays one error/warning at a time on LCD with error codes
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module error_message_cycler (
    input  wire         clk,
    input  wire         rst_n,
    
    // Enable cycling
    input  wire         cycle_enable,           // Enable message cycling
    
    // Error flags from error_handler
    input  wire         err_no_water,
    input  wire         err_no_paper,
    input  wire         err_no_coffee,
    input  wire         err_temp_fault,
    input  wire         err_pressure_fault,
    input  wire         err_system_fault,
    
    // Warning flags from error_handler
    input  wire         warn_paper_low,
    input  wire         warn_bin0_low,
    input  wire         warn_bin1_low,
    input  wire         warn_creamer_low,
    input  wire         warn_chocolate_low,
    input  wire         warn_temp_heating,
    
    // Consumable info for specific messages
    input  wire         bin0_empty,
    input  wire         bin1_empty,
    
    // Outputs
    output reg [127:0]  line1_text,             // LCD line 1
    output reg [127:0]  line2_text,             // LCD line 2
    output reg          message_updated,        // Pulse when message changes
    output reg [3:0]    current_message_index   // Current message being displayed (for debug)
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Cycle timing - 2 seconds per message at 50MHz
    parameter CYCLE_TIME = 32'd100_000_000;
    
    // Error codes (priority order)
    parameter ERROR_COUNT = 4'd6;
    parameter WARNING_COUNT = 4'd6;
    parameter MAX_MESSAGES = 4'd12;
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    reg [31:0] cycle_timer;
    reg [3:0] message_index;
    reg [127:0] line1_next;
    reg [127:0] line2_next;
    
    // Track active errors and warnings
    reg [5:0] active_errors;      // Bitmap of active errors
    reg [5:0] active_warnings;    // Bitmap of active warnings
    reg [3:0] total_messages;     // Total number of messages to cycle through
    
    //========================================================================
    // Helper Function - Create LCD String
    //========================================================================
    
    function automatic [127:0] lcd_str;
        input string s;
        int i;
        byte unsigned c;
        begin
            lcd_str = {16{8'h20}};  // Fill with spaces
            for (i = 0; i < 16 && i < s.len(); i++) begin
                c = s[i];
                lcd_str[127-(i*8) -: 8] = c;
            end
        end
    endfunction
    
    //========================================================================
    // Build Active Message Bitmap
    //========================================================================
    
    always @(*) begin
        // Build error bitmap (bit position = error number)
        active_errors[0] = err_no_water;
        active_errors[1] = err_no_paper;
        active_errors[2] = err_no_coffee;
        active_errors[3] = err_temp_fault;
        active_errors[4] = err_pressure_fault;
        active_errors[5] = err_system_fault;
        
        // Build warning bitmap
        active_warnings[0] = warn_paper_low;
        active_warnings[1] = warn_bin0_low;
        active_warnings[2] = warn_bin1_low;
        active_warnings[3] = warn_creamer_low;
        active_warnings[4] = warn_chocolate_low;
        active_warnings[5] = warn_temp_heating;
        
        // Count total active messages
        total_messages = count_bits(active_errors) + count_bits(active_warnings);
    end
    
    // Function to count set bits
    function automatic [3:0] count_bits;
        input [5:0] bitmap;
        integer i;
        begin
            count_bits = 0;
            for (i = 0; i < 6; i = i + 1) begin
                if (bitmap[i]) count_bits = count_bits + 1;
            end
        end
    endfunction
    
    //========================================================================
    // Cycle Timer
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_timer <= 0;
            message_index <= 0;
        end else begin
            if (!cycle_enable || total_messages == 0) begin
                // Not cycling or no messages
                cycle_timer <= 0;
                message_index <= 0;
            end else begin
                if (cycle_timer >= CYCLE_TIME - 1) begin
                    // Time to switch to next message
                    cycle_timer <= 0;
                    
                    // Find next active message
                    message_index <= get_next_message_index(message_index, active_errors, active_warnings);
                end else begin
                    cycle_timer <= cycle_timer + 1;
                end
            end
        end
    end
    
    //========================================================================
    // Get Next Active Message Index
    //========================================================================
    
    function automatic [3:0] get_next_message_index;
        input [3:0] current_idx;
        input [5:0] errors;
        input [5:0] warnings;
        integer i;
        integer search_idx;
        reg found;
        begin
            // Search for next active message starting from current_idx + 1
            found = 0;
            get_next_message_index = 0;
            
            // Start search from next position
            search_idx = current_idx + 1;
            
            // Search through all possible messages (errors first, then warnings)
            for (i = 0; i < MAX_MESSAGES && !found; i = i + 1) begin
                if (search_idx >= MAX_MESSAGES) search_idx = 0;
                
                // Check if this message is active
                if (search_idx < 6) begin
                    // Error message
                    if (errors[search_idx]) begin
                        get_next_message_index = search_idx;
                        found = 1;
                    end
                end else begin
                    // Warning message
                    if (warnings[search_idx - 6]) begin
                        get_next_message_index = search_idx;
                        found = 1;
                    end
                end
                
                search_idx = search_idx + 1;
            end
            
            // If nothing found, stay at current
            if (!found) get_next_message_index = current_idx;
        end
    endfunction
    
    //========================================================================
    // Message Generation
    //========================================================================
    
    always @(*) begin
        // Default: blank
        line1_next = lcd_str("");
        line2_next = lcd_str("");
        
        if (!cycle_enable || total_messages == 0) begin
            // Not cycling - show nothing or default message
            line1_next = lcd_str("System Ready");
            line2_next = lcd_str("Press Start");
        end else begin
            // Show message based on current index
            case (message_index)
                // ============ ERRORS ============
                4'd0: begin  // E01: No Water / Pressure Error
                    if (err_no_water) begin
                        line1_next = lcd_str("E01: No Water");
                        line2_next = lcd_str("Check Pressure!");
                    end
                end
                
                4'd1: begin  // E02: No Paper Filter
                    if (err_no_paper) begin
                        line1_next = lcd_str("E02: No Paper");
                        line2_next = lcd_str("Insert Filter!");
                    end
                end
                
                4'd2: begin  // E03: No Coffee
                    if (err_no_coffee) begin
                        if (bin0_empty && bin1_empty) begin
                            line1_next = lcd_str("E03: No Coffee");
                            line2_next = lcd_str("Refill Both Bins");
                        end else if (bin0_empty) begin
                            line1_next = lcd_str("E03: Bin 0 Empty");
                            line2_next = lcd_str("Use Bin 1");
                        end else if (bin1_empty) begin
                            line1_next = lcd_str("E03: Bin 1 Empty");
                            line2_next = lcd_str("Use Bin 0");
                        end
                    end
                end
                
                4'd3: begin  // E04: Temperature Fault
                    if (err_temp_fault) begin
                        line1_next = lcd_str("E04: Temp Fault");
                        line2_next = lcd_str("Check Heater!");
                    end
                end
                
                4'd4: begin  // E05: Pressure Fault
                    if (err_pressure_fault) begin
                        line1_next = lcd_str("E05: Press Fault");
                        line2_next = lcd_str("Check Water Sys");
                    end
                end
                
                4'd5: begin  // E06: System Fault
                    if (err_system_fault) begin
                        line1_next = lcd_str("E06: System Err");
                        line2_next = lcd_str("Service Required");
                    end
                end
                
                // ============ WARNINGS ============
                4'd6: begin  // W01: Paper Low
                    if (warn_paper_low) begin
                        line1_next = lcd_str("W01: Paper Low");
                        line2_next = lcd_str("Refill Soon");
                    end
                end
                
                4'd7: begin  // W02: Bin 0 Low
                    if (warn_bin0_low) begin
                        line1_next = lcd_str("W02: Bin 0 Low");
                        line2_next = lcd_str("Refill Soon");
                    end
                end
                
                4'd8: begin  // W03: Bin 1 Low
                    if (warn_bin1_low) begin
                        line1_next = lcd_str("W03: Bin 1 Low");
                        line2_next = lcd_str("Refill Soon");
                    end
                end
                
                4'd9: begin  // W04: Creamer Low
                    if (warn_creamer_low) begin
                        line1_next = lcd_str("W04: Creamer Low");
                        line2_next = lcd_str("Refill Soon");
                    end
                end
                
                4'd10: begin  // W05: Chocolate Low
                    if (warn_chocolate_low) begin
                        line1_next = lcd_str("W05: Choco Low");
                        line2_next = lcd_str("Refill Soon");
                    end
                end
                
                4'd11: begin  // W06: Temperature Heating
                    if (warn_temp_heating) begin
                        line1_next = lcd_str("W06: Heating");
                        line2_next = lcd_str("Please Wait...");
                    end
                end
                
                default: begin
                    line1_next = lcd_str("System Ready");
                    line2_next = lcd_str("Press Start");
                end
            endcase
        end
    end
    
    //========================================================================
    // Register Outputs and Generate Update Pulse
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line1_text <= lcd_str("");
            line2_text <= lcd_str("");
            message_updated <= 1'b0;
            current_message_index <= 0;
        end else begin
            // Detect change
            message_updated <= (line1_text != line1_next) || (line2_text != line2_next);
            
            // Update outputs
            line1_text <= line1_next;
            line2_text <= line2_next;
            current_message_index <= message_index;
        end
    end

endmodule