`default_nettype none


/*
C10 - pin 12
C9 - pin 11
*/
module top (
    input clk48,
    input usr_btn_b,

    output usr_btn_a,
    output rgb_led0_r,
    output rgb_led0_g,
    output rgb_led0_b,

    output rst_n,
    input usr_btn
);
    reg in_edge;
    pos_edge input_edge(
        .clk(clk48),
        .in(usr_btn_b),
        .out(in_edge)
    );

    reg [63:0] in_divisor = 1;
    reg [63:0] divisor_state;
    wire in_divider_reset = divisor_state >= in_divisor;
    counter_64bit input_divider(
        .clk(in_edge),
        .out_value(divisor_state),
        .reset(in_divider_reset)
    );
    
    reg divided_edge;
    pos_edge divider_edge(
        .clk(clk48),
        .in(in_divider_reset),
        .out(divided_edge)
    );
    // assign usr_btn_a = divided_edge;

    reg[63:0] pulse_width = 480;
    pulse_stretch stretch_output(
        .clk(clk48),
        .in(divided_edge),
        .length(pulse_width),
        .out_(usr_btn_a)
    );
    

    // reg [63:0] period = 480000;
    // reg[63:0] pulse_width = 4800;
    // reg [63:0] output_counter;
    // wire period_reset = in_edge;
    // // wire led_state = (output_counter > period / 2) ? 1 : 0;
    // wire led_state = (output_counter < pulse_width) ? 1 : 0;
    // assign rgb_led0_b = led_state;
    // // assign usr_btn_a = usr_btn_b ? led_state : 0;
    // assign usr_btn_a = led_state;
    // // counter for flashing the LED at the current user saved state.


    // Reset when the onboard button is pressed
    assign rst_n = usr_btn;
endmodule

module counter_64bit (
    input clk,
    input reset,
    output reg [63:0] out_value
);
    always @(posedge clk)
        if (reset)
            out_value <= 64'b0;
        else
            out_value <= out_value + 1;
endmodule


module pos_edge (
    input clk,
    input in,
    output out
);
    reg prev_state;
    always @(posedge clk) begin
        prev_state <= in;
        if (in && !prev_state) begin
            out <= 1;
        end else begin
            out <= 0;
        end
    end
endmodule

module debounce (
    input clk,
    input in,
    input[32:0] length,

    output out_
);
    reg[33:0] counter;
    always @(posedge clk)
        if (in) begin
            counter <= length;
            if (counter == 0) begin
                out_ <= 1;        
            end else begin
               out_ <= 0; 
            end
        end else begin
            if (counter > 0) begin
                counter <= counter - 1;
            end
        end
endmodule

module pulse_stretch (
    input clk,
    input in,
    input[32:0] length,
    output out_
);
    reg[32:0] counter;
    // assign out_ = counter == 0;
    always @(posedge clk)
        if (in) begin
            counter <= 0;
            out_ <= 1;        
        end else begin
            // counter <= 1;
            if (counter < length) begin
                counter <= counter + 1;
            end else begin
                out_ <= 0;
            end
        end
endmodule

// module pulse_stretch (
//     input clk,
//     input in,
//     input[32:0] length,

//     output out_
// );
//     reg[32:0] counter;
//     always @(posedge clk)
//         // if (in) begin
//         //     out_ <= 0;
//         // end else begin
//         //     out_ <= 1;
//         // end
//         if (in) begin
//             counter <= length;
//             out_ <= 1;        
//         end else begin
//             if (counter > 0) begin
//                 counter <= counter - 1;
//                 out_ <= 1;        
//             end else begin
//                 out_ <= 0;        
//             end
//         end
// endmodule



/*


    // assign rgb_led0_r = ~usr_btn_a;
    assign rgb_led0_r = ~usr_btn_a;
    assign rgb_led0_g = ~usr_btn_b;
    assign rgb_led0_b = 1;


    // reg clk_hz = 48e6;
    // reg pulse_width_s = 10e-6;
    // reg pulse_width = clk_hz * pulse_width_s;
    reg pulse_width = 480;
    reg [63:0] period = 480;

    reg [63:0] output_counter;
    wire period_reset = output_counter > period ? 1 : 0;
    // 50% duty cycle of LED:
    wire led_state = (output_counter > period / 2) ? 1 : 0;
    assign rgb_led0_b = led_state;
    assign usr_btn_a = led_state;
    counter_64bit period_counter_instantiation(
        .clk(clk48),
        .out_value(output_counter),
        .reset(period_reset)
    );

    // wire in_debounced;
    // debounce debounce_input(
    //     .clk(clk48),
    //     .in(usr_btn_b),
    //     .length(128),
    //     .out_(usr_btn_a)
    // );

    // pulse_stretch stretch_output(
    //     .clk(clk48),
    //     .in(usr_btn_b),
    //     .length(pulse_width),
    //     .out_(usr_btn_a)
    // );
*/