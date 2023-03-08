`default_nettype none


/*
C10 - pin 12
C9 - pin 11
*/
module top (
    input clk48,
    input gpio_1,

    inout sda,
    inout gpio_12,

    output gpio_0,
    output gpio_13,
    output rgb_led0_r,
    output rgb_led0_g,
    output rgb_led0_b,

    output rst_n,
    input usr_btn
);
    wire led_strobe = gpio_0;
    wire in_pulse = gpio_1;
    wire camera_pulse_out = gpio_13;


    // input is a long pulse from the laser, make is a 1 cycle pulse.
    reg in_edge;
    pos_edge input_edge(
        .clk(clk48),
        .in(in_pulse),
        .out(in_edge)
    );


    // Propeller has more than one blade and we want to trigger on the same
    // one each time.
    reg [63:0] in_divisor = 1;
    reg [63:0] divisor_state;
    wire in_divider_reset = divisor_state >= in_divisor;
    counter_64bit input_divider(
        .clk(in_edge),
        .out_value(divisor_state),
        .reset(in_divider_reset)
    );

    // the above module produces a 50% duty cycle wave, make it a pulse:
    reg divided_edge;
    pos_edge divider_edge(
        .clk(clk48),
        .in(in_divider_reset),
        .out(divided_edge)
    );

    reg [63:0] usr_knob_delay; 
    usr_knob usr_knob_instance(
        .clk(clk48),
        .gpio_drv(sda),
        .gpio_meas(gpio_12),
        .period_out(usr_knob_delay),
    );
    reg [63:0] led_pulse_delay_state;
    wire led_strobe_delayed = led_pulse_delay_state == usr_knob_delay;
    counter_64bit led_pulse_delay( // 64 bit => never overflows :)
        .clk(clk48),
        .out_value(led_pulse_delay_state),
        .reset(divided_edge)
    );

    // we want to trigger the flash as often as possible. That way
    // we won't be triggering any seizures with a 24Hz rate.
    // reg[63:0] led_pulse_width = 240;
    reg[63:0] led_pulse_width = 2400;
    pulse_stretch stretch_flash(
        .clk(clk48),
        .in(led_strobe_delayed),
        .length(led_pulse_width),
        .out_(led_strobe)
    );
    // assign led_strobe = divided_edge;

    // Produce a reference wave at the nominal camera frame rate.
    // Stuff for camera_sync
    reg [63:0] camera_hz = 30;
    reg [63:0] camera_period_clk48 = 48000000 / camera_hz;
    reg [63:0] camera_rate_state;
    wire camera_wave_reference = camera_rate_state >= camera_period_clk48;
    counter_64bit camera_rate_generator(
        .clk(clk48),
        .out_value(camera_rate_state),
        .reset(camera_wave_reference)
    );

    // produce a pulse at the same time as divided edge but occurring at the
    // same rate as camera_hz
    reg camera_wave_locked;
    phase_lock phase_lock_camera(
        .clk(clk48),
        .in_reset(camera_wave_reference),
        .in(divided_edge),
        .out(camera_wave_locked)
    );



    reg[63:0] camera_pulse_width = 2400;
    pulse_stretch stretch_camera_rate(
        .clk(clk48),
        .in(camera_wave_locked),
        .length(camera_pulse_width),
        .out_(camera_pulse_out)
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


module pos_edge (
    input clk,
    input in,
    output out
);
    reg prev_state;
    always @(posedge clk) begin
        if (in && !prev_state) begin
            out <= 1;
        end else begin
            out <= 0;
        end
        prev_state <= in;
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
    input[63:0] length,
    output out_
);
    reg[63:0] counter;
    always @(posedge clk)
        if (in) begin
            counter <= 0;
            out_ <= 1;        
        end else begin
            if (counter < length) begin
                counter <= counter + 1;
            end else begin
                out_ <= 0;
            end
        end
endmodule

module phase_lock (
    input clk,
    input in_reset,
    input in,
    output out
);
    reg edge_allowed = 0;
    always @(posedge clk) begin
        if (in_reset)
            edge_allowed <= 1;
        if (in && edge_allowed) begin
            out <= 1;
            edge_allowed <= 0;
        end else begin
            out <= 0;
        end
    end
endmodule

// module delay(
//     input clk
//     input reg[63:0] length,
//     input in,
//     output out
// );
//     reg[63:0] state;
//     reg pulsed;
//     always @(posedge clk) begin
//         if (in) begin
//             state <= length;
//             pulsed <= 0;
//         end else if (!pulsed) begin
//             state <= state + 1;
//         end
//         if (state == length) begin
//             pulsed < 
//         end
//     end
// endmodule

module usr_knob (
    input clk,
    inout gpio_drv,
    inout gpio_meas,
    output reg [63:0] period_out,
);
    parameter MEASURING = 1'b0;
    parameter DISCHARGING = 1'b1;
    reg [1:0] state;
    reg [63:0] period_meas;

    assign gpio_meas = (state == MEASURING) ? 1'bz      : 1'b0;
    wire in_meas = (state == MEASURING)     ? gpio_meas : 1'b0;
    assign gpio_drv = (state == MEASURING)  ? 1'b1      : 1'bz;
    wire in_drv = (state == MEASURING)      ? 1'b1      : gpio_drv;

    always @(posedge clk) begin
        case(state)
            MEASURING: begin
                if (in_meas) begin
                    period_meas <= 0;
                    period_out <= period_meas;
                    state <= DISCHARGING;
                end else begin
                    period_meas <= period_meas + 1;
                end
            end
            DISCHARGING: begin
                // Once the capacitor has been discharged we reset the state:
                if (!in_drv) begin
                    state <= MEASURING;
                end
            end
        endcase
    end
endmodule
