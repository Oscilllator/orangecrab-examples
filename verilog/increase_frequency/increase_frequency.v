/* Copyright 2020 Gregory Davill <greg.davill@gmail.com> */
`default_nettype none


module top (
    input clk48,
    input scl,
    output sda,

    output rgb_led0_r,
    output rgb_led0_g,
    output rgb_led0_b,

    output rst_n,
    input usr_btn
);
    // 8-bit counter for the pwm period.
    reg [63:0] input_counter;
    reg [63:0] period = 48000000;// 1Hz

    // Turn the high side of the switch on
    assign sda = 1;

    reg btn_state = 1'b0;
    always @(posedge clk48)
        if (scl_debounced) begin
            // period <= input_counter;
            period <= period / 2;
            rgb_led0_g <= 0;
            btn_state <= 1'b1;
        end else begin
            rgb_led0_g <= 1;
            btn_state <= 1'b0;
        end

    
    // counter for determining how long the period should be once the
    // user presses the button
    counter_64bit period_counter(
        .clk(clk48),
        .out_value(input_counter),
        .reset(btn_state)
    );

    reg [63:0] output_counter;
    wire period_reset = output_counter > period ? 1 : 0;
    // 50% duty cycle of LED:
    wire led_state = (output_counter > period / 2) ? 1 : 0;
    assign rgb_led0_b = led_state;
    // counter for flashing the LED at the current user saved state.
    counter_64bit period_counter_instantiation(
        .clk(clk48),
        .out_value(output_counter),
        .reset(period_reset)
    );

    wire scl_debounced;
    debounce debounce_input(
        .clk(clk48),
        .in(scl),
        .length(48000),
        .out_(scl_debounced)
    );

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

module debounce (
    input clk,
    input in,
    input[19:0] length,

    output out_
);
    reg[20:0] counter;
    // reg edge_ = 1'b0;
    always @(posedge clk)
        if (in) begin
            // if (~edge_ and counter == 0) begin
            counter <= length;
            if (counter == 0) begin
                out_ <= 1;        
                // edge_ <= 1;
            end else begin
               out_ <= 0; 
            end
        end else begin
            if (counter > 0) begin
                counter <= counter - 1;
            end
        end
endmodule
    // // Assign to inverse cause led is active low
    // assign rgb_led0_b = ~scl;
    // // turn other LED's off:
    // assign rgb_led0_r = 1;
    // assign rgb_led0_g = 1;