module Decimation(
    zoom_level, x_out, y_out, read_addr
);
    input [2:0] zoom_level;
    input [9:0] x_out, y_out;
    output [14:0] read_addr;

    localparam IMG_WIDTH_IN = 160;
    wire [1:0] shift_factor = 3'd2 - zoom_level;
    wire [8:0] x_in = x_out << shift_factor;
    wire [8:0] y_in = y_out << shift_factor;
    assign read_addr = y_in * IMG_WIDTH_IN + x_in;
endmodule