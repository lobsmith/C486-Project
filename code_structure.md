# VHDL/Verilog Code Structure
## 1. Module/Entity Declaration & I/O
### Inputs
* Clock
* Reset
* Blue Street Hall sensors
* Purple Street Hall sensors
### Outputs
* Blue Street: Red, Yellow, Green
* Purple Street: Red, Yellow, Green
* Blue waiting indicator
* Purple waiting indicator
## 2. FSM State Definitions & Architecture
* ALL_RED_TO_BLUE
* BLUE_GREEN
* BLUE_YELLOW
* ALL_RED_TO_PURPLE
* PURPLE_GREEN
* PURPLE_YELLOW
## 3. Traffic Light Timing
* Clock divider / timing base
* Yellow light timer
* All-red timer
## 4. Sensor and Waiting Logic
* Blue Street sensor detection (ignore when irrelevant)
* Purple Street sensor detection (ignore when irrelevant)
* Blue waiting timer
* Purple waiting timer
* Continuous detection (reset when interrupted)
## 5. FSM Next-State Logic
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
## 6. FSM Output Logic
Set traffic light outputs based on the current state.
### Full Structure
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
