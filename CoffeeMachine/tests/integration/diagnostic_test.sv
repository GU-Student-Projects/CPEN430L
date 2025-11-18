//============================================================================
// Diagnostic Testbench: Debug brewing stuck and heating issues
//============================================================================

`timescale 1ns/1ps

module diagnostic_test;
    reg clk, rst_n;
    reg [3:0] buttons;
    reg [17:0] switches;
    
    wire [3:0] menu_state;
    wire [4:0] main_state;
    wire [3:0] recipe_state;
    wire system_active;
    wire brewing_active;
    wire recipe_start_brewing;
    wire [127:0] lcd_line1, lcd_line2;
    wire [7:0] brew_progress;
    wire [7:0] current_temp;
    wire temp_ready;
    wire pressure_ready;
    wire water_system_ok;
    
    // Actuator LEDs
    wire led_heater, led_grinder0, led_grinder1, led_water_pour;
    
    // Simplified connections
    coffee_machine_top dut (
        .CLOCK_50(clk),
        .KEY0(buttons[0]), .KEY1(buttons[1]), .KEY2(buttons[2]), .KEY3(buttons[3]),
        .SW0(switches[0]), .SW1(switches[1]), .SW2(switches[2]), .SW3(switches[3]),
        .SW4(switches[4]), .SW5(switches[5]), .SW6(switches[6]), .SW7(switches[7]),
        .SW8(switches[8]), .SW9(switches[9]), .SW10(switches[10]), .SW11(switches[11]),
        .SW12(switches[12]), .SW13(switches[13]), .SW14(switches[14]), .SW15(switches[15]),
        .SW16(switches[16]), .SW17(switches[17]),
        .LEDR8(led_heater),
        .LEDR11(led_grinder0),
        .LEDR12(led_grinder1),
        .LEDR9(led_water_pour),
        .LEDG0(brewing_active),
        .LEDG1(temp_ready),
        .LEDG2(pressure_ready),
        .LEDR0(), .LEDR1(), .LEDR2(), .LEDR3(), .LEDR4(), .LEDR5(), .LEDR6(), .LEDR7(),
        .LEDR10(), .LEDR13(), .LEDR14(), .LEDR15(), .LEDR16(), .LEDR17(),
        .LEDG3(), .LEDG4(), .LEDG5(), .LEDG6(), .LEDG7(), .LEDG8(),
        .LCD_ON(), .LCD_BLON(), .LCD_EN(), .LCD_RS(), .LCD_RW(), .LCD_DATA(),
        .HEX0(), .HEX1(), .HEX2(), .HEX3(), .HEX4(), .HEX5(), .HEX6(), .HEX7()
    );
    
    assign menu_state = dut.menu_state;
    assign main_state = dut.main_fsm_inst.current_state;
    assign recipe_state = dut.recipe_engine_inst.brew_state;
    assign system_active = dut.system_active;
    assign lcd_line1 = dut.final_line1;
    assign lcd_line2 = dut.final_line2;
    assign brew_progress = dut.brew_progress;
    assign current_temp = dut.current_temp;
    assign temp_ready = dut.temp_ready;
    assign pressure_ready = dut.pressure_ready;
    assign water_system_ok = dut.water_system_ok;
    assign recipe_start_brewing = dut.recipe_start_brewing;
    
    // Monitor critical signals
    always @(posedge clk) begin
        // Detect state changes
        if (dut.main_fsm_inst.current_state != dut.main_fsm_inst.last_state) begin
            $display("[%0t] MAIN_FSM: %0d -> %0d", $time, 
                     dut.main_fsm_inst.last_state, 
                     dut.main_fsm_inst.current_state);
        end
        
        if (dut.menu_navigator_inst.current_menu_state != dut.menu_navigator_inst.next_menu_state) begin
            $display("[%0t] MENU: %0d -> %0d", $time,
                     dut.menu_navigator_inst.current_menu_state,
                     dut.menu_navigator_inst.next_menu_state);
        end
        
        // Recipe engine start signal
        if (recipe_start_brewing) begin
            $display("[%0t] *** recipe_start_brewing PULSED ***", $time);
        end
        
        // Recipe state detection
        if (dut.recipe_engine_inst.brew_state != dut.recipe_engine_inst.prev_brew_state) begin
            $display("[%0t] RECIPE: State %0d -> %0d", $time,
                     dut.recipe_engine_inst.prev_brew_state,
                     dut.recipe_engine_inst.brew_state);
        end
        
        // Water system status changes
        if (temp_ready != $past(temp_ready)) begin
            $display("[%0t] temp_ready changed: %b (temp=%0d)", $time, temp_ready, current_temp);
        end
        
        // Actuator activation
        if (led_heater) $display("[%0t] HEATER ON", $time);
        if (led_grinder0) $display("[%0t] GRINDER0 ON", $time);
        if (led_grinder1) $display("[%0t] GRINDER1 ON", $time);
        if (led_water_pour) $display("[%0t] WATER_POUR ON", $time);
    end
    
    // Periodic status during brewing
    integer brew_monitor_count = 0;
    always @(posedge clk) begin
        if (menu_state == 6) begin  // BREWING state
            brew_monitor_count = brew_monitor_count + 1;
            if (brew_monitor_count % 100000 == 0) begin
                $display("[%0t] BREWING STATUS: Progress=%0d%%, RecipeState=%0d, brewing_active=%b, temp=%0d",
                         $time, brew_progress, recipe_state, brewing_active, current_temp);
            end
        end else begin
            brew_monitor_count = 0;
        end
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
    
    task press_button;
        input integer btn_num;
        begin
            $display("\n[%0t] === Pressing Button %0d ===", $time, btn_num);
            buttons[btn_num] = 0;
            #50_000_000;  // Hold 50ms
            buttons[btn_num] = 1;
            #100_000_000; // Wait 100ms for debounce
        end
    endtask
    
    initial begin
        $display("\n=== DIAGNOSTIC TEST: Brewing and Heating Issues ===\n");
        
        // Setup
        buttons = 4'b1111;
        // Bit encoding: [17:16][15:14][13:12][11:10][9:8][7:6][5:4][3:2][1:0]
        //               [--RESET--][--PRESSURE][CHOC][CREAM][BIN1][BIN0][PAPER]
        // Use 10 (HIGH) for pressure instead of 11
        switches = 18'b010111111111111110;  // All consumables full, pressure HIGH (10)
        rst_n = 1;
        
        // Reset
        switches[17] = 1;
        #100;
        switches[17] = 0;
        #100;
        
        $display("Initial State:");
        $display("  Main: %0d, Menu: %0d, Recipe: %0d", main_state, menu_state, recipe_state);
        $display("\nSwitch Configuration:");
        $display("  SW[17] RESET: %b", switches[17]);
        $display("  SW[12] Temp Override: %b", switches[12]);
        $display("  SW[13] System Fault: %b", switches[13]);
        $display("  SW[11:10] Pressure: %b%b", switches[11], switches[10]);
        $display("  SW[9:8] Chocolate: %b%b", switches[9], switches[8]);
        $display("  SW[7:6] Creamer: %b%b", switches[7], switches[6]);
        $display("  SW[5:4] Bin1: %b%b", switches[5], switches[4]);
        $display("  SW[3:2] Bin0: %b%b", switches[3], switches[2]);
        $display("  SW[1:0] Paper: %b%b", switches[1], switches[0]);
        $display("\nSensor Readings:");
        $display("  pressure_ready_sensor: %b", dut.pressure_ready_sensor);
        $display("  water_pressure: %b", dut.water_pressure);
        $display("  temp_ready: %b", temp_ready);
        $display("  pressure_ready: %b", pressure_ready);
        $display("  water_system_ok: %b", water_system_ok);
        
        // Force past INIT
        $display("\n*** FORCING past INIT ***");
        force dut.main_fsm_inst.current_state = 5'd1;
        #20;
        release dut.main_fsm_inst.current_state;
        #1000;
        
        // Navigate through menu
        $display("\n=== TEST 1: Full Brew Cycle ===");
        press_button(2);  // Start menu
        press_button(2);  // Select coffee
        press_button(2);  // Select drink
        press_button(2);  // Select size
        
        $display("\nAt CONFIRM:");
        $display("  LCD Line1: '%s'", lcd_decode(lcd_line1));
        $display("  LCD Line2: '%s'", lcd_decode(lcd_line2));
        $display("  temp_ready: %b, pressure_ready: %b", temp_ready, pressure_ready);
        $display("  water_system_ok: %b", water_system_ok);
        
        press_button(2);  // Start brewing
        
        $display("\nAfter START BREW:");
        $display("  Main State: %0d", main_state);
        $display("  Menu State: %0d", menu_state);
        $display("  Recipe State: %0d", recipe_state);
        $display("  brewing_active: %b", brewing_active);
        $display("  recipe_start_brewing: %b", recipe_start_brewing);
        
        // Wait and observe
        $display("\n=== Monitoring brew progress for 5 seconds ===");
        #5_000_000_000;  // 5 seconds
        
        $display("\nAfter 5 seconds:");
        $display("  Main State: %0d", main_state);
        $display("  Menu State: %0d", menu_state);
        $display("  Recipe State: %0d", recipe_state);
        $display("  Progress: %0d%%", brew_progress);
        $display("  Temperature: %0d", current_temp);
        $display("  brewing_active: %b", brewing_active);
        
        // Check if stuck
        if (recipe_state == 0) begin
            $display("\n*** ERROR: Recipe engine stuck in IDLE! ***");
            $display("    Checking signals:");
            $display("    - recipe_start_brewing (from main_fsm): %b", recipe_start_brewing);
            $display("    - start_brewing (recipe input): %b", dut.recipe_engine_inst.start_brewing);
            $display("    - recipe_valid: %b", dut.recipe_valid);
        end
        
        if (main_state == 4) begin
            $display("\n*** ERROR: Main FSM stuck in HEATING! ***");
            $display("    - current_temp: %0d", current_temp);
            $display("    - temp_ready: %b", temp_ready);
            $display("    - pressure_ready: %b", pressure_ready);
            $display("    - water_system_ok: %b", water_system_ok);
        end
        
        $finish;
    end
endmodule