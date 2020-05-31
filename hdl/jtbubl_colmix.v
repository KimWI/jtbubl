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
    Date: 29-05-2020 */

module jtbubl_colmix(
    input               rst,
    input               clk,
    input               clk24,
    //output              pxl2_cen,
    input               pxl_cen,
    // Screen
    input               LHBL,
    input               LVBL,
    output              LHBL_dly,
    output              LVBL_dly,
    input      [ 7:0]   col_addr,
    // CPU interface
    input               pal_cs,
    output     [ 7:0]   pal_dout,
    input               cpu_rnw,
    input      [ 8:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,    
    // Colours
    output     [ 3:0]   red,
    output     [ 3:0]   green,
    output     [ 3:0]   blue
);

reg  [11:0] col_in;
wire [11:0] col_out;
wire [ 7:0] col0_data, col1_data;
wire        pal0_we = pal_cs & ~cpu_rnw & ~cpu_addr[0];
wire        pal1_we = pal_cs & ~cpu_rnw &  cpu_addr[0];
wire [ 7:0] cpu_a11 = cpu_addr[8:1];

assign { red, green, blue } = col_out;

jtframe_dual_ram #(.aw(8),.simhexfile("pal_even.hex")) u_ram0(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_a11   ),
    .we0    ( pal0_we   ),
    .q0     ( pal_dout  ),
    // Port 1
    .data1  (           ),
    .addr1  ( col_addr  ),
    .we1    ( 1'b0      ),
    .q1     ( col0_data )
);

jtframe_dual_ram #(.aw(8),.simhexfile("pal_odd.hex")) u_ram1(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_a11   ),
    .we0    ( pal1_we   ),
    .q0     ( pal_dout  ),
    // Port 1
    .data1  (           ),
    .addr1  ( col_addr  ),
    .we1    ( 1'b0      ),
    .q1     ( col1_data )
);

`ifdef GRAY
always @(posedge clk) if(pxl_cen) col_in <= {3{col_addr[3:0]}};
`else
always @(posedge clk) if(pxl_cen) col_in = { col1_data, col0_data[7:4] };
`endif

jtframe_blank #(.DLY(3),.DW(12)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .LHBL_dly   ( LHBL_dly  ),
    .LVBL_dly   ( LVBL_dly  ),
    .preLBL     (           ),
    .rgb_in     ( col_in    ),
    .rgb_out    ( col_out   )
);


endmodule