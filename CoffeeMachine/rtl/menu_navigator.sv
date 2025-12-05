//============================================================================
// Module: menu_navigator
// Description: Updated user interface navigation with maintenance menu
//              Handles button inputs and manages menu state transitions
//              Hidden maintenance menu accessible via button combo
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module menu_navigator (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,
    input  wire         rst_n,
    
    //========================================================================
    // Button Inputs (Raw - from DE2-115 board)
    //========================================================================
    input  wire         btn_cancel,             // BTN[1]: Cancel/Back
    input  wire         btn_left,               // BTN[3]: Navigate left
    input  wire         btn_right,              // BTN[0]: Navigate right
    input  wire         btn_select,             // BTN[2]: Select/Start
    
    //========================================================================
    // System Status Inputs
    //========================================================================
    input  wire         system_ready,
    input  wire         brewing_active,
    input  wire         error_present,
    input  wire [3:0]   warning_count,
    input  wire [3:0]   error_count,
    
    //========================================================================
    // Recipe Validation
    //========================================================================
    input  wire         recipe_valid,
    input  wire         can_make_coffee,
    
    //========================================================================
    // Water System Status
    //========================================================================
    input  wire         temp_ready,
    input  wire         pressure_ready,
    
    //========================================================================
    // Service Timer (NEW)
    //========================================================================
    input  wire [31:0]  hours_since_service,
    input  wire [31:0]  days_since_service,
    
    //========================================================================
    // Menu State Outputs
    //========================================================================
    output reg [3:0]    current_menu_state,
    output reg [2:0]    selected_coffee_type,
    output reg [2:0]    selected_drink_type,
    output reg [1:0]    selected_size,
    output reg [1:0]    selected_maint_option,
    
    //========================================================================
    // Control Outputs
    //========================================================================
    output reg          start_brewing_cmd,
    output reg          enter_settings_mode,
    output reg          enter_maintenance_mode,
    output reg          manual_check_requested,
    output reg          display_refresh
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Main menu states
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
    parameter STATE_INSUFFICIENT = 4'd10;
    
    // Abort confirmation state
    parameter STATE_ABORT_CONFIRM = 4'd11;
    
    // Maintenance menu states
    parameter STATE_MAINTENANCE = 4'd12;
    parameter STATE_MAINT_OPTIONS = 4'd13;
    parameter STATE_MAINT_VIEW_ERRORS = 4'd14;
    parameter STATE_MAINT_MANUAL_CHECK = 4'd15;

    
    // Drink types
    parameter DRINK_BLACK_COFFEE = 3'd0;
    parameter DRINK_ESPRESSO = 3'd1;
    parameter DRINK_LATTE = 3'd2;
    parameter DRINK_MOCHA = 3'd3;
    parameter DRINK_AMERICANO = 3'd4;
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
    
    // Maintenance menu options
    parameter MAINT_VIEW_ERRORS = 2'd0;
    parameter MAINT_MANUAL_CHECK = 2'd1;
    parameter MAINT_SERVICE_TIME = 2'd2;
    parameter MAINT_EXIT = 2'd3;
    parameter NUM_MAINT_OPTIONS = 2'd4;
    
    // Button debouncing
    parameter DEBOUNCE_TIME = 20;
    parameter DEBOUNCE_CYCLES = (DEBOUNCE_TIME * 50_000);
    
    // Special button combination
    parameter COMBO_HOLD_CYCLES = 32'd2_500_000;  // 50ms at 50MHz
    
    // Insufficient resource display timeout
    parameter INSUFFICIENT_TIMEOUT = 500_000_000;
    
    //========================================================================
    // Internal Signals
    //========================================================================
    
    // Debounced button signals
    reg btn_cancel_db;
    reg btn_left_db;
    reg btn_right_db;
    reg btn_select_db;
    
    // Edge detection
    reg btn_cancel_prev, btn_left_prev, btn_right_prev, btn_select_prev;
    wire btn_cancel_pressed, btn_left_pressed, btn_right_pressed, btn_select_pressed;
    
    // Debounce counters
    reg [19:0] debounce_cnt_cancel;
    reg [19:0] debounce_cnt_left;
    reg [19:0] debounce_cnt_right;
    reg [19:0] debounce_cnt_select;
    
    // Special combination detection
    reg [31:0] combo_timer;
    reg combo_active;
    
    // Menu navigation state
    reg [3:0] next_menu_state;
    
    // Display refresh trigger
    reg state_changed;
    
    // Insufficient resource timeout counter
    reg [31:0] insufficient_timer;
    
    // Return state memory
    reg [3:0] return_state;
    
    // Guard to prevent premature completion detection
    reg brewing_has_started;
    
    //========================================================================
    // Button Debouncing Logic
    //========================================================================
    
    // Cancel button debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_cancel <= 0;
            btn_cancel_db <= 1'b0;
        end else begin
            if (btn_cancel == btn_cancel_db) begin
                debounce_cnt_cancel <= 0;
            end else if (debounce_cnt_cancel >= DEBOUNCE_CYCLES - 1) begin
                btn_cancel_db <= btn_cancel;
                debounce_cnt_cancel <= 0;
            end else begin
                debounce_cnt_cancel <= debounce_cnt_cancel + 1;
            end
        end
    end
    
    // Left button debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_left <= 0;
            btn_left_db <= 1'b0;
        end else begin
            if (btn_left == btn_left_db) begin
                debounce_cnt_left <= 0;
            end else if (debounce_cnt_left >= DEBOUNCE_CYCLES - 1) begin
                btn_left_db <= btn_left;
                debounce_cnt_left <= 0;
            end else begin
                debounce_cnt_left <= debounce_cnt_left + 1;
            end
        end
    end
    
    // Right button debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_right <= 0;
            btn_right_db <= 1'b0;
        end else begin
            if (btn_right == btn_right_db) begin
                debounce_cnt_right <= 0;
            end else if (debounce_cnt_right >= DEBOUNCE_CYCLES - 1) begin
                btn_right_db <= btn_right;
                debounce_cnt_right <= 0;
            end else begin
                debounce_cnt_right <= debounce_cnt_right + 1;
            end
        end
    end
    
    // Select button debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt_select <= 0;
            btn_select_db <= 1'b0;
        end else begin
            if (btn_select == btn_select_db) begin
                debounce_cnt_select <= 0;
            end else if (debounce_cnt_select >= DEBOUNCE_CYCLES - 1) begin
                btn_select_db <= btn_select;
                debounce_cnt_select <= 0;
            end else begin
                debounce_cnt_select <= debounce_cnt_select + 1;
            end
        end
    end
    
    //========================================================================
    // Edge Detection
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_cancel_prev <= 1'b0;
            btn_left_prev <= 1'b0;
            btn_right_prev <= 1'b0;
            btn_select_prev <= 1'b0;
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
    // Special Button Combination Detection
    // Detect: (Left OR Right) + Select held simultaneously
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            combo_timer <= 0;
            combo_active <= 1'b0;
        end else begin
            // Check if combo buttons are held
            if ((btn_left_db || btn_right_db) && btn_select_db) begin
                if (combo_timer >= COMBO_HOLD_CYCLES - 1) begin
                    combo_active <= 1'b1;
                    combo_timer <= 0;
                end else begin
                    combo_timer <= combo_timer + 1;
                    combo_active <= 1'b0;
                end
            end else begin
                combo_timer <= 0;
                combo_active <= 1'b0;
            end
        end
    end
    
    //========================================================================
    // Insufficient Resource Timer
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            insufficient_timer <= 0;
        end else begin
            if (current_menu_state == STATE_INSUFFICIENT) begin
                insufficient_timer <= insufficient_timer + 1;
            end else begin
                insufficient_timer <= 0;
            end
        end
    end
    
    //========================================================================
    // Return State Memory
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            return_state <= STATE_CONFIRM;
        end else begin
            if (current_menu_state != STATE_INSUFFICIENT && 
                next_menu_state == STATE_INSUFFICIENT) begin
                return_state <= current_menu_state;
            end
        end
    end
    
    //========================================================================
    // Brewing Started Guard
    // Track when brewing has actually started to prevent premature completion
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            brewing_has_started <= 1'b0;
        end else begin
            if (current_menu_state != STATE_BREWING) begin
                brewing_has_started <= 1'b0;  // Clear when not in brewing state
            end else if (brewing_active) begin
                brewing_has_started <= 1'b1;  // Latch when brewing actually starts
            end
        end
    end
    
    //========================================================================
    // Next State Logic
    //========================================================================
    
    always @(*) begin
        next_menu_state = current_menu_state;
        
        case (current_menu_state)
            
            STATE_SPLASH: begin
                if (combo_active) begin
                    next_menu_state = STATE_MAINTENANCE;
                end else if (btn_select_pressed && !error_present) begin
                    next_menu_state = STATE_CHECK_ERRORS;
                end
            end
            
					STATE_CHECK_ERRORS: begin
						 if (combo_active) begin
							  next_menu_state = STATE_MAINTENANCE;
						 end else if (error_present && error_count > 0) begin
							  // Critical errors - stay here, can't proceed
							  next_menu_state = STATE_CHECK_ERRORS;
						 end else if (warning_count > 0 && btn_select_pressed) begin
							  // Warnings only - user can acknowledge and continue
							  next_menu_state = STATE_COFFEE_SELECT;
						 end else if (!error_present && !warning_count && pressure_ready && can_make_coffee) begin
							  // No issues - auto proceed
							  next_menu_state = STATE_COFFEE_SELECT;
						 end else if (btn_cancel_pressed) begin
							  next_menu_state = STATE_SPLASH;
						 end
					end
									
            STATE_COFFEE_SELECT: begin
                if (combo_active) begin
                    next_menu_state = STATE_MAINTENANCE;
                end else if (btn_select_pressed) begin
                    next_menu_state = STATE_DRINK_SELECT;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_SPLASH;
                end
            end
            
            STATE_DRINK_SELECT: begin
                if (combo_active) begin
                    next_menu_state = STATE_MAINTENANCE;
                end else if (btn_select_pressed) begin
                    next_menu_state = STATE_SIZE_SELECT;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_COFFEE_SELECT;
                end
            end
            
            STATE_SIZE_SELECT: begin
                if (combo_active) begin
                    next_menu_state = STATE_MAINTENANCE;
                end else if (btn_select_pressed) begin
                    next_menu_state = STATE_CONFIRM;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_DRINK_SELECT;
                end
            end
            
            STATE_CONFIRM: begin
                if (combo_active) begin
                    next_menu_state = STATE_MAINTENANCE;
                end else if (btn_select_pressed) begin
                    if (recipe_valid) begin
                        next_menu_state = STATE_BREWING;
                    end else begin
                        next_menu_state = STATE_INSUFFICIENT;
                    end
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_SIZE_SELECT;
                end
            end
            
            STATE_INSUFFICIENT: begin
                if (insufficient_timer >= INSUFFICIENT_TIMEOUT - 1) begin
                    next_menu_state = return_state;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = return_state;
                end
            end
            
            STATE_BREWING: begin
                // Block completion detection until brewing has actually started
                if (btn_cancel_pressed) begin
                    next_menu_state = STATE_ABORT_CONFIRM;
                end else if (!brewing_active && brewing_has_started) begin
                    // Brew completed normally - only after brewing has started
                    next_menu_state = STATE_COMPLETE;
                end
                // NO other transitions allowed during brewing!
            end
            
            STATE_ABORT_CONFIRM: begin
                // Ask user to confirm abort
                if (btn_select_pressed) begin
                    // Confirmed - abort and return to splash
                    next_menu_state = STATE_SPLASH;
                end else if (btn_cancel_pressed) begin
                    // Cancelled abort - return to brewing
                    next_menu_state = STATE_BREWING;
                end
            end
            
            STATE_COMPLETE: begin
                if (btn_select_pressed || btn_cancel_pressed || 
                    btn_left_pressed || btn_right_pressed) begin
                    next_menu_state = STATE_SPLASH;
                end
            end
            
            STATE_ERROR: begin
                if (combo_active) begin
                    next_menu_state = STATE_MAINTENANCE;
                end else if (!error_present && can_make_coffee) begin
                    next_menu_state = STATE_SPLASH;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_SPLASH;
                end
            end
            
            STATE_SETTINGS: begin
                if (btn_cancel_pressed) begin
                    next_menu_state = STATE_SPLASH;
                end
            end
            
            // ============ MAINTENANCE MENU STATES ============
            
            STATE_MAINTENANCE: begin
                // Maintenance menu entry point - go to options
                next_menu_state = STATE_MAINT_OPTIONS;
            end
            
            STATE_MAINT_OPTIONS: begin
                // Navigate maintenance options
                if (btn_select_pressed) begin
                    case (selected_maint_option)
                        MAINT_VIEW_ERRORS:   next_menu_state = STATE_MAINT_VIEW_ERRORS;
                        MAINT_MANUAL_CHECK:  next_menu_state = STATE_MAINT_MANUAL_CHECK;
                        MAINT_SERVICE_TIME:  next_menu_state = STATE_MAINT_VIEW_ERRORS;
                        MAINT_EXIT:          next_menu_state = STATE_SPLASH;
                    endcase
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_SPLASH;
                end
            end
            
            STATE_MAINT_VIEW_ERRORS: begin
                // View current errors/warnings
                if (btn_cancel_pressed) begin
                    next_menu_state = STATE_MAINT_OPTIONS;
                end
            end
            
            STATE_MAINT_MANUAL_CHECK: begin
                // Manual check confirmation
                if (btn_select_pressed) begin
                    next_menu_state = STATE_MAINT_OPTIONS;
                end else if (btn_cancel_pressed) begin
                    next_menu_state = STATE_MAINT_OPTIONS;
                end
            end
            
            default: begin
                next_menu_state = STATE_SPLASH;
            end
            
        endcase
    end
    
    //========================================================================
    // State Register
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_menu_state <= STATE_SPLASH;
            state_changed <= 1'b0;
        end else begin
            state_changed <= (current_menu_state != next_menu_state);
            current_menu_state <= next_menu_state;
        end
    end
    
    //========================================================================
    // Selection Navigation - Coffee Type
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected_coffee_type <= COFFEE_BIN0;
        end else begin
            if (current_menu_state == STATE_COFFEE_SELECT) begin
                if (btn_left_pressed) begin
                    if (selected_coffee_type == 0) begin
                        selected_coffee_type <= NUM_COFFEE_BINS - 1;
                    end else begin
                        selected_coffee_type <= selected_coffee_type - 1;
                    end
                end else if (btn_right_pressed) begin
                    if (selected_coffee_type >= NUM_COFFEE_BINS - 1) begin
                        selected_coffee_type <= 0;
                    end else begin
                        selected_coffee_type <= selected_coffee_type + 1;
                    end
                end
            end
        end
    end
    
    //========================================================================
    // Selection Navigation - Drink Type
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected_drink_type <= DRINK_BLACK_COFFEE;
        end else begin
            if (current_menu_state == STATE_DRINK_SELECT) begin
                if (btn_left_pressed) begin
                    if (selected_drink_type == 0) begin
                        selected_drink_type <= NUM_DRINKS - 1;
                    end else begin
                        selected_drink_type <= selected_drink_type - 1;
                    end
                end else if (btn_right_pressed) begin
                    if (selected_drink_type >= NUM_DRINKS - 1) begin
                        selected_drink_type <= 0;
                    end else begin
                        selected_drink_type <= selected_drink_type + 1;
                    end
                end
            end
        end
    end
    
    //========================================================================
    // Selection Navigation - Size
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected_size <= SIZE_12OZ;
        end else begin
            if (current_menu_state == STATE_SIZE_SELECT) begin
                if (btn_left_pressed) begin
                    if (selected_size == 0) begin
                        selected_size <= NUM_SIZES - 1;
                    end else begin
                        selected_size <= selected_size - 1;
                    end
                end else if (btn_right_pressed) begin
                    if (selected_size >= NUM_SIZES - 1) begin
                        selected_size <= 0;
                    end else begin
                        selected_size <= selected_size + 1;
                    end
                end
            end
        end
    end
    
    //========================================================================
    // Selection Navigation - Maintenance Options
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected_maint_option <= MAINT_VIEW_ERRORS;
        end else begin
            if (current_menu_state == STATE_MAINT_OPTIONS) begin
                if (btn_left_pressed) begin
                    if (selected_maint_option == 0) begin
                        selected_maint_option <= NUM_MAINT_OPTIONS - 1;
                    end else begin
                        selected_maint_option <= selected_maint_option - 1;
                    end
                end else if (btn_right_pressed) begin
                    if (selected_maint_option >= NUM_MAINT_OPTIONS - 1) begin
                        selected_maint_option <= 0;
                    end else begin
                        selected_maint_option <= selected_maint_option + 1;
                    end
                end
            end
        end
    end
    
    //========================================================================
    // Control Output Logic
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_brewing_cmd <= 1'b0;
            enter_settings_mode <= 1'b0;
            enter_maintenance_mode <= 1'b0;
            manual_check_requested <= 1'b0;
            display_refresh <= 1'b0;
        end else begin
            // Start brewing command
            start_brewing_cmd <= (current_menu_state == STATE_CONFIRM && 
                                 next_menu_state == STATE_BREWING);
            
            // Enter settings mode
            enter_settings_mode <= (current_menu_state == STATE_SETTINGS);
            
            enter_maintenance_mode <= (current_menu_state == STATE_MAINTENANCE ||
                                       current_menu_state == STATE_MAINT_OPTIONS ||
                                       current_menu_state == STATE_MAINT_VIEW_ERRORS ||
                                       current_menu_state == STATE_MAINT_MANUAL_CHECK);
            
            manual_check_requested <= (current_menu_state == STATE_MAINT_MANUAL_CHECK && 
                                      btn_select_pressed);
            
            // Display refresh
            display_refresh <= state_changed;
        end
    end

endmodule