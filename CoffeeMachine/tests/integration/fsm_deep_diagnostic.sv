//============================================================================
// Deep FSM Diagnostic - Find why stuck in ERROR_CYCLE
//============================================================================

`timescale 1ns/1ps

module fsm_deep_diagnostic;
    reg clk, rst_n;
    reg [3:0] buttons;
    reg [17:0] switches;
    
    wire [3:0] menu_state;
    wire [4:0] main_state;
    wire [4:0] main_next_state;
    
    // All the conditions that affect FSM transitions
    wire enter_maintenance_mode;
    wire start_brewing_cmd;
    wire critical_error;
    wire error_present;
    wire [3:0] warning_count;
    wire [3:0] error_count;
    wire can_make_coffee;
    wire water_system_ok;
    wire temp_ready;
    wire pressure_ready;
    wire recipe_valid;
    
    // System status
    wire system_ready;
    wire system_active;
    
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
    
    // Tap into internal signals
    assign menu_state = dut.menu_state;
    assign main_state = dut.main_fsm_inst.current_state;
    assign main_next_state = dut.main_fsm_inst.next_state;
    
    assign enter_maintenance_mode = dut.enter_maintenance_mode;
    assign start_brewing_cmd = dut.start_brewing_cmd;
    assign critical_error = dut.critical_error;
    assign error_present = dut.error_present;
    assign warning_count = dut.warning_count;
    assign error_count = dut.error_count;
    assign can_make_coffee = dut.can_make_coffee;
    assign water_system_ok = dut.water_system_ok;
    assign temp_ready = dut.temp_ready;
    assign pressure_ready = dut.pressure_ready;
    assign recipe_valid = dut.recipe_valid;
    assign system_ready = dut.system_ready;
    assign system_active = dut.system_active;
    
    // Clock
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    // Monitor FSM state transitions with detailed reasoning
    always @(posedge clk) begin
        if (main_state == 2) begin  // ERROR_CYCLE state
            // Check all conditions in the ERROR_CYCLE next state logic
            if (enter_maintenance_mode) begin
                $display("[%0t] ERROR_CYCLE: Should go to MAINTENANCE (enter_maintenance_mode=1)", $time);
            end else if (start_brewing_cmd && !critical_error) begin
                $display("[%0t] ERROR_CYCLE: Should go to IDLE (start_brewing_cmd=1, !critical_error)", $time);
            end else if (menu_state != 0 && menu_state != 1 && !critical_error) begin
                $display("[%0t] ERROR_CYCLE: Should go to IDLE (menu navigated, menu=%0d, !critical_error)", $time, menu_state);
            end else if (!critical_error && warning_count == 0) begin
                $display("[%0t] ERROR_CYCLE: Should go to SPLASH (!critical_error, warning_count=0)", $time);
            end else begin
                // None of the exit conditions are met - explain why stuck
                $display("[%0t] ERROR_CYCLE: STUCK! Checking exit conditions:", $time);
                $display("    enter_maintenance_mode = %b (need 1)", enter_maintenance_mode);
                $display("    start_brewing_cmd = %b (need 1)", start_brewing_cmd);
                $display("    critical_error = %b (need 0 for exit)", critical_error);
                $display("    menu_state = %0d (need != 0 and != 1)", menu_state);
                $display("    warning_count = %0d (need 0 for SPLASH)", warning_count);
                $display("    ---");
                $display("    Can exit if: start_brewing_cmd && !critical_error");
                $display("                 OR menu_state not in {0,1} && !critical_error");
                $display("                 OR !critical_error && warning_count==0");
            end
        end
    end
    
    // Detailed status logger every 500ms during error state
    integer error_log_count = 0;
    always @(posedge clk) begin
        if (main_state == 2) begin
            error_log_count = error_log_count + 1;
            if (error_log_count % 25_000_000 == 0) begin  // Every 500ms
                $display("\n[%0t] ===== ERROR_CYCLE STATE DIAGNOSTIC =====", $time);
                $display("Main FSM:");
                $display("  current_state = %0d (ERROR_CYCLE)", main_state);
                $display("  next_state = %0d", main_next_state);
                $display("\nMenu Navigator:");
                $display("  menu_state = %0d", menu_state);
                $display("  start_brewing_cmd = %b", start_brewing_cmd);
                $display("\nError System:");
                $display("  critical_error = %b", critical_error);
                $display("  error_present = %b", error_present);
                $display("  error_count = %0d", error_count);
                $display("  warning_count = %0d", warning_count);
                $display("\nWater System:");
                $display("  temp_ready = %b", temp_ready);
                $display("  pressure_ready = %b", pressure_ready);
                $display("  water_system_ok = %b", water_system_ok);
                $display("\nRecipe:");
                $display("  recipe_valid = %b", recipe_valid);
                $display("  can_make_coffee = %b", can_make_coffee);
                $display("\nSystem Status:");
                $display("  system_ready = %b", system_ready);
                $display("  system_active = %b", system_active);
                $display("============================================\n");
            end
        end else begin
            error_log_count = 0;
        end
    end
    
    task press_button;
        input integer btn_num;
        begin
            $display("\n[%0t] === Pressing Button %0d ===", $time, btn_num);
            buttons[btn_num] = 0;
            #50_000_000;
            buttons[btn_num] = 1;
            #100_000_000;
        end
    endtask
    
    initial begin
        $display("\n=== DEEP FSM DIAGNOSTIC ===\n");
        
        buttons = 4'b1111;
        // Try with pressure = 10 (normal)
        switches = 18'b0_00_1_0_01_11_11_11_11_11;
        rst_n = 1;
        
        // Reset
        switches[17] = 1;
        #100;
        switches[17] = 0;
        #100;
        
        $display("After Reset:");
        $display("  Main State: %0d", main_state);
        $display("  Menu State: %0d", menu_state);
        $display("  Pressure switches [11:10]: %b%b", switches[11], switches[10]);
        $display("  pressure_ready: %b", pressure_ready);
        $display("  water_system_ok: %b", water_system_ok);
        
        // Force past INIT
        $display("\n*** Forcing past INIT ***");
        force dut.main_fsm_inst.current_state = 5'd1;  // SPLASH
        #20;
        release dut.main_fsm_inst.current_state;
        #1000;
        
        $display("After forcing to SPLASH:");
        $display("  Main State: %0d", main_state);
        $display("  critical_error: %b", critical_error);
        $display("  warning_count: %0d", warning_count);
        
        // Navigate menu
        press_button(2);  // Start
        
        $display("\nAfter first button press:");
        $display("  Main State: %0d", main_state);
        $display("  Menu State: %0d", menu_state);
        
        // If we're stuck in ERROR_CYCLE, let it run and diagnose
        if (main_state == 2) begin
            $display("\n!!! STUCK IN ERROR_CYCLE - Running diagnostic for 2 seconds !!!\n");
            #2_000_000_000;
        end else begin
            // Continue through menu
            press_button(2);  // Select coffee
            press_button(2);  // Select drink
            press_button(2);  // Select size
            press_button(2);  // Start brewing
            
            #2_000_000_000;
        end
        
        $display("\n=== FINAL STATE ===");
        $display("  Main State: %0d", main_state);
        $display("  Menu State: %0d", menu_state);
        
        $finish;
    end
endmodule