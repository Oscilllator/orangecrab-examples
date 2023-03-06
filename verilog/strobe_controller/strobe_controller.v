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

    reg [63:0] delay; 
    usr_knob usr_knob_instance(
        .clk(clk48),
        .gpio_drv(sda),
        .gpio_meas(gpio_12),
        .period_out(delay),
    );

    // Stuff for camera_sync
    reg [63:0] delay_counter;
    wire camera_rate = delay_counter >= delay;
    counter_64bit camera_rate_generator(
        .clk(clk48),
        .out_value(delay_counter),
        .reset(camera_rate)
    );
    assign gpio_1 = camera_rate;
    assign gpio_13 = gpio_12;

  
    // assign gpio_13 = gpio_1;
    // reg in_edge;
    // pos_edge input_edge(
    //     .clk(clk48),
    //     .in(gpio_1),
    //     .out(in_edge)
    // );

    // reg [63:0] in_divisor = 1;
    // reg [63:0] divisor_state;
    // wire in_divider_reset = divisor_state >= in_divisor;
    // counter_64bit input_divider(
    //     .clk(in_edge),
    //     .out_value(divisor_state),
    //     .reset(in_divider_reset)
    // );
    
    // reg divided_edge;
    // pos_edge divider_edge(
    //     .clk(clk48),
    //     .in(in_divider_reset),
    //     .out(divided_edge)
    // );

    // // Stuff for camera_sync
    // reg [63:0] camera_hz = 60;
    // reg [63:0] camera_period_clk48 = 48000000 / camera_hz;
    // reg [63:0] camera_rate_state;
    // wire camera_rate = camera_rate_state >= camera_period_clk48;
    // counter_64bit camera_rate_generator(
    //     .clk(clk48),
    //     .out_value(camera_rate_state),
    //     .reset(camera_rate)
    // );

    // reg strobe_camera_locked;
    // phase_lock phase_lock_camera(
    //     .clk(clk48),
    //     .in_reset(camera_rate),
    //     .in(divided_edge),
    //     .out(strobe_camera_locked)
    // );

    // reg[63:0] pulse_width = 2400;
    // pulse_stretch stretch_camera_rate(
    //     .clk(clk48),
    //     .in(strobe_camera_locked),
    //     .length(pulse_width),
    //     .out_(gpio_13)
    // );
    // // assign gpio_13 = camera_rate

    // reg[63:0] pulse_width = 240;
    // pulse_stretch stretch_output(
    //     .clk(clk48),
    //     .in(strobe_camera_locked),
    //     .length(pulse_width),
    //     .out_(gpio_0)
    // );

    // assign gpio_0  = gpio_1;


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


    // assign rgb_led0_r = ~gpio_0;
    assign rgb_led0_r = ~gpio_0;
    assign rgb_led0_g = ~gpio_1;
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
    assign gpio_0 = led_state;
    counter_64bit period_counter_instantiation(
        .clk(clk48),
        .out_value(output_counter),
        .reset(period_reset)
    );

    // wire in_debounced;
    // debounce debounce_input(
    //     .clk(clk48),
    //     .in(gpio_1),
    //     .length(128),
    //     .out_(gpio_0)
    // );

    // pulse_stretch stretch_output(
    //     .clk(clk48),
    //     .in(gpio_1),
    //     .length(pulse_width),
    //     .out_(gpio_0)
    // );
*/

    // always @(posedge in_reset) begin
    //     edge_allowed <= 1;
    //     // Potential problem: in is positive here.
    // end
    // always @(negedge in) begin
    //     edge_allowed <= 0;
    // end
    // assign out = edge_allowed && in;