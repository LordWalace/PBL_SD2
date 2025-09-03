// Esse algoritmo podera apresentar problemas entao ele deve ser corrigido 

module BlockAveraging(
    input           clk,
    input           enable,
    input   [2:0]   zoom_level,
    input   [7:0]   pixel_in_p0,
    input   [7:0]   pixel_in_p1,
    input   [7:0]   pixel_in_p2,
    input   [7:0]   pixel_in_p3,
    output reg  [7:0]   pixel_out,
    output reg  [14:0]  read_addr,
    output reg  [16:0]  write_addr,
    output reg          done
);
    localparam IMG_WIDTH_IN = 160;
    reg [7:0] x_out_count, y_out_count;
    reg [16:0] out_pixel_count;

    wire [7:0] IMG_WIDTH_OUT;
    wire [6:0] IMG_HEIGHT_OUT;
    wire [13:0] IMG_SIZE_OUT;
    wire [1:0] shift_factor;
    wire [8:0] x_in;
    wire [8:0] y_in;

    assign IMG_WIDTH_OUT  = (zoom_level == 3'd0) ? 40 : (zoom_level == 3'd1) ? 80 : 160;
    assign IMG_HEIGHT_OUT = (zoom_level == 3'd0) ? 30 : (zoom_level == 3'd1) ? 60 : 120;
    assign IMG_SIZE_OUT   = IMG_WIDTH_OUT * IMG_HEIGHT_OUT;
    assign shift_factor   = 3'd2 - zoom_level;

    always @(posedge clk) begin
        if (!enable) begin
            x_out_count <= 0; y_out_count <= 0; out_pixel_count <= 0; done <= 1'b0;
        end else begin
            if (out_pixel_count >= IMG_SIZE_OUT - 1) begin
                done <= 1'b1; out_pixel_count <= 0; x_out_count <= 0; y_out_count <= 0;
            end else begin
                done <= 1'b0;
                out_pixel_count <= out_pixel_count + 1;
                if (x_out_count == IMG_WIDTH_OUT - 1) begin
                    x_out_count <= 0; y_out_count <= y_out_count + 1;
                end else begin
                    x_out_count <= x_out_count + 1;
                end
            end
        end
    end
    
    assign x_in = x_out_count << shift_factor;
    assign y_in = y_out_count << shift_factor;
    
    always @(*) begin
        if (zoom_level == 3'd1) begin // 0.5x Zoom
            pixel_out = (pixel_in_p0 + pixel_in_p1 + pixel_in_p2 + pixel_in_p3) >> 2;
        end else begin // 1x ou 0.25x Zoom
            pixel_out = pixel_in_p0;
        end
        
        read_addr = y_in * IMG_WIDTH_IN + x_in;
        write_addr = out_pixel_count;
    end
endmodule