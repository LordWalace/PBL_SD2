module ImageProcessor(
    clk, enable, algorithm_select, zoom_level,
    pixel_in_from_rom, read_addr,
    pixel_out_to_ram, write_addr, done
);
    input           clk;	
    input           enable;
    input   [1:0]   algorithm_select;
    input   [2:0]   zoom_level;
    input   [7:0]   pixel_in_from_rom;
    output          read_addr;
    output          pixel_out_to_ram;
    output          write_addr;
    output          done;

    reg [14:0]  read_addr;
    reg [7:0]   pixel_out_to_ram;
    reg [18:0]  write_addr;
    reg         done;

    // --- Contadores Centrais para a imagem de SAÍDA ---
    reg [9:0] x_out_count, y_out_count;
    reg [18:0] write_ptr;
    
    // --- FSM de 4 tempos para a Leitura ---
    reg [1:0] fetch_state;
    localparam FETCH_P0 = 2'b00, FETCH_P1 = 2'b01, FETCH_P2 = 2'b10, FETCH_P3 = 2'b11;

    // Registadores para guardar os 4 pixels lidos a cada ciclo de 4 tempos
    reg [7:0] p0, p1, p2, p3;

    // --- Fios para Tamanhos de Saída Dinâmicos ---
    wire [9:0] IMG_WIDTH_OUT, IMG_HEIGHT_OUT;
    wire [18:0] IMG_SIZE_OUT;
    
    // --- Lógica Sequencial Principal ---
    always @(posedge clk) begin
        if (!enable) begin
            x_out_count <= 0; y_out_count <= 0; write_ptr <= 0; done <= 1'b0;
            fetch_state <= FETCH_P0;
        end else begin
            // A FSM de leitura avança a cada ciclo de clock, criando um "relógio" de 4 tempos
            fetch_state <= fetch_state + 1;

            // Os contadores principais só avançam a cada 4 ciclos (no último estado da FSM)
            if (fetch_state == FETCH_P3) begin
                if (write_ptr >= IMG_SIZE_OUT - 1) begin
                    done <= 1'b1;
                    write_ptr <= 0; x_out_count <= 0; y_out_count <= 0;
                end else begin
                    done <= 1'b0;
                    write_ptr <= write_ptr + 1;
                    if (x_out_count == IMG_WIDTH_OUT - 1) begin
                        x_out_count <= 0; y_out_count <= y_out_count + 1;
                    end else begin
                        x_out_count <= x_out_count + 1;
                    end
                end
            end
            
            // Guarda os pixels lidos nos registadores a cada tempo
            case(fetch_state)
                FETCH_P0: p0 <= pixel_in_from_rom;
                FETCH_P1: p1 <= pixel_in_from_rom;
                FETCH_P2: p2 <= pixel_in_from_rom;
                FETCH_P3: p3 <= pixel_in_from_rom;
            endcase
        end
    end

    // --- Instanciação dos Módulos "Core" (Apenas Calculadoras) ---
    wire [14:0] read_addr_nn, read_addr_pr, read_addr_dec, read_addr_ba;
    wire [7:0]  pixel_out_ba;

    NearestNeighbor  u_nn (.zoom_level(zoom_level), .x_out(x_out_count), .y_out(y_out_count), .read_addr(read_addr_nn));
    PixelReplication u_pr (.zoom_level(zoom_level), .x_out(x_out_count), .y_out(y_out_count), .read_addr(read_addr_pr));
    Decimation       u_dec(.zoom_level(zoom_level), .x_out(x_out_count), .y_out(y_out_count), .read_addr(read_addr_dec));
    BlockAveraging   u_ba (.zoom_level(zoom_level), .x_out(x_out_count), .y_out(y_out_count), .p0(p0), .p1(p1), .p2(p2), .p3(p3), .read_addr(read_addr_ba), .pixel_out(pixel_out_ba));

    // --- Multiplexador de Saídas ---
    always @(*) begin
        case(algorithm_select)
            2'b00: begin read_addr = read_addr_nn;  pixel_out_to_ram = p0; end // Usa o pixel lido no primeiro tempo
            2'b01: begin read_addr = read_addr_pr;  pixel_out_to_ram = p0; end
            2'b10: begin read_addr = read_addr_dec; pixel_out_to_ram = p0; end
            2'b11: begin 
                pixel_out_to_ram = pixel_out_ba;
                // O endereço de leitura muda a cada tempo do ciclo de 4
                case(fetch_state)
                    FETCH_P0: read_addr = read_addr_ba;
                    FETCH_P1: read_addr = read_addr_ba + 1;
                    FETCH_P2: read_addr = read_addr_ba + 160;
                    FETCH_P3: read_addr = read_addr_ba + 160 + 1;
                    default: read_addr = read_addr_ba;
                endcase
            end
            default: begin read_addr = 15'h0; pixel_out_to_ram = 8'h0; end
        endcase
        write_addr = write_ptr;
    end

    // Determina o tamanho da imagem de saída com base no zoom_level
    assign IMG_WIDTH_OUT = (zoom_level > 2) ? (160 << (zoom_level - 2)) : (160 >> (2 - zoom_level));
    assign IMG_HEIGHT_OUT = (zoom_level > 2) ? (120 << (zoom_level - 2)) : (120 >> (2 - zoom_level));
    assign IMG_SIZE_OUT = IMG_WIDTH_OUT * IMG_HEIGHT_OUT;
    
endmodule