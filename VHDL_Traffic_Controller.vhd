-- VHDL TRAFFIC CONTROLLER

library IEEE;                                    -- declare standard VHDL libraries
use IEEE.STD_LOGIC_1164.ALL;                     -- import digital logic (STD_LOGIC_VECTOR)
use IEEE.NUMERIC_STD.ALL;                        -- import standard numeric types and arithmetic operations (unsigned, signed)

-------------------------------------------------------------------------------------------------------------
---------------------------------------- 1. ENTITY DECLARATION & I/O ----------------------------------------
-------------------------------------------------------------------------------------------------------------

-- port declaration: define inputs and outputs
entity traffic_controller is
    Port (
        -- INPUTS: clock and reset signals
        clk                 : in  STD_LOGIC;    -- FPGA clock signal
        reset               : in  STD_LOGIC;    -- reset signal

        -- INPUTS: 4 Hall sensors
        blue_sensor_north   : in  STD_LOGIC;    -- Blue Street, Northmost sensor (Southbound)
        blue_sensor_south   : in  STD_LOGIC;    -- Blue Street, Southmost sensor (Northbound)
        purple_sensor_east  : in  STD_LOGIC;    -- Purple Street, Eastmost sensor (Westbound)
        purple_sensor_west  : in  STD_LOGIC;    -- Purple Street, Westmost sensor (Eastbound)
        
        -- OUTPUTS: 8 LEDs (2 red, 2 yellow, 2 green, 2 waiting indicators)
        blue_green          : out STD_LOGIC;    -- BLUE: green;  PURPLE: red
        blue_yellow         : out STD_LOGIC;    -- BLUE: yellow; PURPLE: red
        blue_red            : out STD_LOGIC;    -- BLUE: red;    PURPLE: red (before transition to PURPLE_GREEN)
        purple_green        : out STD_LOGIC;    -- BLUE: red;    PURPLE: green
        purple_yellow       : out STD_LOGIC;    -- BLUE: red;    PURPLE: yellow
        purple_red          : out STD_LOGIC;    -- BLUE: red;    PURPLE: red (before transition to BLUE_GREEN)
        blue_waiting        : out STD_LOGIC;    -- blue waiting indicator
        purple_waiting      : out STD_LOGIC;    -- purple waiting indicator

        -- OUTPUTS: four-digit seven-segment timer display
        seg                 : out STD_LOGIC_VECTOR(6 downto 0);
        an                  : out STD_LOGIC_VECTOR(3 downto 0);
        dp                  : out STD_LOGIC
    );
end traffic_controller;

architecture Behavioral of traffic_controller is
    
    -------------------------------------------------------------------------------------------------------------
    ---------------------------------- 2. FSM STATE DEFINITIONS & ARCHITECTURE ----------------------------------
    -------------------------------------------------------------------------------------------------------------
    
    -- define unique binary encodings for each state; start state: ALL_RED_TO_BLUE
    -- STATE is added, since VHDL is not case sensitive and will confuse state names with LED outputs
    constant STATE_ALL_RED_TO_BLUE   : STD_LOGIC_VECTOR(2 downto 0) := "000";
    constant STATE_BLUE_GREEN        : STD_LOGIC_VECTOR(2 downto 0) := "001";
    constant STATE_BLUE_YELLOW       : STD_LOGIC_VECTOR(2 downto 0) := "010";
    constant STATE_ALL_RED_TO_PURPLE : STD_LOGIC_VECTOR(2 downto 0) := "011";
    constant STATE_PURPLE_GREEN      : STD_LOGIC_VECTOR(2 downto 0) := "100";
    constant STATE_PURPLE_YELLOW     : STD_LOGIC_VECTOR(2 downto 0) := "101";

    -- Basys 3 runs on 100MHz clock (100 million cycles per second)
    -- define timing limits
    constant CLOCK_MAX          : INTEGER := 100000000;                         -- 100,000,000 clock cycle limit - 27 bits
    constant YELLOW_MAX         : INTEGER := 3;                                 -- 3-second yellow light limit - 2 bits
    constant ALL_RED_MAX        : INTEGER := 2;                                 -- 2-second all-red limit - 2 bits
    constant GREEN_MAX          : INTEGER := 30;                                -- 30-second all-green limit - 6 bits
    constant BLUE_WAITING_MAX   : UNSIGNED(3 downto 0) := to_unsigned(10, 4);   -- 10-second Blue waiting limit - 4 bits
    constant PURPLE_WAITING_MAX : UNSIGNED(3 downto 0) := to_unsigned(10, 4);   -- 10-second Purple waiting limit - 4 bits

    -- define state registers (3 bits wide for 6 states)
    signal current_state        : STD_LOGIC_VECTOR(2 downto 0);
    signal next_state           : STD_LOGIC_VECTOR(2 downto 0);

    -- define internal timing registers
    signal count                : UNSIGNED(26 downto 0);                        -- internal timing register - 27 bits
    signal one_second_tick      : STD_LOGIC;                                    -- one-second timing tick - 1 bit
    signal yellow_count         : UNSIGNED(1 downto 0);                         -- internal yellow light timer register - 2 bits
    signal all_red_count        : UNSIGNED(1 downto 0);                         -- internal all-red timer register - 2 bits
    signal blue_green_count     : UNSIGNED(5 downto 0);                         -- internal green timer register for Blue Street - 6 bits
    signal purple_green_count   : UNSIGNED(5 downto 0);                         -- internal green timer register for Purple Street - 6 bits
    signal blue_waiting_count   : UNSIGNED(3 downto 0) := (others => '0');      -- internal blue waiting timer register - 4 bits
    signal purple_waiting_count : UNSIGNED(3 downto 0) := (others => '0');      -- internal purple waiting timer register - 4 bits

    -- define signals indicating sensor waiting conditions
    signal blue_waiting_condition   : STD_LOGIC;
    signal purple_waiting_condition : STD_LOGIC;

    -- define signals indicating when each green timer expires
    signal blue_green_timer_done    : STD_LOGIC;
    signal purple_green_timer_done  : STD_LOGIC;

    -- define signals indicating vehicle detection
    signal blue_vehicle_detected    : STD_LOGIC;
    signal purple_vehicle_detected  : STD_LOGIC;

    ---------------------- ELAPSED TIMER DISPLAY ----------------------

    -- elapsed seconds in the current FSM phase
    signal elapsed_seconds : UNSIGNED(5 downto 0);

    -- remember the previous FSM state to detect phase changes
    signal previous_state : STD_LOGIC_VECTOR(2 downto 0);

    -- counter used to refresh the four display digits
    signal refresh_counter : UNSIGNED(19 downto 0);

    -- current digit being displayed
    signal display_digit : UNSIGNED(3 downto 0);

    -- decimal digits for the elapsed-seconds display
    signal elapsed_ones : UNSIGNED(3 downto 0);
    signal elapsed_tens : UNSIGNED(3 downto 0);
    
begin
    
    -------------------------------------------------------------------------------------------------------------
    ----------------------------------------- 3. TRAFFIC LIGHT TIMING -------------------------------------------
    -------------------------------------------------------------------------------------------------------------

    -------------------------- CLOCK TIMER --------------------------
    
    -- implement sequential timing logic (producing one pulse per second)
    -- PROCESS executes when the clock has a rising edge or reset is activated
    process(clk, reset) begin
        if reset = '1' then
            count           <= (others => '0');      -- reset counter to 0 (others => '0' sets all bits to 0)
            one_second_tick <= '0';                  -- one-second signal turned off

        -- NORMAL OPERATION: IF clock is on rising edge and reset is not activated
        elsif rising_edge(clk) then
            -- DEFAULT: no one-second tick at the beginning of each clock cycle (1'b0)
            one_second_tick <= '0';

            -- IF count has reached the 100MHz limit (count == 99,999,999)
            if count = to_unsigned(CLOCK_MAX - 1, count'length) then
                count           <= (others => '0');  -- reset counter to 0
                one_second_tick <= '1';              -- produce one-second tick
            
            -- IF count has NOT reached the 100MHz limit (count != 99,999,999)
            else
                count <= count + 1;                  -- add one cycle to the counter and continue
            end if;
        end if;
    end process;

    ------------------------ YELLOW LIGHT TIMER ------------------------

    -- implement sequential yellow light timing logic (count by one-second intervals)
    process(clk, reset) begin
        -- IF reset has been activated
        if reset = '1' then
            yellow_count <= (others => '0');        -- reset counter to 0

        -- IF clock is on rising edge and reset is not activated
        elsif rising_edge(clk) then
            -- IF the machine is currently in a yellow light state
            if (current_state = STATE_BLUE_YELLOW) or (current_state = STATE_PURPLE_YELLOW) then
                -- IF one-second tick occurs
                if one_second_tick = '1' then
                    -- IF count has reached the 3-second limit
                    if yellow_count = to_unsigned(YELLOW_MAX, yellow_count'length) then
                        yellow_count <= (others => '0');    -- reset counter to 0
                    
                    -- IF count has NOT reached the 3-second limit
                    else yellow_count <= yellow_count + 1;                -- add one second to the counter and continue
                    end if;
                end if;
    
            -- IF the machine is NOT in a yellow light state
            else yellow_count <= (others => '0');                                       -- reset counter to 0
            end if;
        end if;
    end process;

    -------------------------- ALL-RED TIMER --------------------------
    
    -- implement sequential all-red timing logic (count by one-second intervals)
    process(clk, reset) begin
        -- IF reset has been activated
        if reset = '1' then
            all_red_count <= (others => '0');        -- reset counter to 0

        -- IF clock is on rising edge and reset is not activated
        elsif rising_edge(clk) then
            -- IF the machine is currently in an all-red state
            if (current_state = STATE_ALL_RED_TO_BLUE) or (current_state = STATE_ALL_RED_TO_PURPLE) then
                -- IF one-second tick occurs
                if one_second_tick = '1' then
                    -- IF count has reached the 2-second limit
                    if all_red_count = to_unsigned(ALL_RED_MAX, all_red_count'length) then
                        all_red_count <= (others => '0');    -- reset counter to 0
                    
                    -- IF count has NOT reached the 2-second limit
                    else all_red_count <= all_red_count + 1;                            -- add one second to the counter and continue
                    end if;
                end if;
            -- IF the machine is NOT in an all-red state
            else all_red_count <= (others => '0');                                      -- reset counter to 0
            end if;
        end if;
    end process;

   ----------------------- GREEN LIGHT TIMER ------------------------
                                                   
   -- define signal indicating when Blue Street green timer expires
    blue_green_timer_done <= '1' when
        (current_state = STATE_BLUE_GREEN) and
        (blue_green_count >= to_unsigned(GREEN_MAX, blue_green_count'length))
        else '0';

    -- define signal indicating when Purple Street green timer expires
    purple_green_timer_done <= '1' when
        (current_state = STATE_PURPLE_GREEN) and
        (purple_green_count >= to_unsigned(GREEN_MAX, purple_green_count'length))
        else '0';

    -- implement sequential green light timing logic for Blue Street (count by one-second intervals)
    process(clk, reset)
    begin
        -- IF reset has been activated
        if reset = '1' then
            blue_green_count <= (others => '0');                                        -- reset counter to 0
    
        -- IF clock is on rising edge and reset is not activated
        elsif rising_edge(clk) then
            -- If Blue Street is currently in the green state
            if current_state = STATE_BLUE_GREEN then
                -- IF a one-second tick occurs
                if one_second_tick = '1' then
                    -- IF count has NOT reached the 30-second limit
                    if blue_green_count < to_unsigned(GREEN_MAX, blue_green_count'length) then
                        blue_green_count <= blue_green_count + 1;                       -- add one second to the counter and continue
                    end if;
                end if;
    
            -- IF Blue Street is NOT in the green state
            else blue_green_count <= (others => '0');                                   -- reset counter to 0
            end if;
        end if;
    end process;

    -- implement sequential green light timing logic for Purple Street (count by one-second intervals)
    process(clk, reset)
    begin
        -- IF reset has been activated
        if reset = '1' then
            purple_green_count <= (others => '0');                                      -- reset counter to 0
    
        -- IF clock is on rising edge and reset is not activated
        elsif rising_edge(clk) then
            -- If Purple Street is currently in the green state
            if current_state = STATE_PURPLE_GREEN then
                -- IF a one-second tick occurs
                if one_second_tick = '1' then
                    -- IF count has NOT reached the 30-second limit
                    if purple_green_count < to_unsigned(GREEN_MAX, purple_green_count'length) then
                        purple_green_count <= purple_green_count + 1;                   -- add one second to the counter and continue
                    end if;
                end if;
    
            -- IF Purple Street is NOT in the green state
            else purple_green_count <= (others => '0');                                 -- reset counter to 0
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------------------------------------------
    ---------------------------------------- 4. SENSOR AND WAITING LOGIC ----------------------------------------
    -------------------------------------------------------------------------------------------------------------
    
    -------------------------- SENSOR DETECTION --------------------------
    
    -- determine whether Blue Street has vehicle detection from either direction
    blue_vehicle_detected <= blue_sensor_north or blue_sensor_south;
    
    -- determine whether Purple Street has vehicle detection from either direction
    purple_vehicle_detected <= purple_sensor_east or purple_sensor_west;
    
    -------------------------- SENSOR RELEVANCE --------------------------
    
    -- define Blue Street waiting condition (vehicle detected while Purple Street is green)
    blue_waiting_condition <= '1' when
        (blue_vehicle_detected = '1') and
        (current_state = STATE_PURPLE_GREEN)
        else '0';

    -- define Purple Street waiting condition (vehicle detected while Blue Street is green)
    purple_waiting_condition <= '1' when
        (purple_vehicle_detected = '1') and
        (current_state = STATE_BLUE_GREEN)
        else '0';

    ------------------------- BLUE WAITING TIMER -------------------------
    
    -- implement sequential blue waiting timing logic (count by one-second intervals)
    process(clk, reset)
    begin
        -- IF reset has been activated
        if reset = '1' then
            blue_waiting_count <= (others => '0');                                      -- reset counter to 0
    
        -- IF the clock is on its rising edge
        elsif rising_edge(clk) then
            -- IF the Blue Street waiting condition is active
            if blue_waiting_condition = '1' then
                -- IF a one-second tick occurs
                if one_second_tick = '1' then
                    -- IF count has NOT reached the 10-second limit
                    if blue_waiting_count < BLUE_WAITING_MAX then
                        blue_waiting_count <= blue_waiting_count + 1;                   -- add one second to the counter and continue
                    end if;
                    
                    -- once the counter reaches 10 sec, it is not assigned a new value
                    -- therefore, it will remain unchanged until purple_waiting_condition is false
                end if;
    
            -- IF the Blue Street waiting condition has NOT been met
            else blue_waiting_count <= (others => '0');                                 -- reset counter to 0
            end if;
        end if;
    end process;

    ------------------------ PURPLE WAITING TIMER ------------------------
    
    -- implement sequential purple waiting timing logic (count by one-second intervals)
    process(clk, reset)
    begin
        -- IF reset has been activated
        if reset = '1' then
            purple_waiting_count <= (others => '0');                                    -- reset counter to 0
    
        -- IF the clock is on its rising edge
        elsif rising_edge(clk) then
            -- IF the Purple Street waiting condition is active
            if purple_waiting_condition = '1' then
                -- IF a one-second tick occurs
                if one_second_tick = '1' then
                    -- IF count has NOT reached the 10-second limit
                    if purple_waiting_count < PURPLE_WAITING_MAX then
                        purple_waiting_count <= purple_waiting_count + 1;               -- add one second to the counter and continue
                    end if;
                    
                    -- once the counter reaches 10 sec, it is not assigned a new value
                    -- therefore, it will remain unchanged until blue_waiting_condition is false
                end if;
    
            -- IF the Purple Street waiting condition has NOT been met
            else purple_waiting_count <= (others => '0');                               -- reset counter to 0
            end if;
        end if;
    end process;

    ------------------------ CONTINUOUS DETECTION ------------------------
    
    -- Maintain continuous Blue Street detection while Purple Street is GREEN.
    -- Reset Blue waiting timer if the Blue waiting condition is interrupted.
    
    -- Maintain continuous Purple Street detection while Blue Street is GREEN.
    -- Reset Purple waiting timer if the Purple waiting condition is interrupted.

    -------------------------------------------------------------------------------------------------------------
    ------------------------------------------ 5. FSM NEXT-STATE LOGIC ------------------------------------------
    -------------------------------------------------------------------------------------------------------------

    -- combinational logic determines the next state
    process(current_state, all_red_count, purple_waiting_count,
            blue_green_timer_done, yellow_count,
            blue_waiting_count, purple_green_timer_done)
    begin
        -- DEFAULT: remain in the current state if no transition occurs
        next_state <= current_state;

        case current_state is
            -- ALL-RED: allow 2 seconds before Blue Street turns green
            when STATE_ALL_RED_TO_BLUE =>
                if all_red_count >= to_unsigned(ALL_RED_MAX, all_red_count'length) then
                    next_state <= STATE_BLUE_GREEN;
                end if;

            -- BLUE GREEN: switch when Purple Street has waited 10 seconds
            -- OR Blue Street's 30-second green limit expires
            when STATE_BLUE_GREEN =>
                if (purple_waiting_count >= PURPLE_WAITING_MAX)
                    or (blue_green_timer_done = '1') then
                    next_state <= STATE_BLUE_YELLOW;
                end if;

            -- BLUE YELLOW: allow 3 seconds before ALL-RED
            when STATE_BLUE_YELLOW =>
                if yellow_count >= to_unsigned(YELLOW_MAX, yellow_count'length) then
                    next_state <= STATE_ALL_RED_TO_PURPLE;
                end if;
            
            -- ALL-RED: allow 2 seconds before Purple Street turns green
            when STATE_ALL_RED_TO_PURPLE =>
                if all_red_count >= to_unsigned(ALL_RED_MAX, all_red_count'length) then
                    next_state <= STATE_PURPLE_GREEN;
                end if;

            -- PURPLE GREEN: switch when Blue Street has waited 10 seconds
            -- OR Purple Street's 30-second green limit expires
            when STATE_PURPLE_GREEN =>
                if (blue_waiting_count >= BLUE_WAITING_MAX)
                    or (purple_green_timer_done = '1') then
                    next_state <= STATE_PURPLE_YELLOW;
                end if;

            -- PURPLE YELLOW: allow 3 seconds before ALL-RED
            when STATE_PURPLE_YELLOW =>
                if yellow_count >= to_unsigned(YELLOW_MAX, yellow_count'length) then
                    next_state <= STATE_ALL_RED_TO_BLUE;
                end if;

            -- DEFAULT: start state is ALL_RED_TO_BLUE
            -- much like C++/Java, VHDL requires a default case (others)
            when others => next_state <= STATE_ALL_RED_TO_BLUE;
        end case;
    end process;

    -- implement sequential logic that updates current_state on the positive clock edge
    process(clk, reset)
    begin
        -- IF reset has been activated
        if reset = '1' then current_state <= STATE_ALL_RED_TO_BLUE;
    
        -- IF reset is not activated, update on the rising clock edge
        elsif rising_edge(clk) then current_state <= next_state;
        end if;
    end process;

   --------------------- ELAPSED SECONDS COUNTER ---------------------

    process(clk, reset)
    begin
        if reset = '1' then
            elapsed_seconds <= (others => '0');
            previous_state  <= STATE_ALL_RED_TO_BLUE;

        elsif rising_edge(clk) then
            -- Reset elapsed time when a new phase begins
            if current_state /= previous_state then
                elapsed_seconds <= (others => '0');
                previous_state  <= current_state;

            -- Increment once per second
            elsif one_second_tick = '1' and elapsed_seconds < 59 then
                elapsed_seconds <= elapsed_seconds + 1;
            end if;
        end if;
    end process;

    --------------------- DISPLAY REFRESH COUNTER ---------------------

    process(clk, reset)
    begin
        if reset = '1' then
            refresh_counter <= (others => '0');

        elsif rising_edge(clk) then
            refresh_counter <= refresh_counter + 1;
        end if;
    end process;

    -------------------- DECIMAL DIGIT CONVERSION ---------------------

    elapsed_ones <= to_unsigned(to_integer(elapsed_seconds) mod 10, 4);
    elapsed_tens <= to_unsigned((to_integer(elapsed_seconds) / 10) mod 10, 4);

    --------------------- DISPLAY DIGIT SELECTION ---------------------

    process(refresh_counter, elapsed_ones, elapsed_tens)
    begin
        -- DEFAULT: all digits disabled
        an <= "1111";
        display_digit <= (others => '0');

        case refresh_counter(19 downto 18) is
            when "00" =>
                an <= "1110";  -- rightmost digit
                display_digit <= elapsed_ones;

            when "01" =>
                an <= "1101";
                display_digit <= elapsed_tens;

            when "10" =>
                an <= "1011";
                display_digit <= to_unsigned(0, 4);

            when "11" =>
                an <= "0111";  -- leftmost digit
                display_digit <= to_unsigned(0, 4);

            when others =>
                an <= "1111";
                display_digit <= (others => '0');
        end case;
    end process;
                                                      
    -------------------------------------------------------------------------------------------------------------
    ------------------------------------------- 6. FSM OUTPUT LOGIC ---------------------------------------------
    -------------------------------------------------------------------------------------------------------------

    -- set traffic light outputs based on the current state
    process(current_state)
    begin
        -- DEFAULT: all outputs are off
        blue_green    <= '0';
        blue_yellow   <= '0';
        blue_red      <= '0';
        purple_green  <= '0';
        purple_yellow <= '0';
        purple_red    <= '0';

        case current_state is
            -- ALL_RED_TO_BLUE: Blue Street = RED, Purple Street = RED
            when STATE_ALL_RED_TO_BLUE =>
                blue_red  <= '1';
                purple_red <= '1';

            -- BLUE_GREEN: Blue Street = GREEN, Purple Street = RED
            when STATE_BLUE_GREEN =>
                blue_green <= '1';
                purple_red <= '1';

            -- BLUE_YELLOW: Blue Street = YELLOW, Purple Street = RED
            when STATE_BLUE_YELLOW =>
                blue_yellow <= '1';
                purple_red  <= '1';

            -- ALL_RED_TO_PURPLE: Blue Street = RED, Purple Street = RED
            when STATE_ALL_RED_TO_PURPLE =>
                blue_red   <= '1';
                purple_red <= '1';

            -- PURPLE_GREEN: Blue Street = RED, Purple Street = GREEN
            when STATE_PURPLE_GREEN =>
                blue_red     <= '1';
                purple_green <= '1';

            -- PURPLE_YELLOW: Blue Street = RED, Purple Street = YELLOW
            when STATE_PURPLE_YELLOW =>
                blue_red      <= '1';
                purple_yellow <= '1';

            -- DEFAULT: Blue Street = RED, Purple Street = RED
            when others =>
                blue_red   <= '1';
                purple_red <= '1';
        end case;
    end process;

    -- set waiting indicator outputs based on the current state
    process(blue_waiting_condition, purple_waiting_condition)
    begin
        -- DEFAULT: both waiting indicators are off
        blue_waiting   <= '0';
        purple_waiting <= '0';
    
        -- Blue Street waiting
        if blue_waiting_condition = '1' then
            blue_waiting <= '1';
        end if;
    
        -- Purple Street waiting
        if purple_waiting_condition = '1' then
            purple_waiting <= '1';
        end if;
    end process;

    --------------------- SEVEN-SEGMENT DECODER ---------------------

    process(display_digit)
    begin
        dp <= '1';  -- Decimal point off

        case to_integer(display_digit) is
            when 0 => seg <= "1000000";
            when 1 => seg <= "1111001";
            when 2 => seg <= "0100100";
            when 3 => seg <= "0110000";
            when 4 => seg <= "0011001";
            when 5 => seg <= "0010010";
            when 6 => seg <= "0000010";
            when 7 => seg <= "1111000";
            when 8 => seg <= "0000000";
            when 9 => seg <= "0010000";
            when others => seg <= "1111111";
        end case;
    end process;
end Behavioral;
