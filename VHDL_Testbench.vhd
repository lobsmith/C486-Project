-- VHDL TRAFFIC CONTROLLER TESTBENCH

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.ENV.ALL; -- Used to end the simulation normally

entity traffic_controller_tb is
end traffic_controller_tb;

architecture Behavioral of traffic_controller_tb is

    -- 1. DECLARE TESTBENCH SIGNALS

    -- Inputs to the design under test
    signal tb_clk              : STD_LOGIC := '0';
    signal tb_reset            : STD_LOGIC := '0';
    signal tb_blue_sensor_north : STD_LOGIC := '0';
    signal tb_blue_sensor_south : STD_LOGIC := '0';
    signal tb_purple_sensor_east : STD_LOGIC := '0';
    signal tb_purple_sensor_west : STD_LOGIC := '0';

    -- Outputs from the design under test
    signal tb_blue_green   : STD_LOGIC;
    signal tb_blue_yellow  : STD_LOGIC;
    signal tb_blue_red     : STD_LOGIC;
    signal tb_purple_green : STD_LOGIC;
    signal tb_purple_yellow : STD_LOGIC;
    signal tb_purple_red   : STD_LOGIC;
    signal tb_blue_waiting : STD_LOGIC;
    signal tb_purple_waiting : STD_LOGIC;

    -- Seven-segment display outputs
    signal tb_seg : STD_LOGIC_VECTOR(6 downto 0);
    signal tb_an  : STD_LOGIC_VECTOR(3 downto 0);
    signal tb_dp  : STD_LOGIC;

    -- Accelerated timing for simulation
    -- The actual FPGA design retains its default CLOCK_MAX value.
    constant SIM_CLOCK_MAX : INTEGER := 4;

begin

    -- 2. INSTANTIATE DESIGN UNDER TEST (DUT)

    uut : entity work.traffic_controller
        generic map (
            CLOCK_MAX => SIM_CLOCK_MAX
        )
        port map (
            clk                => tb_clk,
            reset              => tb_reset,
            blue_sensor_north  => tb_blue_sensor_north,
            blue_sensor_south  => tb_blue_sensor_south,
            purple_sensor_east => tb_purple_sensor_east,
            purple_sensor_west => tb_purple_sensor_west,
            blue_green         => tb_blue_green,
            blue_yellow        => tb_blue_yellow,
            blue_red           => tb_blue_red,
            purple_green       => tb_purple_green,
            purple_yellow      => tb_purple_yellow,
            purple_red         => tb_purple_red,
            blue_waiting       => tb_blue_waiting,
            purple_waiting     => tb_purple_waiting,
            seg                => tb_seg,
            an                 => tb_an,
            dp                 => tb_dp
        );

    -- 3. GENERATE CLOCK SIGNAL

    clock_process : process
    begin
        tb_clk <= '0';
        wait for 5 ns;
        tb_clk <= '1';
        wait for 5 ns;
    end process;

    -- 4. INITIALIZE INPUTS AND APPLY TESTS

    test_process : process
        variable phase_start : time;
        variable phase_end   : time;
        variable phase_duration : time;
    begin

        -- TEST 1: STARTUP AND RESET

        -- Apply reset to the traffic controller
        tb_reset <= '1';
        wait for 20 ns;

        -- Verify that both streets are red during reset
        assert tb_blue_red = '1'
            report "ERROR: Blue red light is not active during reset."
            severity error;

        assert tb_purple_red = '1'
            report "ERROR: Purple red light is not active during reset."
            severity error;

        -- Verify that neither street has green during reset
        assert tb_blue_green = '0' and tb_purple_green = '0'
            report "ERROR: A green light is active during reset."
            severity error;

        -- Release reset and allow the controller to operate
        tb_reset <= '0';

        -- Wait for Blue Street to receive green
        wait until tb_blue_green = '1';
        wait for 1 ns;

        -- Verify that Blue is green and Purple remains red
        assert tb_blue_green = '1'
            report "ERROR: Blue Street did not receive green first."
            severity error;

        assert tb_purple_green = '0'
            report "ERROR: Purple Street received green at the wrong time."
            severity error;

        assert tb_purple_red = '1'
            report "ERROR: Purple Street should remain red."
            severity error;

        report "TEST 1 PASSED: Startup and reset verified."
            severity note;

        -- TEST 2: NORMAL OPERATION

        -- Verify that the controller transitions from Blue green to Blue yellow
        wait until tb_blue_yellow = '1';

        assert tb_blue_green = '0'
            report "ERROR: Blue green should turn off during yellow."
            severity error;

        assert tb_purple_red = '1'
            report "ERROR: Purple should remain red during Blue yellow."
            severity error;

        -- Verify that both streets are red during the all-red interval
        wait until tb_blue_red = '1' and tb_purple_red = '1'
            and tb_blue_yellow = '0' and tb_purple_yellow = '0';

        assert tb_blue_green = '0' and tb_purple_green = '0'
            report "ERROR: A green light is active during all red."
            severity error;

        -- TEST 3: VEHICLE DETECTION BELOW WAITING THRESHOLD

        -- Wait until Purple has green before testing Blue waiting
        wait until tb_purple_green = '1';

        -- Detect a vehicle on Blue Street
        tb_blue_sensor_north <= '1';
        wait for 1 ns;

        assert tb_blue_waiting = '1'
            report "ERROR: Blue waiting indicator did not activate."
            severity error;

        -- Keep the sensor active for less than 10 seconds
        wait for 100 ns;

        -- Remove the vehicle before the waiting threshold
        tb_blue_sensor_north <= '0';
        wait for 1 ns;

        assert tb_blue_waiting = '0'
            report "ERROR: Blue waiting indicator did not deactivate."
            severity error;

        -- Wait until Blue has green before testing Purple waiting
        wait until tb_blue_green = '1';

        -- Detect a vehicle on Purple Street
        tb_purple_sensor_east <= '1';
        wait for 1 ns;

        assert tb_purple_waiting = '1'
            report "ERROR: Purple waiting indicator did not activate."
            severity error;

        -- Keep the sensor active for less than 10 seconds
        wait for 100 ns;

        -- Remove the vehicle before the waiting threshold
        tb_purple_sensor_east <= '0';
        wait for 1 ns;

        assert tb_purple_waiting = '0'
            report "ERROR: Purple waiting indicator did not deactivate."
            severity error;

        report "TEST 3 PASSED: Vehicle detection below threshold verified."
            severity note;


        -- TEST 4: VEHICLE DETECTION AT WAITING THRESHOLD

        -- Wait until Purple has green
        wait until tb_purple_green = '1';

        -- Detect a vehicle on Blue Street
        tb_blue_sensor_north <= '1';
        wait for 1 ns;

        assert tb_blue_waiting = '1'
            report "ERROR: Blue waiting indicator did not activate."
            severity error;

        -- Keep the vehicle detected long enough to reach the threshold
        -- Ten simulated seconds are approximately 400 ns
        -- Allow additional time for counter alignment
        wait for 450 ns;

        -- Verify that the controller has started transitioning
        assert tb_purple_yellow = '1'
            report "ERROR: Purple did not transition to yellow after the waiting threshold."
            severity error;

        assert tb_purple_green = '0'
            report "ERROR: Purple green remained active after the transition."
            severity error;

        assert tb_blue_yellow = '0'
            report "ERROR: Blue yellow should not activate during Purple yellow."
            severity error;

        -- Remove the vehicle after the transition begins
        tb_blue_sensor_north <= '0';

        report "TEST 4 PASSED: Blue vehicle waiting threshold verified."
            severity note;

        -- TEST 5: INTERRUPTED DETECTION AND WAITING COUNTER RESET

        -- Wait until Purple has green
        wait until tb_purple_green = '1';

        -- Detect a vehicle on Blue Street
        tb_blue_sensor_north <= '1';

        -- Keep the sensor active for less than the waiting threshold
        wait for 200 ns;

        -- Interrupt detection before the waiting threshold
        tb_blue_sensor_north <= '0';
        wait for 1 ns;

        assert tb_blue_waiting = '0'
            report "ERROR: Blue waiting indicator did not deactivate after detection was interrupted."
            severity error;

        -- Wait until Purple has green again for a fresh detection
        wait until tb_purple_green = '1';

        -- Detect a vehicle on Blue Street again
        tb_blue_sensor_north <= '1';

        -- Verify that the new detection starts a fresh waiting interval
        wait for 200 ns;

        assert tb_purple_green = '1'
            report "ERROR: Purple green ended before the fresh waiting interval was completed."
            severity error;

        -- Keep the sensor active until the waiting threshold is reached
        wait for 250 ns;

        assert tb_purple_yellow = '1'
            report "ERROR: Waiting counter may not have reset after detection was interrupted."
            severity error;

        -- Remove the vehicle after the transition begins
        tb_blue_sensor_north <= '0';

        report "TEST 5 PASSED: Interrupted detection and waiting counter reset verified."
            severity note;

        -- TEST 6: BOTH SENSORS ON THE SAME STREET

        -- Wait until Purple has green
        wait until tb_purple_green = '1';

        -- Activate the North sensor on Blue Street
        tb_blue_sensor_north <= '1';
        wait for 1 ns;

        assert tb_blue_waiting = '1'
            report "ERROR: North sensor did not activate Blue waiting indicator."
            severity error;

        -- Activate the South sensor while North remains active
        tb_blue_sensor_south <= '1';
        wait for 1 ns;

        assert tb_blue_waiting = '1'
            report "ERROR: Blue waiting indicator failed with both sensors active."
            severity error;

        -- Deactivate North while South remains active
        tb_blue_sensor_north <= '0';
        wait for 1 ns;

        assert tb_blue_waiting = '1'
            report "ERROR: Blue waiting indicator deactivated while South sensor remained active."
            severity error;

        -- Deactivate South
        tb_blue_sensor_south <= '0';
        wait for 1 ns;

        assert tb_blue_waiting = '0'
            report "ERROR: Blue waiting indicator remained active after both sensors were cleared."
            severity error;

        -- Wait until Blue has green
        wait until tb_blue_green = '1';

        -- Activate the East sensor on Purple Street
        tb_purple_sensor_east <= '1';
        wait for 1 ns;

        assert tb_purple_waiting = '1'
            report "ERROR: East sensor did not activate Purple waiting indicator."
            severity error;

        -- Activate the West sensor while East remains active
        tb_purple_sensor_west <= '1';
        wait for 1 ns;

        assert tb_purple_waiting = '1'
            report "ERROR: Purple waiting indicator failed with both sensors active."
            severity error;

        -- Deactivate East while West remains active
        tb_purple_sensor_east <= '0';
        wait for 1 ns;

        assert tb_purple_waiting = '1'
            report "ERROR: Purple waiting indicator deactivated while West sensor remained active."
            severity error;

        -- Deactivate West
        tb_purple_sensor_west <= '0';
        wait for 1 ns;

        assert tb_purple_waiting = '0'
            report "ERROR: Purple waiting indicator remained active after both sensors were cleared."
            severity error;

        report "TEST 6 PASSED: Both sensors on each street verified."
            severity note;

        -- TEST 7: SIMULTANEOUS VEHICLE DETECTION

        -- Wait until Purple has green
        wait until tb_purple_green = '1';

        -- Detect vehicles on both streets
        tb_blue_sensor_north <= '1';
        tb_purple_sensor_east <= '1';
        wait for 1 ns;

        -- Verify that Blue vehicles are waiting
        assert tb_blue_waiting = '1'
            report "ERROR: Blue waiting indicator did not activate during simultaneous detection."
            severity error;

        -- Verify that Purple has green and Blue remains red
        assert tb_purple_green = '1' and tb_blue_green = '0'
            report "ERROR: Incorrect traffic lights during simultaneous vehicle detection."
            severity error;

        -- Verify that both streets are never green simultaneously
        assert not (tb_blue_green = '1' and tb_purple_green = '1')
            report "ERROR: Both streets have green lights simultaneously."
            severity error;

        -- Allow the controller to continue operating
        -- The Blue vehicle should cause Purple to transition after the waiting threshold
        wait until tb_purple_yellow = '1';

        -- Verify that Purple green turns off during yellow
        assert tb_purple_green = '0'
            report "ERROR: Purple green remained active during Purple yellow."
            severity error;

        -- Verify that Blue does not receive green prematurely
        assert tb_blue_green = '0'
            report "ERROR: Blue green activated before the all-red interval."
            severity error;

        -- Remove the Blue vehicle while Purple is transitioning
        tb_blue_sensor_north <= '0';

        -- Keep the Purple vehicle detected
        wait for 1 ns;

        assert tb_purple_waiting = '0'
            report "ERROR: Purple waiting indicator should be inactive while Purple is transitioning."
            severity error;

        -- Wait until Blue receives green
        wait until tb_blue_green = '1';

        -- Verify that Blue now has green and Purple does not
        assert tb_blue_green = '1' and tb_purple_green = '0'
            report "ERROR: Incorrect traffic lights after the transition to Blue green."
            severity error;

        -- Verify that both streets are never green simultaneously
        assert not (tb_blue_green = '1' and tb_purple_green = '1')
            report "ERROR: Both streets have green lights simultaneously after the transition."
            severity error;

        -- Clear the remaining Purple vehicle
        tb_purple_sensor_east <= '0';

        report "TEST 7 PASSED: Simultaneous vehicle detection verified."
            severity note;

        -- TEST 8: FSM TIMING AND ALL-RED INTERVALS

        -- Verify Blue yellow duration
        wait until tb_blue_yellow = '1';
        phase_start := now;

        -- Wait until Blue yellow ends
        wait until tb_blue_yellow = '0';
        phase_end := now;
        phase_duration := phase_end - phase_start;

        -- Verify that Blue yellow lasts approximately 3 simulated seconds
        -- With SIM_CLOCK_MAX = 4, 3 seconds is approximately 120 ns
        assert phase_duration >= 80 ns and phase_duration <= 160 ns
            report "ERROR: Blue yellow duration is outside the expected range."
            severity error;

        -- Verify the all-red interval before Purple green
        wait until tb_blue_red = '1' and tb_purple_red = '1'
            and tb_blue_yellow = '0' and tb_purple_yellow = '0';

        phase_start := now;

        -- Both streets must remain red until Purple receives green
        assert tb_blue_green = '0' and tb_purple_green = '0'
            report "ERROR: A green light is active during the all-red interval."
            severity error;

        wait until tb_purple_green = '1';
        phase_end := now;
        phase_duration := phase_end - phase_start;

        -- Verify that the all-red interval lasts approximately 2 simulated seconds
        -- With SIM_CLOCK_MAX = 4, 2 seconds is approximately 80 ns
        assert phase_duration >= 40 ns and phase_duration <= 120 ns
            report "ERROR: All-red interval before Purple green is outside the expected range."
            severity error;

        -- Verify Purple yellow duration
        wait until tb_purple_yellow = '1';
        phase_start := now;

        -- Wait until Purple yellow ends
        wait until tb_purple_yellow = '0';
        phase_end := now;
        phase_duration := phase_end - phase_start;

        -- Verify that Purple yellow lasts approximately 3 simulated seconds
        assert phase_duration >= 80 ns and phase_duration <= 160 ns
            report "ERROR: Purple yellow duration is outside the expected range."
            severity error;

        -- Verify the all-red interval before Blue green
        wait until tb_blue_red = '1' and tb_purple_red = '1'
            and tb_blue_yellow = '0' and tb_purple_yellow = '0';

        phase_start := now;

        -- Both streets must remain red until Blue receives green
        assert tb_blue_green = '0' and tb_purple_green = '0'
            report "ERROR: A green light is active during the all-red interval."
            severity error;

        wait until tb_blue_green = '1';
        phase_end := now;
        phase_duration := phase_end - phase_start;

        -- Verify that the all-red interval lasts approximately 2 simulated seconds
        assert phase_duration >= 40 ns and phase_duration <= 120 ns
            report "ERROR: All-red interval before Blue green is outside the expected range."
            severity error;

        report "TEST 8 PASSED: FSM timing and all-red intervals verified."
            severity note;

        -- TEST 9: RESET DURING OPERATION

        -- Wait until Purple has green
        wait until tb_purple_green = '1';

        -- Detect a vehicle on Blue Street
        tb_blue_sensor_north <= '1';
        wait for 1 ns;

        -- Verify that Blue waiting activates
        assert tb_blue_waiting = '1'
            report "ERROR: Blue waiting indicator did not activate before reset."
            severity error;

        -- Apply reset while the controller is operating
        tb_reset <= '1';
        wait for 20 ns;

        -- Verify that both streets are red during reset
        assert tb_blue_red = '1' and tb_purple_red = '1'
            report "ERROR: Both streets are not red during reset."
            severity error;

        -- Verify that neither street has green during reset
        assert tb_blue_green = '0' and tb_purple_green = '0'
            report "ERROR: A green light is active during reset."
            severity error;

        -- Verify that neither street has yellow during reset
        assert tb_blue_yellow = '0' and tb_purple_yellow = '0'
            report "ERROR: A yellow light is active during reset."
            severity error;

        -- Verify that the waiting indicators are inactive
        assert tb_blue_waiting = '0' and tb_purple_waiting = '0'
            report "ERROR: A waiting indicator remains active during reset."
            severity error;

        -- Clear the sensor and release reset
        tb_blue_sensor_north <= '0';
        tb_reset <= '0';

        -- Wait for the controller to return to its startup sequence
        wait until tb_blue_green = '1';
        wait for 1 ns;

        -- Verify that Blue receives green first after reset
        assert tb_blue_green = '1'
            report "ERROR: Blue Street did not receive green after reset."
            severity error;

        assert tb_purple_green = '0' and tb_purple_red = '1'
            report "ERROR: Purple Street has an incorrect signal after reset."
            severity error;

        assert tb_blue_yellow = '0' and tb_purple_yellow = '0'
            report "ERROR: A yellow light is active after reset."
            severity error;

        report "TEST 9 PASSED: Reset during operation verified."
            severity note;

        -- End the simulation after all tests have completed
        report "ALL TESTS COMPLETED."
            severity note;

        finish;
        wait;

    end process;

end Behavioral;
