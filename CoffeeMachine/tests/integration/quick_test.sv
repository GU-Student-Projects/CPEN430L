//============================================================================
// Quick Testbench: Force past INIT state
//============================================================================

`timescale 1ns/1ps

module quick_test;
    reg clk, rst_n;
    reg [3:0] buttons;
    reg [17:0] switches;
    
    wire [3:0] menu_state;
    wire [4:0] main_state;
    wire system_active;
    wire [127:0] lcd_line1, lcd_line2;
    
    // Simplified connections - just what we need
    coffee_machine_top dut (
        .CLOCK_50(clk),
        .KEY0(buttons[0]), .KEY1(buttons[1]), .KEY2(buttons[2]), .KEY3(buttons[3]),
        .SW0(switches[0]), .SW1(switches[1]), .SW2(switches[2]), .SW3(switches[3]),
        .SW4(switches[4]), .SW5(switches[5]), .SW6(switches[6]), .SW7(switches[7]),
        .SW8(switches[8]), .SW9(switches[9]), .SW10(switches[10]), .SW11(switches[11]),
        .SW12(switches[12]), .SW13(switches[13]), .SW14(switches[14]), .SW15(switches[15]),
        .SW16(switches[16]), .SW17(switches[17]),
        .LEDR0(), .LEDR1(), .LEDR2(), .LEDR3(), .LEDR4(), .LEDR5(), .LEDR6(), .LEDR7(),
        .LEDR8(), .LEDR9(), .LEDR10(), .LEDR11(), .LEDR12(), .LEDR13(), .LEDR14(), .LEDR15(),
        .LEDR16(), .LEDR17(),
        .LEDG0(), .LEDG1(), .LEDG2(), .LEDG3(), .LEDG4(), .LEDG5(), .LEDG6(), .LEDG7(), .LEDG8(),
        .LCD_ON(), .LCD_BLON(), .LCD_EN(), .LCD_RS(), .LCD_RW(), .LCD_DATA(),
        .HEX0(), .HEX1(), .HEX2(), .HEX3(), .HEX4(), .HEX5(), .HEX6(), .HEX7()
    );
    
    assign menu_state = dut.menu_state;
    assign main_state = dut.main_fsm_inst.current_state;
    assign system_active = dut.system_active;
    assign lcd_line1 = dut.message_manager_inst.line1_text;
    assign lcd_line2 = dut.message_manager_inst.line2_text;
    
    // Monitor button presses
    always @(posedge clk) begin
        if (dut.menu_navigator_inst.btn_select_pressed)
            $display("[%0t] *** btn_select_pressed detected! ***", $time);
        if (dut.menu_navigator_inst.btn_cancel_pressed)
            $display("[%0t] *** btn_cancel_pressed detected! ***", $time);
        if (dut.menu_navigator_inst.btn_left_pressed)
            $display("[%0t] *** btn_left_pressed detected! ***", $time);
        if (dut.menu_navigator_inst.btn_right_pressed)
            $display("[%0t] *** btn_right_pressed detected! ***", $time);
    end
    
    // Clock
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    // Helper to display LCD text
    function string lcd_decode;
        input [127:0] data;
        integer i;
        reg [7:0] c;
        begin
            lcd_decode = "";
            for (i = 0; i < 16; i++) begin
                c = data[127-i*8 -: 8];
                if (c >= 8'h20 && c <= 8'h7E)
                    lcd_decode = {lcd_decode, string'(c)};
                else
                    lcd_decode = {lcd_decode, " "};
            end
        end
    endfunction
    
    initial begin
        $display("\n=== QUICK TEST: Check State Transitions ===\n");
        
        // Setup
        buttons = 4'b1111;  // All released
        switches = 18'b011111111111111110;  // All consumables infinite, pressure OK, no reset
        rst_n = 1;
        
        // Reset
        switches[17] = 1;
        #100;
        switches[17] = 0;
        #100;
        
        $display("After Reset:");
        $display("  Main State: %0d", main_state);
        $display("  Menu State: %0d", menu_state);
        $display("  system_active: %b", system_active);
        $display("  error_present: %b", dut.error_present);
        $display("  can_make_coffee: %b", dut.can_make_coffee);
        $display("  pressure_ready: %b", dut.pressure_ready);
        
        // FORCE past INIT by directly setting state (simulation hack)
        $display("\n*** FORCING main FSM past INIT state ***");
        force dut.main_fsm_inst.current_state = 5'd1;  // Force to SPLASH
        #20;
        release dut.main_fsm_inst.current_state;
        
        #1000;
        $display("\nAfter forcing to SPLASH:");
        $display("  Main State: %0d", main_state);
        $display("  Menu State: %0d", menu_state);
        
        // Now try pressing SELECT (KEY2)
        $display("\n*** Pressing SELECT to start menu ***");
        buttons[2] = 0;  // Press SELECT (KEY2)
        #50_000_000;     // Hold for 50ms
        buttons[2] = 1;  // Release
        #100_000_000;    // Wait 100ms for debounce to fully reset
        
        $display("After SELECT:");
        $display("  Main State: %0d", main_state);
        $display("  Menu State: %0d (should be 2=COFFEE_SELECT)", menu_state);
        $display("  LCD Line1: '%s'", lcd_decode(lcd_line1));
        $display("  LCD Line2: '%s'", lcd_decode(lcd_line2));
        
        // Select coffee
        $display("\n*** SELECT coffee bin ***");
        buttons[2] = 0; #50_000_000; buttons[2] = 1; #100_000_000;
        $display("  Menu State: %0d (should be 3=DRINK_SELECT)", menu_state);
        $display("  LCD Line1: '%s'", lcd_decode(lcd_line1));
        
        // Select drink
        $display("\n*** SELECT drink ***");
        buttons[2] = 0; #50_000_000; buttons[2] = 1; #100_000_000;
        $display("  Menu State: %0d (should be 4=SIZE_SELECT)", menu_state);
        $display("  LCD Line1: '%s'", lcd_decode(lcd_line1));
        
        // Select size
        $display("\n*** SELECT size ***");
        buttons[2] = 0; #50_000_000; buttons[2] = 1; #100_000_000;
        $display("  Menu State: %0d (should be 5=CONFIRM)", menu_state);
        $display("  LCD Line1: '%s'", lcd_decode(lcd_line1));
        $display("  LCD Line2: '%s'", lcd_decode(lcd_line2));
        
        // Confirm brew
        $display("\n*** CONFIRM BREW (START) ***");
        buttons[2] = 0; #50_000_000; buttons[2] = 1; #100_000_000;
        
        $display("\n=== CRITICAL CHECK ===");
        $display("  Menu State: %0d", menu_state);
        if (menu_state == 7) begin
            $display("  *** BUG: Menu jumped to COMPLETE (state 7)! ***");
        end else if (menu_state == 6) begin
            $display("  *** GOOD: Menu is in BREWING (state 6) ***");
        end else begin
            $display("  ??? Unexpected state: %0d", menu_state);
        end
        
        $display("  Main State: %0d", main_state);
        $display("  system_active: %b", system_active);
        $display("  LCD Line1: '%s'", lcd_decode(lcd_line1));
        $display("  LCD Line2: '%s'", lcd_decode(lcd_line2));
        
        #1000000;
        $finish;
    end
endmodule