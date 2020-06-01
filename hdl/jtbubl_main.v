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
    input               clk24,

    // Video interface
    output reg          vram_cs,
    output reg          pal_cs,
    output reg          black_n,
    output reg          flip,

    // Sound interface
    input      [ 7:0]   snd_reply,
    ouput reg  [ 7:0]   snd_cmd,

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
);

reg  [ 7:0] main_din, sub_din;
wire [ 7:0] ram2main, ram2sub, main_dout, sub_dout;
wire [15:0] main_addr, sub_addr;
wire        main_mreq_n, main_iorq_n, main_rd_n, main_wr_n, main_rfsh_n;
wire        sub_mreq_n,  sub_iorq_n,  sub_rd_n,  sub_wr_n;
reg         main_sub_cs, main_mcu_cs, // shared memories
            tres_cs,  // watchdog reset
            main2sub_nmi_n,
            misc_cs;
reg  [ 2:0] bank;
reg         sub_rst_n, mcu_rst_n;

assign      main_rom_addr = main_addr[15] ?
                        { { {1'b0, bank}+4'b10} , main_addr[13:0] } : // banked
                        { 3'd0, main_addr[14:0] }; // not banked
assign      sub_rom_addr = sub_addr[14:0];

// Main CPU address decoder
always @(*) begin
    main_rom_cs    = !mreq_n && (!main_addr[15] || main_addr[15:14]==2'b10);
    vram_cs        = !mreq_n && main_addr[15:13]==3'b110;
    main_sub_cs    = !mreq_n && main_addr[15:13]==3'b111 && main_addr[12:11]!=2'b11;
    pal_cs         = !mreq_n && main_addr[15: 9]==7'b1111_100;
    sound_cs       = !mreq_n && main_addr[15: 8]==8'hFA && !main_addr[7];
    tres_cs        = !mreq_n && main_addr[15: 8]==8'hFA && main_addr[7];
    main2sub_nmi_n = !mreq_n && main_addr[15: 8]==8'hFA && main_addr[7:6]==2'b00;
    misc_cs        = !mreq_n && main_addr[15: 8]==8'hFA && main_addr[7:6]==2'b01;
    main_mcu_cs    = !mreq_n && main_addr[15:10]==6'b1111_11
end

always @(posedge clk24 ) begin
    if( !main_rst_n ) begin
        bank      <= 3'd0;
        sub_rst_n <= 0;
        mcu_rst_n <= 0;
        black_n   <= 0;
        flip      <= 0;
    end else begin
        bank      <= cpu_dout[2:0];
        sub_rst_n <= cpu_dout[4];
        mcu_rst_n <= cpu_dout[5];
        black_n   <= cpu_dout[6];
        flip      <= cpu_dout[7];
    end
end

// Watchdog triggers after 256 frames

// Time shared
jtframe_dual_ram #(.aw(13)) u_shared(
    .clk0   ( clk24           ),
    .clk1   ( clk24           ),
    // Port 0
    .data0  ( main_dout       ),
    .addr0  ( main_addr[12:0] ),
    .we0    ( main_we         ),
    .q0     ( ram2main        ),
    // Port 1
    .data1  ( sub_dout        ),
    .addr1  ( sub_addr        ),
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
    .wr_n     ( main_wr_n      ),
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
    .int_n    ( 1'b1           ),
    .nmi_n    ( main2sub_nmi_n ),
    .busrq_n  ( 1'b1           ),
    .m1_n     (                ),
    .mreq_n   ( sub_mreq_n     ),
    .iorq_n   ( sub_iorq_n     ),
    .rd_n     ( sub_rd_n       ),
    .wr_n     ( sub_wr_n       ),
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

endmodule