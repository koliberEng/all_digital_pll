-- 
-- 
-- 

library ieee;
use ieee.std_logic_1164.all;

entity tb_adpll is
end entity tb_adpll;

architecture testbench of tb_adpll is
    -- Constants
    constant CLOCK_PERIOD   : time := 6.4 ns; -- Clock period (156.25 MHz)
    constant SIM_TIME       : time := 5000 ms; -- Simulation time
    constant TARGET_FREQ    : real := 10.0;
    constant TARGET_PERIOD  : real := 1.0 / TARGET_FREQ ;
    constant REF_PERIOD     : time := TARGET_PERIOD * 1.000000 sec;

    -- Signals
    signal reset       : std_logic := '1';
    signal clock       : std_logic := '0';
    signal ref_clk     : std_logic := '0';
    signal clk_out     : std_logic;

begin 
    -- Clock Process
    process begin
        --while now < SIM_TIME 
        loop
            clock <= not clock;
            wait for CLOCK_PERIOD / 2;
        end loop;
        --wait;
    end process;

    -- Ref_clk Process
    process
    begin
        --while now < SIM_TIME 
        wait for 1 us; -- add delay for phase mismatch on start. 
        loop
            ref_clk <= not ref_clk;
            -- not exactly 1000 hz to see pll try to match it
            --wait for 500.005 us; -- 1000 Hz frequency + dFreq
            wait for REF_PERIOD / 2; 
        end loop;
        --wait;
    end process;

    -- Stimulus Process
    process
    begin
        wait for 50 ns;
        reset <= '0'; -- Transition reset from high to low
        wait;
    end process;



    -- Instantiate the DUT
    DUT : entity work.all_digital_pll
        generic map (
            CLOCK_FREQ  => 156.25e6,
            TARGET_FREQ => TARGET_FREQ
        )
        port map (
            reset   => reset,
            clock   => clock,
            ref_clk => ref_clk,
            clk_out => clk_out
        );

    -- Add waveform outputs if needed

end architecture testbench;
