module ZoomSelection(
    // Interface de Controlo
    input           clk,
    input           enable,
    input   [1:0]   algorithm_select,
    input   [2:0]   zoom_level,       // 3 bits para 5 níveis de zoom

    // Interface com a Memória de Leitura (ROM)
    input   [7:0]   pixel_in_p0,
    input   [7:0]   pixel_in_p1,
    input   [7:0]   pixel_in_p2,
    input   [7:0]   pixel_in_p3,
    output reg [14:0]  base_read_addr,

    // Interface com a Memória de Escrita (RAM)
    output reg  [7:0]   pixel_out,
    output reg  [16:0]  write_addr,

    // Sinal de Fim
    output reg          done
);

    // Fios para as saídas de cada módulo de algoritmo
    wire [7:0]  pixel_out_nn, pixel_out_pr, pixel_out_dec, pixel_out_ba;
    wire [14:0] read_addr_nn, read_addr_pr, read_addr_dec, read_addr_ba;
    wire [16:0] write_addr_nn, write_addr_pr, write_addr_dec, write_addr_ba;
    wire        done_nn, done_pr, done_dec, done_ba;

    // Instanciação dos 4 módulos de algoritmo
    NearestNeighbor u_nn (
        .clk(clk), .enable(enable), .zoom_level(zoom_level), .pixel_in(pixel_in_p0),
        .pixel_out(pixel_out_nn), .read_addr(read_addr_nn), .write_addr(write_addr_nn), .done(done_nn)
    );
    PixelReplication u_pr (
        .clk(clk), .enable(enable), .zoom_level(zoom_level), .pixel_in(pixel_in_p0),
        .pixel_out(pixel_out_pr), .read_addr(read_addr_pr), .write_addr(write_addr_pr), .done(done_pr)
    );
    Decimation u_dec (
        .clk(clk), .enable(enable), .zoom_level(zoom_level), .pixel_in(pixel_in_p0),
        .pixel_out(pixel_out_dec), .read_addr(read_addr_dec), .write_addr(write_addr_dec), .done(done_dec)
    );
    BlockAveraging u_ba (
        .clk(clk), .enable(enable), .zoom_level(zoom_level),
        .pixel_in_p0(pixel_in_p0), .pixel_in_p1(pixel_in_p1), .pixel_in_p2(pixel_in_p2), .pixel_in_p3(pixel_in_p3),
        .pixel_out(pixel_out_ba), .read_addr(read_addr_ba), .write_addr(write_addr_ba), .done(done_ba)
    );

    // Multiplexador: seleciona a saída do módulo correto
    always @(*) begin
        case(algorithm_select)
            2'b00: begin // Nearest Neighbor
                pixel_out = pixel_out_nn;
                base_read_addr = read_addr_nn;
                write_addr = write_addr_nn;
                done = done_nn;
            end
            2'b01: begin // Pixel Replication
                pixel_out = pixel_out_pr;
                base_read_addr = read_addr_pr;
                write_addr = write_addr_pr;
                done = done_pr;
            end
            2'b10: begin // Decimation
                pixel_out = pixel_out_dec;
                base_read_addr = read_addr_dec;
                write_addr = write_addr_dec;
                done = done_dec;
            end
            2'b11: begin // Block Averaging
                pixel_out = pixel_out_ba;
                base_read_addr = read_addr_ba;
                write_addr = write_addr_ba;
                done = done_ba;
            end
            default: begin
                pixel_out = 8'h00;
                base_read_addr = 15'h00;
                write_addr = 17'h00;
                done = 1'b0;
            end
        endcase
    end

endmodule