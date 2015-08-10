library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity aZRaEL_vram2vgaAmstradMiaow is
    Generic(
	 VOFFSET_NEGATIF:integer:=(600/2-480/2)/2;
	 VOFFSET_PALETTE:integer:=((600-480)/2)/2;
	 HardHZoom : integer:=1; -- divise l'horloge n�cessaire par HardHZoom et HZoom HardHZoom fois
	 -- Amstrad
	 -- 
	 --OFFSET:STD_LOGIC_VECTOR(15 downto 0):=x"C000";
	 -- ecran.bas
	 -- CLS
	 -- FOR A=&C000 TO &FFFF
	 -- POKE A,&FF
	 -- NEXT A
	 -- 
	 -- ligne.bas
	 -- CLS
	 -- FOR A=&C000 TO &C050
	 -- POKE A,&FF
	 -- NEXT A
	 -- 
	 -- lignes.bas
	 -- CLS
	 -- FOR A=&C000 TO &C7FF
	 -- POKE A,&FF
	 -- NEXT A
	 -- 
	 -- Organisation d'un octet :
	 -- mode 1 :
	 --   1 octet <=> 4 pixels
	 --   [AAAA][BBBB] : superposition des couleurs de [AAAA] et [BBBB]
	 --   A+B=0+0=bleu fonc� (couleur du fond par d�faut)
	 --   A+B=0+1=bleu clair
	 --   A+B=1+0=jaune
	 --   A+B=1+1=rouge
	 --  par exemple [1100][0011] donnera 2 pixels jaune suivi de 2 pixels bleu clair &C3
	 -- mode 0 : 
	 --   1 octet <=> 2 pixels
	 --   [AA][BB][CC][DD] : superposition des couleurs de AA, BB, CC, DD
	 --   comme il y a "trop" de combinaisons pour une sortie RGB sans variation de lumi�re
	 --   ils ont fait clignoter les derni�re combinaisons. La variation de lumi�re a �t�
	 --   ajout� par la suite, avec PEN/PAPER...
	 -- mode 2 :
	 --   1 octet <=> 8 pixels
	 --   [AAAAAAAA] : on a donc que 2 couleurs xD
	 MODE_MAX:integer:=2;
--	 NB_PIXEL_PER_OCTET:integer:=4;--2**(MODE+1);
	NB_PIXEL_PER_OCTET_MAX:integer:=8;
	NB_PIXEL_PER_OCTET_MIN:integer:=2;
	 -- Lorsqu'on lance lignes.bas on peut ensuite d�placer le curseur pour compter
	 -- mode 1 :
	 --   On a 40 caract�res par lignes en mode 1, un caract�re fait 8 pixels de large
	 CHAR_WIDTH:integer:=16; -- c'est stupide en fait c'est l'octet, car le crtc pond des adresses et non une sortie RGB normalement xD
	 -- On a 320x200pixels=64000pixels=16000 octets utilis�s
	 --  or on scanne &FFFF+1-&C000=16384 octets... donc il y a des trous x)
	 -- 
	 -- trou.bas
	 -- MODE 1
	 -- CLS
	 -- FOR A=0 TO 639
	 -- FOR B=0 to 399
	 -- PLOT a,b
	 -- NEXT b
	 -- NEXT a
	 -- 
	 -- On observe le snapshoot on a des &F0 aux adresses :
	 -- C000 � C7D0-1
	 -- C800 � CFD0-1
	 -- D000 � D7D0-1
	 -- D800 � DFD0-1
	 -- E000 � E7D0-1
	 -- E800 � EFD0-1
	 -- F000 � F7D0-1
	 -- F800 � FFD0-1
	 --
	 -- plus rapide :D
	 --
	 -- trou2.bas
	 -- paper 2
	 -- cls
	 -- 
	 -- si on va en bas de l'�cran afin de remonter l'image d'un cran et qu'on refait un snapshoot
	 -- on remarque que c'est le bazard niveau m�moire : les trou ne sont plus au m�me endroit !
	 -- c'est pourquoi j'ai mis "MODE 1" dans trou.bas x)
	 -- si on remonte l'image en allant en bas de l'�cran avec le curseur
	 --  un "poke &C000,&ff" ne vise plus en haut � gauche... parfois il ne marche m�me plus : il est dans le trou !
	 -- 
--   --modeline label pxcl HDsp HSS HSE HTot VDsp VSS VSE VTot flags
--   --modeline "640x480@60" 25.2 640 656 752 800 480 490 492 525 -vsync -hsync
              label_modeline  :string:="640x480@60";--(ignored  by  svgalib) mainly there to be compatible with XF86Config.   I  use  the  format  "Width  x   Height   @   Vert.Refresh", but that's just personal taste...
              pxcl:string:="25.2"; -- the pixel clock in MHz
              HDsp:integer:=640; -- size of the visible area (horizontal/vertical)
              HSS:integer:=656; -- Sync start (horizontal/vertical)
              HSE:integer:=752; -- Sync end (horizontal/vertical)
              HTot:integer:=800; -- Total width/height (end of back porch)
              VDsp:integer:=480; -- size of the visible area (horizontal/vertical)
              VSS:integer:=490; -- Sync start (horizontal/vertical)
              VSE:integer:=492; -- Sync end (horizontal/vertical)
              VTot:integer:=525; -- Total width/height (end of back porch)
				  nvsync:std_logic:='1';--flags  +vsync -vsync
				  nhsync:std_logic:='1'; --flags  +hsync -hsync
              --flags  interlace interlaced
              --       doublescan Sync polarity, interlace mode
				  SQRT_VRAM_SIZE:integer:=16;

				  HZoom:integer:=1;
				  VZoom:integer:=2;
				  
				  VRAM_HDsp:integer:=800; --suivant les mode, le nombre de pixels affich�s est constant !
				  VRAM_VDsp:integer:=300 --600/2
		  );
    Port ( DATA : in  STD_LOGIC_VECTOR (7 downto 0); -- buffer
           ADDRESS : out  STD_LOGIC_VECTOR (14 downto 0):=(others=>'0');
			  PALETTE_D : in STD_LOGIC_VECTOR (7 downto 0);
			  PALETTE_A : out STD_LOGIC_VECTOR (13 downto 0):=(others=>'0');
           RED : out  STD_LOGIC_VECTOR(1 downto 0);
           GREEN : out  STD_LOGIC_VECTOR(1 downto 0);
           BLUE : out  STD_LOGIC_VECTOR(1 downto 0);
           VSYNC : out  STD_LOGIC;
           HSYNC : out  STD_LOGIC;
           CLK_25MHz : in  STD_LOGIC
			  );
end aZRaEL_vram2vgaAmstradMiaow;

architecture Behavioral of aZRaEL_vram2vgaAmstradMiaow is
	constant DO_NOTHING_OUT : integer range 0 to 2:=0;
	constant DO_READ : integer range 0 to 2:=1;
	constant DO_BORDER: integer range 0 to 2:=2;
	
	constant DO_NOTHING : STD_LOGIC:='0';
	constant DO_HSYNC : STD_LOGIC:='1';
	constant DO_VSYNC : STD_LOGIC:='1';

	constant VDecal_negatif:integer:=VOFFSET_NEGATIF; --(600/2-480/2)/2;
	constant HDecal_negatif:integer:=(800-640)/2;
	constant HDecal:integer:=0;
	constant VDecal:integer:=0;
	
	type palette_type is array(31 downto 0) of std_logic_vector(5 downto 0); -- RRVVBB
	constant palette:palette_type:=(
		20=>"000000",
		 4=>"000001",
		21=>"000011",
		28=>"010000",
		24=>"010001",
			29=>"010011",
		12=>"110000",
			5=>"110001",
		13=>"110011",
		22=>"000100",
		6=>"000101",
		23=>"000111",
		30=>"010100",
		 0=>"010101",
		31=>"010111",
		14=>"110100",
		 7=>"110101",
		15=>"110111",
		18=>"001100",
		 2=>"001101",
		19=>"001111",
		26=>"011100",
		25=>"011101",
		27=>"011111",
		10=>"111100",
		 3=>"111101",
		11=>"111111",
		
		-- others color >=27
		1=>"010101",
		8=>"110001",
		9=>"111101",
		16=>"000001",
		17=>"001101"
		);
	
	signal MODE_select:STD_LOGIC_VECTOR (1 downto 0):="01"; -- mode 1
begin

aZRaEL_vram2vgaAmstrad_process : process(CLK_25MHz) is

	constant PALETTE_H_OFFSET:integer:=32-1;--16+1  +1;
	constant PALETTE_V_OFFSET:integer:=VOFFSET_PALETTE; --((600-480)/2)/2;
	constant HMax:integer:=(HTot/HardHZoom)-1;
	constant VMax:integer:=VTot-1;
	
	variable horizontal_counter : integer range 0 to 1024-1 :=0;
	variable vertical_counter : integer range 0 to 1024-1 :=0;
	
	variable palette_horizontal_counter : integer range 0 to 1024-1:=PALETTE_H_OFFSET;
	variable palette_vertical_counter : integer range 0 to 1024-1:=PALETTE_V_OFFSET;
	constant DO_NADA:integer range 0 to 4:=0;
	constant DO_MODE:integer range 0 to 4:=1;
	constant DO_COLOR:integer range 0 to 4:=2;
	constant DO_HBEGIN:integer range 0 to 4:=3;
	constant DO_HEND:integer range 0 to 4:=4;
	variable palette_action:integer range 0 to 4:=DO_NADA;
	variable palette_action_retard:integer range 0 to 4:=DO_NADA;
	variable palette_color:integer range 0 to 16-1:=0;
	variable palette_color_retard:integer range 0 to 16-1:=0;
	variable palette_A_mem:std_logic_vector(palette_A'range):=(others=>'0');
	variable palette_D_mem:std_logic_vector(7 downto 0);
	
	variable etat_rgb : integer range 0 to 2:=DO_NOTHING_OUT;
	variable etat_rgb_retard : integer range 0 to 2:=DO_NOTHING_OUT;
	variable etat_hsync : STD_LOGIC:=DO_NOTHING;
	variable etat_hsync_retard : STD_LOGIC:=DO_NOTHING;
	variable etat_vsync : STD_LOGIC:=DO_NOTHING;
	variable etat_vsync_retard : STD_LOGIC:=DO_NOTHING;
	variable color : STD_LOGIC_VECTOR(2**(MODE_MAX)-1 downto 0);
	variable color_patch : STD_LOGIC_VECTOR(2**(MODE_MAX)-1 downto 0);
	variable cursor_pixel_ref : integer range 0 to NB_PIXEL_PER_OCTET_MAX-1;
	variable cursor_pixel : integer range 0 to NB_PIXEL_PER_OCTET_MAX-1;
	variable cursor_pixel_retard : integer range 0 to NB_PIXEL_PER_OCTET_MAX-1;
	variable v:integer range 0 to 256-1;
	variable h:integer range 0 to CHAR_WIDTH*128*8-1;
	variable new_h:integer range 0 to 128*8-1;
	variable NB_PIXEL_PER_OCTET:integer range NB_PIXEL_PER_OCTET_MIN to NB_PIXEL_PER_OCTET_MAX;
	--variable ADRESSE_CONSTANT_mem:integer range 0 to 16*1024-1;
	--variable ADRESSE_INC_mem:integer range 0 to 16*1024-1;
	--variable ADRESSE_VAR_mem:integer range 0 to 16*1024-1;
	variable MA:STD_LOGIC_VECTOR(13 downto 0);
	--variable MA_13_begin:std_logic:='0';
	variable RA:STD_LOGIC_VECTOR(4 downto 0);
	variable CA:STD_LOGIC_VECTOR(0 downto 0); -- sqrt(CHAR_WIDTH/8)-1 ?
	variable no_char:integer range 0 to CHAR_WIDTH/8-1;
	
	
	type pen_type is array(15 downto 0) of std_logic_vector(5 downto 0);
	variable pen:pen_type:=(
		palette(4),palette(12),palette(21),palette(28),
		palette(24),palette(29),palette(12),palette(5),
		palette(13),palette(22),palette(6),palette(23),
		palette(30),palette(0),palette(31),palette(14)
	);
	variable border:std_logic_vector(5 downto 0);

	variable ADDRESS_mem : STD_LOGIC_VECTOR (14 downto 0):=(others=>'0');
	variable has_LEFT_BORDER : boolean:=false;
	variable has_RIGHT_BORDER : boolean:=false;
	variable horizontal_counter_LEFT_BORDER : integer range 0 to 1024-1 :=0;
	variable horizontal_counter_RIGHT_BORDER : integer range 0 to 1024-1 :=0;
	variable is_full_vertical_BORDER:boolean:=true;
begin
	if rising_edge(CLK_25MHz) then
	
	
	

		
	
	
	
	
	
	
	
		if MODE_select="00" then
			NB_PIXEL_PER_OCTET:=2;
		elsif MODE_select="01" then
			NB_PIXEL_PER_OCTET:=4;
		elsif MODE_select="10" then
			NB_PIXEL_PER_OCTET:=8;
		else
			NB_PIXEL_PER_OCTET:=2;
		end if;
		
		-- plus stable
		cursor_pixel_retard:=cursor_pixel;
		if etat_rgb_retard = DO_READ then
			color:=(others=>'0');
			for i in 2**(MODE_MAX)-1 downto 0 loop
				if (MODE_select="00" and i<=3)
				or (MODE_select="01" and i<=1)
				or (MODE_select="10" and i<=0) then
					color(3-i):=DATA(i*NB_PIXEL_PER_OCTET+(NB_PIXEL_PER_OCTET-1-cursor_pixel_retard));
				end if;
			end loop;
			if MODE_select="10" then
				RED<=pen(conv_integer(color(3)))(5 downto 4);
				GREEN<=pen(conv_integer(color(3)))(3 downto 2);
				BLUE<=pen(conv_integer(color(3)))(1 downto 0);
			elsif MODE_select="01" then
				RED<=pen(conv_integer(color(3 downto 2)))(5 downto 4);
				GREEN<=pen(conv_integer(color(3 downto 2)))(3 downto 2);
				BLUE<=pen(conv_integer(color(3 downto 2)))(1 downto 0);
			elsif MODE_select="00" then
				color_patch:=color(3) & color(1) & color(2) & color(0); -- pas relou xD
				RED<=pen(conv_integer(color_patch))(5 downto 4);
				GREEN<=pen(conv_integer(color_patch))(3 downto 2);
				BLUE<=pen(conv_integer(color_patch))(1 downto 0);
			else -- MODE 11
				RED<="01";
				GREEN<="11";
				BLUE<="01";
			end if;
		elsif etat_rgb_retard = DO_BORDER then
			RED<=border(5 downto 4);
			GREEN<=border(3 downto 2);
			BLUE<=border(1 downto 0);
		else
			RED<="00";
			GREEN<="00";
			BLUE<="00";
		end if;
		etat_rgb_retard:=etat_rgb;
		-- strange cursor_pixel_retard:=cursor_pixel;

		
		if etat_hsync_retard = DO_HSYNC then
			hsync<='1' xor nhsync;
		else
			hsync<='0' xor nhsync;
		end if;
		etat_hsync_retard:=etat_hsync;
		
		if etat_vsync_retard = DO_VSYNC then
			vsync<='1' xor nvsync;
			--palette_A_mem:=(others=>'0');
		else
			vsync<='0' xor nvsync;
		end if;
		etat_vsync_retard:=etat_vsync;
		
		

--puis la palette c'est celle du 800x600... pas du 640x400
-- puis c'est trop petit cet RAM, � peine de quoi afficher 60 lignes en 33o par palette et 100 lignes en 32*5bit+2bit
--donc il faudrai au minimum tripler la m�moire si on la joue serr�, ou au maximum multiplier par 5
--Number of RAMB16s: 18 out of      20   90% => on peut triper la m�moire mais pas plus
		if palette_action_retard=DO_MODE then
--nopb palette
			palette_D_mem:=palette_D;
			MODE_select<=palette_D_mem(1 downto 0);
			border:=palette(conv_integer(palette_D_mem(7 downto 3)));
			if palette_D_mem(2)='1' then
				is_full_vertical_BORDER:=true;
			else
				is_full_vertical_BORDER:=false;
			end if;
		elsif palette_action_retard=DO_COLOR then
--nopb palette
			palette_D_mem:=palette_D;
			pen(palette_color_retard):=palette(conv_integer(palette_D_mem(4 downto 0)));

		--RHdisp fait 40 hors 16*40=640 pixels donc on a 16* en ratio.
		--HDecal_negatif/16=5 donc on peut tenter d'emp�cher un d�passement.
		elsif palette_action_retard=DO_HBEGIN then
			palette_D_mem:=palette_D;
			horizontal_counter_LEFT_BORDER:=conv_integer(palette_D_mem(7 downto 0));
			if horizontal_counter_LEFT_BORDER>((HDecal_negatif-HDecal)/16) then
				--horizontal_counter_LEFT_BORDER:=160;
				--horizontal_counter_LEFT_BORDER:=15;--conv_integer(palette_D_mem(7 downto 0));
				horizontal_counter_LEFT_BORDER:=horizontal_counter_LEFT_BORDER*16;
				horizontal_counter_LEFT_BORDER:=horizontal_counter_LEFT_BORDER-HDecal_negatif+HDecal;
				--horizontal_counter_LEFT_BORDER:=16*(conv_integer(palette_D_mem(7 downto 0))-((HDecal_negatif-HDecal)/16));
				has_LEFT_BORDER:=true;
			else
				horizontal_counter_LEFT_BORDER:=0;
				has_LEFT_BORDER:=false;
			end if;
		elsif palette_action_retard=DO_HEND then
			palette_D_mem:=palette_D;
			horizontal_counter_RIGHT_BORDER:=conv_integer(palette_D_mem(7 downto 0));
			if horizontal_counter_RIGHT_BORDER<(HDsp/HardHZoom)/16 + ((HDecal_negatif-HDecal)/16) then
				--horizontal_counter_RIGHT_BORDER:=480-1;
				--horizontal_counter_RIGHT_BORDER:=35;--conv_integer(palette_D_mem(7 downto 0));
				horizontal_counter_RIGHT_BORDER:=horizontal_counter_RIGHT_BORDER*16;
				horizontal_counter_RIGHT_BORDER:=horizontal_counter_RIGHT_BORDER-HDecal_negatif+HDecal;
				horizontal_counter_RIGHT_BORDER:=horizontal_counter_RIGHT_BORDER-1;
				--horizontal_counter_RIGHT_BORDER:=(16*(conv_integer(palette_D_mem(7 downto 0))-((HDecal_negatif-HDecal)/16)))-1;
				has_RIGHT_BORDER:=true;
			else
				horizontal_counter_RIGHT_BORDER:=HDsp/HardHZoom;
				has_RIGHT_BORDER:=false; -- HEURISTIC :p
			end if;
		end if;
		palette_action_retard:=palette_action;
		palette_color_retard:=palette_color;
		
		
		
		
		
		if palette_vertical_counter mod VZoom=0 and palette_vertical_counter<VDsp then  -- une ligne sur deux d�j�... + ne d�passe pas VRAM verticalement
			if palette_horizontal_counter<1 then
				-- mode
				palette_A<=palette_A_mem;
				palette_action:=DO_HBEGIN;
			elsif palette_horizontal_counter<2 then
				-- mode
				palette_A<=palette_A_mem;
				palette_action:=DO_MODE;
			elsif palette_horizontal_counter<2+16 then
				-- color
				palette_A<=palette_A_mem;
				palette_action:=DO_COLOR;
				if palette_horizontal_counter = 2 then
					palette_color:=0;
				else
					palette_color:=palette_color+1;
				end if;
			elsif palette_horizontal_counter<2+16+1 then
				-- mode
				palette_A<=palette_A_mem;
				palette_action:=DO_HEND;
			else
				palette_action:=DO_NADA;
			end if;
		else
			palette_action:=DO_NADA;
		end if;
		
		
		
		if horizontal_counter<HDsp/HardHZoom and vertical_counter<VDsp then
			if horizontal_counter+HDecal_negatif<HDecal or vertical_counter+VDecal_negatif<VDecal or horizontal_counter+HDecal_negatif>=HDecal+HZoom*VRAM_HDsp or vertical_counter+VDecal_negatif>=VDecal+VZoom*VRAM_VDsp then
				ADDRESS<= (others=>'0');
				-- OUT OF VRAM800x600
				etat_rgb:=DO_BORDER;
			elsif is_full_vertical_BORDER then
				-- vertical full BORDER (UPPER AND LOWER ONES)
				ADDRESS<= (others=>'0');
				etat_rgb:=DO_BORDER;
			elsif has_LEFT_BORDER and horizontal_counter<horizontal_counter_LEFT_BORDER then
				-- LEFT BORDER
				ADDRESS<= (others=>'0');
				etat_rgb:=DO_BORDER;
			elsif has_RIGHT_BORDER and horizontal_counter>horizontal_counter_RIGHT_BORDER then
				-- RIGHT BORDER
				ADDRESS<= (others=>'0');
				etat_rgb:=DO_BORDER;
			else
				v:=(vertical_counter+VDecal_negatif-VDecal)/(VZoom);
				h:=(horizontal_counter+HDecal_negatif-HDecal)/(HZoom);
				no_char:=(h / 8) mod (CHAR_WIDTH/8);
				-- 640�200 pixels with 2 colours ("Mode 2", 80 text columns) donc bien 8 pixels physique par octets
				if NB_PIXEL_PER_OCTET=2 then
					cursor_pixel_ref:=(((h-1+8) mod 8) / 4) mod 8;
					cursor_pixel:=cursor_pixel_ref;
				elsif NB_PIXEL_PER_OCTET=4 then
					cursor_pixel_ref:=(((h-1+8) mod 8) / 2) mod 8; -- ok
					cursor_pixel:=cursor_pixel_ref; -- correction trajectoire... retard arriv� data par rapport adressage : un temps
				elsif NB_PIXEL_PER_OCTET=8 then
					cursor_pixel_ref:=(((h-1+8) mod 8) / 1) mod 8;
					cursor_pixel:=cursor_pixel_ref; -- cacher un pixel sur deux
				end if;
				new_h:=h/CHAR_WIDTH; -- v�ritablement un octet repr�sente physique 8 pixels, 
				etat_rgb:=DO_READ;

				MA:=conv_std_logic_vector(v*(VRAM_HDsp/CHAR_WIDTH),14);
				MA:=new_h+MA;
				CA:=conv_std_logic_vector(no_char,1);
				ADDRESS_mem:=MA(13 downto 0) & CA(0);
				ADDRESS<=ADDRESS_mem;
			end if;
		else
			ADDRESS<= (others=>'0');
			etat_rgb:=DO_NOTHING_OUT;
		end if;
		if horizontal_counter>=HSS/HardHZoom and horizontal_counter<HSE/HardHZoom then
			etat_hsync:=DO_HSYNC;
		else
			etat_hsync:=DO_NOTHING;
		end if;
		if vertical_counter>=VSS and vertical_counter<VSE then
			etat_vsync:=DO_VSYNC;
		else
			etat_vsync:=DO_NOTHING;
		end if;

		
		
		
		
		
		
		
		
		if horizontal_counter>=HMax then
			horizontal_counter:=0;
		else
			horizontal_counter:=horizontal_counter+1;
		end if;
		if horizontal_counter=0 then
			if vertical_counter>=VMax then
				vertical_counter:=0;
			else
				vertical_counter:=vertical_counter+1;
			end if;
		end if;
		
		if palette_horizontal_counter>=HMax then
			palette_horizontal_counter:=0;
		else
			palette_horizontal_counter:=palette_horizontal_counter+1;
		end if;
		if palette_horizontal_counter=0 then
			if palette_vertical_counter>=VMax then
				palette_vertical_counter:=0;
				palette_A_mem:=(others=>'0');
			else
				palette_vertical_counter:=palette_vertical_counter+1;
				if palette_vertical_counter mod VZoom=0 then -- une ligne sur deux d�j�...
					palette_A_mem:=palette_A_mem+1;
				end if;
			end if;
		elsif palette_horizontal_counter<2+16+1 then
				if palette_vertical_counter mod VZoom=0 then -- une ligne sur deux d�j�...
					palette_A_mem:=palette_A_mem+1;
				end if;
		end if;
		
	end if;
end process aZRaEL_vram2vgaAmstrad_process;

end Behavioral;
