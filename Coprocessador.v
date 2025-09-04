module Coprocessador (
    CLOCK_50, KEY, SW,
    VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N,
    VGA_R, VGA_G, VGA_B,
    HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);
    // --- Entradas e Saídas ---
    input           CLOCK_50;
    input   [3:0]   KEY;
    input   [3:0]   SW;
    output          VGA_CLK;
    output          VGA_HS;
    output          VGA_VS;
    output          VGA_BLANK_N;
    output  [7:0]   VGA_R;
    output  [7:0]   VGA_G;
    output  [7:0]   VGA_B;
    output  [6:0]   HEX0;
    output  [6:0]   HEX1;
    output  [6:0]   HEX2;
    output  [6:0]   HEX3;
    output  [6:0]   HEX4;
    output  [6:0]   HEX5;

    // --- Sinais de Controlo ---
    wire reset = !KEY[0];
    wire return_press = !KEY[1];
    wire zoom_in_press = !KEY[2];
    wire zoom_out_press = !KEY[3];
    reg [1:0] algorithm_select;
    wire multiple_switches_error, no_switch_selected_error;

    assign multiple_switches_error = (SW[0] + SW[1] + SW[2] + SW[3] > 1);
    assign no_switch_selected_error = (SW[3:0] == 4'b0000);

    always @(*) begin
        if (SW[0]) algorithm_select = 2'b00;
        else if (SW[1]) algorithm_select = 2'b01;
        else if (SW[2]) algorithm_select = 2'b10;
        else if (SW[3]) algorithm_select = 2'b11;
        else algorithm_select = 2'b00;
    end

    reg prev_zoom_in, prev_zoom_out, prev_return;
    wire zoom_in_pulse, zoom_out_pulse, return_pulse;
    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            prev_zoom_in <= 1'b0;
            prev_zoom_out <= 1'b0;
            prev_return <= 1'b0;
        end else begin
            prev_zoom_in <= zoom_in_press;
            prev_zoom_out <= zoom_out_press;
            prev_return <= return_press;
        end
    end
    assign zoom_in_pulse = zoom_in_press & ~prev_zoom_in;
    assign zoom_out_pulse = zoom_out_press & ~prev_zoom_out;
    assign return_pulse = return_press & ~prev_return;

    // --- Fios de Ligação ---
    wire enable_processing, processing_finished, wren_from_controller;
    wire [14:0] base_read_addr;
    wire [16:0] write_addr;
    wire [7:0] pixel_out_from_resizer;
    wire [7:0] pixel_from_rom_p0, pixel_from_rom_p1, pixel_from_rom_p2, pixel_from_rom_p3;
    wire [16:0] vga_read_addr;
    wire [7:0] vga_pixel_data;
    wire [2:0] zoom_level;
    wire invalid_zoom_error;
    wire processing_has_run_once;
    
    // --- FIOS PARA A ARQUITETURA VGA (SINTAXE CORRIGIDA) ---
    wire vga_clk_25mhz;
    wire [9:0] vga_next_x, vga_next_y;
    wire is_image_area;
    wire [7:0] color_to_driver, pixel_from_rom_for_vga;
    wire vga_sync_dummy;
    wire [2:0] vga_display_zoom_level;

    // --- Geração do Clock de 25MHz ---
    reg clk_div_reg = 0;
    always @(posedge CLOCK_50) clk_div_reg <= ~clk_div_reg;
    assign vga_clk_25mhz = clk_div_reg;

    // --- Instanciação dos Módulos ---
    Controller main_fsm (.clk(CLOCK_50), .reset(reset), .zoom_in(zoom_in_pulse), .zoom_out(zoom_out_pulse), .return_to_previous(return_pulse), .algorithm_select(algorithm_select), .multiple_switches_error(multiple_switches_error), .no_switch_selected_error(no_switch_selected_error), .done(processing_finished), .enable(enable_processing), .wren(wren_from_controller), .zoom_level(zoom_level), .invalid_zoom_error(invalid_zoom_error), .processing_has_run_once(processing_has_run_once));

    localparam IMG_WIDTH = 160;
    ImgRom rom0 (.clock(CLOCK_50), .address(base_read_addr), .q(pixel_from_rom_p0));
    ImgRom rom1 (.clock(CLOCK_50), .address(base_read_addr + 1), .q(pixel_from_rom_p1));
    ImgRom rom2 (.clock(CLOCK_50), .address(base_read_addr + IMG_WIDTH), .q(pixel_from_rom_p2));
    ImgRom rom3 (.clock(CLOCK_50), .address(base_read_addr + IMG_WIDTH + 1), .q(pixel_from_rom_p3));
    ImgRom vga_rom_reader (.clock(CLOCK_50), .address(vga_read_addr[14:0]), .q(pixel_from_rom_for_vga));

    ZoomSelection resizer (.clk(CLOCK_50), .enable(enable_processing), .algorithm_select(algorithm_select), .zoom_level(zoom_level), .pixel_in_p0(pixel_from_rom_p0), .pixel_in_p1(pixel_from_rom_p1), .pixel_in_p2(pixel_from_rom_p2), .pixel_in_p3(pixel_from_rom_p3), .pixel_out(pixel_out_from_resizer), .base_read_addr(base_read_addr), .write_addr(write_addr), .done(processing_finished));

    VdRam frame_buffer (.clock(CLOCK_50), .wren(wren_from_controller), .wraddress(write_addr), .data(pixel_out_from_resizer), .rdaddress(vga_read_addr), .q(vga_pixel_data));

    assign vga_display_zoom_level = processing_has_run_once ? zoom_level : 3'd2;
    VGAController vga_logic_inst (.pclk(CLOCK_50), .reset(reset), .zoom_level(vga_display_zoom_level), .current_x(vga_next_x), .current_y(vga_next_y), .is_image_area(is_image_area), .read_addr(vga_read_addr));

    wire [7:0] display_pixel = processing_has_run_once ? vga_pixel_data : pixel_from_rom_for_vga;
    assign color_to_driver = is_image_area ? display_pixel : 8'h00;

    VGA_Driver the_vga_driver (.clock(vga_clk_25mhz), .reset(reset), .color_in(color_to_driver), .next_x(vga_next_x), .next_y(vga_next_y), .hsync(VGA_HS), .vsync(VGA_VS), .red(VGA_R), .green(VGA_G), .blue(VGA_B), .sync(vga_sync_dummy), .clk(VGA_CLK), .blank(VGA_BLANK_N));

    Informations scrolling_display (.clk(CLOCK_50), .reset(reset), .algorithm_select(algorithm_select), .invalid_zoom_error(invalid_zoom_error), .multiple_switches_error(multiple_switches_error), .no_switch_selected_error(no_switch_selected_error), .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5));

endmodule