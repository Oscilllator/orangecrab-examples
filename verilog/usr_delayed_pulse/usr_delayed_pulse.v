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
    wire pulse_out = gpio_13;
    wire usr_knob_drv = sda;
    wire usr_knob_meas = gpio_12;

    reg [63:0] usr_knob_period; 
    usr_knob usr_knob_instance(
        .clk(clk48),
        .gpio_drv(usr_knob_drv),
        .gpio_meas(usr_knob_meas),
        .period_out(usr_knob_period),
        .state_(rgb_led0_b)
    );
    assign led_strobe = rgb_led0_b;

    reg [63:0] wave_generated;
    wire wave_reference = wave_generated >= (usr_knob_period * 2);
    counter_64bit rate_generator(
        .clk(clk48),
        .out_value(wave_generated),
        .reset(wave_reference)
    );
    assign pulse_out = wave_reference;

    // reg in_edge;
    // pos_edge input_edge(
    //     .clk(clk48),
    //     .in(wave_reference),
    //     .out(in_edge)
    // );

    // reg [63:0] out_delay_state;
    // wire out_delayed = out_delay_state == usr_knob_period;
    // counter_64bit led_pulse_delay( // 64 bit => never overflows :)
    //     .clk(clk48),
    //     .out_value(out_delay_state),
    //     .reset(out_delayed)
    // );
    // reg out_delayed_stretched;
    // reg[63:0] out_pulse_width = 2400;
    // pulse_stretch stretch_flash(
    //     .clk(clk48),
    //     .in(out_delayed),
    //     .length(out_pulse_width),
    //     .out_(out_delayed_stretched)
    // );
    // // assign led_strobe = out_delayed_stretched;

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

module usr_knob (
    input clk,
    inout gpio_drv,
    inout gpio_meas,
    output reg [63:0] period_out,
    output reg state_
);
    parameter MEASURING = 1'b0;
    parameter DISCHARGING = 1'b1;
    reg [1:0] state;
    reg [63:0] period_meas;
    assign state_ = state;

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
