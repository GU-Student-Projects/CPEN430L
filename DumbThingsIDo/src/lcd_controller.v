// LCD Controller Module for 16x2 Character LCD
module lcd_controller(
    input wire clk,
    input wire reset_n,
    input wire [3:0] current_state,
    input wire [1:0] menu_cursor,
    input wire [1:0] coffee_selection,
    input wire [1:0] strength_selection,
    input wire [1:0] size_selection,
    input wire [23:0] pour_progress,
    input wire [23:0] pour_total,
    input wire update_trigger,
    
    output wire lcd_on,
    output wire lcd_blon,
    output reg lcd_rs,
    output reg lcd_en,
    output wire lcd_rw,
    inout wire [7:0] lcd_data,
    output wire busy
);
    
    // LCD states
    localparam LCD_INIT = 3'd0;
    localparam LCD_IDLE = 3'd1;
    localparam LCD_CLEAR = 3'd2;
    localparam LCD_SET_ADDR = 3'd3;
    localparam LCD_WRITE_CHAR = 3'd4;
    localparam LCD_WAIT = 3'd5;
    
    reg [2:0] lcd_state;
    reg [2:0] lcd_next_state;
    reg [19:0] delay_counter;
    reg [4:0] init_step;
    reg [7:0] char_index;
    reg [7:0] lcd_data_out;
    reg lcd_data_dir; // 0 = input, 1 = output
    
    // Display buffers
    reg [7:0] line1 [0:15];
    reg [7:0] line2 [0:15];
    reg [4:0] char_pos;
    reg current_line;
    
    // Assign LCD control signals
    assign lcd_on = 1'b1;
    assign lcd_blon = 1'b1;
    assign lcd_rw = 1'b0; // Always write
    assign lcd_data = lcd_data_dir ? lcd_data_out : 8'hZ;
    assign busy = (lcd_state != LCD_IDLE);
    
    // Update display content based on current state
    always @(posedge clk) begin
        if (!reset_n || update_trigger) begin
            case (current_state)
                4'd0: begin // Welcome
                    // Line 1: "Coffee Selector"
                    line1[0] <= "C"; line1[1] <= "o"; line1[2] <= "f"; line1[3] <= "f";
                    line1[4] <= "e"; line1[5] <= "e"; line1[6] <= " "; line1[7] <= "S";
                    line1[8] <= "e"; line1[9] <= "l"; line1[10] <= "e"; line1[11] <= "c";
                    line1[12] <= "t"; line1[13] <= "o"; line1[14] <= "r"; line1[15] <= " ";
                    // Line 2: "Press KEY0"
                    line2[0] <= "P"; line2[1] <= "r"; line2[2] <= "e"; line2[3] <= "s";
                    line2[4] <= "s"; line2[5] <= " "; line2[6] <= "K"; line2[7] <= "E";
                    line2[8] <= "Y"; line2[9] <= "0"; line2[10] <= " "; line2[11] <= " ";
                    line2[12] <= " "; line2[13] <= " "; line2[14] <= " "; line2[15] <= " ";
                end
                
                4'd1: begin // Coffee Selection
                    // Line 1: "Select Coffee:"
                    line1[0] <= "S"; line1[1] <= "e"; line1[2] <= "l"; line1[3] <= "e";
                    line1[4] <= "c"; line1[5] <= "t"; line1[6] <= " "; line1[7] <= "C";
                    line1[8] <= "o"; line1[9] <= "f"; line1[10] <= "f"; line1[11] <= "e";
                    line1[12] <= "e"; line1[13] <= ":"; line1[14] <= " "; line1[15] <= " ";
                    // Line 2: "[1] [2]" with cursor indication
                    if (menu_cursor == 0) begin
                        line2[0] <= ">"; line2[1] <= "1"; line2[2] <= "<"; line2[3] <= " ";
                    end else begin
                        line2[0] <= " "; line2[1] <= "1"; line2[2] <= " "; line2[3] <= " ";
                    end
                    line2[4] <= " "; line2[5] <= " "; line2[6] <= " "; line2[7] <= " ";
                    if (menu_cursor == 1) begin
                        line2[8] <= ">"; line2[9] <= "2"; line2[10] <= "<"; line2[11] <= " ";
                    end else begin
                        line2[8] <= " "; line2[9] <= "2"; line2[10] <= " "; line2[11] <= " ";
                    end
                    line2[12] <= " "; line2[13] <= " "; line2[14] <= " "; line2[15] <= " ";
                end
                
                4'd2: begin // Strength Selection
                    // Line 1: "Strength:"
                    line1[0] <= "S"; line1[1] <= "t"; line1[2] <= "r"; line1[3] <= "e";
                    line1[4] <= "n"; line1[5] <= "g"; line1[6] <= "t"; line1[7] <= "h";
                    line1[8] <= ":"; line1[9] <= " "; line1[10] <= " "; line1[11] <= " ";
                    line1[12] <= " "; line1[13] <= " "; line1[14] <= " "; line1[15] <= " ";
                    // Line 2: "Mild Med Strong" with cursor
                    if (menu_cursor == 0) begin
                        line2[0] <= ">"; line2[1] <= "M"; line2[2] <= "i"; line2[3] <= "l";
                        line2[4] <= "d";
                    end else begin
                        line2[0] <= " "; line2[1] <= "M"; line2[2] <= "i"; line2[3] <= "l";
                        line2[4] <= "d";
                    end
                    line2[5] <= " ";
                    if (menu_cursor == 1) begin
                        line2[6] <= ">"; line2[7] <= "M"; line2[8] <= "e"; line2[9] <= "d";
                    end else begin
                        line2[6] <= " "; line2[7] <= "M"; line2[8] <= "e"; line2[9] <= "d";
                    end
                    line2[10] <= " ";
                    if (menu_cursor == 2) begin
                        line2[11] <= ">"; line2[12] <= "S"; line2[13] <= "t"; line2[14] <= "r";
                        line2[15] <= "g";
                    end else begin
                        line2[11] <= " "; line2[12] <= "S"; line2[13] <= "t"; line2[14] <= "r";
                        line2[15] <= "g";
                    end
                end
                
                4'd3: begin // Size Selection
                    // Line 1: "Select Size:"
                    line1[0] <= "S"; line1[1] <= "e"; line1[2] <= "l"; line1[3] <= "e";
                    line1[4] <= "c"; line1[5] <= "t"; line1[6] <= " "; line1[7] <= "S";
                    line1[8] <= "i"; line1[9] <= "z"; line1[10] <= "e"; line1[11] <= ":";
                    line1[12] <= " "; line1[13] <= " "; line1[14] <= " "; line1[15] <= " ";
                    // Line 2: "10oz 16oz 20oz" with cursor
                    if (menu_cursor == 0) begin
                        line2[0] <= ">"; line2[1] <= "1"; line2[2] <= "0"; line2[3] <= "o";
                        line2[4] <= "z";
                    end else begin
                        line2[0] <= " "; line2[1] <= "1"; line2[2] <= "0"; line2[3] <= "o";
                        line2[4] <= "z";
                    end
                    line2[5] <= " ";
                    if (menu_cursor == 1) begin
                        line2[6] <= ">"; line2[7] <= "1"; line2[8] <= "6"; line2[9] <= "o";
                        line2[10] <= "z";
                    end else begin
                        line2[6] <= " "; line2[7] <= "1"; line2[8] <= "6"; line2[9] <= "o";
                        line2[10] <= "z";
                    end
                    line2[11] <= " ";
                    if (menu_cursor == 2) begin
                        line2[12] <= ">"; line2[13] <= "2"; line2[14] <= "0"; line2[15] <= "z";
                    end else begin
                        line2[12] <= " "; line2[13] <= "2"; line2[14] <= "0"; line2[15] <= "z";
                    end
                end
                
                4'd4: begin // Confirmation
                    // Line 1: "Confirm Order?"
                    line1[0] <= "C"; line1[1] <= "o"; line1[2] <= "n"; line1[3] <= "f";
                    line1[4] <= "i"; line1[5] <= "r"; line1[6] <= "m"; line1[7] <= " ";
                    line1[8] <= "O"; line1[9] <= "r"; line1[10] <= "d"; line1[11] <= "e";
                    line1[12] <= "r"; line1[13] <= "?"; line1[14] <= " "; line1[15] <= " ";
                    // Line 2: "Cancel  Confirm"
                    if (menu_cursor == 0) begin
                        line2[0] <= ">"; line2[1] <= "C"; line2[2] <= "a"; line2[3] <= "n";
                        line2[4] <= "c"; line2[5] <= "e"; line2[6] <= "l"; line2[7] <= " ";
                    end else begin
                        line2[0] <= " "; line2[1] <= "C"; line2[2] <= "a"; line2[3] <= "n";
                        line2[4] <= "c"; line2[5] <= "e"; line2[6] <= "l"; line2[7] <= " ";
                    end
                    if (menu_cursor == 1) begin
                        line2[8] <= ">"; line2[9] <= "C"; line2[10] <= "o"; line2[11] <= "n";
                        line2[12] <= "f"; line2[13] <= "i"; line2[14] <= "r"; line2[15] <= "m";
                    end else begin
                        line2[8] <= " "; line2[9] <= "C"; line2[10] <= "o"; line2[11] <= "n";
                        line2[12] <= "f"; line2[13] <= "i"; line2[14] <= "r"; line2[15] <= "m";
                    end
                end
                
                4'd5: begin // Pouring
                    // Line 1: "Pouring..."
                    line1[0] <= "P"; line1[1] <= "o"; line1[2] <= "u"; line1[3] <= "r";
                    line1[4] <= "i"; line1[5] <= "n"; line1[6] <= "g"; line1[7] <= ".";
                    line1[8] <= "."; line1[9] <= "."; line1[10] <= " "; line1[11] <= " ";
                    line1[12] <= " "; line1[13] <= " "; line1[14] <= " "; line1[15] <= " ";
                    // Line 2: Progress bar
                    begin
                        integer i;
                        reg [7:0] progress_chars;
                        progress_chars = (pour_progress * 16) / pour_total;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < progress_chars)
                                line2[i] <= 8'hFF; // Full block character
                            else
                                line2[i] <= 8'h2D; // Dash character
                        end
                    end
                end
                
                4'd6: begin // Complete
                    // Line 1: "Complete!"
                    line1[0] <= "C"; line1[1] <= "o"; line1[2] <= "m"; line1[3] <= "p";
                    line1[4] <= "l"; line1[5] <= "e"; line1[6] <= "t"; line1[7] <= "e";
                    line1[8] <= "!"; line1[9] <= " "; line1[10] <= " "; line1[11] <= " ";
                    line1[12] <= " "; line1[13] <= " "; line1[14] <= " "; line1[15] <= " ";
                    // Line 2: "Press KEY0"
                    line2[0] <= "P"; line2[1] <= "r"; line2[2] <= "e"; line2[3] <= "s";
                    line2[4] <= "s"; line2[5] <= " "; line2[6] <= "K"; line2[7] <= "E";
                    line2[8] <= "Y"; line2[9] <= "0"; line2[10] <= " "; line2[11] <= " ";
                    line2[12] <= " "; line2[13] <= " "; line2[14] <= " "; line2[15] <= " ";
                end
            endcase
        end
    end
    
    // LCD state machine
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            lcd_state <= LCD_INIT;
            delay_counter <= 20'd0;
            init_step <= 5'd0;
            char_pos <= 5'd0;
            current_line <= 1'b0;
            lcd_data_dir <= 1'b1;
            lcd_rs <= 1'b0;
            lcd_en <= 1'b0;
            lcd_data_out <= 8'h00;
        end else begin
            case (lcd_state)
                LCD_INIT: begin
                    // Initialization sequence for 16x2 LCD
                    if (delay_counter < 20'd750000) begin // 15ms delay at 50MHz
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 20'd0;
                        case (init_step)
                            5'd0: begin
                                lcd_data_out <= 8'h38; // Function set: 8-bit, 2-line
                                lcd_rs <= 1'b0;
                                lcd_en <= 1'b1;
                                init_step <= init_step + 1;
                            end
                            5'd1: begin
                                lcd_en <= 1'b0;
                                init_step <= init_step + 1;
                            end
                            5'd2: begin
                                lcd_data_out <= 8'h0C; // Display on, cursor off
                                lcd_en <= 1'b1;
                                init_step <= init_step + 1;
                            end
                            5'd3: begin
                                lcd_en <= 1'b0;
                                init_step <= init_step + 1;
                            end
                            5'd4: begin
                                lcd_data_out <= 8'h01; // Clear display
                                lcd_en <= 1'b1;
                                init_step <= init_step + 1;
                            end
                            5'd5: begin
                                lcd_en <= 1'b0;
                                init_step <= init_step + 1;
                            end
                            5'd6: begin
                                lcd_data_out <= 8'h06; // Entry mode: increment
                                lcd_en <= 1'b1;
                                init_step <= init_step + 1;
                            end
                            5'd7: begin
                                lcd_en <= 1'b0;
                                init_step <= init_step + 1;
                            end
                            default: begin
                                lcd_state <= LCD_IDLE;
                                init_step <= 5'd0;
                            end
                        endcase
                    end
                end
                
                LCD_IDLE: begin
                    if (update_trigger) begin
                        lcd_state <= LCD_CLEAR;
                        char_pos <= 5'd0;
                        current_line <= 1'b0;
                    end
                end
                
                LCD_CLEAR: begin
                    if (delay_counter < 20'd2000) begin
                        if (delay_counter == 20'd0) begin
                            lcd_data_out <= 8'h01; // Clear command
                            lcd_rs <= 1'b0;
                            lcd_en <= 1'b1;
                        end else if (delay_counter == 20'd10) begin
                            lcd_en <= 1'b0;
                        end
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 20'd0;
                        lcd_state <= LCD_SET_ADDR;
                    end
                end
                
                LCD_SET_ADDR: begin
                    if (delay_counter < 20'd2000) begin
                        if (delay_counter == 20'd0) begin
                            // Set DDRAM address
                            lcd_data_out <= current_line ? 8'hC0 : 8'h80;
                            lcd_rs <= 1'b0;
                            lcd_en <= 1'b1;
                        end else if (delay_counter == 20'd10) begin
                            lcd_en <= 1'b0;
                        end
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 20'd0;
                        lcd_state <= LCD_WRITE_CHAR;
                        char_pos <= 5'd0;
                    end
                end
                
                LCD_WRITE_CHAR: begin
                    if (delay_counter < 20'd2000) begin
                        if (delay_counter == 20'd0) begin
                            // Write character data
                            lcd_data_out <= current_line ? line2[char_pos] : line1[char_pos];
                            lcd_rs <= 1'b1;
                            lcd_en <= 1'b1;
                        end else if (delay_counter == 20'd10) begin
                            lcd_en <= 1'b0;
                        end
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 20'd0;
                        if (char_pos < 15) begin
                            char_pos <= char_pos + 1;
                        end else if (!current_line) begin
                            current_line <= 1'b1;
                            lcd_state <= LCD_SET_ADDR;
                        end else begin
                            lcd_state <= LCD_IDLE;
                            current_line <= 1'b0;
                        end
                    end
                end
                
                default: lcd_state <= LCD_IDLE;
            endcase
        end
    end
    
endmodule