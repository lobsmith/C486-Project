// VERILOG TRAFFIC CONTROLLER

/***************** 1. MODULE DECLARATION & I/O *****************/
// port declaration: define inputs and outputs
module traffic_controller(
  // 6 switch inputs (4 Hall sensors, clock, reset)
  input  wire     clk,               // FPGA clock signal
  input  wire     reset,             // reset signal
  input  wire     hall_sensor[3:0],  // 4 Hall sensors

  // 8 LED outputs (2 red, 2 yellow, 2 green, 2 waiting indicators)
  output wire     blue_green,        // BLUE: green;  PURPLE: red
  output wire     blue_yellow,       // BLUE: yellow; PURPLE: red
  output wire     blue_red,          // BLUE: red;    PURPLE: red (before transition to PURPLE_GREEN)
  output wire     purple_green,      // BLUE: red;    PURPLE: green
  output wire     purple_yellow,     // BLUE: red;    PURPLE: yellow
  output wire     purple_red,        // BLUE: red;    PURPLE: red (before transition to BLUE_GREEN)
  output wire     blue_waiting,      // blue waiting indicator
  output wire     purple_waiting     // purple waiting indicator
);
endmodule

/***************** 2. FSM State Definitions & Architecture *****************/
* ALL_RED_TO_BLUE
* BLUE_GREEN
* BLUE_YELLOW
* ALL_RED_TO_PURPLE
* PURPLE_GREEN
* PURPLE_YELLOW

/***************** 3. Timing and Counters *****************/
* Clock divider / timing base
* Yellow light timer
* All-red timer
* Blue waiting timer
* Purple waiting timer

/***************** 4. Sensor and Waiting Logic *****************/
* Determine whether Blue Street has vehicle detection
* Determine whether Purple Street has vehicle detection
* Determine whether sensor inputs are relevant:
  * Only during GREEN/RED states
  * Ignore sensors during YELLOW/RED states
  * Ignore sensors during ALL-RED state
* Maintain continuous detection timers
* Reset timer when required detection is interrupted

/***************** 5. FSM Next-State Logic *****************/
### Determining Factors
  * Current state
  * Relevant sensor detection
  * Waiting timer
  * Yellow timer
  * All-red timer
### Full Structure
````
case current_state

    ALL_RED_TO_BLUE:
        wait for all-red timing
        → BLUE_GREEN

    BLUE_GREEN:
        if Purple has been continuously detected for 10 sec
            → BLUE_YELLOW
        otherwise
            → BLUE_GREEN

    BLUE_YELLOW:
        when yellow timer expires
            → ALL_RED_TO_PURPLE

    ALL_RED_TO_PURPLE:
        when all-red timer expires
            → PURPLE_GREEN

    PURPLE_GREEN:
        if Blue has been continuously detected for 10 sec
            → PURPLE_YELLOW
        otherwise
            → PURPLE_GREEN

    PURPLE_YELLOW:
        when yellow timer expires
            → ALL_RED_TO_BLUE
````

/***************** 6. FSM Output Logic *****************/
// Set traffic light outputs based on the current state.
````
ALL_RED_TO_BLUE
  Blue = RED
  Purple = RED

BLUE_GREEN
  Blue = GREEN
  Purple = RED

BLUE_YELLOW
  Blue = YELLOW
  Purple = RED

ALL_RED_TO_PURPLE
  Blue = RED
  Purple = RED

PURPLE_GREEN
  Blue = RED
  Purple = GREEN

PURPLE_YELLOW
  Blue = RED
  Purple = YELLOW

Waiting indicators
````
