----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 02:50:18 PM
-- Design Name: 
-- Module Name: ALU - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ALU is
    Port ( i_A : in STD_LOGIC_VECTOR (7 downto 0);
           i_B : in STD_LOGIC_VECTOR (7 downto 0);
           i_op : in STD_LOGIC_VECTOR (2 downto 0);
           o_result : out STD_LOGIC_VECTOR (7 downto 0);
           o_flags : out STD_LOGIC_VECTOR (3 downto 0));
           
         
end ALU;

architecture Behavioral of ALU is

    -- component declarations
    
    component ripple_adder is
    Port ( A : in STD_LOGIC_VECTOR (3 downto 0);
           B : in STD_LOGIC_VECTOR (3 downto 0);
           Cin : in STD_LOGIC;
           S : out STD_LOGIC_VECTOR (3 downto 0);
           Cout : out STD_LOGIC
       );
    end component ripple_adder;
    
    -- signal declarations
    signal A_lo, A_hi      : STD_LOGIC_VECTOR(3 downto 0); --half and half for two ripple adders
    signal B_lo, B_hi      : STD_LOGIC_VECTOR(3 downto 0);
    signal B_mod           : STD_LOGIC_VECTOR(7 downto 0); --B needs to be altered for subtraction
    signal sum_lo, sum_hi  : STD_LOGIC_VECTOR(3 downto 0); -- house results from adders
    signal carry_lo: STD_LOGIC; --carry from lower ripple adder
    signal carry_hi: STD_LOGIC; --carry from upper ripple adder
    signal alu_result      : STD_LOGIC_VECTOR(7 downto 0);
    signal Cin             : STD_LOGIC;
    signal final_sum : STD_LOGIC_VECTOR(7 downto 0);
    
    
    signal xnor_part: std_logic; 
    signal xor_part: std_logic; 
    signal not_alu_one: std_logic;
    signal xnor_xor_parts_anded: std_logic; 

begin
 
    A_hi <= i_A(7 downto 4);
    A_lo <= i_A(3 downto 0); 
 
    B_mod <= i_B when i_op /= "001" else (not i_B); -- not B for subtraction, essentially the mux in the diagram
    B_hi <= B_mod(7 downto 4);
    B_lo <= B_mod(3 downto 0); 
    
    Cin <= '1' when i_op = "001" else '0'; -- if subtraction, need a carry in to add one more to B
    
    
    ripple_adder_1: ripple_adder 
        port map (
            A    => A_lo,
            B    => B_lo,
            Cin  => Cin,
            S    => sum_lo,
            Cout => carry_lo
        );
        
    --adds the two halves of the two numbers    
    ripple_adder_2: ripple_adder
        port map (
            A    => A_hi,
            B    => B_hi,
            Cin  => carry_lo,
            S    => sum_hi,
            Cout => carry_hi
        );
        
    final_sum(7 downto 4) <= sum_hi;
    final_sum(3 downto 0) <= sum_lo; 
        
    with i_op select
    alu_result <= final_sum when "000", --add
                  final_sum when "001", --subtract
                  (B_mod and i_A) when "010", -- and
                  (B_mod or i_A) when "011", -- or
                  (others => '0') when others;
                  
                  
    o_result <= alu_result;
    
    --flag checking 
    --o_flags(3) is negative
           --o_flags(2) is zero
           --o_flags(1) is carry
           --o_flags(0) is overflow
    o_flags(3) <= alu_result(7);    
    o_flags(2) <= '1' when alu_result = "00000000" else '0';
    o_flags(1) <= carry_hi and (not i_op(1));
    
    
    --overflow 
    not_alu_one <= not i_op(1); --we're doing addition or subtraction
    xnor_part <= not ( i_A(7) xor  i_B(7)  xor i_op(0)  ); -- A and B have same signs for addition, or different signs for subtraction
                                    -- imagine a triple gate xnnor
    xor_part <= i_A(7) xor alu_result(7) ; -- A and Sum have different signs. 
    
    xnor_xor_parts_anded <= xnor_part and xor_part; --'and' them 
    o_flags(0) <= xnor_xor_parts_anded and not_alu_one;
    
    
    -- doing addition or subtraction AND a and result have different signs AND making sure that if the signs 
    -- are the same we get 0 xor 0 is 0 for addition and 0 xor 1 is 1 for subtraction,  notted will get our result. 
    -- if signs are different we get 1 xor 0 is 1 for addition and 1 xor 1 for subtraction, notted will get our result. 
    
    
        
end Behavioral;
