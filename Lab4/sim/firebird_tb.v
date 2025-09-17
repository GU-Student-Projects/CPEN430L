// firebird_tb.v - Testbench for the taillight controller
// Standard Verilog 2001 - no SystemVerilog, no SIMULATION flag

`timescale 1ns / 1ps

module firebird_tb;

    // Clock period for 50MHz
    parameter CLOCK_PERIOD = 20;  // 20ns = 50MHz
    
    // Testbench signals
    reg clk;
    reg [3:0] key;
    reg [2:0] sw;
    wire [7:0] ledg;
    
    // Test mechanism variables
    reg [2:0] prev_left_state;
    reg [2:0] prev_right_state;
    integer sequence_errors;
    integer left_activations;
    integer right_activations;
    integer left_on_time;
    integer left_off_time;
    integer right_on_time;
    integer right_off_time;
    integer test_cycles;
    reg test_active;
    
    // For fast simulation, we'll override the counter
    // The actual hardware uses 8.75M, we'll use 1000 for simulation
    parameter SIM_COUNTER = 1000;
    
    // Instantiate the Unit Under Test (UUT)
    firebird uut (
        .CLOCK_50(clk),
        .KEY(key),
        .SW(sw),
        .LEDG(ledg)
    );
    
    // Override the counter parameter using defparam
    // This works because counter.v uses a parameter, not localparam
    defparam uut.timing_gen.COUNTER_MAX = SIM_COUNTER;
    
    // Clock generation
    always begin
        clk = 0;
        #(CLOCK_PERIOD/2);
        clk = 1;
        #(CLOCK_PERIOD/2);
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
        key = 4'b1111;
        sw = 3'b000;
    end
    
    // Note: LED patterns are:
    // Left:  000 -> 001 -> 011 -> 111 -> 000 (inner to outer)
    // Right: 000 -> 100 -> 110 -> 111 -> 000 (outer to inner)
    // This creates a symmetrical sweep pattern
    
    // Monitor and count events
    always @(posedge clk) begin
        if (test_active) begin
            test_cycles = test_cycles + 1;
            
            // Check left side state transitions
            if (ledg[7:5] != prev_left_state) begin
                // Check for valid transitions
                case (prev_left_state)
                    3'b000: begin
                        if (ledg[7:5] != 3'b001 && ledg[7:5] != 3'b000) begin
                            $display("ERROR: LEFT invalid transition %b -> %b at time %0t", 
                                    prev_left_state, ledg[7:5], $time);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    3'b001: begin
                        if (ledg[7:5] != 3'b011 && ledg[7:5] != 3'b000) begin
                            $display("ERROR: LEFT invalid transition %b -> %b at time %0t", 
                                    prev_left_state, ledg[7:5], $time);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    3'b011: begin
                        if (ledg[7:5] != 3'b111 && ledg[7:5] != 3'b000) begin
                            $display("ERROR: LEFT invalid transition %b -> %b at time %0t", 
                                    prev_left_state, ledg[7:5], $time);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    3'b111: begin
                        if (ledg[7:5] != 3'b000 && ledg[7:5] != 3'b001) begin
                            $display("ERROR: LEFT invalid transition %b -> %b at time %0t", 
                                    prev_left_state, ledg[7:5], $time);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                endcase
                
                // Count activations
                if (prev_left_state == 3'b000 && ledg[7:5] == 3'b001) begin
                    left_activations = left_activations + 1;
                    $display("  Left activation #%d at time %0t", left_activations, $time);
                end
                
                prev_left_state = ledg[7:5];
            end
            
            // Check right side state transitions
            if (ledg[2:0] != prev_right_state) begin
                // Right side goes outer to inner: 000 -> 100 -> 110 -> 111 -> 000
                case (prev_right_state)
                    3'b000: begin
                        if (ledg[2:0] != 3'b100 && ledg[2:0] != 3'b000) begin
                            $display("ERROR: RIGHT invalid transition %b -> %b at time %0t", 
                                    prev_right_state, ledg[2:0], $time);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    3'b100: begin
                        if (ledg[2:0] != 3'b110 && ledg[2:0] != 3'b000) begin
                            $display("ERROR: RIGHT invalid transition %b -> %b at time %0t", 
                                    prev_right_state, ledg[2:0], $time);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    3'b110: begin
                        if (ledg[2:0] != 3'b111 && ledg[2:0] != 3'b000) begin
                            $display("ERROR: RIGHT invalid transition %b -> %b at time %0t", 
                                    prev_right_state, ledg[2:0], $time);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    3'b111: begin
                        if (ledg[2:0] != 3'b000 && ledg[2:0] != 3'b100) begin
                            $display("ERROR: RIGHT invalid transition %b -> %b at time %0t", 
                                    prev_right_state, ledg[2:0], $time);
                            sequence_errors = sequence_errors + 1;
                        end
                    end
                    default: begin
                        $display("ERROR: RIGHT unexpected state %b", prev_right_state);
                        sequence_errors = sequence_errors + 1;
                    end
                endcase
                
                // Count activations (000 -> 100 transition for right)
                if (prev_right_state == 3'b000 && ledg[2:0] == 3'b100) begin
                    right_activations = right_activations + 1;
                    $display("  Right activation #%d at time %0t", right_activations, $time);
                end
                
                prev_right_state = ledg[2:0];
            end
            
            // Count duty cycles
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
    
    // Main test sequence
    initial begin
        // Create waveform file
        $dumpfile("firebird_tb.vcd");
        $dumpvars(0, firebird_tb);
        
        $display("\n=====================================");
        $display("  TAILLIGHT CONTROLLER TEST BENCH");
        $display("  Counter overridden to: %d cycles", SIM_COUNTER);
        $display("=====================================\n");
        
        // Wait for initialization
        #(CLOCK_PERIOD * 100);
        
        // Test 1: System Reset
        $display("Test 1: System Reset");
        key[3] = 1'b0;  // Assert reset
        #(CLOCK_PERIOD * 50);
        key[3] = 1'b1;  // Release reset
        #(CLOCK_PERIOD * 50);
        
        if (ledg == 8'b00000000) begin
            $display("PASS: Reset cleared all LEDs\n");
        end else begin
            $display("FAIL: Reset did not clear LEDs: %b\n", ledg);
        end
        
        // Test 2: Left Turn Signal
        $display("Test 2: Left Turn Signal");
        $display("Starting at time %0t", $time);
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
        
        sw[2] = 1'b1;  // Enable left turn
        
        // Wait for debouncer (16-bit = 65536 cycles)
        $display("Waiting for debouncer to settle...");
        #(CLOCK_PERIOD * 70000);
        
        $display("Starting measurement");
        test_active = 1;
        
        // Run for 8 state changes (2 complete cycles)
        // Each state takes SIM_COUNTER cycles
        #(CLOCK_PERIOD * SIM_COUNTER * 8);
        
        test_active = 0;
        sw[2] = 1'b0;
        #(CLOCK_PERIOD * 100);
        
        // Display results
        $display("Test 2 Results:");
        $display("  Test duration: %d cycles", test_cycles);
        $display("  Sequence errors: %d", sequence_errors);
        $display("  Left activations: %d (expected: 2)", left_activations);
        $display("  Right activations: %d (expected: 0)", right_activations);
        if (left_on_time + left_off_time > 0) begin
            $display("  Left duty cycle: %d%% (expected: ~75%%)", 
                    (100 * left_on_time) / (left_on_time + left_off_time));
        end
        
        if (sequence_errors == 0 && left_activations >= 1 && right_activations == 0) begin
            $display("PASS: Left turn signal test\n");
        end else begin
            $display("FAIL: Left turn signal test\n");
        end
        
        // Wait between tests
        #(CLOCK_PERIOD * 2000);
        
        // Test 3: Right Turn Signal
        $display("Test 3: Right Turn Signal");
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
        
        sw[1] = 1'b1;  // Enable right turn
        #(CLOCK_PERIOD * 70000);  // Debouncer settle
        
        test_active = 1;
        #(CLOCK_PERIOD * SIM_COUNTER * 8);
        test_active = 0;
        
        sw[1] = 1'b0;
        #(CLOCK_PERIOD * 100);
        
        $display("Test 3 Results:");
        $display("  Sequence errors: %d", sequence_errors);
        $display("  Left activations: %d (expected: 0)", left_activations);
        $display("  Right activations: %d (expected: 2)", right_activations);
        if (right_on_time + right_off_time > 0) begin
            $display("  Right duty cycle: %d%%", 
                    (100 * right_on_time) / (right_on_time + right_off_time));
        end
        
        if (sequence_errors == 0 && right_activations >= 1 && left_activations == 0) begin
            $display("PASS: Right turn signal test\n");
        end else begin
            $display("FAIL: Right turn signal test\n");
        end
        
        #(CLOCK_PERIOD * 2000);
        
        // Test 4: Hazard Mode
        $display("Test 4: Hazard Mode");
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
        
        sw[0] = 1'b1;  // Enable hazard
        #(CLOCK_PERIOD * 70000);
        
        test_active = 1;
        #(CLOCK_PERIOD * SIM_COUNTER * 8);
        test_active = 0;
        
        sw[0] = 1'b0;
        #(CLOCK_PERIOD * 100);
        
        $display("Test 4 Results:");
        $display("  Sequence errors: %d", sequence_errors);
        $display("  Left activations: %d", left_activations);
        $display("  Right activations: %d", right_activations);
        
        if (sequence_errors == 0 && left_activations == right_activations && 
            left_activations >= 1) begin
            $display("PASS: Hazard mode synchronized correctly\n");
        end else begin
            $display("FAIL: Hazard mode test\n");
        end
        
        #(CLOCK_PERIOD * 2000);
        
        // Test 5: Both Turn Signals
        $display("Test 5: Both Turn Signals (Independent)");
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
        
        sw[2] = 1'b1;  // Enable left
        sw[1] = 1'b1;  // Enable right
        #(CLOCK_PERIOD * 70000);
        
        test_active = 1;
        #(CLOCK_PERIOD * SIM_COUNTER * 8);
        test_active = 0;
        
        sw[2] = 1'b0;
        sw[1] = 1'b0;
        #(CLOCK_PERIOD * 100);
        
        $display("Test 5 Results:");
        $display("  Sequence errors: %d", sequence_errors);
        $display("  Left activations: %d", left_activations);
        $display("  Right activations: %d", right_activations);
        
        if (sequence_errors == 0 && left_activations >= 1 && right_activations >= 1) begin
            $display("PASS: Both signals test\n");
        end else begin
            $display("FAIL: Both signals test\n");
        end
        
        // Final Summary
        $display("\n=====================================");
        $display("     TEST SUITE COMPLETE");
        $display("  Total simulation time: %0t ns", $time);
        $display("=====================================\n");
        
        #(CLOCK_PERIOD * 100);
        $finish;
    end
    
    // Timeout protection
    initial begin
        #(10000000);  // 10ms timeout
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule