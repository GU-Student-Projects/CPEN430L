//============================================================================
// Module: water_temp_controller
// Description: Autonomous water temperature and pressure controller
//              FIXED: Realistic heating (30s to reach temp, 1min cooldown)
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
    
    // Temperature change rates (realistic timing)
    // Target: 15 seconds to heat from 25°C to 200°C = 175°C increase
    // At 1ms update rate: 15000 updates in 15 seconds
    // Rate needed: 175 / 15000 = 0.0117°C per update ≈ 1°C per 86 updates
    
    parameter HEAT_RATE = 8'd1;           // Heat 1 unit per update
    parameter COOL_RATE = 8'd1;           // Cool 1 unit per update
    parameter HEAT_UPDATE_DIV = 16'd86;   // Heat every 86ms (~15s total)
    parameter COOL_UPDATE_DIV = 16'd10000; // Cool every 10 seconds per degree!
    
    // Timing parameters
    parameter HEATING_CYCLE_TIME = 50_000;  // 1ms at 50MHz (base update rate)
    parameter PRESSURE_CHECK_TIME = 2_500_000;  // 50ms at 50MHz (pressure monitoring)
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    // Temperature simulation counter
    reg [31:0] heat_cycle_counter;
    reg        update_temperature;
    
    // Rate divider counters for realistic heating/cooling
    reg [15:0] heat_divider;
    reg [15:0] cool_divider;
    reg        do_heat_update;
    reg        do_cool_update;
    
    // Pressure monitoring counter
    reg [31:0] pressure_check_counter;
    reg        check_pressure;
    
    typedef enum logic [2:0] {
        STATE_COLD,         // Cold start - not heated
        STATE_HEATING,      // Actively heating
        STATE_AT_TEMP,      // At target temperature
        STATE_COOLING       // Cooling down
    } temp_state_t;
    
    temp_state_t temp_state;
    
    // Internal flags
    reg temp_at_target;
    reg temp_above_target;
    reg temp_below_target;
    
    //========================================================================
    // Timing Generators
    //========================================================================
    
    // Heating cycle timer (1ms base update rate)
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
    
    // Heat rate divider (slow down heating to realistic rate)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            heat_divider <= 0;
            do_heat_update <= 1'b0;
        end else if (update_temperature) begin
            if (heat_divider >= HEAT_UPDATE_DIV - 1) begin
                heat_divider <= 0;
                do_heat_update <= 1'b1;
            end else begin
                heat_divider <= heat_divider + 1;
                do_heat_update <= 1'b0;
            end
        end else begin
            do_heat_update <= 1'b0;
        end
    end
    
    // Cool rate divider (even slower cooling)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cool_divider <= 0;
            do_cool_update <= 1'b0;
        end else if (update_temperature) begin
            if (cool_divider >= COOL_UPDATE_DIV - 1) begin
                cool_divider <= 0;
                do_cool_update <= 1'b1;
            end else begin
                cool_divider <= cool_divider + 1;
                do_cool_update <= 1'b0;
            end
        end else begin
            do_cool_update <= 1'b0;
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
                    
                    if (water_temp_override) begin
                        // Override: force temperature ready for testing
                        temp_ready <= 1'b1;
                    end else begin
                        temp_ready <= 1'b0;
                        
                        if (heating_enable) begin
                            temp_state <= STATE_HEATING;
                        end
                    end
                end
                
                STATE_HEATING: begin
                    
                    if (water_temp_override) begin
                        // Override: instantly ready for testing
                        heater_enable <= 1'b0;
                        temp_ready <= 1'b1;
                        temp_state <= STATE_AT_TEMP;
                    end else if (!heating_enable) begin
                        heater_enable <= 1'b0;
                        temp_ready <= 1'b0;
                        temp_state <= STATE_COOLING;
                    end else if (temp_at_target) begin
                        // Reached target temperature
                        heater_enable <= 1'b1;  // Keep heating on for maintenance
                        temp_ready <= 1'b1;
                        temp_state <= STATE_AT_TEMP;
                    end else begin
                        // Continue heating
                        heater_enable <= 1'b1;
                        temp_ready <= 1'b0;
                    end
                end
                
                STATE_AT_TEMP: begin
                    
                    if (water_temp_override) begin
                        // Override keeps us ready
                        temp_ready <= 1'b1;
                        heater_enable <= 1'b0;
                    end else if (!heating_enable && !brewing_active) begin
                        heater_enable <= 1'b0;
                        temp_ready <= 1'b0;
                        temp_state <= STATE_COOLING;
                    end else if (temp_below_target) begin
                        // Below target - heat up
                        heater_enable <= 1'b1;
                        temp_ready <= 1'b0;
                        temp_state <= STATE_HEATING;  // Go back to heating
                    end else if (temp_above_target) begin
                        // Above target - turn off heater, let it cool
                        heater_enable <= 1'b0;
                        temp_ready <= 1'b1;
                    end else begin
                        // At target - maintain with cycling
                        heater_enable <= 1'b1;
                        temp_ready <= 1'b1;
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
    // Temperature Simulation with Realistic Rates
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_temp <= TEMP_COLD;
            overheat_error <= 1'b0;
        end else begin
            
            // Overheat detection
            if (current_temp >= TEMP_MAX_SAFE) begin
                overheat_error <= 1'b1;
            end else begin
                overheat_error <= 1'b0;
            end
            
            // Override forces temperature to target
            if (water_temp_override) begin
                current_temp <= target_temp;  // Set to target temp instantly
            // Overheat forces cold
            end else if (overheat_error) begin
                current_temp <= TEMP_COLD;
            // Heating: only update at divided rate
            end else if (heater_enable && do_heat_update && (current_temp < TEMP_MAX_SAFE)) begin
                if (current_temp < target_temp) begin
                    if ((current_temp + HEAT_RATE) <= TEMP_MAX_SAFE) begin
                        current_temp <= current_temp + HEAT_RATE;
                    end else begin
                        current_temp <= TEMP_MAX_SAFE;
                    end
                end
            // Cooling: only update at divided rate (slower than heating)
            end else if (!heater_enable && do_cool_update && (current_temp > TEMP_COLD)) begin
                if (current_temp >= (TEMP_COLD + COOL_RATE)) begin
                    current_temp <= current_temp - COOL_RATE;
                end else begin
                    current_temp <= TEMP_COLD;
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

endmodule