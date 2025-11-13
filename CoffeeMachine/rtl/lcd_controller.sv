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
    // Parameters - CRITICAL: Proper HD44780 Timing
    //========================================================================
    
    // Timing parameters (based on 50 MHz clock = 20ns period)
    // HD44780 requires MINIMUM delays - we use generous safety margins
    parameter POWER_ON_DELAY = 32'd3_750_000;   // 75ms power-on wait (spec: >40ms)
    parameter LONG_DELAY = 32'd100_000;         // 2ms for Clear/Home (spec: 1.52ms)
    parameter SHORT_DELAY = 32'd2_500;          // 50us for other commands (spec: 37us)
    parameter ENABLE_HIGH = 32'd15_000;         // 300us enable high time (spec: 230ns min)
    parameter ENABLE_LOW = 32'd15_000;          // 300us enable low time (spec: 500ns min)
    
    // LCD Commands
    parameter CMD_CLEAR = 8'h01;                // Clear display
    parameter CMD_HOME = 8'h02;                 // Return home
    parameter CMD_ENTRY_MODE = 8'h06;           // Entry mode: increment, no shift
    parameter CMD_DISPLAY_OFF = 8'h08;          // Display off
    parameter CMD_DISPLAY_ON = 8'h0C;           // Display on, cursor off, blink off
    parameter CMD_FUNCTION_SET = 8'h38;         // 8-bit, 2 lines, 5x8 font
    parameter CMD_SET_DDRAM_LINE1 = 8'h80;      // Set DDRAM address to line 1 start
    parameter CMD_SET_DDRAM_LINE2 = 8'hC0;      // Set DDRAM address to line 2 start
    
    //========================================================================
    // State Machine - Enhanced for proper timing
    //========================================================================
    
    typedef enum logic [4:0] {
        IDLE,
        POWER_ON_WAIT,
        // Initialization sequence
        INIT_FUNCTION_SET1,
        INIT_WAIT1,
        INIT_FUNCTION_SET2,
        INIT_WAIT2,
        INIT_FUNCTION_SET3,
        INIT_WAIT3,
        INIT_DISPLAY_OFF,
        INIT_WAIT4,
        INIT_CLEAR,
        INIT_WAIT5,
        INIT_ENTRY_MODE,
        INIT_WAIT6,
        INIT_DISPLAY_ON,
        INIT_WAIT7,
        // Ready and display update states
        READY,
        CLEAR_DISPLAY,
        WAIT_CLEAR,
        SET_LINE1_ADDR,
        WAIT_LINE1_ADDR,
        WRITE_LINE1,
        WAIT_WRITE1,
        SET_LINE2_ADDR,
        WAIT_LINE2_ADDR,
        WRITE_LINE2,
        WAIT_WRITE2,
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
            if (update_display && ready && !update_pending) begin
                // Capture new data
                line1_buffer <= line1_data;
                line2_buffer <= line2_data;
                update_pending <= 1'b1;
            end else if (state == READY && next_state == CLEAR_DISPLAY) begin
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
            IDLE: next_state = POWER_ON_WAIT;
            
            POWER_ON_WAIT: if (delay_done) next_state = INIT_FUNCTION_SET1;
            
            // Initialization with proper wait states
            INIT_FUNCTION_SET1: if (delay_done) next_state = INIT_WAIT1;
            INIT_WAIT1: if (delay_done) next_state = INIT_FUNCTION_SET2;
            INIT_FUNCTION_SET2: if (delay_done) next_state = INIT_WAIT2;
            INIT_WAIT2: if (delay_done) next_state = INIT_FUNCTION_SET3;
            INIT_FUNCTION_SET3: if (delay_done) next_state = INIT_WAIT3;
            INIT_WAIT3: if (delay_done) next_state = INIT_DISPLAY_OFF;
            INIT_DISPLAY_OFF: if (delay_done) next_state = INIT_WAIT4;
            INIT_WAIT4: if (delay_done) next_state = INIT_CLEAR;
            INIT_CLEAR: if (delay_done) next_state = INIT_WAIT5;
            INIT_WAIT5: if (delay_done) next_state = INIT_ENTRY_MODE;
            INIT_ENTRY_MODE: if (delay_done) next_state = INIT_WAIT6;
            INIT_WAIT6: if (delay_done) next_state = INIT_DISPLAY_ON;
            INIT_DISPLAY_ON: if (delay_done) next_state = INIT_WAIT7;
            INIT_WAIT7: if (delay_done) next_state = READY;
            
            READY: if (update_pending) next_state = CLEAR_DISPLAY;
            
            CLEAR_DISPLAY: if (delay_done) next_state = WAIT_CLEAR;
            WAIT_CLEAR: if (delay_done) next_state = SET_LINE1_ADDR;
            SET_LINE1_ADDR: if (delay_done) next_state = WAIT_LINE1_ADDR;
            WAIT_LINE1_ADDR: if (delay_done) next_state = WRITE_LINE1;
            WRITE_LINE1: if (delay_done) next_state = WAIT_WRITE1;
            WAIT_WRITE1: begin
                if (delay_done) begin
                    if (char_index >= 15) next_state = SET_LINE2_ADDR;
                    else next_state = WRITE_LINE1;
                end
            end
            
            SET_LINE2_ADDR: if (delay_done) next_state = WAIT_LINE2_ADDR;
            WAIT_LINE2_ADDR: if (delay_done) next_state = WRITE_LINE2;
            WRITE_LINE2: if (delay_done) next_state = WAIT_WRITE2;
            WAIT_WRITE2: begin
                if (delay_done) begin
                    if (char_index >= 15) next_state = DONE;
                    else next_state = WRITE_LINE2;
                end
            end
            
            DONE: next_state = READY;
            
            default: next_state = IDLE;
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
                SET_LINE1_ADDR: char_index <= 0;
                WAIT_WRITE1: if (delay_done && char_index < 15) char_index <= char_index + 1;
                SET_LINE2_ADDR: char_index <= 0;
                WAIT_WRITE2: if (delay_done && char_index < 15) char_index <= char_index + 1;
            endcase
        end
    end
    
    //========================================================================
    // Current Character Selection
    //========================================================================
    
    always @(*) begin
        // Default to line1
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
        
        // Override for line2
        if (state == WRITE_LINE2 || state == WAIT_WRITE2) begin
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
    // LCD Control Outputs with Proper Enable Timing
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            LCD_ON <= 1'b0;
            LCD_BLON <= 1'b0;
            LCD_EN <= 1'b0;
            LCD_RS <= 1'b0;
            LCD_RW <= 1'b0;
            LCD_DATA <= 8'h00;
            delay_target <= POWER_ON_DELAY;
            ready <= 1'b0;
            busy <= 1'b1;
        end else begin
            // Always write mode
            LCD_RW <= 1'b0;
            
            case (state)
                IDLE: begin
                    LCD_ON <= 1'b1;
                    LCD_BLON <= 1'b1;
                    LCD_EN <= 1'b0;
                    LCD_RS <= 1'b0;
                    LCD_DATA <= 8'h00;
                    ready <= 1'b0;
                    busy <= 1'b1;
                end
                
                POWER_ON_WAIT: begin
                    delay_target <= POWER_ON_DELAY;
                    LCD_EN <= 1'b0;
                end
                
                // Initialization commands with enable pulse
                INIT_FUNCTION_SET1, INIT_FUNCTION_SET2, INIT_FUNCTION_SET3: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_FUNCTION_SET;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                INIT_WAIT1, INIT_WAIT2, INIT_WAIT3: begin
                    LCD_EN <= 1'b0;
                    delay_target <= SHORT_DELAY;
                end
                
                INIT_DISPLAY_OFF: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_DISPLAY_OFF;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                INIT_WAIT4: begin
                    LCD_EN <= 1'b0;
                    delay_target <= SHORT_DELAY;
                end
                
                INIT_CLEAR: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_CLEAR;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                INIT_WAIT5: begin
                    LCD_EN <= 1'b0;
                    delay_target <= LONG_DELAY;
                end
                
                INIT_ENTRY_MODE: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_ENTRY_MODE;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                INIT_WAIT6: begin
                    LCD_EN <= 1'b0;
                    delay_target <= SHORT_DELAY;
                end
                
                INIT_DISPLAY_ON: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_DISPLAY_ON;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                INIT_WAIT7: begin
                    LCD_EN <= 1'b0;
                    delay_target <= SHORT_DELAY;
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
                    ready <= 1'b0;
                    busy <= 1'b1;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                WAIT_CLEAR: begin
                    LCD_EN <= 1'b0;
                    delay_target <= LONG_DELAY;
                end
                
                SET_LINE1_ADDR: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_SET_DDRAM_LINE1;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                WAIT_LINE1_ADDR: begin
                    LCD_EN <= 1'b0;
                    delay_target <= SHORT_DELAY;
                end
                
                WRITE_LINE1: begin
                    LCD_RS <= 1'b1;
                    LCD_DATA <= current_char;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                WAIT_WRITE1: begin
                    LCD_EN <= 1'b0;
                    delay_target <= SHORT_DELAY;
                end
                
                SET_LINE2_ADDR: begin
                    LCD_RS <= 1'b0;
                    LCD_DATA <= CMD_SET_DDRAM_LINE2;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                WAIT_LINE2_ADDR: begin
                    LCD_EN <= 1'b0;
                    delay_target <= SHORT_DELAY;
                end
                
                WRITE_LINE2: begin
                    LCD_RS <= 1'b1;
                    LCD_DATA <= current_char;
                    LCD_EN <= (delay_counter < ENABLE_HIGH);
                    delay_target <= ENABLE_HIGH + ENABLE_LOW;
                end
                
                WAIT_WRITE2: begin
                    LCD_EN <= 1'b0;
                    delay_target <= SHORT_DELAY;
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