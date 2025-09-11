module hex7seg (
    input  wire [3:0] digit,    // 4-bit input for digit/letter encoding
    output reg  [6:0] segments   // 7-segment output
);

    // Encoding for digits 0-9 and letters G, T, L, E, Q
    always @(*) begin
        case (digit)
            4'h0: segments = 7'b1000000; // 0
            4'h1: segments = 7'b1111001; // 1
            4'h2: segments = 7'b0100100; // 2
            4'h3: segments = 7'b0110000; // 3
            4'h4: segments = 7'b0011001; // 4
            4'h5: segments = 7'b0010010; // 5
            4'h6: segments = 7'b0000010; // 6
            4'h7: segments = 7'b1111000; // 7
            4'h8: segments = 7'b0000000; // 8
            4'h9: segments = 7'b0010000; // 9
            4'hA: segments = 7'b0000010; // G (looks like 6)
            4'hB: segments = 7'b0000111; // t (lowercase t)
            4'hC: segments = 7'b1000111; // L
            4'hD: segments = 7'b0000110; // E
            4'hE: segments = 7'b0011000; // q (closest to Q)
            4'hF: segments = 7'b1111111; // blank (all segments off)
            default: segments = 7'b1111111; // All segments off
        endcase
    end

endmodule