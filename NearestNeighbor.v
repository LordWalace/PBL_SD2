module NearestNeighbor (
    input           clk,
    input           enable,
    input   [7:0]   pixel_in,
    output  [7:0]   pixel_out,
    output  [15:0]  read_addr,
    output  [15:0]  write_addr,
    output          done
);
    // Parâmetros da imagem
    localparam IMG_WIDTH_IN   = 160;
    localparam IMG_HEIGHT_IN  = 120;
    localparam IMG_WIDTH_OUT  = 320;
    localparam IMG_HEIGHT_OUT = 240;
    localparam IMG_SIZE_OUT   = IMG_WIDTH_OUT * IMG_HEIGHT_OUT;

    // Registador de estado (ponteiro) que varre a imagem de SAÍDA
    reg [16:0] ptr; // Tamanho suficiente para IMG_SIZE_OUT

    // Fios para cálculos intermediários das coordenadas
    wire [8:0] x_out = ptr % IMG_WIDTH_OUT;
    wire [8:0] y_out = ptr / IMG_WIDTH_OUT;
    wire [7:0] x_in  = x_out >> 1; // Divide por 2 para encontrar o pixel de entrada correspondente
    wire [7:0] y_in  = y_out >> 1; // Divide por 2

    // Lógica sequencial para o contador
    always @(posedge clk) begin
        if (!enable) begin
            ptr <= 0;
        end else if (ptr < IMG_SIZE_OUT) begin
            ptr <= ptr + 1;
        end
    end

    // Lógica combinacional para as saídas
    assign read_addr  = y_in * IMG_WIDTH_IN + x_in;
    assign write_addr = ptr;
    assign pixel_out  = pixel_in;
    assign done       = (ptr == IMG_SIZE_OUT);

endmodule