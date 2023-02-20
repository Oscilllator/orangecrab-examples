/* Copyright 2020 Gregory Davill <greg.davill@gmail.com> */
`default_nettype none


module top (
    input clk48,
    input usr_btn_a,

    output out,
    input usr_btn
);
    // 8-bit counter for the pwm period.
    reg [63:0] input_counter;
    reg [63:0] period = 48000000;// 1Hz

    reg clk_hz = 48e6;
    reg pulse_width_s = 10e-6;
    reg pulse_width = clk_hz * pulse_width_s;

    wire in_debounced;
    debounce debounce_input(
        .clk(clk48),
        .in(usr_btn_a),
        .length(128),
        .out_(in_debounced)
    );
    pulse_stretch stretch_output(
        .clk(clk48),
        .in(in_debounced),
        .length(pulse_width),
        .out_(out)
    );

    // Reset when the onboard button is pressed
    assign rst_n = usr_btn;

endmodule

module debounce (
    input clk,
    input in,
    input[19:0] length,

    output out_
);
    reg[20:0] counter;
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
    input[19:0] length,

    output out_
);
    reg[20:0] counter;
    always @(posedge clk)
        if (in) begin
            counter <= length;
            out_ <= 1;        
        end else begin
            if (counter > 0) begin
                counter <= counter - 1;
                out_ <= 1;        
            end else begin
                out_ <= 0;        
            end
        end
endmodule