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

module jtbubl_gfx(
    input               rst,
    input               clk,
    input               clk24,
    input               pxl2_cen,
    input               pxl_cen,
    // PROMs
    input      [ 7:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,
    // Screen
    input               LHBL,
    input               LVBL,
    // CPU interface
    input               vram_cs,
    output reg [ 7:0]   vram_dout,
    input               cpu_rnw,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    // SDRAM interface
    output     [18:0]   gfx_addr,
    input      [15:0]   gfx_data,
    input               gfx_ok,
    output              gfx_cs,
    // Color address to palette
    output     [ 7:0]   col_addr
);

wire [ 7:0] scan0_data, scan1_data, scan2_data, scan3_data;
wire [ 7:0] vram0_dout, vram1_dout, vram2_dout, vram3_dout;
wire [10:0] vram_addr = cpu_addr[10:0];
reg  [ 3:0] vram_we;
reg  [10:0] scan_addr;

always @(*) begin
    vram_we = 4'd0;
    if( ~cpu_rnw && vram_cs ) vram_we[cpu_addr[1:0]] = 1;
end

always @(posedge clk) begin
    case( cpu_addr[1:0] )
        2'd0: vram_dout <= vram0_dout;
        2'd1: vram_dout <= vram1_dout;
        2'd2: vram_dout <= vram2_dout;
        2'd3: vram_dout <= vram3_dout;
    endcase
end

jtframe_dual_ram #(.aw(11),.simfile("vram0.hex")) u_ram0(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[0]),
    .q0     ( vram0_dout),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( scan0_data)
);

jtframe_dual_ram #(.aw(11),.simfile("vram1.hex")) u_ram1(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[1]),
    .q0     ( vram1_dout),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( scan1_data)
);

jtframe_dual_ram #(.aw(11),.simfile("vram2.hex")) u_ram2(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[2]),
    .q0     ( vram2_dout),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( scan2_data)
);

jtframe_dual_ram #(.aw(11),.simfile("vram3.hex")) u_ram3(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[3]),
    .q0     ( vram3_dout),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( scan3_data)
);

jtframe_prom #(.dw(4),.aw(8), .simfile("prom.hex")) u_prom(
    .clk    ( clk       ),
    .cen    ( pxl2_cen  ),
    .data   ( prog_data ),
    .rd_addr(           ),
    .wr_addr( prog_addr ),
    .we     ( prom_we   ),
    .q      (           )
);

endmodule