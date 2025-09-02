module BlockAveraging (
    input           clk,
    input           enable,
    input   [7:0]   pixel_in_p0, // (x, y)
    input   [7:0]   pixel_in_p1, // (x+1, y)
    input   [7:0]   pixel_in_p2, // (x, y+1)
    input   [7:0]   pixel_in_p3, // (x+1, y+1)
    output  [7:0]   pixel_out,
    output  [15:0]  read_addr,
    output  [15:0]  write_addr,
    output          done
);
    // Parâmetros da imagem
    localparam IMG_WIDTH_IN   = 160;
    localparam IMG_HEIGHT_IN  = 120;
    localparam IMG_WIDTH_OUT  = 80;
    localparam IMG_HEIGHT_OUT = 60;
    localparam IMG_SIZE_OUT   = IMG_WIDTH_OUT * IMG_HEIGHT_OUT;

    // Registador de estado (ponteiro)
    reg [12:0] ptr;

    // Fios para cálculos intermediários
    wire [6:0] x_out = ptr % IMG_WIDTH_OUT;
    wire [5:0] y_out = ptr / IMG_WIDTH_OUT;
    wire [7:0] x_in  = x_out << 1;
    wire [6:0] y_in  = y_out << 1;
    wire [9:0] sum   = pixel_in_p0 + pixel_in_p1 + pixel_in_p2 + pixel_in_p3;

    // Lógica sequencial
    always @(posedge clk) begin
        if (!enable) begin
            ptr <= 0;
        end else if (ptr < IMG_SIZE_OUT) begin
            ptr <= ptr + 1;
        end
    end

    // Lógica combinacional
    assign read_addr  = y_in * IMG_WIDTH_IN + x_in; // Endereço base do bloco 2x2
    assign write_addr = ptr;
    assign pixel_out  = sum >> 2; // Média dos 4 pixels (divisão por 4)
    assign done       = (ptr == IMG_SIZE_OUT);

endmodule