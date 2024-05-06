-------------------------------------------------------------------------------
-- verilog version:
--
-- module sat (
--      sat_in, 
--      sat_out
--  );
--
--  parameter IN_SIZE = 21; // Default is to saturate 22 bits to 21 bits
--  parameter OUT_SIZE = 20;
--  input [IN_SIZE:0]       sat_in;
--  output reg [OUT_SIZE:0] sat_out;
--
--  wire [OUT_SIZE:0] max_pos = {1'b0,{OUT_SIZE{1'b1}}};
--  wire [OUT_SIZE:0] max_neg = {1'b1,{OUT_SIZE{1'b0}}};
--
-- always @* 
-- begin
--      // Are the bits to be saturated + 1 the same?
--      if ((sat_in[IN_SIZE:OUT_SIZE]=={IN_SIZE-OUT_SIZE+1{1'b0}}) ||
--          (sat_in[IN_SIZE:OUT_SIZE]=={IN_SIZE-OUT_SIZE+1{1'b1}}))
--              sat_out = sat_in[OUT_SIZE:0];
--      else if (sat_in[IN_SIZE]) // neg underflow. go to max neg
--              sat_out = max_neg;
--      else // pos overflow, go to max pos
--              sat_out = max_pos;
--      end
-- endmodule

-------------------------------------------------------------------------------
-- saturation logic. given a value and a bit width (size) the input is 
-- limited to the saturated limit (power of 2)


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY saturation IS
    GENERIC (
        -- ISIZE is the upper index limit -1 therefore the bit vector is ISIZE 
        -- OSIZE is the upper index limit -1 therefore the bit vector is OSIZE
        ISIZE      : INTEGER := 21 ; -- default is to saturate 21 bits to 20 bits
        OSIZE      : INTEGER := 20 
    ) ;
    PORT (
        sat_in      : IN  STD_LOGIC_VECTOR(ISIZE-1 DOWNTO 0); -- 
        sat_out     : OUT STD_LOGIC_VECTOR(OSIZE-1 DOWNTO 0)
    ) ; 
END saturation ; 

ARCHITECTURE behave OF saturation IS

-------------------------------------------------------------------------------
function AND_REDUCE(slv : in STD_LOGIC_VECTOR) return STD_LOGIC is
    variable res_v : STD_LOGIC := '1';  -- Null slv vector will return '1'
begin
  for i in slv'range loop
    res_v := res_v AND slv(i);
  end loop;
  return res_v;
end function ;
-------------------------------------------------------------------------------
function OR_REDUCE(ARG: STD_LOGIC_VECTOR) return STD_LOGIC is
    variable result: STD_LOGIC := '0' ;
begin
	result := '0' ;
	for i in ARG'range loop
	    result := result OR ARG(i) ;
	end loop ;
    return result ;
end function ;
-------------------------------------------------------------------------------

    SIGNAL max_pos  : STD_LOGIC_VECTOR(OSIZE-1 DOWNTO 0);
    SIGNAL max_neg  : STD_LOGIC_VECTOR(OSIZE-1 DOWNTO 0);
    
BEGIN 


    max_pos(max_pos'LEFT)             <= '0' ;            -- sign bit 
    max_pos(max_pos'LEFT-1 DOWNTO 0)  <= (others => '1') ;-- remaining bits 
    max_neg(max_neg'LEFT)             <= '1' ;            -- sign bit 
    max_neg(max_neg'LEFT-1 DOWNTO 0)  <= (others => '0') ;-- remaining bits     
    
    
-- if ISIZE = 18 and OSIZE = 12 then input(17:11) <7 bits>
-- equals 18-12+1 = 7 replicated zeros (same for ones to test for neg
-- value.
sat_test : PROCESS ( sat_in )
BEGIN
    IF  (OR_REDUCE(sat_in(ISIZE-1 DOWNTO OSIZE-1)) = '0')  OR
        (AND_REDUCE(sat_in(ISIZE-1 DOWNTO OSIZE-1)) = '1') THEN
                -- not saturated, normal operation
                sat_out     <= sat_in(OSIZE-1 DOWNTO 0) ;

    ELSIF (sat_in(ISIZE-1) = '1') THEN 
                -- neg underflow. go to max neg
                sat_out     <= max_neg;
    ELSE                        
                -- pos overflow, go to max pos
                sat_out     <= max_pos;
    END IF ;
END PROCESS sat_test ;


END behave ; 


