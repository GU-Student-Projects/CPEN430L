module lightTB ();
begin

reg x;
reg y;

wire f;

reg exp;       // A value for calculating the expected result as  test check
reg error_det; // remember if we fail a test check

light u_light
(
 .x1(x),
 .x2(y),
 .f(f)
);

initial
begin
error_det = 0;
x = 0;  // Blocking statements evalute one at a time realtive to one another.
y = 0;
#100;
x = 1;
#100;
y = 1;
#100;
x = 0;
#100;
y = 0;
#100;
if (error_det) $display("Test FAILS");
else $display("Test PASSES");
end

// This is a automated checking system.  Each time x or y changes value,
// wait 5 ns and then check result. 

always @ (x or y)
begin
   #5;
   exp = x ^ y;
   if (f === exp) // === is like == but will not match X's
      $display("Result %x matches expected value %x.", f, exp);
   else
   begin
      $display("ERROR: Result %x does not matche expected value %x.",f,exp);
      error_det = 1'b1;
   end
end

end
endmodule