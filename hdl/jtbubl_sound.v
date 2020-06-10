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
    Date: 02-06-2020 */

module jtbubl_sound(
    input             rstn,
    input             clk,
    input             cen3,   //  3   MHz
    // Interface with main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    output reg [ 7:0] main_latch,    
    output reg        main_flag,
    // ROM
    output     [14:0] rom_addr,
    output  reg       rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,

    // Sound output
    output signed [15:0] snd,
    output            sample
);

wire        [15:0] A;
wire               iorq_n, m1_n, wr_n, rd_n;
wire        [ 7:0] ram_dout, dout, fm0_dout, fm1_dout;
reg                ram_cs, fm1_cs, fm0_cs, latch_cs, io_cs, nmi_en;
wire               mreq_n, rfsh_n;
wire               snd_flag;
reg         [ 7:0]  din;
wire               intn_fm0, intn_fm1;
wire               int_n;
wire               flag_clr;
wire               nmi_n;
wire signed [15:0] fm0_snd,  fm1_snd;
wire        [ 9:0] psg_snd;
wire signed [ 9:0] psg2x; // DC-removed version of psg0

assign int_n      = intn_fm0;
assign rom_addr   = A[14:0];
assign fm1_dout   = 8'h00;
assign nmi_n      = snd_flag | ~nmi_en;
assign flag_clr   = io_cs && !rd_n && A[1:0]==2'b0;

always @(*) begin
    rom_cs = !mreq_n && A[15];
    ram_cs = !mreq_n && !A[15] && A[14:13]==2'b00;
    fm0_cs = !mreq_n && !A[15] && A[14:13]==2'b01;
    fm1_cs = !mreq_n && !A[15] && A[14:13]==2'b10;
    io_cs  = !mreq_n && !A[15] && A[14:13]==2'b11;
end

always @(posedge clk) begin
    if( io_cs && !rd_n )
        din <= A[1] ? 8'hff : (
            A[0] ? {7'hf,snd_flag} : snd_latch);
    else begin
        case( 1'b1 )
            rom_cs:   din <= rom_data;
            fm0_cs:   din <= fm0_dout;
            fm1_cs:   din <= fm1_dout;
            latch_cs: din <= snd_latch;
            ram_cs:   din <= ram_dout;
            default:  din <= 8'hff;
        endcase
    end
end

always @(posedge clk, negedge rstn) begin
    if( !rstn ) begin
        main_latch <= 8'h00;
        main_flag  <= 0;
        nmi_en     <= 0;
    end else begin
        if( io_cs && !wr_n ) begin
            case( A[1:0] )
                2'd0: begin
                    main_latch <= dout;
                    main_flag  <= 1;
                end
                2'd1: nmi_en     <= 1; // enables NMI
                2'd2: nmi_en     <= 0;
            endcase
        end else begin
            main_flag <= 0;
        end
    end
end

jtframe_ff u_flag(
    .clk    ( clk      ),
    .rst    ( ~rstn    ),
    .cen    ( 1'b1     ),
    .din    ( 1'b0     ),
    .q      (          ),
    .qn     ( snd_flag ),
    .set    ( flag_clr ),
    .clr    ( 1'b0     ),
    .sigedge( snd_stb  )
);

jtframe_sysz80 #(.RAM_AW(13)) u_cpu(
    .rst_n      ( rstn        ),
    .clk        ( clk         ),
    .cen        ( cen3        ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     (             ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   (             ),
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

jt49_dcrm2 #(.sw(10)) u_dcrm (
    .clk    (  clk      ),
    .cen    (  cen3     ),
    .rst    (  ~rstn    ),
    .din    (  psg_snd  ),
    .dout   (  psg2x    )
);

jt12_mixer #(.w0(16),.w1(16),.w2(10),.w3(8),.wout(16)) u_mixer(
    .clk    ( clk          ),
    .cen    ( cen3         ),
    .ch0    ( fm0_snd      ),
    .ch1    ( fm1_snd      ),
    .ch2    ( psg2x        ),
    .ch3    ( 8'd0         ),
    .gain0  ( 8'h10        ),
    .gain1  ( 8'h10        ),
    .gain2  ( 8'h10        ),
    .gain3  ( 8'd0         ),
    .mixed  ( snd          )
);

jt03 u_2203(
    .rst    ( ~rstn      ),
    // CPU interface
    .clk    ( clk        ),
    .cen    ( cen3       ),
    .din    ( dout       ),
    .addr   ( A[0]       ),
    .cs_n   ( ~fm0_cs    ),
    .wr_n   ( wr_n       ),
    .psg_snd( psg_snd    ),
    .fm_snd ( fm0_snd    ),
    .snd_sample ( sample ),
    // unused outputs
    .dout   ( fm0_dout   ),
    .irq_n  ( intn_fm0   ),
    .psg_A  (),
    .psg_B  (),
    .psg_C  (),
    .snd    ()
);

assign fm1_snd = 16'd0;

`ifdef SIMULATION
    integer fsnd;
    initial begin
        fsnd=$fopen("fm_sound.raw","wb");
    end
    always @(posedge sample) begin
        $fwrite(fsnd,"%u", {fm0_snd, fm1_snd});
    end
`endif

endmodule