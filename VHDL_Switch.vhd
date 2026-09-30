library IEEE;                                    -- declare standard VHDL libraries
use IEEE.STD_LOGIC_1164.ALL;                     -- import digital logic (STD_LOGIC_VECTOR)

-- port declaration section, VHDL uses "Port"
entity switch_led is
    Port (
        sw  : in  STD_LOGIC_VECTOR(3 downto 0);  -- 4 switch inputs
        led : out STD_LOGIC_VECTOR(3 downto 0)   -- 4 LED outputs
    );
end switch_led;

-- architecture section defines how the component works
architecture Behavioral of switch_led is
begin
    -- connect AND, OR, NOT gates to LEDs
    led(0) <= sw(0) and sw(1);                   -- AND gate - connect to LED 0
    led(1) <= sw(0) or sw(1);                    -- OR gate - connect to LED 1
    led(2) <= not sw(2);                         -- inverter - connect to LED 2
    led(3) <= sw(2) and not sw(3);               -- AND gate with inverted input -
                                                 -- connect to LED 3
end Behavioral;
