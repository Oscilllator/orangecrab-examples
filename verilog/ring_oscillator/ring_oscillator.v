/* Copyright 2020 Gregory Davill <greg.davill@gmail.com> */
`default_nettype none


module top (
    input clk48,

    output rgb_led0_r,
    output rgb_led0_g,
    output rgb_led0_b,
    output usr_btn_a,
    output usr_btn_b,

    output rst_n,
    input usr_btn
);
    assign usr_btn_b = 0;

    wire  c1 = ~c2;
    wire c2 = ~c3;
    wire c3 = ~c1;

    // Reset when the onboard button is pressed
    assign rst_n = usr_btn;

    // assign rgb_led0_r = 0;
    div_32bit output_divider3(
        .clk(clk48),
        .div(1 << 25),
        .out(rgb_led0_b));

    wire ringout;
    // ringoscillator #(DELAY_LUTS=1) osc (ringout)
    ringoscillator  osc (ringout);
    div_32bit output_divider(
        .clk(ringout),
        .div(1000),
        .out(rgb_led0_r));

endmodule

module div_32bit (
    input clk,
    input[31:0] div,
    output reg out
);
    reg [31:0] counter = 0;
    always @(posedge clk)
        if (counter >= div) begin
            counter <= 0;
            out = ~out;
        end else begin
            counter <= counter + 1;
        end
endmodule

// Taken from:
// https://github.com/DurandA/verilog-buildingblocks/issues/1
// Ring oscillator.
//
// Avoid using zero delay LUTs. Zero delay LUTs may be unstable
// and also results in extremely high frequencies at very low amplitudes.
// E.g. on the ice40hx1k, this results in a ~650MHz signal,
// but so weak that other logic will not properly pick it up.
// When connecting it to an output pin, the signal has -25dBm.
module ringoscillator(output wire chain_out);
	parameter DELAY_LUTS = 1;

	wire chain_wire[DELAY_LUTS+1:0];
	assign chain_wire[0] = chain_wire[DELAY_LUTS+1];
	assign chain_out = chain_wire[1];
	// inverter is at [0], so [1] comes freshly from the inverter.
	// if that matters.

	generate
		genvar i;
		for(i=0; i<=DELAY_LUTS; i=i+1) begin: delayline
			(* keep *) (* noglobal *)
			TRELLIS_SLICE #(.LUT0_INITVAL((i==0)?16'd1:16'd2))
				chain_lut(.F0(chain_wire[i+1]), .A0(chain_wire[i]), .B0(0), .C0(0), .D0(0));
		end
	endgenerate
	
endmodule

// module top(input CLK, output J1_10, LED0, LED1, LED2, LED3, LED4);
// 	wire chain_in, chain_out, resetn;
// 	assign J1_10 = chain_out;

// 	// reset generator

// 	reg [7:0] reset_count = 0;
// 	assign resetn = &reset_count;

// 	always @(posedge CLK) begin
// 		if (!(&reset_count))
// 			reset_count <= reset_count + 1;
// 	end

// 	// ring oscillator

// 	wire [99:0] buffers_in, buffers_out;
// 	assign buffers_in = {buffers_out[98:0], chain_in};
// 	assign chain_out = buffers_out[99];
// 	assign chain_in = resetn ? !chain_out : 0;

// 	SB_LUT4 #(
// 		.LUT_INIT(16'd2)
// 	) buffers [99:0] (
// 		.O(buffers_out),
// 		.I0(buffers_in),
// 		.I1(1'b0),
// 		.I2(1'b0),
// 		.I3(1'b0)
// 	);

// 	// frequency counter

// 	reg [19:0] counter = 23;
// 	reg do_count, do_reset;
// 	always @(posedge chain_out) begin
// 		if (do_reset)
// 			counter <= 0;
// 		else if (do_count)
// 			counter <= counter + 1;
// 	end

// 	// control

// 	reg [1:0] state;
// 	reg [15:0] wait_cnt;
// 	reg [19:0] last_counter;
// 	reg [19:0] this_counter;
// 	reg [2:0] debounce;
// 	reg [4:0] leds;

// 	assign {LED4, LED3, LED2, LED1, LED0} = leds;

// 	always @(posedge CLK) begin
// 		wait_cnt <= wait_cnt + 1;
// 		do_reset <= state == 0;
// 		do_count <= state == 1;

// 		if (!resetn) begin
// 			state <= 0;
// 			wait_cnt <= 0;
// 			leds <= 1;
// 		end else
// 		if (&wait_cnt) begin
// 			if (state == 2) begin
// 				last_counter <= this_counter;
// 				this_counter <= counter;
// 			end
// 			if (state == 3) begin
// 				if (last_counter > this_counter+5) begin
// 					if (!debounce)
// 						leds <= {1'b1, leds[0], leds[3:1]};
// 					debounce <= ~0;
// 				end else begin
// 					if (debounce)
// 						debounce <= debounce-1;
// 					else
// 						leds[4] <= 0;
// 				end
// 			end
// 			state <= state + 1;
// 		end
// 	end
// endmodule