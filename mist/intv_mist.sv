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
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
`ifdef DEMISTIFY_HDMI
	output        VGA_CLK,
	output        VGA_WINDOW,
`endif

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

`ifdef DEMISTIFY
	input  [11:0] keypad,
	input  [15:0] SDRAM_DQ_IN,
	output [15:0] SDRAM_DQ_OUT,
	output        SDRAM_DRIVE_DQ,
`endif
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
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
`ifdef USE_MIDI_PINS
	input         MIDI_IN,
	output        MIDI_OUT,
`endif
	input         UART_RX,
	output        UART_TX

);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

`ifdef USE_AUDIO_IN
localparam bit USE_AUDIO_IN = 1;
`else
localparam bit USE_AUDIO_IN = 0;
`endif

`ifdef USE_MIDI_PINS
localparam bit USE_MIDI_PINS = 1;
`else
localparam bit USE_MIDI_PINS = 0;
`endif

// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 1;
assign SDRAM2_DQMH = 1;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif

`include "build_id.v"

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
    "P1OMN,Format,Auto,Raw,Intellicart;",
    "P1,System;",
    "P1O9,ECS,Off,On;",
    "P1OA,Voice,On,Off;",
    "P1O58,MAP,Auto,0,1,2,3,4,5,6,7,8,9;",
    "P2,Video;",
    "P2OB,Video standard,NTSC,PAL;",
    "P2OCD,Scanlines,Off,25%,50%,75%;",
    "P2OE,Composite blend,Off,On;",
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

wire ypbpr;
wire nocsync;

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

// include user_io module for arm controller communication
user_io #(
	.STRLEN(($size(CONF_STR)>>3)),
	.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD),
	.FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))
	)
user_io(
	.conf_str       ( CONF_STR       ),

	.clk_sys        ( clk_sys        ),

	.SPI_CLK        ( SPI_SCK        ),
	.SPI_SS_IO      ( CONF_DATA0     ),
	.SPI_MISO       ( SPI_DO         ),
	.SPI_MOSI       ( SPI_DI         ),

	.scandoubler_disable ( tv15khz   ),
	.ypbpr          ( ypbpr ),
	.no_csync       ( nocsync ),
	.buttons        ( buttons        ),

	.joystick_0     ( js0            ),
	.joystick_1     ( js1            ),
	.joystick_analog_0 ( ja0            ),
	.joystick_analog_1 ( ja1            ),

	.status         ( status        ),
`ifdef USE_HDMI
	.i2c_start      (i2c_start      ),
	.i2c_read       (i2c_read       ),
	.i2c_addr       (i2c_addr       ),
	.i2c_subaddr    (i2c_subaddr    ),
	.i2c_dout       (i2c_dout       ),
	.i2c_din        (i2c_din        ),
	.i2c_ack        (i2c_ack        ),
	.i2c_end        (i2c_end        ),
`endif
	.key_pressed    (ps2_key_pressed ),
	.key_extended   (ps2_key_ext),
	.key_code       (ps2_key),
	.key_strobe     (ps2_key_stb)
);

assign LED = ~ioctl_download;

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
wire blend = status[14];
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

`ifdef DEMISTIFY
reg [11:0] keypad_d2,keypad_d;
always @(posedge clk_sys) begin
	keypad_d2 <= keypad;
	keypad_d <= keypad_d2;
end
`else
wire [11:0]	keypad_d = 12'b0;
`endif

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
    .joystick_analog_0({ja0[7:0],ja0[15:8]}),
    .joystick_analog_1({ja1[7:0],ja1[15:8]}),
    .keypad(keypad_d),
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

`ifdef YOSYS
assign SDRAM_DQ_OUT = sdram_dq_out;
assign sdram_dq_in = SDRAM_DQ_IN;
assign SDRAM_DRIVE_DQ = sdram_drive_dq;
`else

assign SDRAM_DQ = sdram_drive_dq ? sdram_dq_out : {16{1'bz}};
assign sdram_dq_in = SDRAM_DQ;
`endif

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
	.cart_we (cart_download)
);


// DAC takes unsigned values; audio is 16-bit signed so invert the first bit.

dacwrap dac (
	.clk(clk_sys),
	.reset_n(pll_locked),
	.d_l({~laud[15],laud[14:0]}),
	.d_r({~raud[15],raud[14:0]}),
	.q_l(AUDIO_L),
	.q_r(AUDIO_R)
);

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(pal ? 32'd48_000_000 : 32'd42_954_540),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(laud),
	.right_chan(raud)
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_sys),
	.rst_i(1'b0),
	.clk_rate_i(pal ? 32'd48_000_000 : 32'd42_954_540),
	.spdif_o(SPDIF),
	.sample_i({raud, laud})
);
`endif

mist_video #(.COLOR_DEPTH(8), .OUT_COLOR_DEPTH(VGA_BITS), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(10), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD)) mist_video (
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
	.no_csync    ( nocsync ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( blend      ),

	// video in
	.R           ( CORE_R ),
	.G           ( CORE_G ),
	.B           ( CORE_B ),
	.HSync       ( CORE_HS ),
	.VSync       ( CORE_VS ),
	.HBlank      ( CORE_HBLANK ),
	.VBlank      ( CORE_VBLANK ),

	// MiST video output signals
`ifdef DEMISTIFY_HDMI
	.VGA_DE      ( VGA_WINDOW ),
`endif
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);

wire clk_vid;

clocks clocks (
	.clk_i(CLOCK_27),
	.pal(pal),
	.clk_sys(clk_sys),
	.clk_sdram(SDRAM_CLK),
`ifdef DEMISTIFY_HDMI
	.clk_video(VGA_CLK),
`endif
	.locked(pll_locked)
);

`ifdef USE_HDMI
i2c_master #(10_000_000) i2c_master (
	.CLK         (clk_sys),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.COLOR_DEPTH(8), .SD_HCNT_WIDTH(10), .USE_BLANKS(1), .OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1)) hdmi_video(
	.clk_sys        ( clk_sys          ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	// video in
	.R              ( CORE_R           ),
	.G              ( CORE_G           ),
	.B              ( CORE_B           ),
	.HSync          ( CORE_HS          ),
	.VSync          ( CORE_VS          ),
	.HBlank         ( CORE_HBLANK      ),
	.VBlank         ( CORE_VBLANK      ),
	.VGA_R          ( HDMI_R           ),
	.VGA_G          ( HDMI_G           ),
	.VGA_B          ( HDMI_B           ),
	.VGA_VS         ( HDMI_VS          ),
	.VGA_HS         ( HDMI_HS          ),
	.VGA_DE         ( HDMI_DE          ),
	.scandoubler_disable( 1'b0         ),
	.scanlines      ( scanlines        ),
	.blend          ( blend            ),
	.ypbpr          ( 1'b0             ),
	.no_csync       ( 1'b1             )
	);

assign HDMI_PCLK = clk_sys;
`endif

endmodule
