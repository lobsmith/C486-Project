# FPGA Traffic Controller
## 1. Project Overview
This project implements a four-way traffic controller using an FPGA. The controller manages traffic lights for two intersecting streets (Blue Street and Purple Street)
using a finite state machine (FSM), timing logic, and Hall-effect sensors.

The project implements the controller in both Verilog and VHDL to compare the two hardware description languages under equivalent functional requirements.

Hardware platform:
- FPGA board: Digilent Basys 3
- FPGA device: AMD Xilinx Artix-7 XC7A35T
- FPGA part number: `xc7a35tcpg236-1`
- Clock frequency: 100 MHz
- Development software: AMD Vivado

## 2. Inputs & Outputs
### Inputs
- `clk`: FPGA system clock
- `reset`: Resets the controller
- `blue_sensor_north`: Hall-effect sensor on Blue Street
- `blue_sensor_south`: Hall-effect sensor on Blue Street
- `purple_sensor_east`: Hall-effect sensor on Purple Street
- `purple_sensor_west`: Hall-effect sensor on Purple Street
### Outputs
- `blue_red`: Blue Street red light
- `blue_yellow`: Blue Street yellow light
- `blue_green`: Blue Street green light
- `purple_red`: Purple Street red light
- `purple_yellow`: Purple Street yellow light
- `purple_green`: Purple Street green light
- `blue_waiting`: Blue Street waiting indicator
- `purple_waiting`: Purple Street waiting indicator

The Hall-effect sensors detect vehicles using magnets attached to the model cars. The two sensors on each street are combined to determine whether a vehicle is detected on that street.

## 3. FSM States and Traffic Control
The controller uses six states:
- `ALL_RED_TO_BLUE`
- `BLUE_GREEN`
- `BLUE_YELLOW`
- `ALL_RED_TO_PURPLE`
- `PURPLE_GREEN`
- `PURPLE_YELLOW`

The normal state sequence is:

`ALL_RED_TO_BLUE`
  -> `BLUE_GREEN`
  -> `BLUE_YELLOW`
  -> `ALL_RED_TO_PURPLE`
  -> `PURPLE_GREEN`
  -> `PURPLE_YELLOW`
  -> `ALL_RED_TO_BLUE`

* The controller starts in `ALL_RED_TO_BLUE`, allowing Blue Street to receive the first green signal after the initial all-red interval.
* During a green phase, the controller monitors the sensors on the opposing street. If a vehicle is continuously detected on the red street for 10 seconds while the opposing street is green, the controller begins the transition to the other street.
* If vehicle detection is interrupted before the 10-second threshold, the waiting timer resets. A new continuous detection period is required.
* Yellow lights remain active for 3 seconds, followed by a 2-second all-red interval before the other street receives green.
* Waiting detection is only relevant during the opposing street's green phase. Sensor activity during yellow and all-red phases must not trigger the waiting timer.

## 4. Code Structure
The Verilog and VHDL implementations follow the same general architecture.
1. Module/Entity Declaration and I/O: Defines the clock, reset, sensor inputs, traffic-light outputs, and waiting indicators.
2. FSM State Definitions: Defines the six traffic states and their encodings.
3. Traffic Light Timing: Generates one-second timing intervals from the 100 MHz clock and tracks the required yellow and all-red durations.
4. Sensor and Waiting Logic: Combines the sensors for each street, qualifies vehicle detection according to the current state, and tracks continuous detection.
5. FSM Next-State Logic: Determines the next state using the current state, sensor conditions, and timing counters.
6. FSM Output Logic: Sets the traffic-light outputs according to the active state and controls the waiting indicators.

## 5. Files Included
The ZIP archive should contain the relevant project files, including:
- Vivado project file (`.xpr`), if included
- Verilog source file(s) (`.v`)
- VHDL source file(s) (`.vhd`)
- Basys 3 constraint file (`.xdc`)
- Any testbench files included with the submission
- This `README.txt` file

The Verilog and VHDL source files contain the corresponding implementations of the traffic controller. The XDC file assigns the top-level signals to physical FPGA pins.

## 6. Software Requirements
To build and run the project, use:
- AMD Vivado Design Suite with support for the Artix-7 FPGA family
- Digilent Basys 3 FPGA board
- A USB data cable compatible with the board's PROG USB port
The project can be synthesized and implemented in Vivado. Physical testing requires the FPGA board and appropriate hardware connections.

## 7. How to Open and Run the Project
### Open Project
1. Extract the ZIP archive to a local folder.
2. Open AMD Vivado.
3. Select File > Open Project.
4. Navigate to the extracted project folder and open the included `.xpr` file.
5. Confirm that the correct HDL source files and Basys 3 XDC constraint file are present.

If the ZIP contains source files but no `.xpr` project file, create a new RTL project in Vivado, add the appropriate HDL source files, and add the XDC file under Constraints.

### Select Implementation
1. Open the Sources window in Vivado.
2. Select the desired implementation, Verilog or VHDL.
3. Set the corresponding top-level module or entity as the design's top.
4. Confirm that the XDC pin assignments match the top-level signal names.
5. Confirm that the selected FPGA part is `xc7a35tcpg236-1`.
Only one traffic-controller implementation should be selected as the active top-level design when generating a bitstream.

### Build Design
1. In the Flow Navigator, select Run Synthesis.
2. Resolve any reported errors before continuing.
3. Select Run Implementation after synthesis completes.
4. Select Generate Bitstream.
5. Wait for Vivado to finish and confirm that the bitstream was generated successfully.

### Program the FPGA
1. Connect the Basys 3 to the computer using a USB data cable through the board's PROG USB port.
2. Power on the board.
3. In Vivado, open Hardware Manager.
4. Select Open Target > Auto Connect.
5. Confirm that the FPGA device is detected.
6. Select Program Device and choose the generated bitstream file.
7. Complete programming and verify the controller's behavior on the board.

## 8. Testing
The controller should be checked for the following behaviors:
- Correct startup sequence and initial all-red interval
- Correct traffic-light outputs in every FSM state
- Correct yellow and all-red timing intervals
- No transition when no vehicle is waiting
- No transition when vehicle detection ends before 10 seconds
- Transition after 10 seconds of continuous vehicle detection
- Reset of the waiting timer when detection is interrupted
- Correct behavior for both Blue Street and Purple Street
- Correct combination of the two sensors on each street
- No waiting-timer activation during yellow or all-red phases
The Verilog and VHDL implementations should be tested under equivalent conditions to support a fair comparison.

## 9. Additional Notes

* The project is designed for the Digilent Basys 3 board. Pin assignments must match the included XDC file, and physical sensor inputs must be connected according to the circuit's wiring configuration.
* The elapsed seconds display is a planned enhancement and should only be considered part of the implementation if the corresponding display logic and FPGA pin assignments are included in the submitted version.
* For successful execution, use the included Vivado project when available and ensure that the correct implementation is selected before generating the bitstream.
