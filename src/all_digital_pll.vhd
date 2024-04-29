-------------------------------------------------------------------------------
-- The nco instance generates an NCO output nco_clk based on the input clock clock.
-- The phase_detector instance compares the input clock clock with the NCO output 
-- nco_clk and generates a phase error phase_err.
-- The loop_filter instance processes the phase error and generates a control 
-- signal tune_ctrl to adjust the NCO frequency.
-- The clock enable signal clock_en is generated internally based on the input 
-- clock clock. The output clock clk_out is driven by the NCO output nco_clk.



library ieee;
use ieee.std_logic_1164.all;

entity all_digital_pll is
    port (
        reset       : in  std_logic;
        clock       : in  std_logic;
        ref_clk     : in  std_logic; 
        clk_out     : out std_logic
    );
end entity all_digital_pll;

architecture rtl of all_digital_pll is
    -- Constants for NCO
    constant CLOCK_FREQ   : real := 156.250e6; -- 
    constant TARGET_FREQ  : real := 1000.00;  -- 
    constant AW           : integer := 40;   -- 

    -- Constants for Loop Filter
    constant BETA         : std_logic_vector(3 downto 0) := "0000"; -- Porportional gain
    constant ALPHA        : std_logic_vector(3 downto 0) := "1111"; -- integrator gain

    -- Internal signals
    signal phase_err      : std_logic_vector(23 downto 0);
    signal tune_ctrl      : std_logic_vector(23 downto 0);
    signal nco_clk        : std_logic := '0';
    signal nco_clk_r      : std_logic := '0';

    signal clock_en       : std_logic := '0';

begin

    -- NCO instance
    nco_inst : entity work.nco
        generic map (
            CLOCK_FREQ  => CLOCK_FREQ,
            TARGET_FREQ => TARGET_FREQ,
            AW          => AW
        )
        port map (
            reset     => reset,
            clock     => clock,
            nco_clk   => nco_clk,
            tune_ctrl => tune_ctrl
        );

    -- Phase Detector instance
    phase_detector_inst : entity work.phase_detector
        port map (
            reset       => reset,
            clock       => clock,
            ref_clk     => ref_clk,
            nco_clk     => nco_clk,
            phase_error => phase_err
        );

    -- Loop Filter instance
    loop_filter_inst : entity work.loop_filter
        port map (
            reset      => reset,
            clock      => clock,
            clock_en   => clock_en,
            phase_err  => phase_err,
            beta       => BETA,
            alpha      => ALPHA,
            tune_ctrl  => tune_ctrl
        );

    -- Clock Enable Generation (optional)
    process (clock)
    begin
        if rising_edge(clock) then
            nco_clk_r     <= nco_clk;
            
            if reset = '1' then
                clock_en <= '0';
            else
                if nco_clk_r = '0' and nco_clk = '1'  then 
                    clock_en <= '1';
                else 
                    clock_en <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Output Clock
    clk_out <= nco_clk;

end architecture rtl;
