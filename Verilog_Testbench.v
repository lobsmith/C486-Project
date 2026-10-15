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

        // IF Blue Street is green and Purple Street is red, then start-up test is successful
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

        // IF Blue Street is green and Purple Street is red, then normal operation test is successful
        if (tb_blue_green == 1'b1 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 2 PASSED: Normal operation with no vehicles.");

        // OTHERWISE, normal operation test is unsuccessful
        else
            $display("TEST 2 FAILED: Unexpected traffic light outputs during normal operation.");
        
        /****************** TEST 3: VEHICLE DETECTION BELOW WAITING THRESHOLD *********************/

        // give the clock time to begin test 3.1A
        #100;
        
        /* -------------- TEST 3.1A: BLUE STREET NORTH SENSOR DETECTS A VEHICLE ------------- */
        tb_blue_north = 1; #10;

        // IF Blue Street is red and Purple Street is green when Blue Street North detects a vehicle,
        // then Blue Street North detection test is successful
        if (tb_blue_green == 1'b0 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b1 &&
            tb_purple_green == 1'b1 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b0)
            
            $display("TEST 3.1A PASSED: Blue Street North sensor detected a vehicle and did not trigger a transition.");

        // OTHERWISE, Blue Street North detection test is unsuccessful
        else
            $display("TEST 3.1A FAILED: Unexpected traffic light outputs during Blue Street North detection.");

        // remove the waiting vehicle before waiting threshold is reached
        tb_blue_north = 0;
        
        // give the clock time to begin test 3.1B
        #100;
        
        /* -------------- TEST 3.1B: BLUE STREET SOUTH SENSOR DETECTS A VEHICLE ------------- */
        tb_blue_south = 1; #10;

        // IF Blue Street is red and Purple Street is green when Blue Street South detects a vehicle,
        // then Blue Street South detection test is successful
        if (tb_blue_green == 1'b0 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b1 &&
            tb_purple_green == 1'b1 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b0)
            
            $display("TEST 3.1B PASSED: Blue Street South sensor detected a vehicle and did not trigger a transition.");

        // OTHERWISE, Blue Street South detection test is unsuccessful
        else
            $display("TEST 3.1B FAILED: Unexpected traffic light outputs during Blue Street South detection.");

        // remove the waiting vehicle before waiting threshold is reached
        tb_blue_south = 0;

        // give the clock time to begin test 3.2A
        #100;
        
        /* ------------ TEST 3.2A: PURPLE STREET EAST SENSOR DETECTS A VEHICLE -------------- */
        tb_purple_east = 1; #10;

        // IF Blue Street is green and Purple Street is red when Purple Street East detects a vehicle,
        // then Purple Street East detection test is successful
        if (tb_blue_green == 1'b1 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 3.2A PASSED: Purple Street East sensor detected a vehicle and did not trigger a transition.");

        // OTHERWISE, Purple Street East detection test is unsuccessful
        else
            $display("TEST 3.2A FAILED: Unexpected traffic light outputs during Purple Street East detection.");

        // remove the waiting vehicle before waiting threshold is reached
        tb_purple_east = 0;

        // give the clock time to begin test 3.2B
        #100;
        
        /* ------------ TEST 3.2B: PURPLE STREET WEST SENSOR DETECTS A VEHICLE -------------- */
        tb_purple_west = 1; #10;

        // IF Blue Street is green and Purple Street is red when Purple Street West detects a vehicle,
        // then Purple Street West detection test is successful
        if (tb_blue_green == 1'b1 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 3.2B PASSED: Purple Street West sensor detected a vehicle and did not trigger a transition.");

        // OTHERWISE, Purple Street West detection test is unsuccessful
        else
            $display("TEST 3.2B FAILED: Unexpected traffic light outputs during Purple Street West detection.");

        // remove the waiting vehicle before waiting threshold is reached
        tb_purple_west = 0;
        
        /******************* TEST 4: VEHICLE DETECTION AT WAITING THRESHOLD ***********************/

        /* ---------------- TEST 4.1A: BLUE STREET NORTH WAITING THRESHOLD ------------------ */
        
        // allow time for Purple Street to become green
        #100;
        
        // activate Blue Street North sensor
        tb_blue_north = 1;
        
        // wait until the 10-second threshold is reached (1,000,000,000 cycles)
        #10000000000;
        
        // IF Purple Street turns yellow after Blue Street waiting threshold has been reached,
        // then Blue Street North sensor transition test is successful
        if (tb_blue_green == 1'b0 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b1 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b1 && tb_purple_red == 1'b0)
            
            $display("TEST 4.1A PASSED: Blue Street North detection triggered the transition from PURPLE_GREEN to PURPLE_YELLOW.");
        else
            $display("TEST 4.1A FAILED: Blue Street North detection did not trigger the transition from PURPLE_GREEN to PURPLE_YELLOW.");
        
        // remove the waiting vehicle
        tb_blue_north = 0;
        
        /* ---------------- TEST 4.1B: BLUE STREET SOUTH WAITING THRESHOLD ------------------ */

        // allow time for Purple Street to become green
        #100;
        
        // activate Blue Street South sensor
        tb_blue_south = 1;
        
        // wait until the 10-second threshold is reached (1,000,000,000 cycles)
        #10000000000;
        
        // IF Purple Street turns yellow after Blue Street waiting threshold has been reached,
        // then Blue Street South sensor transition test is successful
        if (tb_blue_green == 1'b0 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b1 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b1 && tb_purple_red == 1'b0)
            
            $display("TEST 4.1B PASSED: Blue Street South detection triggered the transition from PURPLE_GREEN to PURPLE_YELLOW.");
        else
            $display("TEST 4.1B FAILED: Blue Street South detection did not trigger the transition from PURPLE_GREEN to PURPLE_YELLOW.");
        
        // remove the waiting vehicle
        tb_blue_south = 0;
        
        /* ---------------- TEST 4.2A: PURPLE STREET EAST WAITING THRESHOLD ----------------- */
        
        // allow time for Blue Street to become green
        #100;
        
        // activate Purple Street East sensor
        tb_purple_east = 1;
        
        // wait until the 10-second threshold is reached (1,000,000,000 cycles)
        #10000000000;
        
        // IF Blue Street turns yellow after Purple Street waiting threshold has been reached,
        // then Purple Street East sensor transition test is successful
        if (tb_blue_green == 1'b0 && tb_blue_yellow == 1'b1 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 4.2A PASSED: Purple Street East detection triggered the transition from BLUE_GREEN to BLUE_YELLOW.");
        else
            $display("TEST 4.2A FAILED: Purple Street East detection did not trigger the transition from BLUE_GREEN to BLUE_YELLOW.");
        
        // remove the waiting vehicle
        tb_purple_east = 0;

        /* ---------------- TEST 4.2B: PURPLE STREET WEST WAITING THRESHOLD ----------------- */
        
        // allow time for Blue Street to become green
        #100;
        
        // activate Purple Street West sensor
        tb_purple_west = 1;
        
        // wait until the 10-second threshold is reached (1,000,000,000 cycles)
        #10000000000;
        
        // IF Blue Street turns yellow after Purple Street waiting threshold has been reached,
        // then Purple Street West sensor transition test is successful
        if (tb_blue_green == 1'b0 && tb_blue_yellow == 1'b1 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)
            
            $display("TEST 4.2B PASSED: Purple Street West detection triggered the transition from BLUE_GREEN to BLUE_YELLOW.");
        else
            $display("TEST 4.2B FAILED: Purple Street West detection did not trigger the transition from BLUE_GREEN to BLUE_YELLOW.");
        
        // remove the waiting vehicle
        tb_purple_west = 0;
                
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
        #100; $finish;
    end
endmodule
