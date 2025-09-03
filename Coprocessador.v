module Coprocessador (
    input           CLOCK_50,
    input   [3:0]   KEY,
    input   [3:0]   SW,
    output          VGA_CLK,
    output          VGA_HS,
    output          VGA_VS,
    output          VGA_BLANK_N,
    output  [7:0]   VGA_R,
    output  [7:0]   VGA_G,
    output  [7:0]   VGA_B,
    output  [6:0]   HEX0,
    output  [6:0]   HEX1,
    output  [6:0]   HEX2,
    output  [6:0]   HEX3,
    output  [6:0]   HEX4,
    output  [6:0]   HEX5
);

    // --- Sinais de Controlo ---
    wire reset = !KEY[0];
    wire zoom_in_press = !KEY[2];
    wire zoom_out_press = !KEY[3];

    // --- LÓGICA DE SELEÇÃO E ERRO DAS CHAVES ---
    reg [1:0] algorithm_select;
    wire multiple_switches_error;
    wire no_switch_selected_error;

    assign multiple_switches_error = (SW[0] + SW[1] + SW[2] + SW[3] > 1);
    assign no_switch_selected_error = (SW[3:0] == 4'b0000);

    always @(*) begin
        if (SW[0]) algorithm_select = 2'b00;
        else if (SW[1]) algorithm_select = 2'b01;
        else if (SW[2]) algorithm_select = 2'b10;
        else if (SW[3]) algorithm_select = 2'b11;
        else algorithm_select = 2'b00;
    end

    // Gera pulsos únicos para os botões de zoom - SINTAXE CORRIGIDA
    reg prev_zoom_in, prev_zoom_out;
    wire zoom_in_pulse, zoom_out_pulse;

    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            prev_zoom_in <= 1'b0; 
            prev_zoom_out <= 1'b0;
        end else begin
            prev_zoom_in <= zoom_in_press; 
            prev_zoom_out <= zoom_out_press;
        end
    end
    assign zoom_in_pulse = zoom_in_press & ~prev_zoom_in;
    assign zoom_out_pulse = zoom_out_press & ~prev_zoom_out;

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

    // --- Instanciação dos Módulos ---
    Controller main_fsm (
        .clk(CLOCK_50), .reset(reset),
        .zoom_in(zoom_in_pulse), .zoom_out(zoom_out_pulse),
        .algorithm_select(algorithm_select),
        .multiple_switches_error(multiple_switches_error),
        .no_switch_selected_error(no_switch_selected_error),
        .done(processing_finished), .enable(enable_processing), .wren(wren_from_controller),
        .zoom_level(zoom_level),
        .invalid_zoom_error(invalid_zoom_error)
    );

    localparam IMG_WIDTH = 160;
    ImgRom rom0 (.clock(CLOCK_50), .address(base_read_addr), .q(pixel_from_rom_p0));
    ImgRom rom1 (.clock(CLOCK_50), .address(base_read_addr + 1), .q(pixel_from_rom_p1));
    ImgRom rom2 (.clock(CLOCK_50), .address(base_read_addr + IMG_WIDTH), .q(pixel_from_rom_p2));
    ImgRom rom3 (.clock(CLOCK_50), .address(base_read_addr + IMG_WIDTH + 1), .q(pixel_from_rom_p3));

    ZoomSelection resizer (
        .clk(CLOCK_50), .enable(enable_processing), .algorithm_select(algorithm_select),
        .zoom_level(zoom_level),
        .pixel_in_p0(pixel_from_rom_p0), .pixel_in_p1(pixel_from_rom_p1), .pixel_in_p2(pixel_from_rom_p2), .pixel_in_p3(pixel_from_rom_p3),
        .pixel_out(pixel_out_from_resizer), .base_read_addr(base_read_addr), .write_addr(write_addr), .done(processing_finished)
    );

    VdRam frame_buffer (.clock(CLOCK_50), .wren(wren_from_controller), .wraddress(write_addr), .data(pixel_out_from_resizer), .rdaddress(vga_read_addr), .q(vga_pixel_data));
    VGAController vga_inst (.pclk(CLOCK_50), .reset(reset), .h_sync(VGA_HS), .v_sync(VGA_VS), .video_on(VGA_BLANK_N), .read_addr(vga_read_addr));

    Informations scrolling_display (
        .clk(CLOCK_50), .reset(reset), .algorithm_select(algorithm_select),
        .invalid_zoom_error(invalid_zoom_error),
        .multiple_switches_error(multiple_switches_error),
        .no_switch_selected_error(no_switch_selected_error),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5)
    );

    // --- Lógica de Saída VGA ---
    assign VGA_CLK = CLOCK_50;
    assign VGA_R = VGA_BLANK_N ? vga_pixel_data : 8'h00;
    assign VGA_G = VGA_BLANK_N ? vga_pixel_data : 8'h00;
    assign VGA_B = VGA_BLANK_N ? vga_pixel_data : 8'h00;

endmodule