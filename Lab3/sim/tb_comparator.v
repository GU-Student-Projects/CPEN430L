`timescale 1ns / 1ps

module tb_comparator;

    // Clock signal for synchronized version
    reg CLOCK_50;
    
    // Testbench signals
    reg  [1:0] A, B;
    wire AGTB, AEQB, ALTB;
    
    // Clock generation (50 MHz)
    initial begin
        CLOCK_50 = 0;
        forever #10 CLOCK_50 = ~CLOCK_50;  // 50 MHz clock
    end
    
    // Instantiate UUT (basic comparator)
    comparator uut (
        .A(A),
        .B(B),
        .AGTB(AGTB),
        .AEQB(AEQB),
        .ALTB(ALTB)
    );
    
    integer i, j;

    initial begin
        // Create VCD file for waveform viewing
        $dumpfile("comparator_waveform.vcd");
        $dumpvars(0, tb_comparator);
        
        // Display header
        $display("Time\tA\tB\tAGTB\tAEQB\tALTB");
        $display("-------------------------------");
        
        // Loop through all 16 combinations using nonblocking assignments
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                A <= i[1:0];
                B <= j[1:0];
                
                // Wait one clock to see the change propagate
                @(posedge CLOCK_50);
                
                $display("%0t\t%0b\t%0b\t%b\t%b\t%b", 
                         $time, A, B, AGTB, AEQB, ALTB);
            end
        end
        
        $display("All combinations tested.");
        $finish;
    end

endmodule
