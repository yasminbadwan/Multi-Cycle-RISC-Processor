// ====================================================
// Data Memory
// ====================================================
// Stores 256 words of 32 bits each (initialized to 0).
// Reads and writes happen on the RISING clock edge.
// Used only during the MEM stage (LW, SW, SWAP).
// ====================================================

`timescale 1ns/1ps

module data_memory(
    input  wire        Clk,
    input  wire [31:0] Address,   // memory address (from ALUOut)
    input  wire [31:0] Data_in,   // data to write (from register B)
    input  wire        MemWrite,  // 1 = write Data_in to Address
    input  wire        MemRead,   // 1 = read from Address into Data_out
    output reg  [31:0] Data_out   // data read from memory
);

    reg [31:0] Memory [0:255];  // 256 x 32-bit words
    integer i;

    // Initialize all locations to zero
    initial begin
        for (i = 0; i < 256; i = i + 1)
            Memory[i] = 32'd0;
    end

    // Synchronous read and write on rising edge
    always @(posedge Clk) begin
        if (MemRead)
            Data_out <= Memory[Address[7:0]];
        if (MemWrite)
            Memory[Address[7:0]] <= Data_in;
    end

endmodule

// NOTE: Full processor testbench is inside processor.v (module processor_tb).
// The code below is an optional standalone quick test for data memory only.

// Testbench data_memory
`timescale 1ns/1ps

module data_memory_tb;

    // Testbench signals
    reg         Clk;
    reg  [31:0] Address;
    reg  [31:0] Data_in;
    reg         MemWrite;
    reg         MemRead;
    wire [31:0] Data_out;

    // Instantiate Data Memory
    data_memory uut (
        .Clk(Clk),
        .Address(Address),
        .Data_in(Data_in),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .Data_out(Data_out)
    );

    // Clock generation: period = 10 ns
    always begin
        #5 Clk = ~Clk;
    end

    initial begin
        // Initial values
        Clk = 0;
        Address = 32'd0;
        Data_in = 32'd0;
        MemWrite = 1'b0;
        MemRead = 1'b0;

        #10;

        // Test 1: Write 99 into Memory[5]
        Address = 32'd5;
        Data_in = 32'd99;
        MemWrite = 1'b1;
        MemRead = 1'b0;
        #10;

        // Stop writing
        MemWrite = 1'b0;
        MemRead = 1'b0;
        #10;

        // Test 2: Read from Memory[5]
        Address = 32'd5;
        MemWrite = 1'b0;
        MemRead = 1'b1;
        #10;

        $display("Memory[5] = %0d", Data_out);

        // Stop reading
        MemRead = 1'b0;
        #10;

        // Test 3: Write 123 into Memory[10]
        Address = 32'd10;
        Data_in = 32'd123;
        MemWrite = 1'b1;
        MemRead = 1'b0;
        #10;

        // Stop writing
        MemWrite = 1'b0;
        #10;

        // Test 4: Read from Memory[10]
        Address = 32'd10;
        MemRead = 1'b1;
        MemWrite = 1'b0;
        #10;

        $display("Memory[10] = %0d", Data_out);

        // Test 5: Invalid case, MemRead and MemWrite both 1
        // Your memory should do nothing in this case
        Address = 32'd20;
        Data_in = 32'd777;
        MemRead = 1'b1;
        MemWrite = 1'b1;
        #10;

        // Read Memory[20], expected value is still 0
        MemWrite = 1'b0;
        MemRead = 1'b1;
        Address = 32'd20;
        #10;

        $display("Memory[20] = %0d", Data_out);

        $stop;
    end

endmodule