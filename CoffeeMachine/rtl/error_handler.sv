//============================================================================
// Module: error_handler
// Description: Error detection, prioritization, and reporting for coffee machine
//
//============================================================================

`timescale 1ns/1ps

module error_handler (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         bin0_empty, bin0_low, bin1_empty, bin1_low,
    input  wire         creamer_empty, creamer_low, chocolate_empty, chocolate_low,
    input  wire         paper_empty, paper_low,
    input  wire         temp_ready, pressure_ready, water_system_ok,
    input  wire         system_fault_flag, actuator_timeout, recipe_valid, can_make_coffee,
    output reg          critical_error, error_present,
    output reg [3:0]    warning_count, error_count,
    output reg          err_no_water, err_no_paper, err_no_coffee,
    output reg          err_temp_fault, err_pressure_fault, err_system_fault,
    output reg          warn_paper_low, warn_bin0_low, warn_bin1_low,
    output reg          warn_creamer_low, warn_chocolate_low, warn_temp_heating
);

    parameter ERROR_DEBOUNCE_CYCLES = 32'd2_500_000;  // 50ms at 50MHz
    
    reg no_water_detected, no_paper_detected, no_coffee_detected;
    reg temp_fault_detected, pressure_fault_detected, system_fault_detected;
    reg paper_low_detected, bin0_low_detected, bin1_low_detected;
    reg creamer_low_detected, chocolate_low_detected, temp_heating_detected;
    
    reg [31:0] no_water_counter, no_paper_counter, no_coffee_counter;
    reg [31:0] temp_fault_counter, pressure_fault_counter;
    reg no_water_debounced, no_paper_debounced, no_coffee_debounced;
    reg temp_fault_debounced, pressure_fault_debounced;
    
    reg [15:0] error_history;
    reg [3:0]  consecutive_errors;
    reg [3:0]  prev_consecutive_errors;  // FIX: Track previous value
    
    // Error Detection
    always @(*) begin
        no_water_detected = !water_system_ok;
        temp_fault_detected = !temp_ready;
        pressure_fault_detected = !pressure_ready;
        no_paper_detected = paper_empty;
        no_coffee_detected = !can_make_coffee;
        system_fault_detected = system_fault_flag || actuator_timeout;
    end
    
    // Debouncing - No water
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            no_water_counter <= 0;
            no_water_debounced <= 1'b0;
        end else begin
            if (no_water_detected == no_water_debounced) begin
                no_water_counter <= 0;
            end else if (no_water_counter >= ERROR_DEBOUNCE_CYCLES - 1) begin
                no_water_debounced <= no_water_detected;
                no_water_counter <= 0;
            end else begin
                no_water_counter <= no_water_counter + 1;
            end
        end
    end
    
    // Debouncing - No paper
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            no_paper_counter <= 0;
            no_paper_debounced <= 1'b0;
        end else begin
            if (no_paper_detected == no_paper_debounced) begin
                no_paper_counter <= 0;
            end else if (no_paper_counter >= ERROR_DEBOUNCE_CYCLES - 1) begin
                no_paper_debounced <= no_paper_detected;
                no_paper_counter <= 0;
            end else begin
                no_paper_counter <= no_paper_counter + 1;
            end
        end
    end
    
    // Debouncing - No coffee
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            no_coffee_counter <= 0;
            no_coffee_debounced <= 1'b0;
        end else begin
            if (no_coffee_detected == no_coffee_debounced) begin
                no_coffee_counter <= 0;
            end else if (no_coffee_counter >= ERROR_DEBOUNCE_CYCLES - 1) begin
                no_coffee_debounced <= no_coffee_detected;
                no_coffee_counter <= 0;
            end else begin
                no_coffee_counter <= no_coffee_counter + 1;
            end
        end
    end
    
    // Debouncing - Temperature
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_fault_counter <= 0;
            temp_fault_debounced <= 1'b0;
        end else begin
            if (temp_fault_detected == temp_fault_debounced) begin
                temp_fault_counter <= 0;
            end else if (temp_fault_counter >= ERROR_DEBOUNCE_CYCLES - 1) begin
                temp_fault_debounced <= temp_fault_detected;
                temp_fault_counter <= 0;
            end else begin
                temp_fault_counter <= temp_fault_counter + 1;
            end
        end
    end
    
    // Debouncing - Pressure
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pressure_fault_counter <= 0;
            pressure_fault_debounced <= 1'b0;
        end else begin
            if (pressure_fault_detected == pressure_fault_debounced) begin
                pressure_fault_counter <= 0;
            end else if (pressure_fault_counter >= ERROR_DEBOUNCE_CYCLES - 1) begin
                pressure_fault_debounced <= pressure_fault_detected;
                pressure_fault_counter <= 0;
            end else begin
                pressure_fault_counter <= pressure_fault_counter + 1;
            end
        end
    end
    
    // Warning Detection (No Debouncing)
    always @(*) begin
        paper_low_detected = paper_low;
        bin0_low_detected = bin0_low;
        bin1_low_detected = bin1_low;
        creamer_low_detected = creamer_low;
        chocolate_low_detected = chocolate_low;
        temp_heating_detected = !temp_ready && !temp_fault_debounced;
    end
    
    // Error and Warning Flags
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            err_no_water <= 1'b0;
            err_no_paper <= 1'b0;
            err_no_coffee <= 1'b0;
            err_temp_fault <= 1'b0;
            err_pressure_fault <= 1'b0;
            err_system_fault <= 1'b0;
            warn_paper_low <= 1'b0;
            warn_bin0_low <= 1'b0;
            warn_bin1_low <= 1'b0;
            warn_creamer_low <= 1'b0;
            warn_chocolate_low <= 1'b0;
            warn_temp_heating <= 1'b0;
        end else begin
            err_no_water <= no_water_debounced;
            err_no_paper <= no_paper_debounced;
            err_no_coffee <= no_coffee_debounced;
            err_temp_fault <= temp_fault_debounced;
            err_pressure_fault <= pressure_fault_debounced;
            err_system_fault <= system_fault_detected;
            warn_paper_low <= paper_low_detected;
            warn_bin0_low <= bin0_low_detected;
            warn_bin1_low <= bin1_low_detected;
            warn_creamer_low <= creamer_low_detected;
            warn_chocolate_low <= chocolate_low_detected;
            warn_temp_heating <= temp_heating_detected;
        end
    end
    
    // Critical Error
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            critical_error <= 1'b0;
        end else begin
            critical_error <= err_no_water || err_no_paper || err_no_coffee || 
                            err_system_fault || (err_temp_fault && err_pressure_fault);
        end
    end
    
    // General Error Flag
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_present <= 1'b0;
        end else begin
            error_present <= err_no_water || err_no_paper || err_no_coffee || 
                           err_temp_fault || err_pressure_fault || err_system_fault;
        end
    end
    
    // Error Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_count <= 4'd0;
        end else begin
            error_count = 4'd0;
            if (err_no_water) error_count = error_count + 1;
            if (err_no_paper) error_count = error_count + 1;
            if (err_no_coffee) error_count = error_count + 1;
            if (err_temp_fault) error_count = error_count + 1;
            if (err_pressure_fault) error_count = error_count + 1;
            if (err_system_fault) error_count = error_count + 1;
        end
    end
    
    // Warning Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            warning_count <= 4'd0;
        end else begin
            warning_count = 4'd0;
            if (warn_paper_low) warning_count = warning_count + 1;
            if (warn_bin0_low) warning_count = warning_count + 1;
            if (warn_bin1_low) warning_count = warning_count + 1;
            if (warn_creamer_low) warning_count = warning_count + 1;
            if (warn_chocolate_low) warning_count = warning_count + 1;
            if (warn_temp_heating) warning_count = warning_count + 1;
        end
    end
    
    // Error History Tracking - FIX: Track previous value
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_history <= 16'd0;
            consecutive_errors <= 4'd0;
            prev_consecutive_errors <= 4'd0;
        end else begin
            prev_consecutive_errors <= consecutive_errors;
            
            if (error_present) begin
                if (consecutive_errors < 4'd15) begin
                    consecutive_errors <= consecutive_errors + 1;
                end
            end else begin
                consecutive_errors <= 4'd0;
            end
        end
    end
    
    // Debug/Monitoring - FIX: Only print on threshold crossings!
    // synthesis translate_off
    always @(posedge clk) begin
        // Log when crossing specific thresholds only
        if (consecutive_errors == 5 && prev_consecutive_errors == 4) begin
            $display("[%0t] WARNING: 5 consecutive errors detected", $time);
        end
        if (consecutive_errors == 10 && prev_consecutive_errors == 9) begin
            $display("[%0t] WARNING: 10 consecutive errors - System unstable!", $time);
        end
        if (consecutive_errors == 15 && prev_consecutive_errors == 14) begin
            $display("[%0t] CRITICAL: 15 consecutive errors - Maximum!", $time);
        end
    end
    // synthesis translate_on
    
endmodule