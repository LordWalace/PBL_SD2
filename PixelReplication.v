module PixelReplication(
    input           clk,
    input           enable,
    input   [2:0]   zoom_level,
    input   [7:0]   pixel_in,
    output reg  [7:0]   pixel_out,
    output reg  [14:0]  read_addr,
    output reg  [16:0]  write_addr,
    output reg          done
);
    localparam IMG_WIDTH_IN = 160;
    reg [9:0] x_out_count, y_out_count;
    reg [18:0] out_pixel_count;

    wire [9:0] IMG_WIDTH_OUT;
    wire [9:0] IMG_HEIGHT_OUT;
    wire [18:0] IMG_SIZE_OUT;
    wire [1:0] shift_factor;
    wire [8:0] x_in;
    wire [8:0] y_in;

    assign IMG_WIDTH_OUT  = (zoom_level == 3'd4) ? 640 : (zoom_level == 3'd3) ? 320 : 160;
    assign IMG_HEIGHT_OUT = (zoom_level == 3'd4) ? 480 : (zoom_level == 3'd3) ? 240 : 120;
    assign IMG_SIZE_OUT   = IMG_WIDTH_OUT * IMG_HEIGHT_OUT;
    assign shift_factor   = zoom_level - 3'd2;

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
    
    assign x_in = x_out_count >> shift_factor;
    assign y_in = y_out_count >> shift_factor;
    
    always @(*) begin
        pixel_out = pixel_in;
        read_addr = y_in * IMG_WIDTH_IN + x_in;
        write_addr = out_pixel_count;
    end
endmodule