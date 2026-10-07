// VERILOG TRAFFIC CONTROLLER

`timescale 1ns / 1ps

/***************** 1. MODULE DECLARATION & I/O *****************/
// port declaration: define inputs and outputs
module traffic_controller(
  // INPUTS: clock and reset signals
  input  wire  clk,                // FPGA clock signal
  input  wire  reset,              // reset signal

  // INPUTS: 4 Hall sensors
  input  wire  blue_sensor_north,  // Blue Street, Northmost sensor (Southbound)
  input  wire  blue_sensor_south,  // Blue Street, Southmost sensor (Northbound)
  input  wire  purple_sensor_east, // Purple Street, Eastmost sensor (Westbound)
  input  wire  purple_sensor_west, // Purple Street, Westmost sensor (Eastbound)

  // OUTPUTS: 8 LEDs (2 red, 2 yellow, 2 green, 2 waiting indicators)
  output wire  blue_green,         // BLUE: green;  PURPLE: red
  output wire  blue_yellow,        // BLUE: yellow; PURPLE: red
  output wire  blue_red,           // BLUE: red;    PURPLE: red (before transition to PURPLE_GREEN)
  output wire  purple_green,       // BLUE: red;    PURPLE: green
  output wire  purple_yellow,      // BLUE: red;    PURPLE: yellow
  output wire  purple_red,         // BLUE: red;    PURPLE: red (before transition to BLUE_GREEN)
  output wire  blue_waiting,       // blue waiting indicator
  output wire  purple_waiting      // purple waiting indicator
);

/***************** 2. FSM STATE DEFINITIONS & ARCHITECTURE *****************/
* ALL_RED_TO_BLUE
* BLUE_GREEN
* BLUE_YELLOW
* ALL_RED_TO_PURPLE
* PURPLE_GREEN
* PURPLE_YELLOW
  // define unique binary encodings for each state; start state: ALL_RED_TO_BLUE
  parameter ALL_RED_TO_BLUE   = 3'b000;   // ALL_RED_TO_BLUE   = 0b000
  parameter BLUE_GREEN        = 3'b001;   // BLUE_GREEN        = 0b001
  parameter BLUE_YELLOW       = 3'b010;   // BLUE_YELLOW       = 0b010
  parameter ALL_RED_TO_PURPLE = 3'b011;   // ALL_RED_TO_PURPLE = 0b011
  parameter PURPLE_GREEN      = 3'b100;   // PURPLE_GREEN      = 0b100
  parameter PURPLE_YELLOW     = 3'b101;   // PURPLE_YELLOW     = 0b101
  
  // define physical state registers (3 bits wide for 6 states)
  reg [2:0] current_state;
  reg [2:0] next_state;

endmodule

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
