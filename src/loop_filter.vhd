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
    port (
        reset       : in  std_logic;
        clock       : in  std_logic;
        clock_en    : in  std_logic;
        phase_err   : in  std_logic_vector(23 downto 0);
        beta        : in  std_logic_vector(3 downto 0);
        alpha       : in  std_logic_vector(3 downto 0);
        tune_ctrl   : out std_logic_vector(23 downto 0)
    );
end entity loop_filter;

architecture rtl of loop_filter is
    signal integrator    : signed(31 downto 0) := (others => '0');
    signal integrator_d  : signed(31 downto 0) := (others => '0');
    signal b1            : signed(23 downto 0);
    signal a1            : signed(23 downto 0);
    signal tune_ctrl_d   : signed(23 downto 0);
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

    
    integrator_d <= integrator + signed(phase_err);

    -- Calculate b1 (beta gain) P gain 
    b1 <= signed(phase_err) sra 0; -- to_integer(unsigned(beta));

    -- Calculate a1 (alpha gain) I gain
    a1 <= resize(integrator_d sra 4, a1'length); -- was 6, to_integer(unsigned(alpha));

    -- Output tune_ctrl_d
    tune_ctrl_d <= signed(resize((a1 + b1), tune_ctrl_d'length));

    -- Output tune_ctrl (registered)
    process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                tune_ctrl <= (others => '0');
            elsif clock_en = '1' then
                        tune_ctrl <= std_logic_vector(tune_ctrl_d);
            end if;
        end if;
    end process;

end architecture rtl;


