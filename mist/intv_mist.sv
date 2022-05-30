//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

`default_nettype none
module intv_mist
(
   input         CLOCK_27,   // Input clock 27 MHz

   output  [5:0] VGA_R,
   output  [5:0] VGA_G,
   output  [5:0] VGA_B,
   output        VGA_HS,
   output        VGA_VS,

   output        LED,

   output        AUDIO_L,
   output        AUDIO_R,

   output        UART_TX,
   input         UART_RX,

   input         SPI_SCK,
   output        SPI_DO,
   input         SPI_DI,
   input         SPI_SS2,
   input         SPI_SS3,
   input         CONF_DATA0,

   output [12:0] SDRAM_A,
   inout  [15:0] SDRAM_DQ,
   output        SDRAM_DQML,
   output        SDRAM_DQMH,
   output        SDRAM_nWE,
   output        SDRAM_nCAS,
   output        SDRAM_nRAS,
   output        SDRAM_nCS,
   output  [1:0] SDRAM_BA,
   output        SDRAM_CLK,
   output        SDRAM_CKE
);

//////////////////////////////////////////////////////////////////

// assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

//////////////////////////////////////////////////////////////////

`include "build_id.v"

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XX XXXXXXXXXXXXXXXXXXXXX

localparam CONF_STR = {
    "INTV;;",
    "F,ROMINTBIN,Load Cartridge;",
    "O58,MAP,Auto,0,1,2,3,4,5,6,7,8,9;",
    "OMN,Format,Auto,Raw,Intellicart;",
    "O9,ECS,Off,On;",
    "OA,Voice,On,Off;",
    "OCD,Scanlines,Off,25%,50%,75%;",
    "OB,Video standard,NTSC,PAL;",
    "O1,Swap Joystick,Off,On;",
    "T0,Reset;",
    "V,v",`BUILD_DATE
};

wire  [1:0] buttons;
wire [63:0] status;

wire        ioctl_download;
wire [7:0]  ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0]  ioctl_dout;
wire        ioctl_wait;
wire [31:0] js0,js1;
wire [15:0] ja0,ja1;
wire clk_sys,pll_locked;
wire ps2_key_pressed;
wire ps2_key_stb;
wire ps2_key_ext;
wire [7:0] ps2_key;
wire tv15khz;

// include user_io module for arm controller communication
user_io #(.STRLEN($size(CONF_STR)>>3)) user_io (
	.conf_str       ( CONF_STR       ),

	.clk_sys        ( clk_sys        ),

	.SPI_CLK        ( SPI_SCK        ),
	.SPI_SS_IO      ( CONF_DATA0     ),
	.SPI_MISO       ( SPI_DO         ),
	.SPI_MOSI       ( SPI_DI         ),

	.scandoubler_disable ( tv15khz   ),
	.ypbpr          ( ),
	.no_csync       ( ),
	.buttons        ( buttons        ),

	.joystick_0     ( js0            ),
	.joystick_1     ( js1            ),
	.joystick_analog_0 ( ja0            ),
	.joystick_analog_1 ( ja1            ),

	.status         ( status         ),
	.key_pressed    (ps2_key_pressed ),
	.key_extended   (ps2_key_ext),
	.key_code       (ps2_key),
	.key_strobe     (ps2_key_stb)
);


data_io data_io (
	.clk_sys        ( clk_sys ),
	// SPI interface
	.SPI_SCK        ( SPI_SCK ),
	.SPI_SS2        ( SPI_SS2 ),
	.SPI_DI         ( SPI_DI  ),

	// ram interface
	.ioctl_download ( ioctl_download ),
	.ioctl_index    ( ioctl_index ),
	.ioctl_wr       ( ioctl_wr ),
	.ioctl_addr     ( ioctl_addr ),
	.ioctl_dout     ( ioctl_dout )
);


wire [1:0] scanlines = status[13:12];
wire pal     = status[11];
wire swap    = status[1];
wire ecs     = status[9];
wire ivoice  =!status[10];
wire [3:0] mapp    = status[8:5];
wire [1:0] format  = status[23:22];

wire [7:0] CORE_R,CORE_G,CORE_B;
wire       CORE_HS,CORE_VS,CORE_DE,CORE_CE;
wire       CORE_HBLANK,CORE_VBLANK;
wire CLK_VIDEO;
   
wire [15:0] laud,raud;

wire cart_download = ioctl_download && ioctl_index[5:0]==5'b1 ? 1'b1 : 1'b0;
wire cart_req, cart_ack;
wire cart_stb;
wire [15:0] cart_addr;
wire [15:0] cart_dout;

wire rom_download = ioctl_download && ioctl_index[5:0]==5'b0 ? 1'b1 : 1'b0;
wire rom_req, rom_ack;
wire rom_stb;
wire [15:0] rom_addr;
wire [15:0] rom_dout;

intv_core intv_core
(
    .clksys(clk_sys),
    .pll_locked(pll_locked),
    .pal(pal),
    .swap(swap),
    .ecs(ecs),
    .ivoice(ivoice),
    .mapp(mapp),
    .format(format),
    .reset(status[0]),
    .vga_clk(CLK_VIDEO),
    .vga_ce(CORE_CE),
    .vga_r(CORE_R),
    .vga_g(CORE_G),
    .vga_b(CORE_B),
    .vga_hs(CORE_HS),
    .vga_vs(CORE_VS),
    .vga_de(CORE_DE),
    .vga_vb(CORE_VBLANK),
    .vga_hb(CORE_HBLANK),
    .joystick_0(js0),
    .joystick_1(js1),
    .joystick_analog_0(ja0),
    .joystick_analog_1(ja1),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_wait(ioctl_wait),
    .ps2_key({ps2_key_stb,ps2_key_pressed,ps2_key_ext,ps2_key}),
    .audio_l(laud),
    .audio_r(raud),
	 .cart_addr(cart_addr),
	 .cart_stb(cart_stb),
	 .cart_in(cart_dout),
	 .rom_addr(rom_addr),
	 .rom_stb(rom_stb),
	 .rom_in(rom_dout)
);

wire sdram_drive_dq;
wire [15:0] sdram_dq_in,sdram_dq_out;

assign SDRAM_DQ = sdram_drive_dq ? sdram_dq_out : {16{1'bz}};
assign sdram_dq_in = SDRAM_DQ;

always @(posedge clk_sys) begin
	if ((rom_stb && !ioctl_download) || (rom_download && ioctl_wr))
		rom_req<=~rom_ack;
	if ((cart_stb && !ioctl_download) || (cart_download && ioctl_wr))
		cart_req<=~cart_ack;
end

assign SDRAM_CKE=1'b1;

sdram_amr #(.SDRAM_tCK(23800)) sdram (
	.SDRAM_DRIVE_DQ(sdram_drive_dq),
	.SDRAM_DQ_IN(sdram_dq_in),
	.SDRAM_DQ_OUT(sdram_dq_out),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nWE(SDRAM_nWE),
	
	// cpu/chipset interface
	.init_n(pll_locked),
	.clk(clk_sys),
	.clkref(1'b0),
	.sync_en(1'b0),

	.rom_addr(rom_download ? ioctl_addr[21:0] : {rom_addr,1'b0}),
	.rom_dout(rom_dout),
	.rom_din (ioctl_dout),
	.rom_req (rom_req),
	.rom_ack (rom_ack),
	.rom_we (rom_download),

	.cart_addr(cart_download ? ioctl_addr[21:0] : {cart_addr,1'b0}),
	.cart_dout(cart_dout),
	.cart_din (ioctl_dout),
	.cart_req (cart_req),
	.cart_ack (cart_ack),
	.cart_we (cart_download),
);


dac #(.C_bits(16)) ldac (
	.clk_i(clk_sys),
	.res_n_i(pll_locked),
	.dac_i(laud),
	.dac_o(AUDIO_L)
);

dac #(.C_bits(16)) rdac (
	.clk_i(clk_sys),
	.res_n_i(pll_locked),
	.dac_i(raud),
	.dac_o(AUDIO_R)
);


mist_video #(.COLOR_DEPTH(6), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(10), .OSD_AUTO_CE(0)) mist_video (
	.clk_sys     ( clk_sys    ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( scanlines  ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b0       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( tv15khz ),
	// disable csync without scandoubler
	.no_csync    ( 1'b0 ),
	// YPbPr always uses composite sync
	.ypbpr       ( 1'b0 ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( CORE_DE ? CORE_R[7:2] : 6'b0 ),
	.G           ( CORE_DE ? CORE_G[7:2] : 6'b0 ),
	.B           ( CORE_DE ? CORE_B[7:2] : 6'b0 ),
	.HSync       ( CORE_HS ),
	.VSync       ( CORE_VS ),

	// MiST video output signals
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);


pll pll (
	.inclk0(CLOCK_27),
	.c0(clk_sys),
	.c1(SDRAM_CLK),
	.locked(pll_locked)
);

//pll pll
//(
//    .refclk(CLK_50M),
//    .reconfig_to_pll(reconfig_to_pll),
//    .reconfig_from_pll(reconfig_from_pll),
//    .locked(pll_locked),
//    .outclk_0(clk_sys)
//);
//
//wire [63:0] reconfig_to_pll;
//wire [63:0] reconfig_from_pll;
//wire        cfg_waitrequest;
//reg         cfg_write;
//reg   [5:0] cfg_address;
//reg   [31:0] cfg_data;
//
//pll_cfg pll_cfg
//(
//    .mgmt_clk(CLK_50M),
//    .mgmt_reset(0),
//    .mgmt_waitrequest(cfg_waitrequest),
//    .mgmt_read(0),
//    .mgmt_readdata(),
//    .mgmt_write(cfg_write),
//    .mgmt_address(cfg_address),
//    .mgmt_writedata(cfg_data),
//    .reconfig_to_pll(reconfig_to_pll),
//    .reconfig_from_pll(reconfig_from_pll)
//);
//
//
//// NTSC : 3.579545MHz *  12 =  42.95454MHz
//// PAL  : 4MHz        *  12 =  48MHz
//  
//// STIC : CLK * 12
//// IVOICE : CLK
//  
//reg tv_reset = 0;
//always @(posedge CLK_50M) begin
//    reg pald = 0, pald2 = 0;
//    reg [2:0] state = 0;
//
//    pald  <= pal;
//    pald2 <= pald;
//
//    cfg_write <= 0;
//    if(pald2 != pald) state <= 1;
//
//    if(!cfg_waitrequest) begin
//        if(state) state<=state+1'd1;
//        case(state)
//               0: tv_reset <= 0;
//               1: begin
//                         tv_reset <= 1;
//                         cfg_address <= 0; // Waitrequest mode
//                         cfg_data <= 0;
//                         cfg_write <= 1;
//                    end
//               2: begin
//                         cfg_address <= 3; // N counter
//                         cfg_data <= 32'h00010000;
//                         cfg_write <= 1;
//                    end
//               3: begin
//                         cfg_address <= 4; // M counter
//                         cfg_data <= 32'h00000404;
//                         cfg_write <= 1;
//                    end
//               4: begin
//                         cfg_address <= 5; // C0 counter
//                         cfg_data <= pald2 ? 32'h00020504 : 32'h00000505;
//                         cfg_write <= 1;
//                    end
//               5: begin
//                         cfg_address <= 7; // M frac
//                         cfg_data <= pald2 ? 32'hA3D709E8 : 32'h9745BF27;
//                         cfg_write <= 1;
//                    end
//               6: begin
//                         cfg_address <= 2; // Start reconf
//                         cfg_data <= 0;
//                         cfg_write <= 1;
//                    end
//          endcase
//     end
//end

endmodule
