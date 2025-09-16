// firebird_tb.v - Testbench for the taillight controller
// Implements predictive state model, activation counters, and duty cycle monitoring

`timescale 1ns / 1ps

module firebird_tb;  // Make sure module name matches file name

    // Clock period for 50MHz
    parameter CLOCK_PERIOD = 20;  // 20ns = 50MHz
    
    // Testbench signals
    reg clk;
    reg [3:0] key;
    reg [2:0] sw;
    wire [7:0] ledg;
    
    // Test mechanism 1: Predictive state model
    // Valid states: 000 -> 001 -> 011 -> 111 -> 000
    reg [2:0] prev_left_state;
    reg [2:0] prev_right_state;
    integer sequence_errors;
    
    // Test mechanism 2: LED activation counter
    integer left_activations;
    integer right_activations;
    
    // Test mechanism 3: Duty cycle counters
    integer left_on_time;
    integer left_off_time;
    integer right_on_time;
    integer right_off_time;
    
    // General test variables
    integer test_cycles;
    reg test_active;
    
    // For simulation speedup
    `ifdef SIMULATION
        // With SIMULATION flag, firebird.v already has fast parameters
        parameter EXPECTED_PERIOD = 10000;  // Matches the SIMULATION counter value
    `else
        // Without flag, override for practical simulation
        defparam uut.timing_gen.COUNTER_MAX = 24'd1000;
        defparam uut.debounce_left.DEBOUNCE_BITS = 4;
        defparam uut.debounce_right.DEBOUNCE_BITS = 4;
        defparam uut.debounce_hazard.DEBOUNCE_BITS = 4;
        parameter EXPECTED_PERIOD = 1000;
    `endif
    
    // Instantiate the Unit Under Test (UUT)
    firebird uut (
        .CLOCK_50(clk),
        .KEY(key),
        .SW(sw),
        .LEDG(ledg)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    
    // Initialize variables
    initial begin
        sequence_errors = 0;
        left_activations = 0;
        right_activations = 0;
        left_on_time = 0;
        left_off_time = 0;
        right_on_time = 0;
        right_off_time = 0;
        test_cycles = 0;
        test_active = 0;
        prev_left_state = 3'b000;
        prev_right_state = 3'b000;
    end
    
    // Test Mechanism 1: Predictive State Model
    // Check that states follow: 000 -> 001 -> 011 -> 111 -> 000
    task check_sequence;
        input [2:0] current;
        input [2:0] previous;
        input string side;
        begin
            // Only check when there's a transition
            if (current != previous) begin
                case (previous)
                    3'b000: begin
                        if (current != 3'b001 && current != 3'b000) begin
                            $display("ERROR: %s invalid transition %b -> %b", side, previous, current);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    3'b001: begin
                        if (current != 3'b011 && current != 3'b000) begin
                            $display("ERROR: %s invalid transition %b -> %b", side, previous, current);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    3'b011: begin
                        if (current != 3'b111 && current != 3'b000) begin
                            $display("ERROR: %s invalid transition %b -> %b", side, previous, current);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    3'b111: begin
                        if (current != 3'b000 && current != 3'b001) begin
                            $display("ERROR: %s invalid transition %b -> %b", side, previous, current);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                endcase
            end
        end
    endtask
    
    // Monitor and count events
    always @(posedge clk) begin
        if (test_active) begin
            test_cycles = test_cycles + 1;
            
            // Check left side state transitions
            if (ledg[7:5] != prev_left_state) begin
                check_sequence(ledg[7:5], prev_left_state, "LEFT");
                
                // Count activations (000 -> 001 transition)
                if (prev_left_state == 3'b000 && ledg[7:5] == 3'b001) begin
                    left_activations = left_activations + 1;
                end
                
                prev_left_state = ledg[7:5];
            end
            
            // Check right side state transitions
            if (ledg[2:0] != prev_right_state) begin
                check_sequence(ledg[2:0], prev_right_state, "RIGHT");
                
                // Count activations (000 -> 001 transition)
                if (prev_right_state == 3'b000 && ledg[2:0] == 3'b001) begin
                    right_activations = right_activations + 1;
                end
                
                prev_right_state = ledg[2:0];
            end
            
            // Count duty cycles (any LED on vs all off)
            if (ledg[7:5] != 3'b000) 
                left_on_time = left_on_time + 1;
            else
                left_off_time = left_off_time + 1;
                
            if (ledg[2:0] != 3'b000)
                right_on_time = right_on_time + 1;
            else
                right_off_time = right_off_time + 1;
        end
    end
    
    // Reset test counters
    task reset_counters;
        begin
            sequence_errors = 0;
            left_activations = 0;
            right_activations = 0;
            left_on_time = 0;
            left_off_time = 0;
            right_on_time = 0;
            right_off_time = 0;
            test_cycles = 0;
            prev_left_state = 3'b000;
            prev_right_state = 3'b000;
        end
    endtask
    
    // Display test results with strict pass/fail criteria
    task display_results;
        input string test_name;
        real left_duty, right_duty;
        integer expected_activations;
        integer pass_count, fail_count;
        begin
            pass_count = 0;
            fail_count = 0;
            
            $display("\n=== %s Results ===", test_name);
            $display("Test duration: %d cycles", test_cycles);
            
            // TEST 1: State sequence validation
            if (sequence_errors == 0) begin
                $display("✓ State sequences: PASS (no errors)");
                pass_count = pass_count + 1;
            end else begin
                $display("✗ State sequences: FAIL (%d errors)", sequence_errors);
                fail_count = fail_count + 1;
            end
            
            // TEST 2: Activation count validation
            // Expected activations = test_cycles / (EXPECTED_PERIOD * 4 states)
            expected_activations = test_cycles / (EXPECTED_PERIOD * 4);
            $display("Activations - Left: %d, Right: %d", left_activations, right_activations);
            
            // Check activation counts based on test type
            if (test_name == "Left Turn") begin
                if (left_activations >= expected_activations-1 && 
                    left_activations <= expected_activations+1 && 
                    right_activations == 0) begin
                    $display("✓ Activation count: PASS (within tolerance)");
                    pass_count = pass_count + 1;
                end else begin
                    $display("✗ Activation count: FAIL (expected ~%d left, 0 right)", expected_activations);
                    fail_count = fail_count + 1;
                end
            end else if (test_name == "Right Turn") begin
                if (right_activations >= expected_activations-1 && 
                    right_activations <= expected_activations+1 && 
                    left_activations == 0) begin
                    $display("✓ Activation count: PASS (within tolerance)");
                    pass_count = pass_count + 1;
                end else begin
                    $display("✗ Activation count: FAIL (expected 0 left, ~%d right)", expected_activations);
                    fail_count = fail_count + 1;
                end
            end else if (test_name == "Hazard" || test_name == "Both Signals") begin
                if (left_activations == right_activations && 
                    left_activations >= expected_activations-1) begin
                    $display("✓ Activation count: PASS (synchronized)");
                    pass_count = pass_count + 1;
                end else begin
                    $display("✗ Activation count: FAIL (not synchronized or too few)");
                    fail_count = fail_count + 1;
                end
            end
            
            // TEST 3: Duty cycle validation (should be ~75% when active)
            // Expected ratio: 3 on states to 1 off state = 75% duty cycle
            if (left_on_time + left_off_time > 0) begin
                left_duty = 100.0 * left_on_time / (left_on_time + left_off_time);
                $display("Left duty cycle: %.1f%% (on: %d, off: %d)", 
                        left_duty, left_on_time, left_off_time);
                
                // Check if duty cycle is within expected range (60-80% when active)
                // Note: includes startup time, so range is wider
                if (test_name == "Left Turn" || test_name == "Hazard" || test_name == "Both Signals") begin
                    if (left_duty >= 55.0 && left_duty <= 80.0) begin
                        $display("✓ Left duty cycle: PASS (within acceptable range)");
                        pass_count = pass_count + 1;
                    end else begin
                        $display("✗ Left duty cycle: FAIL (expected 55-80%%)");
                        fail_count = fail_count + 1;
                    end
                end
            end
            
            if (right_on_time + right_off_time > 0) begin
                right_duty = 100.0 * right_on_time / (right_on_time + right_off_time);
                $display("Right duty cycle: %.1f%% (on: %d, off: %d)", 
                        right_duty, right_on_time, right_off_time);
                
                // Check if duty cycle is within expected range
                if (test_name == "Right Turn" || test_name == "Hazard" || test_name == "Both Signals") begin
                    if (right_duty >= 55.0 && right_duty <= 80.0) begin
                        $display("✓ Right duty cycle: PASS (within acceptable range)");
                        pass_count = pass_count + 1;
                    end else begin
                        $display("✗ Right duty cycle: FAIL (expected 55-80%%)");
                        fail_count = fail_count + 1;
                    end
                end
            end
            
            // Overall test result
            $display("\nTest Summary: %d PASS, %d FAIL", pass_count, fail_count);
            if (fail_count == 0) begin
                $display("★ %s Test: PASSED ALL CHECKS ★", test_name);
            end else begin
                $display("✗ %s Test: FAILED", test_name);
            end
            $display("========================\n");
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize
        key = 4'b1111;  // Keys not pressed
        sw = 3'b000;    // Switches off
        
        // Create waveform file
        $dumpfile("firebird_tb.vcd");
        $dumpvars(0, firebird_tb);
        
        $display("\n=====================================");
        $display("  TAILLIGHT CONTROLLER TEST BENCH");
        $display("=====================================\n");
        
        // Wait for initial settling
        #(CLOCK_PERIOD * 100);
        
        // Test 1: System Reset
        $display("Test 1: System Reset");
        key[3] = 1'b0;  // Assert reset
        #(CLOCK_PERIOD * 50);
        key[3] = 1'b1;  // Release reset
        #(CLOCK_PERIOD * 50);
        
        if (ledg == 8'b00000000) begin
            $display("✓ Reset test PASS - All LEDs cleared\n");
        end else begin
            $display("✗ Reset test FAIL - LEDs not cleared: %b\n", ledg);
        end
        
        // Test 2: Left Turn Signal
        $display("Test 2: Left Turn Signal");
        $display("Starting test at time %0t", $time);
        $display("Counter MAX = %d", uut.timing_gen.COUNTER_MAX);
        reset_counters();
        sw[2] = 1'b1;  // Enable left turn
        
        // Wait for debouncer to settle (with 4-bit debouncer, needs 16 clocks)
        #(CLOCK_PERIOD * 20);
        
        test_active = 1;
        
        // Add progress indicator
        $display("Running Left Turn test for %d clock cycles...", EXPECTED_PERIOD * 8);
        $display("Expecting ~%d enable pulses", 8);
        
        // Monitor first few enable pulses
        fork
            begin
                repeat(5) begin
                    @(posedge uut.timing_gen.enable);
                    $display("  Enable pulse at time %0t, LEDs: L=%b R=%b", 
                            $time, ledg[7:5], ledg[2:0]);
                end
            end
            begin
                // Run for multiple complete sequences
                #(CLOCK_PERIOD * EXPECTED_PERIOD * 8);
            end
        join_any
        disable fork;
        
        sw[2] = 1'b0;  // Disable
        test_active = 0;
        #(CLOCK_PERIOD * 100);
        display_results("Left Turn");
        
        // Ensure clean state between tests
        #(CLOCK_PERIOD * 2000);  // Wait for any pending transitions
        
        // Test 3: Right Turn Signal
        $display("Test 3: Right Turn Signal");
        reset_counters();
        test_active = 1;
        sw[1] = 1'b1;  // Enable right turn
        
        #(CLOCK_PERIOD * EXPECTED_PERIOD * 8);
        
        sw[1] = 1'b0;  // Disable
        test_active = 0;
        #(CLOCK_PERIOD * 100);
        display_results("Right Turn");
        
        // Ensure clean state between tests
        #(CLOCK_PERIOD * 2000);
        
        // Test 4: Hazard Mode
        $display("Test 4: Hazard Mode");
        reset_counters();
        test_active = 1;
        sw[0] = 1'b1;  // Enable hazard
        
        #(CLOCK_PERIOD * EXPECTED_PERIOD * 8);
        
        sw[0] = 1'b0;  // Disable
        test_active = 0;
        #(CLOCK_PERIOD * 100);
        display_results("Hazard");
        
        // Check synchronization
        if (left_activations == right_activations && left_activations > 0) begin
            $display("✓ Hazard synchronization PASS\n");
        end else begin
            $display("✗ Hazard synchronization FAIL (L:%d R:%d)\n", 
                    left_activations, right_activations);
        end
        
        // Test 5: Both Signals (Independent)
        $display("Test 5: Both Turn Signals");
        reset_counters();
        test_active = 1;
        sw[2] = 1'b1;  // Left
        sw[1] = 1'b1;  // Right
        
        #(CLOCK_PERIOD * EXPECTED_PERIOD * 8);
        
        sw[2] = 1'b0;
        sw[1] = 1'b0;
        test_active = 0;
        #(CLOCK_PERIOD * 100);
        display_results("Both Signals");
        
        // Final Summary
        $display("\n=====================================");
        $display("        TEST SUITE COMPLETE");
        $display("=====================================");
        $display("Simulation time: %0t ns\n", $time);
        
        #(CLOCK_PERIOD * 100);
        $finish;
    end
    
    // Safety timeout - adjusted for faster simulation
    initial begin
        #(CLOCK_PERIOD * 10000000);  // 10M clock cycles timeout (200ms simulated)
        $display("ERROR: Simulation timeout - check for infinite loops");
        $finish;
    end

endmodule