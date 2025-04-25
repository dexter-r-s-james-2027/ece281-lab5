--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(7 downto 0); -- operands and opcode
        btnU    :   in std_logic; -- reset
        btnC    :   in std_logic; -- fsm cycler
        btnL    :   in std_logic; --clock reset --added in 
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is 
  
	-- declare components and signals------------------------
	
	component clock_divider is
        generic ( constant k_DIV : natural := 2 );
        port (  i_clk    : in std_logic;    -- basys3 clk
                i_reset  : in std_logic;    -- asynchronous
                o_clk    : out std_logic    -- divided (slow) clock
        );
    end component clock_divider;
    
    component controller_fsm is
        port(  i_reset : in STD_LOGIC; --"synchronous" reset
               i_adv : in STD_LOGIC;
               o_cycle : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component controller_fsm;
    
    component ALU is
        port (  i_A : in STD_LOGIC_VECTOR (7 downto 0);
                i_B : in STD_LOGIC_VECTOR (7 downto 0);
                i_op : in STD_LOGIC_VECTOR (2 downto 0);
                o_result : out STD_LOGIC_VECTOR (7 downto 0);
                o_flags : out STD_LOGIC_VECTOR (3 downto 0)
                );
    end component ALU;
    
    component TDM4 is
        generic ( constant k_WIDTH : natural  := 4); -- bits in input and output
        port (  i_clk		: in  STD_LOGIC;
                i_reset		: in  STD_LOGIC; -- asynchronous
                i_D3 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		        i_D2 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		        i_D1 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		        i_D0 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		        o_data		: out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		        o_sel		: out STD_LOGIC_VECTOR (3 downto 0)	-- selected data line (one-cold)
	           );
        end component TDM4;
        
    component twos_comp is
        port (  i_bin: in std_logic_vector(7 downto 0);
                o_sign: out std_logic;
                o_hund: out std_logic_vector(3 downto 0);
                o_tens: out std_logic_vector(3 downto 0);
                o_ones: out std_logic_vector(3 downto 0)
               );
        end component twos_comp;
     
    component sevenseg_decoder is
        Port (  i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
                o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
               );
    end component sevenseg_decoder;
    
    --signals-----------------
    
    -- fsm driver
    signal w_cycle : std_logic_vector(3 downto 0) := "0001"; --FSM Cycle one hot decoded
    -- clock signals
    signal w_clk_fsm : std_logic;  --clock signal to drive the FSM
    signal w_clk_tdm: std_logic; --clock signal to drive the TDM
    -- alu in out 
    signal a_reg : std_logic_vector(7 downto 0); --houses contents of register A
    signal b_reg : std_logic_vector(7 downto 0); --houses contents of register B  
    signal op_code: std_logic_vector(2 downto 0); --houses the op code
    signal alu_out : std_logic_vector(7 downto 0); --alu output
    signal flags : std_logic_vector(3 downto 0); -- NZCV flags for LEDs
    -- 4:1 mux signals
    signal mux_out : std_logic_vector(7 downto 0); --houses output of 4:1 mux
    -- two comp signals
    signal negative_sign : std_logic;  --this sign indicates whether or not a negative sign is necessary in the seven seg display
    signal w_hund : std_logic_vector(3 downto 0);
    signal w_tens : std_logic_vector(3 downto 0);
    signal w_ones : std_logic_vector(3 downto 0);
    -- TDM signals
    signal tdm_out : std_logic_vector(3 downto 0); --houses the binary output of the two's complement to give the TDM
    signal tdm_select: std_logic_vector(3 downto 0); --houses the anode select
    signal w_dummy : std_logic_vector(3 downto 0) := x"F"; -- dummy signal for the 4th (leftmost) display meant to house the negative
    
    --seven segment signals
    signal seg_houser : std_logic_vector(6 downto 0); -- signal to house the raw output of the seven segment

  
    -- negative positive MUX for 3rd display 
    signal w_mux_sel : std_logic_vector(1 downto 0); 
    signal positive_number : std_logic_vector(6 downto 0) := "1111111";
    signal negative_number : std_logic_vector(6 downto 0) := "0111111";
    
    --reset signals
        --clocks are an async reset on btnL
    --synchronous resets: 
        --TDM4
        --Registers
        --Controller FSM 
        
    
    signal w_reset_synchronous: std_logic;
    
    signal w_register_reset: std_logic; 

    

begin
	-- PORT MAPS ----------------------------------------
	
	fsm_inst: controller_fsm
	   port map(
	       i_reset => btnU, --master reset 
	       i_adv => btnC,
	       o_cycle => w_cycle
	   );
	
	clock_divider_inst_fsm: clock_divider
	   generic map(k_Div => 50000000)
	   port map(
	       i_clk => clk,
	       i_reset => btnL, 
	       o_clk => w_clk_fsm
	   );
	   
	clock_divider_inst_tdm: clock_divider
	   generic map(k_Div => 50000)
	   port map(
	       i_clk => clk,
	       i_reset => btnL, 
	       o_clk => w_clk_tdm
	   );
	   	   
	ALU_inst : ALU
        Port map( 
               i_A => a_reg,
               i_B => b_reg,
               i_op => op_code,
               o_result => alu_out,
               o_flags => flags
        ); 
                   	
    twos_comp_inst : twos_comp	
        Port map(
                i_bin => mux_out,
                o_sign => negative_sign, 
                o_hund => w_hund,
                o_tens => w_tens,
                o_ones => w_ones 
        );
    TDM_4 : TDM4
	   generic map (k_WIDTH => 4)
	   port map(
	       i_reset     => btnU, --master sync reset 
	       i_clk       => w_clk_tdm,
	       i_D0        => w_ones,
	       i_D1        => w_tens,
	       i_D2        => w_hund,
	       i_D3        => w_dummy, 
	       o_data      => tdm_out,
	       o_sel       => tdm_select
	       );
        
    sevenseg_decoder_inst : sevenseg_decoder
        port map (
            i_Hex => tdm_out,     
            o_seg_n => seg_houser
        );
        
        -- register processes --
    state_register_a : process(w_clk_fsm, w_cycle) --make these async? 
	begin
        if rising_edge(w_clk_fsm) then
           if w_register_reset = '1' then
               a_reg <= "00000000";
           elsif w_cycle = "0001" then 
                a_reg <= sw;
           end if;
        end if;
	end process state_register_a;
	    
    state_register_b : process(w_clk_fsm, w_cycle)
	begin
        if rising_edge(w_clk_fsm) then
           if w_register_reset = '1' then
                b_reg <= "00000000"; --zeroes to reset 
           elsif w_cycle = "0010" then
                b_reg <= sw;
            end if;
        end if;
	end process state_register_b;
	
	
	-- CONCURRENT STATEMENTS ----------------------------
	
	--op code
	op_code(2) <= sw(2);
	op_code(1) <= sw(1);
	op_code(0) <= sw(0);
	
	--resets 
	w_register_reset <= btnU or w_cycle(3); --master reset button pushed OR in reset state
	
	--4:1 mux for ALU and zeroes 
	
	with w_cycle select
	mux_out <= a_reg when "0001",
	           b_reg when "0010",
	           alu_out when "0100",
	          "00000000" when others; 
	      
	--negative, positive, or normal output to dsiplay
	
    w_mux_sel(0) <= tdm_select(3); --when on the third tdm, one cold, should be zero (only for sign)
	w_mux_sel(1) <= negative_sign; -- 1 when negative, 0 when positive  
	
	with w_mux_sel select
    seg <= positive_number   when "00", --anode 3 positive
           negative_number   when "10", --anode 3 negative
           seg_houser        when others;
	-- anodes
	
	an <= tdm_select; 
	
	-- LEDs
	led(3 downto 0) <= w_cycle;
	led(10 downto 4) <= (others => '0');
	led(12) <= '0';
	led(15 downto 13) <=  flags(3 downto 1);
	led(11) <= flags(0); 
	
	
end top_basys3_arch;
