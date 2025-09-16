// debouncer.v - Debounces mechanical switch inputs

module debouncer #(
    parameter DEBOUNCE_BITS = 19  // Default ~10.5ms at 50MHz (2^19 / 50MHz)
                                   // Can be overridden for simulation
)(
    input wire clk,           // System clock
    input wire rst_n,         // Active-low reset
    input wire sw_in,         // Raw switch input
    output reg sw_out         // Debounced output
);

    // Synchronized signal from sync module
    wire sw_sync;
    
    // Debounce counter
    reg [DEBOUNCE_BITS-1:0] counter;
    
    // State for debounced output
    reg sw_state;
    
    // Maximum count value (all 1's)
    localparam COUNTER_MAX = {DEBOUNCE_BITS{1'b1}};
    
    // Instantiate the sync module for metastability handling
    sync synchronizer (
        .swIn(sw_in),
        .clk(clk),
        .syncsignal(sw_sync)
    );
    
    // Debounce logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= {DEBOUNCE_BITS{1'b0}};
            sw_state <= 1'b0;
            sw_out <= 1'b0;
        end else begin
            // If synchronized input differs from current state
            if (sw_sync != sw_state) begin
                // Increment counter
                counter <= counter + 1'b1;
                
                // If counter saturates, update output
                if (counter == COUNTER_MAX) begin
                    sw_state <= sw_sync;
                    sw_out <= sw_sync;
                    counter <= {DEBOUNCE_BITS{1'b0}};
                end
            end else begin
                // Reset counter if input matches state
                counter <= {DEBOUNCE_BITS{1'b0}};
            end
        end
    end

endmodule