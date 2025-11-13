//============================================================================
// Module: lcd_controller
// Description: 16x2 Character LCD Controller with simple string interface
//              Supports HD44780-compatible LCDs
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module lcd_controller (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,                    // 50 MHz system clock
    input  wire         rst_n,                  // Active-low reset
    
    //========================================================================
    // String Interface (from system)
    //========================================================================
    input  wire [127:0] line1_data,             // Line 1: 16 characters (8 bits each)
    input  wire [127:0] line2_data,             // Line 2: 16 characters (8 bits each)
    input  wire         update_display,         // Pulse to update LCD
    
    //========================================================================
    // LCD Hardware Interface (to DE2-115 LCD)
    //========================================================================
    output reg          LCD_ON,                 // LCD power control
    output reg          LCD_BLON,               // Backlight control
    output reg          LCD_EN,                 // LCD enable signal
    output reg          LCD_RS,                 // Register select (0=cmd, 1=data)
    output reg          LCD_RW,                 // Read/Write (0=write, 1=read)
    output reg  [7:0]   LCD_DATA,               // 8-bit data bus
    
    //========================================================================
    // Status
    //========================================================================
    output reg          ready,                  // Ready for new data
    output reg          busy                    // Currently updating display
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Timing parameters (based on 50 MHz clock)
    parameter INIT_DELAY = 32'd2_500_000;       // 50ms for power-on init
    parameter CMD_DELAY = 32'd100_000;          // 2ms for commands
    parameter DATA_DELAY = 32'd2_500;           // 50us for data writes
    parameter EN_PULSE_WIDTH = 32'd500;         // 10us enable pulse
    
    // LCD Commands
    parameter CMD_CLEAR = 8'h01;                // Clear display
    parameter CMD_HOME = 8'h02;                 // Return home
    parameter CMD_ENTRY_MODE = 8'h06;           // Entry mode: increment, no shift
    parameter CMD_DISPLAY_ON = 8'h0C;           // Display on, cursor off, blink off
    parameter CMD_FUNCTION_SET = 8'h38;         // 8-bit, 2 lines, 5x8 font
    parameter CMD_SET_DDRAM_LINE1 = 8'h80;      // Set DDRAM address to line 1
    parameter CMD_SET_DDRAM_LINE2 = 8'hC0;      // Set DDRAM address to line 2
    
    //========================================================================
    // State Machine
    //========================================================================
    
    typedef enum logic [4:0] {
        IDLE,
        INIT_START,
        INIT_FUNCTION_SET1,
        INIT_FUNCTION_SET2,
        INIT_FUNCTION_SET3,
        INIT_DISPLAY_OFF,
        INIT_CLEAR,
        INIT_ENTRY_MODE,
        INIT_DISPLAY_ON,
        READY,
        CLEAR_DISPLAY,
        SET_LINE1_ADDR,
        WRITE_LINE1,
        SET_LINE2_ADDR,
        WRITE_LINE2,
        DONE
    } lcd_state_t;
    
    lcd_state_t state, next_state;
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    reg [31:0] delay_counter;
    reg [31:0] delay_target;
    reg [3:0]  char_index;              // Current character being written (0-15)
    reg [7:0]  current_char;            // Current character to write
    reg        en_pulse;                // Enable pulse flag
    
    // Store line data internally
    reg [127:0] line1_buffer;
    reg [127:0] line2_buffer;
    reg         update_pending;
    
    //========================================================================
    // State Machine - State Register
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    //========================================================================
    // Delay Counter
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_counter <= 0;
        end else begin
            if (state != next_state) begin
                // Reset counter on state change
                delay_counter <= 0;
            end else if (delay_counter < delay_target) begin
                delay_counter <= delay_counter + 1;
            end
        end
    end
    
    wire delay_done = (delay_counter >= delay_target);
    
    //========================================================================
    // Update Request Handling
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line1_buffer <= 0;
            line2_buffer <= 0;
            update_pending <= 1'b0;
        end else begin
            if (update_display && ready) begin
                // Capture new data
                line1_buffer <= line1_data;
                line2_buffer <= line2_data;
                update_pending <= 1'b1;
            end else if (state == READY && update_pending) begin
                // Clear pending flag when starting update
                update_pending <= 1'b0;
            end
        end
    end
    
    //========================================================================
    // State Machine - Next State Logic
    //========================================================================
    
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (delay_done) begin
                    next_state = INIT_START;
                end
            end
            
            INIT_START: begin
                if (delay_done) begin
                    next_state = INIT_FUNCTION_SET1;
                end
            end
            
            INIT_FUNCTION_SET1: begin
                if (delay_done && !en_pulse) begin
                    next_state = INIT_FUNCTION_SET2;
                end
            end
            
            INIT_FUNCTION_SET2: begin
                if (delay_done && !en_pulse) begin
                    next_state = INIT_FUNCTION_SET3;
                end
            end
            
            INIT_FUNCTION_SET3: begin
                if (delay_done && !en_pulse) begin
                    next_state = INIT_DISPLAY_OFF;
                end
            end
            
            INIT_DISPLAY_OFF: begin
                if (delay_done && !en_pulse) begin
                    next_state = INIT_CLEAR;
                end
            end
            
            INIT_CLEAR: begin
                if (delay_done && !en_pulse) begin
                    next_state = INIT_ENTRY_MODE;
                end
            end
            
            INIT_ENTRY_MODE: begin
                if (delay_done && !en_pulse) begin
                    next_state = INIT_DISPLAY_ON;
                end
            end
            
            INIT_DISPLAY_ON: begin
                if (delay_done && !en_pulse) begin
                    next_state = READY;
                end
            end
            
            READY: begin
                if (update_pending) begin
                    next_state = CLEAR_DISPLAY;
                end
            end
            
            CLEAR_DISPLAY: begin
                if (delay_done && !en_pulse) begin
                    next_state = SET_LINE1_ADDR;
                end
            end
            
            SET_LINE1_ADDR: begin
                if (delay_done && !en_pulse) begin
                    next_state = WRITE_LINE1;
                end
            end
            
            WRITE_LINE1: begin
                if (delay_done && !en_pulse) begin
                    if (char_index >= 15) begin
                        next_state = SET_LINE2_ADDR;
                    end
                    // else stay in WRITE_LINE1 for next character
                end
            end
            
            SET_LINE2_ADDR: begin
                if (delay_done && !en_pulse) begin
                    next_state = WRITE_LINE2;
                end
            end
            
            WRITE_LINE2: begin
                if (delay_done && !en_pulse) begin
                    if (char_index >= 15) begin
                        next_state = DONE;
                    end
                    // else stay in WRITE_LINE2 for next character
                end
            end
            
            DONE: begin
                next_state = READY;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //========================================================================
    // Character Index Management
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_index <= 0;
        end else begin
            case (state)
                SET_LINE1_ADDR: begin
                    char_index <= 0;
                end
                
                WRITE_LINE1: begin
                    if (delay_done && !en_pulse && char_index < 15) begin
                        char_index <= char_index + 1;
                    end
                end
                
                SET_LINE2_ADDR: begin
                    char_index <= 0;
                end
                
                WRITE_LINE2: begin
                    if (delay_done && !en_pulse && char_index < 15) begin
                        char_index <= char_index + 1;
                    end
                end
            endcase
        end
    end
    
    //========================================================================
    // Current Character Selection
    //========================================================================
    
    always @(*) begin
        case (char_index)
            4'd0:  current_char = line1_buffer[127:120];
            4'd1:  current_char = line1_buffer[119:112];
            4'd2:  current_char = line1_buffer[111:104];
            4'd3:  current_char = line1_buffer[103:96];
            4'd4:  current_char = line1_buffer[95:88];
            4'd5:  current_char = line1_buffer[87:80];
            4'd6:  current_char = line1_buffer[79:72];
            4'd7:  current_char = line1_buffer[71:64];
            4'd8:  current_char = line1_buffer[63:56];
            4'd9:  current_char = line1_buffer[55:48];
            4'd10: current_char = line1_buffer[47:40];
            4'd11: current_char = line1_buffer[39:32];
            4'd12: current_char = line1_buffer[31:24];
            4'd13: current_char = line1_buffer[23:16];
            4'd14: current_char = line1_buffer[15:8];
            4'd15: current_char = line1_buffer[7:0];
        endcase
        
        if (state == WRITE_LINE2) begin
            case (char_index)
                4'd0:  current_char = line2_buffer[127:120];
                4'd1:  current_char = line2_buffer[119:112];
                4'd2:  current_char = line2_buffer[111:104];
                4'd3:  current_char = line2_buffer[103:96];
                4'd4:  current_char = line2_buffer[95:88];
                4'd5:  current_char = line2_buffer[87:80];
                4'd6:  current_char = line2_buffer[79:72];
                4'd7:  current_char = line2_buffer[71:64];
                4'd8:  current_char = line2_buffer[63:56];
                4'd9:  current_char = line2_buffer[55:48];
                4'd10: current_char = line2_buffer[47:40];
                4'd11: current_char = line2_buffer[39:32];
                4'd12: current_char = line2_buffer[31:24];
                4'd13: current_char = line2_buffer[23:16];
                4'd14: current_char = line2_buffer[15:8];
                4'd15: current_char = line2_buffer[7:0];
            endcase
        end
    end
    
    //========================================================================
    // LCD Control Outputs
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            LCD_ON <= 1'b0;
            LCD_BLON <= 1'b0;
            LCD_EN <= 1'b0;
            LCD_RS <= 1'b0;
            LCD_RW <= 1'b0;
            LCD_DATA <= 8'h00;
            delay_target <= INIT_DELAY;
            en_pulse <= 1'b0;
            ready <= 1'b0;
            busy <= 1'b0;
        end else begin
            // Default: write mode
            LCD_RW <= 1'b0;
            
            case (state)
                IDLE: begin
                    LCD_ON <= 1'b1;
                    LCD_BLON <= 1'b1;
                    LCD_EN <= 1'b0;
                    LCD_RS <= 1'b0;
                    LCD_DATA <= 8'h00;
                    delay_target <= INIT_DELAY;
                    ready <= 1'b0;
                    busy <= 1'b1;
                end
                
                INIT_FUNCTION_SET1,
                INIT_FUNCTION_SET2,
                INIT_FUNCTION_SET3: begin
                    LCD_RS <= 1'b0;  // Command
                    LCD_DATA <= CMD_FUNCTION_SET;
                    delay_target <= CMD_DELAY;
                    
                    // Generate enable pulse
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                INIT_DISPLAY_OFF: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= 8'h08;  // Display off
                    delay_target <= CMD_DELAY;
                    
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                INIT_CLEAR: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_CLEAR;
                    delay_target <= CMD_DELAY;
                    
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                INIT_ENTRY_MODE: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_ENTRY_MODE;
                    delay_target <= CMD_DELAY;
                    
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                INIT_DISPLAY_ON: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_DISPLAY_ON;
                    delay_target <= CMD_DELAY;
                    
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                READY: begin
                    LCD_EN <= 1'b0;
                    LCD_RS <= 1'b0;
                    LCD_DATA <= 8'h00;
                    ready <= 1'b1;
                    busy <= 1'b0;
                end
                
                CLEAR_DISPLAY: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_CLEAR;
                    delay_target <= CMD_DELAY;
                    ready <= 1'b0;
                    busy <= 1'b1;
                    
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                SET_LINE1_ADDR: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_SET_DDRAM_LINE1;
                    delay_target <= DATA_DELAY;
                    
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                WRITE_LINE1: begin
                    LCD_RS <= 1'b1;  // Data
                    LCD_DATA <= current_char;
                    delay_target <= DATA_DELAY;
                    
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                SET_LINE2_ADDR: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_SET_DDRAM_LINE2;
                    delay_target <= DATA_DELAY;
                    
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                WRITE_LINE2: begin
                    LCD_RS <= 1'b1;  // Data
                    LCD_DATA <= current_char;
                    delay_target <= DATA_DELAY;
                    
                    if (delay_counter < EN_PULSE_WIDTH) begin
                        LCD_EN <= 1'b1;
                        en_pulse <= 1'b1;
                    end else begin
                        LCD_EN <= 1'b0;
                        en_pulse <= 1'b0;
                    end
                end
                
                DONE: begin
                    LCD_EN <= 1'b0;
                    LCD_RS <= 1'b0;
                    busy <= 1'b0;
                end
                
                default: begin
                    LCD_EN <= 1'b0;
                    LCD_RS <= 1'b0;
                    LCD_DATA <= 8'h00;
                end
            endcase
        end
    end
    
endmodule