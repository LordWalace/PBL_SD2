module Decimation(
    clk, enable, zoom_level, pixel_in,
    pixel_out, read_addr, write_addr, done
);
    input           clk;
    input           enable;
    input   [2:0]   zoom_level;
    input   [7:0]   pixel_in;
    output          pixel_out;
    output          read_addr;
    output          write_addr;
    output          done;
    
    reg  [7:0]   pixel_out;
    reg  [14:0]  read_addr;
    reg  [18:0]  write_addr;
    reg          done;
    
    localparam IMG_WIDTH_IN = 160;
    reg [7:0] x_out_count, y_out_count;
    reg [16:0] write_ptr;
    reg [16:0] write_addr_sync;
    
    wire [7:0] IMG_WIDTH_OUT;
    wire [6:0] IMG_HEIGHT_OUT;
    wire [13:0] IMG_SIZE_OUT;
    wire [1:0] shift_factor;
    wire [8:0] x_in, y_in;

    assign IMG_WIDTH_OUT  = (zoom_level == 3'd0) ? 40 : (zoom_level == 3'd1) ? 80 : 160;
    assign IMG_HEIGHT_OUT = (zoom_level == 3'd0) ? 30 : (zoom_level == 3'd1) ? 60 : 120;
    assign IMG_SIZE_OUT   = IMG_WIDTH_OUT * IMG_HEIGHT_OUT;
    assign shift_factor   = 3'd2 - zoom_level;

    always @(posedge clk) begin
        if (!enable) begin
            x_out_count <= 0; y_out_count <= 0; write_ptr <= 0; done <= 1'b0;
        end else begin
            if (write_ptr >= IMG_SIZE_OUT) begin
                done <= 1'b1; write_ptr <= 0; x_out_count <= 0; y_out_count <= 0;
            end else begin
                done <= 1'b0;
                write_ptr <= write_ptr + 1;
                if (x_out_count == IMG_WIDTH_OUT - 1) begin
                    x_out_count <= 0;
                    y_out_count <= y_out_count + 1;
                end else begin
                    x_out_count <= x_out_count + 1;
                end
            end
        end
        write_addr_sync <= write_ptr;
    end
    
    assign x_in = x_out_count << shift_factor;
    assign y_in = y_out_count << shift_factor;
    
    always @(*) begin
        pixel_out = pixel_in;
        read_addr = y_in * IMG_WIDTH_IN + x_in;
        write_addr = write_addr_sync;
    end
endmodule