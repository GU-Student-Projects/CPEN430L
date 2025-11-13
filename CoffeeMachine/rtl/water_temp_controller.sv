//============================================================================
// Module: water_temp_controller
// Description: Autonomous water temperature and pressure controller
//              Manages heater control and monitors water system status
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module water_temp_controller (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,                    // 50 MHz system clock
    input  wire         rst_n,                  // Active-low reset
    
    //========================================================================
    // Sensor Interface
    //========================================================================
    input  wire         water_pressure_ok,      // Pressure sensor (from sensor_interface)
    input  wire         water_temp_override,    // Temperature override for testing
    input  wire         pressure_override,      // Pressure override for testing
    
    //========================================================================
    // Control Interface (from main FSM)
    //========================================================================
    input  wire         heating_enable,         // Enable heating system
    input  wire         brewing_active,         // Brewing in progress
    input  wire [1:0]   target_temp_mode,       // Temperature target mode
                                                // 00: Standby (warm)
                                                // 01: Brewing (hot)
                                                // 10: Extra hot
                                                // 11: Reserved
    
    //========================================================================
    // Actuator Outputs
    //========================================================================
    output reg          heater_enable,          // Heater control output
    
    //========================================================================
    // Status Outputs
    //========================================================================
    output reg          temp_ready,             // Temperature at target
    output reg          pressure_ready,         // Pressure in valid range
    output wire         water_system_ok,        // Overall water system status
    output reg [7:0]    current_temp,           // Current temperature (simulated)
    output reg [7:0]    target_temp,            // Target temperature
    output reg          overheat_error          // Overheat safety flag
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Temperature setpoints (arbitrary units 0-255)
    parameter TEMP_STANDBY = 8'd150;      // Warm standby temperature
    parameter TEMP_BREWING = 8'd200;      // Standard brewing temperature
    parameter TEMP_EXTRA_HOT = 8'd230;    // Extra hot mode
    parameter TEMP_COLD = 8'd25;          // Room temperature (cold start)
    parameter TEMP_MAX_SAFE = 8'd245;     // Safety cutoff temperature
    
    // Temperature hysteresis
    parameter TEMP_HYSTERESIS = 8'd5;     // ±5 units around target
    
    // These are shift amounts for exponential decay
    parameter HEAT_RATE_SHIFT = 3;        // Divide temperature delta by 8
    parameter COOL_RATE_SHIFT = 4;        // Divide temperature delta by 16
    parameter MIN_RATE = 8'd1;            // Minimum change rate
    
    // Timing parameters
    parameter HEATING_CYCLE_TIME = 50_000;  // 1ms at 50MHz (heating update rate)
    parameter PRESSURE_CHECK_TIME = 2_500_000;  // 50ms at 50MHz (pressure monitoring)
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    // Temperature simulation counter
    reg [31:0] heat_cycle_counter;
    reg        update_temperature;
    
    // Pressure monitoring counter
    reg [31:0] pressure_check_counter;
    reg        check_pressure;
    
    typedef enum logic [2:0] {
        STATE_COLD,         // Cold start - not heated
        STATE_HEATING,      // Actively heating
        STATE_AT_TEMP,      // At target temperature (merged READY + MAINTAINING)
        STATE_COOLING       // Cooling down
    } temp_state_t;
    
    temp_state_t temp_state;
    
    // Internal flags
    reg temp_at_target;
    reg temp_above_target;
    reg temp_below_target;
    
    reg [7:0] temp_delta;
    
    //========================================================================
    // Timing Generators
    //========================================================================
    
    // Heating cycle timer (controls temperature update rate)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            heat_cycle_counter <= 0;
            update_temperature <= 1'b0;
        end else begin
            if (heat_cycle_counter >= HEATING_CYCLE_TIME - 1) begin
                heat_cycle_counter <= 0;
                update_temperature <= 1'b1;
            end else begin
                heat_cycle_counter <= heat_cycle_counter + 1;
                update_temperature <= 1'b0;
            end
        end
    end
    
    // Pressure check timer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pressure_check_counter <= 0;
            check_pressure <= 1'b0;
        end else begin
            if (pressure_check_counter >= PRESSURE_CHECK_TIME - 1) begin
                pressure_check_counter <= 0;
                check_pressure <= 1'b1;
            end else begin
                pressure_check_counter <= pressure_check_counter + 1;
                check_pressure <= 1'b0;
            end
        end
    end
    
    //========================================================================
    // Target Temperature Selection
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_temp <= TEMP_STANDBY;
        end else begin
            case (target_temp_mode)
                2'b00: target_temp <= TEMP_STANDBY;
                2'b01: target_temp <= TEMP_BREWING;
                2'b10: target_temp <= TEMP_EXTRA_HOT;
                2'b11: target_temp <= TEMP_BREWING;  // Default to brewing
                default: target_temp <= TEMP_STANDBY;
            endcase
        end
    end
    
    //========================================================================
    // Temperature Comparison Logic
    //========================================================================
    
    always @(*) begin
        // Check if temperature is within hysteresis band
        if ((current_temp >= (target_temp - TEMP_HYSTERESIS)) && 
            (current_temp <= (target_temp + TEMP_HYSTERESIS))) begin
            temp_at_target = 1'b1;
            temp_above_target = 1'b0;
            temp_below_target = 1'b0;
        end else if (current_temp > (target_temp + TEMP_HYSTERESIS)) begin
            temp_at_target = 1'b0;
            temp_above_target = 1'b1;
            temp_below_target = 1'b0;
        end else begin
            temp_at_target = 1'b0;
            temp_above_target = 1'b0;
            temp_below_target = 1'b1;
        end
    end
    
    //========================================================================
    // Temperature Control State Machine
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_state <= STATE_COLD;
            heater_enable <= 1'b0;
            temp_ready <= 1'b0;
        end else begin
            case (temp_state)
                
                STATE_COLD: begin
                    heater_enable <= 1'b0;
                    temp_ready <= 1'b0;
                    
                    if (heating_enable && !water_temp_override) begin
                        temp_state <= STATE_HEATING;
                    end
                end
                
                STATE_HEATING: begin
                    temp_ready <= 1'b0;
                    
                    if (!heating_enable) begin
                        heater_enable <= 1'b0;
                        temp_state <= STATE_COOLING;
                    end else if (water_temp_override) begin
                        // Override forces cold state
                        heater_enable <= 1'b0;
                        temp_ready <= 1'b0;
                        temp_state <= STATE_COLD;
                    end else if (temp_at_target) begin
                        // Reached target temperature
                        heater_enable <= 1'b1;  // Keep heating on for now
                        temp_state <= STATE_AT_TEMP;
                    end else begin
                        // Continue heating
                        heater_enable <= 1'b1;
                    end
                end
                
                STATE_AT_TEMP: begin
                    temp_ready <= 1'b1;
                    
                    if (!heating_enable) begin
                        heater_enable <= 1'b0;
                        temp_state <= STATE_COOLING;
                    end else if (water_temp_override) begin
                        heater_enable <= 1'b0;
                        temp_ready <= 1'b0;
                        temp_state <= STATE_COLD;
                    end else if (temp_below_target) begin
                        // Below target - heat up
                        heater_enable <= 1'b1;
                    end else if (temp_above_target) begin
                        // Above target - turn off heater
                        heater_enable <= 1'b0;
                    end else begin
                        // At target - maintain
                        heater_enable <= 1'b1;
                    end
                end
                
                STATE_COOLING: begin
                    heater_enable <= 1'b0;
                    temp_ready <= 1'b0;
                    
                    if (heating_enable && !water_temp_override) begin
                        temp_state <= STATE_HEATING;
                    end else if (current_temp <= TEMP_COLD + 10) begin
                        temp_state <= STATE_COLD;
                    end
                end
                
                default: begin
                    temp_state <= STATE_COLD;
                    heater_enable <= 1'b0;
                    temp_ready <= 1'b0;
                end
                
            endcase
        end
    end
    
    //========================================================================
    // Temperature Simulation with Exponential Model
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_temp <= TEMP_COLD;
            overheat_error <= 1'b0;
        end else if (update_temperature) begin
            
            if (current_temp >= TEMP_MAX_SAFE) begin
                overheat_error <= 1'b1;
                // Force cooling by setting temp very high to trigger cooling logic
            end else begin
                overheat_error <= 1'b0;
            end
            
            if (water_temp_override || overheat_error) begin
                // Override forces cold temperature
                current_temp <= TEMP_COLD;
            end else if (heater_enable && (current_temp < TEMP_MAX_SAFE)) begin
                if (current_temp < target_temp) begin
                    temp_delta = (target_temp - current_temp) >> HEAT_RATE_SHIFT;
                    if (temp_delta < MIN_RATE) temp_delta = MIN_RATE;
                    
                    if ((current_temp + temp_delta) <= TEMP_MAX_SAFE) begin
                        current_temp <= current_temp + temp_delta;
                    end else begin
                        current_temp <= TEMP_MAX_SAFE;
                    end
                end
            end else if (!heater_enable && (current_temp > TEMP_COLD)) begin
                if (current_temp > TEMP_COLD) begin
                    temp_delta = (current_temp - TEMP_COLD) >> COOL_RATE_SHIFT;
                    if (temp_delta < MIN_RATE) temp_delta = MIN_RATE;
                    
                    if (current_temp >= (TEMP_COLD + temp_delta)) begin
                        current_temp <= current_temp - temp_delta;
                    end else begin
                        current_temp <= TEMP_COLD;
                    end
                end
            end
        end
    end
    
    //========================================================================
    // Pressure Monitoring
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pressure_ready <= 1'b1;  // Default: pressure OK
        end else if (check_pressure) begin
            if (pressure_override) begin
                // Override forces pressure error
                pressure_ready <= 1'b0;
            end else begin
                // Normal operation - follow sensor
                pressure_ready <= water_pressure_ok;
            end
        end
    end
    
    //========================================================================
    // Overall Water System Status
    //========================================================================
    
    // System is OK if both temperature and pressure are ready
    assign water_system_ok = temp_ready && pressure_ready && !overheat_error;
    
    //========================================================================
    // Debug/Monitoring (Optional - removed during synthesis)
    //========================================================================
    
    // Synthesis translate_off
    // reg [2:0] prev_temp_state;
    
    // always @(posedge clk) begin
    //     prev_temp_state <= temp_state;
        
    //     // Log state transitions
    //     if (temp_state != prev_temp_state) begin
    //         case (temp_state)
    //             STATE_COLD: $display("[%0t] Water Controller: STATE_COLD", $time);
    //             STATE_HEATING: $display("[%0t] Water Controller: STATE_HEATING", $time);
    //             STATE_AT_TEMP: $display("[%0t] Water Controller: STATE_AT_TEMP", $time);
    //             STATE_COOLING: $display("[%0t] Water Controller: STATE_COOLING", $time);
    //         endcase
    //     end
        
    //     // Log temperature milestones
    //     if (temp_ready && !temp_ready) begin
    //         $display("[%0t] Water temperature READY (current: %0d, target: %0d)", 
    //                  $time, current_temp, target_temp);
    //     end
        
    //     // Log pressure issues
    //     if (check_pressure && !pressure_ready) begin
    //         $display("[%0t] WARNING: Water pressure NOT OK!", $time);
    //     end
        
    //     // Log override conditions
    //     if (water_temp_override) begin
    //         $display("[%0t] WARNING: Temperature override active - forcing COLD", $time);
    //     end
    //     if (pressure_override) begin
    //         $display("[%0t] WARNING: Pressure override active - forcing ERROR", $time);
    //     end
        
    //     // Log overheat
    //     if (overheat_error) begin
    //         $display("[%0t] CRITICAL: OVERHEAT detected! Temp: %0d >= Max: %0d", 
    //                  $time, current_temp, TEMP_MAX_SAFE);
    //     end
    // end
    // Synthesis translate_on
    
endmodule