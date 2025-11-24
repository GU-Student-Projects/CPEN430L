//============================================================================
// Module: actuator_control
// Description: Actuator control with INTERLOCK DISABLED for testing
// Author: Gabriel DiMartino
// Date: November 2025
//============================================================================

`timescale 1ns/1ps

module actuator_control (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         grinder0_cmd,
    input  wire         grinder1_cmd,
    input  wire         water_pour_cmd,
    input  wire         water_direct_cmd,
    input  wire         paper_motor_cmd,
    input  wire         heater_cmd,
    input  wire         temp_ready,
    input  wire         pressure_ready,
    input  wire         water_system_ok,
    input  wire         system_fault,
    input  wire         paper_filter_present,
    input  wire         brewing_active,
    input  wire         emergency_stop,
    output reg          led_heater,
    output reg          led_water_pour,
    output reg          led_water_direct,
    output reg          led_grinder0,
    output reg          led_grinder1,
    output reg          led_paper_motor,
    output reg          actuators_active,
    output reg [5:0]    active_count
);

    parameter GRINDER_MAX_TIME = 32'd250_000_000;
    parameter WATER_MAX_TIME = 32'd500_000_000;
    parameter PAPER_MAX_TIME = 32'd50_000_000;
    parameter INTERLOCK_DELAY = 32'd2_500_000;
    parameter ENABLE_INTERLOCK = 0;  // FIXED: Disabled for testing (was 1)
    
    reg heater_safe;
    reg water_pour_safe;
    reg water_direct_safe;
    reg grinder0_safe;
    reg grinder1_safe;
    reg paper_motor_safe;
    
    reg [31:0] grinder0_timer;
    reg [31:0] grinder1_timer;
    reg [31:0] water_pour_timer;
    reg [31:0] water_direct_timer;
    reg [31:0] paper_motor_timer;
    
    reg grinder0_timeout;
    reg grinder1_timeout;
    reg water_pour_timeout;
    reg water_direct_timeout;
    reg paper_motor_timeout;
    
    reg [31:0] interlock_timer;
    reg interlock_active;
    
    reg grinder0_prev;
    reg grinder1_prev;
    reg water_pour_prev;
    reg water_direct_prev;
    reg paper_motor_prev;
    
    // Heater interlock
    always @(*) begin
        if (system_fault || emergency_stop) begin
            heater_safe = 1'b0;
        end else begin
            heater_safe = heater_cmd;
        end
    end
    
    // Water pour interlock
    always @(*) begin
        if (system_fault || emergency_stop || water_pour_timeout) begin
            water_pour_safe = 1'b0;
        end else if (!temp_ready || !pressure_ready || !paper_filter_present) begin
            water_pour_safe = 1'b0;
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            water_pour_safe = 1'b0;
        end else begin
            water_pour_safe = water_pour_cmd;
        end
    end
    
    // Water direct interlock
    always @(*) begin
        if (system_fault || emergency_stop || water_direct_timeout) begin
            water_direct_safe = 1'b0;
        end else if (!pressure_ready) begin
            water_direct_safe = 1'b0;
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            water_direct_safe = 1'b0;
        end else begin
            water_direct_safe = water_direct_cmd;
        end
    end
    
    // Grinder 0 interlock
    always @(*) begin
        if (system_fault || emergency_stop || grinder0_timeout) begin
            grinder0_safe = 1'b0;
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            grinder0_safe = 1'b0;
        end else begin
            grinder0_safe = grinder0_cmd;
        end
    end
    
    // Grinder 1 interlock
    always @(*) begin
        if (system_fault || emergency_stop || grinder1_timeout) begin
            grinder1_safe = 1'b0;
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            grinder1_safe = 1'b0;
        end else begin
            grinder1_safe = grinder1_cmd;
        end
    end
    
    // Paper motor interlock
    always @(*) begin
        if (system_fault || emergency_stop || paper_motor_timeout) begin
            paper_motor_safe = 1'b0;
        end else if (!paper_filter_present && paper_motor_cmd) begin
            paper_motor_safe = 1'b0;
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            paper_motor_safe = 1'b0;
        end else begin
            paper_motor_safe = paper_motor_cmd;
        end
    end
    
    // Timeout monitoring - Grinder 0
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grinder0_timer <= 0;
            grinder0_timeout <= 1'b0;
        end else begin
            if (!grinder0_cmd) begin
                grinder0_timer <= 0;
                grinder0_timeout <= 1'b0;
            end else if (grinder0_timer >= GRINDER_MAX_TIME) begin
                grinder0_timeout <= 1'b1;
            end else begin
                grinder0_timer <= grinder0_timer + 1;
            end
        end
    end
    
    // Timeout monitoring - Grinder 1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grinder1_timer <= 0;
            grinder1_timeout <= 1'b0;
        end else begin
            if (!grinder1_cmd) begin
                grinder1_timer <= 0;
                grinder1_timeout <= 1'b0;
            end else if (grinder1_timer >= GRINDER_MAX_TIME) begin
                grinder1_timeout <= 1'b1;
            end else begin
                grinder1_timer <= grinder1_timer + 1;
            end
        end
    end
    
    // Timeout monitoring - Water pour
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            water_pour_timer <= 0;
            water_pour_timeout <= 1'b0;
        end else begin
            if (!water_pour_cmd) begin
                water_pour_timer <= 0;
                water_pour_timeout <= 1'b0;
            end else if (water_pour_timer >= WATER_MAX_TIME) begin
                water_pour_timeout <= 1'b1;
            end else begin
                water_pour_timer <= water_pour_timer + 1;
            end
        end
    end
    
    // Timeout monitoring - Water direct
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            water_direct_timer <= 0;
            water_direct_timeout <= 1'b0;
        end else begin
            if (!water_direct_cmd) begin
                water_direct_timer <= 0;
                water_direct_timeout <= 1'b0;
            end else if (water_direct_timer >= WATER_MAX_TIME) begin
                water_direct_timeout <= 1'b1;
            end else begin
                water_direct_timer <= water_direct_timer + 1;
            end
        end
    end
    
    // Timeout monitoring - Paper motor
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            paper_motor_timer <= 0;
            paper_motor_timeout <= 1'b0;
        end else begin
            if (!paper_motor_cmd) begin
                paper_motor_timer <= 0;
                paper_motor_timeout <= 1'b0;
            end else if (paper_motor_timer >= PAPER_MAX_TIME) begin
                paper_motor_timeout <= 1'b1;
            end else begin
                paper_motor_timer <= paper_motor_timer + 1;
            end
        end
    end
    
    // Previous state tracking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grinder0_prev <= 1'b0;
            grinder1_prev <= 1'b0;
            water_pour_prev <= 1'b0;
            water_direct_prev <= 1'b0;
            paper_motor_prev <= 1'b0;
        end else begin
            grinder0_prev <= grinder0_safe;
            grinder1_prev <= grinder1_safe;
            water_pour_prev <= water_pour_safe;
            water_direct_prev <= water_direct_safe;
            paper_motor_prev <= paper_motor_safe;
        end
    end
    
    // Interlock delay timer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            interlock_timer <= 0;
            interlock_active <= 1'b0;
        end else begin
            if ((grinder0_safe != grinder0_prev) ||
                (grinder1_safe != grinder1_prev) ||
                (water_pour_safe != water_pour_prev) ||
                (water_direct_safe != water_direct_prev) ||
                (paper_motor_safe != paper_motor_prev)) begin
                interlock_timer <= INTERLOCK_DELAY;
                interlock_active <= 1'b1;
            end else if (interlock_timer > 0) begin
                interlock_timer <= interlock_timer - 1;
                interlock_active <= 1'b1;
            end else begin
                interlock_active <= 1'b0;
            end
        end
    end
    
    // Output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_heater <= 1'b0;
            led_water_pour <= 1'b0;
            led_water_direct <= 1'b0;
            led_grinder0 <= 1'b0;
            led_grinder1 <= 1'b0;
            led_paper_motor <= 1'b0;
        end else begin
            led_heater <= heater_safe;
            led_water_pour <= water_pour_safe;
            led_water_direct <= water_direct_safe;
            led_grinder0 <= grinder0_safe;
            led_grinder1 <= grinder1_safe;
            led_paper_motor <= paper_motor_safe;
        end
    end
    
    // Status monitoring
    always @(*) begin
        active_count = 0;
        if (led_heater) active_count = active_count + 1;
        if (led_water_pour) active_count = active_count + 1;
        if (led_water_direct) active_count = active_count + 1;
        if (led_grinder0) active_count = active_count + 1;
        if (led_grinder1) active_count = active_count + 1;
        if (led_paper_motor) active_count = active_count + 1;
    end
    
    always @(*) begin
        actuators_active = (active_count > 0);
    end
    
endmodule