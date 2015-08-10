<?xml version="1.0" encoding="UTF-8"?>
<drawing version="7">
    <attr value="artix7" name="DeviceFamilyName">
        <trait delete="all:0" />
        <trait editname="all:0" />
        <trait edittrait="all:0" />
    </attr>
    <netlist>
        <signal name="vram_W" />
        <signal name="vram_D(7:0)" />
        <signal name="vram_A(14:0)" />
        <signal name="vram_CLK" />
        <signal name="CLK25MHz" />
        <signal name="HSYNC" />
        <signal name="VSYNC" />
        <signal name="XLXN_693(14:0)" />
        <signal name="XLXN_694(13:0)" />
        <signal name="RED2(1:0)" />
        <signal name="GREEN3(2:0)" />
        <signal name="BLUE2(1:0)" />
        <signal name="palette_W" />
        <signal name="palette_D(7:0)" />
        <signal name="palette_A(13:0)" />
        <signal name="palette_CLK" />
        <signal name="nCLK25MHz" />
        <signal name="XLXN_713(7:0)" />
        <signal name="XLXN_715(7:0)" />
        <signal name="XLXN_717" />
        <signal name="XLXN_718" />
        <signal name="XLXN_719" />
        <signal name="XLXN_721" />
        <signal name="XLXN_724(7:0)" />
        <signal name="XLXN_738(7:0)" />
        <signal name="XLXN_743(7:0)" />
        <signal name="XLXN_744(7:0)" />
        <port polarity="Input" name="vram_W" />
        <port polarity="Input" name="vram_D(7:0)" />
        <port polarity="Input" name="vram_A(14:0)" />
        <port polarity="Input" name="vram_CLK" />
        <port polarity="Input" name="CLK25MHz" />
        <port polarity="Output" name="HSYNC" />
        <port polarity="Output" name="VSYNC" />
        <port polarity="Output" name="RED2(1:0)" />
        <port polarity="Output" name="GREEN3(2:0)" />
        <port polarity="Output" name="BLUE2(1:0)" />
        <port polarity="Input" name="palette_W" />
        <port polarity="Input" name="palette_D(7:0)" />
        <port polarity="Input" name="palette_A(13:0)" />
        <port polarity="Input" name="palette_CLK" />
        <port polarity="Input" name="nCLK25MHz" />
        <blockdef name="VRAM32Ko_Amstrad">
            <timestamp>2014-10-11T17:41:26</timestamp>
            <rect width="256" x="64" y="-384" height="384" />
            <line x2="0" y1="-352" y2="-352" x1="64" />
            <line x2="0" y1="-288" y2="-288" x1="64" />
            <rect width="64" x="0" y="-236" height="24" />
            <line x2="0" y1="-224" y2="-224" x1="64" />
            <rect width="64" x="0" y="-172" height="24" />
            <line x2="0" y1="-160" y2="-160" x1="64" />
            <line x2="0" y1="-96" y2="-96" x1="64" />
            <rect width="64" x="0" y="-44" height="24" />
            <line x2="0" y1="-32" y2="-32" x1="64" />
            <rect width="64" x="320" y="-364" height="24" />
            <line x2="384" y1="-352" y2="-352" x1="320" />
        </blockdef>
        <blockdef name="aZRaEL_vram2vgaAmstradMiaow">
            <timestamp>2014-11-22T19:15:38</timestamp>
            <rect width="384" x="64" y="-448" height="448" />
            <line x2="0" y1="-416" y2="-416" x1="64" />
            <rect width="64" x="0" y="-236" height="24" />
            <line x2="0" y1="-224" y2="-224" x1="64" />
            <rect width="64" x="0" y="-44" height="24" />
            <line x2="0" y1="-32" y2="-32" x1="64" />
            <line x2="512" y1="-416" y2="-416" x1="448" />
            <line x2="512" y1="-352" y2="-352" x1="448" />
            <rect width="64" x="448" y="-300" height="24" />
            <line x2="512" y1="-288" y2="-288" x1="448" />
            <rect width="64" x="448" y="-236" height="24" />
            <line x2="512" y1="-224" y2="-224" x1="448" />
            <rect width="64" x="448" y="-172" height="24" />
            <line x2="512" y1="-160" y2="-160" x1="448" />
            <rect width="64" x="448" y="-108" height="24" />
            <line x2="512" y1="-96" y2="-96" x1="448" />
            <rect width="64" x="448" y="-44" height="24" />
            <line x2="512" y1="-32" y2="-32" x1="448" />
        </blockdef>
        <blockdef name="VRAM_Amstrad_NEXYS4_16Ko">
            <timestamp>2014-10-11T17:41:8</timestamp>
            <rect width="256" x="64" y="-384" height="384" />
            <line x2="0" y1="-352" y2="-352" x1="64" />
            <line x2="0" y1="-288" y2="-288" x1="64" />
            <rect width="64" x="0" y="-236" height="24" />
            <line x2="0" y1="-224" y2="-224" x1="64" />
            <rect width="64" x="0" y="-172" height="24" />
            <line x2="0" y1="-160" y2="-160" x1="64" />
            <line x2="0" y1="-96" y2="-96" x1="64" />
            <rect width="64" x="0" y="-44" height="24" />
            <line x2="0" y1="-32" y2="-32" x1="64" />
            <rect width="64" x="320" y="-364" height="24" />
            <line x2="384" y1="-352" y2="-352" x1="320" />
        </blockdef>
        <blockdef name="fd8ce">
            <timestamp>2000-1-1T10:10:10</timestamp>
            <line x2="64" y1="-128" y2="-128" x1="0" />
            <line x2="64" y1="-192" y2="-192" x1="0" />
            <line x2="64" y1="-32" y2="-32" x1="0" />
            <line x2="64" y1="-256" y2="-256" x1="0" />
            <line x2="320" y1="-256" y2="-256" x1="384" />
            <line x2="64" y1="-32" y2="-32" x1="192" />
            <line x2="192" y1="-64" y2="-32" x1="192" />
            <line x2="64" y1="-128" y2="-144" x1="80" />
            <line x2="80" y1="-112" y2="-128" x1="64" />
            <rect width="64" x="320" y="-268" height="24" />
            <rect width="64" x="0" y="-268" height="24" />
            <rect width="256" x="64" y="-320" height="256" />
        </blockdef>
        <blockdef name="gnd">
            <timestamp>2000-1-1T10:10:10</timestamp>
            <line x2="64" y1="-64" y2="-96" x1="64" />
            <line x2="52" y1="-48" y2="-48" x1="76" />
            <line x2="60" y1="-32" y2="-32" x1="68" />
            <line x2="40" y1="-64" y2="-64" x1="88" />
            <line x2="64" y1="-64" y2="-80" x1="64" />
            <line x2="64" y1="-128" y2="-96" x1="64" />
        </blockdef>
        <blockdef name="vcc">
            <timestamp>2000-1-1T10:10:10</timestamp>
            <line x2="64" y1="-32" y2="-64" x1="64" />
            <line x2="64" y1="0" y2="-32" x1="64" />
            <line x2="32" y1="-64" y2="-64" x1="96" />
        </blockdef>
        <block symbolname="VRAM32Ko_Amstrad" name="XLXI_474">
            <blockpin signalname="vram_CLK" name="vram_CLK" />
            <blockpin signalname="nCLK25MHz" name="vga_CLK" />
            <blockpin signalname="vram_A(14:0)" name="vram_A(14:0)" />
            <blockpin signalname="XLXN_693(14:0)" name="vga_A(14:0)" />
            <blockpin signalname="vram_W" name="vram_W" />
            <blockpin signalname="vram_D(7:0)" name="vram_D(7:0)" />
            <blockpin signalname="XLXN_713(7:0)" name="vga_D(7:0)" />
        </block>
        <block symbolname="aZRaEL_vram2vgaAmstradMiaow" name="XLXI_476">
            <blockpin signalname="CLK25MHz" name="CLK_25MHz" />
            <blockpin signalname="XLXN_743(7:0)" name="DATA(7:0)" />
            <blockpin signalname="XLXN_744(7:0)" name="PALETTE_D(7:0)" />
            <blockpin signalname="VSYNC" name="VSYNC" />
            <blockpin signalname="HSYNC" name="HSYNC" />
            <blockpin signalname="XLXN_693(14:0)" name="ADDRESS(14:0)" />
            <blockpin signalname="XLXN_694(13:0)" name="PALETTE_A(13:0)" />
            <blockpin signalname="RED2(1:0)" name="RED(1:0)" />
            <blockpin signalname="GREEN3(2:0)" name="GREEN(2:0)" />
            <blockpin signalname="BLUE2(1:0)" name="BLUE(1:0)" />
        </block>
        <block symbolname="VRAM_Amstrad_NEXYS4_16Ko" name="XLXI_478">
            <blockpin signalname="palette_CLK" name="vram_CLK" />
            <blockpin signalname="nCLK25MHz" name="vga_CLK" />
            <blockpin signalname="palette_A(13:0)" name="vram_A(13:0)" />
            <blockpin signalname="XLXN_694(13:0)" name="vga_A(13:0)" />
            <blockpin signalname="palette_W" name="vram_W" />
            <blockpin signalname="palette_D(7:0)" name="vram_D(7:0)" />
            <blockpin signalname="XLXN_715(7:0)" name="vga_D(7:0)" />
        </block>
        <block symbolname="fd8ce" name="XLXI_482">
            <blockpin signalname="CLK25MHz" name="C" />
            <blockpin signalname="XLXN_717" name="CE" />
            <blockpin signalname="XLXN_718" name="CLR" />
            <blockpin signalname="XLXN_713(7:0)" name="D(7:0)" />
            <blockpin signalname="XLXN_738(7:0)" name="Q(7:0)" />
        </block>
        <block symbolname="fd8ce" name="XLXI_483">
            <blockpin signalname="CLK25MHz" name="C" />
            <blockpin signalname="XLXN_719" name="CE" />
            <blockpin signalname="XLXN_721" name="CLR" />
            <blockpin signalname="XLXN_715(7:0)" name="D(7:0)" />
            <blockpin signalname="XLXN_724(7:0)" name="Q(7:0)" />
        </block>
        <block symbolname="gnd" name="XLXI_484">
            <blockpin signalname="XLXN_718" name="G" />
        </block>
        <block symbolname="gnd" name="XLXI_485">
            <blockpin signalname="XLXN_721" name="G" />
        </block>
        <block symbolname="vcc" name="XLXI_486">
            <blockpin signalname="XLXN_717" name="P" />
        </block>
        <block symbolname="vcc" name="XLXI_487">
            <blockpin signalname="XLXN_719" name="P" />
        </block>
        <block symbolname="fd8ce" name="XLXI_488">
            <blockpin signalname="nCLK25MHz" name="C" />
            <blockpin signalname="XLXN_719" name="CE" />
            <blockpin signalname="XLXN_721" name="CLR" />
            <blockpin signalname="XLXN_724(7:0)" name="D(7:0)" />
            <blockpin signalname="XLXN_744(7:0)" name="Q(7:0)" />
        </block>
        <block symbolname="fd8ce" name="XLXI_492">
            <blockpin signalname="nCLK25MHz" name="C" />
            <blockpin signalname="XLXN_717" name="CE" />
            <blockpin signalname="XLXN_718" name="CLR" />
            <blockpin signalname="XLXN_738(7:0)" name="D(7:0)" />
            <blockpin signalname="XLXN_743(7:0)" name="Q(7:0)" />
        </block>
    </netlist>
    <sheet sheetnum="1" width="3520" height="2720">
        <branch name="vram_W">
            <wire x2="544" y1="1136" y2="1136" x1="336" />
        </branch>
        <branch name="vram_A(14:0)">
            <wire x2="544" y1="1008" y2="1008" x1="368" />
        </branch>
        <branch name="vram_D(7:0)">
            <wire x2="544" y1="1200" y2="1200" x1="352" />
        </branch>
        <iomarker fontsize="28" x="336" y="1136" name="vram_W" orien="R180" />
        <iomarker fontsize="28" x="368" y="1008" name="vram_A(14:0)" orien="R180" />
        <iomarker fontsize="28" x="352" y="1200" name="vram_D(7:0)" orien="R180" />
        <iomarker fontsize="28" x="32" y="224" name="CLK25MHz" orien="R270" />
        <instance x="544" y="1232" name="XLXI_474" orien="R0">
        </instance>
        <branch name="HSYNC">
            <wire x2="2096" y1="688" y2="688" x1="1984" />
        </branch>
        <branch name="VSYNC">
            <wire x2="2096" y1="624" y2="624" x1="1984" />
        </branch>
        <instance x="1472" y="1040" name="XLXI_476" orien="R0">
        </instance>
        <iomarker fontsize="28" x="2096" y="624" name="VSYNC" orien="R0" />
        <iomarker fontsize="28" x="2096" y="688" name="HSYNC" orien="R0" />
        <branch name="XLXN_693(14:0)">
            <wire x2="544" y1="1072" y2="1072" x1="480" />
            <wire x2="480" y1="1072" y2="1296" x1="480" />
            <wire x2="2064" y1="1296" y2="1296" x1="480" />
            <wire x2="2064" y1="752" y2="752" x1="1984" />
            <wire x2="2064" y1="752" y2="1296" x1="2064" />
        </branch>
        <branch name="RED2(1:0)">
            <wire x2="2192" y1="880" y2="880" x1="1984" />
        </branch>
        <branch name="GREEN3(2:0)">
            <wire x2="2192" y1="944" y2="944" x1="1984" />
        </branch>
        <branch name="BLUE2(1:0)">
            <wire x2="2192" y1="1008" y2="1008" x1="1984" />
        </branch>
        <instance x="704" y="2640" name="XLXI_478" orien="R0">
        </instance>
        <branch name="XLXN_694(13:0)">
            <wire x2="384" y1="2480" y2="2688" x1="384" />
            <wire x2="3120" y1="2688" y2="2688" x1="384" />
            <wire x2="704" y1="2480" y2="2480" x1="384" />
            <wire x2="3120" y1="816" y2="816" x1="1984" />
            <wire x2="3120" y1="816" y2="2688" x1="3120" />
        </branch>
        <branch name="palette_W">
            <wire x2="704" y1="2544" y2="2544" x1="672" />
        </branch>
        <iomarker fontsize="28" x="672" y="2544" name="palette_W" orien="R180" />
        <branch name="palette_D(7:0)">
            <wire x2="704" y1="2608" y2="2608" x1="672" />
        </branch>
        <iomarker fontsize="28" x="672" y="2608" name="palette_D(7:0)" orien="R180" />
        <branch name="palette_A(13:0)">
            <wire x2="704" y1="2416" y2="2416" x1="544" />
        </branch>
        <iomarker fontsize="28" x="544" y="2416" name="palette_A(13:0)" orien="R180" />
        <branch name="vram_CLK">
            <wire x2="544" y1="880" y2="880" x1="368" />
        </branch>
        <branch name="palette_CLK">
            <wire x2="704" y1="2288" y2="2288" x1="608" />
        </branch>
        <iomarker fontsize="28" x="608" y="2288" name="palette_CLK" orien="R180" />
        <branch name="nCLK25MHz">
            <wire x2="32" y1="880" y2="944" x1="32" />
            <wire x2="544" y1="944" y2="944" x1="32" />
            <wire x2="32" y1="944" y2="1984" x1="32" />
            <wire x2="32" y1="1984" y2="2352" x1="32" />
            <wire x2="704" y1="2352" y2="2352" x1="32" />
            <wire x2="736" y1="1984" y2="1984" x1="32" />
            <wire x2="736" y1="1984" y2="2112" x1="736" />
            <wire x2="2080" y1="2112" y2="2112" x1="736" />
            <wire x2="944" y1="1712" y2="1712" x1="736" />
            <wire x2="736" y1="1712" y2="1984" x1="736" />
            <wire x2="2224" y1="1776" y2="1776" x1="2080" />
            <wire x2="2080" y1="1776" y2="2112" x1="2080" />
        </branch>
        <instance x="1664" y="1904" name="XLXI_483" orien="R0" />
        <branch name="XLXN_713(7:0)">
            <wire x2="944" y1="1456" y2="1456" x1="272" />
            <wire x2="272" y1="1456" y2="1584" x1="272" />
            <wire x2="336" y1="1584" y2="1584" x1="272" />
            <wire x2="944" y1="880" y2="880" x1="928" />
            <wire x2="944" y1="880" y2="1456" x1="944" />
        </branch>
        <branch name="XLXN_715(7:0)">
            <wire x2="1568" y1="2288" y2="2288" x1="1088" />
            <wire x2="1664" y1="1648" y2="1648" x1="1568" />
            <wire x2="1568" y1="1648" y2="2288" x1="1568" />
        </branch>
        <branch name="XLXN_719">
            <wire x2="2112" y1="1504" y2="1504" x1="1648" />
            <wire x2="2112" y1="1504" y2="1712" x1="2112" />
            <wire x2="2224" y1="1712" y2="1712" x1="2112" />
            <wire x2="1648" y1="1504" y2="1712" x1="1648" />
            <wire x2="1664" y1="1712" y2="1712" x1="1648" />
            <wire x2="2112" y1="1472" y2="1504" x1="2112" />
        </branch>
        <instance x="2224" y="1904" name="XLXI_488" orien="R0" />
        <instance x="2080" y="2160" name="XLXI_485" orien="R0" />
        <branch name="XLXN_721">
            <wire x2="1664" y1="1872" y2="1952" x1="1664" />
            <wire x2="2144" y1="1952" y2="1952" x1="1664" />
            <wire x2="2144" y1="1952" y2="2032" x1="2144" />
            <wire x2="2224" y1="1952" y2="1952" x1="2144" />
            <wire x2="2224" y1="1872" y2="1952" x1="2224" />
        </branch>
        <instance x="2048" y="1472" name="XLXI_487" orien="R0" />
        <branch name="XLXN_724(7:0)">
            <wire x2="2224" y1="1648" y2="1648" x1="2048" />
        </branch>
        <instance x="768" y="1408" name="XLXI_486" orien="R0" />
        <instance x="336" y="1840" name="XLXI_482" orien="R0" />
        <branch name="XLXN_717">
            <wire x2="320" y1="1424" y2="1648" x1="320" />
            <wire x2="336" y1="1648" y2="1648" x1="320" />
            <wire x2="832" y1="1424" y2="1424" x1="320" />
            <wire x2="832" y1="1424" y2="1648" x1="832" />
            <wire x2="944" y1="1648" y2="1648" x1="832" />
            <wire x2="832" y1="1408" y2="1424" x1="832" />
        </branch>
        <branch name="XLXN_718">
            <wire x2="336" y1="1808" y2="1872" x1="336" />
            <wire x2="944" y1="1872" y2="1872" x1="336" />
            <wire x2="944" y1="1872" y2="1936" x1="944" />
            <wire x2="944" y1="1808" y2="1872" x1="944" />
        </branch>
        <instance x="944" y="1840" name="XLXI_492" orien="R0" />
        <branch name="XLXN_738(7:0)">
            <wire x2="944" y1="1584" y2="1584" x1="720" />
        </branch>
        <branch name="XLXN_743(7:0)">
            <wire x2="1392" y1="1584" y2="1584" x1="1328" />
            <wire x2="1392" y1="816" y2="1584" x1="1392" />
            <wire x2="1472" y1="816" y2="816" x1="1392" />
        </branch>
        <branch name="XLXN_744(7:0)">
            <wire x2="1408" y1="528" y2="1008" x1="1408" />
            <wire x2="1472" y1="1008" y2="1008" x1="1408" />
            <wire x2="2720" y1="528" y2="528" x1="1408" />
            <wire x2="2720" y1="528" y2="1648" x1="2720" />
            <wire x2="2720" y1="1648" y2="1648" x1="2608" />
        </branch>
        <iomarker fontsize="28" x="368" y="880" name="vram_CLK" orien="R180" />
        <branch name="CLK25MHz">
            <wire x2="32" y1="224" y2="624" x1="32" />
            <wire x2="1136" y1="624" y2="624" x1="32" />
            <wire x2="1472" y1="624" y2="624" x1="1136" />
            <wire x2="1136" y1="624" y2="1280" x1="1136" />
            <wire x2="1136" y1="1280" y2="1280" x1="224" />
            <wire x2="224" y1="1280" y2="1712" x1="224" />
            <wire x2="224" y1="1712" y2="2064" x1="224" />
            <wire x2="1648" y1="2064" y2="2064" x1="224" />
            <wire x2="336" y1="1712" y2="1712" x1="224" />
            <wire x2="1664" y1="1776" y2="1776" x1="1648" />
            <wire x2="1648" y1="1776" y2="2064" x1="1648" />
        </branch>
        <instance x="880" y="2064" name="XLXI_484" orien="R0" />
        <iomarker fontsize="28" x="32" y="880" name="nCLK25MHz" orien="R270" />
        <iomarker fontsize="28" x="2192" y="880" name="RED2(1:0)" orien="R0" />
        <iomarker fontsize="28" x="2192" y="944" name="GREEN3(2:0)" orien="R0" />
        <iomarker fontsize="28" x="2192" y="1008" name="BLUE2(1:0)" orien="R0" />
    </sheet>
</drawing>