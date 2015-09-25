LIBRARY IEEE;
USE  IEEE.STD_LOGIC_1164.all;
USE  IEEE.STD_LOGIC_ARITH.all;
USE  IEEE.STD_LOGIC_UNSIGNED.all;

-- This is an improved version of the ACC_CLK_GEN provided for Lab 8.

ENTITY ACC_CLK_GEN IS

	PORT
	(
		clock_25Mhz      : IN  STD_LOGIC;
		clock_12500KHz   : OUT STD_LOGIC;
		clock_200KHz      : OUT STD_LOGIC;
		clock_10KHz      : OUT STD_LOGIC;
		clock_100Hz      : OUT STD_LOGIC;
		clock_10Hz       : OUT STD_LOGIC
	);
	
END ACC_CLK_GEN;

ARCHITECTURE a OF ACC_CLK_GEN IS

	SIGNAL count_10hz      : STD_LOGIC_VECTOR(22 DOWNTO 0); 
	SIGNAL count_100hz     : STD_LOGIC_VECTOR(18 DOWNTO 0);
	SIGNAL count_10Khz     : STD_LOGIC_VECTOR(12 DOWNTO 0); 
	SIGNAL count_200Khz     : STD_LOGIC_VECTOR(8 DOWNTO 0); 
	SIGNAL count_12p5Mhz   : STD_LOGIC_VECTOR(2 DOWNTO 0); 
	SIGNAL clock_10hz_int  : STD_LOGIC; 
	SIGNAL clock_100hz_int : STD_LOGIC;
	SIGNAL clock_10Khz_int : STD_LOGIC; 
	SIGNAL clock_200Khz_int : STD_LOGIC; 
	SIGNAL clock_12500KHz_int : STD_LOGIC; 
BEGIN
	clock_200Khz <= clock_200Khz_int;
	clock_10Khz <= clock_10Khz_int;
	clock_100hz <= clock_100hz_int;
	clock_10hz  <= clock_10hz_int;
	clock_12500KHz <= clock_12500KHz_int;
	
	PROCESS 
	BEGIN
		WAIT UNTIL clock_25Mhz'EVENT and clock_25Mhz = '1';
			IF count_10hz < 1249999 THEN
				count_10hz <= count_10hz + 1;
			ELSE
				count_10hz <= "00000000000000000000000";
				clock_10hz_int <= NOT(clock_10hz_int);
			END IF;
			IF count_100hz < 124999 THEN
				count_100hz <= count_100hz + 1;
			ELSE
				count_100hz <= "0000000000000000000";
				clock_100hz_int <= NOT(clock_100hz_int);
			END IF;	
			IF count_10Khz < 1249 THEN
				count_10Khz <= count_10Khz + 1;
			ELSE
				count_10Khz <= "0000000000000";
				clock_10Khz_int <= NOT(clock_10Khz_int);
			END IF;	
			IF count_200Khz < 62 THEN
				count_200Khz <= count_200Khz + 1;
			ELSE
				count_200Khz <= "000000000";
				clock_200Khz_int <= NOT(clock_200Khz_int);
			END IF;	
			clock_12500KHz_int <= NOT(clock_12500KHz_int);
	END PROCESS;	
END a;

