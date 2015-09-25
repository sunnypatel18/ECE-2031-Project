LIBRARY IEEE;
LIBRARY ALTERA_MF;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE ALTERA_MF.ALTERA_MF_COMPONENTS.ALL;
USE LPM.LPM_COMPONENTS.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY UART_DATA IS
	PORT(
		CLOCK    : IN    STD_LOGIC;
		RESETN   : IN    STD_LOGIC;
		UART_STB : IN    STD_LOGIC;
		UART_ACK : OUT	 STD_LOGIC;
		IO_DATA  : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END UART_DATA;


ARCHITECTURE a OF UART_DATA IS
	SIGNAL READ_REQ : STD_LOGIC; -- read request from SCOMP
	SIGNAL OUTDATA : STD_LOGIC_VECTOR(15 DOWNTO 0);

BEGIN
	-- Use altsyncram component for unified program and data memory
	MEMORY : altsyncram
	GENERIC MAP (
		intended_device_family => "Cyclone",
		width_a          => 16,
		widthad_a        => 10,
		numwords_a       => 1024,
		operation_mode   => "SINGLE_PORT",
		outdata_reg_a    => "UNREGISTERED",
		indata_aclr_a    => "NONE",
		wrcontrol_aclr_a => "NONE",
		address_aclr_a   => "NONE",
		outdata_aclr_a   => "NONE",
		init_file        => "SimpleRobotProgram.mif",
		lpm_hint         => "ENABLE_RUNTIME_MOD=NO",
		lpm_type         => "altsyncram"
	);

	-- Use LPM function to drive I/O bus
	IO_BUS: LPM_BUSTRI
	GENERIC MAP (
		lpm_width => 16
	)
	PORT MAP (
		data     => OUTDATA,
		enabledt => READ_REQ,
		tridata  => IO_DATA
	);

	PROCESS (CLOCK, RESETN)

	BEGIN
		IF (RESETN = '0') THEN          -- Active low, asynchronous reset
			
		ELSIF (RISING_EDGE(CLOCK)) THEN
			
		END IF;
	END PROCESS;
END a;