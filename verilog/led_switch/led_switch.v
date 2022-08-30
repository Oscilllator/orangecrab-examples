/* Copyright 2020 Gregory Davill <greg.davill@gmail.com> */
`default_nettype none

/*
 *  Blink a LED on the OrangeCrab using verilog
 *  Is able to reset the OrangeCrab by driving rst_n low on btn0 press.
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

    // Turn the high side of the switch on
    assign usr_btn_a = 1;

    // Assign to inverse cause led is active low
    assign rgb_led0_b = ~usr_btn_b;
    // turn other LED's off:
    assign rgb_led0_r = 1;
    assign rgb_led0_g = 1;

    // Reset when the onboard button is pressed
    assign rst_n = usr_btn;


endmodule
