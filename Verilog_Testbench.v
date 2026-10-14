// TESTBENCH FOR VERILOG TRAFFIC CONTROLLER

`timescale 1ns/1ps;

module verilog_controller_tb();
    /************************************** 1. DECLARE TESTBENCH SIGNALS ***************************************/
    
    // inputs must be 'reg' so they can accept values
    reg  tb_clk;
    reg  tb_reset;
    reg  tb_blue_north;
    reg  tb_blue_south;
    reg  tb_purple_east;
    reg  tb_purple_west;

    // outputs must be 'wire'
    wire tb_blue_green;
    wire tb_blue_yellow;
    wire tb_blue_red;
    wire tb_purple_green;
    wire tb_purple_yellow;
    wire tb_purple_red;
    wire tb_blue_waiting;
    wire tb_purple_waiting;

    /******************************** 2. INSTANTIATE DESIGN UNDER TEST (DUT) ***********************************/
    
    // connect testbench to module ports in Verilog_Traffic_Controller.v
    // SYNTAX: .DUT_port_name(testbench_signal_name)
    traffic_controller uut (
        // INPUTS: clock signals
        .clk(tb_clk),
        .reset(tb_reset),

        // INPUTS: Hall sensors
        .blue_sensor_north(tb_blue_north),
        .blue_sensor_south(tb_blue_south),
        .purple_sensor_east(tb_purple_east),
        .purple_sensor_west(tb_purple_west),
        
        // OUTPUTS: traffic lights
        .blue_green(tb_blue_green),
        .blue_yellow(tb_blue_yellow),
        .blue_red(tb_blue_red),
        .purple_green(tb_purple_green),
        .purple_yellow(tb_purple_yellow),
        .purple_red(tb_purple_red),

        // OUTPUTS: waiting indicators
        .blue_waiting(tb_blue_waiting),
        .purple_waiting(tb_purple_waiting),
    );

    /**************************** 3. GENERATE CLOCK SIGNAL FOR SEQUENTIAL DESIGN *******************************/

    // toggles clk every 5ns (10ns per cycle, matches the 100MHz frequency of Basys 3)
    always begin
        #5 tb_clk = ~tb_clk;
    end

    /****************************************** 4. APPLY TEST CASES ********************************************/
    
    initial begin
        // initialize inputs
        tb_clk = 0;
        tb_reset = 1;
        tb_blue_north = 0;
        tb_blue_south = 0;
        tb_purple_east = 0;
        tb_purple_west = 0;

        // wait 20ns for global reset to settle, then release reset
        #20;
        tb_reset = 0;

        /********************************** TEST 1: START-UP **************************************/
        
        // observe transition from ALL_RED_TO_BLUE to BLUE_GREEN
        // give the clock time to operate
        #10;

        // IF Blue Street is green and Purple Street is red, start-up test is successful
        if (tb_blue_green == 1'b1 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 1 PASSED: Start-up transitioned to BLUE_GREEN.");

        // OTHERWISE, start-up test is unsuccessful
        else
            $display("TEST 1 FAILED: Unexpected traffic light outputs at start-up.");

        /******************************* TEST 2: NORMAL OPERATION *********************************/
        /*********** same condition is tested, except under normal operating conditions ***********/
        
        // DEFAULT: no vehicles detected (already set)

        // give the clock time to operate
        #100;

        // IF Blue Street is green and Purple Street is red, normal operation test is successful
        if (tb_blue_green == 1'b1 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 2 PASSED: Normal operation with no vehicles.");

        // OTHERWISE, normal operation test is unsuccessful
        else
            $display("TEST 2 FAILED: Unexpected traffic light outputs during normal operation.");
        
        /****************** TEST 3: VEHICLE DETECTION BELOW WAITING THRESHOLD *********************/

        // give the clock time to begin test 3.1
        #100;
        
        /* -------------- TEST 3.1: BLUE STREET NORTH SENSOR DETECTS A VEHICLE -------------- */
        tb_blue_north = 1;

        // IF Blue Street is red and Purple Street is green when Blue Street North detects a vehicle,
        // Blue Street North detection test is successful
        if (tb_blue_green == 1'b0 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b1 &&
            tb_purple_green == 1'b1 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b0)
            
            $display("TEST 3.1 PASSED: Blue Street North sensor detected a vehicle and did not trigger a transition.");

        // OTHERWISE, Blue Street North detection test is unsuccessful
        else
            $display("TEST 3.1 FAILED: Unexpected traffic light outputs during Blue Street North detection.");

        // remove the waiting vehicle before waiting threshold is reached
        tb_blue_north = 0;
        
        // give the clock time to begin test 3.2
        #100;
        
        /* -------------- TEST 3.2: BLUE STREET SOUTH SENSOR DETECTS A VEHICLE -------------- */
        tb_blue_south = 1;

        // IF Blue Street is red and Purple Street is green when Blue Street South detects a vehicle,
        // Blue Street South detection test is successful
        if (tb_blue_green == 1'b0 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b1 &&
            tb_purple_green == 1'b1 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b0)
            
            $display("TEST 3.2 PASSED: Blue Street South sensor detected a vehicle and did not trigger a transition.");

        // OTHERWISE, Blue Street South detection test is unsuccessful
        else
            $display("TEST 3.2 FAILED: Unexpected traffic light outputs during Blue Street South detection.");

        // remove the waiting vehicle before waiting threshold is reached
        tb_blue_south = 0;

        // give the clock time to begin test 3.3
        #100;
        
        /* ------------- TEST 3.3: PURPLE STREET EAST SENSOR DETECTS A VEHICLE -------------- */
        tb_purple_east = 1;

        // IF Blue Street is green and Purple Street is red when Purple Street East detects a vehicle,
        // Purple Street East detection test is successful
        /*if (tb_blue_green == 1'b1 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 3 PASSED: Brief vehicle detection did not trigger a transition.");

        // OTHERWISE, Purple Street East detection test is unsuccessful
        else
            $display("TEST 3 FAILED: Brief vehicle detection triggered an unexpected transition.");*/

        // IF Blue Street is green and Purple Street is red when Purple Street East detects a vehicle,
        // Purple Street East detection test is successful
        if (tb_blue_green == 1'b1 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 3.3 PASSED: Purple Street East sensor detected a vehicle and did not trigger a transition.");

        // OTHERWISE, Purple Street East detection test is unsuccessful
        else
            $display("TEST 3.3 FAILED: Unexpected traffic light outputs during Purple Street East detection.");

        // remove the waiting vehicle before waiting threshold is reached
        tb_purple_east = 0;

        // give the clock time to begin test 3.3
        #100;
        
        /* ------------- TEST 3.4: PURPLE STREET WEST SENSOR DETECTS A VEHICLE -------------- */
        tb_purple_west = 1;

        // IF Blue Street is green and Purple Street is red when Purple Street West detects a vehicle,
        // Purple Street West detection test is successful
        if (tb_blue_green == 1'b1 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 3.4 PASSED: Purple Street West sensor detected a vehicle and did not trigger a transition.");

        // OTHERWISE, Purple Street West detection test is unsuccessful
        else
            $display("TEST 3.4 FAILED: Unexpected traffic light outputs during Purple Street West detection.");

        // remove the waiting vehicle before waiting threshold is reached
        tb_purple_west = 0;
        
        /******************* TEST 4: VEHICLE DETECTION AT WAITING THRESHOLD ***********************/

        // give the clock time to operate
        #100;

        
        /**************** TEST 5: VEHICLE DETECTION INTERRUPTION & TIMER RESET ********************/

        // give the clock time to operate
        #100;

        
        /********************** TEST 6: VEHICLES DETECTED ON BOTH STREETS *************************/

        // give the clock time to operate
        #100;

        
        /********************* TEST 7: FSM TRANSITIONS & ALL-RED INTERVALS ************************/

        // give the clock time to operate
        #100;

        
        /************************************* END SIMULATION *************************************/
        #100;
        $finish;
    end

    // 4. INITIALIZE INPUTS AND APPLY RESET

    // 5. TEST INITIAL FSM STATE

    // 6. TEST NORMAL OPERATION WITH NO VEHICLES

    // 7. TEST VEHICLE DETECTION BELOW WAITING THRESHOLD

    // 8. TEST VEHICLE DETECTION AT WAITING THRESHOLD

    // 9. TEST VEHICLE DETECTION INTERRUPTION AND TIMER RESET

    // 10. TEST VEHICLES DETECTED ON BOTH STREETS

    // 11. TEST FSM TRANSITIONS AND ALL-RED INTERVALS

    // 12. END SIMULATION
endmodule
