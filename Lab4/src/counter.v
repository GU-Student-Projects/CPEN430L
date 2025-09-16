// counter.v - Provides timing for human-visible display rate
// Generates enable pulses at approximately 175ms intervals from 50MHz clock

module counter #(
    parameter COUNTER_MAX = 24'd8_750_000  // Default for ~175ms at 50MHz
)(
    input wire clk,          // 50 MHz system clock
    input wire rst_n,        // Active-low reset
    output reg enable        // Enable pulse for state transitions
);
    
    reg [23:0] count;
    
    // Counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 24'd0;
            enable <= 1'b0;
        end else begin
            if (count >= COUNTER_MAX - 1) begin
                count <= 24'd0;
                enable <= 1'b1;  // Generate enable pulse
            end else begin
                count <= count + 1'b1;
                enable <= 1'b0;
            end
        end
    end

endmodule