//============================================================================
// Module: message_manager
// Description: Updated LCD message generation with maintenance menu support
//              Displays maintenance options, service timer, and error lists
// Author: Gabriel DiMartino
// Date: November 2025
//============================================================================

`timescale 1ns/1ps

module message_manager (
    input  wire         clk,
    input  wire         rst_n,
    
    // Menu state
    input  wire [3:0]   current_menu_state,
    input  wire [2:0]   selected_coffee_type,
    input  wire [2:0]   selected_drink_type,
    input  wire [1:0]   selected_size,
    input  wire [1:0]   selected_maint_option,
    
    // System status
    input  wire [7:0]   brew_progress,
    input  wire [3:0]   warning_count,
    input  wire [3:0]   error_count,
    input  wire         error_present,
    input  wire         can_make_coffee,

    
    // Service timer
    input  wire [31:0]  hours_since_service,
    input  wire [31:0]  days_since_service,
    
    // Consumable status
    input  wire         bin0_empty,
    input  wire         bin0_low,
    input  wire         bin1_empty,
    input  wire         bin1_low,
    input  wire         creamer_empty,
    input  wire         creamer_low,
    input  wire         chocolate_empty,
    input  wire         chocolate_low,
    input  wire         paper_empty,
    input  wire         paper_low,
    
    // Water system
    input  wire         temp_ready,
    input  wire         pressure_ready,
    
    // LCD output
    output reg [127:0]  line1_text,
    output reg [127:0]  line2_text,
    output reg          message_updated
);

    // Menu states (FIXED: Match corrected FSM parameters)
    parameter STATE_SPLASH = 4'd0;
    parameter STATE_CHECK_ERRORS = 4'd1;
    parameter STATE_COFFEE_SELECT = 4'd2;
    parameter STATE_DRINK_SELECT = 4'd3;
    parameter STATE_SIZE_SELECT = 4'd4;
    parameter STATE_CONFIRM = 4'd5;
    parameter STATE_BREWING = 4'd6;
    parameter STATE_COMPLETE = 4'd7;
    parameter STATE_SETTINGS = 4'd8;
    parameter STATE_ERROR = 4'd9;
    parameter STATE_INSUFFICIENT = 4'd10;
    
    // Abort confirmation state (FIXED: was 4'd16)
    parameter STATE_ABORT_CONFIRM = 4'd11;
    
    // Maintenance states
    parameter STATE_MAINTENANCE = 4'd12;
    parameter STATE_MAINT_OPTIONS = 4'd13;
    parameter STATE_MAINT_VIEW_ERRORS = 4'd14;
    parameter STATE_MAINT_MANUAL_CHECK = 4'd15;
    
    // Drink types
    parameter DRINK_BLACK_COFFEE = 3'd0;
    parameter DRINK_COFFEE_CREAM = 3'd1;
    parameter DRINK_LATTE = 3'd2;
    parameter DRINK_MOCHA = 3'd3;
    parameter DRINK_HOT_CHOCOLATE = 3'd4;
    
    // Sizes
    parameter SIZE_8OZ = 2'd0;
    parameter SIZE_12OZ = 2'd1;
    parameter SIZE_16OZ = 2'd2;
    
    // Coffee bins
    parameter COFFEE_BIN0 = 3'd0;
    parameter COFFEE_BIN1 = 3'd1;
    
    // Maintenance options
    parameter MAINT_VIEW_ERRORS = 2'd0;
    parameter MAINT_MANUAL_CHECK = 2'd1;
    parameter MAINT_SERVICE_TIME = 2'd2;
    parameter MAINT_EXIT = 2'd3;
    
    reg [127:0] line1_text_next;
    reg [127:0] line2_text_next;
    reg [3:0] prev_menu_state;
    
    // Helper function to create LCD string
    function automatic [127:0] lcd_str;
        input string s;
        int i;
        byte unsigned c;
        begin
            lcd_str = {16{8'h20}};  // Fill with spaces
            for (i = 0; i < 16 && i < s.len(); i++) begin
                c = s[i];
                lcd_str[127-(i*8) -: 8] = c;
            end
        end
    endfunction
    
    // Number to ASCII
    function automatic [7:0] num_to_ascii;
        input integer num;
        begin
            if (num >= 0 && num <= 9)
                num_to_ascii = 8'h30 + num[7:0];
            else
                num_to_ascii = 8'h20;
        end
    endfunction
    
    // Progress bar generator
    function automatic [127:0] progress_bar;
        input [7:0] progress;
        integer filled;
        integer i;
        reg [127:0] result;
        begin
            filled = (progress * 16) / 100;
            if (filled > 16) filled = 16;
            
            result = {16{8'h2D}};
            
            for (i = 0; i < 16; i = i + 1) begin
                if (i < filled) begin
                    result[(127 - i*8) -: 8] = 8'h23;  // '#'
                end else begin
                    result[(127 - i*8) -: 8] = 8'h2D;  // '-'
                end
            end
            
            progress_bar = result;
        end
    endfunction
    
    // Format service time as string
    function automatic [127:0] format_service_time;
        input [31:0] days;
        input [31:0] hours;
        reg [7:0] d_tens, d_ones, h_tens, h_ones;
        reg [127:0] result;
        begin
            result = {16{8'h20}};  // Initialize with spaces
            
            if (days > 99) begin
                // Too many days - show "99+ days"
                result = lcd_str("99+ days");
            end else if (days > 0) begin
                // Show days and hours: "XXd YYh"
                d_tens = num_to_ascii((days / 10) % 10);
                d_ones = num_to_ascii(days % 10);
                h_tens = num_to_ascii((hours / 10) % 10);
                h_ones = num_to_ascii(hours % 10);
                
                // Format: "XXd YYh"
                result[127:120] = d_tens;
                result[119:112] = d_ones;
                result[111:104] = 8'h64;  // 'd'
                result[103:96]  = 8'h20;  // ' '
                result[95:88]   = h_tens;
                result[87:80]   = h_ones;
                result[79:72]   = 8'h68;  // 'h'
                result[71:0]    = {9{8'h20}};  // spaces
            end else begin
                // Show hours and minutes: "XXh YYm"
                h_tens = num_to_ascii((hours / 10) % 10);
                h_ones = num_to_ascii(hours % 10);
                
                // Format: "XXh"
                result[127:120] = h_tens;
                result[119:112] = h_ones;
                result[111:104] = 8'h68;  // 'h'
                result[103:0]   = {13{8'h20}};  // spaces
            end
            
            format_service_time = result;
        end
    endfunction
    
    //========================================================================
    // Message Generation Logic
    //========================================================================
    
    always @(*) begin
        line1_text_next = lcd_str("");
        line2_text_next = lcd_str("");
        
        case (current_menu_state)
            
            STATE_SPLASH: begin
                if (error_present || warning_count > 0) begin
                    line1_text_next = lcd_str("Coffee Machine");
                    // Show counts
                    line2_text_next = lcd_str("W:X E:Y Press->"); 
                    // Format warning/error counts
                    line2_text_next[103:96] = num_to_ascii(warning_count);
                    line2_text_next[79:72] = num_to_ascii(error_count);
                end else begin
                    line1_text_next = lcd_str("Coffee Machine");
                    line2_text_next = lcd_str("Press Start");
                end
            end
            
            STATE_CHECK_ERRORS: begin
                if (paper_empty) begin
                    line1_text_next = lcd_str("Not Enough:");
                    line2_text_next = lcd_str("Paper Filter!");
                end else if (!can_make_coffee) begin
                    line1_text_next = lcd_str("Not Enough:");
                    line2_text_next = lcd_str("Coffee!");
                end else if (creamer_empty) begin
                    line1_text_next = lcd_str("Not Enough:");
                    line2_text_next = lcd_str("Creamer!");
                end else if (chocolate_empty) begin
                    line1_text_next = lcd_str("Not Enough:");
                    line2_text_next = lcd_str("Chocolate!");
                end else if (!pressure_ready) begin
                    line1_text_next = lcd_str("Water System");
                    line2_text_next = lcd_str("Pressure Error!");
                end else begin
                    line1_text_next = lcd_str("Checking...");
                    line2_text_next = lcd_str("Please wait");
                end
            end
            
            STATE_COFFEE_SELECT: begin
                if (selected_coffee_type == 0) begin
                    line1_text_next = lcd_str("Coffee Bin: [1]");
                    if (bin0_empty) begin
                        line2_text_next = lcd_str("EMPTY! Try Bin2");
                    end else if (bin0_low) begin
                        line2_text_next = lcd_str("LOW <-> Select");
                    end else begin
                        line2_text_next = lcd_str("<-> Select");
                    end
                end else begin
                    line1_text_next = lcd_str("Coffee Bin: [2]");
                    if (bin1_empty) begin
                        line2_text_next = lcd_str("EMPTY! Try Bin1");
                    end else if (bin1_low) begin
                        line2_text_next = lcd_str("LOW <-> Select");
                    end else begin
                        line2_text_next = lcd_str("<-> Select");
                    end
                end
            end
            
            STATE_DRINK_SELECT: begin
                case (selected_drink_type)
                    DRINK_BLACK_COFFEE: line1_text_next = lcd_str("Drink: [Black]");
                    DRINK_COFFEE_CREAM: line1_text_next = lcd_str("Drink: [Cream]");
                    DRINK_LATTE:        line1_text_next = lcd_str("Drink: [Latte]");
                    DRINK_MOCHA:        line1_text_next = lcd_str("Drink: [Mocha]");
                    DRINK_HOT_CHOCOLATE:line1_text_next = lcd_str("Drink:[HotChoco]");
                    default:            line1_text_next = lcd_str("Drink: ?");
                endcase
                line2_text_next = lcd_str("<-> Select");
            end
            
            STATE_SIZE_SELECT: begin
                case (selected_size)
                    SIZE_8OZ:  line1_text_next = lcd_str("Size: [8oz]");
                    SIZE_12OZ: line1_text_next = lcd_str("Size: [12oz]");
                    SIZE_16OZ: line1_text_next = lcd_str("Size: [16oz]");
                    default:   line1_text_next = lcd_str("Size: ?");
                endcase
                line2_text_next = lcd_str("<-> Select");
            end
            
            STATE_CONFIRM: begin
                case (selected_drink_type)
                    DRINK_BLACK_COFFEE: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("Black Coffee 8z");
                            SIZE_12OZ: line1_text_next = lcd_str("Black Coffee12z");
                            SIZE_16OZ: line1_text_next = lcd_str("Black Coffee16z");
                        endcase
                    end
                    DRINK_COFFEE_CREAM: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("Coffee+Cream 8z");
                            SIZE_12OZ: line1_text_next = lcd_str("Coffee+Cream12z");
                            SIZE_16OZ: line1_text_next = lcd_str("Coffee+Cream16z");
                        endcase
                    end
                    DRINK_LATTE: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("Latte 8oz");
                            SIZE_12OZ: line1_text_next = lcd_str("Latte 12oz");
                            SIZE_16OZ: line1_text_next = lcd_str("Latte 16oz");
                        endcase
                    end
                    DRINK_MOCHA: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("Mocha 8oz");
                            SIZE_12OZ: line1_text_next = lcd_str("Mocha 12oz");
                            SIZE_16OZ: line1_text_next = lcd_str("Mocha 16oz");
                        endcase
                    end
                    DRINK_HOT_CHOCOLATE: begin
                        case (selected_size)
                            SIZE_8OZ:  line1_text_next = lcd_str("Hot Choco 8oz");
                            SIZE_12OZ: line1_text_next = lcd_str("Hot Choco 12oz");
                            SIZE_16OZ: line1_text_next = lcd_str("Hot Choco 16oz");
                        endcase
                    end
                endcase
                line2_text_next = lcd_str("Start? Cancel?");
            end
            
            STATE_INSUFFICIENT: begin
                line1_text_next = lcd_str("Not Enough:");
                if (bin0_empty && selected_coffee_type == COFFEE_BIN0) begin
                    line2_text_next = lcd_str("Bin 0 Coffee!");
                end else if (bin1_empty && selected_coffee_type == COFFEE_BIN1) begin
                    line2_text_next = lcd_str("Bin 1 Coffee!");
                end else if (creamer_empty) begin
                    line2_text_next = lcd_str("Creamer!");
                end else if (chocolate_empty) begin
                    line2_text_next = lcd_str("Chocolate!");
                end else if (paper_empty) begin
                    line2_text_next = lcd_str("Paper Filter!");
                end else begin
                    line2_text_next = lcd_str("Ingredients!");
                end
            end
            
            STATE_BREWING: begin
                if (!temp_ready) begin
                    // Still heating before brewing can start
                    line1_text_next = lcd_str("Heating Water...");
                    line2_text_next = lcd_str("Please Wait");
                end else begin
                    // Actually brewing
                    line1_text_next = lcd_str("Brewing...");
                    line2_text_next = progress_bar(brew_progress);
                end
            end
            
            STATE_COMPLETE: begin
                line1_text_next = lcd_str("Enjoy Your");
                line2_text_next = lcd_str("Beverage!");
            end
            
            STATE_SETTINGS: begin
                line1_text_next = lcd_str("Settings Mode");
                line2_text_next = lcd_str("Cancel to exit");
            end
            
            STATE_ERROR: begin
                if (!pressure_ready) begin
                    line1_text_next = lcd_str("ERR: No Water");
                    line2_text_next = lcd_str("Check Pressure!");
                end else if (paper_empty) begin
                    line1_text_next = lcd_str("ERR: No Paper");
                    line2_text_next = lcd_str("Refill Filter!");
                end else if (bin0_empty && bin1_empty) begin
                    line1_text_next = lcd_str("ERR: No Coffee");
                    line2_text_next = lcd_str("Refill Bins!");
                end else begin
                    line1_text_next = lcd_str("SYSTEM ERROR");
                    line2_text_next = lcd_str("Press Cancel");
                end
            end
            
            // ============ ABORT CONFIRMATION (NEW) ============
            
            STATE_ABORT_CONFIRM: begin
                line1_text_next = lcd_str("Abort Brewing?");
                line2_text_next = lcd_str("Start=Yes Can=No");
            end
            
            // ============ MAINTENANCE MENU MESSAGES ============
            
            STATE_MAINTENANCE: begin
                line1_text_next = lcd_str("Entering");
                line2_text_next = lcd_str("Maintenance...");
            end
            
            STATE_MAINT_OPTIONS: begin
                line1_text_next = lcd_str("Maintenance Menu");
                case (selected_maint_option)
                    MAINT_VIEW_ERRORS:   line2_text_next = lcd_str("[View Errors]<->");
                    MAINT_MANUAL_CHECK:  line2_text_next = lcd_str("[Manual Check]<>");
                    MAINT_SERVICE_TIME:  line2_text_next = lcd_str("[Service Time]<>");
                    MAINT_EXIT:          line2_text_next = lcd_str("[Exit]<->");
                    default:             line2_text_next = lcd_str("<- Options ->");
                endcase
            end
            
            STATE_MAINT_VIEW_ERRORS: begin
                // UPDATED: Handle both view errors AND service time display
                // Check if we're viewing service time (selected_maint_option == MAINT_SERVICE_TIME)
                if (selected_maint_option == MAINT_SERVICE_TIME) begin
                    // Display service timer
                    line1_text_next = lcd_str("Time Since Srvc");
                    line2_text_next = format_service_time(days_since_service, 
                                                         hours_since_service);
                end else begin
                    // Display errors/warnings
                    if (error_present || warning_count > 0) begin
                        line1_text_next = lcd_str("Active Issues:");
                        if (error_present) begin
                            line2_text_next = lcd_str("See Error Cycle");
                        end else begin
                            line2_text_next = lcd_str("See Warnings");
                        end
                    end else begin
                        line1_text_next = lcd_str("No Active");
                        line2_text_next = lcd_str("Errors/Warnings");
                    end
                end
            end
            
            STATE_MAINT_MANUAL_CHECK: begin
                line1_text_next = lcd_str("Manual Check?");
                line2_text_next = lcd_str("Start=Y Back=N");
            end
            
            default: begin
                line1_text_next = lcd_str("System Error");
                line2_text_next = lcd_str("Unknown State");
            end
            
        endcase
    end
    
    // Register outputs and detect changes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line1_text <= lcd_str("");
            line2_text <= lcd_str("");
            prev_menu_state <= STATE_SPLASH;
            message_updated <= 1'b0;
        end else begin
            line1_text <= line1_text_next;
            line2_text <= line2_text_next;
            prev_menu_state <= current_menu_state;
            
            message_updated <= (line1_text != line1_text_next) || 
                             (line2_text != line2_text_next);
        end
    end

endmodule