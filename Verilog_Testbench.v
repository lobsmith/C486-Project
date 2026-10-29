// TESTBENCH FOR VERILOG TRAFFIC CONTROLLER

`timescale 1ns/1ps

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

    // outputs must be 'wire' for the elapsed-seconds display
    wire [6:0] tb_seg;
    wire [3:0] tb_an;
    wire tb_dp;

    // use a smaller clock divider to accelerate simulation
    // the actual FPGA implementation continues to use the 100MHz clock
    parameter SIM_CLOCK_MAX = 4;

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

        // OUTPUTS: elapsed-seconds display
        .seg(tb_seg),
        .an(tb_an),
        .dp(tb_dp)
    );

    // override the timing parameters for simulation
    // these overrides accelerate the simulation without changing the FPGA source code
    defparam uut.CLOCK_MAX = SIM_CLOCK_MAX;
    defparam uut.GREEN_MAX = 30;
    defparam uut.YELLOW_MAX = 3;
    defparam uut.ALL_RED_MAX = 2;
    defparam uut.BLUE_WAITING_MAX = 10;
    defparam uut.PURPLE_WAITING_MAX = 10;

    /**************************** 3. GENERATE CLOCK SIGNAL FOR SEQUENTIAL DESIGN *******************************/

    // toggles clk every 5ns (10ns per cycle, matches the 100MHz frequency of Basys 3)
    always begin
        #5 tb_clk = ~tb_clk;
    end

    /******************************* 4. MONITOR TRAFFIC LIGHT SAFETY CONDITIONS *******************************/

    // ensure both streets are never green at the same time
    always @(posedge tb_clk) begin
        if (tb_reset == 1'b0 &&
            tb_blue_green == 1'b1 &&
            tb_purple_green == 1'b1) begin

            $display("TEST FAILED: Both streets are green simultaneously.");
            $finish;
        end
    end

    /****************************************** 5. APPLY TEST CASES ********************************************/

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
        wait (uut.current_state == uut.BLUE_GREEN);
        #1;

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

        // wait for Purple Street to become green before testing Blue Street sensors
        wait (uut.current_state == uut.PURPLE_GREEN);
        #1;

        /* -------------- TEST 3.1A: BLUE STREET NORTH SENSOR DETECTS A VEHICLE ------------- */

        // activate Blue Street North sensor briefly
        tb_blue_north = 1;
        #10;

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
        @(posedge tb_clk);
        #1;

        // IF the waiting counter resets after detection is interrupted, then the reset test is successful
        if (uut.blue_waiting_count == 0)
            $display("TEST 3.1A TIMER PASSED: Blue North waiting counter reset after detection stopped.");
        else
            $display("TEST 3.1A TIMER FAILED: Blue North waiting counter did not reset.");

        // give the clock time to begin test 3.1B
        #10;

        /* -------------- TEST 3.1B: BLUE STREET SOUTH SENSOR DETECTS A VEHICLE ------------- */

        // activate Blue Street South sensor briefly
        tb_blue_south = 1;
        #10;

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
        @(posedge tb_clk);
        #1;

        // IF the waiting counter resets after detection is interrupted, then the reset test is successful
        if (uut.blue_waiting_count == 0)
            $display("TEST 3.1B TIMER PASSED: Blue South waiting counter reset after detection stopped.");
        else
            $display("TEST 3.1B TIMER FAILED: Blue South waiting counter did not reset.");

        // wait for Blue Street to become green before testing Purple Street sensors
        wait (uut.current_state == uut.BLUE_GREEN);
        #1;

        /* ------------ TEST 3.2A: PURPLE STREET EAST SENSOR DETECTS A VEHICLE -------------- */

        // activate Purple Street East sensor briefly
        tb_purple_east = 1;
        #10;

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
        @(posedge tb_clk);
        #1;

        // IF the waiting counter resets after detection is interrupted, then the reset test is successful
        if (uut.purple_waiting_count == 0)
            $display("TEST 3.2A TIMER PASSED: Purple East waiting counter reset after detection stopped.");
        else
            $display("TEST 3.2A TIMER FAILED: Purple East waiting counter did not reset.");

        // give the clock time to begin test 3.2B
        #10;

        /* ------------ TEST 3.2B: PURPLE STREET WEST SENSOR DETECTS A VEHICLE -------------- */

        // activate Purple Street West sensor briefly
        tb_purple_west = 1;
        #10;

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
        @(posedge tb_clk);
        #1;

        // IF the waiting counter resets after detection is interrupted, then the reset test is successful
        if (uut.purple_waiting_count == 0)
            $display("TEST 3.2B TIMER PASSED: Purple West waiting counter reset after detection stopped.");
        else
            $display("TEST 3.2B TIMER FAILED: Purple West waiting counter did not reset.");

        /******************* TEST 4: VEHICLE DETECTION AT WAITING THRESHOLD ***********************/

        /* ---------------- TEST 4.1A: BLUE STREET NORTH WAITING THRESHOLD ------------------ */

        // allow time for Purple Street to become green
        wait (uut.current_state == uut.PURPLE_GREEN);
        #1;

        // activate Blue Street North sensor
        tb_blue_north = 1;

        // wait until the 10-second threshold is reached
        // the simulation clock divider has been reduced to accelerate the test
        wait (uut.current_state == uut.PURPLE_YELLOW);
        #1;

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
        wait (uut.current_state == uut.PURPLE_GREEN);
        #1;

        // activate Blue Street South sensor
        tb_blue_south = 1;

        // wait until the 10-second threshold is reached
        // the simulation clock divider has been reduced to accelerate the test
        wait (uut.current_state == uut.PURPLE_YELLOW);
        #1;

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
        wait (uut.current_state == uut.BLUE_GREEN);
        #1;

        // activate Purple Street East sensor
        tb_purple_east = 1;

        // wait until the 10-second threshold is reached
        // the simulation clock divider has been reduced to accelerate the test
        wait (uut.current_state == uut.BLUE_YELLOW);
        #1;

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
        wait (uut.BLUE_GREEN == uut.current_state);
        #1;

        // activate Purple Street West sensor
        tb_purple_west = 1;

        // wait until the 10-second threshold is reached
        // the simulation clock divider has been reduced to accelerate the test
        wait (uut.current_state == uut.BLUE_YELLOW);
        #1;

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

        /* ------------------ TEST 5.1: BLUE NORTH DETECTION INTERRUPTION ------------------- */

        // allow time for Purple Street to become green
        wait (uut.current_state == uut.PURPLE_GREEN);
        #1;

        // activate Blue Street North sensor
        tb_blue_north = 1;

        // wait until the waiting counter has accumulated some time
        wait (uut.blue_waiting_count >= 2);

        // confirm the counter has accumulated time
        if (uut.blue_waiting_count >= 2)
            $display("TEST 5.1A PASSED: Blue North waiting counter accumulated time.");
        else
            $display("TEST 5.1A FAILED: Blue North waiting counter did not accumulate time.");

        // interrupt vehicle detection
        tb_blue_north = 0;

        // allow the next clock edge to process the sensor change
        @(posedge tb_clk);
        #1;

        // verify the waiting counter has reset to zero
        if (uut.blue_waiting_count == 0)
            $display("TEST 5.1B PASSED: Blue North detection interruption reset the waiting counter.");
        else
            $display("TEST 5.1B FAILED: Blue North waiting counter did not reset.");

        // allow time for the next test
        #100;

        /********************** TEST 6: VEHICLES DETECTED ON BOTH STREETS *************************/

        // allow time for Purple Street to become green
        wait (uut.current_state == uut.PURPLE_GREEN);
        #1;

        // activate one sensor on each street simultaneously
        tb_blue_north = 1;
        tb_purple_east = 1;
        #1;

        // IF only the opposing street waiting indicator activates while Purple Street is green,
        // then simultaneous detection test is successful
        if (tb_blue_waiting == 1'b1 && tb_purple_waiting == 1'b0 &&
            tb_blue_green == 1'b0 && tb_purple_green == 1'b1)

            $display("TEST 6.1 PASSED: Simultaneous vehicle detection was handled while Purple Street was green.");
        else
            $display("TEST 6.1 FAILED: Unexpected outputs during simultaneous vehicle detection.");

        // remove both vehicles before the waiting threshold is reached
        tb_blue_north = 0;
        tb_purple_east = 0;
        @(posedge tb_clk);
        #1;

        // IF the waiting counter resets after both vehicles are removed, then the test is successful
        if (uut.blue_waiting_count == 0)
            $display("TEST 6.1 TIMER PASSED: Blue waiting counter reset after simultaneous detection stopped.");
        else
            $display("TEST 6.1 TIMER FAILED: Blue waiting counter did not reset.");

        // allow time for Blue Street to become green
        wait (uut.current_state == uut.BLUE_GREEN);
        #1;

        // activate one sensor on each street simultaneously
        tb_blue_south = 1;
        tb_purple_west = 1;
        #1;

        // IF only the opposing street waiting indicator activates while Blue Street is green,
        // then simultaneous detection test is successful
        if (tb_purple_waiting == 1'b1 && tb_blue_waiting == 1'b0 &&
            tb_blue_green == 1'b1 && tb_purple_green == 1'b0)

            $display("TEST 6.2 PASSED: Simultaneous vehicle detection was handled while Blue Street was green.");
        else
            $display("TEST 6.2 FAILED: Unexpected outputs during simultaneous vehicle detection.");

        // remove both vehicles before the waiting threshold is reached
        tb_blue_south = 0;
        tb_purple_west = 0;
        @(posedge tb_clk);
        #1;

        // IF the waiting counter resets after both vehicles are removed, then the test is successful
        if (uut.purple_waiting_count == 0)
            $display("TEST 6.2 TIMER PASSED: Purple waiting counter reset after simultaneous detection stopped.");
        else
            $display("TEST 6.2 TIMER FAILED: Purple waiting counter did not reset.");

        /********************* TEST 7: FSM TRANSITIONS & ALL-RED INTERVALS ************************/

        // allow time for the normal FSM sequence to continue
        wait (uut.current_state == uut.BLUE_YELLOW);
        #1;

        // IF Blue Street is yellow and Purple Street is red, then the first FSM transition is successful
        if (tb_blue_green == 1'b0 && tb_blue_yellow == 1'b1 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)

            $display("TEST 7.1 PASSED: FSM transitioned from BLUE_GREEN to BLUE_YELLOW.");
        else
            $display("TEST 7.1 FAILED: Unexpected outputs during BLUE_YELLOW.");

        // wait for the all-red interval before Purple Street becomes green
        wait (uut.current_state == uut.ALL_RED_TO_PURPLE);
        #1;

        // IF both streets are red during the all-red interval, then the test is successful
        if (tb_blue_red == 1'b1 && tb_purple_red == 1'b1 &&
            tb_blue_green == 1'b0 && tb_purple_green == 1'b0 &&
            tb_blue_yellow == 1'b0 && tb_purple_yellow == 1'b0)

            $display("TEST 7.2 PASSED: Both streets were red during ALL_RED_TO_PURPLE.");
        else
            $display("TEST 7.2 FAILED: Unexpected outputs during ALL_RED_TO_PURPLE.");

        // wait for Purple Street to become green
        wait (uut.current_state == uut.PURPLE_GREEN);
        #1;

        // IF Purple Street is green and Blue Street is red, then the next FSM transition is successful
        if (tb_purple_green == 1'b1 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b0 &&
            tb_blue_green == 1'b0 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b1)

            $display("TEST 7.3 PASSED: FSM transitioned from ALL_RED_TO_PURPLE to PURPLE_GREEN.");
        else
            $display("TEST 7.3 FAILED: Unexpected outputs during PURPLE_GREEN.");

        // wait for Purple Street to turn yellow
        wait (uut.current_state == uut.PURPLE_YELLOW);
        #1;

        // IF Purple Street is yellow and Blue Street is red, then the next FSM transition is successful
        if (tb_purple_green == 1'b0 && tb_purple_yellow == 1'b1 && tb_purple_red == 0 &&
            tb_blue_green == 1'b0 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b1)

            $display("TEST 7.4 PASSED: FSM transitioned from PURPLE_GREEN to PURPLE_YELLOW.");
        else
            $display("TEST 7.4 FAILED: Unexpected outputs during PURPLE_YELLOW.");

        // wait for the all-red interval before Blue Street becomes green
        wait (uut.current_state == uut.ALL_RED_TO_BLUE);
        #1;

        // IF both streets are red during the all-red interval, then the test is successful
        if (tb_blue_red == 1'b1 && tb_purple_red == 1'b1 &&
            tb_blue_green == 1'b0 && tb_purple_green == 1'b0 &&
            tb_blue_yellow == 1'b0 && tb_purple_yellow == 1'b0)

            $display("TEST 7.5 PASSED: Both streets were red during ALL_RED_TO_BLUE.");
        else
            $display("TEST 7.5 FAILED: Unexpected outputs during ALL_RED_TO_BLUE.");

        /*********************** TEST 8: ELAPSED-SECONDS DISPLAY OUTPUTS **************************/

        // allow the display logic time to update
        #100;

        // IF the segment, digit-select, and decimal-point outputs are known values,
        // then the display output test is successful
        if ((^tb_seg) !== 1'bx && (^tb_an) !== 1'bx && tb_dp !== 1'bx)

            $display("TEST 8 PASSED: Elapsed-seconds display outputs are not unknown.");
        else
            $display("TEST 8 FAILED: One or more elapsed-seconds display outputs are unknown.");

        // display the current output values for inspection
        $display("DISPLAY OUTPUTS: seg=%b, an=%b, dp=%b", tb_seg, tb_an, tb_dp);

        /************************ TEST 9: RESET DURING OPERATION **********************************/

        // wait for Blue Street to become green
        wait (uut.current_state == uut.BLUE_GREEN);
        #1;

        // activate reset during normal operation
        tb_reset = 1;
        #1;

        // IF the FSM returns to ALL_RED_TO_BLUE after reset, then the reset test is successful
        if (uut.current_state == uut.ALL_RED_TO_BLUE)

            $display("TEST 9 PASSED: Reset returned the FSM to ALL_RED_TO_BLUE.");
        else
            $display("TEST 9 FAILED: Reset did not return the FSM to ALL_RED_TO_BLUE.");

        // remove all vehicle detection and release reset
        tb_blue_north = 0;
        tb_blue_south = 0;
        tb_purple_east = 0;
        tb_purple_west = 0;

        #10;
        tb_reset = 0;

        // wait for the controller to restart
        wait (uut.current_state == uut.BLUE_GREEN);
        #1;

        // IF Blue Street is green and Purple Street is red after reset, then restart is successful
        if (tb_blue_green == 1'b1 && tb_blue_yellow == 1'b0 && tb_blue_red == 1'b0 &&
            tb_purple_green == 1'b0 && tb_purple_yellow == 1'b0 && tb_purple_red == 1'b1)

            $display("TEST 9 RESTART PASSED: Controller restarted in BLUE_GREEN.");
        else
            $display("TEST 9 RESTART FAILED: Unexpected outputs after reset.");

        /************************************* END SIMULATION *************************************/

        // give the clock time to complete the final test
        #100;
        $display("TESTBENCH COMPLETED.");
        $finish;
    end

    /******************************* SIMULATION WATCHDOG ******************************************/

    // stop the simulation if a state transition or test gets stuck
    initial begin
        #1000000;
        $display("WATCHDOG: Simulation timed out before all tests completed.");
        $finish;
    end

endmodule
