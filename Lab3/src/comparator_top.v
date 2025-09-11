module comparator_top (
    input  wire CLOCK_50,
    input  wire [3:0] SW,        // Switches: SW[3:2] = A, SW[1:0] = B
    output wire [2:0] LED,       // LEDs: LED[2]=AGTB, LED[1]=AEQB, LED[0]=ALTB
    output wire [6:0] HEX0,      // Seven segment display 0 (rightmost)
    output wire [6:0] HEX1,      // Seven segment display 1 
    output wire [6:0] HEX2,      // Seven segment display 2 
    output wire [6:0] HEX3       // Seven segment display 3 (leftmost)
);
    // Internal signals
    wire [3:0] SW_sync;          // Synchronized switch signals
    wire [1:0] A, B;
    wire AGTB, AEQB, ALTB;
    reg [3:0] digit3, digit2, digit1, digit0;
    
    // Instantiate synchronizers for each switch input
    sync sync_sw0 (
        .swIn(SW[0]),
        .clk(CLOCK_50),
        .syncsignal(SW_sync[0])
    );
    
    sync sync_sw1 (
        .swIn(SW[1]),
        .clk(CLOCK_50),
        .syncsignal(SW_sync[1])
    );
    
    sync sync_sw2 (
        .swIn(SW[2]),
        .clk(CLOCK_50),
        .syncsignal(SW_sync[2])
    );
    
    sync sync_sw3 (
        .swIn(SW[3]),
        .clk(CLOCK_50),
        .syncsignal(SW_sync[3])
    );
    
    // Assign synchronized inputs
    assign A = SW_sync[3:2];
    assign B = SW_sync[1:0];
    
    // Instantiate magnitude comparator
    comparator comp_inst (
        .A(A),
        .B(B),
        .AGTB(AGTB),
        .AEQB(AEQB),
        .ALTB(ALTB)
    );
    
    // Assign outputs to LEDs
    assign LED[2] = AGTB;
    assign LED[1] = AEQB;
    assign LED[0] = ALTB;
    
    // Display control logic using procedural combinational style
    always @(*) begin
        if (AGTB) begin
            // Display format: "AGtB" where A and B are the actual values
            digit3 = {2'b00, A};      // A value (0-3)
            digit2 = 4'hA;            // 'G'
            digit1 = 4'hB;            // 't'
            digit0 = {2'b00, B};      // B value (0-3)
        end
        else if (AEQB) begin
            // Display format: "AEqB" where A and B are the actual values
            digit3 = {2'b00, A};      // A value (0-3)
            digit2 = 4'hD;            // 'E'
            digit1 = 4'hE;            // 'q'
            digit0 = {2'b00, B};      // B value (0-3)
        end
        else if (ALTB) begin
            // Display format: "ALtB" where A and B are the actual values
            digit3 = {2'b00, A};      // A value (0-3)
            digit2 = 4'hC;            // 'L'
            digit1 = 4'hB;            // 't'
            digit0 = {2'b00, B};      // B value (0-3)
        end
        else begin
            // Error state - should never happen
            digit3 = 4'hF;            // blank
            digit2 = 4'hF;            // blank
            digit1 = 4'hF;            // blank
            digit0 = 4'hF;            // blank
        end
    end
    
    // Instantiate seven segment decoders for each display
    hex7seg hex3_inst (
        .digit(digit3),
        .segments(HEX3)
    );
    
    hex7seg hex2_inst (
        .digit(digit2),
        .segments(HEX2)
    );
    
    hex7seg hex1_inst (
        .digit(digit1),
        .segments(HEX1)
    );
    
    hex7seg hex0_inst (
        .digit(digit0),
        .segments(HEX0)
    );
endmodule