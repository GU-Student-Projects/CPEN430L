//============================================================================
// Module: lcd_controller
// Description: High-level LCD controller with string interface
//              Manages initialization sequence and character writing
//              Application-specific - Easy to modify for different uses
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//
// This module can be customized for your specific application.
// Handles conversion from 128-bit strings to individual LCD commands.
//============================================================================

`timescale 1ns/1ps

module lcd_controller (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,            // 50 MHz system clock
    input  wire         rst_n,          // Active-low reset
    
    //========================================================================
    // String Interface (from application)
    //========================================================================
    input  wire [127:0] line1_data,     // Line 1: 16 characters (8 bits each)
    input  wire [127:0] line2_data,     // Line 2: 16 characters (8 bits each)
    input  wire         update_display, // Pulse to update LCD
    
    //========================================================================
    // LCD Hardware Interface
    //========================================================================
    output wire         LCD_ON,
    output wire         LCD_BLON,
    output wire         LCD_EN,
    output wire         LCD_RS,
    output wire         LCD_RW,
    output wire [7:0]   LCD_DATA,
    
    //========================================================================
    // Status
    //========================================================================
    output wire         ready,          // Ready for new data
    output wire         busy            // Currently updating
);

    //========================================================================
    // LCD Commands
    //========================================================================
    localparam [7:0] CMD_FUNCTION_SET_1  = 8'h30;  // Initial function set
    localparam [7:0] CMD_FUNCTION_SET    = 8'h38;  // 8-bit, 2 lines, 5x8
    localparam [7:0] CMD_DISPLAY_OFF     = 8'h08;  // Display off
    localparam [7:0] CMD_CLEAR           = 8'h01;  // Clear display
    localparam [7:0] CMD_ENTRY_MODE      = 8'h06;  // Entry mode set
    localparam [7:0] CMD_DISPLAY_ON      = 8'h0C;  // Display on
    localparam [7:0] CMD_SET_DDRAM_LINE1 = 8'h80;  // Line 1 address
    localparam [7:0] CMD_SET_DDRAM_LINE2 = 8'hC0;  // Line 2 address

    //========================================================================
    // Timing Parameters (in clock cycles at 50 MHz)
    //========================================================================
	localparam integer DLY_4_1MS  = 250_000;     // 5ms (was 4.1ms)
	localparam integer DLY_100US  = 10_000;      // 200µs (was 100µs)
	localparam integer DLY_CMD    = 10_000;      // 200µs (was 100µs)
	localparam integer DLY_CLEAR  = 150_000;     // 3ms (was 2ms)
    //========================================================================
    // State Machine
    //========================================================================
    typedef enum logic [5:0] {
        // Initialization states
        S_PWRUP,        // Power-up wait (handled by lcd_driver)
        S_INIT1,        // Send 0x30 #1
        S_WAIT1,        // Wait 4.1ms
        S_INIT2,        // Send 0x30 #2
        S_WAIT2,        // Wait 100µs
        S_INIT3,        // Send 0x30 #3
        S_WAIT3,        // Wait 100µs
        S_FUNCSET,      // Send 0x38
        S_WAITF,        // Wait
        S_DISPOFF,      // Send 0x08
        S_WAITD,        // Wait
        S_CLEAR,        // Send 0x01
        S_WAITC,        // Wait 2ms
        S_ENTRY,        // Send 0x06
        S_WAITE,        // Wait
        S_DISPON,       // Send 0x0C
        S_WAITON,       // Wait
        // Operational states
        S_IDLE,         // Ready for commands
        S_SET_L1,       // Set line 1 address
        S_WAIT_L1,      // Wait for address set
        S_WRITE_L1,     // Write line 1 character
        S_WAIT_WL1,     // Wait for character write
        S_SET_L2,       // Set line 2 address
        S_WAIT_L2,      // Wait for address set
        S_WRITE_L2,     // Write line 2 character
        S_WAIT_WL2      // Wait for character write
    } state_t;

    state_t state;

    //========================================================================
    // Internal Registers
    //========================================================================
    reg [31:0] delay_counter;
    reg [4:0]  char_index;          // 0-15 for current character
    reg [127:0] line1_buffer;
    reg [127:0] line2_buffer;
    reg        update_pending;
    
    // Interface to lcd_driver
    reg        send;
    reg [7:0]  cmd_byte;
    reg        is_data;
    wire       driver_busy;
    wire       driver_ready;

    //========================================================================
    // LCD Driver Instance
    //========================================================================
    lcd_driver lcd_driver_inst (
        .clk(clk),
        .rst_n(rst_n),
        .send(send),
        .cmd_byte(cmd_byte),
        .is_data(is_data),
        .busy(driver_busy),
        .ready(driver_ready),
        .LCD_ON(LCD_ON),
        .LCD_BLON(LCD_BLON),
        .LCD_EN(LCD_EN),
        .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW),
        .LCD_DATA(LCD_DATA)
    );

    //========================================================================
    // Status Outputs
    //========================================================================
    assign ready = (state == S_IDLE) && !driver_busy;
    assign busy = (state != S_IDLE) || driver_busy;

    //========================================================================
    // Character Selection
    //========================================================================
    wire [7:0] current_char_l1 = line1_buffer[127 - (char_index * 8) -: 8];
    wire [7:0] current_char_l2 = line2_buffer[127 - (char_index * 8) -: 8];

    //========================================================================
    // Capture Display Data
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line1_buffer <= 128'd0;
            line2_buffer <= 128'd0;
            update_pending <= 1'b0;
        end else begin
            if (update_display && (state == S_IDLE) && !driver_busy) begin
                line1_buffer <= line1_data;
                line2_buffer <= line2_data;
                update_pending <= 1'b1;
            end else if (state == S_IDLE && update_pending && !driver_busy) begin
                update_pending <= 1'b0;  // Clear when starting write
            end
        end
    end

    //========================================================================
    // Main State Machine
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_PWRUP;
            send <= 1'b0;
            cmd_byte <= 8'h00;
            is_data <= 1'b0;
            delay_counter <= 32'd0;
            char_index <= 5'd0;
            
        end else begin
            // Default: don't send
            send <= 1'b0;
            
            case (state)
                //============================================================
                // POWER-UP: Wait for driver initialization
                //============================================================
                S_PWRUP: begin
                    if (driver_ready) begin
                        state <= S_INIT1;
                    end
                end
                
                //============================================================
                // INITIALIZATION SEQUENCE (HD44780 datasheet procedure)
                //============================================================
                
                // Send 0x30 #1
                S_INIT1: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_FUNCTION_SET_1;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAIT1;
                    end
                end
                
                // Wait 4.1ms
                S_WAIT1: begin
                    if (!driver_busy && delay_counter >= DLY_4_1MS) begin
                        state <= S_INIT2;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                // Send 0x30 #2
                S_INIT2: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_FUNCTION_SET_1;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAIT2;
                    end
                end
                
                // Wait 100µs
                S_WAIT2: begin
                    if (!driver_busy && delay_counter >= DLY_100US) begin
                        state <= S_INIT3;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                // Send 0x30 #3
                S_INIT3: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_FUNCTION_SET_1;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAIT3;
                    end
                end
                
                // Wait 100µs
                S_WAIT3: begin
                    if (!driver_busy && delay_counter >= DLY_100US) begin
                        state <= S_FUNCSET;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                // Function Set: 8-bit, 2-line, 5x8
                S_FUNCSET: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_FUNCTION_SET;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAITF;
                    end
                end
                
                S_WAITF: begin
                    if (!driver_busy && delay_counter >= DLY_CMD) begin
                        state <= S_DISPOFF;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                // Display Off
                S_DISPOFF: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_DISPLAY_OFF;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAITD;
                    end
                end
                
                S_WAITD: begin
                    if (!driver_busy && delay_counter >= DLY_CMD) begin
                        state <= S_CLEAR;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                // Clear Display
                S_CLEAR: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_CLEAR;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAITC;
                    end
                end
                
                S_WAITC: begin
                    if (!driver_busy && delay_counter >= DLY_CLEAR) begin
                        state <= S_ENTRY;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                // Entry Mode Set
                S_ENTRY: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_ENTRY_MODE;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAITE;
                    end
                end
                
                S_WAITE: begin
                    if (!driver_busy && delay_counter >= DLY_CMD) begin
                        state <= S_DISPON;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                // Display On
                S_DISPON: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_DISPLAY_ON;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAITON;
                    end
                end
                
                S_WAITON: begin
                    if (!driver_busy && delay_counter >= DLY_CMD) begin
                        state <= S_IDLE;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                //============================================================
                // IDLE - Ready for display updates
                //============================================================
                S_IDLE: begin
                    if (update_pending && !driver_busy) begin
                        char_index <= 5'd0;
                        state <= S_SET_L1;
                    end
                end
                
                //============================================================
                // WRITE LINE 1
                //============================================================
                
                // Set DDRAM address to line 1 start
                S_SET_L1: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_SET_DDRAM_LINE1;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAIT_L1;
                    end
                end
                
                S_WAIT_L1: begin
                    if (!driver_busy && delay_counter >= DLY_CMD) begin
                        char_index <= 5'd0;
                        state <= S_WRITE_L1;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                // Write 16 characters of line 1
                S_WRITE_L1: begin
                    if (!driver_busy) begin
                        cmd_byte <= current_char_l1;
                        is_data <= 1'b1;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAIT_WL1;
                    end
                end
                
                S_WAIT_WL1: begin
                    if (!driver_busy && delay_counter >= DLY_CMD) begin
                        if (char_index < 5'd15) begin
                            char_index <= char_index + 1;
                            state <= S_WRITE_L1;
                        end else begin
                            char_index <= 5'd0;
                            state <= S_SET_L2;
                        end
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                //============================================================
                // WRITE LINE 2
                //============================================================
                
                // Set DDRAM address to line 2 start
                S_SET_L2: begin
                    if (!driver_busy) begin
                        cmd_byte <= CMD_SET_DDRAM_LINE2;
                        is_data <= 1'b0;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAIT_L2;
                    end
                end
                
                S_WAIT_L2: begin
                    if (!driver_busy && delay_counter >= DLY_CMD) begin
                        char_index <= 5'd0;
                        state <= S_WRITE_L2;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                // Write 16 characters of line 2
                S_WRITE_L2: begin
                    if (!driver_busy) begin
                        cmd_byte <= current_char_l2;
                        is_data <= 1'b1;
                        send <= 1'b1;
                        delay_counter <= 32'd0;
                        state <= S_WAIT_WL2;
                    end
                end
                
                S_WAIT_WL2: begin
                    if (!driver_busy && delay_counter >= DLY_CMD) begin
                        if (char_index < 5'd15) begin
                            char_index <= char_index + 1;
                            state <= S_WRITE_L2;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                default: begin
                    state <= S_PWRUP;
                end
            endcase
        end
    end

endmodule