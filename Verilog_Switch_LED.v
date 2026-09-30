// port declaration section
module switch_led(
    input  wire [3:0] sw,              // 4 switch inputs
    output wire [3:0] led              // 4 LED outputs
);

    // connect AND, OR, NOT gates to LEDs
    assign led[0] = sw[0] & sw[1];     // AND gate - connect to LED 0
    assign led[1] = sw[0] | sw[1];     // OR gate - connect to LED 1
    assign led[2] = ~sw[2];            // inverter - connect to LED 2
    assign led[3] = sw[2] & ~sw[3];    // AND gate with inverted input -
                                       // connect to LED 3
endmodule
