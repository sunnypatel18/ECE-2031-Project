-- VEL_CONTROL.VHD
-- 04/03/2011
-- This was the velocity controller for the AmigoBot project.
-- Team Flying Robots
-- ECE2031 L05  (minor mods by T. Collins, plus major addition of closed-loop control)

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK,
--  INSTABILITY, AND RUNAWAY ROBOTS!!

LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
USE LPM.LPM_COMPONENTS.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY VEL_CONTROL IS
PORT(PWM_CLK,    -- must be a 100 MHz clock signal to get ~25kHz phase frequency
	RESETN,
	CS,       -- chip select, asserted when new speed is input
	IO_WRITE : IN STD_LOGIC;  -- asserted when being written to
	IO_DATA  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);  -- commanded speed from SCOMP (only lower 8 bits used)
	VELOCITY : IN STD_LOGIC_VECTOR(16 DOWNTO 0); -- actual velocity of motor, for closed loop control
	CTRL_CLK : IN STD_LOGIC;  -- clock that determines control loop sampling rate (~10 Hz)
	ENABLE   : IN STD_LOGIC;  -- prevents running control while motors are disabled
	MOTOR_PHASE : OUT STD_LOGIC; -- polarity of motor output
	STOPPED     : OUT STD_LOGIC;
	WATCHDOG    : OUT STD_LOGIC  -- safety feature
);
END VEL_CONTROL;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK,
--  INSTABILITY, AND RUNAWAY ROBOTS!!

ARCHITECTURE a OF VEL_CONTROL IS
	SIGNAL COUNT  : STD_LOGIC_VECTOR(11 DOWNTO 0); -- counter output
	SIGNAL IO_DATA_INT: STD_LOGIC_VECTOR(15 DOWNTO 0); -- internal speed value
	SIGNAL LATCH: STD_LOGIC;
	SIGNAL PWM_CMD: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL MOTOR_PHASE_INT: STD_LOGIC;

BEGIN
	-- Use LPM counter megafunction to make a divide by 4096 counter
	counter: LPM_COUNTER
	GENERIC MAP(
		lpm_width => 12,
		lpm_direction => "UP"
	)
	PORT MAP(
		clock => PWM_CLK,
		q => COUNT
	);

	-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK,
	--  INSTABILITY, AND RUNAWAY ROBOTS!!

	-- Use LPM compare megafunction to produce desired duty cycle
	compare: LPM_COMPARE
	GENERIC MAP(
		lpm_width => 12,
		lpm_representation => "UNSIGNED"
	)
	PORT MAP(
		dataa => COUNT,
		datab =>  PWM_CMD(11 DOWNTO 0),
		ageb => MOTOR_PHASE_INT
	);

	-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK,
	--  INSTABILITY, AND RUNAWAY ROBOTS!!

	LATCH <= CS AND IO_WRITE; -- part of IO fix (below) -- TRC
	WATCHDOG <= NOT LATCH;  -- The watchdog uses the latch signal to ensure SCOMP is alive
	
	PROCESS (RESETN, LATCH)
		BEGIN
		-- set speed to 0 after a reset
		IF RESETN = '0' THEN
			IO_DATA_INT <= x"0000";
			STOPPED <= '1';
		-- keep the IO command (velocity command) from SCOMP in an internal register IO_DATA_INT
		ELSIF RISING_EDGE(LATCH) THEN   -- fixed unreliable OUT operation - TRC
		-- handle the case of the max negative velocity
			IF ((IO_DATA(15 DOWNTO 9) = "000000000") 
			  OR ((IO_DATA(15 DOWNTO 9) = "111111111") AND (IO_DATA(8 DOWNTO 0) /= "000000000"))) THEN
				IO_DATA_INT <= IO_DATA(15 DOWNTO 0);
			ELSE 
				IO_DATA_INT <= x"0000";  -- behavior for out of range (treat as zero)
			END IF;
			STOPPED <= '0';
		END IF;
	END PROCESS;

	-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK,
	--  INSTABILITY, AND RUNAWAY ROBOTS!!

	-- added closed loop control so that motor will try to achieve exactly the value commanded - TRC
	PROCESS (CTRL_CLK, RESETN, ENABLE)
		VARIABLE CMD_VEL, VEL_ERR, CUM_VEL_ERR: INTEGER := 0;
		VARIABLE LAST_CMD_VEL: INTEGER := 0;
		CONSTANT SATURATION: INTEGER := 500000000;  -- Limits effect of integrator "windup"
		VARIABLE DERR, LASTERR: INTEGER := 0;
		CONSTANT LIMIT: INTEGER := 268435455;
		VARIABLE MOTOR_CMD: INTEGER;
		VARIABLE PROP_CTRL, INT_CTRL, DERIV_CTRL, FF_CTRL: INTEGER := 0;

		-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK,
		--  INSTABILITY, AND RUNAWAY ROBOTS!!
		VARIABLE KP: INTEGER := 1000; -- 2k starts to get unstable
		VARIABLE KI: INTEGER := 60; -- ~40 seems reasonable
		VARIABLE KD: INTEGER := 1000; -- 
		VARIABLE KF: INTEGER := 0; -- 1024 is close to 1:1

		BEGIN

-- if using external gains...		
--	KP := TO_INTEGER(SIGNED(GAINS(15 DOWNTO 0)));
--	KI := TO_INTEGER(SIGNED(GAINS(31 DOWNTO 16)));
--	KD := TO_INTEGER(SIGNED(GAINS(47 DOWNTO 32)));
--	KF := TO_INTEGER(SIGNED(GAINS(63 DOWNTO 48)));
	
		IF RESETN = '0' OR ENABLE = '0' THEN
			MOTOR_CMD := 0; -- at startup, motor should be stopped
			CUM_VEL_ERR := 0;
			LASTERR := 0;
			DERR := 0;
		ELSIF RISING_EDGE(CTRL_CLK) THEN   -- determine a control signal at each control cycle
			-- incoming velocity is 2^3 times control velocity
			CMD_VEL := TO_INTEGER(SIGNED(IO_DATA_INT(9 DOWNTO 0)&"000")); -- match magnitudes
			VEL_ERR := CMD_VEL - TO_INTEGER(SIGNED(VELOCITY));  -- commanded vel should equal measured vel
			IF(CMD_VEL = LAST_CMD_VEL) THEN -- prevent derivative-kick.
				DERR := VEL_ERR - LASTERR;
			ELSE LAST_CMD_VEL := CMD_VEL;
			END IF;
			LASTERR := VEL_ERR;
--			IF CMD_VEL = 0 THEN
--				CUM_VEL_ERR := 0;  -- reset integrator when motor is stopped
--			ELSE
				CUM_VEL_ERR := CUM_VEL_ERR + VEL_ERR;   -- perform the integration, if not near setpoint
--			END IF;
--			IF (CUM_VEL_ERR > SATURATION) THEN
--				CUM_VEL_ERR := SATURATION;
--			ELSIF (VEL_ERR < -SATURATION) THEN
--				CUM_VEL_ERR := -SATURATION;
--			END IF;
			PROP_CTRL := VEL_ERR * KP;   -- The "P" component of the PID controller
			INT_CTRL  := CUM_VEL_ERR * KI;   -- The "I" component
			DERIV_CTRL := DERR * KD;-- The "D" component
			FF_CTRL := CMD_VEL * KF;   -- FeedForward component...
			MOTOR_CMD := (FF_CTRL) + (PROP_CTRL) + (INT_CTRL) + (DERIV_CTRL);
--			IF (MOTOR_CMD > LIMIT) THEN
--				MOTOR_CMD := LIMIT;
--			ELSIF (MOTOR_CMD < -LIMIT) THEN
--				MOTOR_CMD := -LIMIT;
--			END IF;
		END IF;
		
		PWM_CMD <= STD_LOGIC_VECTOR(TO_SIGNED((MOTOR_CMD/8192)+2048, PWM_CMD'LENGTH));

	END PROCESS;

	PROCESS BEGIN
	WAIT UNTIL RISING_EDGE(PWM_CLK);
		MOTOR_PHASE <= MOTOR_PHASE_INT;
	END PROCESS;
END a;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK,
--  INSTABILITY, AND RUNAWAY ROBOTS!!

