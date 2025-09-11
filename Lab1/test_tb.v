module test_tb();


reg clk = 0;
reg reset;
wire dout;

// This is SIMULATION code. DON'T DO THIS IN RTL
// Generate a clock that toggles every 5 ns probably
always #5 clk = ~clk;

initial
begin
    $display("%0t, Starting SIM", $time);
    reset = 1;
    #100;
    reset = 0;
    #1000;
    $display("%0t, Ending SIM", $time);
    $finish();
end


test u_test
(
.clk(clk),
.reset(reset),
.D(dout)
);


endmodule 