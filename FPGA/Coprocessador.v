module Coprocessador (
    // Clock principal da FPGA
    input           CLOCK_50,

    // --- Saídas Físicas (VGA, Display) ---
    output          VGA_CLK,
    output          VGA_HS,
    output          VGA_VS,
    output          VGA_BLANK_N,
    output [7:0]    VGA_R,
    output [7:0]    VGA_G,
    output [7:0]    VGA_B,
    output [6:0]    HEX0,
    output [6:0]    HEX1,
    output [6:0]    HEX2,
    output [6:0]    HEX3,
    output [6:0]    HEX4,
    output [6:0]    HEX5,

    // <<< NOVA SAÍDA PARA DEBUG >>>
    output [9:0]    LEDR,            // LEDs para depuração

    // --- NOVA INTERFACE DE 3 PIOs (UNIDIRECIONAL) ---
    input  [31:0] PIO_CONTROL_IN,    // HPS -> FPGA: Sinais de controlo e endereço
    input  [31:0] PIO_DATA_IN,       // HPS -> FPGA: Dados de escrita
    output [31:0] PIO_DATA_OUT       // FPGA -> HPS: Status e dados de leitura
);

    // --- DECODIFICAÇÃO DOS PIOs UNIDIRECIONAIS ---
    
    // --- Entradas do HPS ---
    // PIO_CONTROL_IN [31:0] O primeiro pio estava negado
    wire hps_reset              =  ~PIO_CONTROL_IN[31];      // bit 31: reset ativo baixo
    wire [14:0] hps_address_img =  PIO_CONTROL_IN[14:0];   // bits 14:0: endereço da ImgRam
    
    // <<< NOVOS SINAIS DE HANDSHAKE (Activate) >>>
    wire hps_activate_img_write =  PIO_CONTROL_IN[10];     // bit 10: HPS pede escrita na ImgRam
    wire hps_activate_reg_write =  PIO_CONTROL_IN[5];      // bit 5:  HPS pede escrita no Registo

    // Sinais antigos (agora ignorados, substituídos pelo handshake)
    wire hps_write_img          =  PIO_CONTROL_IN[9];
    wire hps_chipselect_img     =  PIO_CONTROL_IN[8];
    wire hps_read_control       =  PIO_CONTROL_IN[4];
    wire hps_write_control      =  PIO_CONTROL_IN[3];
    wire hps_chipselect_control =  PIO_CONTROL_IN[2];
    
    wire [1:0] hps_address_control = PIO_CONTROL_IN[1:0];  // bits 1:0

    // PIO_DATA_IN [31:0]
    wire [31:0] hps_writedata_control = PIO_DATA_IN;        // Palavra completa de 32 bits
    wire [7:0] hps_writedata_img       = PIO_DATA_IN[7:0];   // Apenas os 8 bits inferiores para o pixel

    // Sinais de clock e de saída do RegisterController
    wire hps_clk = CLOCK_50;
    wire [31:0] hps_readdata_control; // saída do RegisterController

    // <<< NOVOS SINAIS DE HANDSHAKE (Acknowledge) >>>
    reg fpga_ack_img_write;
    reg fpga_ack_reg_write;


    // --- Saída para o HPS (MODIFICADA) ---
    assign PIO_DATA_OUT = hps_read_control ? hps_readdata_control : {
        16'h0000,                  // Reserved [31:16]
        zoom_level,                // [15:13] zoom atual
        algorithm_select,          // [12:11] algoritmo atual
        6'b000000,                 // Reserved [10:5]
        processing_has_run_once,   // [4] histórico de processamento
        processing_finished,       // [3] processamento finalizado (O sinal que o HPS espera)
        fpga_ack_reg_write,        // [2] <<< NOVO ACK para Registo
        fpga_ack_img_write,        // [1] <<< NOVO ACK para ImgRam
        1'b1                       // [0] sistema ativo
    };

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
    
    
    // <<< INÍCIO DA NOVA LÓGICA DE HANDSHAKE (Substitui o sincronizador antigo) >>>
    
    // Sinais internos para a lógica de escrita síncrona
    wire wren_img_ram;
    wire wren_reg_controller;
    
    // Registos para capturar (latch) os dados assíncronos do HPS
    reg [14:0] latched_address_img;
    reg [7:0]  latched_data_img;
    reg [1:0]  latched_address_control;
    reg [31:0] latched_writedata_control;

    // Sincronizadores para os sinais "Activate"
    reg  hps_activate_img_q, hps_activate_img_q2;
    reg  hps_activate_reg_q, hps_activate_reg_q2;
    
    // Detetores de Borda (para pulsos)
    wire img_write_request = hps_activate_img_q & ~hps_activate_img_q2; // Borda de subida
    wire img_write_release = ~hps_activate_img_q & hps_activate_img_q2; // Borda de descida
    wire reg_write_request = hps_activate_reg_q & ~hps_activate_reg_q2; // Borda de subida
    wire reg_write_release = ~hps_activate_reg_q & hps_activate_reg_q2; // Borda de descida

    // Lógica principal do Handshake
    always @(posedge CLOCK_50 or posedge hps_reset) begin
        if (hps_reset) begin
            // Sincronizadores
            hps_activate_img_q  <= 1'b0;
            hps_activate_img_q2 <= 1'b0;
            hps_activate_reg_q  <= 1'b0;
            hps_activate_reg_q2 <= 1'b0;
            
            // Sinais ACK
            fpga_ack_img_write <= 1'b0;
            fpga_ack_reg_write <= 1'b0;
            
            // Latches de dados (não estritamente necessário no reset, mas boa prática)
            latched_address_img <= 15'b0;
            latched_data_img    <= 8'b0;
            latched_address_control <= 2'b0;
            latched_writedata_control <= 32'b0;

        end else begin
            // 1. Sincronizar os sinais "Activate" do HPS
            hps_activate_img_q  <= hps_activate_img_write;
            hps_activate_img_q2 <= hps_activate_img_q;
            hps_activate_reg_q  <= hps_activate_reg_write;
            hps_activate_reg_q2 <= hps_activate_reg_q;

            // 2. Lógica de Handshake da ImgRam
            if (img_write_request) begin // HPS ativou (0 -> 1)
                latched_address_img <= hps_address_img; // Captura o endereço
                latched_data_img    <= hps_writedata_img;  // Captura o dado
                fpga_ack_img_write  <= 1'b1; // Envia o ACK
            end
            else if (img_write_release) begin // HPS desativou (1 -> 0)
                fpga_ack_img_write  <= 1'b0; // Baixa o ACK
            end

            // 3. Lógica de Handshake do RegisterController
            if (reg_write_request) begin // HPS ativou (0 -> 1)
                latched_address_control <= hps_address_control; // Captura o endereço
                latched_writedata_control <= hps_writedata_control; // Captura o dado
                fpga_ack_reg_write  <= 1'b1; // Envia o ACK
            end
            else if (reg_write_release) begin // HPS desativou (1 -> 0)
                fpga_ack_reg_write  <= 1'b0; // Baixa o ACK
            end
        end
    end

    // 4. Gerar os pulsos de escrita síncronos de 1 ciclo para os módulos internos
    // O 'wren' só é '1' por um ciclo, APÓS o pedido do HPS.
    assign wren_img_ram = img_write_request;
    assign wren_reg_controller = reg_write_request;

    // <<< FIM DA NOVA LÓGICA DE HANDSHAKE >>>


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

    
    // --- Instanciação dos Módulos (MODIFICADA) ---

    // 1. Módulo de Registadores API (agora usa dados e controlo síncronos)
    RegisterController control_regs (
        .clk(hps_clk), .reset(hps_reset), 
        .address(latched_address_control),     // <<< MODIFICADO (usa dado capturado)
        .chipselect(wren_reg_controller),    // <<< MODIFICADO (usa pulso síncrono)
        .write(wren_reg_controller),         // <<< MODIFICADO (usa pulso síncrono)
        .read(hps_read_control),             // (A leitura não foi alterada)
        .writedata(latched_writedata_control), // <<< MODIFICADO (usa dado capturado)
        .readdata(hps_readdata_control),
        .algorithm_select_out(algorithm_select),
        .zoom_level_out(zoom_level),
        .start_pulse_out(start_pulse), 
        .processing_done_in(processing_finished)
    );

    // 2. O Controller (FSM)
    Controller main_fsm (
        .clk(CLOCK_50), 
        .reset(hps_reset), 
        .start(start_pulse), 
        .hps_writing_image(wren_img_ram),  // <<< MODIFICADO (usa pulso síncrono)
        .done(processing_finished), 
        .enable(enable_processing), 
        .wren(wren_from_controller), 
        .processing_has_run_once(processing_has_run_once)
    );

    // 3. Memória da Imagem (agora usa dados e controlo síncronos)
    ImgRam processing_ram (
        .clock(CLOCK_50), 
        .rdaddress(read_addr_to_ram), 
        .q(pixel_in_to_processor),
        .wraddress(latched_address_img), // <<< MODIFICADO (usa dado capturado)
        .data(latched_data_img),       // <<< MODIFICADO (usa dado capturado)
        .wren(wren_img_ram)            // <<< MODIFICADO (usa pulso síncrono)
    );
     
    // 4. Processador de Imagem
    ImageProcessor processor (
        .clk(CLOCK_50), .enable(enable_processing), 
        .algorithm_select(algorithm_select), .zoom_level(zoom_level), 
        .pixel_in_from_rom(pixel_in_to_processor), .read_addr(read_addr_to_ram), 
        .pixel_out_to_ram(pixel_out_from_processor), .write_addr(write_addr), 
        .done(processing_finished) 
    );
    // 5. Memória de Vídeo (Frame Buffer)
    VdRam frame_buffer (.clock(CLOCK_50), .wren(wren_from_controller), .wraddress(write_addr), .data(pixel_out_from_processor), .rdaddress(vga_read_addr), .q(vga_pixel_data));
    
    // 6. Arquitetura de Exibição VGA
    assign vga_display_zoom_level = processing_has_run_once ? zoom_level : 3'd2;
    VGAController vga_logic_inst (.pclk(CLOCK_50), .reset(hps_reset), .zoom_level(vga_display_zoom_level), .current_x(vga_next_x), .current_y(vga_next_y), .is_image_area(is_image_area), .read_addr(vga_read_addr));
    
    assign color_to_driver = is_image_area ? vga_pixel_data : 8'h00;  
    VGA_Driver the_vga_driver (.clock(vga_clk_25mhz), .reset(hps_reset), .color_in(color_to_driver), .next_x(vga_next_x), .next_y(vga_next_y), .hsync(VGA_HS), .vsync(VGA_VS), .red(VGA_R), .green(VGA_G), .blue(VGA_B), .sync(vga_sync_dummy), .clk(VGA_CLK), .blank(VGA_BLANK_N));
    
    // 7. Driver do Display (Agora não mostra mais erros de validação)
    Informations scrolling_display (.clk(CLOCK_50), .reset(hps_reset), .algorithm_select(algorithm_select), .invalid_zoom_error(1'b0), .multiple_switches_error(1'b0), .no_switch_selected_error(1'b0), .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5));


    // <<< INÍCIO DO NOVO BLOCO DE DEBUG (MODIFICADO) >>>
    
    // Registos para "segurar" os pulsos
    reg  img_ram_write_latch;
    reg  start_pulse_latch;   

    always @(posedge CLOCK_50 or posedge hps_reset) begin
        if (hps_reset) begin
            img_ram_write_latch <= 1'b0;
            start_pulse_latch   <= 1'b0;
        end else begin
            
            // Latch para o *pedido* de escrita na ImgRam
            if (wren_img_ram) begin
                img_ram_write_latch <= 1'b1;
            end
            
            // Latch para o *pedido* de escrita no registo (que gera o start_pulse)
            // (Assumindo que start_pulse é um pulso síncrono vindo do RegisterController)
            if (start_pulse) begin
                start_pulse_latch <= 1'b1;
            end
        end
    end

    // --- Mapeamento dos Sinais de Debug para os LEDs ---
    assign LEDR[9] = ~hps_reset;            // LIGADO = Sistema FORA de reset.
    assign LEDR[8] = img_ram_write_latch;   // LIGADO = Pelo menos 1 escrita na ImgRam foi DETECTADA.
    assign LEDR[7] = start_pulse_latch;     // LIGADO = O comando 'start' foi DETECTADO.
    assign LEDR[6] = enable_processing;     // LIGADO = FSM (Controller) está no estado S_PROCESS.
    assign LEDR[5] = processing_finished;   // LIGADO = O ImageProcessor TERMINOU.
    assign LEDR[4] = fpga_ack_img_write;    // Pisca durante a escrita da ImgRam (Handshake)
    assign LEDR[3] = fpga_ack_reg_write;    // Pisca durante a escrita do Registo (Handshake)
    assign LEDR[2:0] = 3'b0;                // Não utilizados
    
    // <<< FIM DO NOVO BLOCO DE DEBUG >>>
    
endmodule