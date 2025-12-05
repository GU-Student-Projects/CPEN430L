//============================================================================
// Module: main_fsm
// Description: Main FSM with splash screen error cycling and maintenance menu
//              Supports: Splash->Error Cycling->Menu flow
//              Hidden maintenance menu accessible via button combination
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module main_fsm (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,
    input  wire         rst_n,
    
    //========================================================================
    // Menu Navigator Interface
    //========================================================================
    input  wire [3:0]   menu_state,
    input  wire         start_brewing_cmd,
    input  wire         enter_settings_mode,
    input  wire         enter_maintenance_mode,
    input  wire [2:0]   selected_coffee_type,
    input  wire [2:0]   selected_drink_type,
    input  wire [1:0]   selected_size,
    
    //========================================================================
    // Recipe Engine Interface
    //========================================================================
    output reg          recipe_start_brewing,
    output reg          recipe_abort_brewing,
    input  wire         recipe_brewing_active,
    input  wire         recipe_brewing_complete,
    input  wire         recipe_valid,
    
    //========================================================================
    // Water Temperature Controller Interface
    //========================================================================
    output reg          water_heating_enable,
    output reg [1:0]    water_target_temp_mode,
    input  wire         water_temp_ready,
    input  wire         water_pressure_ready,
    input  wire         water_system_ok,
    
    //========================================================================
    // Consumable Manager Interface
    //========================================================================
    input  wire         can_make_coffee,
    input  wire         paper_filter_present,
    
    //========================================================================
    // Error Handler Interface
    //========================================================================
    input  wire         critical_error,
    input  wire [3:0]   warning_count,
    input  wire [3:0]   error_count,
    output reg          system_fault,
    
    //========================================================================
    // Service Timer Interface
    //========================================================================
    output reg          manual_check_clear,
    output reg          service_timer_enable,
    
    //========================================================================
    // Error Cycling Control 
    //========================================================================
    output reg          error_cycle_enable,
    
    //========================================================================
    // System Status Outputs
    //========================================================================
    output reg          system_ready,
    output reg          system_active,
    output reg          emergency_stop,
    output reg [2:0]    brew_stage,
    
    //========================================================================
    // Debug Outputs
    //========================================================================
    output wire [4:0]   debug_current_state
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Main FSM states
    parameter STATE_INIT = 5'd0;
    parameter STATE_SPLASH = 5'd1;
    parameter STATE_ERROR_CYCLE = 5'd2;
    parameter STATE_IDLE = 5'd3;
    parameter STATE_HEATING = 5'd4;
    parameter STATE_READY = 5'd5;
    parameter STATE_VALIDATE = 5'd6;
    parameter STATE_BREWING = 5'd7;
    parameter STATE_COMPLETE = 5'd8;
    parameter STATE_ERROR = 5'd9;
    parameter STATE_SETTINGS = 5'd10;
    parameter STATE_MAINTENANCE = 5'd11;
    parameter STATE_EMERGENCY = 5'd12;
    parameter STATE_COOLDOWN = 5'd13;
    
    // Menu states
    parameter MENU_SPLASH = 4'd0;
    parameter MENU_CHECK_ERRORS = 4'd1;
    parameter MENU_COFFEE_SELECT = 4'd2;
    parameter MENU_DRINK_SELECT = 4'd3;
    parameter MENU_SIZE_SELECT = 4'd4;
    parameter MENU_CONFIRM = 4'd5;
    parameter MENU_BREWING = 4'd6;
    parameter MENU_COMPLETE = 4'd7;
    parameter MENU_SETTINGS = 4'd8;
    parameter MENU_MAINTENANCE = 4'd9;
    parameter MENU_ERROR = 4'd10;
    parameter MENU_ABORT_CONFIRM = 4'd11;
    
    // Temperature modes
    parameter TEMP_STANDBY = 2'b00;
    parameter TEMP_BREWING = 2'b01;
    parameter TEMP_EXTRA_HOT = 2'b10;
    
    // Timing parameters
    `ifdef SIMULATION
        // Fast simulation times
        parameter INIT_DELAY = 32'd1000;              // 20us initialization
        parameter SPLASH_DISPLAY_TIME = 32'd2000;     // 40us on splash
        parameter COOLDOWN_TIME = 32'd2000;           // 40us cooldown
        parameter ERROR_RETRY_TIME = 32'd5000;        // 100us before retry
        parameter COMPLETE_TIMEOUT = 32'd10000;       // 200us for completion acknowledgment
    `else
        // Real hardware times
        parameter INIT_DELAY = 32'd50_000_000;          // 1 second initialization
        parameter SPLASH_DISPLAY_TIME = 32'd100_000_000; // 2 seconds on splash
        parameter COOLDOWN_TIME = 32'd100_000_000;      // 2 seconds cooldown
        parameter ERROR_RETRY_TIME = 32'd250_000_000;   // 5 seconds before retry
        parameter COMPLETE_TIMEOUT = 32'd1_500_000_000; // 30 seconds for completion acknowledgment
    `endif
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    reg [4:0] current_state;
    reg [4:0] next_state;
    reg [4:0] last_state;
    
    reg [31:0] state_timer;
    reg [31:0] error_timer;
    
    reg brewing_in_progress;
    reg brew_started;
    
    reg brew_recipe_started;
    
    //========================================================================
    // Debug Output Assignment
    //========================================================================
    
    assign debug_current_state = current_state;
    
    //========================================================================
    // State Machine - State Register
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_INIT;
            last_state <= STATE_INIT;
        end else begin
            last_state <= current_state;
            current_state <= next_state;
        end
    end
    
    //========================================================================
    // State Machine - Next State Logic
    //========================================================================
    
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            
            //================================================================
            // INIT - System initialization
            //================================================================
            STATE_INIT: begin
                if (state_timer >= INIT_DELAY) begin
                    next_state = STATE_SPLASH;
                end
            end
            
            //================================================================
            // SPLASH - Display splash screen
            //================================================================
            STATE_SPLASH: begin
                if (state_timer >= SPLASH_DISPLAY_TIME) begin
                    next_state = STATE_ERROR_CYCLE;
                end
            end
            
            //================================================================
            // ERROR_CYCLE - Cycle through errors/warnings
            //================================================================
            STATE_ERROR_CYCLE: begin
                if (critical_error) begin
                    next_state = STATE_ERROR;
                end else if (menu_state == MENU_COFFEE_SELECT || 
                           menu_state == MENU_DRINK_SELECT || 
                           menu_state == MENU_SIZE_SELECT) begin
                    next_state = STATE_IDLE;
                end
            end
            
            //================================================================
            // IDLE - Waiting for user selections
            //================================================================
            STATE_IDLE: begin
                if (critical_error) begin
                    next_state = STATE_ERROR_CYCLE;
                end else if (enter_maintenance_mode) begin
                    next_state = STATE_MAINTENANCE;
                end else if (start_brewing_cmd) begin
                    next_state = STATE_HEATING;
                end else if (menu_state == MENU_SPLASH) begin
                    // User cancelled back to splash
                    next_state = STATE_SPLASH;
                end
                // Stay in IDLE while user navigates coffee/drink/size selection
            end
            
            //================================================================
            // HEATING - Bringing water to temperature
            //================================================================
            STATE_HEATING: begin
                if (critical_error) begin
                    next_state = STATE_ERROR_CYCLE;
                end else if (menu_state == MENU_ABORT_CONFIRM) begin
                    next_state = STATE_COOLDOWN;
                end else if (water_temp_ready && water_pressure_ready) begin
                    // Water system ready - proceed to validation
                    next_state = STATE_VALIDATE;
                end
                // Stay in HEATING until water is ready - blocks all other transitions
            end
            
            //================================================================
            // READY - System ready to brew (water at temperature)
            //================================================================
            STATE_READY: begin
                if (critical_error) begin
                    next_state = STATE_ERROR_CYCLE;
                end else if (!recipe_valid) begin
                    next_state = STATE_ERROR;
                end else if (menu_state == MENU_ABORT_CONFIRM) begin
                    next_state = STATE_COOLDOWN;
                end else if (recipe_brewing_active) begin
                    next_state = STATE_BREWING;
                end
            end
            
            //================================================================
            // VALIDATE - Final validation before brewing
            //================================================================
            STATE_VALIDATE: begin
                if (critical_error) begin
                    next_state = STATE_ERROR_CYCLE;
                end else if (!recipe_valid) begin
                    next_state = STATE_ERROR;
                end else if (menu_state == MENU_ABORT_CONFIRM) begin
                    next_state = STATE_COOLDOWN;
                end else if (recipe_brewing_active) begin
                    next_state = STATE_BREWING;
                end
            end
            
            //================================================================
            // BREWING - Active brewing in progress
            //================================================================
            STATE_BREWING: begin
                if (critical_error) begin
                    next_state = STATE_ERROR_CYCLE;
                end else if (menu_state == MENU_ABORT_CONFIRM) begin
                    next_state = STATE_COOLDOWN;
                end else if (brew_recipe_started && recipe_brewing_complete) begin
                    next_state = STATE_COMPLETE;
                end
            end
            
            //================================================================
            // COMPLETE - Brewing complete
            //================================================================
            STATE_COMPLETE: begin
                if (critical_error) begin
                    next_state = STATE_ERROR_CYCLE;
                end else if (state_timer >= COMPLETE_TIMEOUT) begin
                    next_state = STATE_COOLDOWN;
                end else if (menu_state == MENU_COFFEE_SELECT || 
                           menu_state == MENU_SPLASH) begin
                    next_state = STATE_COOLDOWN;
                end
            end
            
            //================================================================
            // ERROR - System error state
            //================================================================
            STATE_ERROR: begin
                if (!critical_error && error_count == 0) begin
                    if (error_timer >= ERROR_RETRY_TIME) begin
                        next_state = STATE_IDLE;
                    end
                end else if (menu_state == MENU_SPLASH) begin
                    next_state = STATE_SPLASH;
                end
            end
            
            //================================================================
            // SETTINGS - Settings menu (not fully implemented)
            //================================================================
            STATE_SETTINGS: begin
                if (menu_state != MENU_SETTINGS) begin
                    next_state = STATE_IDLE;
                end
            end
            
            //================================================================
            // MAINTENANCE - Maintenance menu
            //================================================================
            STATE_MAINTENANCE: begin
                if (menu_state != MENU_MAINTENANCE) begin
                    next_state = STATE_IDLE;
                end
            end
            
            //================================================================
            // EMERGENCY - Emergency stop activated
            //================================================================
            STATE_EMERGENCY: begin
                if (!critical_error) begin
                    next_state = STATE_COOLDOWN;
                end
            end
            
            //================================================================
            // COOLDOWN - Cool down after brewing or abort
            //================================================================
            STATE_COOLDOWN: begin
                if (state_timer >= COOLDOWN_TIME) begin
                    if (critical_error) begin
                        next_state = STATE_ERROR;
                    end else begin
                        next_state = STATE_IDLE;
                    end
                end
            end
            
            //================================================================
            // Default case
            //================================================================
            default: begin
                next_state = STATE_INIT;
            end
            
        endcase
    end
    
    //========================================================================
    // State Machine - Output Logic
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            system_ready <= 1'b0;
            system_active <= 1'b0;
            system_fault <= 1'b0;
            emergency_stop <= 1'b0;
            water_heating_enable <= 1'b0;
            water_target_temp_mode <= TEMP_STANDBY;
            brewing_in_progress <= 1'b0;
            brew_started <= 1'b0;
            brew_recipe_started <= 1'b0;
            recipe_start_brewing <= 1'b0;
            recipe_abort_brewing <= 1'b0;
            error_cycle_enable <= 1'b0;
            manual_check_clear <= 1'b0;
            service_timer_enable <= 1'b0;
            brew_stage <= 3'd0;
        end else begin
            // Default: Clear one-shot signals
            recipe_start_brewing <= 1'b0;
            recipe_abort_brewing <= 1'b0;
            manual_check_clear <= 1'b0;
            
            case (current_state)
                
                STATE_INIT: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b0;
                    brew_stage <= 3'd0;
                end
                
                STATE_SPLASH: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd0;
                end
                
                STATE_ERROR_CYCLE: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    error_cycle_enable <= 1'b1;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd0;
                end
                
                STATE_IDLE: begin
                    system_ready <= 1'b1;
                    system_active <= 1'b0;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd0;
                end
                
                STATE_HEATING: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b1;
                    water_target_temp_mode <= TEMP_BREWING;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd1;  // Stage 1: Heating
                end
                
                STATE_READY: begin
                    system_ready <= 1'b1;
                    system_active <= 1'b0;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b1;
                    water_target_temp_mode <= TEMP_BREWING;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd0;
                    
                    // FIXED: Only pulse on entry to READY state, not continuously
                    if (last_state != STATE_READY) begin
                        recipe_start_brewing <= 1'b1;
                    end
                end
                
                STATE_VALIDATE: begin
                    system_ready <= 1'b1;
                    system_active <= 1'b0;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b1;
                    water_target_temp_mode <= TEMP_BREWING;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd0;
                    
                    if (recipe_valid && water_temp_ready && water_pressure_ready) begin
                        recipe_start_brewing <= 1'b1;
                    end
                end
                
                STATE_BREWING: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b1;
                    water_target_temp_mode <= TEMP_BREWING;
                    brewing_in_progress <= 1'b1;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    
                    // Calculate brew stage based on recipe progress
                    if (recipe_brewing_active) begin
                        brew_stage <= 3'd2;
                        brew_recipe_started <= 1'b1;
                        brew_started <= 1'b1;
                    end else begin
                        brew_stage <= 3'd1;
                    end
                    
                    if (last_state != STATE_BREWING && !recipe_brewing_active) begin
                        recipe_start_brewing <= 1'b1;
                    end
                    
                    // Clear brew_recipe_started flag on entry to BREWING
                    if (last_state != STATE_BREWING) begin
                        brew_recipe_started <= 1'b0;
                    end
                    
                    // Abort handling
                    if (current_state == STATE_BREWING && 
                        next_state != STATE_BREWING && 
                        next_state != STATE_COMPLETE) begin
                        recipe_abort_brewing <= 1'b1;
                        brewing_in_progress <= 1'b0;
                    end
                end
                
                STATE_COMPLETE: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b1;
                    water_target_temp_mode <= TEMP_BREWING;
                    brewing_in_progress <= 1'b0;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd7;  // Complete
                    
                    // Clear brewing flags to prevent restart
                    brew_started <= 1'b0;
                    brew_recipe_started <= 1'b0;
                end
                
                STATE_ERROR: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b1;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd0;
                    
                    if (recipe_brewing_active) begin
                        recipe_abort_brewing <= 1'b1;
                    end
                end
                
                STATE_SETTINGS: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd0;
                end
                
                STATE_MAINTENANCE: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b0;
                    brew_stage <= 3'd0;
                    
                end
                
                STATE_EMERGENCY: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b1;
                    emergency_stop <= 1'b1;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd0;
                    
                    recipe_abort_brewing <= 1'b1;
                end
                
                STATE_COOLDOWN: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b1;
                    brew_stage <= 3'd0;
                end
                
                default: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b1;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                    error_cycle_enable <= 1'b0;
                    service_timer_enable <= 1'b0;
                    brew_stage <= 3'd0;
                end
                
            endcase
        end
    end
    
    //========================================================================
    // State Timer Management
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_timer <= 0;
        end else begin
            if (current_state != last_state) begin
                state_timer <= 0;
            end else begin
                state_timer <= state_timer + 1;
            end
        end
    end
    
    //========================================================================
    // Error Timer Management
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_timer <= 0;
        end else begin
            if (current_state == STATE_ERROR || current_state == STATE_EMERGENCY) begin
                error_timer <= error_timer + 1;
            end else begin
                error_timer <= 0;
            end
        end
    end

endmodule