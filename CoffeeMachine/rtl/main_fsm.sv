//============================================================================
// Module: main_fsm
// Description: Main finite state machine controller for coffee machine
//              Orchestrates all subsystems and manages system-level states
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
// 
//============================================================================

`timescale 1ns/1ps

module main_fsm (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,                    // 50 MHz system clock
    input  wire         rst_n,                  // Active-low reset
    
    //========================================================================
    // Menu Navigator Interface
    //========================================================================
    input  wire [3:0]   menu_state,             // Current menu state
    input  wire         start_brewing_cmd,      // Start brewing command
    input  wire         enter_settings_mode,    // Enter settings command
    input  wire [2:0]   selected_coffee_type,   // Selected coffee bin
    input  wire [2:0]   selected_drink_type,    // Selected drink type
    input  wire [1:0]   selected_size,          // Selected size
    
    //========================================================================
    // Recipe Engine Interface
    //========================================================================
    output reg          recipe_start_brewing,   // Start brewing in recipe engine
    output reg          recipe_abort_brewing,   // Abort brewing
    input  wire         recipe_brewing_active,  // Recipe engine is brewing
    input  wire         recipe_brewing_complete,// Brew cycle complete
    input  wire         recipe_valid,           // Recipe is valid
    
    //========================================================================
    // Water Temperature Controller Interface
    //========================================================================
    output reg          water_heating_enable,   // Enable heating system
    output reg [1:0]    water_target_temp_mode, // Target temperature mode
    input  wire         water_temp_ready,       // Temperature ready
    input  wire         water_pressure_ready,   // Pressure ready
    input  wire         water_system_ok,        // Overall water system OK
    
    //========================================================================
    // Consumable Manager Interface
    //========================================================================
    input  wire         can_make_coffee,        // At least one bin has coffee
    input  wire         paper_filter_present,   // Paper filter available
    
    //========================================================================
    // Error Handler Interface
    //========================================================================
    input  wire         critical_error,         // Critical error present
    input  wire [3:0]   warning_count,          // Number of warnings
    output reg          system_fault,           // System fault flag
    
    //========================================================================
    // System Status Outputs
    //========================================================================
    output reg          system_ready,           // System ready to brew
    output reg          system_active,          // System actively working
    output reg          emergency_stop          // Emergency stop signal
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Main FSM states
    parameter STATE_INIT = 5'd0;
    parameter STATE_IDLE = 5'd1;
    parameter STATE_HEATING = 5'd2;
    parameter STATE_READY = 5'd3;
    parameter STATE_VALIDATE = 5'd4;
    parameter STATE_BREWING = 5'd5;
    parameter STATE_COMPLETE = 5'd6;
    parameter STATE_ERROR = 5'd7;
    parameter STATE_SETTINGS = 5'd8;
    parameter STATE_EMERGENCY = 5'd9;
    parameter STATE_COOLDOWN = 5'd10;
    
    // Menu states (from menu_navigator)
    parameter MENU_SPLASH = 4'd0;
    parameter MENU_CHECK_ERRORS = 4'd1;
    parameter MENU_COFFEE_SELECT = 4'd2;
    parameter MENU_DRINK_SELECT = 4'd3;
    parameter MENU_SIZE_SELECT = 4'd4;
    parameter MENU_CONFIRM = 4'd5;
    parameter MENU_BREWING = 4'd6;
    parameter MENU_COMPLETE = 4'd7;
    parameter MENU_SETTINGS = 4'd8;
    parameter MENU_ERROR = 4'd9;
    
    // Temperature modes
    parameter TEMP_STANDBY = 2'b00;
    parameter TEMP_BREWING = 2'b01;
    parameter TEMP_EXTRA_HOT = 2'b10;
    
    // Timing parameters
    parameter INIT_DELAY = 32'd50_000_000;      // 1 second initialization
    parameter COOLDOWN_TIME = 32'd100_000_000;  // 2 seconds cooldown
    parameter ERROR_RETRY_TIME = 32'd250_000_000; // 5 seconds before retry
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    // State machine
    reg [4:0] current_state;
    reg [4:0] next_state;
    reg [4:0] last_state;
    
    // Timers
    reg [31:0] state_timer;
    reg [31:0] error_timer;
    
    // Brewing tracking
    reg brewing_in_progress;
    reg brew_started;
    
    //========================================================================
    // State Machine - State Register
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_INIT;
            last_state <= STATE_INIT;
        end else begin
            last_state <= current_state;  // FIX: Track previous state
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
                    next_state = STATE_IDLE;
                end
            end
            
            //================================================================
            // IDLE - System off, standby
            //================================================================
            STATE_IDLE: begin
                if (critical_error) begin
                    next_state = STATE_ERROR;
                end else if (menu_state != MENU_SPLASH) begin
                    // User interaction detected, start heating
                    next_state = STATE_HEATING;
                end else if (enter_settings_mode) begin
                    next_state = STATE_SETTINGS;
                end
            end
            
            //================================================================
            // HEATING - Bringing water to temperature
            //================================================================
            STATE_HEATING: begin
                if (critical_error) begin
                    next_state = STATE_ERROR;
                end else if (water_system_ok) begin
                    next_state = STATE_READY;
                end else if (menu_state == MENU_SPLASH) begin
                    // User went back to splash, return to idle
                    next_state = STATE_COOLDOWN;
                end else if (enter_settings_mode) begin
                    next_state = STATE_SETTINGS;
                end
            end
            
            //================================================================
            // READY - System ready, waiting for brew command
            //================================================================
            STATE_READY: begin
                if (critical_error) begin
                    next_state = STATE_ERROR;
                end else if (start_brewing_cmd) begin
                    next_state = STATE_VALIDATE;
                end else if (menu_state == MENU_SPLASH) begin
                    // Return to idle after period of inactivity
                    if (state_timer >= COOLDOWN_TIME) begin
                        next_state = STATE_COOLDOWN;
                    end
                end else if (!water_system_ok) begin
                    // Water system lost readiness
                    next_state = STATE_HEATING;
                end else if (enter_settings_mode) begin
                    next_state = STATE_SETTINGS;
                end
            end
            
            //================================================================
            // VALIDATE - Pre-brew validation
            //================================================================
            STATE_VALIDATE: begin
                if (critical_error) begin
                    next_state = STATE_ERROR;
                end else if (!recipe_valid || !can_make_coffee || !paper_filter_present) begin
                    next_state = STATE_ERROR;
                end else if (water_system_ok) begin
                    next_state = STATE_BREWING;
                end else begin
                    // Validation failed
                    next_state = STATE_ERROR;
                end
            end
            
            //================================================================
            // BREWING - Active brewing cycle
            //================================================================
            STATE_BREWING: begin
                if (critical_error) begin
                    next_state = STATE_EMERGENCY;
                end else if (recipe_brewing_complete) begin
                    next_state = STATE_COMPLETE;
                end else if (!recipe_brewing_active && brew_started) begin
                    // Brewing stopped unexpectedly
                    next_state = STATE_ERROR;
                end else if (menu_state != MENU_BREWING) begin
                    // User canceled brewing
                    next_state = STATE_READY;
                end
            end
            
            //================================================================
            // COMPLETE - Brewing complete
            //================================================================
            STATE_COMPLETE: begin
                if (critical_error) begin
                    next_state = STATE_ERROR;
                end else if (menu_state != MENU_COMPLETE) begin
                    // User acknowledged completion
                    next_state = STATE_READY;
                end else if (state_timer >= COOLDOWN_TIME * 2) begin
                    // Auto-return to ready after 4 seconds
                    next_state = STATE_READY;
                end
            end
            
            //================================================================
            // ERROR - Error handling state
            //================================================================
            STATE_ERROR: begin
                if (!critical_error && error_timer >= ERROR_RETRY_TIME) begin
                    // Error cleared, return to appropriate state
                    if (can_make_coffee && paper_filter_present) begin
                        next_state = STATE_HEATING;
                    end else begin
                        next_state = STATE_IDLE;
                    end
                end else if (menu_state == MENU_SPLASH) begin
                    // User returned to splash, go to idle
                    next_state = STATE_IDLE;
                end else if (enter_settings_mode) begin
                    next_state = STATE_SETTINGS;
                end
            end
            
            //================================================================
            // SETTINGS - Settings/maintenance mode
            //================================================================
            STATE_SETTINGS: begin
                if (menu_state != MENU_SETTINGS) begin
                    // User exited settings
                    next_state = STATE_IDLE;
                end
            end
            
            //================================================================
            // EMERGENCY - Emergency stop state
            //================================================================
            STATE_EMERGENCY: begin
                if (!critical_error && error_timer >= ERROR_RETRY_TIME) begin
                    next_state = STATE_IDLE;
                end
            end
            
            //================================================================
            // COOLDOWN - Controlled shutdown to idle
            //================================================================
            STATE_COOLDOWN: begin
                if (state_timer >= COOLDOWN_TIME) begin
                    next_state = STATE_IDLE;
                end else if (menu_state != MENU_SPLASH) begin
                    // User became active again
                    next_state = STATE_HEATING;
                end
            end
            
            //================================================================
            // DEFAULT
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
            // Recipe engine outputs
            recipe_start_brewing <= 1'b0;
            recipe_abort_brewing <= 1'b0;
            
            // Water controller outputs
            water_heating_enable <= 1'b0;
            water_target_temp_mode <= TEMP_STANDBY;
            
            // System status outputs
            system_ready <= 1'b0;
            system_active <= 1'b0;
            system_fault <= 1'b0;
            emergency_stop <= 1'b0;
            
            // Internal tracking
            brewing_in_progress <= 1'b0;
            brew_started <= 1'b0;
            
        end else begin
            recipe_start_brewing <= 1'b0;
            recipe_abort_brewing <= 1'b0;
            
            case (current_state)
                
                STATE_INIT: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                end
                
                STATE_IDLE: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                    brew_started <= 1'b0;
                end
                
                STATE_HEATING: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b1;
                    water_target_temp_mode <= TEMP_BREWING;
                    brewing_in_progress <= 1'b0;
                    brew_started <= 1'b0;
                end
                
                STATE_READY: begin
                    system_ready <= 1'b1;
                    system_active <= 1'b0;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b1;
                    water_target_temp_mode <= TEMP_BREWING;
                    brewing_in_progress <= 1'b0;
                    brew_started <= 1'b0;
                end
                
                STATE_VALIDATE: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b1;
                    water_target_temp_mode <= TEMP_BREWING;
                    brewing_in_progress <= 1'b0;
                end
                
                STATE_BREWING: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b1;
                    system_fault <= 1'b0;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b1;
                    water_target_temp_mode <= TEMP_BREWING;
                    brewing_in_progress <= 1'b1;
                    
                    if (last_state != STATE_BREWING) begin
                        // Just entered BREWING state - start brewing!
                        recipe_start_brewing <= 1'b1;
                        brew_started <= 1'b1;
                    end
                    
                    if (current_state == STATE_BREWING && next_state != STATE_BREWING && next_state != STATE_COMPLETE) begin
                        // Leaving BREWING prematurely (not to COMPLETE) - abort!
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
                end
                
                STATE_ERROR: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b1;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                    
                    // Abort any ongoing brewing
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
                end
                
                STATE_EMERGENCY: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b1;
                    emergency_stop <= 1'b1;  // EMERGENCY STOP!
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
                    
                    // Force abort brewing
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
                end
                
                default: begin
                    system_ready <= 1'b0;
                    system_active <= 1'b0;
                    system_fault <= 1'b1;
                    emergency_stop <= 1'b0;
                    water_heating_enable <= 1'b0;
                    water_target_temp_mode <= TEMP_STANDBY;
                    brewing_in_progress <= 1'b0;
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
                // State changed - reset timer
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
    
    //========================================================================
    // Debug/Monitoring (Optional - removed during synthesis)
    //========================================================================
    
    // Synthesis translate_off
    // function [8*16-1:0] state_name;
    //     input [4:0] state;
    //     begin
    //         case (state)
    //             STATE_INIT: state_name = "INIT";
    //             STATE_IDLE: state_name = "IDLE";
    //             STATE_HEATING: state_name = "HEATING";
    //             STATE_READY: state_name = "READY";
    //             STATE_VALIDATE: state_name = "VALIDATE";
    //             STATE_BREWING: state_name = "BREWING";
    //             STATE_COMPLETE: state_name = "COMPLETE";
    //             STATE_ERROR: state_name = "ERROR";
    //             STATE_SETTINGS: state_name = "SETTINGS";
    //             STATE_EMERGENCY: state_name = "EMERGENCY";
    //             STATE_COOLDOWN: state_name = "COOLDOWN";
    //             default: state_name = "UNKNOWN";
    //         endcase
    //     end
    // endfunction
    
    // always @(posedge clk) begin
    //     // Log state transitions
    //     if (current_state != last_state) begin
    //         $display("[%0t] Main FSM: %s -> %s", $time, state_name(last_state), state_name(current_state));
    //     end
        
    //     // Log important events
    //     if (recipe_start_brewing) begin
    //         $display("[%0t] Main FSM: Starting brewing cycle", $time);
    //     end
        
    //     if (recipe_abort_brewing) begin
    //         $display("[%0t] Main FSM: Aborting brewing cycle", $time);
    //     end
        
    //     if (emergency_stop) begin
    //         $display("[%0t] Main FSM: *** EMERGENCY STOP ACTIVE ***", $time);
    //     end
        
    //     if (system_fault) begin
    //         $display("[%0t] Main FSM: System fault flag set", $time);
    //     end
    // end
    // Synthesis translate_on
    
endmodule