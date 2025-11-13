//============================================================================
// Module: menu_navigator
// Description: User interface navigation controller for coffee machine
//              Handles button inputs and manages menu state transitions
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module menu_navigator (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,                    // 50 MHz system clock
    input  wire         rst_n,                  // Active-low reset
    
    //========================================================================
    // Button Inputs (Raw - from DE2-115 board)
    //========================================================================
    input  wire         btn_cancel,             // BTN[0]: Cancel/Back
    input  wire         btn_left,               // BTN[1]: Navigate left
    input  wire         btn_right,              // BTN[2]: Navigate right
    input  wire         btn_select,             // BTN[3]: Select/Start
    
    //========================================================================
    // System Status Inputs
    //========================================================================
    input  wire         system_ready,           // System ready to brew
    input  wire         brewing_active,         // Currently brewing
    input  wire         error_present,          // Critical error present
    input  wire [3:0]   warning_count,          // Number of active warnings
    
    //========================================================================
    // Recipe Validation (from recipe_engine)
    //========================================================================
    input  wire         recipe_valid,           // Current selection is valid
    input  wire         can_make_coffee,        // At least one bin has coffee
    
    //========================================================================
    // Menu State Outputs
    //========================================================================
    output reg [3:0]    current_menu_state,     // Current menu state
    output reg [2:0]    selected_coffee_type,   // Selected coffee bin (0 or 1)
    output reg [2:0]    selected_drink_type,    // Selected drink (0-4)
    output reg [1:0]    selected_size,          // Selected size (0-2)
    
    //========================================================================
    // Control Outputs
    //========================================================================
    output reg          start_brewing_cmd,      // Command to start brewing
    output reg          enter_settings_mode,    // Enter settings/maintenance mode
    output reg          display_refresh         // Pulse to refresh display
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Menu states
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
    
    // Drink types (matches recipe_engine)
    parameter DRINK_BLACK_COFFEE = 3'd0;
    parameter DRINK_COFFEE_CREAM = 3'd1;
    parameter DRINK_LATTE = 3'd2;
    parameter DRINK_MOCHA = 3'd3;
    parameter DRINK_HOT_CHOCOLATE = 3'd4;
    parameter NUM_DRINKS = 3'd5;
    
    // Size options
    parameter SIZE_8OZ = 2'd0;
    parameter SIZE_12OZ = 2'd1;
    parameter SIZE_16OZ = 2'd2;
    parameter NUM_SIZES = 2'd3;
    
    // Coffee bins
    parameter COFFEE_BIN0 = 3'd0;
    parameter COFFEE_BIN1 = 3'd1;
    parameter NUM_COFFEE_BINS = 3'd2;
    
    // Button debouncing
    parameter DEBOUNCE_TIME = 20;  // 20ms
    parameter DEBOUNCE_CYCLES = (DEBOUNCE_TIME * 50_000);
    
    // Special button combination timeout
    parameter COMBO_TIMEOUT = 100_000_000;  // 2 seconds at 50MHz
    
    //========================================================================
    // Internal Signals
    //========================================================================
    
    // Debounced button signals
    reg btn_cancel_db;
    reg btn_left_db;
    reg btn_right_db;
    reg btn_select_db;
    
    // Edge detection (rising edge = button press)
    reg btn_cancel_prev, btn_left_prev, btn_right_prev, btn_select_prev;
    wire btn_cancel_pressed, btn_left_pressed, btn_right_pressed, btn_select_pressed;
    
    // Debounce counters
    reg [19:0] debounce_cnt_cancel;
    reg [19:0] debounce_cnt_left;
    reg [19:0] debounce_cnt_right;
    reg [19:0] debounce_cnt_select;
    
    // Special combination detection (BTN[1]+BTN[2]+BTN[3])
    reg [31:0] combo_timer;
    reg combo_detected;
    
    // Menu navigation state
    reg [3:0] next_menu_state;
    
    // Display refresh trigger
    reg state_changed;
    
    //========================================================================
    // Button Debouncing Logic
    //========================================================================
    
    // Cancel button debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_cancel <= 0;
            btn_cancel_db <= 0;
        end else begin
            if (btn_cancel == btn_cancel_db) begin
                debounce_cnt_cancel <= 0;
            end else begin
                if (debounce_cnt_cancel >= DEBOUNCE_CYCLES - 1) begin
                    btn_cancel_db <= btn_cancel;
                    debounce_cnt_cancel <= 0;
                end else begin
                    debounce_cnt_cancel <= debounce_cnt_cancel + 1;
                end
            end
        end
    end
    
    // Left button debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_left <= 0;
            btn_left_db <= 0;
        end else begin
            if (btn_left == btn_left_db) begin
                debounce_cnt_left <= 0;
            end else begin
                if (debounce_cnt_left >= DEBOUNCE_CYCLES - 1) begin
                    btn_left_db <= btn_left;
                    debounce_cnt_left <= 0;
                end else begin
                    debounce_cnt_left <= debounce_cnt_left + 1;
                end
            end
        end
    end
    
    // Right button debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_right <= 0;
            btn_right_db <= 0;
        end else begin
            if (btn_right == btn_right_db) begin
                debounce_cnt_right <= 0;
            end else begin
                if (debounce_cnt_right >= DEBOUNCE_CYCLES - 1) begin
                    btn_right_db <= btn_right;
                    debounce_cnt_right <= 0;
                end else begin
                    debounce_cnt_right <= debounce_cnt_right + 1;
                end
            end
        end
    end
    
    // Select button debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_select <= 0;
            btn_select_db <= 0;
        end else begin
            if (btn_select == btn_select_db) begin
                debounce_cnt_select <= 0;
            end else begin
                if (debounce_cnt_select >= DEBOUNCE_CYCLES - 1) begin
                    btn_select_db <= btn_select;
                    debounce_cnt_select <= 0;
                end else begin
                    debounce_cnt_select <= debounce_cnt_select + 1;
                end
            end
        end
    end
    
    //========================================================================
    // Edge Detection (Button Press Detection)
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_cancel_prev <= 0;
            btn_left_prev <= 0;
            btn_right_prev <= 0;
            btn_select_prev <= 0;
        end else begin
            btn_cancel_prev <= btn_cancel_db;
            btn_left_prev <= btn_left_db;
            btn_right_prev <= btn_right_db;
            btn_select_prev <= btn_select_db;
        end
    end
    
    assign btn_cancel_pressed = btn_cancel_db && !btn_cancel_prev;
    assign btn_left_pressed = btn_left_db && !btn_left_prev;
    assign btn_right_pressed = btn_right_db && !btn_right_prev;
    assign btn_select_pressed = btn_select_db && !btn_select_prev;
    
    //========================================================================
    // Special Button Combination Detection (Settings Mode)
    // BTN[1] + BTN[2] + BTN[3] held for 2 seconds
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            combo_timer <= 0;
            combo_detected <= 0;
        end else begin
            if (btn_left_db && btn_right_db && btn_select_db) begin
                // All three buttons held
                if (combo_timer >= COMBO_TIMEOUT - 1) begin
                    combo_detected <= 1'b1;
                    combo_timer <= COMBO_TIMEOUT;  // Hold at max
                end else begin
                    combo_timer <= combo_timer + 1;
                    combo_detected <= 1'b0;
                end
            end else begin
                combo_timer <= 0;
                combo_detected <= 1'b0;
            end
        end
    end
    
    //========================================================================
    // Menu State Machine
    //========================================================================
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_menu_state <= STATE_SPLASH;
        end else begin
            current_menu_state <= next_menu_state;
        end
    end
    
    // Detect state changes for display refresh
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_changed <= 1'b0;
        end else begin
            state_changed <= (current_menu_state != next_menu_state);
        end
    end
    
    // Next state logic
    always @(*) begin
        next_menu_state = current_menu_state;
        
        case (current_menu_state)
            
            STATE_SPLASH: begin
                // Splash screen - wait for any button or automatic transition
                if (btn_select_pressed || btn_cancel_pressed || btn_left_pressed || btn_right_pressed) begin
                    next_menu_state = STATE_CHECK_ERRORS;
                end else if (combo_detected) begin
                    next_menu_state = STATE_SETTINGS;
                end
            end
            
            STATE_CHECK_ERRORS: begin
                // Check for critical errors
                if (error_present) begin
                    next_menu_state = STATE_ERROR;
                end else if (system_ready && can_make_coffee) begin
                    next_menu_state = STATE_COFFEE_SELECT;
                end else if (!can_make_coffee) begin
                    next_menu_state = STATE_ERROR;  // No coffee available
                end
            end
            
            STATE_COFFEE_SELECT: begin
                // Select coffee bin
                if (btn_select_pressed) begin
                    next_menu_state = STATE_DRINK_SELECT;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_SPLASH;
                end else if (combo_detected) begin
                    next_menu_state = STATE_SETTINGS;
                end
            end
            
            STATE_DRINK_SELECT: begin
                // Select drink type
                if (btn_select_pressed) begin
                    next_menu_state = STATE_SIZE_SELECT;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_COFFEE_SELECT;
                end else if (combo_detected) begin
                    next_menu_state = STATE_SETTINGS;
                end
            end
            
            STATE_SIZE_SELECT: begin
                // Select size
                if (btn_select_pressed) begin
                    next_menu_state = STATE_CONFIRM;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_DRINK_SELECT;
                end else if (combo_detected) begin
                    next_menu_state = STATE_SETTINGS;
                end
            end
            
            STATE_CONFIRM: begin
                // Confirm selection and start brewing
                if (btn_select_pressed && recipe_valid) begin
                    next_menu_state = STATE_BREWING;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_SIZE_SELECT;
                end else if (combo_detected) begin
                    next_menu_state = STATE_SETTINGS;
                end
            end
            
            STATE_BREWING: begin
                // Brewing in progress - wait for completion
                if (!brewing_active) begin
                    next_menu_state = STATE_COMPLETE;
                end else if (btn_cancel_pressed) begin
                    // Cancel brewing - return to splash
                    next_menu_state = STATE_SPLASH;
                end
            end
            
            STATE_COMPLETE: begin
                // Brew complete - wait for any button
                if (btn_select_pressed || btn_cancel_pressed || btn_left_pressed || btn_right_pressed) begin
                    next_menu_state = STATE_SPLASH;
                end
            end
            
            STATE_ERROR: begin
                // Error state - wait for error to clear
                if (!error_present && can_make_coffee) begin
                    next_menu_state = STATE_SPLASH;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_SPLASH;  // Allow exit
                end else if (combo_detected) begin
                    next_menu_state = STATE_SETTINGS;
                end
            end
            
            STATE_SETTINGS: begin
                // Settings/maintenance mode
                if (btn_cancel_pressed) begin
                    next_menu_state = STATE_SPLASH;
                end
            end
            
            default: begin
                next_menu_state = STATE_SPLASH;
            end
            
        endcase
    end
    
    //========================================================================
    // Selection Management (Coffee, Drink, Size)
    //========================================================================
    
    // Coffee bin selection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected_coffee_type <= COFFEE_BIN0;
        end else begin
            if (current_menu_state == STATE_COFFEE_SELECT) begin
                if (btn_left_pressed) begin
                    if (selected_coffee_type == 0) begin
                        selected_coffee_type <= NUM_COFFEE_BINS - 1;  // Wrap around
                    end else begin
                        selected_coffee_type <= selected_coffee_type - 1;
                    end
                end else if (btn_right_pressed) begin
                    if (selected_coffee_type >= NUM_COFFEE_BINS - 1) begin
                        selected_coffee_type <= 0;  // Wrap around
                    end else begin
                        selected_coffee_type <= selected_coffee_type + 1;
                    end
                end
            end
        end
    end
    
    // Drink type selection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected_drink_type <= DRINK_BLACK_COFFEE;
        end else begin
            if (current_menu_state == STATE_DRINK_SELECT) begin
                if (btn_left_pressed) begin
                    if (selected_drink_type == 0) begin
                        selected_drink_type <= NUM_DRINKS - 1;  // Wrap around
                    end else begin
                        selected_drink_type <= selected_drink_type - 1;
                    end
                end else if (btn_right_pressed) begin
                    if (selected_drink_type >= NUM_DRINKS - 1) begin
                        selected_drink_type <= 0;  // Wrap around
                    end else begin
                        selected_drink_type <= selected_drink_type + 1;
                    end
                end
            end
        end
    end
    
    // Size selection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected_size <= SIZE_12OZ;  // Default to medium
        end else begin
            if (current_menu_state == STATE_SIZE_SELECT) begin
                if (btn_left_pressed) begin
                    if (selected_size == 0) begin
                        selected_size <= NUM_SIZES - 1;  // Wrap around
                    end else begin
                        selected_size <= selected_size - 1;
                    end
                end else if (btn_right_pressed) begin
                    if (selected_size >= NUM_SIZES - 1) begin
                        selected_size <= 0;  // Wrap around
                    end else begin
                        selected_size <= selected_size + 1;
                    end
                end
            end
        end
    end
    
    //========================================================================
    // Command Outputs
    //========================================================================
    
    // Start brewing command (pulse)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_brewing_cmd <= 1'b0;
        end else begin
            start_brewing_cmd <= (current_menu_state == STATE_CONFIRM && 
                                 next_menu_state == STATE_BREWING);
        end
    end
    
    // Enter settings mode command (pulse)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enter_settings_mode <= 1'b0;
        end else begin
            enter_settings_mode <= (next_menu_state == STATE_SETTINGS && 
                                   current_menu_state != STATE_SETTINGS);
        end
    end
    
    // Display refresh trigger
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            display_refresh <= 1'b0;
        end else begin
            // Refresh on state change or selection change
            display_refresh <= state_changed || 
                             btn_left_pressed || 
                             btn_right_pressed;
        end
    end
    
    //========================================================================
    // Debug/Monitoring (Optional - removed during synthesis)
    //========================================================================
    
    // Synthesis translate_off
    // always @(posedge clk) begin
    //     // Log state transitions
    //     if (state_changed) begin
    //         case (next_menu_state)
    //             STATE_SPLASH: $display("[%0t] Menu: SPLASH", $time);
    //             STATE_CHECK_ERRORS: $display("[%0t] Menu: CHECK_ERRORS", $time);
    //             STATE_COFFEE_SELECT: $display("[%0t] Menu: COFFEE_SELECT", $time);
    //             STATE_DRINK_SELECT: $display("[%0t] Menu: DRINK_SELECT", $time);
    //             STATE_SIZE_SELECT: $display("[%0t] Menu: SIZE_SELECT", $time);
    //             STATE_CONFIRM: $display("[%0t] Menu: CONFIRM", $time);
    //             STATE_BREWING: $display("[%0t] Menu: BREWING", $time);
    //             STATE_COMPLETE: $display("[%0t] Menu: COMPLETE", $time);
    //             STATE_SETTINGS: $display("[%0t] Menu: SETTINGS", $time);
    //             STATE_ERROR: $display("[%0t] Menu: ERROR", $time);
    //         endcase
    //     end
        
    //     // Log button presses
    //     if (btn_cancel_pressed) $display("[%0t] Button: CANCEL", $time);
    //     if (btn_left_pressed) $display("[%0t] Button: LEFT", $time);
    //     if (btn_right_pressed) $display("[%0t] Button: RIGHT", $time);
    //     if (btn_select_pressed) $display("[%0t] Button: SELECT", $time);
        
    //     // Log selection changes
    //     if (current_menu_state == STATE_COFFEE_SELECT && (btn_left_pressed || btn_right_pressed)) begin
    //         $display("[%0t] Selected Coffee Bin: %0d", $time, selected_coffee_type);
    //     end
    //     if (current_menu_state == STATE_DRINK_SELECT && (btn_left_pressed || btn_right_pressed)) begin
    //         $display("[%0t] Selected Drink: %0d", $time, selected_drink_type);
    //     end
    //     if (current_menu_state == STATE_SIZE_SELECT && (btn_left_pressed || btn_right_pressed)) begin
    //         $display("[%0t] Selected Size: %0d", $time, selected_size);
    //     end
        
    //     // Log special combo
    //     if (combo_detected) begin
    //         $display("[%0t] Settings combo detected!", $time);
    //     end
    // end
    // Synthesis translate_on
    
endmodule