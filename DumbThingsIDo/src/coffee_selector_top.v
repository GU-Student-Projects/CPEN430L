// Top-level module for Coffee Selector System with VGA and LCD
module coffee_selector_top(
    input wire clk,           // 50MHz clock from DE2-115
    input wire reset_n,       // Active-low reset
    input wire [3:0] key,     // KEY[3:0] on DE2-115 (active-low)
    output wire [7:0] led,    // LEDs for pouring indication
    
    // VGA outputs
    output wire vga_clk,      // VGA pixel clock
    output wire vga_blank_n,  // VGA blank signal
    output wire vga_sync_n,   // VGA sync signal
    output wire vga_hs,       // Horizontal sync
    output wire vga_vs,       // Vertical sync
    output wire [7:0] vga_r,  // Red channel
    output wire [7:0] vga_g,  // Green channel
    output wire [7:0] vga_b,  // Blue channel
    
    // LCD outputs for DE2-115
    output wire lcd_on,       // LCD power on
    output wire lcd_blon,     // LCD backlight on
    output wire lcd_rs,       // LCD register select (0=command, 1=data)
    output wire lcd_en,       // LCD enable
    output wire lcd_rw,       // LCD read/write (0=write)
    inout wire [7:0] lcd_data // LCD data bus
);

    // Internal signals
    wire pixel_clk;
    wire [10:0] h_counter;
    wire [9:0] v_counter;
    wire h_sync, v_sync;
    wire display_enable;
    wire [7:0] red, green, blue;
    
    // Debounced key signals
    wire key0_press, key1_press, key2_press, key3_press;
    
    // State machine signals
    reg [3:0] current_state;
    reg [3:0] next_state;
    reg [1:0] coffee_selection;  // 0: none, 1: coffee1, 2: coffee2
    reg [1:0] strength_selection; // 0: mild, 1: medium, 2: strong
    reg [1:0] size_selection;     // 0: 10oz, 1: 16oz, 2: 20oz
    reg [1:0] menu_cursor;        // Current selection position
    reg pouring;
    reg [23:0] pour_timer;
    reg [23:0] pour_duration;
    
    // LCD control signals
    wire lcd_busy;
    reg lcd_update;
    
    // State definitions
    localparam STATE_WELCOME    = 4'd0;
    localparam STATE_COFFEE_SEL = 4'd1;
    localparam STATE_STRENGTH   = 4'd2;
    localparam STATE_SIZE       = 4'd3;
    localparam STATE_CONFIRM    = 4'd4;
    localparam STATE_POURING    = 4'd5;
    localparam STATE_COMPLETE   = 4'd6;
    
    // PLL for 74.25MHz pixel clock (720p@60Hz)
    pll_vga pll_inst(
        .inclk0(clk),
        .c0(pixel_clk)
    );
    
    // VGA timing generator for 720p@60Hz
    vga_timing_720p timing_gen(
        .pixel_clk(pixel_clk),
        .reset_n(reset_n),
        .h_counter(h_counter),
        .v_counter(v_counter),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .display_enable(display_enable)
    );
    
    // Key debouncing
    key_debounce debounce0(.clk(clk), .reset_n(reset_n), .key_in(~key[0]), .key_out(key0_press));
    key_debounce debounce1(.clk(clk), .reset_n(reset_n), .key_in(~key[1]), .key_out(key1_press));
    key_debounce debounce2(.clk(clk), .reset_n(reset_n), .key_in(~key[2]), .key_out(key2_press));
    key_debounce debounce3(.clk(clk), .reset_n(reset_n), .key_in(~key[3]), .key_out(key3_press));
    
    // LCD Controller Instance
    lcd_controller lcd_ctrl(
        .clk(clk),
        .reset_n(reset_n),
        .current_state(current_state),
        .menu_cursor(menu_cursor),
        .coffee_selection(coffee_selection),
        .strength_selection(strength_selection),
        .size_selection(size_selection),
        .pour_progress(pour_timer),
        .pour_total(pour_duration),
        .update_trigger(lcd_update),
        .lcd_on(lcd_on),
        .lcd_blon(lcd_blon),
        .lcd_rs(lcd_rs),
        .lcd_en(lcd_en),
        .lcd_rw(lcd_rw),
        .lcd_data(lcd_data),
        .busy(lcd_busy)
    );
    
    // State machine
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= STATE_WELCOME;
            coffee_selection <= 2'd0;
            strength_selection <= 2'd1;
            size_selection <= 2'd0;
            menu_cursor <= 2'd0;
            pouring <= 1'b0;
            pour_timer <= 24'd0;
            pour_duration <= 24'd0;
            lcd_update <= 1'b1;
        end else begin
            current_state <= next_state;
            
            // Trigger LCD update on state change
            if (current_state != next_state) begin
                lcd_update <= 1'b1;
            end else begin
                lcd_update <= 1'b0;
            end
            
            case (current_state)
                STATE_WELCOME: begin
                    if (key0_press) begin
                        menu_cursor <= 2'd0;
                    end
                end
                
                STATE_COFFEE_SEL: begin
                    if (key1_press && menu_cursor > 0) begin
                        menu_cursor <= menu_cursor - 1;
                        lcd_update <= 1'b1;
                    end
                    if (key2_press && menu_cursor < 1) begin
                        menu_cursor <= menu_cursor + 1;
                        lcd_update <= 1'b1;
                    end
                    if (key0_press) begin
                        coffee_selection <= menu_cursor + 1;
                        menu_cursor <= 2'd1; // Default to medium strength
                    end
                end
                
                STATE_STRENGTH: begin
                    if (key1_press && menu_cursor > 0) begin
                        menu_cursor <= menu_cursor - 1;
                        lcd_update <= 1'b1;
                    end
                    if (key2_press && menu_cursor < 2) begin
                        menu_cursor <= menu_cursor + 1;
                        lcd_update <= 1'b1;
                    end
                    if (key0_press) begin
                        strength_selection <= menu_cursor;
                        menu_cursor <= 2'd0; // Default to 10oz
                    end
                end
                
                STATE_SIZE: begin
                    if (key1_press && menu_cursor > 0) begin
                        menu_cursor <= menu_cursor - 1;
                        lcd_update <= 1'b1;
                    end
                    if (key2_press && menu_cursor < 2) begin
                        menu_cursor <= menu_cursor + 1;
                        lcd_update <= 1'b1;
                    end
                    if (key0_press) begin
                        size_selection <= menu_cursor;
                        menu_cursor <= 2'd0;
                    end
                end
                
                STATE_CONFIRM: begin
                    if (key1_press && menu_cursor > 0) begin
                        menu_cursor <= menu_cursor - 1;
                        lcd_update <= 1'b1;
                    end
                    if (key2_press && menu_cursor < 1) begin
                        menu_cursor <= menu_cursor + 1;
                        lcd_update <= 1'b1;
                    end
                    if (key0_press && menu_cursor == 1) begin
                        // Start pouring
                        pouring <= 1'b1;
                        pour_timer <= 24'd0;
                        // Set pour duration based on size (at 50MHz base clock)
                        case (size_selection)
                            2'd0: pour_duration <= 24'd150_000_000; // 3 seconds for 10oz
                            2'd1: pour_duration <= 24'd250_000_000; // 5 seconds for 16oz
                            2'd2: pour_duration <= 24'd350_000_000; // 7 seconds for 20oz
                            default: pour_duration <= 24'd150_000_000;
                        endcase
                    end
                end
                
                STATE_POURING: begin
                    if (pour_timer < pour_duration) begin
                        pour_timer <= pour_timer + 1;
                        // Update LCD periodically during pouring
                        if (pour_timer[19:0] == 20'd0) begin
                            lcd_update <= 1'b1;
                        end
                    end else begin
                        pouring <= 1'b0;
                        pour_timer <= 24'd0;
                    end
                end
                
                STATE_COMPLETE: begin
                    if (key0_press) begin
                        coffee_selection <= 2'd0;
                        strength_selection <= 2'd1;
                        size_selection <= 2'd0;
                        menu_cursor <= 2'd0;
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            STATE_WELCOME: begin
                if (key0_press) next_state = STATE_COFFEE_SEL;
            end
            
            STATE_COFFEE_SEL: begin
                if (key0_press) next_state = STATE_STRENGTH;
                else if (key3_press) next_state = STATE_WELCOME;
            end
            
            STATE_STRENGTH: begin
                if (key0_press) next_state = STATE_SIZE;
                else if (key3_press) next_state = STATE_COFFEE_SEL;
            end
            
            STATE_SIZE: begin
                if (key0_press) next_state = STATE_CONFIRM;
                else if (key3_press) next_state = STATE_STRENGTH;
            end
            
            STATE_CONFIRM: begin
                if (key0_press && menu_cursor == 1) next_state = STATE_POURING;
                else if (key0_press && menu_cursor == 0) next_state = STATE_SIZE;
                else if (key3_press) next_state = STATE_SIZE;
            end
            
            STATE_POURING: begin
                if (!pouring) next_state = STATE_COMPLETE;
            end
            
            STATE_COMPLETE: begin
                if (key0_press) next_state = STATE_WELCOME;
            end
        endcase
    end
    
    // Display controller for VGA
    display_controller display(
        .pixel_clk(pixel_clk),
        .h_counter(h_counter),
        .v_counter(v_counter),
        .display_enable(display_enable),
        .current_state(current_state),
        .menu_cursor(menu_cursor),
        .coffee_selection(coffee_selection),
        .strength_selection(strength_selection),
        .size_selection(size_selection),
        .pour_progress(pour_timer),
        .pour_total(pour_duration),
        .red(red),
        .green(green),
        .blue(blue)
    );
    
    // LED control for pouring indication
    assign led = pouring ? 8'hFF : 8'h00;
    
    // VGA output assignments
    assign vga_clk = pixel_clk;
    assign vga_hs = ~h_sync;
    assign vga_vs = ~v_sync;
    assign vga_blank_n = display_enable;
    assign vga_sync_n = 1'b0;
    assign vga_r = display_enable ? red : 8'h00;
    assign vga_g = display_enable ? green : 8'h00;
    assign vga_b = display_enable ? blue : 8'h00;

endmodule

