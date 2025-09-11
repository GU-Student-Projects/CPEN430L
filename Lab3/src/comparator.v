module comparator (
    input  wire [1:0] A,        // 2-bit input A
    input  wire [1:0] B,        // 2-bit input B
    output reg  AGTB,           // A greater than B
    output reg  AEQB,           // A equal to B
    output reg  ALTB            // A less than B
);

    // Procedural combinational logic block
    always @(*) begin
        // Default outputs
        AGTB = 1'b0;
        AEQB = 1'b0;
        ALTB = 1'b0;
        
        // Compare A and B
        if (A > B) begin
            AGTB = 1'b1;
        end
        else if (A == B) begin
            AEQB = 1'b1;
        end
        else begin
            ALTB = 1'b1;
        end
    end

endmodule