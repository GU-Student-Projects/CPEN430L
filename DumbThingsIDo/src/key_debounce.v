// Key Debounce Module
module key_debounce(
    input wire clk,
    input wire reset_n,
    input wire key_in,
    output reg key_out
);
    
    reg [19:0] counter;
    reg key_sync_0, key_sync_1;
    reg key_prev;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter <= 20'd0;
            key_sync_0 <= 1'b0;
            key_sync_1 <= 1'b0;
            key_prev <= 1'b0;
            key_out <= 1'b0;
        end else begin
            key_sync_0 <= key_in;
            key_sync_1 <= key_sync_0;
            
            if (key_sync_1 != key_prev) begin
                counter <= 20'd0;
                key_prev <= key_sync_1;
            end else if (counter < 20'd1000000) begin
                counter <= counter + 1;
            end else begin
                key_out <= key_sync_1 & ~key_prev;
            end
        end
    end
    
endmodule