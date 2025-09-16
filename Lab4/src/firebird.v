// firebird.v - Top-level structural interconnect
// Connects taillight controller, counter, and debouncers

module firebird (
    input wire CLOCK_50,      // 50 MHz board clock
    input wire [3:0] KEY,     // Push buttons (KEY[3] is reset)
    input wire [2:0] SW,      // Switches for control
    output wire [7:0] LEDG    // Green LEDs for display
);

    // Internal signals
    wire rst_n;
    wire enable_pulse;
    wire left_req_debounced;
    wire right_req_debounced;
    wire hazard_req_debounced;
    wire [2:0] left_leds_internal;
    wire [2:0] right_leds_internal;
    
    // Reset is KEY[3] (active-low)
    assign rst_n = KEY[3];
    
    // Debounce the switch inputs
    // Use smaller debounce counter for simulation
    `ifdef SIMULATION
        localparam DEBOUNCE_COUNT = 10;  // Very fast for simulation
    `else
        localparam DEBOUNCE_COUNT = 19;  // ~10.5ms for real hardware
    `endif
    
    debouncer #(.DEBOUNCE_BITS(DEBOUNCE_COUNT)) debounce_left (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .sw_in(SW[2]),
        .sw_out(left_req_debounced)
    );
    
    debouncer #(.DEBOUNCE_BITS(DEBOUNCE_COUNT)) debounce_right (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .sw_in(SW[1]),
        .sw_out(right_req_debounced)
    );
    
    debouncer #(.DEBOUNCE_BITS(DEBOUNCE_COUNT)) debounce_hazard (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .sw_in(SW[0]),
        .sw_out(hazard_req_debounced)
    );
    
    // Instantiate the counter for timing
    // Use faster counter for simulation
    `ifdef SIMULATION
        localparam COUNTER_VAL = 24'd10_000;  // Fast for simulation (200us)
    `else
        localparam COUNTER_VAL = 24'd8_750_000;  // 175ms for real hardware
    `endif
    
    counter #(
        .COUNTER_MAX(COUNTER_VAL)
    ) timing_gen (
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
        .left_leds(left_leds_internal),
        .right_leds(right_leds_internal)
    );
    
    // Map internal signals to output LEDs
    // LEDG[7:5] = Left segments (inner to outer)
    // LEDG[2:0] = Right segments (inner to outer)
    assign LEDG[7:5] = left_leds_internal;
    assign LEDG[4:3] = 2'b00;  // Middle LEDs off (spacing)
    assign LEDG[2:0] = right_leds_internal;

endmodule