// firebird.v - Top-level structural interconnect
// Connects taillight controller, counter, and debouncers

module firebird (
    input wire CLOCK_50,      // 50 MHz board clock
    input wire [3:0] KEY,     // Push buttons (KEY[3] is reset, KEY[2] = brake)
    input wire [2:0] SW,      // Switches for control
    output wire [7:0] LEDG    // Green LEDs for display
);

    // Internal signals
    wire rst_n;
    wire enable_pulse;
    wire left_req_debounced;
    wire right_req_debounced;
    wire hazard_req_debounced;
	 wire brake_req;
    wire [2:0] left_leds_internal;
    wire [2:0] right_leds_internal;
    
    // Reset is KEY[3] (active-low)
    assign rst_n = KEY[3];

    // Brake is KEY[2] (active-low)
    assign brake_req = KEY[2];

    // Debounce the switch inputs
    debouncer #(.DEBOUNCE_BITS(16)) debounce_left (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .sw_in(SW[2]),
        .sw_out(left_req_debounced)
    );
    
    debouncer #(.DEBOUNCE_BITS(16)) debounce_right (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .sw_in(SW[1]),
        .sw_out(right_req_debounced)
    );
    
    debouncer #(.DEBOUNCE_BITS(16)) debounce_hazard (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .sw_in(SW[0]),
        .sw_out(hazard_req_debounced)
    );
    
    // Instantiate the counter for timing
    counter timing_gen (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .enable(enable_pulse)
    );
    
    // Instantiate the taillight controller
    taillight controller (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .enable(enable_pulse),
        .left_req(left_req_debounced),
        .right_req(right_req_debounced),
        .hazard_req(hazard_req_debounced),
        .brake_req(brake_req),                    // NEW: brake signal
        .left_leds(left_leds_internal),
        .right_leds(right_leds_internal)
    );
    
    // Map internal signals to output LEDs
    // LEDG[7:5] = Left segments (inner to outer)
    // LEDG[2:0] = Right segments (outer to inner)
    assign LEDG[7:5] = left_leds_internal;
    assign LEDG[4:3] = 2'b00;  // Middle LEDs off (spacing)
    assign LEDG[2:0] = right_leds_internal;

endmodule
