-------------------------------------------------------------------------------
--
-- nco description 
--
-- generics:
-- CLOCK_FREQ : real type from 10MHz to 500MHz with default setting at 100MHz
--              this setting lets the entity know the frequency of clock 
--
-- TARGET_FREQ: real type from 0.0 to 100MHz, this is the NCO target frequency
--              based on clock frequency and a tune_ctrl word of zero
--
--
-- external ports: 
-- reset : resets logic to a known state all registers and counters are reset 
--         to zero
--
-- clock : high speed sampling clock used to run all the nco logic
--
-- nco_clk : this is a clock output from the MSB phase accumulator            
--
-- tune_ctrl : input as a std_logic vector, then used as a signed value, 
--             this is the control word (phase error signal) 
--             that adjusts the NCO up or down in frequency relative to the 
--             FREQ_CTRL. 
--
--
-- internal signals:
-- phase_acc: this is a phase accumulator that accumulates count values based
--           on the current accumulator value + FREQ_CTRL + tune_crl. The most
--           significant bit of this accumulator is used for the NCO clock.
--
-- FREQ_CTRL: this is a constant that is a signed value with bit length equal to 
--            "AW" the accumulator word length. It is equal to the TARGET_FREQ 
--            (type real) divided by CLOCK_FREQ (type real) then mulitiplied by (2^AW)


-- nco_early: if the nco_clk risging edge occurs and the ref_clk is zero this 
--            signal is set high, once the ref_clk rising edge occurs this signal
--            is set to low. 
--
-- ref_early: if the ref_clk risging edge occurs and the nco_clk is zero this 
--            signal is set high, once the nco_clk rising edge occurs this signal
--            is set to low. 
--
-- counter:   this counter is limited buy number of bits in the counter to 2^bits - 1
--            and its negative value -2^bits - 1. The counter counts up when ref_early
--            is set and counts down when nco_early is set. It does not count
--            if both or neither are set. 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity nco is
    generic (
        CLOCK_FREQ  : real range 10.0e6 to 500.0e6 := 100.0e6; -- Default clock frequency
        TARGET_FREQ : real range 0.0 to 100.0e6 := 1.0;        -- Default target frequency
        AW          : integer := 40;                            -- Default accumulator word length
        PDW         : integer := 32
    );
    port (
        reset     : in  std_logic;
        clock     : in  std_logic;
        nco_clk   : out std_logic;
        tune_ctrl : in  std_logic_vector(PDW-1 downto 0)
    );
end entity nco;

architecture rtl of nco is
    signal phase_acc : signed(AW-1 downto 0) := (others => '0');

    constant FREQ_CTRL_1 : real := (TARGET_FREQ*(2**AW) / CLOCK_FREQ); --AW is 56 bits and is outside the 32 bit integer width
    constant FREQ_CTRL_H : unsigned(23 downto 0) := to_unsigned(integer(FREQ_CTRL_1 / 2**32),24);
    constant FREQ_CTRL_L : unsigned(31 downto 0) := to_unsigned(integer(FREQ_CTRL_1 - (floor(FREQ_CTRL_1/(2**32))) * 2**32),32);
    -- from VALUE := X - (FLOOR(ABS(X)/ABS(Y)))*ABS(Y);
    constant FREQ_CTRL : signed(AW-1 downto 0) :=
                signed(std_logic_vector(FREQ_CTRL_H & FREQ_CTRL_L));

        --to_signed(natural(real(TARGET_FREQ) / real(CLOCK_FREQ) * 2.0**AW), AW); --AW is 56 bits and is outside the 32 bit integer width


    -- notes:
    --  freq ctrl  = (target freq)* 2^(acc word length)/ clock freq
    --  target freq = freq ctrl * clock freq / (2^acc word lenth)
    
begin

    process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                phase_acc <= (others => '0');
            else
                phase_acc <= phase_acc + FREQ_CTRL + signed(tune_ctrl);
            end if;
        end if;
    end process;
    
    -- invert so clk starts high this means that on nco accumulator rollover
    -- nco_clk has a rising edge. 
    nco_clk <= not phase_acc(AW-1); 

end architecture rtl;


