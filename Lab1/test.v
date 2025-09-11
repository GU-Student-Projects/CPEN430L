module test (
	input clk,
	input reset,
	output reg D
);

	always @ (posedge clk)
	begin
	if (reset)
		D <= 1'b0;
	else
		D <= !D;
	end
	
endmodule 