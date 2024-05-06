-------------------------------------------------------------------------------
--
-- loop_filter entity description 
-- from xapp854
--
-- generics:
-- none
--
-- external ports: 
-- reset : resets logic to a known state all registers and counters are reset 
--         to zero
--
-- clock : high speed sampling clock used to run all the nco logic
--
-- clock_en : clock enable signal run at DAC rate all clocked logic is enabled 
--            using this signal. 
--
-- phase_err : this is a input from the phase error detector, this std_logic vector
--         that is used as a signed value
--
-- beta : power of 2 1st order loop gain the error is shifted right to divide by 
--        1 based on this number 
--
-- alpha : power of 2 2nd order loop gain, the input to the integrator is shifted
--         right to divide by 2 based on this value. 
--
-- tune_ctrl: is a signed value that is converted to a 16 bit std_logic_vector output. 
--            this control word is output to the NCO entity. This is equal to tune_ctrl_d
--            after being registered. 
--
--
-- internal signals:
-- integrator: this is a 48 bit registered value of new_int.
--
-- integrator_d: this is a 48 bit logic input value that is equal to integrator +
--          phase_err input (as a signed value)
--
-- tune_ctrl_d: is the sumation of a1 and b1
--
-- b1:      this is the resultant value after the input phase_err signal is adjusted 
--          by the gain value of beta
--
-- a1:      this is the resultant value after the integrator_d has been adjusted 
--          (arithmetic right shift) by alpha
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity loop_filter is
    generic (
        PDW : integer := 24
    );
    port (
        reset       : in  std_logic;
        clock       : in  std_logic;
        clock_en    : in  std_logic;
        phase_err   : in  std_logic_vector(PDW-1 downto 0);
        beta        : in  std_logic_vector(3 downto 0);
        alpha       : in  std_logic_vector(3 downto 0);
        tune_ctrl   : out std_logic_vector(PDW-1 downto 0)
    );
end entity loop_filter;

architecture rtl of loop_filter is
    signal integrator    : signed(PDW+8-1 downto 0) := (others => '0');
    signal integrator_d  : signed(PDW+8-1 downto 0) := (others => '0');
    signal b1            : signed(PDW+8-1 downto 0);
    signal a1            : signed(PDW-1 downto 0);
    signal tune_ctrl_d   : signed(PDW+8-1 downto 0);
    signal tune_ctrl_sat : std_logic_vector(PDW-1 downto 0);
begin

    -- Integrator
    process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                integrator <= (others => '0');
            elsif  (clock_en = '1') then 
                    integrator <= integrator_d;
            end if;
        end if;
    end process;

    -- note: limits are not checked here, an over, under flow condition can
    -- exist
    integrator_d <= integrator + signed(phase_err);

    -- The proportional gain is increased until it reaches the ultimate gain 
    -- Ku at which the output of the loop starts to oscillate constantly. Ku 
    -- and the oscillation period Tu are used to set the gains as follows:
    -- P 	Kp=0.50 Ku; 
    -- PI 	Kp=0.45 Ku;  Ki=0.54 Ku / Tu 
    
    -- Calculate a1 (alpha gain) P gain, divide by power of 2
    -- a1 <= signed(phase_err) sra to_integer(unsigned(alpha));
    --debug only
    -- was performed with 34 bit tune and error 40bit accum
    --a1 <= signed(phase_err) sla 3; --6: just oscillates; 8: not stabel;  4: stable 1000Hz
    --a1 <= signed(phase_err) sla 3; -- works well for 1000 hz
    --a1 <= signed(phase_err) SRA 2; -- works well for 100 hz

    -- now use a 32 bit error values and 56 bit accum in nco. 
    a1 <= signed(phase_err) SLA 7; --  10 hz ; SLA 7 works well, 8,9 ph error ocillates -1,1



    -- Calculate a1 (beta gain) I gain, divide by power of 2
    --b1 <= integrator_d sla 1; -- to_integer(unsigned(beta));  -- for 1000Hz
    --b1 <= integrator_d sla 1; -- works well for 1000Hz
    -- b1 <= integrator_d SRA 5; -- works well for 100Hz, Tu ~8,9
    --b1 <= integrator_d SRA 10; -- works well for 100Hz, Tu ~4
    
    -- use 58bit accum and 32 bit error values
    b1 <= (others => '0');

    -- Output tune_ctrl_d, not checked for over,under flow
    tune_ctrl_d <= a1 + b1; 

    -- Output tune_ctrl (registered)
    process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                tune_ctrl <= (others => '0');
            elsif clock_en = '1' then
                        tune_ctrl <= std_logic_vector(tune_ctrl_sat);
            end if;
        end if;
    end process;


    -- limit the tune control output to signed 24 bits max / min 
    saturation_i : entity work.saturation
    generic map (
        ISIZE       =>  PDW+8 , 
        OSIZE       =>  PDW 
    ) port map (
        sat_in      => std_logic_vector(tune_ctrl_d),  --IN  STD_LOGIC_VECTOR(ISIZE-1 DOWNTO 0); -- 
        sat_out     => tune_ctrl_sat --OUT STD_LOGIC_VECTOR(OSIZE-1 DOWNTO 0)
    ) ;




end architecture rtl;


