// VGA Timing Generator for 720p@60Hz
module vga_timing_720p(
    input wire pixel_clk,
    input wire reset_n,
    output reg [10:0] h_counter,
    output reg [9:0] v_counter,
    output reg h_sync,
    output reg v_sync,
    output wire display_enable
);
    
    // 720p@60Hz timing parameters
    parameter H_VISIBLE = 1280;
    parameter H_FRONT = 110;
    parameter H_SYNC = 40;
    parameter H_BACK = 220;
    parameter H_TOTAL = 1650;
    
    parameter V_VISIBLE = 720;
    parameter V_FRONT = 5;
    parameter V_SYNC = 5;
    parameter V_BACK = 20;
    parameter V_TOTAL = 750;
    
    always @(posedge pixel_clk or negedge reset_n) begin
        if (!reset_n) begin
            h_counter <= 11'd0;
            v_counter <= 10'd0;
        end else begin
            if (h_counter < H_TOTAL - 1) begin
                h_counter <= h_counter + 1;
            end else begin
                h_counter <= 11'd0;
                if (v_counter < V_TOTAL - 1) begin
                    v_counter <= v_counter + 1;
                end else begin
                    v_counter <= 10'd0;
                end
            end
        end
    end
    
    always @(posedge pixel_clk) begin
        h_sync <= (h_counter >= H_VISIBLE + H_FRONT) && 
                  (h_counter < H_VISIBLE + H_FRONT + H_SYNC);
        v_sync <= (v_counter >= V_VISIBLE + V_FRONT) && 
                  (v_counter < V_VISIBLE + V_FRONT + V_SYNC);
    end
    
    assign display_enable = (h_counter < H_VISIBLE) && (v_counter < V_VISIBLE);
    
endmodule