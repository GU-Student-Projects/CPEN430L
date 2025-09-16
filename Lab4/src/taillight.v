// taillight.v - Sequential taillight pattern controller
// Manages the 3-segment sweep pattern for turn signals and hazards

module taillight (
    input wire clk,           // System clock
    input wire rst_n,         // Active-low reset
    input wire enable,        // Enable signal from counter (pulse for state change)
    input wire left_req,      // Left turn request
    input wire right_req,     // Right turn request
    input wire hazard_req,    // Hazard request
    output reg [2:0] left_leds,  // Left segment LEDs [7:5]
    output reg [2:0] right_leds  // Right segment LEDs [2:0]
);

    // State encoding for the sequential pattern
    localparam S_OFF = 3'b000;
    localparam S_1   = 3'b001;
    localparam S_2   = 3'b011;
    localparam S_3   = 3'b111;
    
    // State registers
    reg [1:0] left_state, left_state_next;
    reg [1:0] right_state, right_state_next;
    
    // State machine for left side
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_state <= 2'b00;
        end else if (enable) begin
            left_state <= left_state_next;
        end
    end
    
    // State machine for right side
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            right_state <= 2'b00;
        end else if (enable) begin
            right_state <= right_state_next;
        end
    end
    
    // Next state logic for left side
    always @(*) begin
        left_state_next = left_state;
        
        if (hazard_req || left_req) begin
            case (left_state)
                2'b00: left_state_next = 2'b01;
                2'b01: left_state_next = 2'b10;
                2'b10: left_state_next = 2'b11;
                2'b11: left_state_next = 2'b00;
                default: left_state_next = 2'b00;
            endcase
        end else begin
            left_state_next = 2'b00;
        end
    end
    
    // Next state logic for right side
    always @(*) begin
        right_state_next = right_state;
        
        if (hazard_req || right_req) begin
            case (right_state)
                2'b00: right_state_next = 2'b01;
                2'b01: right_state_next = 2'b10;
                2'b10: right_state_next = 2'b11;
                2'b11: right_state_next = 2'b00;
                default: right_state_next = 2'b00;
            endcase
        end else begin
            right_state_next = 2'b00;
        end
    end
    
    // Output logic for left LEDs (inner to outer pattern)
    always @(*) begin
        if (hazard_req || left_req) begin
            case (left_state)
                2'b00: left_leds = S_OFF;  // 000
                2'b01: left_leds = S_1;    // 001 (innermost)
                2'b10: left_leds = S_2;    // 011
                2'b11: left_leds = S_3;    // 111 (all on)
                default: left_leds = S_OFF;
            endcase
        end else begin
            left_leds = S_OFF;
        end
    end
    
    // Output logic for right LEDs (inner to outer pattern)
    always @(*) begin
        if (hazard_req || right_req) begin
            case (right_state)
                2'b00: right_leds = S_OFF;  // 000
                2'b01: right_leds = S_1;    // 001 (innermost)
                2'b10: right_leds = S_2;    // 011
                2'b11: right_leds = S_3;    // 111 (all on)
                default: right_leds = S_OFF;
            endcase
        end else begin
            right_leds = S_OFF;
        end
    end

endmodule