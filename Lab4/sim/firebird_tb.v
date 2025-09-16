// firebird_tb.v - Advanced testbench for the taillight controller

`timescale 1ns / 1ps

module firebird_tb;

    // Clock period for 50MHz
    parameter CLOCK_PERIOD = 20;  // 20ns = 50MHz
    
    // Expected state sequence for predictive model
    parameter [3:0] STATE_0 = 4'b0000;  // 000
    parameter [3:0] STATE_1 = 4'b0001;  // 001
    parameter [3:0] STATE_2 = 4'b0011;  // 011
    parameter [3:0] STATE_3 = 4'b0111;  // 111
    
    // Testbench signals
    reg clk;
    reg [3:0] key;
    reg [2:0] sw;
    wire [7:0] ledg;
    
    // Test mechanism variables
    // 1. Predictive state model
    reg [3:0] expected_left_state;
    reg [3:0] expected_right_state;
    reg [3:0] last_left_state;
    reg [3:0] last_right_state;
    integer state_errors;
    
    // 2. LED activation counters
    integer left_activation_count;
    integer right_activation_count;
    reg [2:0] prev_left_leds;
    reg [2:0] prev_right_leds;
    
    // 3. Duty cycle counters
    integer left_on_cycles[2:0];   // Count for each LED
    integer left_off_cycles[2:0];
    integer right_on_cycles[2:0];
    integer right_off_cycles[2:0];
    integer total_cycles;
    
    // 4. Transition counters
    integer left_transitions;
    integer right_transitions;
    
    // Test control
    reg test_enable;
    reg [31:0] test_duration;
    string current_test;
    
    // For simulation speedup, we'll use a modified counter
    `ifdef SIM_SPEEDUP
        defparam uut.timing_gen.COUNTER_MAX = 24'd1000;  // Much faster for simulation
        parameter EXPECTED_CYCLE_TIME = 1000;  // Matches speedup value
    `else
        parameter EXPECTED_CYCLE_TIME = 8750000;  // Normal operation
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
    
    // Initialize test mechanisms
    initial begin
        state_errors = 0;
        left_activation_count = 0;
        right_activation_count = 0;
        left_transitions = 0;
        right_transitions = 0;
        prev_left_leds = 3'b000;
        prev_right_leds = 3'b000;
        test_enable = 0;
        total_cycles = 0;
        
        for (int i = 0; i < 3; i++) begin
            left_on_cycles[i] = 0;
            left_off_cycles[i] = 0;
            right_on_cycles[i] = 0;
            right_off_cycles[i] = 0;
        end
    end
    
    // Predictive state model checker
    function automatic void check_state_sequence(
        input [2:0] current_leds,
        input [2:0] previous_leds,
        input string side
    );
        reg valid_transition;
        
        valid_transition = 0;
        
        // Check for valid state transitions
        case (previous_leds)
            3'b000: valid_transition = (current_leds == 3'b000) || (current_leds == 3'b001);
            3'b001: valid_transition = (current_leds == 3'b011) || (current_leds == 3'b000);
            3'b011: valid_transition = (current_leds == 3'b111) || (current_leds == 3'b000);
            3'b111: valid_transition = (current_leds == 3'b000) || (current_leds == 3'b001);
            default: valid_transition = 0;
        endcase
        
        if (!valid_transition && test_enable) begin
            $display("ERROR at %0t: Invalid state transition on %s side: %b -> %b", 
                     $time, side, previous_leds, current_leds);
            state_errors = state_errors + 1;
        end
    endfunction
    
    // Monitor LED states and count activations
    always @(posedge clk) begin
        if (test_enable) begin
            total_cycles = total_cycles + 1;
            
            // Track left LEDs
            if (ledg[7:5] != prev_left_leds) begin
                check_state_sequence(ledg[7:5], prev_left_leds, "LEFT");
                
                // Count transitions
                if (prev_left_leds == 3'b000 && ledg[7:5] == 3'b001) begin
                    left_activation_count = left_activation_count + 1;
                end
                if (prev_left_leds != ledg[7:5]) begin
                    left_transitions = left_transitions + 1;
                end
                
                prev_left_leds = ledg[7:5];
            end
            
            // Track right LEDs
            if (ledg[2:0] != prev_right_leds) begin
                check_state_sequence(ledg[2:0], prev_right_leds, "RIGHT");
                
                // Count transitions
                if (prev_right_leds == 3'b000 && ledg[2:0] == 3'b001) begin
                    right_activation_count = right_activation_count + 1;
                end
                if (prev_right_leds != ledg[2:0]) begin
                    right_transitions = right_transitions + 1;
                end
                
                prev_right_leds = ledg[2:0];
            end
            
            // Update duty cycle counters
            for (int i = 0; i < 3; i++) begin
                if (ledg[5+i]) // Left LEDs
                    left_on_cycles[i] = left_on_cycles[i] + 1;
                else
                    left_off_cycles[i] = left_off_cycles[i] + 1;
                    
                if (ledg[i]) // Right LEDs
                    right_on_cycles[i] = right_on_cycles[i] + 1;
                else
                    right_off_cycles[i] = right_off_cycles[i] + 1;
            end
        end
    end
    
    // Task to reset counters for new test
    task reset_test_counters;
        begin
            state_errors = 0;
            left_activation_count = 0;
            right_activation_count = 0;
            left_transitions = 0;
            right_transitions = 0;
            total_cycles = 0;
            prev_left_leds = 3'b000;
            prev_right_leds = 3'b000;
            
            for (int i = 0; i < 3; i++) begin
                left_on_cycles[i] = 0;
                left_off_cycles[i] = 0;
                right_on_cycles[i] = 0;
                right_off_cycles[i] = 0;
            end
        end
    endtask
    
    // Task to display test results
    task display_test_results;
        input string test_name;
        real duty_cycle;
        begin
            $display("\n========== %s Results ==========", test_name);
            $display("State Errors: %0d", state_errors);
            $display("Left Activations: %0d, Transitions: %0d", left_activation_count, left_transitions);
            $display("Right Activations: %0d, Transitions: %0d", right_activation_count, right_transitions);
            $display("Total Clock Cycles: %0d", total_cycles);
            
            $display("\nLeft LED Duty Cycles:");
            for (int i = 0; i < 3; i++) begin
                if (left_on_cycles[i] + left_off_cycles[i] > 0) begin
                    duty_cycle = 100.0 * left_on_cycles[i] / (left_on_cycles[i] + left_off_cycles[i]);
                    $display("  LED[%0d]: ON=%0d, OFF=%0d, Duty=%.1f%%", 
                             5+i, left_on_cycles[i], left_off_cycles[i], duty_cycle);
                end
            end
            
            $display("\nRight LED Duty Cycles:");
            for (int i = 0; i < 3; i++) begin
                if (right_on_cycles[i] + right_off_cycles[i] > 0) begin
                    duty_cycle = 100.0 * right_on_cycles[i] / (right_on_cycles[i] + right_off_cycles[i]);
                    $display("  LED[%0d]: ON=%0d, OFF=%0d, Duty=%.1f%%", 
                             i, right_on_cycles[i], right_off_cycles[i], duty_cycle);
                end
            end
            
            // Validate results
            if (state_errors == 0) begin
                $display("\n✓ PASS: No state sequence errors detected");
            end else begin
                $display("\n✗ FAIL: %0d state sequence errors detected", state_errors);
            end
            
            // Check expected activation count (depends on test duration)
            if (test_name == "Left Turn Signal" || test_name == "Right Turn Signal") begin
                integer expected_activations = total_cycles / (EXPECTED_CYCLE_TIME * 4);
                if (test_name == "Left Turn Signal") begin
                    if (left_activation_count >= expected_activations - 1 && 
                        left_activation_count <= expected_activations + 1) begin
                        $display("✓ PASS: Activation count within expected range");
                    end else begin
                        $display("✗ FAIL: Activation count mismatch. Expected ~%0d, got %0d", 
                                expected_activations, left_activation_count);
                    end
                end
            end
            
            $display("=====================================\n");
        end
    endtask
    
    // Test stimulus
    initial begin
        // Initialize inputs
        key = 4'b1111;  // All keys not pressed (active-low)
        sw = 3'b000;    // All switches off
        
        // Create VCD file for waveform viewing
        $dumpfile("firebird_tb.vcd");
        $dumpvars(0, firebird_tb);
        
        // Display header
        $display("\n=================================================");
        $display("       FIREBIRD TAILLIGHT CONTROLLER TEST       ");
        $display("=================================================");
        $display("Time\t\tReset\tSW[2:0]\tLEDG[7:5]\tLEDG[2:0]");
        $display("----\t\t-----\t-------\t---------\t---------");
        $monitor("%0t\t%b\t%b\t%b\t\t%b", 
                 $time, key[3], sw, ledg[7:5], ledg[2:0]);
        
        // Test 1: Reset test
        $display("\n### Test 1: Reset Test ###");
        reset_test_counters();
        #(CLOCK_PERIOD * 10);
        key[3] = 1'b0;  // Assert reset
        #(CLOCK_PERIOD * 10);
        key[3] = 1'b1;  // Release reset
        #(CLOCK_PERIOD * 10);
        
        // Verify reset worked
        if (ledg == 8'b00000000) begin
            $display("✓ Reset test PASSED");
        end else begin
            $display("✗ Reset test FAILED: LEDs not cleared");
        end
        
        // Test 2: Left turn signal
        $display("\n### Test 2: Left Turn Signal ###");
        reset_test_counters();
        test_enable = 1;
        current_test = "Left Turn Signal";
        sw[2] = 1'b1;  // Enable left turn
        #(CLOCK_PERIOD * EXPECTED_CYCLE_TIME * 8);  // Run for 2 complete cycles
        sw[2] = 1'b0;  // Disable left turn
        test_enable = 0;
        #(CLOCK_PERIOD * 1000);
        display_test_results(current_test);
        
        // Test 3: Right turn signal
        $display("\n### Test 3: Right Turn Signal ###");
        reset_test_counters();
        test_enable = 1;
        current_test = "Right Turn Signal";
        sw[1] = 1'b1;  // Enable right turn
        #(CLOCK_PERIOD * EXPECTED_CYCLE_TIME * 8);  // Run for 2 complete cycles
        sw[1] = 1'b0;  // Disable right turn
        test_enable = 0;
        #(CLOCK_PERIOD * 1000);
        display_test_results(current_test);
        
        // Test 4: Hazard lights
        $display("\n### Test 4: Hazard Lights ###");
        reset_test_counters();
        test_enable = 1;
        current_test = "Hazard Lights";
        sw[0] = 1'b1;  // Enable hazard
        #(CLOCK_PERIOD * EXPECTED_CYCLE_TIME * 8);  // Run for 2 complete cycles
        sw[0] = 1'b0;  // Disable hazard
        test_enable = 0;
        #(CLOCK_PERIOD * 1000);
        display_test_results(current_test);
        
        // Verify synchronization in hazard mode
        if (left_activation_count == right_activation_count) begin
            $display("✓ Hazard synchronization PASSED");
        end else begin
            $display("✗ Hazard synchronization FAILED: Left=%0d, Right=%0d", 
                    left_activation_count, right_activation_count);
        end
        
        // Test 5: Both left and right (independent operation)
        $display("\n### Test 5: Both Left and Right (Independent) ###");
        reset_test_counters();
        test_enable = 1;
        current_test = "Both Independent";
        sw[2] = 1'b1;  // Enable left
        sw[1] = 1'b1;  // Enable right
        #(CLOCK_PERIOD * EXPECTED_CYCLE_TIME * 8);
        sw[2] = 1'b0;
        sw[1] = 1'b0;
        test_enable = 0;
        #(CLOCK_PERIOD * 1000);
        display_test_results(current_test);
        
        // Test 6: Hazard overrides individual signals
        $display("\n### Test 6: Hazard Override Test ###");
        reset_test_counters();
        test_enable = 1;
        current_test = "Hazard Override";
        sw[2] = 1'b1;  // Enable left
        #(CLOCK_PERIOD * EXPECTED_CYCLE_TIME * 2);
        sw[0] = 1'b1;  // Enable hazard (should sync both)
        #(CLOCK_PERIOD * EXPECTED_CYCLE_TIME * 4);
        sw[2] = 1'b0;
        sw[0] = 1'b0;
        test_enable = 0;
        #(CLOCK_PERIOD * 1000);
        display_test_results(current_test);
        
        // Test 7: Reset during operation
        $display("\n### Test 7: Reset During Operation ###");
        reset_test_counters();
        test_enable = 1;
        current_test = "Reset During Operation";
        sw[0] = 1'b1;  // Enable hazard
        #(CLOCK_PERIOD * EXPECTED_CYCLE_TIME * 2);
        key[3] = 1'b0;  // Assert reset
        #(CLOCK_PERIOD * 100);
        
        // Check that LEDs are cleared during reset
        if (ledg != 8'b00000000) begin
            $display("✗ Reset during operation FAILED: LEDs not cleared");
            state_errors = state_errors + 1;
        end
        
        key[3] = 1'b1;  // Release reset
        #(CLOCK_PERIOD * EXPECTED_CYCLE_TIME * 2);
        sw[0] = 1'b0;
        test_enable = 0;
        #(CLOCK_PERIOD * 1000);
        display_test_results(current_test);
        
        // Final summary
        $display("\n=================================================");
        $display("              FINAL TEST SUMMARY                 ");
        $display("=================================================");
        $display("All tests completed!");
        $display("Total simulation time: %0t", $time);
        
        // End simulation
        #(CLOCK_PERIOD * 1000);
        $finish;
    end
    
    // Watchdog timer to prevent infinite simulation
    initial begin
        #(CLOCK_PERIOD * EXPECTED_CYCLE_TIME * 100);  // Adjust based on simulation needs
        $display("\nERROR: Simulation timeout!");
        $display("Check if counter period is too long or system is stuck");
        $finish;
    end
    
    // Additional assertion checks
    always @(posedge clk) begin
        // Check for illegal states (should never see these patterns)
        if (test_enable) begin
            if (ledg[7:5] == 3'b010 || ledg[7:5] == 3'b100 || ledg[7:5] == 3'b101 || 
                ledg[7:5] == 3'b110) begin
                $display("ERROR at %0t: Illegal left LED pattern detected: %b", $time, ledg[7:5]);
                state_errors = state_errors + 1;
            end
            
            if (ledg[2:0] == 3'b010 || ledg[2:0] == 3'b100 || ledg[2:0] == 3'b101 || 
                ledg[2:0] == 3'b110) begin
                $display("ERROR at %0t: Illegal right LED pattern detected: %b", $time, ledg[2:0]);
                state_errors = state_errors + 1;
            end
        end
    end

endmodule