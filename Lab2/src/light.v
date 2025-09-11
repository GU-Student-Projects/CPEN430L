module light
(
input x1,
input x2,
input clk,
output f
);
	wire w1;
	wire w2;
   assign f = (w1 && !w2)  || (!w1 && w2);
	sync u_sync1(.clk(clk), .swIn(x1), .syncsignal (w1));
	sync u_sync2(.clk(clk), .swIn(x2), .syncsignal (w2));
endmodule




