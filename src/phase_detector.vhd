-------------------------------------------------------------------------------
--
-- phase detector description 
--
-- external ports: 
-- reset : resets logic to a known state all registers and counters are reset 
--         to zero
--
-- clock : high speed sampling clock used to run all the PLL modules, phase
--         detector, nco, all digital pll logic.
--
-- ref_clk : asynchronous clock input, this needs to be synchronized to clock
--
-- nco_clk : this is synchronous to clock and is the same approximate freq as
--           ref_clk. this is the clock from the nco that the phase detector
--           is trying to determin the error to. 
--
-- phase_error: this is a phase error that indicates how early or late the nco 
--           clock is from the ref_clk. if the ref clk is early this is a positive 
--           count value. If the ref_clk is late with respect to the nco clock, 
--           this value is negative. This value is based on a up-down counter
--           that counts up when the ref_clk is early and down when the ref_clk
--           is late. The counters are enabled when the rising edge of ref_clk
--           or nco_clk. 
--
-- internal signals:
-- nco_early: if the nco_clk risging edge occurs and the ref_clk is zero this 
--            signal is set high, once the ref_clk rising edge occurs this signal
--            is set to low. 
--
-- ref_early: if the ref_clk risging edge occurs and the nco_clk is zero this 
--            signal is set high, once the nco_clk rising edge occurs this signal
--            is set to low. 
--
-- counter:   this counter is limited buy number of bits in the counter to 2^PDW - 1
--            and its negative value -2^PDW - 1. The counter counts up when ref_early
--            is set and counts down when nco_early is set. It does not count
--            if both or neither are set. 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity phase_detector is
    generic (
        PDW : integer := 24
    );
    port (
        reset           : in  std_logic;
        clock           : in  std_logic;
        ref_clk         : in  std_logic; -- async input 
        nco_clk         : in  std_logic;
        phase_error     : out std_logic_vector(PDW-1 downto 0);
        phase_error_en  : out std_logic
    );
end entity phase_detector;

architecture rtl of phase_detector is

    signal ref_clk_r    : std_logic_vector(1 downto 0) := (others => '0');
    signal nco_clk_r    : std_logic;
    signal nco_early    : std_logic;
    signal ref_early    : std_logic;
    signal ref_early_r  : std_logic; 
    signal nco_early_r  : std_logic; 
    signal count_stop_r : std_logic; 
    signal count_stop   : std_logic; 
    signal counter      : integer := 0;
begin

    -- Synchronize ref_clk to the clock and phase detection counter enables
    process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                ref_early   <= '0';
                nco_early   <= '0';
                ref_early_r <= '0'; 
                nco_early_r <= '0';
                ref_clk_r   <= (others => '0');
                nco_clk_r   <= '0';
                phase_error_en  <= '0';
                count_stop  <= '0';
                count_stop_r <= '0';
            else
                -- shift registers to sync ref clk to sampling clock
                -- and to detect rising edge fo ref clk
                ref_clk_r   <= ref_clk_r(0) & ref_clk ; -- sync input
                
                -- register to detect rising edge of clk.
                nco_clk_r   <= nco_clk ;

                -- assumes nco clock is high for 1/2 cycle. 
                if (ref_clk_r(1) = '0' and ref_clk_r(0) = '1' and nco_early = '0' and nco_clk = '0') then  
                    ref_early       <= '1';
                elsif (nco_clk = '1') then 
                    ref_early       <= '0';
                end if; 

                if ( nco_clk_r = '0' and nco_clk = '1' and ref_early = '0' and ref_clk = '0') then  
                    nco_early       <= '1';
                elsif (ref_clk = '1') then 
                    nco_early       <= '0';
                end if; 
                
                ref_early_r     <= ref_early ;
                nco_early_r     <= nco_early ;

                -- falling edge of either early signals
                -- falling edge of early is caused by the detection of the opposite clock rising edge
                -- or the end of the detection time.
                if ((ref_early = '0' and ref_early_r = '1') OR
                    (nco_early = '0' and nco_early_r = '1')) then 
                        count_stop  <= '1';
                else
                        count_stop  <= '0';
                end if; 

                -- drive enable to signal downstream compoenents that 
                -- enable output is valid and updated. 
                if (count_stop = '1') then
                    phase_error_en  <= '1';
                elsif phase_error_en = '1' then 
                    phase_error_en  <= '0';
                end if; 
            end if;
        end if;
    end process;


    -- Update phase error counter
    process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                counter <= 0;
                phase_error <= (others => '0');

            -- check for over flow and under flow conditions in counter
            elsif (ref_early = '1' and counter < (2**(PDW-2))-1) then
                counter <= counter + 1;
            elsif (nco_early = '1' and counter > -(2**(PDW-2))+1)then
                counter <= counter - 1;
            
            elsif (count_stop = '1') then
                counter <= 0;
                phase_error <= std_logic_vector(to_signed(counter, PDW));
            end if;
        end if;
    end process;

    -- Output phase error
    --phase_error <= std_logic_vector(to_signed(counter, BIPDWTS));

end architecture rtl;





