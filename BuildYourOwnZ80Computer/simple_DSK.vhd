--    {@{@{@{@{@{@
--  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r004
--  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
--  {@{@{@{@{@{@{@{@
--  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
--  {@{@        {@{@   Contact : renaudhelias@gmail.com
--  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
--    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
--
--
--------------------------------------------------------------------------------
-- FPGAmstrad_amstrad_motherboard.simple_DSK
-- Mecashark version : direct read/write access to sdcard.
--
-- State machine : PHASE_* (one-to-one with FDC "state" responses to Z80)
-- Crossing state machine : etat_*
-- Global state : etat_wait '1:busy' : goto PHASE_*_WAIT, '0:not busy' : do leave PHASE_*_WAIT (one-to-one with FDC "ST0/ST1/ST2/ST3" responses to Z80)
-- Bonus : is_dskReady(current_face), at '1' when a dsk is selected/inserted
--
-- see SDRAM_FAT32_LOADER.vhd mecashark
-- TODO : do fix PARADOS.ROM second drive ?
-- READ_TRACK (&02) does use megashark_BOT_EOT output and R as BOT input containing skips or not.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--(FDCTEST.ASM) arnoldemu's response : Please don't use those old tests. The 'acid test' disc tests are much better and more reliable.
--http://www.cpctech.org.uk/test.zip
--
--See "disc" directory.
--I need to go back and improve some of the tests because the result is different on some fdcs and I need to test on 664 and ddi-1.
--
--These are all good:
-- - seek, recalibrate, sense interrupt status, sense drive status, write protect


--Garbage research notes (it's a doc copy/paste)
--
--Before accessing a disk you should first "Recalibrate" the drive, that moves the head backwards until it reaches Track 0. (The Track 0 signal from the drive is sensed by the FDC and it initializes it's internal track counter for that drive to 0).
--On a 80 track drive you may need to repeat that twice because some models of the FDC stop after 77 steps and if your recalibrating from track 80 it will not recalibrate fully.
--Now if you want to format, read or write a sector on a specific track you must first Seek that track (command 0Fh). That'll move the read/write head to the physical track number. If you don't do that, then the FDC will attempt to read/write data to/from the current physical track, independenly of the specified logical Track-ID.
--The Track-, Sector-, and Head-IDs are logical IDs only. These logical IDs are defined when formatting the disk, and aren't required to be identical to the physical Track, Sector, or Head numbers. However, when reading or writing a sector you must specify the same IDs that have been used during formatting.
--Despite the confusing name, a sector with a "Deleted Data Address Mark" (DAM) is not deleted. The DAM-flag is just another ID-bit, and (if that ID-bit is specified correctly in the command) it can be read/written like normal data sectors.
--At the end of a successful read/write command, the program should send a Terminal Count (TC) signal to the FDC. However, in the CPC the TC pin isn't connected to the I/O bus, making it impossible for the program to confirm a correct operation. For that reason, the FDC will assume that the command has failed, and it'll return both Bit 6 in Status Register 0 and Bit 7 in Status Register 1 set. The program should ignore this error message.
--The CPC doesn't support floppy DMA transfers, and the FDCs Interrupt signal isn't used in the CPC also.
--Usually single sided 40 Track 3" disk drives are used in CPCs, whereas 40 tracks is the official specification, practically 42 tracks could be used (the limit is specific to the FDD, some support more tracks. 42 is a good maximum). The FDC controller can be used to control 80 tracks, and/or double sided drives also, even though AMSDOS isn't supporting such formats. AMSDOS is supporting a maximum of two disk drives only. 

entity simple_DSK is
    Port ( nCLK4_1 : in  STD_LOGIC;
           reset : in STD_LOGIC;
           A10_A8_A7 : in  STD_LOGIC_VECTOR (2 downto 0); -- chip select
           A0 : in  STD_LOGIC;-- data/status reg select
           IO_RD : in  STD_LOGIC;
           IO_WR : in  STD_LOGIC;
           D_command : in  STD_LOGIC_VECTOR (7 downto 0);
           D_result : out  STD_LOGIC_VECTOR (7 downto 0) := (others=>'1');

			  --leds8_debug : out STD_LOGIC_VECTOR (39 downto 0);

			  is_dskReady : in std_logic_vector(1 downto 0);
			  
			  megashark_CHRNresult : in STD_LOGIC_VECTOR(4*8-1 downto 0);
			  megashark_doGOTO : out STD_LOGIC_VECTOR(2 downto 0); -- not a W/R operation finally
			  megashark_CHRN : out STD_LOGIC_VECTOR(4*8-1 downto 0);
			  megashark_BOT_EOT : out STD_LOGIC_VECTOR(15 downto 0);
			  megashark_A : out std_logic_vector(8 downto 0); -- sector byte selection : 512B block * 2sides (for MT)
			  megashark_Din : in std_logic_vector(7 downto 0);
			  megashark_Dout : out std_logic_vector(7 downto 0);
			  megashark_doREAD : out STD_LOGIC_VECTOR(5 downto 0);
			  megashark_doWRITE : out STD_LOGIC_VECTOR(2 downto 0);
			  megashark_done : in std_logic;
			  megashark_face : out std_logic_vector(3 downto 0):="0000";
			  megashark_INFO_2SIDES : in std_logic;
			  megashark_INFO_ST0 : in std_logic_vector(7 downto 0);
			  megashark_INFO_ST1 : in std_logic_vector(7 downto 0);
			  megashark_INFO_ST2 : in std_logic_vector(7 downto 0);
			  megashark_INFO_PANIC : in std_logic_vector(1 downto 0) -- no data blocks to read
			  );
end simple_DSK;

architecture Behavioral of simple_DSK is

	constant IS_ARNOLDEMU_TESTBENCH:boolean:=false; -- does activate a gremlin...

	constant SECTOR_SIZE:integer:=512; -- some protected format seen with SECTOR_SIZES(6) value
	constant SECTOR_FOUND:std_logic_vector(7 downto 0):=x"01";
	--constant sampleSector : STD_LOGIC_VECTOR(8*16*2-1 downto 0) := x"004441525453313830A020200000004902030405060708090A0B000000000000";

	constant REQ_MASTER : STD_LOGIC_VECTOR (7 downto 0):=x"80";
	constant DATA_IN_OUT : STD_LOGIC_VECTOR (7 downto 0):=x"40";
	constant EXEC_MODE : STD_LOGIC_VECTOR (7 downto 0):=x"20";
	constant COMMAND_BUSY : STD_LOGIC_VECTOR (7 downto 0):=x"10";
	constant FDD_BUSY : STD_LOGIC_VECTOR (7 downto 0):=x"10";

	signal status:STD_LOGIC_VECTOR (7 downto 0):=REQ_MASTER;
	
	--constant ST0_NORMAL : std_logic_vector(7 downto 0):=x"00";
	constant ST0_ABNORMAL : std_logic_vector(7 downto 0):=x"40";
	constant ST0_INVALID : std_logic_vector(7 downto 0):=x"80";
	--constant ST0_READY_CHANGE : std_logic_vector(7 downto 0):=x"C0"; --FIXME
	constant ST0_NOT_READY : std_logic_vector(7 downto 0):=x"08";
	constant ST0_HEAD_ADDR : std_logic_vector(7 downto 0):=x"04";
	constant ST0_EQUIP_CHECK : std_logic_vector(7 downto 0):=x"10"; -- RECALIBRATE (SEEK 0) cmd fail
	constant ST0_SEEK_END : std_logic_vector(7 downto 0):=x"20";
	-- + actualDrive
	-- hacks FDCTEST.ASM
	constant ST0_END_OF_READ_DRIVE_USX : std_logic_vector(7 downto 0):=x"40"; -- FDCTEST.ASM WTF ???????
	
	constant ST1_MISSING_ADDR : std_logic_vector(7 downto 0):=x"01"; -- protected dsk
	constant ST1_NOT_WRITABLE : std_logic_vector(7 downto 0):=x"02";
	constant ST1_NO_DATA : std_logic_vector(7 downto 0):=x"04"; -- protected dsk
	constant ST1_OVERRUN : std_logic_vector(7 downto 0):=x"10";
	constant ST1_DATA_ERROR : std_logic_vector(7 downto 0):=x"20"; -- protected dsk
	constant ST1_END_CYL : std_logic_vector(7 downto 0):=x"80"; -- protected dsk
	-- hacks FDCTEST.ASM
	constant ST1_SECTOR_NOT_FOUND_BAD : std_logic_vector(7 downto 0):=x"84";
	
	--constant ST2_MISSING_ADDR : std_logic_vector(7 downto 0):=x"01"; -- protected dsk
	--constant ST2_BAD_CYLINDER : std_logic_vector(7 downto 0):=x"02";
	constant ST2_SCAN_NOT_SATISFIED : std_logic_vector(7 downto 0):=x"04";
	
	constant ST2_SCAN_EQUAL_HIT : std_logic_vector(7 downto 0):=x"08";
	--constant ST2_WRONG_CYL : std_logic_vector(7 downto 0):=x"10";
	constant ST2_DATA_ERROR : std_logic_vector(7 downto 0):=x"20"; -- protected dsk
	constant ST2_CONTROL_MARK : std_logic_vector(7 downto 0):=x"40"; -- protected dsk
	-- hacks FDCTEST.ASM
	constant ST2_SECTOR_NOT_FOUND_BAD : std_logic_vector(7 downto 0):=x"00";
	
	--constant ST3_HEAD_ADDR : std_logic_vector(7 downto 0):=x"04";
	constant ST3_TWO_SIDE : std_logic_vector(7 downto 0):=x"08";
	constant ST3_TRACK_0 : std_logic_vector(7 downto 0):=x"10";
	constant ST3_READY : std_logic_vector(7 downto 0):=x"20";
	constant ST3_WRITE_PROT : std_logic_vector(7 downto 0):=x"40";
	--constant ST3_FAULT : std_logic_vector(7 downto 0):=x"80";
	
	constant PANIC_RAGE_QUIT : std_logic_vector(1 downto 0):="01";
	constant PANIC_SLOW_QUIT : std_logic_vector(1 downto 0):="10";
	--constant PANIC_SLOW_SKIP : std_logic_vector(2 downto 0):="100";
	-- + actualDrive
	
	constant ACTION_POLL:integer range 0 to 9:=0;
	--constant ETAT_READ_DIAGNOSTIC:integer range 0 to 9:=1;
	constant ACTION_READ:integer range 0 to 9:=1;
	constant ACTION_SEEK:integer range 0 to 9:=2;
	constant ACTION_WRITE:integer range 0 to 9:=3;
	constant ETAT_RECALIBRATE:integer range 0 to 9:=4;
	constant ACTION_READ_ID:integer range 0 to 9:=5;
	constant ETAT_SENSE_DRIVE_STATUS:integer range 0 to 9:=6;
	constant ETAT_SENSE_INTERRUPT_STATUS:integer range 0 to 9:=7;
	constant ACTION_SCAN:integer range 0 to 9:=8;
	constant ACTION_OVERRUN:integer range 0 to 9:=9;
	
	constant PHASE_ATTENTE_COMMANDE:integer range 0 to 9:=0;
	constant PHASE_COMMAND:integer range 0 to 9:=1;
	constant PHASE_WAIT_EXECUTION_READ:integer range 0 to 9:=2;
	constant PHASE_WAIT_EXECUTION_WRITE:integer range 0 to 9:=3;
	constant PHASE_EXECUTION_READ:integer range 0 to 9:=4;
	constant PHASE_EXECUTION_WRITE:integer range 0 to 9:=5;
	constant PHASE_AFTER_EXECUTION_WRITE:integer range 0 to 9:=6;
	constant PHASE_WAIT_RESULT:integer range 0 to 9:=7;
	constant PHASE_RESULT:integer range 0 to 9:=8;
	constant PHASE_WAIT_ATTENTE_COMMANDE:integer range 0 to 9:=9;

	signal phase:integer range 0 to 9:=PHASE_ATTENTE_COMMANDE;
	
	
	constant NB_SECTOR_PER_PISTE:integer:=15;
	constant NB_PISTE_PER_FACE:integer:=80;
	constant NB_FACE:integer:=2;
	
	component altera_syncram is
	  generic (abits : integer := 9; dbits : integer := 32 );
	  port (
	    clk      : in std_ulogic;
	    address  : in std_logic_vector((abits -1) downto 0);
	    datain   : in std_logic_vector((dbits -1) downto 0);
	    dataout  : out std_logic_vector((dbits -1) downto 0);
	    enable   : in std_ulogic;
	    write    : in std_ulogic); 
	end component;
	
	signal memshark_chrn:STD_LOGIC_VECTOR(4*8-1 downto 0):=(others=>'0');
	signal memshark_doGOTO:boolean:=false;
	signal memshark_doGOTO_T:boolean:=false;
	signal memshark_doGOTO_R:boolean:=false;
	signal memshark_doREAD:boolean:=false;
	--signal memshark_doREADfirstSector:boolean:=false; -- is_next first step : go to first sector of track
	signal memshark_doREADnext:boolean:=false;
	signal memshark_doREAD_DEL:boolean:=false;
	signal memshark_doREAD_SK:boolean:=false;
	signal memshark_doREAD_MT:boolean:=false;
	signal memshark_doWRITE:boolean:=false;
	signal memshark_doWRITE_DEL:boolean:=false;
	signal memshark_doWRITE_MT:boolean:=false;
	signal memshark_DTL:integer range 0 to SECTOR_SIZE-1:=0;
	signal memshark_is_writeDTL:boolean:=false;
	signal memshark_done:boolean:=true;
	
	signal block_Din:std_logic_vector(7 downto 0);
	signal block_Din_megashark:std_logic_vector(7 downto 0);
	signal block_Din_cortex:std_logic_vector(7 downto 0);
	signal block_Dout:std_logic_vector(7 downto 0);
	signal block_A:std_logic_vector(8 downto 0);
	signal block_A_megashark:std_logic_vector(8 downto 0);
	signal block_A_cortex:std_logic_vector(8 downto 0);
	signal block_W:std_ulogic;
	signal block_W_megashark:std_ulogic:='0';
	signal block_W_cortex:std_ulogic:='0';

	signal megashark_doGOTO_s:std_logic_vector(2 downto 0):="000";
	signal megashark_doREAD_s:std_logic_vector(5 downto 0):="000000";
	signal megashark_doWRITE_s:std_logic_vector(2 downto 0):="000";
	
begin

megashark_doGOTO<=megashark_doGOTO_s;
megashark_doREAD<=megashark_doREAD_s;
megashark_doWRITE<=megashark_doWRITE_s;

--The Main Status register can be always read through Port FB7E. The other four Status Registers cannot be read directly, instead they are returned through the data register as result bytes in response to specific commands.
--
--Main Status Register (Port FB7E)
--
-- b0..3  DB  FDD0..3 Busy (seek/recalib active, until succesful sense intstat)
-- b4     CB  FDC Busy (still in command-, execution- or result-phase)
-- b5     EXM Execution Mode (still in execution-phase, non_DMA_only)
-- b6     DIO Data Input/Output (0=CPU->FDC, 1=FDC->CPU) (see b7)
-- b7     RQM Request For Master (1=ready for next byte) (see b6 for direction)


--     if (buffer != null) {
--      if (direction == READ)
--        status = (status & ~REQ_MASTER) | DATA_IN_OUT | EXEC_MODE;
--      else
--        status = (status & ~DATA_IN_OUT) | REQ_MASTER | EXEC_MODE;  // ??? Is RQM high immediately?
--    }
--    else {
--      status |= DATA_IN_OUT;
--    }


-- "Because of this multibyte interchange of information between the uPD765A/uPD765B and the processor, it is convenient to consider each command as consisting of three phases"
	-- JavaCPC comparison in comments : checked OK
	-- writePort: if REQ_MASTER and then not(COMMAND_BUSY) then can start a command
status <= REQ_MASTER when phase = PHASE_ATTENTE_COMMANDE
   -- writePort: if REQ_MASTER and COMMAND_BUSY then command is started : push param[]
	else REQ_MASTER or COMMAND_BUSY when phase = PHASE_COMMAND
	-- readPort:reads : if REQ_MASTER then do slow remove REQ_MASTER
	-- getNextSector:read : add DATA_IN_OUT and EXEC_MODE, do remove REQ_MASTER
	else               COMMAND_BUSY or EXEC_MODE or DATA_IN_OUT when phase = PHASE_WAIT_EXECUTION_READ
	else REQ_MASTER or COMMAND_BUSY or EXEC_MODE or DATA_IN_OUT when phase = PHASE_EXECUTION_READ
	-- getNextSector:write : do remove DATA_IN_OUT, add REQ_MASTER and EXEC_MODE
	else REQ_MASTER or COMMAND_BUSY or EXEC_MODE when phase = PHASE_EXECUTION_WRITE
	else               COMMAND_BUSY or EXEC_MODE when phase = PHASE_AFTER_EXECUTION_WRITE
	else               COMMAND_BUSY or EXEC_MODE when phase = PHASE_WAIT_EXECUTION_WRITE
	-- readPort:result : if REQ_MASTER then pop result[],
	--                         if last pop then remove COMMAND_BUSY and DATA_IN_OUT
	else               COMMAND_BUSY or DATA_IN_OUT when phase = PHASE_WAIT_RESULT
	else REQ_MASTER or COMMAND_BUSY or DATA_IN_OUT when phase = PHASE_RESULT
	else               COMMAND_BUSY or DATA_IN_OUT when phase = PHASE_WAIT_ATTENTE_COMMANDE
	else REQ_MASTER;

-- fdc_result_phase:
-- 1 attendre REQ_MASTER+DATA_IN_OUT
-- 2 lire 1 coup
-- 3 si COMMAND_BUSY, retenter : goto 1

-- fdc_data_write:
-- 1 attendre REQ_MASTER
-- si EXEC_MODE alors Ã©crire un coup, puis goto 1

-- fdc_data_read:
-- 1 attendre REQ_MASTER
-- si EXEC_MODE alors lire un coup, puis goto 1




-- 1FF = 512 9bit
-- 3FF = 1023 10bit 


 RAMB16_S9_inst : altera_syncram
 generic map (
   abits =>9, -- 1FF=511 9bits
	dbits =>8
 )
 port map (
	clk=>nCLK4_1,
	address=>block_A,
	datain=>block_Din,
	dataout=>block_Dout,
	enable=>'1',
	write=>block_W
	);
block_Din<=block_Din_megashark when not(memshark_done) else block_Din_cortex;
block_A<=block_A_megashark when not(memshark_done) else block_A_cortex;
block_W<=block_W_megashark when not(memshark_done) else block_W_cortex;
megashark:process(reset,nCLK4_1)
	--variable newDskInserted : boolean := true;
	variable chrn_mem:STD_LOGIC_VECTOR(4*8-1 downto 0):=(others=>'0');
	variable memshark_counter:integer range 0 to SECTOR_SIZE-1; --std_logic_vector(8 downto 0):=(others=>'0');
	variable memshark_step:integer range 0 to 9;
	variable block_A_megashark_mem:std_logic_vector(block_A_megashark'range):=(others=>'0');
	variable block_Din_megashark_mem:std_logic_vector(block_Din_megashark'range):=(others=>'0');
	variable block_W_megashark_mem:std_logic:='0';
	variable megashark_A_mem:std_logic_vector(megashark_A'range):=(others=>'0');
	variable megashark_Dout_mem:std_logic_vector(megashark_Dout'range):=(others=>'0');
	variable doGOTO_mem:std_logic_vector(2 downto 0):="000";
	variable doREAD_mem:std_logic_vector(5 downto 0):="000000";
	variable doWRITE_mem:std_logic_vector(2 downto 0):="000";
begin
	if reset='1' then
	elsif rising_edge(nCLK4_1) then --CLK4
		--if not(is_dskReady(0)='1' and is_dskReady(1)='1') then
		--	memshark_done<=true; -- unbind
		--	megashark_doGOTO_s<='0'; -- unbind
		--	megashark_doREAD_s<='0'; -- unbind
		--	megashark_doWRITE_s<='0'; -- unbind
		--end if;
		
		if memshark_doGOTO then
			-- GOTO CHRN : here R is current_sector (0 or +)
			memshark_done<=false;
			doGOTO_mem:="001";
			if memshark_doGOTO_T then
				doGOTO_mem(1):='1';
			end if;
			if memshark_doGOTO_R then
				doGOTO_mem(1):='1';
				doGOTO_mem(2):='1';
			end if;
			memshark_step:=0;
		elsif memshark_doREAD then
			-- READ CHRN : here R is sector id (x"C1"...), READ_DIAGNOSTIC do use EOT parameter, that is a sector id, so I doREAD when READ_DIAGNOSTIC command is called, instead of launching doGOTO.
			memshark_done<=false;
			doREAD_mem:="000001";
			if memshark_doREADnext then
				doREAD_mem(2):='1';
			end if;
			if memshark_doREAD_DEL then
				doREAD_mem(3):='1';
			end if;
			if memshark_doREAD_SK then
				doREAD_mem(4):='1';
			end if;
			if memshark_doREAD_MT then
				doREAD_mem(5):='1';
			end if;
			memshark_step:=3;
		elsif memshark_doWRITE then
			memshark_done<=false;
			doWRITE_mem:="001";
			if memshark_doWRITE_DEL then
				doWRITE_mem(1):='1';
			end if;
			if memshark_doWRITE_MT then
				doWRITE_mem(2):='1';
			end if;
			memshark_step:=6;
		end if;
		
		megashark_doGOTO_s<="000";
		megashark_doREAD_s<="000000";
		megashark_doWRITE_s<="000";
		
		block_W_megashark_mem:='0'; -- we write only one time
		if not(memshark_done) then
			if megashark_done='1' and megashark_doGOTO_s(0)='0' and megashark_doREAD_s(0)='0' and megashark_doWRITE_s(0)='0' then
				case memshark_step is
					when 0=> -- GOTO memshark_chrn
						chrn_mem:=memshark_chrn;
						megashark_CHRN<=chrn_mem;
						megashark_doGOTO_s<=doGOTO_mem;
						memshark_step:=1;
					when 1=>
						chrn_mem:=megashark_CHRNresult;
						memshark_step:=2;
					when 2=> -- CHRN OK
						memshark_done<=true;
						
					when 3=> -- READ memshark_chrn
						chrn_mem:=memshark_chrn;
						megashark_CHRN<=chrn_mem;
						memshark_counter:=0;
						megashark_A<=conv_std_logic_vector(memshark_counter,9);
						megashark_doREAD_s<=doREAD_mem;
						memshark_step:=4;
					when 4=>
						doREAD_mem(1):='1'; -- POP
						block_A_megashark_mem:=conv_std_logic_vector(memshark_counter,9);
						block_Din_megashark_mem:=megashark_Din;
						block_W_megashark_mem:='1';
						if memshark_counter = SECTOR_SIZE-1 then
							memshark_step:=5;
						else
							megashark_CHRN<=chrn_mem;
							memshark_counter:=memshark_counter+1;
							megashark_A<=conv_std_logic_vector(memshark_counter,9);
							megashark_doREAD_s<=doREAD_mem; -- avec POP
						end if;
					when 5=>
						chrn_mem:=megashark_CHRNresult;
						memshark_step:=2;
						
					when 6=> -- WRITE memshark_chrn
						-- just wait one tic that I can read block_A_megashark_mem
						chrn_mem:=memshark_chrn;
						megashark_CHRN<=chrn_mem;
						memshark_counter:=0;
						block_A_megashark_mem:=conv_std_logic_vector(memshark_counter,9);
						block_W_megashark_mem:='0';
						memshark_step:=9;
					when 9=>
						chrn_mem:=memshark_chrn;
						megashark_CHRN<=chrn_mem;
							-- just wait MORE THAN one tic that I can read block_A_megashark_mem
							megashark_Dout_mem:=block_Dout;
							megashark_Dout<=megashark_Dout_mem;
							megashark_A_mem:=conv_std_logic_vector(memshark_counter,9);
							megashark_A<=megashark_A_mem;
							megashark_doWRITE_s<=doWRITE_mem;
						memshark_counter:=0;
						block_A_megashark_mem:=conv_std_logic_vector(memshark_counter,9);
						block_W_megashark_mem:='0';
						memshark_step:=7;
					when 7=>
						if not(memshark_is_writeDTL) and memshark_counter = SECTOR_SIZE-1 then
							-- fin de non DTL
							megashark_CHRN<=chrn_mem;
							megashark_Dout_mem:=block_Dout;
							megashark_Dout<=megashark_Dout_mem;
							megashark_A_mem:=conv_std_logic_vector(memshark_counter,9);
							megashark_A<=megashark_A_mem;
							megashark_doWRITE_s<=doWRITE_mem;
							memshark_step:=8;
						else
							megashark_CHRN<=chrn_mem;
							megashark_Dout_mem:=block_Dout;
							megashark_Dout<=megashark_Dout_mem;
							megashark_A_mem:=conv_std_logic_vector(memshark_counter,9);
							megashark_A<=megashark_A_mem;
							megashark_doWRITE_s<=doWRITE_mem;
							memshark_counter:=memshark_counter+1;
							if memshark_is_writeDTL and memshark_counter = memshark_DTL then
								-- fin de DTL...
								memshark_step:=8;
							else
								block_A_megashark_mem:=conv_std_logic_vector(memshark_counter,9);
								block_W_megashark_mem:='0';
							end if;
						end if;
					when 8=>
						chrn_mem:=megashark_CHRNresult;
						memshark_step:=2;
				end case;
			end if;
		end if;
		block_Din_megashark<=block_Din_megashark_mem;
		block_A_megashark<=block_A_megashark_mem;
		block_W_megashark<=block_W_megashark_mem;
	end if;
end process megashark;





cortex:process(reset,nCLK4_1)
	variable current_byte:integer range 0 to SECTOR_SIZE-1;
	type sector_size_type is array(0 to 4) of integer;
	constant SECTOR_SIZES:sector_size_type:=(128,256,512,1024,2048);--(x"80",x"100",x"200",x"400",x"800",x"1000",x"1800");
	--variable dtl:integer range 0 to SECTOR_SIZE-1:=0; -- against Drive <drive>: disc changed, closing <filename>	The user has changed the disc while files were still open on it.
	
	type params_type is array(0 to 7) of std_logic_vector(7 downto 0);
	type results_type is array(0 to 6) of std_logic_vector(7 downto 0);
	variable pcount:integer range 0 to 8:=0;
	variable params:params_type:=(others=>(others=>'0')); -- stack of params
	variable exec_restant:integer range 0 to SECTOR_SIZE*4:=0;
	variable exec_restant_write:integer range 0 to SECTOR_SIZE:=0;
	variable rcount:integer range 0 to 7:=0;
	variable result:results_type:=(others=>(others=>'0')); -- stack of result
	type chrn_type is array(3 downto 0) of std_logic_vector(7 downto 0);
	variable chrn:chrn_type:=(others=>(others=>'0'));
	variable status_mem:std_logic_vector(7 downto 0);

	function getCHRN(chrn : in STD_LOGIC_VECTOR(4*8-1 downto 0)) return chrn_type is
		variable chrn_interne:chrn_type;
	begin
		chrn_interne(3):=chrn(31 downto 24);
		chrn_interne(2):=chrn(23 downto 16);
		chrn_interne(1):=chrn(15 downto 8);
		chrn_interne(0):=chrn(7 downto 0);
		return chrn_interne;
	end function;

	function setCHRN(chrn : in chrn_type) return STD_LOGIC_VECTOR is
	begin
		return chrn(3) & chrn(2) & chrn(1) & chrn(0);
	end function;

	variable action:integer range 0 to 9;
	variable check_dsk_face:boolean:=false;
	variable check_dsk_low_density:boolean:=false;
	variable is_low_density:boolean:=false;
	variable etat_wait:boolean:=false; -- memshark is busy or out of synchro (work in progress, do generate a ST0/ST1 failing for this round)
	variable command:std_logic_vector(7 downto 0);
	variable is_multitrack:boolean:=false;
	
	variable is_del:boolean:=false;
	variable is_sk:boolean:=false;

	variable is_readtrack:boolean:=false;
	--variable isBOT:boolean:=false; -- against loop FDCTEST.ASM 37 multi-track operation - eot doesn't exist
	--variable BOTbegin:std_logic_vector(7 downto 0);
	
	variable has_control_mark:boolean:=false;
	
	variable data:std_logic_vector(7 downto 0);
	variable do_update:boolean;

	variable wasIO_RD:std_logic:='0';
	variable wasIO_WR:std_logic:='0';
	
--Status Register 0
--
-- b0,1   US  Unit Select (driveno during interrupt)
-- b2     HD  Head Adress (head during interrupt)
-- b3     NR  Not Ready (drive not ready or non-existing 2nd head selected)
-- b4     EC  Equipment Check (drive failure or recalibrate failed (retry))
-- b5     SE  Seek End (Set if seek-command completed)
-- b6,7   IC  Interrupt Code (0=OK, 1=aborted:readfail/OK if EN, 2=unknown cmd
--            or senseint with no int occured, 3=aborted:disc removed etc.)
--
--Status Register 1
--
-- b0     MA  Missing Adress Mark (Sector_ID or DAM not found)
-- b1     NW  Not Writeable (tried to write/format disc with wprot_tab=on)
-- b2     ND  No Data (Sector_ID not found, CRC fail in ID_field)
-- b3,6   0   Not used
-- b4     OR  Over Run (CPU too slow in execution-phase (ca. 26us/Byte))
-- b5     DE  Data Error (CRC-fail in ID- or Data-Field)
-- b7     EN  End of Track (set past most read/write commands) (see IC)
--
--Status Register 2
--
-- b0     MD  Missing Address Mark in Data Field (DAM not found)
-- b1     BC  Bad Cylinder (read/programmed track-ID different and read-ID = FF)
-- b2     SN  Scan Not Satisfied (no fitting sector found)
-- b3     SH  Scan Equal Hit (equal)
-- b4     WC  Wrong Cylinder (read/programmed track-ID different) (see b1)
-- b5     DD  Data Error in Data Field (CRC-fail in data-field)
-- b6     CM  Control Mark (read/scan command found sector with deleted DAM)
-- b7     0   Not Used
--
--Status Register 3
--
-- b0,1   US  Unit Select (pin 28,29 of FDC)
-- b2     HD  Head Address (pin 27 of FDC)
-- b3     TS  Two Side (0=yes, 1=no (!))
-- b4     T0  Track 0 (on track 0 we are)
-- b5     RY  Ready (drive ready signal)
-- b6     WP  Write Protected (write protected)
-- b7     FT  Fault (if supported: 1=Drive failure)
	variable ST0:std_logic_vector(7 downto 0):=(others=>'0');
	variable actualDrive:std_logic_vector(3 downto 0):=(others=>'0'); -- H + US + US
	variable ST1:std_logic_vector(7 downto 0):=(others=>'0');
	variable ST2:std_logic_vector(7 downto 0):=(others=>'0');
	variable ST3:std_logic_vector(7 downto 0):=(others=>'0');
	-- BLOCK_SIZE : N stands for the number of data bytes written in a (Number) sector
	constant BLOCK_SIZE:std_logic_vector(7 downto 0):=x"02";
	constant TRACK_00:std_logic_vector(7 downto 0):=x"00";
	variable BOT:std_logic_vector(7 downto 0):=(others=>'0');
	variable EOT:std_logic_vector(7 downto 0):=(others=>'0');
	variable EOT_DTL:integer range 0 to SECTOR_SIZE-1:=0;
	variable is_EOT_DTL:boolean:=false; -- FIXME
	variable block_A_cortex_mem:std_logic_vector(block_A_cortex'range):=(others=>'0');
	variable block_Din_cortex_mem:std_logic_vector(block_Din_cortex'range):=(others=>'0');
	variable block_W_cortex_mem:std_logic:='0';
	
	--variable current_face:std_logic:='0';
	variable current_face_notReady:boolean:=true;
	
	variable compare_low_or_equal:boolean:=false;
	variable compare_high_or_equal:boolean:=false;
	variable compare_OK:boolean:=false;
	
	variable is_seeking_FACE_A:boolean:=false;
	variable is_seeking_FACE_B:boolean:=false;
	variable is_recalibrating_FACE_A:boolean:=false;
	variable is_recalibrating_FACE_B:boolean:=false;
	
	variable is_issue:boolean:=false; -- not is_seeking but bad command result
	variable is_abnormal_motor:boolean:=false;
	
	
	variable motors:std_logic:='0';
	
	variable gremlin:integer range 0 to 511:=0; --When sector data is read, a byte comes every 32us. => overrun
begin

	if reset='1' then
		D_result<=(others=>'1');

		current_byte:=0;
		pcount:=0;
		exec_restant:=0;
		exec_restant_write:=0;
		rcount:=0;
		action:=ACTION_POLL;
		data:=(others=>'0');
		is_issue:=false;
		motors:='0';
		gremlin:=0;
		
		do_update:=false;
		phase<=PHASE_ATTENTE_COMMANDE;
		etat_wait:=false;
	elsif rising_edge(nCLK4_1) then --CLK4
	
			memshark_doGOTO<=false;
			memshark_doGOTO_T<=false;
			memshark_doGOTO_R<=false;
			memshark_doREAD<=false;
			--memshark_doREADfirstSector<=false;
			memshark_doREADnext<=false;
			memshark_doREAD_DEL<=false;
			memshark_doREAD_SK<=false;
			memshark_doREAD_MT<=false;
			memshark_doWRITE<=false;
			memshark_doWRITE_DEL<=false;
			memshark_doWRITE_MT<=false;
			
			if actualDrive(1)='1' then
				current_face_notReady:=true;
			elsif actualDrive(0)='0' and is_dskReady(0) = '1' and motors='1' then
				current_face_notReady:=false;
			elsif actualDrive(0)='1' and is_dskReady(1) = '1' and motors='1' then
				current_face_notReady:=false;
			else
				current_face_notReady:=true;
			end if;
			
			block_W_cortex_mem:='0';
			
			if etat_wait then
				if phase = PHASE_WAIT_ATTENTE_COMMANDE and memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
					-- that's all folks !
					chrn:=getCHRN(megashark_CHRNresult); -- C (from SEEK command ask)
					etat_wait:=false;
					phase <= PHASE_ATTENTE_COMMANDE;
					action := ACTION_POLL;
					--leds8_debug(39 downto 32)<=x"C8";
					
					--leds8_debug(31 downto 24)<=megashark_CHRNresult(31 downto 24);
					--leds8_debug(23 downto 16)<=megashark_CHRNresult(23 downto 16);
					--leds8_debug(15 downto 8)<=megashark_CHRNresult(15 downto 8);
					--leds8_debug(7 downto 0)<=megashark_CHRNresult(7 downto 0);
					
					--leds8_debug(31 downto 24)<=x"00";
					--leds8_debug(23 downto 16)<=megashark_INFO_ST2;
					--leds8_debug(15 downto 8)<=megashark_INFO_ST1;
					--leds8_debug(7 downto 0)<=megashark_INFO_ST0 or "00000" & actualDrive(2 downto 0);
				elsif phase = PHASE_WAIT_EXECUTION_READ and memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
					-- that's all folks !
					etat_wait:=false;
					has_control_mark:=false;
					if megashark_INFO_PANIC=PANIC_RAGE_QUIT then -- FDCTEST.ASM &1B read2_del_data_skip (EOT skip)
						-- is_sector_or_track_not_found
						-- no bytes to read
						exec_restant_write:=0;
						exec_restant:=0;
						phase <= PHASE_RESULT;
						rcount:=7;
					else
						if is_EOT_DTL and megashark_CHRNresult(15 downto 8)=EOT then
							exec_restant:=EOT_DTL;
						else
							exec_restant:=SECTOR_SIZES(conv_integer(params(3)));
						end if;
						phase <= PHASE_EXECUTION_READ;
					end if;
					--leds8_debug(39 downto 32)<=x"08";
					
					--leds8_debug(31 downto 24)<=megashark_CHRNresult(31 downto 24);
					--leds8_debug(23 downto 16)<=megashark_CHRNresult(23 downto 16);
					--leds8_debug(15 downto 8)<=megashark_CHRNresult(15 downto 8);
					--leds8_debug(7 downto 0)<=megashark_CHRNresult(7 downto 0);
					
					--leds8_debug(31 downto 24)<=x"00";
					--leds8_debug(23 downto 16)<=megashark_INFO_ST2;
					--leds8_debug(15 downto 8)<=megashark_INFO_ST1;
					--leds8_debug(7 downto 0)<=megashark_INFO_ST0 or "00000" & actualDrive(2 downto 0);
				elsif phase = PHASE_WAIT_EXECUTION_WRITE and memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
					-- that's all folks !
					etat_wait:=false;
					if megashark_INFO_PANIC=PANIC_RAGE_QUIT then -- FDCTEST.ASM &43FAIL01 or (megashark_INFO_PANIC=PANIC_SLOW_QUIT and not(memshark_doWRITE_MT)) then
						-- is_sector_or_track_not_found
						-- no bytes to write
						exec_restant_write:=0;
						exec_restant:=0;
						phase <= PHASE_RESULT;
						rcount:=7;
					else
						phase <= PHASE_EXECUTION_WRITE;
					end if;
					--leds8_debug(39 downto 32)<=x"88";
					
					--leds8_debug(31 downto 24)<=megashark_CHRNresult(31 downto 24);
					--leds8_debug(23 downto 16)<=megashark_CHRNresult(23 downto 16);
					--leds8_debug(15 downto 8)<=megashark_CHRNresult(15 downto 8);
					--leds8_debug(7 downto 0)<=megashark_CHRNresult(7 downto 0);

					--leds8_debug(31 downto 24)<=x"00";
					--leds8_debug(23 downto 16)<=megashark_INFO_ST2;
					--leds8_debug(15 downto 8)<=megashark_INFO_ST1;
					--leds8_debug(7 downto 0)<=megashark_INFO_ST0 or "00000" & actualDrive(2 downto 0);
				elsif phase = PHASE_WAIT_RESULT and memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
					-- that's all folks !
					etat_wait:=false;
					phase <= PHASE_RESULT;
					--leds8_debug(39 downto 32)<=x"38";
					
					--leds8_debug(31 downto 24)<=megashark_CHRNresult(31 downto 24);
					--leds8_debug(23 downto 16)<=megashark_CHRNresult(23 downto 16);
					--leds8_debug(15 downto 8)<=megashark_CHRNresult(15 downto 8);
					--leds8_debug(7 downto 0)<=megashark_CHRNresult(7 downto 0);
					
					--leds8_debug(31 downto 24)<=x"00";
					--leds8_debug(23 downto 16)<=megashark_INFO_ST2;
					--leds8_debug(15 downto 8)<=megashark_INFO_ST1;
					--leds8_debug(7 downto 0)<=megashark_INFO_ST0 or "00000" & actualDrive(2 downto 0);
				end if;
			end if;
	
	
			if current_face_notReady or etat_wait then
				--The following bits are used from NEC765 status register 1:
				--b7 EN (End of Cylinder)
				--b5 DE (Data Error)
				--b2 ND (No Data)
				--b0 MA (Missing Address Mark)
				--The following bits are used from NEC765 status register 2:
				--b5 CM (Control Mark)
				--b5 DD (Data Error in Data field)
				--b0 MD (Missing address Mark in Data field)
			
				-- DSK NOT READY MESSAGE
				ST0:=ST0_ABNORMAL or ST0_NOT_READY or actualDrive; -- do press retry to test :/
				ST1:=x"00";
				ST2:=x"00";
				ST3:=x"00" or actualDrive;
			else
				ST0:=megashark_INFO_ST0 or "00000" & actualDrive(2 downto 0);
				ST1:=megashark_INFO_ST1;
				ST2:=megashark_INFO_ST2;
				--if megashark_INFO_ST0=ST0_END_OF_READ_DRIVE_USX and megashark_INFO_ST1=ST1_END_CYL and megashark_INFO_ST2=x"00" then
				--	-- normal finishing
				--	ST2:=megashark_INFO_ST2; -- is this the definition of "state H/US0/US1 at interrupt ???"
				--else
				--	ST2:=megashark_INFO_ST2 or actualDrive;
				--end if;
				-- TEST : |a |b |a using ss40t in drive A: and ds80t DOS D2 in drive B:
				-- RESULT : crash due to ST0_ABNORMAL returned in a simple READ_ID cmd...
				
				if (megashark_INFO_ST2 and ST2_CONTROL_MARK) = ST2_CONTROL_MARK then
					has_control_mark:=true;
				end if;
				
				ST3:=ST3_READY or actualDrive;
			end if;
			
			if megashark_INFO_2SIDES='1' then
				-- JavaCPC : 2T is at '1' if it is a double sided dsk...
				-- Batman in one disk not running correctly
				-- RTypes128K doesn't matter ST3_TWO_SIDE.
				ST3:=ST3 or ST3_TWO_SIDE;
			end if;
			--JavaCPC
			--if megashark_INFO_2SIDES='0' and actualDrive(2)='1' then
			--	--When the FDD IS in the not-ready state and (Not Ready) a Read or Write command IS Issued, this flag IS set 
			--	--If a Read or Write command isissued to side 1 of a single-sided drive,then this flag IS set
			--	ST0:=ST0 or ST0_NOT_READY;
			--end if;
				
			--When sector data is read, a byte comes every 32us. => overrun
			if (phase=PHASE_EXECUTION_WRITE or phase=PHASE_EXECUTION_READ) then
				if IS_ARNOLDEMU_TESTBENCH then
					gremlin:=gremlin+1;
				end if;
				if gremlin=gremlin'HIGH then
					-- FDCTEST.ASM &3D PHASE_EXECUTION_READ
					-- FDCTEST.ASM &45 PHASE_EXECUTION_WRITE
					--HELL (gremlin and (PHASE_EXECUTION_WRITE or PHASE_EXECUTION_READ))
					rcount:=7;
					action:=ACTION_OVERRUN;
					exec_restant:=0;
					exec_restant_write:=0;
					if etat_wait then
						phase<=PHASE_WAIT_RESULT; -- we switch into RESULT
					else
						phase<=PHASE_RESULT;
					end if;
				end if;
			end if;

-- Validated ! : IO_RD/IO_WR are false during T1 of Z80, and IO_RD can read output until its end.
-- that's the correct way to do.
			if ((wasIO_RD='0' and IO_RD='1') or (wasIO_WR='0' and IO_WR='1')) and A10_A8_A7=b"000" then
				-- I am concerned (motors)
				do_update:=true;
			elsif ((wasIO_RD='0' and IO_RD='1') or (wasIO_WR='0' and IO_WR='1')) and A10_A8_A7=b"010"  then
				-- I am concerned
				do_update:=true;
			elsif ((wasIO_RD='1' and IO_RD='1') or (wasIO_WR='1' and IO_WR='1')) and (A10_A8_A7=b"010" or A10_A8_A7=b"000") then
				-- dodo
				do_update:=false;
			else
				-- I am not concerned : unbind
				
				
				D_result<=(others=>'1');
				
				do_update:=false;
			end if;
			
--		 FDC Command Table
--
--Command     Parameters              Exm Result               Description
--02+MF+SK    HU TR HD ?? SZ NM GP SL <R> S0 S1 S2 TR HD NM SZ read track
--03          XX YY                    -                       specify spd/dma
--04          HU                       -  S3                   sense drive state
--05+MT+MF    HU TR HD SC SZ LS GP SL <W> S0 S1 S2 TR HD LS SZ write sector(s)
--06+MT+MF+SK HU TR HD SC SZ LS GP SL <R> S0 S1 S2 TR HD LS SZ read sector(s)
--07          HU                       -                       recalib.seek TP=0
--08          -                        -  S0 TP                sense int.state
--09+MT+MF    HU TR HD SC SZ LS GP SL <W> S0 S1 S2 TR HD LS SZ wr deleted sec(s)
--0A+MF       HU                       -  S0 S1 S2 TR HD LS SZ read ID
--0C+MT+MF+SK HU TR HD SC SZ LS GP SL <R> S0 S1 S2 TR HD LS SZ rd deleted sec(s)
--0D+MF       HU SZ NM GP FB          <W> S0 S1 S2 TR HD LS SZ format track
--0F          HU TP                    -                       seek track n
--11+MT+MF+SK HU TR HD SC SZ LS GP SL <W> S0 S1 S2 TR HD LS SZ scan equal
--19+MT+MF+SK HU TR HD SC SZ LS GP SL <W> S0 S1 S2 TR HD LS SZ scan low or equal
--1D+MT+MF+SK HU TR HD SC SZ LS GP SL <W> S0 S1 S2 TR HD LS SZ scan high or eq.
--
--Parameter bits that can be specified in some Command Bytes are:
--
-- MT  Bit7  Multi Track (continue multi-sector-function on other head)
-- MF  Bit6  MFM-Mode-Bit (Default 1=Double Density)
-- SK  Bit5  Skip-Bit (set if secs with deleted DAM shall be skipped)
--
--Parameter/Result bytes are:
--
-- HU  b0,1=Unit/Drive Number, b2=Physical Head Number, other bits zero
-- TP  Physical Track Number
-- TR  Track-ID (usually same value as TP)
-- HD  Head-ID
-- SC  First Sector-ID (sector you want to read)
-- SZ  Sector Size (80h shl n) (default=02h for 200h bytes)
-- LS  Last Sector-ID (should be same as SC when reading a single sector)
-- GP  Gap (default=2Ah except command 0D: default=52h)
-- SL  Sectorlen if SZ=0 (default=FFh)
-- Sn  Status Register 0..3
-- FB  Fillbyte (for the sector data areas) (default=E5h)
-- NM  Number of Sectors (default=09h)
-- XX  b0..3=headunload n*32ms (8" only), b4..7=steprate (16-n)*2ms
-- YY  b0=DMA_disable, b1-7=headload n*4ms (8" only)
			--leds8_debug(39 downto 32)<=status_mem; --conv_std_logic_vector(phase,8);
			--leds8_debug(31 downto 24)<=conv_std_logic_vector(action,8);
			--leds8_debug(23 downto 16)<=ST2;
			--leds8_debug(15 downto 8)<=ST1;
			--leds8_debug(7 downto 0)<=ST0;
			if do_update then
				--if CLK4(1)='1' then
					-- z80 is solved
					D_result<=(others=>'1');
					if (IO_RD='1' and A10_A8_A7=b"010" and A0='0') then
						-- read status
						-- read status
						status_mem:=status;
						if (is_seeking_FACE_A or is_seeking_FACE_B) and (is_issue or current_face_notReady) then
							status_mem:= status_mem or FDD_BUSY; -- FDCTEST.ASM &01 recal_nr (against FAIL 03)
						end if;
						if is_seeking_FACE_A then
							status_mem(0):='1';
						end if;
						if is_seeking_FACE_B then
							status_mem(1):='1';
						end if;
						D_result<=status_mem;
					elsif (IO_RD='1' and A10_A8_A7=b"010" and A0='1') then
						-- read data
						gremlin:=0;
						if phase=PHASE_EXECUTION_READ then
							if exec_restant>0 then
								exec_restant:=exec_restant-1;
							end if;
							if action=ACTION_READ then
								chrn:=getCHRN(megashark_CHRNresult);
								if not(etat_wait) then
									data:=block_Dout;
									D_result<=data;
								else
									D_result<=(others=>'1');
								end if;
								if current_byte=SECTOR_SIZE-1 then
									-- bug overflow !
									current_byte:=0;
								else
									current_byte:=current_byte+1;
								end if;
								if not(etat_wait) then
									block_A_cortex_mem:=conv_std_logic_vector(current_byte,9);
									block_W_cortex_mem:='0';
								end if;

								
								if exec_restant=0 then
									if megashark_INFO_PANIC=PANIC_SLOW_QUIT and not(is_multitrack) then
										if etat_wait then
											phase<=PHASE_WAIT_RESULT;
										else
											phase<=PHASE_RESULT;
										end if;
										rcount:=7;
										if is_readtrack then
												BOT:=chrn(1);
 										end if;
									else
										-- FDCTEST.ASM read_data_noskip R=1, EOT=9 => 2 read_data
										if megashark_INFO_PANIC=PANIC_SLOW_QUIT and is_multitrack then
											--FDCTEST.ASM &2D : is_readtrack+is_multitrack : EOT at 1 does read 2*512 sectors.
											-- FDCTEST.ASM &33 read_data_mt
											-- switch logical head also
											chrn(2)(0):=not(params(5)(0)); --not(chrn(2)(0)); -- H
											-- switch physical head also
											actualDrive(2):=not(actualDrive(2));
											BOT:=x"01";
											if is_readtrack then
												chrn(1):=params(4); -- R for flag
											else
												chrn(1):=BOT;
											end if;
											is_multitrack:=false;
										else
											if is_readtrack then
												BOT:=chrn(1)+x"01";
												chrn(1):=params(4); -- R for flag
											else
												BOT:=chrn(1)+x"01"; -- start at sector id
												chrn(1):=BOT;
											end if;
										end if;
										megashark_face(3 downto 0)<=actualDrive(3 downto 0);
										megashark_BOT_EOT<=BOT & EOT;
										
										memshark_is_writeDTL<=false;
										etat_wait := true;
										phase<=PHASE_WAIT_EXECUTION_READ;
										if memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
											-- on lance une tentative de lecture du block en parallele
											memshark_chrn<=setCHRN(chrn);
											memshark_doREAD<=true;
											if is_readtrack then
												memshark_doREADnext<=true;
											end if;
											memshark_doREAD_DEL<=is_del;
											memshark_doREAD_SK<=is_sk;
											memshark_doREAD_MT<=is_multitrack;
										else
											rcount:=7;
											exec_restant:=0;
											exec_restant_write:=0;
											action:=ACTION_OVERRUN;
											phase<=PHASE_WAIT_RESULT;
										end if;
									end if;
								end if;
								
							end if;
							
							
							
							
						
						elsif phase/=PHASE_RESULT then
							-- ###################
							-- #                 #
							-- # H H EEE L   L   #
							-- # H H E   L   L   #
							-- # HHH EE  L   L   #
							-- # H H E   L   L   #
							-- # H H EEE LLL LLL # RD
							-- #                 #
							-- ############################
							-- HELL (PHASE_EXECUTION_WRITE)
							exec_restant:=0;
							exec_restant_write:=0;
							rcount:=1;
							--is_issue:=true;
							result(0):=ST0_INVALID; -- invalid command issue
							-- ejection !
							if etat_wait then
								phase<=PHASE_WAIT_RESULT;
							else
								phase<=PHASE_RESULT;
							end if;
							--FDCTEST.ASM &3D PHASE_WAIT_EXECUTION_READ ?
							D_result<=ST0_INVALID; -- with a simple INVALID direct response
						else --PHASE_RESULT
							if action=ACTION_OVERRUN and rcount=7 then
								action:=ACTION_POLL;
								chrn:=getCHRN(megashark_CHRNresult);
								result(6):=ST0_ABNORMAL or "00000" & actualDrive(2 downto 0);
								result(5):=ST1_OVERRUN;
								result(4):=x"00";
								result(3):=chrn(3); -- C
								result(2):=chrn(2); -- H
								result(1):=chrn(1); -- R (READ_ID sector ID)
								result(0):=chrn(0); -- N (BLOCK_SIZE)
								
								--leds8_debug(39 downto 32)<=x"48";
					
								--leds8_debug(31 downto 24)<=result(3);
								--leds8_debug(23 downto 16)<=result(2);
								--leds8_debug(15 downto 8)<=result(1);
								--leds8_debug(7 downto 0)<=result(0);
								
								--leds8_debug(31 downto 24)<=x"00";
								--leds8_debug(23 downto 16)<=result(4);
								--leds8_debug(15 downto 8)<=result(5);
								--leds8_debug(7 downto 0)<=result(6);
								
							elsif action=ACTION_SCAN and rcount=7 then
								action:=ACTION_POLL;
								chrn:=getCHRN(megashark_CHRNresult);
								result(6):="00000" & actualDrive(2 downto 0);
								result(5):=x"00";
								if compare_OK then
									result(4):=ST2 or ST2_SCAN_EQUAL_HIT; -- ST2
								else
									result(4):=ST2 or ST2_SCAN_NOT_SATISFIED; -- ST2
								end if;
								result(3):=chrn(3); --params(6); -- C
								result(2):=chrn(2); --params(5); -- H
								result(1):=chrn(1); --SECTOR_FOUND; --params(2); -- R (EOT)
								result(0):=chrn(0); -- N (BLOCK_SIZE)
							elsif action=ACTION_WRITE and rcount=7 then
								action:=ACTION_POLL;
								chrn:=getCHRN(megashark_CHRNresult);
								result(6):=ST0; -- ST0
								result(5):=ST1;-- or ST1_END_CYL; -- ST1
								result(4):=ST2; -- ST2
								if current_face_notReady then
									--FDCTEST.ASM &42 test_write_nr (motors='0')
									result(3):=params(6);
									result(2):=params(5);
									result(1):=params(4);
									result(0):=params(3);
								else
									result(3):=chrn(3); --params(6); -- C
									result(2):=chrn(2); --params(5); -- H
									--FDCTEST.ASM &41 test_write2 (deleted write)
									result(1):=chrn(1); --SECTOR_FOUND; --params(2); -- R (EOT)
									result(0):=chrn(0); -- N (BLOCK_SIZE)
								end if;
							elsif action=ACTION_READ and rcount=7 then
								action:=ACTION_POLL;
								chrn:=getCHRN(megashark_CHRNresult);
								result(4):=ST2;
								result(5):=ST1;
								result(6):=ST0;
								if current_face_notReady then
									-- FDCTEST &15 read_nr_data (motors='0')
									result(3):=params(6);
									result(2):=params(5);
									result(1):=params(4);
									result(0):=params(3);
								else
									result(3):=chrn(3); -- params(6); -- C
									result(2):=chrn(2); -- params(5); -- H
									result(1):=chrn(1); -- params(4);
									result(0):=chrn(0); -- N (BLOCK_SIZE)
								end if;
							elsif action=ACTION_READ_ID and rcount=7 then-- PARADOS second drive seem have serious problem (with same data and fixed sector id here, size of disk/file is different), perhaps more FDC instructions runs
								action:=ACTION_POLL;
								chrn:=getCHRN(megashark_CHRNresult);
								result(6):=ST0;
								result(5):=ST1; -- ST1 (I'm always fine)
								result(4):=ST2; -- ST2
								result(3):=chrn(3); -- C
								result(2):=chrn(2); -- H
								result(1):=chrn(1); -- R (READ_ID sector ID)
								result(0):=chrn(0); --params(3); -- FDCTEST.ASM &47 chrn(0); -- N (BLOCK_SIZE)
							elsif action=ETAT_SENSE_DRIVE_STATUS and rcount=1 then
								action:=ACTION_POLL;
								chrn:=getCHRN(megashark_CHRNresult);
								if chrn(3)=0 then
									result(0):=ST3 or ST3_TRACK_0;
								else
									result(0):=ST3;
								end if;
							elsif action=ETAT_SENSE_INTERRUPT_STATUS  and rcount=3 then
								action:=ACTION_POLL;
								--chrn:=getCHRN(megashark_CHRNresult); -- result of a previous seek/recalibrate
								if (is_seeking_FACE_A or is_seeking_FACE_B) and current_face_notReady then
									-- FDCTEST.ASM &01 recal_nr
									is_issue:=true;
								end if;
								if is_issue or is_abnormal_motor then
									 -- generaly just after a failing "read command"
									is_issue:=false;
									is_abnormal_motor:=false;
									-- JavaCPC rcount = 1;
									if is_seeking_FACE_A or is_seeking_FACE_B then
										-- FDCTEST.ASM &01 recal_nr
										rcount:=2;
										result(1):=ST0 or ST0_ABNORMAL or ST0_SEEK_END;
										result(0):=x"00";
									else
										-- motors='0'
										rcount:=1;
										result(0):=ST0_INVALID or ST0_ABNORMAL; -- FDCTEST.ASM &0E sens_intr2
									end if;
									is_seeking_FACE_A:=false;
									is_seeking_FACE_B:=false;
									is_recalibrating_FACE_A:=false;
									is_recalibrating_FACE_B:=false;
								elsif is_seeking_FACE_A then --actualDrive(1 downto 0)="00" and is_seeking_FACE_A then
									rcount:=2;
									-- FDCTEST.ASM &00 recal_test : attention, il faut mettre la disquette de test en |B sinon le test "fail 69"
									if is_recalibrating_FACE_A and chrn(3)/=x"00" then
										-- is_sector_or_track_not_found => seek 77 not returned at track 0 !
										result(1):=ST0 or ST0_ABNORMAL or ST0_SEEK_END or ST0_EQUIP_CHECK; -- recalibrate => seek 77 not returned at track 0 !
										result(0):=x"00";
									else
										result(1):=ST0 or ST0_SEEK_END; -- generaly just after a "recalibrate command" ST0_SEEK_END
										result(0):=chrn(3); -- C -- PCN : Present Cylinder Number
									end if;
									is_seeking_FACE_A:=false;
									is_recalibrating_FACE_A:=false;
								elsif is_seeking_FACE_B then --actualDrive(1 downto 0)="01" and is_seeking_FACE_B then
									rcount:=2;
									-- FDCTEST.ASM &00 recal_test : attention, il faut mettre la disquette de test en |B sinon le test "fail 69"
									if is_recalibrating_FACE_B and chrn(3)/=x"00" then
										-- is_sector_or_track_not_found => seek 77 not returned at track 0 !
										result(1):=ST0 or  ST0_ABNORMAL or ST0_SEEK_END or ST0_EQUIP_CHECK ; -- recalibrate => seek 77 not returned at track 0 !
										result(0):=x"00";
									else
										result(1):=ST0 or ST0_SEEK_END; -- generaly just after a "recalibrate command" ST0_SEEK_END
										result(0):=chrn(3); -- C -- PCN : Present Cylinder Number
									end if;
									is_seeking_FACE_B:=false;
									is_recalibrating_FACE_B:=false;
								else
									-- FDCTEST.ASM &0D sens_intr1
									-- Cpc Aventure : "Please insert disk 2" message ?
									rcount:=1;
									-- JavaCPC result[rindex = 0] = ST0_INVALID;
									--result(0):=ST0 or ST0_INVALID;
									-- FDCTEST.ASM &0D sens_intr1
									-- FDCHELPER.ASM do_motor_off clear_fdd_interrupts
									result(0):=ST0_INVALID; -- invalid command issue
								end if;
							end if;
							
							if rcount>0 then
							
								rcount:=rcount-1;
								
								data:=result(rcount);
								D_result<=data;
								
								if rcount=0 then
									if etat_wait then
										phase<=PHASE_WAIT_ATTENTE_COMMANDE;
									else
										phase<=PHASE_ATTENTE_COMMANDE;
									end if;
									action:=ACTION_POLL;
								end if;
							else
								-- INVALID
								D_result<=ST0_INVALID;
							end if;
						end if;
							
							
							
					
					elsif (IO_WR='1' and A10_A8_A7=b"000") then -- http://www.cpcwiki.eu/index.php/Default_I/O_Port_Summary
						motors:=D_command(0);
						if motors='0' and not(current_face_notReady) then
							is_abnormal_motor:=true; -- FDCTEST.ASM &0E sens_intr2
							if phase = PHASE_WAIT_EXECUTION_READ or phase = PHASE_EXECUTION_READ then
								rcount:=1;
								--is_issue:=true;
								result(0):=ST0_INVALID; -- invalid command issue
								exec_restant:=0;
								exec_restant_write:=0;
								if etat_wait then
									phase<=PHASE_WAIT_RESULT; -- we switch into RESULT
								else
									phase<=PHASE_RESULT;
								end if;
							elsif (phase=PHASE_EXECUTION_WRITE or phase=PHASE_AFTER_EXECUTION_WRITE or phase=PHASE_WAIT_EXECUTION_WRITE) then
								-- FDCTEST.ASM &40 test_write_rc
								rcount:=1;
								--is_issue:=true;
								result(0):=ST0_INVALID; -- invalid command issue
								exec_restant:=0;
								exec_restant_write:=0;
								if etat_wait then
									phase<=PHASE_WAIT_RESULT; -- we switch into RESULT
								else
									phase<=PHASE_RESULT;
								end if;
							end if;
						elsif motors='1' then
							is_abnormal_motor:=false;
						end if;




						
					elsif (IO_RD='1' and A10_A8_A7=b"000") then
						-- WinAPE does return 128 for anything... even FDC status...
						-- PRINT INP(&FA7E)
						D_result<="0000000" & motors;
					elsif (IO_WR='1' and A10_A8_A7=b"010" and A0='0') then
						-- HELL
					elsif (IO_WR='1' and A10_A8_A7=b"010" and A0='1') then
						-- write data
						gremlin:=0;
						if phase=PHASE_EXECUTION_WRITE then
							if exec_restant_write>0 then
								exec_restant_write:=exec_restant_write-1;
							end if;
							if action=ACTION_WRITE then
								--if current_byte>=SECTOR_SIZES(chrn(3)) then
								data:=D_command;
								if not(etat_wait) then
									block_A_cortex_mem:=conv_std_logic_vector(current_byte,9);
									block_Din_cortex_mem:=data;
									block_W_cortex_mem:='1';
								end if;
								if current_byte=SECTOR_SIZE-1 then
									--overrun
									current_byte:=0;
								else
									current_byte:=current_byte+1;
								end if;
								if exec_restant_write=0 then
									if etat_wait then
										exec_restant_write:=0;
										exec_restant:=0;
										rcount:=1;
										--is_issue:=true;
										result(0):=ST0_INVALID; -- invalid command issue
										phase<=PHASE_WAIT_RESULT;
									else
										--rcount:=7;
										phase<=PHASE_AFTER_EXECUTION_WRITE;
										etat_wait:=true;
									end if;
								end if;
							elsif action=ACTION_SCAN then
								--if current_byte>=SECTOR_SIZES(chrn(3)) then
								data:=D_command;
								if not(etat_wait) then
									if compare_OK then
										if block_Dout=data then
											-- cool
										elsif compare_low_or_equal and block_Dout<=data then
											-- cool
										elsif compare_high_or_equal and block_Dout>=data then
											-- cool
										else
											compare_OK:=false;
										end if;
									end if;
								end if;
								if current_byte=SECTOR_SIZE-1 then
									--overrun
									current_byte:=0;
								else
									current_byte:=current_byte+1;
								end if;
								
								if not(etat_wait) then
									block_A_cortex_mem:=conv_std_logic_vector(current_byte,9);
									block_W_cortex_mem:='0';
								end if;
								
								if exec_restant_write=0 then
									if EOT=chrn(1) then
										if etat_wait then
											phase<=PHASE_WAIT_RESULT;
										else
											phase<=PHASE_RESULT;
										end if;
										rcount:=7;
									else
										BOT:=chrn(1)+1;
										chrn(1):=BOT;
										if EOT=BOT and is_EOT_DTL then
											exec_restant_write:=EOT_DTL;
											memshark_is_writeDTL<=true;
										else
											exec_restant_write:=SECTOR_SIZE;
											memshark_is_writeDTL<=false;
										end if;
										etat_wait := true;
										phase<=PHASE_WAIT_EXECUTION_WRITE;
										if memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
											-- on lance une tentative de lecture du block en parallele
											memshark_chrn<=setCHRN(chrn);
											memshark_doREAD<=true;
											--memshark_doREADnext<=true; -- FDCTEST.ASM scan_equal : EF
											memshark_doREAD_DEL<=is_del;
											memshark_doREAD_SK<=is_sk;
											memshark_doREAD_MT<=is_multitrack;
											-- pointer charger le premier octet (tout de suite ou apres la sortie d'un PHASE_WAIT_*)
											block_A_cortex_mem:=conv_std_logic_vector(current_byte,9);
											block_W_cortex_mem:='0';
										else
											rcount:=1;
											--is_issue:=true;
											result(0):=ST0_INVALID; -- invalid command issue
											phase<=PHASE_WAIT_RESULT;
										end if;
									end if;
								end if;
							else
								-- HELL
							end if;
						elsif phase=PHASE_ATTENTE_COMMANDE or phase=PHASE_RESULT then
							-- PHASE_RESULT : FDCTEST.ASM &55
							-- result is facultative.
							phase<=PHASE_ATTENTE_COMMANDE;
							pcount:=0;
							exec_restant:=0;
							exec_restant_write:=0;
							rcount:=0;
							action:=ACTION_POLL;
							-- MT MF et SK (we don't care about theses 3 first bits)
							command:=D_command and x"1f";
							is_multitrack:=(D_command(7)='1');
							is_low_density:=(D_command(6)='0');
							is_del:=false;
							is_sk:=(D_command(5)='1');
							is_readtrack:=false;
							check_dsk_face:=false;
							check_dsk_low_density:=false;

							compare_OK:=false;
							case command is
								when x"02" => -- read track
									-- defw read_track9		;; 2D read track with multi-track (starting side 0) --is_multitrack:=false; -- READ_DIAGNOSTIC : pas de MT ici <= en fait si !
									action:=ACTION_READ; -- getNextSector(READ) with resetSector() : sector=0
									phase<=PHASE_COMMAND;
									is_readtrack:=true; -- EOT is not sector, but sector count.
									pcount:=8;
									check_dsk_face:=true;
									--check_dsk_low_density:=true;
									--is_multitrack:=false;  -- FDCTEST.ASM &2D : MT read_track : taken into account.
								when x"03" => -- specify
									pcount:=2;
									phase<=PHASE_COMMAND;
									is_multitrack:=false;
									is_sk:=false;
								when x"04" => -- SENSE DRIVE STATUS
									pcount:=1;
									action:=ETAT_SENSE_DRIVE_STATUS;
									check_dsk_face:=true;
									phase<=PHASE_COMMAND;
									is_multitrack:=false;
									is_sk:=false;
								when x"05" => -- write data
									pcount:=8;
									phase<=PHASE_COMMAND;
									action:=ACTION_WRITE;
									check_dsk_face:=true;
									--check_dsk_low_density:=true;
									is_sk:=false;
								when x"06" => -- read
									pcount:=8;
									action:=ACTION_READ; -- getNextSector(READ) : sector=0
									phase<=PHASE_COMMAND;
									check_dsk_face:=true;
									--FDCTEST.ASM &4C read_data_low
									check_dsk_low_density:=true;
								when x"07" => -- recalibrate (==SEEK at C=0, 77 fois max)
									pcount:=1;
									action:=ETAT_RECALIBRATE;
									phase<=PHASE_COMMAND;
									check_dsk_face:=true;
									is_multitrack:=false;
									is_sk:=false;
								when x"08" => -- sense interrupt status : status information about the FDC at the end of operation
									rcount:=3;
									if etat_wait then
										phase<=PHASE_WAIT_RESULT;
									else
										phase<=PHASE_RESULT;
									end if;
									action:=ETAT_SENSE_INTERRUPT_STATUS;
									is_multitrack:=false;
									is_sk:=false;
								when x"09" => -- write DELETED DATA
									pcount:=8;
									phase<=PHASE_COMMAND;
									action:=ACTION_WRITE;
									is_del:=true;
									check_dsk_face:=true;
									--check_dsk_low_density:=true;
									is_sk:=false;
								when x"0a" => -- read id
									pcount:=1; -- select drive/side
									action:=ACTION_READ_ID;
									check_dsk_face:=true;
									check_dsk_low_density:=true;
									phase<=PHASE_COMMAND;
									is_multitrack:=false;
									is_sk:=false;
								when x"0C" => -- read DELETED DATA
									pcount:=8;
									action:=ACTION_READ;
									phase<=PHASE_COMMAND;
									is_del:=true; -- skip [not] set? if (isDeletedData()) {result[2] |= 0x040;}
									check_dsk_face:=true;
									--check_dsk_low_density:=true;
								when x"0f" => -- seek : changing track C
									phase<=PHASE_COMMAND;
									pcount:=2;
									action:=ACTION_SEEK;
									check_dsk_face:=true;
									is_multitrack:=false;
									is_sk:=false;
								when x"11" => -- SCAN EQUAL
									pcount:=8;
									phase<=PHASE_COMMAND;
									action:=ACTION_SCAN;
									compare_low_or_equal:=false;
									compare_high_or_equal:=false;
									check_dsk_face:=true;
									--check_dsk_low_density:=true;
								when x"19" => -- SCAN LOW OR EQUAL
									pcount:=8;
									phase<=PHASE_COMMAND;
									action:=ACTION_SCAN;
									compare_low_or_equal:=true;
									compare_high_or_equal:=false;
									check_dsk_face:=true;
									--check_dsk_low_density:=true;
								when x"1D" => -- SCAN HIGH OR EQUAL
									pcount:=8;
									phase<=PHASE_COMMAND;
									action:=ACTION_SCAN;
									compare_low_or_equal:=false;
									compare_high_or_equal:=true;
									check_dsk_face:=true;
									--check_dsk_low_density:=true;
								when x"10" => -- VERSION
									rcount:=1;
									result(0):=x"80"; -- 80H indicates 765A/A-2 as JavaCPC
									--result(0):=ST0 or x"90"; --90h indicates 765B
									if etat_wait then
										phase<=PHASE_WAIT_RESULT;
									else
										phase<=PHASE_RESULT;
									end if;
								when others => --INVALID
									--go to standby state
									rcount:=1;
									result(0):=ST0_INVALID; -- 80h 
									if etat_wait then
										phase<=PHASE_WAIT_RESULT;
									else
										phase<=PHASE_RESULT;
									end if;
							end case;
						elsif phase=PHASE_COMMAND then
							if pcount>0 then
								pcount:=pcount-1;
								params(pcount):=D_command;
								if check_dsk_face then
									check_dsk_face:=false;
									-- HD : physical HEAD
									actualDrive(2 downto 0):=D_command(2 downto 0); -- HD US1 US0
									if check_dsk_low_density and is_low_density then
										actualDrive(3):='1';
									else
										actualDrive(3):='0';
									end if;
									megashark_face(3 downto 0)<=actualDrive(3 downto 0);
								end if;
							end if;
							if pcount=0 then
								if action=ETAT_RECALIBRATE then -- no result
									actualDrive(2):='0';
									megashark_face(3 downto 0)<=actualDrive(3 downto 0);
									-- let's go
									if actualDrive(1 downto 0)="00" then
										is_seeking_FACE_A:=true;
										is_recalibrating_FACE_A:=true;
									elsif actualDrive(1 downto 0)="01" then
										is_seeking_FACE_B:=true;
										is_recalibrating_FACE_B:=true;
									end if;
									-- goto track 0 side 0
									if current_face_notReady then
										--FDCTEST.ASM &01 recal_nr
										-- disk not inserted
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=0; -- GOTO INVALID (SEEK ISSUE)
										is_issue:=true;
									elsif memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
										actualDrive(2):='0';
										memshark_chrn<=x"00000002";
										memshark_doGOTO<=true;
										memshark_doGOTO_R<=true;
										etat_wait := true;
									else
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=0; -- GOTO INVALID (SEEK ISSUE)
										is_issue:=true;
										-- system not ready
										etat_wait := true;
									end if;
								elsif action=ACTION_READ_ID then
									rcount:=7;
									if current_face_notReady then
										-- disk not inserted
										-- FDCTEST &4A read_id_nr
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=7; -- goto RESULT
									elsif memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
										-- let's go
										--FDCTEST.ASM &47 : conserve last used chrn
										chrn:=getCHRN(megashark_CHRNresult);
										memshark_chrn<=setCHRN(chrn);
										memshark_doGOTO<=true;
										etat_wait := true;
									else
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=1;
										--is_issue:=true;
										result(0):=ST0_INVALID; -- invalid command issue
										-- system not ready
										etat_wait := true;
									end if;
								elsif action=ACTION_SCAN then
									BOT:=params(4);
									EOT:=params(2); -- EOT = R
									megashark_BOT_EOT<=BOT & EOT;
									chrn(3):=params(6); -- C
									chrn(2):=params(5); -- H
									chrn(1):=params(4); -- R
									chrn(0):=BLOCK_SIZE; -- N
									-- params select C H R N EOT GPL DTL
									if params(3)>x"00" then -- N
										is_EOT_DTL:=false;
										
										exec_restant_write:=SECTOR_SIZE;--S(params(3)); -- SECTOR_SIZES(params(3))
									else
										is_EOT_DTL:=true;
										EOT_DTL:=conv_integer(params(0)); -- DTL
										if EOT_DTL=0 then
											-- (FDCTEST.ASM 5B)
											EOT_DTL:=256;
										end if;
										if BOT=EOT then
											exec_restant_write:=EOT_DTL; -- DTL
											--memshark_DTL<=EOT_DTL;
										else
											exec_restant_write:=SECTOR_SIZE;
											--memshark_DTL<=EOT_DTL;
										end if;
										--dtl:=conv_integer(params(0))+1; -- we don't call write cmd for nothing, so dtl=0 is for something : 1 byte, and FF is for 512 bytes
									end if;
									current_byte:=0;
									if current_face_notReady then
										-- disk not inserted
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=0; -- GOTO INVALID
									elsif memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
										-- on lance une tentative de lecture du block en parallele
										memshark_chrn<=setCHRN(chrn);
										memshark_doREAD<=true;
										memshark_doREAD_DEL<=is_del;
										memshark_doREAD_SK<=is_sk;
										memshark_doREAD_MT<=is_multitrack;
										etat_wait := true;
										compare_OK:=true;
									else
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=1;
										--is_issue:=true;
										result(0):=ST0_INVALID; -- invalid command issue
										-- system not ready
										etat_wait := true;
									end if;
									-- pointer charger le premier octet (tout de suite ou apres la sortie d'un PHASE_WAIT_*)
									block_A_cortex_mem:=conv_std_logic_vector(current_byte,9);
									block_W_cortex_mem:='0';
								elsif action=ACTION_READ then
									if is_readtrack then
										-- JavaCPC resetSector();
										BOT:=x"01"; -- do read first track please.
									else
										BOT:=params(4);
									end if;
									EOT:=params(2); -- EOT = R
									megashark_BOT_EOT<=BOT & EOT;
									chrn(3):=params(6); -- C
									chrn(2):=params(5); -- H
									if chrn(2)(0)='1' then --and actualDrive(2)='1' then
										--FDCTEST.ASM &36 read_data_mt4
										is_multitrack:=false;
									end if;
									chrn(1):=params(4); -- R
									chrn(0):=params(3); -- N -- FDCTEST.ASM &12 read_data3
									-- params select C H R N EOT GPL DTL
									if params(3)>x"00" then -- N
										is_EOT_DTL:=false;
										exec_restant:=SECTOR_SIZES(conv_integer(params(3))); -- gÃƒÆ’Ã‚Â©nÃƒÆ’Ã‚Â©ralement N=2 : SECTOR_SIZE=512
									else
										is_EOT_DTL:=true;
										EOT_DTL:=conv_integer(params(0));
										if is_readtrack then
											-- FDCTEST.ASM &28 read_track5
											--arnoldemu : Testing so far indicates if bit 0 of DTL is set to 0, then 0x028 is read, otherwise it's 0x050, but there is more to it.
--											if EOT_DTL mod 2 = 0 then
--												EOT_DTL:=40; -- 0x028
--											else
--												EOT_DTL:=80; -- 0x050
--											end if;
											-- FDCTEST.ASM &5C check_dtl1 => devrait selon commentaire retourner "0050" (80) et non "0100" à l'écran.
											if EOT_DTL >= 128 then
												EOT_DTL:=80; -- 0x050
											else
												EOT_DTL:=40; -- 0x028
											end if;
										elsif EOT_DTL=0 then
											-- FDCTEST.ASM 5B
											EOT_DTL:=256;
										end if;
										if (is_readtrack and EOT=x"01") or (not(is_readtrack) and BOT=EOT) then
											-- FDCTEST.ASM &28 read_track5
											exec_restant:=EOT_DTL; -- DTL
											--memshark_DTL<=EOT_DTL;
										else
											exec_restant:=SECTOR_SIZE;
											--memshark_DTL<=0;
										end if;
										--dtl:=conv_integer(params(0))+1; -- we don't call write cmd for nothing, so dtl=0 is for something : 1 byte, and FF is for 512 bytes
									end if;
									current_byte:=0;
									if current_face_notReady then
										-- disk not inserted
										-- FDCTEST &15 read_nr_data
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=7; -- goto RESULT
									elsif memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
										-- on lance une tentative de lecture du block en parallele
										memshark_chrn<=setCHRN(chrn);
										memshark_doREAD<=true;
										if is_readtrack then
											memshark_doREADnext<=true;
										end if;
										memshark_doREAD_DEL<=is_del;
										memshark_doREAD_SK<=is_sk;
										memshark_doREAD_MT<=is_multitrack;
										etat_wait := true;
									else
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=1;
										--is_issue:=true;
										result(0):=ST0_INVALID; -- invalid command issue
										-- system not ready
										etat_wait := true;
									end if;
									-- pointer charger le premier octet (tout de suite ou apres la sortie d'un PHASE_WAIT_*)
									block_A_cortex_mem:=conv_std_logic_vector(current_byte,9);
									block_W_cortex_mem:='0';
								elsif action=ACTION_SEEK then -- no result
									-- let's go
									if actualDrive(1 downto 0)="00" then
										is_seeking_FACE_A:=true;
										is_recalibrating_FACE_A:=false;
									elsif actualDrive(1 downto 0)="01" then
										is_seeking_FACE_B:=true;
										is_recalibrating_FACE_B:=false;
									end if;
									-- params select NCN
									if current_face_notReady then
										-- disk not inserted
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=0; -- GOTO INVALID (SEEK ISSUE)
										is_issue:=true;
									elsif memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
										chrn(3):=params(0); -- C = param NCN
										chrn(2):="0000000" & actualDrive(2); -- H
										chrn(1):=TRACK_00; -- R
										chrn(0):=BLOCK_SIZE; -- N
										memshark_chrn<=setCHRN(chrn);
										memshark_doGOTO<=true;
										memshark_doGOTO_T<=true;
										etat_wait := true;
									else
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=0; -- GOTO INVALID (SEEK ISSUE)
										is_issue:=true;
										-- system not ready
										etat_wait := true;
									end if;
								elsif action=ETAT_SENSE_DRIVE_STATUS then
									rcount:=1;
									if current_face_notReady then
										---- FDCHELPER.ASM ready
										-- disk not inserted
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=1; -- FDCTEST.ASM &56 drive_status1
									elsif memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
										-- let's go
										--chrn(2):="0000000" & actualDrive(2); -- H
										--chrn(0):=BLOCK_SIZE;
										--conserve last used chrn
										chrn:=getCHRN(megashark_CHRNresult);
										memshark_chrn<=setCHRN(chrn);
										memshark_doGOTO<=true;
										etat_wait := true;
									else
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=1;
										--is_issue:=true;
										result(0):=ST0_INVALID; -- invalid command issue
										-- system not ready
										etat_wait := true;
									end if;
								elsif action=ACTION_WRITE then
									BOT:=params(4);
									EOT:=params(2); -- R (EOT)
									--megashark_BOT_EOT<=BOT & EOT;
									chrn(3):=params(6); -- C
									chrn(2):=params(5); -- H
									if chrn(2)(0)='1' then --and actualDrive(2)='1' then
										is_multitrack:=false;
									end if;
									chrn(1):=params(4); -- R
									chrn(0):=BLOCK_SIZE; -- N
									-- params select C H R N EOT GPL DTL
									if params(3)>x"00" then -- N
										is_EOT_DTL:=false;
										exec_restant_write:=SECTOR_SIZE;--S(params(3)); -- SECTOR_SIZES(params(3))
									else
										is_EOT_DTL:=true;
										EOT_DTL:=conv_integer(params(0)); -- DTL
										if EOT_DTL=0 then
											-- (FDCTEST.ASM 5E)
											EOT_DTL:=256;
										end if;
										if BOT=EOT then
											exec_restant_write:=EOT_DTL; -- DTL
											--memshark_DTL<=EOT_DTL;
										else
											exec_restant_write:=SECTOR_SIZE;
											--memshark_DTL<=EOT_DTL;
										end if;
									end if;
									current_byte:=0;
									
									if current_face_notReady then
										-- disk not inserted
										-- FDCTEST &42 test_write_nr
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=7; -- goto RESULT
									elsif memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
										etat_wait := false; -- cool, no action at this step, goto next step.
									else
										exec_restant:=0;
										exec_restant_write:=0;
										rcount:=1;
										--is_issue:=true;
										result(0):=ST0_INVALID; -- invalid command issue
										-- system not ready
										etat_wait := true;
									end if;
								end if;
								if exec_restant>0 then
									if etat_wait then
										phase<=PHASE_WAIT_EXECUTION_READ; -- we switch into execution_read
									else
										phase<=PHASE_EXECUTION_READ;
									end if;
								elsif exec_restant_write>0 then
									if etat_wait then
										phase<=PHASE_WAIT_EXECUTION_WRITE;
									else
										phase<=PHASE_EXECUTION_WRITE;
									end if;
								elsif rcount>0 then
									if etat_wait then
										phase<=PHASE_WAIT_RESULT; -- we switch into RESULT
									else
										phase<=PHASE_RESULT;
									end if;
								else
									if etat_wait then
										-- This case does really exists, proof : action=ACTION_POLL, command recalibrate()
										phase<=PHASE_WAIT_ATTENTE_COMMANDE;
									else
										phase<=PHASE_ATTENTE_COMMANDE; -- GOTO INVALID
										action := ACTION_POLL;
									end if;
								end if;
							end if;
						else
							-- HELL (PHASE_EXECUTION_READ)
							-- ###########################
							-- #                 #
							-- # H H EEE L   L   #
							-- # H H E   L   L   #
							-- # HHH EE  L   L   #
							-- # H H E   L   L   #
							-- # H H EEE LLL LLL # WR
							-- #                 #
							-- ###################
							exec_restant:=0;
							exec_restant_write:=0;
							rcount:=1;
							--is_issue:=true;
							result(0):=ST0_INVALID; -- invalid command issue
							-- ejection !
							if etat_wait then
								phase<=PHASE_WAIT_RESULT;
							else
								phase<=PHASE_RESULT;
							end if;
						end if;
					end if;

			end if; --do_update
			
			
			
			
			
			

			if phase=PHASE_AFTER_EXECUTION_WRITE then
				-- special
				if current_face_notReady then
					-- disk not inserted
					exec_restant:=0;
					exec_restant_write:=0;
					rcount:=0; -- GOTO INVALID
					if etat_wait then
						phase<=PHASE_WAIT_RESULT;
					else
						phase<=PHASE_RESULT;
					end if;
				elsif memshark_done and not (memshark_doGOTO or memshark_doREAD or memshark_doWRITE) then
					-- pas de skip ici.
					
					if EOT=BOT and is_EOT_DTL and EOT_DTL=0 and not(is_multitrack) then
						-- nothing to write here...
						etat_wait:=false;
						rcount:=7;
						phase<=PHASE_RESULT;
					elsif EOT=BOT and not(is_multitrack) then
						if is_EOT_DTL then
							memshark_is_writeDTL<=true;
						else
							memshark_is_writeDTL<=false;
						end if;
						memshark_chrn<=setCHRN(chrn);
						memshark_doWRITE<=true;
						memshark_doWRITE_DEL<=is_del;
						memshark_doWRITE_MT<=is_multitrack;
						megashark_face(3 downto 0)<=actualDrive(3 downto 0);
						megashark_BOT_EOT<=BOT & EOT;
						etat_wait:=true;
						exec_restant_write:=0;
						exec_restant:=0;
						rcount:=7;
						phase<=PHASE_WAIT_RESULT;
					else
						-- one more time :)
						memshark_is_writeDTL<=false;
						memshark_chrn<=setCHRN(chrn);
						memshark_doWRITE<=true;
						memshark_doWRITE_DEL<=is_del;
						memshark_doWRITE_MT<=is_multitrack;
						megashark_face(3 downto 0)<=actualDrive(3 downto 0);
						megashark_BOT_EOT<=BOT & EOT;

						if EOT=BOT and is_multitrack then
							-- switch logical head also
							chrn(2)(0):=not(params(5)(0)); --not(chrn(2)(0)); -- H -- later.
							-- switch physical head also
							actualDrive(2):=not(actualDrive(2)); -- later.
							is_multitrack:=false; -- later.
							BOT:=x"01";
							chrn(1):=BOT; -- later.
						else
							BOT:=BOT+1;
							chrn(1):=BOT; -- later.
						end if;
						
						if EOT=BOT and is_EOT_DTL and not(is_multitrack) then
							exec_restant_write:=EOT_DTL;
						else
							exec_restant_write:=SECTOR_SIZE;
						end if;
						
						etat_wait:=true;
						phase<=PHASE_WAIT_EXECUTION_WRITE;
						current_byte:=0;
					end if;
				else
					exec_restant:=0;
					exec_restant_write:=0;
					rcount:=1;
					result(0):=ST0_INVALID; -- invalid command issue
					--is_issue:=true;
					-- system not ready
					etat_wait := true;
					phase<=PHASE_WAIT_RESULT;
				end if;
			end if;
			
			wasIO_RD:=IO_RD;
			wasIO_WR:=IO_WR;
			
			memshark_DTL<=EOT_DTL;
			
			block_A_cortex<=block_A_cortex_mem;
			block_Din_cortex<=block_Din_cortex_mem;
			block_W_cortex<=block_W_cortex_mem;
			
		
	end if;
end process cortex;


end Behavioral;




--FDC Basic testbench[edit]
--TODO : put theses basic scripts directly in comments in source file, not in wiki.... too verbose :/
--
--Results from WinAPE... (left Alt is "COPY" key)
--
--SEEK.BAS :
--
--5 OUT &FA7E,1:PRINT"MOTOR ON":PRINT"GOSUB 520 : MOTOR OFF"
--10 PRINT "GOSUB 40 : RECALIBRATE":PRINT "GOSUB 70 : SEEK"
--20 PRINT "GOSUB 110 : SENSE_INTERRUPT_STATUS":PRINT "GOSUB 150 : STATUS"
--25 PRINT "GOSUB 170 : READ_DATA":PRINT "GOSUB 420 : READ_ID"
--30 END
--40 OUT &FB7F,&X00000111
--50 OUT &FB7F,&X00000000:PRINT"US1 US0)
--60 RETURN
--70 OUT &FB7F,&X00001111
--80 OUT &FB7F,&X00000000:PRINT"HD US1 US0)"
--90 OUT &FB7F,&X00000010:PRINT"TRACK"
--100 RETURN
--110 OUT &FB7F,&X00001000
--120 PRINT BIN$(INP(&FB7F),8):PRINT"ST0"
--130 PRINT BIN$(INP(&FB7F),8):PRINT"PCN CURRENT TRACK"
--140 RETURN
--150 PRINT BIN$(INP(&FB7E),8)
--160 RETURN
--170 OUT &FB7F,&X01000110:PRINT"(MT MF SK"
--180 OUT &FB7F,&X00000000:PRINT"HD US1 US0)"
--190 OUT &FB7F,&X00000000:PRINT"C"
--200 OUT &FB7F,&X00000000:PRINT"H"
--210 OUT &FB7F,&C1:PRINT"R"
--220 OUT &FB7F,&X00000010:PRINT"N"
--230 OUT &FB7F,&C1:PRINT"EOT"
--240 OUT &FB7F,&X00101010:PRINT"GPL"
--250 OUT &FB7F,&X11111111:PRINT"DTL"
--260 status%=INP(&FB7E):PRINT BIN$(status%,8):if status%=&X11110000 then 280 else if status%=&X11010000 then 340
--270 print"BAD STATUS":goto 260
--275 a$=inkey$:if a$="" then 275 else 260
--280 for a%=1 to 512
--290 status%=INP(&FB7E):PRINT BIN$(status%,8):if status% <> &X11110000 then 290
--300 print HEX$(INP(&FB7F),2)," (",a%,")"
--310 next a%
--320 status%=INP(&FB7E):PRINT BIN$(status%,8):if status% <> &X11010000 then 320
--330 a$=inkey$:if a$="" then 330
--340 PRINT BIN$(INP(&FB7F),8):PRINT"ST0"
--350 PRINT BIN$(INP(&FB7F),8):PRINT"ST1"
--360 PRINT BIN$(INP(&FB7F),8):PRINT"ST2"
--370 PRINT BIN$(INP(&FB7F),8):PRINT"C"
--380 PRINT BIN$(INP(&FB7F),8):PRINT"H"
--390 PRINT HEX$(INP(&FB7F),2):PRINT"R"
--400 PRINT BIN$(INP(&FB7F),8):PRINT"N"
--410 RETURN
--420 OUT &FB7F,&X01001010:PRINT"(0 MF"
--430 OUT &FB7F,&X00000000:PRINT"HD US1 US0)"
--440 PRINT BIN$(INP(&FB7F),8):PRINT"ST0"
--450 PRINT BIN$(INP(&FB7F),8):PRINT"ST1"
--460 PRINT BIN$(INP(&FB7F),8):PRINT"ST2"
--470 PRINT BIN$(INP(&FB7F),8):PRINT"C"
--480 PRINT BIN$(INP(&FB7F),8):PRINT"H"
--490 PRINT HEX$(INP(&FB7F),2):PRINT"R"
--500 PRINT BIN$(INP(&FB7F),8):PRINT"N"
--510 RETURN
--520 OUT &FA7E,0
--530 RETURN
--540 GOSUB 420:gosub 170
--550 END
--CAT
--RUN
--GOSUB 150 // STATUS
--10000000
--CAT
--RUN
--GOSUB 420 // READ_ID
--HD US1 US0)
--01001001
--ST0
--00000000
--ST1
--00000000
--ST2
--00000000
--C
--00000000
--H
--C6 or C1
--R
--00000010
--N
--READ_ID does run fine in Basic.
--
--CAT
--RUN
--GOSUB 70 // SEEK
--HD US1 US0)
--TRACK
--GOSUB 150
--10000001 // drive0 is seeking
--GOSUB 110
--00100000 // SEEK END
--ST0
--00000010
--PCN CURRENT TRACK
--CAT
--RUN
--GOSUB 40 // RECALIBRATE
--HD US1 US0)
--TRACK
--GOSUB 150
--10000001 // drive0 is seeking
--GOSUB 110
--00100000 // SEEK END
--ST0
--00000000
--PCN CURRENT TRACK
--It seems that looking at STATUS is needed between SEEK and SENSE_INTERRUPT_STATUS. It's said that SENSE_INTERRUPT_STATUS is needed after SEEK.
--
--SEEK too high does return a normal result at SENSE_INTERRUPT_STATUS, RECALIBRATE without disk does return a normal result also at SENSE_INTERRUPT_STATUS. But does result in a fail at READ_ID command,
--
--WinAPE READ_ID with too high SEEK :
--
--10000000 //ST0 INVALID
--00100101 //ST1 DATA_ERROR & NO_DATA & MISSING_ADDR
--00000001 //ST2
--10001011 //C (too high SEEK)
--00000000 //H
--C8 //R
--00000010 //N
--WinAPE READ_ID without disk inserted :
--
--01001000 //ST0 ABNORMAL & NOT_READY
--00000000 //ST1
--00000000 //ST2
--00000010 //C
--00000000 //H
--C8 //R
--00000010 //N
--JEMU READ_ID with too high SEEK :
--
--01000000 //ST0 ABNORMAL
--00000101 //ST1 NO_DATA & MISSING_ADDR
--00000101 //ST2 SCAN_NOT_SATISFIED & MISSING_ADDR
--00000101 //C
--00000101 //H
--05 //R
--00000101 //N
--WinAPE :
--
--CAT
--RUN
--GOTO 540
--// READ_ID
--HD US1 US0)
--01001001
--ST0
--00000000
--ST1
--00000000
--ST2
--00000000
--C
--00000000
--H
--C6 or C1
--R
--00000010
--N
--// READ_DATA
--(MT MF SK
--HD US1 US0)
--C
--H
--R
--N
--EOT
--GPL
--DTL
--11010000 // no EXEC sequence...
--01001000 // ... due to NOT READY
--ST0
--00000000
--ST1
--00000000
--ST2
--00000000
--C
--00000000
--H
--C1
--R
--00000010
--N
--...too slow to execute a READ_DATA in Basic.
--
--JEMU :
--
--CAT
--RUN
--GOTO 540
--// READ_ID
--HD US1 US0)
--01001001
--ST0
--00000000
--ST1
--00000000
--ST2
--00000000
--C
--00000000
--H
--C6 or C1
--R
--00000010
--N
--// READ_DATA
--(MT MF SK
--HD US1 US0)
--C
--H
--R
--N
--EOT
--GPL
--DTL
--00010000
--BAD STATUS
--11010000 // no EXEC sequence...
--01000000 // ... due to
--ST0
--00000101 // NO_DATA & ADDR_MISSING
--ST1
--00000101 // SCAN_NOT_SATISFIED & ADDR_MISSING
--ST2
--00000101
--C
--00000101
--H
--05
--R
--00000101
--N
--...too slow to execute a READ_DATA in Basic.
--
--ST3SENSE.BAS :
--
--10 OUT &FB7F,&X00000100
--20 OUT &FB7F,&X00000001:PRINT"HD US1 US0)"
--30 PRINT BIN$(INP(&FB7F),8):PRINT"ST3"
--HD US1 US0)
--01110001 or 01010001 for drive B, 00000000 on drive A (with US0=0)
--ST3
--perl FDC frame decoder[edit]
--TODO : put theses basic scripts directly in comments in source file, not in wiki.... too verbose :/
--
--Adding a sniffer into UPD765A.java :
--
--writePort(int port, int value){System.out.println("writePort "+Util.hex((byte)port)+" "+Util.hex((byte)value));
--readPort(int port) {
--  System.out.println("writePort "+Util.hex((byte)port)+" "+Util.hex((byte)status));
-- return status; // just before this
--  System.out.println("writePort "+Util.hex((byte)port)+" "+Util.hex((byte)data));
-- return data; // just before that
--fdcMessages.pl
--
--# perl fdcMessages.pl < test.dsk.sniffer.txt > test.snif.txt
--# perl fdcMessages.pl < orion.dsk.sniffer.txt > orion.snif.txt
--use Switch;
--my $param_count=0;my $data_read_count=0;my $data_write_count=0;my $result_count=0;
--while(my $var = <>){
--	# print $var."\n";
--	if ($var =~ /^writePort ([0-9A-F][0-9A-F]) ([0-9A-F][0-9A-F])$/) {
--		my $addr=$1;my $value=hex($2);
--		$value_hex=sprintf ("%02X", $value );$value_bin=sprintf ("%08b", $value );
--		if ($param_count>0) {
--			$param_count--;
--			if ($param_count eq 4 or $param_count eq 2) {
--				print "W$param_count $value_bin $value_hex\n";
--			} else {
--				print "W$param_count $value_bin\n";
--			}
--		} elsif ($data_write_count>0) {
--			$data_write_count--;
--			#print "W  $value_hex $data_write_count\n";
--			if ($data_write_count eq 511) {
--				print "W $value_hex ";
--			} elsif ($data_write_count>0) {
--				print "$value_hex ";
--			} else {
--				print "$value_hex\n";
--			}
--		} else {
--			$result_count=0;$data_read_count=0;
--			print "COMMAND ";
--			switch($value_bin) {
--				case /00110$/ {
--					print "READ_DATA $value_bin\n";
--					$param_count=8;$data_read_count=512;$result_count=7;}
--				case /01100$/ {
--					print "READ_DELETED_DATA $value_bin\n";
--					$param_count=8;$data_read_count=512;$result_count=7;}
--				case /00101$/ {
--					print "WRITE_DATA $value_bin\n";
--					$param_count=8;$data_write_count=512;$result_count=7;}
-- 				case /01001$/ {
--					print "WRITE_DELETED_DATA $value_bin\n";
--					$param_count=8;$data_write_count=512;$result_count=7;}
--				case /00010$/ {
--					print "READ_DIAGNOSTIC $value_bin\n";
--					$param_count=8;$data_read_count=512;$result_count=7;}
--				case /01010$/ {
--					print "READ_ID $value_bin\n";
--					$param_count=1;$result_count=7;}
--				case /01101$/ {
--					print "WRITE_ID $value_bin (Format Write)\n";
--					$param_count=5;$result_count=7;}
--				case /10001$/ {
--					print "SCAN_EQUAL $value_bin\n";
--					$param_count=8;$data_read_count=512;$result_count=7;}
--				case /11001$/ {
--					print "SCAN_LOW_OR_EQUAL $value_bin\n";
--					$param_count=8;$data_read_count=512;$result_count=7;}
--				case /11101$/ {
--					print "SCAN_HIGH_OR_EQUAL $value_bin\n";
--					$param_count=8;$data_read_count=512;$result_count=7;}
--				case /00111$/ {
--					print "RECALIBRATE $value_bin\n";$param_count=1;}
--				case /01000$/ {
--					print "SENSE_INTERRUPT_STATUS $value_bin\n";
--					$result_count=2;}
--				case /00011$/ {
--					print "SPECIFY $value_bin\n";
--					$param_count=2;}
--				case /00100$/ {
--					print "SENSE_DRIVE_STATUS $value_bin\n";
--					$param_count=1;$result_count=1;}
--				case /10000$/ {
--					print "VERSION $value_bin\n";
--					$result_count=1;}
--				case /01111$/ {
--					print "SEEK $value_bin\n";
--					$param_count=2;}
--				else {
--					print "INVALID: $value_bin\n";
--					$result_count=1;}
--			}
--		}
--	} elsif ($var =~ /^readPort ([0-9A-F][0-9A-F]) ([0-9A-F][0-9A-F])$/) {
--		my $addr=$1;my $value=hex($2);
--		$value_hex=sprintf ("%02X", $value );$value_bin=sprintf ("%08b", $value );
--		if ($addr eq "7E") {
--			# print "READ_STATUS : $value_bin\n";
--		} else {
--			$param_count=0;
--			if ($data_read_count>0) {
--				$data_read_count--;
--				# print "R  $value_hex $data_read_count\n";
--				if ($data_write_count eq 511) {print "R $value_hex ";
--				} elsif ($data_read_count>0) {print "$value_hex ";
--				} else {print "$value_hex\n";}
--			} elsif ($result_count>0) {
--				$result_count--;
--				if ($result_count eq 1) {
--					print "R$result_count $value_bin $value_hex\n";
--				} else {
--					print "R$result_count $value_bin\n";
--				}
--			} else {
--				print "R  $value_hex (garbage)\n";
--			}
--		}
--	}
--}
--Result in JavaCPC :
--
--COMMAND READ_DATA 01100110
--W7 00000000
--W6 00000000
--W5 00000000
--W4 11000011 C3
--W3 00000010
--W2 11000011 C3
--W1 00101010
--W0 11111111
--E5 E5....
--R6 00000000
--R5 00000000
--R4 00000000
--R3 00000000
--R2 00000000
--R1 00000001 01 <= not implemented yet like that in FPGAmstrad (one bug found !)
--R0 00000010

--FDCTEST.DSK
--13 13 13 13 13 13 13 13 05 00 13 13 00 00 00 00 00 00 00 00 13 00 13 00 04 00 11 00 00 00 06 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 13 13
--00 00 01 01 02 02 03 03 04 04 05 05 06 06 07 07 08 08 09 09 0A 0A 0B 0B 0C 0C 0D 0D 0E 0E 0F 0F 10 10 11 11 12 12 13 13 14 14 15 15 16 16 17 17 18 18 19 19
--
--Track-Info &100
--00 00 (&1300)
--Track-Info &1400
--00 01 (&1300)
--Track-Info &2700
--01 00 (&1300)
--Track-Info &3A00
--01 01 (&1300)
--Track-Info &4D00
--02 00 (&1300)
--Track-Info &6000
--02 01 (&1300)
--Track-Info &7300
--03 00 (&1300)
--Track-Info &8600
--03 01 (&1300)
--Track-Info &9900
--04 00 (&500)
--Track-Info &9E00
--05 00 (&1300)
--Track-Info &B100
--05 01 (&1300)
--Track-Info &C400
--0A 00 (&1300)
--Track-Info &D700
--0B 00 (&1300)
--Track-Info &EA00
--0C 00 (&400)
--Track-Info &EE00
--0D 00 (&1100)
--Track-Info &FF00
--0F 00 (&600)
--Track-Info &10500
--19 00  (&1300)
--Track-Info &11800
--19 01
