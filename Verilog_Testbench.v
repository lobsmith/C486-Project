// TESTBENCH FOR VERILOG TRAFFIC CONTROLLER

`timescale 1ns/1ps;

module verilog_controller_tb();
    // 1. DECLARE TESTBENCH SIGNALS
    // inputs must be 'reg' so they can accept values
    reg tb_clk;
    reg tb_reset;
    reg tb_data_in;

    // outputs must be 'wire'
    wire tb_data_out;
    
    // 2. INSTANTIATE DESIGN UNDER TEST (DUT)
    // connect testbench to module ports in Verilog_Traffic_Controller.v
    traffic_controller uut (
        .tb_clk(clk),
        .tb_reset(reset),
        .tb_data_in(data_in),
        .tb_data_out(data_out)
    );
    
    // 3. GENERATE CLOCK SIGNAL FOR SEQUENTIAL DESIGN
    always begin
        #5 tb_clk = ~tb_clk;  // toggles clk every 5ns (matches the 100MHz frequency of Basys 3)
    end

    // 4. APPLY TEST STIMULI
    initial begin
        // initialize inputs
        tb_clk = 0;
        tb_reset = 1;
        tb_data_in = 0;

        // wait 20ns for global reset to settle, then release reset
        #20;
        tb_reset = 0;

        // apply test cases
        #10 tb_data_in = 1;
        #10 tb_data_in = 0;
        #20 tb_data_in = 1;

        // end simulation (50ns)
        #50;
        $finish;
    end
endmodule
