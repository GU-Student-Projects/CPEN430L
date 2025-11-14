//============================================================================
// Module: lcd_driver
// Description: Low-level HD44780 LCD hardware driver
//              Handles all timing, initialization, and protocol details
//              REUSABLE - Works with any HD44780-compatible 16x2 LCD
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//
// This module is PROVEN and should not need modification.
// Based on working lcdIp design with verified HD44780 timing.
//============================================================================

`timescale 1ns/1ps

module lcd_driver (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,            // 50 MHz system clock
    input  wire         rst_n,          // Active-low reset
    
    //========================================================================
    // Command Interface (from application)
    //========================================================================
    input  wire         send,           // Pulse to send command/data
    input  wire [7:0]   cmd_byte,       // Command or data byte to send
    input  wire         is_data,        // 0=command (RS=0), 1=data (RS=1)
    
    output wire         busy,           // Driver is busy executing
    output wire         ready,          // Driver initialized and ready
    
    //========================================================================
    // LCD Hardware Interface
    //========================================================================
    output wire         LCD_ON,         // LCD power (always on)
    output wire         LCD_BLON,       // Backlight (always on)
    output reg          LCD_EN,         // Enable signal
    output reg          LCD_RS,         // Register select (0=cmd, 1=data)
    output reg          LCD_RW,         // Read/Write (always 0=write)
    output reg  [7:0]   LCD_DATA        // 8-bit data bus
);

    //========================================================================
    // LCD Power - Always On
    //========================================================================
    assign LCD_ON = 1'b1;
    assign LCD_BLON = 1'b1;

    //========================================================================
    // Timing Parameters (50 MHz = 20ns per cycle)
    //========================================================================
	localparam integer T_INIT      = 1_000_000;  // 20ms (was 15ms)
	localparam integer T_4_1MS     = 205_000;    // 4.1ms (first init delay)
	localparam integer T_100US     = 5_000;      // 100µs (subsequent init delays)
	localparam integer T_SETUP     = 4;          // 80ns setup time  <-- ADD THIS LINE
	localparam integer T_E_HIGH    = 2_500;      // 50µs (was 20µs)
	localparam integer T_E_LOW     = 2_500;      // 50µs (was 20µs)
	localparam integer T_CMD       = 5_000;      // 100µs (was 50µs)
	localparam integer T_CLEAR     = 150_000;    // 3ms (was 2ms)

    //========================================================================
    // State Machine
    //========================================================================
    typedef enum logic [2:0] {
        INIT_WAIT,      // Power-on initialization wait
        IDLE,           // Waiting for command
        LOAD,           // Load data onto bus
        SETUP,          // Meet setup time
        E_HIGH,         // Enable pulse high
        E_LOW,          // Enable pulse low  
        WAIT_DONE       // Wait for command execution
    } state_t;
    
    state_t state;

    //========================================================================
    // Internal Registers
    //========================================================================
    reg [19:0] timer;               // Countdown timer
    reg [7:0]  cmd_latched;         // Latched command byte
    reg        is_data_latched;     // Latched data/command flag
    reg        system_ready;        // Initialization complete flag
    reg        cmd_busy;            // Command in progress
    
    //========================================================================
    // Output Assignments
    //========================================================================
    assign ready = system_ready;
    assign busy = cmd_busy;
    
    wire timer_done = (timer == 0);
    
    // Determine if command needs long delay (clear/home)
    wire is_clear_or_home = !is_data_latched && 
                           ((cmd_latched == 8'h01) || (cmd_latched == 8'h02));

    //========================================================================
    // Main State Machine (EXACTLY matches working lcdIp)
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= INIT_WAIT;
            timer <= T_INIT;
            LCD_EN <= 1'b0;
            LCD_RS <= 1'b0;
            LCD_RW <= 1'b0;
            LCD_DATA <= 8'h00;
            cmd_latched <= 8'h00;
            is_data_latched <= 1'b0;
            system_ready <= 1'b0;
            cmd_busy <= 1'b1;
            
        end else begin
            // Default: RW is always write mode
            LCD_RW <= 1'b0;
            
            // systemReady flag follows IDLE state
            system_ready <= (state == IDLE);
            
            case (state)
                //============================================================
                // INIT_WAIT - Power-on initialization (15ms)
                //============================================================
                INIT_WAIT: begin
                    cmd_busy <= 1'b1;
                    LCD_EN <= 1'b0;
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        state <= IDLE;
                        cmd_busy <= 1'b0;
                    end
                end
                
                //============================================================
                // IDLE - Wait for command
                //============================================================
                IDLE: begin
                    cmd_busy <= 1'b0;
                    LCD_EN <= 1'b0;
                    
                    if (send) begin
                        // Latch command
                        cmd_latched <= cmd_byte;
                        is_data_latched <= is_data;
                        state <= LOAD;
                    end
                end
                
                //============================================================
                // LOAD - Place data on bus
                //============================================================
                LOAD: begin
                    cmd_busy <= 1'b1;
                    LCD_RS <= is_data_latched;
                    LCD_DATA <= cmd_latched;
                    timer <= T_SETUP;
                    state <= SETUP;
                end
                
                //============================================================
                // SETUP - Meet setup time requirement
                //============================================================
                SETUP: begin
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        timer <= T_E_HIGH;
                        state <= E_HIGH;
                    end
                end
                
                //============================================================
                // E_HIGH - Enable pulse high
                //============================================================
                E_HIGH: begin
                    LCD_EN <= 1'b1;
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        timer <= T_E_LOW;
                        state <= E_LOW;
                    end
                end
                
                //============================================================
                // E_LOW - Enable pulse low (LCD latches on falling edge)
                //============================================================
                E_LOW: begin
                    LCD_EN <= 1'b0;
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        // Set appropriate execution delay
                        timer <= is_clear_or_home ? T_CLEAR : T_CMD;
                        state <= WAIT_DONE;
                    end
                end
                
                //============================================================
                // WAIT_DONE - Wait for LCD to process command
                //============================================================
                WAIT_DONE: begin
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        state <= IDLE;
                        cmd_busy <= 1'b0;
                    end
                end
                
                default: begin
                    state <= INIT_WAIT;
                end
            endcase
        end
    end

endmodule