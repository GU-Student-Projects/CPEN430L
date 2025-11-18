//============================================================================
// Module: actuator_control
// Description: Actuator control and safety interlocking for coffee machine
//              Manages grinders, water valves, heater, and paper motor
// Author: Gabriel DiMartino
// Date: November 2025
// Course: CPEN-430 Digital System Design Lab
//============================================================================

`timescale 1ns/1ps

module actuator_control (
    //========================================================================
    // Clock and Reset
    //========================================================================
    input  wire         clk,                    // 50 MHz system clock
    input  wire         rst_n,                  // Active-low reset
    
    //========================================================================
    // Recipe Engine Commands
    //========================================================================
    input  wire         grinder0_cmd,           // Grinder 0 command
    input  wire         grinder1_cmd,           // Grinder 1 command
    input  wire         water_pour_cmd,         // Pour-over water command
    input  wire         water_direct_cmd,       // Direct water command
    input  wire         paper_motor_cmd,        // Paper motor command
    
    //========================================================================
    // Water System Status (safety interlocks)
    //========================================================================
    input  wire         heater_cmd,             // Heater command from water controller
    input  wire         temp_ready,             // Temperature at target
    input  wire         pressure_ready,         // Pressure in valid range
    input  wire         water_system_ok,        // Overall water system OK
    
    //========================================================================
    // System Status (safety interlocks)
    //========================================================================
    input  wire         system_fault,           // Critical system fault
    input  wire         paper_filter_present,   // Paper filter present
    input  wire         brewing_active,         // Brewing in progress
    input  wire         emergency_stop,         // Emergency stop signal
    
    //========================================================================
    // Physical Actuator Outputs (to LEDs in simulation)
    //========================================================================
    output reg          led_heater,             // LED[8]: Heater enable
    output reg          led_water_pour,         // LED[9]: Pour-over water
    output reg          led_water_direct,       // LED[10]: Direct water
    output reg          led_grinder0,           // LED[11]: Grinder 0
    output reg          led_grinder1,           // LED[12]: Grinder 1
    output reg          led_paper_motor,        // LED[13]: Paper motor
    
    //========================================================================
    // Status Outputs
    //========================================================================
    output reg          actuators_active,       // Any actuator active
    output reg [5:0]    active_count            // Number of active actuators
);

    //========================================================================
    // Parameters
    //========================================================================
    
    // Safety timeout parameters
    parameter GRINDER_MAX_TIME = 32'd250_000_000;    // 5 seconds max grind
    parameter WATER_MAX_TIME = 32'd500_000_000;      // 10 seconds max water flow
    parameter PAPER_MAX_TIME = 32'd50_000_000;       // 1 second max paper feed
    
    // Minimum delays between operations
    parameter INTERLOCK_DELAY = 32'd2_500_000;       // 50ms between switching
    parameter ENABLE_INTERLOCK = 1;                  // Enable interlock delay (set to 0 for testing)
    
    //========================================================================
    // Internal Registers
    //========================================================================
    
    // Safety interlocked outputs
    reg heater_safe;
    reg water_pour_safe;
    reg water_direct_safe;
    reg grinder0_safe;
    reg grinder1_safe;
    reg paper_motor_safe;
    
    // Timeout timers
    reg [31:0] grinder0_timer;
    reg [31:0] grinder1_timer;
    reg [31:0] water_pour_timer;
    reg [31:0] water_direct_timer;
    reg [31:0] paper_motor_timer;
    
    // Timeout flags
    reg grinder0_timeout;
    reg grinder1_timeout;
    reg water_pour_timeout;
    reg water_direct_timeout;
    reg paper_motor_timeout;
    
    // Interlock delay timer
    reg [31:0] interlock_timer;
    reg interlock_active;
    
    // Previous state tracking for edge detection
    reg grinder0_prev;
    reg grinder1_prev;
    reg water_pour_prev;
    reg water_direct_prev;
    reg paper_motor_prev;
    
    //========================================================================
    // Safety Interlock Logic
    //========================================================================
    
    // Heater interlock - can run anytime unless fault
    always @(*) begin
        if (system_fault || emergency_stop) begin
            heater_safe = 1'b0;
        end else begin
            heater_safe = heater_cmd;
        end
    end
    
    // Water pour interlock - requires temp ready, pressure OK, paper present
    always @(*) begin
        if (system_fault || emergency_stop || water_pour_timeout) begin
            water_pour_safe = 1'b0;
        end else if (!temp_ready || !pressure_ready || !paper_filter_present) begin
            water_pour_safe = 1'b0;  // Safety interlock
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            water_pour_safe = 1'b0;  // Wait for interlock delay
        end else begin
            water_pour_safe = water_pour_cmd;
        end
    end
    
    // Water direct interlock - requires pressure OK (temperature less critical)
    always @(*) begin
        if (system_fault || emergency_stop || water_direct_timeout) begin
            water_direct_safe = 1'b0;
        end else if (!pressure_ready) begin
            water_direct_safe = 1'b0;  // Safety interlock
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            water_direct_safe = 1'b0;
        end else begin
            water_direct_safe = water_direct_cmd;
        end
    end
    
    // Grinder 0 interlock - can run unless fault or timeout
    always @(*) begin
        if (system_fault || emergency_stop || grinder0_timeout) begin
            grinder0_safe = 1'b0;
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            grinder0_safe = 1'b0;
        end else begin
            grinder0_safe = grinder0_cmd;
        end
    end
    
    // Grinder 1 interlock - can run unless fault or timeout
    always @(*) begin
        if (system_fault || emergency_stop || grinder1_timeout) begin
            grinder1_safe = 1'b0;
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            grinder1_safe = 1'b0;
        end else begin
            grinder1_safe = grinder1_cmd;
        end
    end
    
    // Paper motor interlock - requires paper present
    always @(*) begin
        if (system_fault || emergency_stop || paper_motor_timeout) begin
            paper_motor_safe = 1'b0;
        end else if (!paper_filter_present && paper_motor_cmd) begin
            paper_motor_safe = 1'b0;  // Don't run if no paper
        end else if (ENABLE_INTERLOCK && interlock_active) begin
            paper_motor_safe = 1'b0;
        end else begin
            paper_motor_safe = paper_motor_cmd;
        end
    end
    
    //========================================================================
    // Timeout Monitoring
    //========================================================================
    
    // Grinder 0 timeout
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grinder0_timer <= 0;
            grinder0_timeout <= 1'b0;
        end else begin
            if (!grinder0_cmd) begin
                // Reset when not commanded
                grinder0_timer <= 0;
                grinder0_timeout <= 1'b0;
            end else if (grinder0_timer >= GRINDER_MAX_TIME) begin
                // Timeout reached
                grinder0_timeout <= 1'b1;
            end else begin
                grinder0_timer <= grinder0_timer + 1;
            end
        end
    end
    
    // Grinder 1 timeout
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
    
    // Water pour timeout
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
    
    // Water direct timeout
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
    
    // Paper motor timeout
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
    
    //========================================================================
    // Interlock Delay Management
    //========================================================================
    
    // Track state changes for interlock delay
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
    
    // Interlock delay timer - prevents rapid switching
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            interlock_timer <= 0;
            interlock_active <= 1'b0;
        end else begin
            // Detect any actuator state change
            if ((grinder0_safe != grinder0_prev) ||
                (grinder1_safe != grinder1_prev) ||
                (water_pour_safe != water_pour_prev) ||
                (water_direct_safe != water_direct_prev) ||
                (paper_motor_safe != paper_motor_prev)) begin
                // Start interlock delay
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
    
    //========================================================================
    // Output Assignment (to LEDs)
    //========================================================================
    
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
    
    //========================================================================
    // Status Monitoring
    //========================================================================
    
    // Count active actuators
    always @(*) begin
        active_count = 0;
        if (led_heater) active_count = active_count + 1;
        if (led_water_pour) active_count = active_count + 1;
        if (led_water_direct) active_count = active_count + 1;
        if (led_grinder0) active_count = active_count + 1;
        if (led_grinder1) active_count = active_count + 1;
        if (led_paper_motor) active_count = active_count + 1;
    end
    
    // Any actuator active flag
    always @(*) begin
        actuators_active = (active_count > 0);
    end
    
    //========================================================================
    // Debug/Monitoring (Optional - removed during synthesis)
    //========================================================================
    
    // Synthesis translate_off
    // always @(posedge clk) begin
    //     // Log actuator activations
    //     if (led_heater && !heater_safe) begin
    //         $display("[%0t] Actuator: HEATER ON", $time);
    //     end else if (!led_heater && heater_safe) begin
    //         $display("[%0t] Actuator: HEATER OFF", $time);
    //     end
        
    //     if (led_water_pour && !water_pour_safe) begin
    //         $display("[%0t] Actuator: WATER POUR ON", $time);
    //     end else if (!led_water_pour && water_pour_safe) begin
    //         $display("[%0t] Actuator: WATER POUR OFF", $time);
    //     end
        
    //     if (led_water_direct && !water_direct_safe) begin
    //         $display("[%0t] Actuator: WATER DIRECT ON", $time);
    //     end else if (!led_water_direct && water_direct_safe) begin
    //         $display("[%0t] Actuator: WATER DIRECT OFF", $time);
    //     end
        
    //     if (led_grinder0 && !grinder0_safe) begin
    //         $display("[%0t] Actuator: GRINDER 0 ON", $time);
    //     end else if (!led_grinder0 && grinder0_safe) begin
    //         $display("[%0t] Actuator: GRINDER 0 OFF", $time);
    //     end
        
    //     if (led_grinder1 && !grinder1_safe) begin
    //         $display("[%0t] Actuator: GRINDER 1 ON", $time);
    //     end else if (!led_grinder1 && grinder1_safe) begin
    //         $display("[%0t] Actuator: GRINDER 1 OFF", $time);
    //     end
        
    //     if (led_paper_motor && !paper_motor_safe) begin
    //         $display("[%0t] Actuator: PAPER MOTOR ON", $time);
    //     end else if (!led_paper_motor && paper_motor_safe) begin
    //         $display("[%0t] Actuator: PAPER MOTOR OFF", $time);
    //     end
        
    //     // Log safety interlock violations
    //     if (water_pour_cmd && !water_pour_safe && !water_pour_timeout) begin
    //         if (!temp_ready) begin
    //             $display("[%0t] SAFETY: Water pour blocked - temp not ready", $time);
    //         end else if (!pressure_ready) begin
    //             $display("[%0t] SAFETY: Water pour blocked - pressure not OK", $time);
    //         end else if (!paper_filter_present) begin
    //             $display("[%0t] SAFETY: Water pour blocked - no paper filter", $time);
    //         end
    //     end
        
    //     // Log timeouts
    //     if (grinder0_timeout) begin
    //         $display("[%0t] TIMEOUT: Grinder 0 exceeded max time", $time);
    //     end
    //     if (grinder1_timeout) begin
    //         $display("[%0t] TIMEOUT: Grinder 1 exceeded max time", $time);
    //     end
    //     if (water_pour_timeout) begin
    //         $display("[%0t] TIMEOUT: Water pour exceeded max time", $time);
    //     end
    //     if (water_direct_timeout) begin
    //         $display("[%0t] TIMEOUT: Water direct exceeded max time", $time);
    //     end
    //     if (paper_motor_timeout) begin
    //         $display("[%0t] TIMEOUT: Paper motor exceeded max time", $time);
    //     end
        
    //     // Log emergency stops
    //     if (emergency_stop) begin
    //         $display("[%0t] EMERGENCY STOP ACTIVE - All actuators disabled", $time);
    //     end
    // end
    // Synthesis translate_on
    
endmodule