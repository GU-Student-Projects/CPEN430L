// sync.v - Two-stage synchronizer for metastability mitigation
// Provides clock domain crossing for asynchronous signals

module sync
(
    input swIn,
    input clk,
    output syncsignal
);
    reg flop1;
    reg flop2;
    
    always@(posedge clk)
    begin
        flop1 <= swIn;
        flop2 <= flop1;
    end
    
    assign syncsignal = flop2;
endmodule