// Esse algoritmo podera apresentar problemas entao ele deve ser corrigido 

module BlockAveraging(
    clk, enable, zoom_level,
    pixel_in_p0, pixel_in_p1, pixel_in_p2, pixel_in_p3,
    pixel_out, read_addr, write_addr, done
);
    input           clk;
    input           enable;
    input   [2:0]   zoom_level;
    input   [7:0]   pixel_in_p0;
    input   [7:0]   pixel_in_p1;
    input   [7:0]   pixel_in_p2;
    input   [7:0]   pixel_in_p3;
    output          pixel_out;
    output          read_addr;
    output          write_addr;
    output          done;

    reg  [7:0]   pixel_out;
    reg  [14:0]  read_addr;
    reg  [18:0]  write_addr;
    reg          done;

    localparam IMG_WIDTH_IN = 160;
    reg [7:0] x_in_count, y_in_count;
    reg [7:0] x_out_count, y_out_count;
    reg [16:0] write_ptr;
    
    wire [7:0] IMG_WIDTH_OUT;
    wire [6:0] IMG_HEIGHT_OUT;
    wire [13:0] IMG_SIZE_OUT;
    wire [1:0] shift_factor;
    wire [9:0] sum;

    assign IMG_WIDTH_OUT  = (zoom_level == 3'd0) ? 40 : (zoom_level == 3'd1) ? 80 : 160;
    assign IMG_HEIGHT_OUT = (zoom_level == 3'd0) ? 30 : (zoom_level == 3'd1) ? 60 : 120;
    assign IMG_SIZE_OUT   = IMG_WIDTH_OUT * IMG_HEIGHT_OUT;
    assign shift_factor   = 3'd2 - zoom_level;

    always @(posedge clk) begin
        if (!enable) begin
            x_out_count <= 0; y_out_count <= 0;
            x_in_count <= 0; y_in_count <= 0;
            write_ptr <= 0;
            done <= 1'b0;
        end else begin
            if (write_ptr >= IMG_SIZE_OUT - 1) begin
                done <= 1'b1;
                write_ptr <= 0; x_out_count <= 0; y_out_count <= 0;
                x_in_count <= 0; y_in_count <= 0;
            end else begin
                done <= 1'b0;
                write_ptr <= write_ptr + 1;
                if (x_out_count == IMG_WIDTH_OUT - 1) begin
                    x_out_count <= 0;
                    y_out_count <= y_out_count + 1;
                end else begin
                    x_out_count <= x_out_count + 1;
                end
                x_in_count <= x_out_count << shift_factor;
                y_in_count <= y_out_count << shift_factor;
            end
        end
    end
    
    assign sum = pixel_in_p0 + pixel_in_p1 + pixel_in_p2 + pixel_in_p3;
    
    always @(*) begin
        if (zoom_level == 3'd1) begin
            pixel_out = sum >> 2;
        end else begin
            pixel_out = pixel_in_p0;
        end
        
        read_addr = y_in_count * IMG_WIDTH_IN + x_in_count;
        write_addr = write_ptr;
    end
endmodule