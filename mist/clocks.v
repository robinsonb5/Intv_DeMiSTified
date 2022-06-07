// Clocking for Cyclone III / IV / 10LP / MAX10 targets

module clocks (
	input clk_i,
	input pal,
	output clk_sys,
	output clk_sdram,
	output locked
);

pll pll (
    .inclk0(clk_i),
    .c0(clk_sys),
    .c1(clk_sdram),
    .areset(pll_areset),
    .scanclk(pll_scanclk),
    .scandata(pll_scandata),
    .scanclkena(pll_scanclkena),
    .configupdate(pll_configupdate),
    .scandataout(pll_scandataout),
    .scandone(pll_scandone),
    .locked(locked)
);

reg ntsc=1'b0;
reg [23:0] debounce;
reg pal_d3=1'b0;
reg pal_d2=1'b0;
reg pal_d=1'b0;

always @(posedge clk_i) begin
	pal_d3<=pal;
	pal_d2<=pal_d3;
	pal_d<=pal_d2;
	
	if(pal_d2 != pal_d)
		debounce<=1'b0;
	else if(&debounce)
		ntsc<=~pal_d;
	else
		debounce<=debounce+1'b1;

end

wire       pll_reconfig_busy;
wire       pll_areset;
wire       pll_configupdate;
wire       pll_scanclk;
wire       pll_scanclkena;
wire       pll_scandata;
wire       pll_scandataout;
wire       pll_scandone;
reg        pll_reconfig_reset;
wire [7:0] pll_rom_address;
wire       pll_rom_q;
reg        pll_write_from_rom;
wire       pll_write_rom_ena;
reg        pll_reconfig;
wire       q_reconfig_ntsc;
wire       q_reconfig_pal;

rom_reconfig_pal rom_reconfig_pal
(
    .address(pll_rom_address),
    .clock(clk_i),
    .rden(pll_write_rom_ena),
    .q(q_reconfig_pal)
);

rom_reconfig_ntsc rom_reconfig_ntsc
(
    .address(pll_rom_address),
    .clock(clk_i),
    .rden(pll_write_rom_ena),
    .q(q_reconfig_ntsc)
);

assign pll_rom_q = ntsc ? q_reconfig_ntsc : q_reconfig_pal;

pll_reconfig pll_reconfig_inst
(
    .busy(pll_reconfig_busy),
    .clock(clk_i),
    .counter_param(0),
    .counter_type(0),
    .data_in(0),
    .pll_areset(pll_areset),
    .pll_areset_in(0),
    .pll_configupdate(pll_configupdate),
    .pll_scanclk(pll_scanclk),
    .pll_scanclkena(pll_scanclkena),
    .pll_scandata(pll_scandata),
    .pll_scandataout(pll_scandataout),
    .pll_scandone(pll_scandone),
    .read_param(0),
    .reconfig(pll_reconfig),
    .reset(pll_reconfig_reset),
    .reset_rom_address(0),
    .rom_address_out(pll_rom_address),
    .rom_data_in(pll_rom_q),
    .write_from_rom(pll_write_from_rom),
    .write_param(0),
    .write_rom_ena(pll_write_rom_ena)
);

always @(posedge clk_i) begin
    reg ntsc_d, ntsc_d2, ntsc_d3;
    reg [1:0] pll_reconfig_state = 0;
    reg [9:0] pll_reconfig_timeout;

    ntsc_d <= ntsc;
    ntsc_d2 <= ntsc_d;
    pll_write_from_rom <= 0;
    pll_reconfig <= 0;
    pll_reconfig_reset <= 0;
    case (pll_reconfig_state)
    2'b00:
    begin
        ntsc_d3 <= ntsc_d2;
        if (ntsc_d2 ^ ntsc_d3) begin
            pll_write_from_rom <= 1;
            pll_reconfig_state <= 2'b01;
        end
    end
    2'b01: pll_reconfig_state <= 2'b10;
    2'b10:
        if (~pll_reconfig_busy) begin
            pll_reconfig <= 1;
            pll_reconfig_state <= 2'b11;
            pll_reconfig_timeout <= 10'd1000;
        end
    2'b11:
    begin
        pll_reconfig_timeout <= pll_reconfig_timeout - 1'd1;
        if (pll_reconfig_timeout == 10'd1) begin
            // pll_reconfig stuck in busy state
            pll_reconfig_reset <= 1;
            pll_reconfig_state <= 2'b00;
        end
        if (~pll_reconfig & ~pll_reconfig_busy) pll_reconfig_state <= 2'b00;
    end
    default: ;
    endcase
end

endmodule

