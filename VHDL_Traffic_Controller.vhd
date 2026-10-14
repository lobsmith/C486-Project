-- VHDL TRAFFIC CONTROLLER

library IEEE;                                    -- declare standard VHDL libraries
use IEEE.STD_LOGIC_1164.ALL;                     -- import digital logic (STD_LOGIC_VECTOR)
use IEEE.NUMERIC_STD.ALL;                        -- import standard numeric types and arithmetic operations (unsigned, signed)

-- `timescale 1ns / 1ps

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
        purple_waiting      : out STD_LOGIC     -- purple waiting indicator
    );
end traffic_controller;

architecture Behavioral of traffic_controller is
    
    -------------------------------------------------------------------------------------------------------------
    ---------------------------------- 2. FSM STATE DEFINITIONS & ARCHITECTURE ----------------------------------
    -------------------------------------------------------------------------------------------------------------
    
    -- define unique binary encodings for each state; start state: ALL_RED_TO_BLUE
    constant ALL_RED_TO_BLUE    = STD_LOGIC_VECTOR(2 downto 0) := "000";
    constant BLUE_GREEN         = STD_LOGIC_VECTOR(2 downto 0) := "001";
    constant BLUE_YELLOW        = STD_LOGIC_VECTOR(2 downto 0) := "010";
    constant ALL_RED_TO_PURPLE  = STD_LOGIC_VECTOR(2 downto 0) := "011";
    constant PURPLE_GREEN       = STD_LOGIC_VECTOR(2 downto 0) := "100";
    constant PURPLE_YELLOW      = STD_LOGIC_VECTOR(2 downto 0) := "101";

    -- define state registers (3 bits wide for 6 states)
    signal current_state : STD_LOGIC_VECTOR(2 downto 0);
    signal next_state    : STD_LOGIC_VECTOR(2 downto 0);

    -- Basys 3 runs on 100MHz clock (100 million cycles per second)
    -- define the 100,000,000 cycle limit using 27 bits
    constant CLOCK_MAX : INTEGER := 100000000;

    -- define internal timing register (27-bit register)
    signal count : STD_LOGIC_VECTOR(26 downto 0);

    -- generate a one-second timing tick (1-bit register)
    signal one_second_tick : STD_LOGIC;

begin
    
    -------------------------------------------------------------------------------------------------------------
    ----------------------------------------- 3. TRAFFIC LIGHT TIMING -------------------------------------------
    -------------------------------------------------------------------------------------------------------------

    -------------------------- CLOCK TIMER --------------------------
    
    -- implement sequential timing logic (producing one pulse per second)
    -- PROCESS executes when the clock has a rising edge or reset is activated
    process(clk, reset) begin
        if reset == '1' then
            count           <= (others <= 0);        -- reset counter to 0 (others <= '0' sets all bits to 0)
            one_second_tick <= '0';                  -- one-second signal turned off

        -- NORMAL OPERATION: IF clock is on rising edge and reset is not activated
        elsif rising_edge(clk) then
            -- DEFAULT: no one-second tick at the beginning of each clock cycle (1'b0)
            one_second_tick <= '0';

            -- IF count has reached the 100MHz limit (count == 99,999,999)
            if unsigned(count) = CLOCK_MAX - 1 then
                count           <= (others <= 0);    -- reset counter to 0
                one_second_tick <= '1';              -- produce one-second tick
            end
            
            -- IF count has NOT reached the 100MHz limit (count != 99,999,999)
            else then
                count <= std_logic_vector(unsigned(count) + 1);       -- add one cycle to the counter and continue
            end if
        end if
    end process;

end Behavioral;

--------------------------------------------------- END OF VHDL CODE ---------------------------------------------------

    -------------------------------------------------------------------------------------------------------------
    ----------------------------------------- 3. TRAFFIC LIGHT TIMING -------------------------------------------
    -------------------------------------------------------------------------------------------------------------
    
    -------------------------- CLOCK TIMER --------------------------

    -- implement sequential timing logic (producing one pulse per second)
    -- ALWAYS block executes when the clock has a rising edge or reset is activated
    always @(posedge clk or posedge reset) begin
        -- IF reset has been activated
        if (reset) begin
            count           <= 27'd0;        -- reset counter to 0
            one_second_tick <= 1'b0;         -- one-second signal turned off (1'b0)
        end

        -- NORMAL OPERATION: IF clock is on rising edge and reset is not activated
        else begin
            -- DEFAULT: no one-second tick at the beginning of each clock cycle (1'b0)
            one_second_tick <= 1'b0;

            -- IF count has reached the 100MHz limit (count == 99,999,999)
            if (count == CLOCK_MAX - 1) begin
                count           <= 27'd0;    -- reset counter to 0
                one_second_tick <= 1'b1;     -- produce one-second tick (1'b1)
            end
            
            -- IF count has NOT reached the 100MHz limit (count != 99,999,999)
            else begin
                count <= count + 1'b1;       -- add one cycle to the counter and continue
            end
        end
    end

    ------------------------ YELLOW LIGHT TIMER ------------------------

    -- define the 3-second yellow light limit using 2 bits
    parameter YELLOW_MAX = 2'd3;

    -- define internal yellow light timer register (2-bit register)
    reg [1:0] yellow_count;

    -- implement sequential yellow light timing logic (count by one-second intervals)
    always @(posedge clk or posedge reset) begin
        -- IF reset has been activated
        if (reset) yellow_count <= 2'd0;                                 -- reset counter to 0

        -- IF the machine is currently in a yellow light state
        else if ((current_state == BLUE_YELLOW) || (current_state == PURPLE_YELLOW)) begin
            -- IF one-second tick occurs
            if (one_second_tick) begin
                -- IF count has reached the 3-second limit
                if (yellow_count == YELLOW_MAX) yellow_count <= 2'd0;    -- reset counter to 0
                
                -- IF count has NOT reached the 3-second limit
                else yellow_count <= yellow_count + 1'b1;                -- add one second to the counter and continue
            end
        end

        -- IF the machine is NOT in a yellow light state
        else yellow_count <= 2'd0;                                       -- reset counter to 0
    end

    -------------------------- ALL-RED TIMER --------------------------
    
    -- define the 2-second all-red limit using 2 bits
    parameter ALL_RED_MAX = 2'd2;

    -- define internal all-red timer register (2-bit register)
    reg [1:0] all_red_count;

    -- implement sequential all-red timing logic (count by one-second intervals)
    always @(posedge clk or posedge reset) begin
        -- IF reset has been activated
        if (reset) all_red_count <= 2'd0;                                  -- reset counter to 0

        -- IF the machine is currently in an all-red state
        else if ((current_state == ALL_RED_TO_BLUE) || (current_state == ALL_RED_TO_PURPLE)) begin
            -- IF one-second tick occurs
            if (one_second_tick) begin
                -- IF count has reached the 2-second limit
                if (all_red_count == ALL_RED_MAX) all_red_count <= 2'd0;   -- reset counter to 0
                
                -- IF count has NOT reached the 2-second limit
                else all_red_count <= all_red_count + 1'b1;                -- add one second to the counter and continue
            end
        end

        -- IF the machine is NOT in an all-red state
        else all_red_count <= 2'd0;                                        -- reset counter to 0
    end

    ------------------------ GREEN LIGHT TIMER ------------------------
    
    -- define the 30-second yellow light limit using 6 bits
    parameter GREEN_MAX = 6'd30;

    -- define internal timer registers for each street (6 bits each)
    reg [5:0] blue_green_count;
    reg [5:0] purple_green_count;

    -- define signals indicating when each green timer expires
    wire blue_green_timer_done;
    wire purple_green_timer_done;
    assign blue_green_timer_done = (current_state == BLUE_GREEN) && (blue_green_count >= GREEN_MAX);
    assign purple_green_timer_done = (current_state == PURPLE_GREEN) && (purple_green_count >= GREEN_MAX);

    -- implement sequential green light timing logic for Blue Street (count by one-second intervals)
    always @(posedge clk or posedge reset) begin
        -- IF reset has been activated
        if (reset) blue_green_count <= 6'd0;                          -- reset counter to 0

        -- IF Blue Street is currently in the green state
        else if (current_state == BLUE_GREEN) begin
            -- IF one-second tick occurs
            if (one_second_tick) begin
                -- IF count has NOT reached the 30-second limit
                if (blue_green_count < GREEN_MAX)
                    blue_green_count <= blue_green_count + 1'b1;      -- add one second to the counter and continue
            end
        end

        -- IF Blue Street is NOT in the green state
        else blue_green_count <= 6'd0;                                -- reset counter to 0
    end

    -- implement sequential green light timing logic for Purple Street (count by one-second intervals)
    always @(posedge clk or posedge reset) begin
        -- IF reset has been activated
        if (reset) purple_green_count <= 6'd0;                        -- reset counter to 0
        
        -- IF Purple Street is currently in the green state
        else if (current_state == PURPLE_GREEN) begin
            -- IF one-second tick occurs
            if (one_second_tick) begin
                -- IF count has NOT reached the 30-second limit
                if (purple_green_count < GREEN_MAX)
                    purple_green_count <= purple_green_count + 1'b1;  -- add one second to the counter and continue
            end
        end
        
        -- IF Purple Street is NOT in the green state
        else purple_green_count <= 6'd0;                              -- reset counter to 0
    end
    
    -------------------------------------------------------------------------------------------------------------
    ---------------------------------------- 4. SENSOR AND WAITING LOGIC ----------------------------------------
    -------------------------------------------------------------------------------------------------------------
    
    -------------------------- SENSOR DETECTION --------------------------
    
    -- determine whether Blue Street has vehicle detection from either direction
    wire blue_vehicle_detected;
    assign blue_vehicle_detected = blue_sensor_north || blue_sensor_south;
    
    -- determine whether Purple Street has vehicle detection from either direction
    wire purple_vehicle_detected;
    assign purple_vehicle_detected = purple_sensor_east || purple_sensor_west;
    
    -------------------------- SENSOR RELEVANCE --------------------------
    
    -- define Blue Street waiting condition (vehicle detected while Purple Street is green)
    wire blue_waiting_condition;
    assign blue_waiting_condition = blue_vehicle_detected && (current_state == PURPLE_GREEN);

    -- define Purple Street waiting condition (vehicle detected while Blue Street is green)
    wire purple_waiting_condition;
    assign purple_waiting_condition = purple_vehicle_detected && (current_state == BLUE_GREEN);

    ------------------------- BLUE WAITING TIMER -------------------------
    
    -- define the 10-second Blue waiting limit using 4 bits
    parameter BLUE_WAITING_MAX = 4'd10;

    -- define internal blue waiting timer register (4-bit register)
    reg [3:0] blue_waiting_count;

    -- implement sequential blue waiting timing logic (count by one-second intervals)
    always @(posedge clk or posedge reset) begin
        -- IF reset has been activated
        if (reset) blue_waiting_count <= 4'd0;                          -- reset counter to 0

        -- IF the Blue Street waiting condition is active
        else if (blue_waiting_condition) begin
            -- IF one-second tick occurs
            if (one_second_tick) begin
                -- IF count has NOT reached the 10-second limit
                if (blue_waiting_count < BLUE_WAITING_MAX)
                    blue_waiting_count <= blue_waiting_count + 1'b1;    -- add one second to the counter and continue
                
                -- once the counter reaches 10 sec, it is not assigned a new value
                -- therefore, it will remain unchanged until blue_waiting_condition is false
            end
        end

        -- IF the Blue Street waiting condition has NOT been met
        else blue_waiting_count <= 4'd0;                                -- reset counter to 0
    end
    
    ------------------------ PURPLE WAITING TIMER ------------------------
    
    -- define the 10-second Purple waiting limit using 4 bits
    parameter PURPLE_WAITING_MAX = 4'd10;

    -- define internal Purple waiting timer register (4-bit register)
    reg [3:0] purple_waiting_count;

    -- implement sequential Purple waiting timing logic (count by one-second intervals)
    always @(posedge clk or posedge reset) begin
        -- IF reset has been activated
        if (reset) purple_waiting_count <= 4'd0;                          -- reset counter to 0

        -- IF the Purple Street waiting condition is active
        else if (purple_waiting_condition) begin
            -- IF one-second tick occurs
            if (one_second_tick) begin
                -- IF count has NOT reached the 10-second limit
                if (purple_waiting_count < PURPLE_WAITING_MAX)
                    purple_waiting_count <= purple_waiting_count + 1'b1;  -- add one second to the counter and continue
                
                -- once the counter reaches 10 sec, it is not assigned a new value
                -- therefore, it will remain unchanged until purple_waiting_condition is false
            end
        end

        -- IF the Purple Street waiting condition has NOT been met
        else purple_waiting_count <= 4'd0;                                -- reset counter to 0
    end
    
    ------------------------ CONTINUOUS DETECTION ------------------------
    
    -- Maintain continuous Blue Street detection while Purple Street is GREEN.
    -- Reset Blue waiting timer if the Blue waiting condition is interrupted.
    
    -- Maintain continuous Purple Street detection while Blue Street is GREEN.
    -- Reset Purple waiting timer if the Purple waiting condition is interrupted.

    -------------------------------------------------------------------------------------------------------------
    ------------------------------------------ 5. FSM NEXT-STATE LOGIC ------------------------------------------
    -------------------------------------------------------------------------------------------------------------

    always @(*) begin
        -- DEFAULT: remain in the current state if no transition occurs
        next_state = current_state;

        case (current_state)
            -- ALL-RED: allow 2 seconds before Blue Street turns green
            ALL_RED_TO_BLUE: begin
                if (all_red_count >= ALL_RED_MAX)
                    next_state = BLUE_GREEN;
            end

            -- BLUE GREEN: switch when Purple Street has waited 10 seconds
            -- OR Blue Street's 30-second green limit expires
            BLUE_GREEN: begin
                if ((purple_waiting_count >= PURPLE_WAITING_MAX) || blue_green_timer_done)
                    next_state = BLUE_YELLOW;
            end

            -- BLUE YELLOW: allow 3 seconds before ALL-RED
            BLUE_YELLOW: begin
                if (yellow_count >= YELLOW_MAX)
                    next_state = ALL_RED_TO_PURPLE;
            end
            
            -- ALL-RED: allow 2 seconds before Purple Street turns green
            ALL_RED_TO_PURPLE: begin
                if (all_red_count >= ALL_RED_MAX)
                    next_state = PURPLE_GREEN;
            end

            -- PURPLE GREEN: switch when Blue Street has waited 10 seconds
            -- OR Purple Street's 30-second green limit expires
            PURPLE_GREEN: begin
                if ((blue_waiting_count >= BLUE_WAITING_MAX) || purple_green_timer_done)
                    next_state = PURPLE_YELLOW;
            end

            -- PURPLE YELLOW: allow 3 seconds before ALL-RED
            PURPLE_YELLOW: begin
                if (yellow_count >= YELLOW_MAX)
                    next_state = ALL_RED_TO_BLUE;
            end

            -- DEFAULT: start state is ALL_RED_TO_BLUE
            -- much like C++/Java, Verilog requires a default case
            default: next_state = ALL_RED_TO_BLUE;
        endcase
    end

    -- implement sequential logic that updates current_state on the positive clock edge
    always @(posedge clk or posedge reset) begin
        if (reset) current_state <= ALL_RED_TO_BLUE;
        else       current_state <= next_state;
    end

    -------------------------------------------------------------------------------------------------------------
    ------------------------------------------- 6. FSM OUTPUT LOGIC ---------------------------------------------
    -------------------------------------------------------------------------------------------------------------

    -- set traffic light outputs based on the current state
    always @(*) begin
        -- DEFAULT: all outputs are off
        blue_green     = 1'b0;
        blue_yellow    = 1'b0;
        blue_red       = 1'b0;
        purple_green   = 1'b0;
        purple_yellow  = 1'b0;
        purple_red     = 1'b0;

        case (current_state)
            -- ALL_RED_TO_BLUE: Blue Street = RED, Purple Street = RED
            ALL_RED_TO_BLUE: begin
                blue_red = 1'b1;
                purple_red = 1'b1;
            end

            -- BLUE_GREEN: Blue Street = GREEN, Purple Street = RED
            BLUE_GREEN: begin
                blue_green = 1'b1;
                purple_red = 1'b1;
            end

            -- BLUE_YELLOW: Blue Street = YELLOW, Purple Street = RED
            BLUE_YELLOW: begin
                blue_yellow = 1'b1;
                purple_red = 1'b1;
            end

            -- ALL_RED_TO_PURPLE: Blue Street = RED, Purple Street = RED
            ALL_RED_TO_PURPLE: begin
                blue_red = 1'b1;
                purple_red = 1'b1;
            end

            -- PURPLE_GREEN: Blue Street = RED, Purple Street = GREEN
            PURPLE_GREEN: begin
                blue_red = 1'b1;
                purple_green = 1'b1;
            end

            -- PURPLE_YELLOW: Blue Street = RED, Purple Street = YELLOW
            PURPLE_YELLOW: begin
                blue_red = 1'b1;
                purple_yellow = 1'b1;
            end

            -- DEFAULT: Blue Street = RED, Purple Street = RED
            default: begin
                blue_red = 1'b1;
                purple_red = 1'b1;
            end
        endcase
    end

    -- set waiting indicator outputs based on the current state
    always @(*) begin
        -- DEFAULT: both waiting indicators are off
        blue_waiting   = 1'b0;
        purple_waiting = 1'b0;

        -- Blue Street waiting
        if (blue_waiting_condition) blue_waiting = 1'b1;

        -- Purple Street waiting
        if (purple_waiting_condition) purple_waiting = 1'b1;
    end
endmodule
