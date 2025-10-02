//Novas alterações devem ser feitas para que ele fique adapitavel para o segundo projeto
//Nova configurações devem ser geradas usa o Qsys (HPS)
//Nova memoria deve ser criada para armazenar a imagem, a nova memoria deve ser uma RAM para ter
//a possibilidade de mudar de imagens

module Coprocessador (
    // Clock principal da FPGA
    input           CLOCK_50,

    // --- Saídas Físicas (VGA, Display) ---
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
    output  [6:0]   HEX5,

    // --- NOVA INTERFACE PARA O HPS QUE SERA GERADA PELO(Qsys)
    input           hps_clk,
    input           hps_reset,
    input   [1:0]   hps_address_control,
    input           hps_chipselect_control,
    input           hps_write_control,
    input           hps_read_control,
    input   [31:0]  hps_writedata_control,
    output  [31:0]  hps_readdata_control,
    // (Interface semelhante para a ImgRam)
    input   [14:0]  hps_address_img,
    input           hps_chipselect_img,
    input           hps_write_img,
    input   [7:0]   hps_writedata_img
);

    // --- Fios de Ligação ---
    wire enable_processing, processing_finished, wren_from_controller;
    wire [14:0] read_addr_to_ram;
    wire [18:0] write_addr;
    wire [7:0] pixel_out_from_processor, pixel_in_to_processor;
    wire [18:0] vga_read_addr;
    wire [7:0] vga_pixel_data;
    wire [2:0] zoom_level;
    wire [1:0] algorithm_select;
    wire start_pulse;
    wire processing_has_run_once;
    
    // --- LÓGICA DE DETEÇÃO DE ESCRITA DO HPS ---
    wire hps_is_writing = hps_chipselect_img && hps_write_img;

    // Fios para a arquitetura VGA
    wire vga_clk_25mhz;
	 wire [9:0] vga_next_x, vga_next_y, is_image_area;
    wire [7:0] color_to_driver;
    wire vga_sync_dummy;
	 wire [2:0] vga_display_zoom_level;

    // --- Geração do Clock de 25MHz ---
    reg clk_div_reg = 0;
    always @(posedge CLOCK_50) clk_div_reg <= ~clk_div_reg;
    assign vga_clk_25mhz = clk_div_reg;

    // --- Instanciação dos Módulos ---

    // 1. Módulo de Registadores API (Interface com o HPS)
    RegisterController control_regs (
        .clk(hps_clk), .reset(hps_reset), .address(hps_address_control),
        .chipselect(hps_chipselect_control), .write(hps_write_control), .read(hps_read_control),
        .writedata(hps_writedata_control), .readdata(hps_readdata_control),

        .algorithm_select_out(algorithm_select),
        .zoom_level_out(zoom_level),
        .start_pulse_out(start_pulse),

        .processing_done_in(processing_finished)
    );

    // 2. O Controller (FSM) agora sabe quando o HPS está a escrever
    Controller main_fsm (
        .clk(CLOCK_50), 
        .reset(hps_reset), 
        .start(start_pulse),
        .hps_writing_image(hps_is_writing), 
        .done(processing_finished), 
        .enable(enable_processing), 
        .wren(wren_from_controller), 
        .processing_has_run_once(processing_has_run_once)
    );

    // 3. Memória da Imagem (Agora é uma RAM)
    ImgRam processing_ram (
        .clock(CLOCK_50), 
        // Porta de Leitura (para o ImageProcessor)
        .rdaddress(read_addr_to_ram), 
        .q(pixel_in_to_processor),

        // Porta de Escrita (para o HPS)
        .wraddress(hps_address_img),
        .data(hps_writedata_img),
        .wren(hps_is_writing)
    );
	 
    // 4. Processador de Imagem
    ImageProcessor processor (.clk(CLOCK_50), .enable(enable_processing), .algorithm_select(algorithm_select), .zoom_level(zoom_level), .pixel_in_from_rom(pixel_in_to_processor), .read_addr(read_addr_to_ram), .pixel_out_to_ram(pixel_out_from_processor), .write_addr(write_addr), .done(processing_finished));
    
    // 5. Memória de Vídeo (Frame Buffer)
    VdRam frame_buffer (.clock(CLOCK_50), .wren(wren_from_controller), .wraddress(write_addr), .data(pixel_out_from_processor), .rdaddress(vga_read_addr), .q(vga_pixel_data));
    
    // 6. Arquitetura de Exibição VGA
    assign vga_display_zoom_level = processing_has_run_once ? zoom_level : 3'd2;
    VGAController vga_logic_inst (.pclk(CLOCK_50), .reset(hps_reset), .zoom_level(vga_display_zoom_level), .current_x(vga_next_x), .current_y(vga_next_y), .is_image_area(is_image_area), .read_addr(vga_read_addr));
    
    assign color_to_driver = is_image_area ? vga_pixel_data : 8'h00;  
    VGA_Driver the_vga_driver (.clock(vga_clk_25mhz), .reset(hps_reset), .color_in(color_to_driver), .next_x(vga_next_x), .next_y(vga_next_y), .hsync(VGA_HS), .vsync(VGA_VS), .red(VGA_R), .green(VGA_G), .blue(VGA_B), .sync(vga_sync_dummy), .clk(VGA_CLK), .blank(VGA_BLANK_N));
    
    // 7. Driver do Display (Agora não mostra mais erros de validação)
    Informations scrolling_display (.clk(CLOCK_50), .reset(hps_reset), .algorithm_select(algorithm_select), .invalid_zoom_error(1'b0), .multiple_switches_error(1'b0), .no_switch_selected_error(1'b0), .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5));

endmodule