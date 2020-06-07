/*  This file is part of JTBUBL.
    JTBUBL program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTBUBL program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTBUBL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 1-06-2020 */

module jtbubl_main(
    input               rst,
    input               clk24,
    input               cen6,

    // Cabinet inputs
    input      [ 1:0]   start_button,
    input      [ 1:0]   coin_input,
    input      [ 5:0]   joystick1,
    input      [ 5:0]   joystick2,

    // Video interface
    output reg          vram_cs,
    output reg          pal_cs,
    output reg          black_n,
    output reg          flip,
    output     [12:0]   cpu_addr,
    output     [ 7:0]   cpu_dout,
    output              cpu_rnw,
    input      [ 7:0]   vram_dout,
    input      [ 7:0]   pal_dout,
    input               LVBL,

    // Sound interface
    // input      [ 7:0]   snd_reply,
    output reg [ 7:0]   snd_latch,

    // Main CPU ROM interface
    output     [17:0]   main_rom_addr,
    output reg          main_rom_cs,
    input               main_rom_ok,
    input      [ 7:0]   main_rom_data,

    // Sub CPU ROM interface
    output     [14:0]   sub_rom_addr,
    output reg          sub_rom_cs,
    input               sub_rom_ok,
    input      [ 7:0]   sub_rom_data,

    // MCU ROM interface
    output     [11:0]   mcu_rom_addr,
    output              mcu_rom_cs,
    input               mcu_rom_ok,
    input      [ 7:0]   mcu_rom_data,

    // DIP switches
    input               dip_pause,
    input      [ 7:0]   dipsw_a,
    input      [ 7:0]   dipsw_b
);

reg  [ 7:0] main_din, sub_din;
wire [ 7:0] ram2main, ram2sub, main_dout, sub_dout, mcu_dout,
            rammcu2main, rammcu2mcu,
            p1_in,
            p1_out, p2_out, p3_out, p4_out;
reg  [ 7:0] p3_in, rammcu_din;
wire [11:0] mcu_bus;
wire [15:0] main_addr, sub_addr, mcu_addr;
wire        main_mreq_n, main_iorq_n, main_rd_n, main_wrn, main_rfsh_n;
wire        sub_mreq_n,  sub_iorq_n,  sub_rd_n,  sub_wrn, mcu_wrn;
reg         rammcu_we, rammcu_cs;
reg         main_sub_cs, main_mcu_cs, // shared memories
            tres_cs,  // watchdog reset
            main2sub_nmi,
            misc_cs, sound_cs;
reg         sub_main_cs;
wire        sub_we, main_we, mainmcu_we, sub_int_n, mcu2main_int_n,
            mcu_vma;
reg  [ 2:0] bank;
reg         main_rst_n, sub_rst_n, mcu_rst;
reg  [ 7:0] wdog_cnt;
reg         last_LVBL;

assign      main_rom_addr = main_addr[15] ?
                        { { {1'b0, bank}+4'b10} , main_addr[13:0] } : // banked
                        { 3'd0, main_addr[14:0] }; // not banked
assign      sub_rom_addr = sub_addr[14:0];
assign      main_we      = main_sub_cs && !main_wrn;
assign      mainmcu_we   = main_mcu_cs && !main_wrn;
assign      sub_we       = sub_main_cs && !sub_wrn;
assign      cpu_addr     = main_addr[12:0];
assign      cpu_dout     = main_dout;
assign      cpu_rnw      = main_wrn;
assign      p1_in[7:4]   = 4'hf;
assign      p1_in[3:2]   = coin_input;
assign      p1_in[1:0]   = 2'b11;
assign      mcu_bus      = { p2_out[3:0], p4_out };

// Watchdog and main CPU reset
always @(posedge clk24, posedge rst) begin
    if( rst ) begin
        main_rst_n <= 0;
        wdog_cnt   <= 8'd0;
    end else begin
        last_LVBL  <= LVBL;
        if( tres_cs )
            wdog_cnt <= 8'd0;
        else if( LVBL && !last_LVBL ) wdog_cnt <= wdog_cnt + 8'd1;
        main_rst_n <= ~wdog_cnt[7];
    end
end

// Main CPU address decoder
always @(*) begin
    main_rom_cs    = !main_mreq_n && (!main_addr[15] || main_addr[15:14]==2'b10);
    vram_cs        = !main_mreq_n && main_addr[15:13]==3'b110;
    main_sub_cs    = !main_mreq_n && main_addr[15:13]==3'b111 && main_addr[12:11]!=2'b11;
    pal_cs         = !main_mreq_n && main_addr[15: 9]==7'b1111_100;
    sound_cs       = !main_mreq_n && main_addr[15: 8]==8'hFA && !main_addr[7];
    tres_cs        = !main_mreq_n && main_addr[15: 8]==8'hFA && main_addr[7];
    main2sub_nmi   = !main_mreq_n && main_addr[15: 8]==8'hFB && main_addr[7:6]==2'b00 && !main_wrn;
    misc_cs        = !main_mreq_n && main_addr[15: 8]==8'hFB && main_addr[7:6]==2'b01 && !main_wrn;
    main_mcu_cs    = !main_mreq_n && main_addr[15:10]==6'b1111_11;
end

// Main CPU input mux
always @(*) begin
    main_din = 
        main_rom_cs ? main_rom_data : (
        vram_cs     ? vram_dout     : (
        pal_cs      ? pal_dout      : (
        main_sub_cs ? ram2main      : (
        main_mcu_cs ? rammcu2main   : 8'hff
        ))));
end

// Main CPU miscellaneous control bits
always @(posedge clk24 ) begin
    if( !main_rst_n ) begin
        bank      <= 3'd0;
        sub_rst_n <= 0;
        mcu_rst   <= 1;
        black_n   <= 0;
        flip      <= 0;
    end else if(misc_cs) begin
        bank      <= cpu_dout[2:0];
        sub_rst_n <= cpu_dout[4];
        mcu_rst   <= ~cpu_dout[5];
        black_n   <= cpu_dout[6];
        flip      <= cpu_dout[7];
    end
end

// Communication with sound CPU
always @(posedge clk24 ) begin
    if( !main_rst_n ) begin
        snd_latch <= 8'd0;
    end else if(sound_cs) begin
        if( !main_wrn )
            snd_latch <= main_dout;
    end
end

// Sub CPU address decoder
always @(*) begin
    sub_rom_cs     = !sub_mreq_n && !sub_addr[15];
    sub_main_cs    = !sub_mreq_n &&  sub_addr[15:13]==3'b111;
end

// Sub CPU input mux
always @(*) begin
    sub_din = sub_rom_cs  ? sub_rom_data : (
              sub_main_cs ? ram2sub : 8'hff );
end

// Time shared
jtframe_dual_ram #(.aw(13)) u_subshared(
    .clk0   ( clk24           ),
    .clk1   ( clk24           ),
    // Port 0
    .data0  ( main_dout       ),
    .addr0  ( main_addr[12:0] ),
    .we0    ( main_we         ),
    .q0     ( ram2main        ),
    // Port 1
    .data1  ( sub_dout        ),
    .addr1  ( sub_addr[12:0]  ),
    .we1    ( sub_we          ),
    .q1     ( ram2sub         )
);

/////////////////////////////////////////
// Main CPU

jtframe_z80 u_maincpu(
    .rst_n    ( main_rst_n     ),
    .clk      ( clk24          ),
    .cen      ( cen6           ),
    .wait_n   ( main_wait_n    ),
    .int_n    ( mcu2main_int_n ),
    .nmi_n    ( 1'b1           ),
    .busrq_n  ( 1'b1           ),
    .m1_n     (                ),
    .mreq_n   ( main_mreq_n    ),
    .iorq_n   ( main_iorq_n    ),
    .rd_n     ( main_rd_n      ),
    .wr_n     ( main_wrn       ),
    .rfsh_n   ( main_rfsh_n    ),
    .halt_n   (                ),
    .busak_n  (                ),
    .A        ( main_addr      ),
    .din      ( main_din       ),
    .dout     ( main_dout      )
);

jtframe_rom_wait u_mainwait(
    .rst_n    ( main_rst_n      ),
    .clk      ( clk24           ),
    .cen_in   (                 ),
    .cen_out  (                 ),
    .gate     ( main_wait_n     ),
    // manage access to ROM data from SDRAM
    .rom_cs   ( main_rom_cs     ),
    .rom_ok   ( main_rom_ok     )
);

/////////////////////////////////////////
// Sub CPU

jtframe_z80 u_subcpu(
    .rst_n    ( sub_rst_n      ),
    .clk      ( clk24          ),
    .cen      ( cen6           ),
    .wait_n   ( sub_wait_n     ),
    .int_n    ( sub_int_n      ),
    .nmi_n    ( ~main2sub_nmi  ),
    .busrq_n  ( 1'b1           ),
    .m1_n     (                ),
    .mreq_n   ( sub_mreq_n     ),
    .iorq_n   ( sub_iorq_n     ),
    .rd_n     ( sub_rd_n       ),
    .wr_n     ( sub_wrn        ),
    .rfsh_n   (                ),
    .halt_n   (                ),
    .busak_n  (                ),
    .A        ( sub_addr       ),
    .din      ( sub_din        ),
    .dout     ( sub_dout       )
);

jtframe_rom_wait u_subwait(
    .rst_n    ( sub_rst_n       ),
    .clk      ( clk24           ),
    .cen_in   (                 ),
    .cen_out  (                 ),
    .gate     ( sub_wait_n      ),
    // manage access to ROM data from SDRAM
    .rom_cs   ( sub_rom_cs      ),
    .rom_ok   ( sub_rom_ok      )
);

jtframe_ff u_subint(
    .rst    ( rst           ),
    .clk    ( clk24         ),
    .cen    ( 1'b1          ),
    .din    ( 1'b1          ),
    .q      (               ),
    .qn     ( sub_int_n     ),
    .set    ( 1'b0          ),
    .clr    ( ~sub_iorq_n   ),
    .sigedge( ~LVBL         ) 
);

/////////////////////////////////////////
// MCU

jtframe_ff u_mcu2main (
    .clk    ( clk24          ),
    .rst    ( rst            ),
    .cen    ( 1'b1           ),
    .din    ( 1'b1           ),
    .q      (                ),
    .qn     ( mcu2main_int_n ),
    .set    ( 1'b1           ),
    .clr    ( main_iorq_n    ),
    .sigedge( p1_out[6]      )
);

// Time shared
jtframe_dual_ram #(.aw(11)) u_mcushared(
    .clk0   ( clk24                ),
    .clk1   ( clk24                ),
    // Port 0: Main CPU access
    .data0  ( main_dout            ),
    .addr0  ( main_addr[10:0]      ),
    .we0    ( mainmcu_we           ),
    .q0     ( rammcu2main          ),
    // Port 1: MCU access
    .data1  ( rammcu_din          ),
    .addr1  ( {1'b0, mcu_bus[9:0]} ),
    .we1    ( rammcu_we            ),
    .q1     ( rammcu2mcu           )
);

always @(*) begin
    if( rammcu_cs )
        p3_in = rammcu2mcu;
    else begin
        case( mcu_bus[1:0] )
            2'd0: p3_in = dipsw_a;
            2'd1: p3_in = dipsw_b;
            2'd2: p3_in = {1'b1, start_button[0], joystick1 };
            2'd3: p3_in = {1'b1, start_button[1], joystick2 };
        endcase // mcu_bus[1:0]
    end
end

reg [3:0] clrcnt;
reg       last_sub_int_n;
reg       mcuirq;

wire      cen_mcu = cen6;

always @(posedge clk24, posedge rst) begin
    if( rst ) begin
        clrcnt <= 4'd0;
        last_sub_int_n <= 1;
        mcuirq <= 0;
    end else if(cen_mcu) begin
        last_sub_int_n <= sub_int_n;
        if( last_sub_int_n && !sub_int_n ) begin
            clrcnt <= 4'd0;
            mcuirq <= 1;
        end else if(mcuirq) begin
            clrcnt<=clrcnt+4'd1;
            if(&clrcnt) mcuirq<=0;
        end
    end
end

wire rammcu_clk = p2_out[4];
reg last_rammcu_clk;

always @(posedge clk24, posedge rst) begin
    if( rst ) begin
        rammcu_cs       <= 0;
        rammcu_we       <= 0;
        last_rammcu_clk <= 1;
        rammcu_din      <= 8'd0;
    end else if(cen_mcu) begin
        last_rammcu_clk <= rammcu_clk;
        if( rammcu_clk && !last_rammcu_clk ) begin
            if( mcu_bus[11:10]==2'b11 ) begin
                rammcu_cs <= 1;
                rammcu_we <= !p1_out[7];
                rammcu_din <= p3_out;
            end else begin
                rammcu_cs <= 0;
                rammcu_we <= 0;
            end            
        end
    end
end

jtframe_6801mcu #(.MAXPORT(7)) u_mcu (
    .rst        ( mcu_rst       ),
    //.rst( rst ), // for quick sims
    .clk        ( clk24         ),
    .cen        ( cen_mcu       ),  // this should be cen4, but let's start easy
    .wrn        ( mcu_wrn       ),
    .vma        ( mcu_vma       ),
    .addr       ( mcu_addr      ),
    .dout       ( mcu_dout      ), 
    .halt       ( 1'b0          ),
    .halted     (               ),
    .irq        ( mcuirq        ), // relies on sub CPU to clear it
    .nmi        ( 1'b0          ),
    // Ports
    .p1_in      ( p1_in         ),
    .p1_out     ( p1_out        ),
    .p2_in      ( p2_out        ), // feed back p2_out for sims
    .p2_out     ( p2_out        ),
    .p3_in      ( p3_in         ),
    .p3_out     ( p3_out        ),
    .p4_in      ( p4_out        ), // feed back p4_out for sims
    .p4_out     ( p4_out        ),
    // external RAM
    .ext_cs     ( 1'b0          ),
    .ext_dout   (               ),
    // ROM interface
    .rom_addr   ( mcu_rom_addr  ),
    .rom_data   ( mcu_rom_data  ),
    .rom_cs     ( mcu_rom_cs    ),
    .rom_ok     ( mcu_rom_ok    )
);

endmodule