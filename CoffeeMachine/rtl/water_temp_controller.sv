//============================================================================
// Module: water_temp_controller  
// Description: Override now properly forces temp_ready
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module water_temp_controller (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         water_pressure_ok,
    input  wire         water_temp_override,
    input  wire         pressure_override,
    input  wire         heating_enable,
    input  wire         brewing_active,
    input  wire [1:0]   target_temp_mode,
    output reg          heater_enable,
    output reg          temp_ready,
    output reg          pressure_ready,
    output wire         water_system_ok,
    output reg [7:0]    current_temp,
    output reg [7:0]    target_temp,
    output reg          overheat_error
);

    parameter TEMP_STANDBY = 8'd150;
    parameter TEMP_BREWING = 8'd200;
    parameter TEMP_EXTRA_HOT = 8'd230;
    parameter TEMP_COLD = 8'd25;
    parameter TEMP_MAX_SAFE = 8'd245;
    parameter TEMP_HYSTERESIS = 8'd5;
    
    parameter HEAT_RATE = 8'd1;
    parameter COOL_RATE = 8'd1;
    parameter HEAT_UPDATE_DIV = 16'd10;      // Fast heating: update every 10ms
    parameter COOL_UPDATE_DIV = 16'd5000;    // SLOW cooling: update every 5 seconds
    
    parameter HEATING_CYCLE_TIME = 50_000;  // 1ms
    parameter PRESSURE_CHECK_TIME = 2_500_000;  // 50ms
    
    reg [31:0] heat_cycle_counter;
    reg        update_temperature;
    reg [15:0] heat_divider;
    reg [15:0] cool_divider;
    reg        do_heat_update;
    reg        do_cool_update;
    reg [31:0] pressure_check_counter;
    reg        check_pressure;
    
    typedef enum logic [2:0] {
        STATE_COLD,
        STATE_HEATING,
        STATE_AT_TEMP,
        STATE_COOLING
    } temp_state_t;
    
    temp_state_t temp_state;
    
    reg temp_at_target;
    reg temp_above_target;
    reg temp_below_target;
    
    //========================================================================
    // Timing Generators
    //========================================================================
    
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
                2'b11: target_temp <= TEMP_BREWING;
                default: target_temp <= TEMP_STANDBY;
            endcase
        end
    end
    
    //========================================================================
    // Temperature Comparison Logic
    //========================================================================
    
    always @(*) begin
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
            if (water_temp_override) begin
                temp_ready <= 1'b1;  // Force ready when override is active
                heater_enable <= 1'b0;  // Don't need heater with override
                // Stay in current state or go to AT_TEMP
                if (temp_state == STATE_COLD || temp_state == STATE_COOLING) begin
                    temp_state <= STATE_AT_TEMP;
                end
            end else begin
                // Normal operation without override
                case (temp_state)
                    
                    STATE_COLD: begin
                        heater_enable <= 1'b0;
                        temp_ready <= 1'b0;
                        
                        if (heating_enable) begin
                            temp_state <= STATE_HEATING;
                        end
                    end
                    
                    STATE_HEATING: begin
                        if (!heating_enable) begin
                            heater_enable <= 1'b0;
                            temp_ready <= 1'b0;
                            temp_state <= STATE_COOLING;
                        end else if (temp_at_target) begin
                            heater_enable <= 1'b1;
                            temp_ready <= 1'b1;
                            temp_state <= STATE_AT_TEMP;
                        end else begin
                            heater_enable <= 1'b1;
                            temp_ready <= 1'b0;
                        end
                    end
                    
                    STATE_AT_TEMP: begin
                        if (!heating_enable && !brewing_active) begin
                            heater_enable <= 1'b0;
                            temp_ready <= 1'b0;
                            temp_state <= STATE_COOLING;
                        end else if (temp_below_target) begin
                            heater_enable <= 1'b1;
                            temp_ready <= 1'b0;
                            temp_state <= STATE_HEATING;
                        end else if (temp_above_target) begin
                            heater_enable <= 1'b0;
                            temp_ready <= 1'b1;
                        end else begin
                            heater_enable <= 1'b1;
                            temp_ready <= 1'b1;
                        end
                    end
                    
                    STATE_COOLING: begin
                        heater_enable <= 1'b0;
                        temp_ready <= 1'b0;
                        
                        if (heating_enable) begin
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
    end
    
    //========================================================================
    // Temperature Simulation
    //========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_temp <= TEMP_COLD;
            overheat_error <= 1'b0;
        end else begin
            if (current_temp >= TEMP_MAX_SAFE) begin
                overheat_error <= 1'b1;
            end else begin
                overheat_error <= 1'b0;
            end
            
            if (water_temp_override) begin
                current_temp <= TEMP_BREWING;  // Always go to brewing temp with override
            end else if (overheat_error) begin
                current_temp <= TEMP_COLD;
            end else if (heater_enable && do_heat_update && (current_temp < TEMP_MAX_SAFE)) begin
                if (current_temp < target_temp) begin
                    if ((current_temp + HEAT_RATE) <= TEMP_MAX_SAFE) begin
                        current_temp <= current_temp + HEAT_RATE;
                    end else begin
                        current_temp <= TEMP_MAX_SAFE;
                    end
                end
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
            pressure_ready <= 1'b1;
        end else if (check_pressure) begin
            if (pressure_override) begin
                pressure_ready <= 1'b0;
            end else begin
                pressure_ready <= water_pressure_ok;
            end
        end
    end
    
    //========================================================================
    // Overall Water System Status
    //========================================================================
    
    assign water_system_ok = temp_ready && pressure_ready && !overheat_error;

endmodule