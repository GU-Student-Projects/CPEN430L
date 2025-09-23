// Display Controller
module display_controller(
    input wire pixel_clk,
    input wire [10:0] h_counter,
    input wire [9:0] v_counter,
    input wire display_enable,
    input wire [3:0] current_state,
    input wire [1:0] menu_cursor,
    input wire [1:0] coffee_selection,
    input wire [1:0] strength_selection,
    input wire [1:0] size_selection,
    input wire [23:0] pour_progress,
    input wire [23:0] pour_total,
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue
);
    
    // Color definitions
    localparam COLOR_BG = 24'h2C3E50;      // Dark blue-gray
    localparam COLOR_BUTTON = 24'h3498DB;   // Blue
    localparam COLOR_SELECTED = 24'hE74C3C; // Red
    localparam COLOR_TEXT = 24'hECF0F1;     // Light gray
    localparam COLOR_COFFEE = 24'h8B4513;   // Brown
    
    // Screen regions
    wire in_button_area;
    wire in_back_button;
    reg [23:0] pixel_color;
    
    // Simple button detection (you would expand this with proper text rendering)
    always @(*) begin
        pixel_color = COLOR_BG;
        
        if (display_enable) begin
            case (current_state)
                4'd0: begin // Welcome screen
                    if (v_counter > 350 && v_counter < 400 && 
                        h_counter > 540 && h_counter < 740) begin
                        pixel_color = COLOR_BUTTON;
                    end
                end
                
                4'd1: begin // Coffee selection
                    // Coffee 1 button
                    if (v_counter > 300 && v_counter < 350) begin
                        if (h_counter > 400 && h_counter < 550) begin
                            pixel_color = (menu_cursor == 0) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                        // Coffee 2 button
                        else if (h_counter > 730 && h_counter < 880) begin
                            pixel_color = (menu_cursor == 1) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                    end
                    // Back button
                    if (v_counter > 650 && v_counter < 690 && 
                        h_counter > 50 && h_counter < 150) begin
                        pixel_color = COLOR_BUTTON;
                    end
                end
                
                4'd2: begin // Strength selection
                    if (v_counter > 300 && v_counter < 350) begin
                        // Mild
                        if (h_counter > 300 && h_counter < 450) begin
                            pixel_color = (menu_cursor == 0) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                        // Medium
                        else if (h_counter > 565 && h_counter < 715) begin
                            pixel_color = (menu_cursor == 1) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                        // Strong
                        else if (h_counter > 830 && h_counter < 980) begin
                            pixel_color = (menu_cursor == 2) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                    end
                    // Back button
                    if (v_counter > 650 && v_counter < 690 && 
                        h_counter > 50 && h_counter < 150) begin
                        pixel_color = COLOR_BUTTON;
                    end
                end
                
                4'd3: begin // Size selection
                    if (v_counter > 300 && v_counter < 350) begin
                        // 10oz
                        if (h_counter > 300 && h_counter < 450) begin
                            pixel_color = (menu_cursor == 0) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                        // 16oz
                        else if (h_counter > 565 && h_counter < 715) begin
                            pixel_color = (menu_cursor == 1) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                        // 20oz
                        else if (h_counter > 830 && h_counter < 980) begin
                            pixel_color = (menu_cursor == 2) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                    end
                    // Back button
                    if (v_counter > 650 && v_counter < 690 && 
                        h_counter > 50 && h_counter < 150) begin
                        pixel_color = COLOR_BUTTON;
                    end
                end
                
                4'd4: begin // Confirmation screen
                    if (v_counter > 400 && v_counter < 450) begin
                        // Cancel button
                        if (h_counter > 400 && h_counter < 550) begin
                            pixel_color = (menu_cursor == 0) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                        // Confirm button
                        else if (h_counter > 730 && h_counter < 880) begin
                            pixel_color = (menu_cursor == 1) ? COLOR_SELECTED : COLOR_BUTTON;
                        end
                    end
                end
                
                4'd5: begin // Pouring animation
                    // Coffee cup outline
                    if ((v_counter > 400 && v_counter < 550) &&
                        (h_counter > 590 && h_counter < 690)) begin
                        // Simple cup shape
                        if ((h_counter == 590 || h_counter == 689) ||
                            (v_counter == 549)) begin
                            pixel_color = COLOR_TEXT;
                        end
                        // Filling animation based on progress
                        else if (v_counter > (549 - (pour_progress * 149 / pour_total))) begin
                            pixel_color = COLOR_COFFEE;
                        end
                    end
                    
                    // Progress bar
                    if (v_counter > 600 && v_counter < 620) begin
                        if (h_counter > 390 && h_counter < (390 + (pour_progress * 500 / pour_total))) begin
                            pixel_color = COLOR_COFFEE;
                        end
                        else if (h_counter >= (390 + (pour_progress * 500 / pour_total)) && h_counter < 890) begin
                            pixel_color = 24'h555555;
                        end
                    end
                end
                
                4'd6: begin // Complete screen
                    if (v_counter > 350 && v_counter < 400 && 
                        h_counter > 490 && h_counter < 790) begin
                        pixel_color = COLOR_BUTTON;
                    end
                end
            endcase
        end
        
        red = pixel_color[23:16];
        green = pixel_color[15:8];
        blue = pixel_color[7:0];
    end
    
endmodule