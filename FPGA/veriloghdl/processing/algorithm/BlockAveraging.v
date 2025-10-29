// Esse algoritmo podera apresentar problemas entao ele deve ser corrigido 
// Ultima alteracao feita porem os dados da imagem original ainda foram perdidos
module BlockAveraging(
    zoom_level, x_out, y_out,
    p0, p1, p2, p3,
    read_addr, pixel_out
);
    input [2:0] zoom_level;
    input [9:0] x_out, y_out;
    input [7:0] p0, p1, p2, p3;
    output [14:0] read_addr;
    output [7:0] pixel_out;
    
    localparam IMG_WIDTH_IN = 160;
    wire [1:0] shift_factor = 3'd2 - zoom_level;
    wire [8:0] x_in = x_out << shift_factor;
    wire [8:0] y_in = y_out << shift_factor;
    wire [9:0] sum = p0 + p1 + p2 + p3;
    
    assign read_addr = y_in * IMG_WIDTH_IN + x_in;
    assign pixel_out = (zoom_level == 3'd1) ? (sum >> 2) : p0;
endmodule