module ImageProcessor(
    // Interface de Controlo
    clk, enable, algorithm_select, zoom_level,
    // Interface com a Memória de Leitura (ÚNICA ROM)
    pixel_in_from_rom, read_addr,
    // Interface com a Memória de Escrita (RAM)
    pixel_out_to_ram, write_addr, done
);
    // --- Entradas e Saídas ---
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

    // --- Fios e Registadores Internos ---
    wire [7:0]  pixel_out_nn, pixel_out_pr, pixel_out_dec, pixel_out_ba;
    wire [14:0] read_addr_nn, read_addr_pr, read_addr_dec, read_addr_ba;
    wire [18:0] write_addr_nn, write_addr_pr, write_addr_dec, write_addr_ba;
    wire        done_nn, done_pr, done_dec, done_ba;
    
    // Registadores para guardar os 4 pixels lidos sequencialmente para o BlockAveraging
    reg [7:0] p0, p1, p2, p3;
    reg [1:0] fetch_state;

    localparam FETCH_P0 = 2'b00;
    localparam FETCH_P1 = 2'b01;
    localparam FETCH_P2 = 2'b10;
    localparam FETCH_P3 = 2'b11;

    // --- Lógica de Leitura Sequencial para o Block Averaging ---
    always @(posedge clk) begin
        if (!enable) begin
            fetch_state <= FETCH_P0;
        end else if (algorithm_select == 2'b11) begin // Apenas para o Block Averaging
            case(fetch_state)
                FETCH_P0: begin p0 <= pixel_in_from_rom; fetch_state <= FETCH_P1; end
                FETCH_P1: begin p1 <= pixel_in_from_rom; fetch_state <= FETCH_P2; end
                FETCH_P2: begin p2 <= pixel_in_from_rom; fetch_state <= FETCH_P3; end
                FETCH_P3: begin p3 <= pixel_in_from_rom; fetch_state <= FETCH_P0; end
            endcase
        end
    end

    // --- Instanciação dos Módulos de Algoritmo ---
    NearestNeighbor u_nn (.clk(clk), .enable(enable), .zoom_level(zoom_level), .pixel_in(pixel_in_from_rom), .pixel_out(pixel_out_nn), .read_addr(read_addr_nn), .write_addr(write_addr_nn), .done(done_nn));
    PixelReplication u_pr (.clk(clk), .enable(enable), .zoom_level(zoom_level), .pixel_in(pixel_in_from_rom), .pixel_out(pixel_out_pr), .read_addr(read_addr_pr), .write_addr(write_addr_pr), .done(done_pr));
    Decimation u_dec (.clk(clk), .enable(enable), .zoom_level(zoom_level), .pixel_in(pixel_in_from_rom), .pixel_out(pixel_out_dec), .read_addr(read_addr_dec), .write_addr(write_addr_dec), .done(done_dec));
    BlockAveraging u_ba (.clk(clk), .enable(enable), .zoom_level(zoom_level), .pixel_in_p0(p0), .pixel_in_p1(p1), .pixel_in_p2(p2), .pixel_in_p3(p3), .pixel_out(pixel_out_ba), .read_addr(read_addr_ba), .write_addr(write_addr_ba), .done(done_ba));

    // --- Multiplexador de Saídas ---
    always @(*) begin
        case(algorithm_select)
            2'b00: begin
                pixel_out_to_ram = pixel_out_nn;
                read_addr = read_addr_nn;
                write_addr = write_addr_nn;
                done = done_nn;
            end
            2'b01: begin
                pixel_out_to_ram = pixel_out_pr;
                read_addr = read_addr_pr;
                write_addr = write_addr_pr;
                done = done_pr;
            end
            2'b10: begin
                pixel_out_to_ram = pixel_out_dec;
                read_addr = read_addr_dec;
                write_addr = write_addr_dec;
                done = done_dec;
            end
            2'b11: begin // Lógica diferente para o Block Averaging para evitar erros
                pixel_out_to_ram = pixel_out_ba;
                write_addr = write_addr_ba;
                done = done_ba;
                // O endereço de leitura é controlado pela FSM interna
                case(fetch_state)
                    FETCH_P0: read_addr = read_addr_ba;
                    FETCH_P1: read_addr = read_addr_ba + 1;
                    FETCH_P2: read_addr = read_addr_ba + 160;
                    FETCH_P3: read_addr = read_addr_ba + 160 + 1;
                    default: read_addr = read_addr_ba;
                endcase
            end
            default: begin
                pixel_out_to_ram = 8'h00;
                read_addr = 15'h0;
                write_addr = 19'h0;
                done = 1'b0;
            end
        endcase
    end
endmodule