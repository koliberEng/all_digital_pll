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
    generic (
        CLOCK_FREQ  : real := 156.250e6;
        TARGET_FREQ : real := 1000.0
    );
    port (
        reset       : in  std_logic;
        clock       : in  std_logic;    -- sampling clock at CLOCK_FREQ
        ref_clk     : in  std_logic;    -- external low speed clock
        clk_out     : out std_logic     -- NCO clock produced by this module
    );
end entity all_digital_pll;

architecture rtl of all_digital_pll is
    -- Constants for NCO
    --constant CLOCK_FREQ     : real := 156.250e6;  -- any local clock on the board, 
    --constant TARGET_FREQ    : real := 1000.00;    -- low speed external clock 
    constant AW             : integer := 56;      -- the accumulator word width
    constant PDW            : integer := 32;      -- phase detector, tune_crl word width

    -- Constants for Loop Filter these are right shift values, this means 
    -- the phase error in the loop filter is divided by this as a power of 2
    -- 2**beta or 2** alpha
    constant ALPHA          : std_logic_vector(3 downto 0) := "0000"; -- porportional  gain
    constant BETA           : std_logic_vector(3 downto 0) := "0000"; -- integrator gain

    -- Internal signals 
    signal phase_err        : std_logic_vector(PDW-1 downto 0);
    signal tune_ctrl        : std_logic_vector(PDW-1 downto 0);
    signal nco_clk          : std_logic := '0';
    signal nco_clk_r        : std_logic := '0';
    signal phase_error_en   : std_logic := '0';

begin

    -- NCO instance
    nco_inst : entity work.nco
        generic map (
            CLOCK_FREQ  => CLOCK_FREQ,
            TARGET_FREQ => TARGET_FREQ,
            AW          => AW,
            PDW         => PDW
        )
        port map (
            reset       => reset,
            clock       => clock,
            nco_clk     => nco_clk,
            tune_ctrl   => tune_ctrl
        );

    -- Phase Detector instance
    phase_detector_inst : entity work.phase_detector
        generic map (
            PDW         => PDW
        ) port map (
            reset           => reset,
            clock           => clock,
            ref_clk         => ref_clk,
            nco_clk         => nco_clk,
            phase_error     => phase_err,
            phase_error_en  => phase_error_en
        );

    -- Loop Filter instance
    loop_filter_inst : entity work.loop_filter
        generic map (
            PDW         => PDW    
        ) port map (
            reset      => reset,
            clock      => clock,
            clock_en   => phase_error_en,
            phase_err  => phase_err,
            beta       => BETA,  -- I gain
            alpha      => ALPHA, -- P gain
            tune_ctrl  => tune_ctrl
        );

    clk_out <= nco_clk;

end architecture rtl;
