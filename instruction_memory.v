// ====================================================
// Instruction Memory
// ====================================================
// Stores up to 256 instructions (each 32 bits).
// Loaded from the file "program.mem" at simulation start.
// Read is COMBINATIONAL: output appears immediately when
// Address changes (no clock needed to read).
// ====================================================

`timescale 1ns/1ps

module instruction_memory(
    input  wire [31:0] Address,      // from Program Counter
    output wire [31:0] Instruction   // instruction at that address
);

    reg [31:0] Memory [0:255];  // 256 x 32-bit words

    // Load program from file at start of simulation
    initial begin
        $readmemb("program.mem", Memory);
    end

    // Combinational read: use lower 8 bits as index (supports 256 addresses)
    assign Instruction = Memory[Address[7:0]];

endmodule		 


`timescale 1ns/1ps	

// Testbench instruction_memory

module instruction_memory_tb;

    reg  [31:0] Address;
    wire [31:0] Instruction;

    integer i;

    instruction_memory uut (
        .Address(Address),
        .Instruction(Instruction)
    );

    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            Address = i;
            #10;
            $display("Address = %0d, Instruction = %b", Address, Instruction);
        end

        $stop;
    end

endmodule