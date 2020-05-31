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
    Date: 02-05-2020 */

module jtbubl_game(
    input           rst,
    input           clk,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    input           loop_rst,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [31:0]  data_read,
    input           data_rdy,
    input           sdram_ack,
    output          refresh_en,
    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_data,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input   [31:0]  dipsw,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB   
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [ 3:0]  gfx_en
);

wire        main_cs, sub_cs, mcu_cs, snd_cs, gfx_cs;
wire        main_ok, sub_ok, mcu_ok, snd_ok, gfx_ok;
wire        snd_irq;
wire [15:0] gfx_data;
wire [18:0] gfx_addr;

wire [ 7:0] main_data, sub_data, mcu_data, snd_data, snd_latch;
wire [14:0] snd_addr, sub_addr, mcu_addr;
wire [17:0] main_addr;
wire        cen12, prom_we;

wire [ 7:0] dipsw_a, dipsw_b;
wire        LHBL, LVBL;

wire [12:0] cpu_addr;
wire        vram_cs,  pal_cs;
wire        cpu_cen, cpu_rnw, cpu_irqn;
wire [ 7:0] gfx_dout, pal_dout, cpu_dout;

assign prog_rd    = 0;
assign dwnld_busy = downloading;
assign { dipsw_b, dipsw_a } = dipsw[19:0];

localparam [24:0] SUB_OFFSET = 25'h2_8000 >> 1;
localparam [24:0] SND_OFFSET = 25'h3_0000 >> 1;
localparam [24:0] MCU_OFFSET = 25'h3_8000 >> 1;
localparam [24:0] GFX_OFFSET = 25'h4_0000 >> 1;
localparam [24:0] PROM_START = 25'hC_0000;

jtframe_cen24 u_cen(
    .clk        ( clk24         ),    // 24 MHz
    .cen12      ( cen12         ),
    .cen6       (               ),
    .cen4       (               ),
    .cen3       (               ),
    .cen3q      (               ), // 1/4 advanced with respect to cen3
    .cen1p5     (               ),
    // 180 shifted signals
    .cen12b     (               ),
    .cen6b      (               ),
    .cen3b      (               ),
    .cen3qb     (               ),
    .cen1p5b    (               )
);

jtframe_dwnld #(.PROM_START(PROM_START))
u_dwnld(
    .clk            ( clk           ),
    .downloading    ( downloading   ),
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_data     ( ioctl_data    ),
    .ioctl_wr       ( ioctl_wr      ),
    .prog_addr      ( prog_addr     ),
    .prog_data      ( prog_data     ),
    .prog_mask      ( prog_mask     ), // active low
    .prog_we        ( prog_we       ),
    .prom_we        ( prom_we       ),
    .sdram_ack      ( sdram_ack     )
);

`ifndef NOMAIN
jtbubl_main u_main(
    .clk            ( clk24         ),        // 24 MHz
    .rst            ( rst           ),
    .cen12          ( cen12         ),
    .cpu_cen        ( cpu_cen       ),
    // communication with main CPU
    .snd_irq        ( snd_irq       ),
    .snd_latch      ( snd_latch     ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // cabinet I/O
    .start_button   ( start_button  ),
    .coin_input     ( coin_input    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( 1'b1          ),
    // GFX
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),
    .gfx_irqn       ( cpu_irqn      ),
    .gfx_vram_cs    ( gfx_vram_cs   ),
    .gfx2_vram_cs   ( gfx2_vram_cs  ),
    .gfx_cfg_cs     ( gfx_cfg_cs    ),
    .gfx2_cfg_cs    ( gfx2_cfg_cs   ),
    .pal_cs         ( pal_cs        ),

    .gfx_dout      ( gfx_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       )
);
`endif

jtbubl_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk24          ( clk24         ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .LHBL_dly       ( LHBL_dly      ),
    .LVBL_dly       ( LVBL_dly      ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( dip_flip      ),
    .dip_pause      ( dip_pause     ),
    .start_button   ( &start_button ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      ( prog_addr[7:0]),
    .prog_data      ( prog_data[3:0]),
    /*
    // GFX - CPU interface
    .cpu_irqn       ( cpu_irqn      ),
    .vram_cs        ( vram_cs       ),
    .pal_cs         ( pal_cs        ),
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_cen        ( cpu_cen       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .gfx_dout       ( gfx_dout      ),
    .pal_dout       ( pal_dout      ),
    // SDRAM
    .gfx_addr       ( gfx_addr      ),
    .gfx_data       ( gfx_data      ),
    .gfx_ok         ( gfx_ok        ),
    .gfx_cs         ( gfx_cs        ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),*/
    // Test
    .gfx_en         ( gfx_en        )
);

`ifndef NOSOUND
jtbubl_sound u_sound(
    .clk        ( clk24         ), // 24 MHz
    .rst        ( rst           ),
    .cen12      ( cen12         ),
    // communication with main CPU
    .snd_irq    ( snd_irq       ),
    .snd_latch  ( snd_latch     ),
    // ROM
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    // Sound output
    .snd_left   ( snd_left      ),
    .snd_right  ( snd_right     ),
    .sample     ( sample        )
);
`else 
assign snd_cs   = 0;
assign snd_addr = 15'd0;
assign snd_left = 16'd0;
assign snd_right= 16'd0;
assign sample   = 0;
`endif

jtframe_rom #(
    .SLOT0_AW    ( 18              ),
    .SLOT0_DW    (  8              ),
    .SLOT0_OFFSET(  0              ), // Main

    .SLOT1_AW    ( 15              ),
    .SLOT1_DW    (  8              ),
    .SLOT1_OFFSET(  SUB_OFFSET     ), // Sub

    .SLOT2_AW    ( 15              ),
    .SLOT2_DW    (  8              ),
    .SLOT2_OFFSET(  MCU_OFFSET     ), // MCU

    .SLOT3_AW    ( 15              ), // Sound
    .SLOT3_DW    (  8              ),
    .SLOT3_OFFSET( SND_OFFSET      ),

    .SLOT4_AW    ( 18              ), // GFX
    .SLOT4_DW    ( 32              ),
    .SLOT4_OFFSET( GFX_OFFSET      )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .vblank      ( ~LVBL         ),

    .slot0_cs    ( main_cs       ),
    .slot1_cs    ( sub_cs        ),
    .slot2_cs    ( mcu_cs        ), 
    .slot3_cs    ( snd_cs        ), // unused
    .slot4_cs    ( gfx_cs        ),
    .slot5_cs    ( 1'b0          ), // unused
    .slot6_cs    (               ),
    .slot7_cs    ( 1'b0          ), // unused
    .slot8_cs    ( 1'b0          ),

    .slot0_ok    ( main_ok       ),
    .slot1_ok    ( sub_ok        ),
    .slot2_ok    ( mcu_ok        ),
    .slot3_ok    ( snd_ok        ),
    .slot4_ok    ( gfx_ok        ),
    .slot5_ok    (               ),
    .slot6_ok    (               ),
    .slot7_ok    (               ),
    .slot8_ok    (               ),

    .slot0_addr  ( main_addr     ),
    .slot1_addr  ( sub_addr      ),
    .slot2_addr  ( mcu_addr      ),
    .slot3_addr  ( snd_addr      ),
    .slot4_addr  ( gfx_addr      ),
    .slot5_addr  (               ),
    .slot6_addr  (               ),
    .slot7_addr  (               ),
    .slot8_addr  (               ),

    .slot0_dout  ( main_data     ),
    .slot1_dout  ( sub_data      ),
    .slot2_dout  ( mcu_data      ),
    .slot3_dout  ( snd_data      ),
    .slot4_dout  ( gfx_data      ),
    .slot5_dout  (               ),
    .slot6_dout  (               ),
    .slot7_dout  (               ),
    .slot8_dout  (               ),

    .ready       (               ),
    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    .refresh_en  ( refresh_en    )
);

endmodule