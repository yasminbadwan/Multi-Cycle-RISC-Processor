// ====================================================
// ALU  -  Arithmetic / Logic Unit
// ====================================================
// Inputs:
//   aluop  = 4-bit code that picks the operation
//   A, B   = 32-bit operands
// Output:
//   aluresult = 32-bit result
// ====================================================

`timescale 1ns/1ps

module ALU(
    input  [3:0]  aluop,
    input  [31:0] A,
    input  [31:0] B,
    output reg [31:0] aluresult
);

    // ALU operation codes (must match the ones used in C.v)
    localparam ADD  = 4'd0;   // A + B
    localparam SUB  = 4'd1;   // A - B
    localparam AND  = 4'd2;   // A & B
    localparam OR   = 4'd3;   // A | B
    localparam XOR  = 4'd4;   // A ^ B
    localparam NOR  = 4'd5;   // ~(A | B)
    localparam SLL  = 4'd6;   // A shifted left  by B[4:0]
    localparam SRL  = 4'd7;   // A shifted right by B[4:0]
    localparam ZERO = 4'd8;   // output 0  (used by CLR)

    always @(*) begin
        case (aluop)
            ADD:  aluresult = A + B;
            SUB:  aluresult = A - B;
            AND:  aluresult = A & B;
            OR:   aluresult = A | B;
            XOR:  aluresult = A ^ B;
            NOR:  aluresult = ~(A | B);
            SLL:  aluresult = A << B[4:0];
            SRL:  aluresult = A >> B[4:0];
            ZERO: aluresult = 32'd0;
            default: aluresult = 32'd0;
        endcase
    end

endmodule

// NOTE: Testbench is inside processor.v (module processor_tb).
// To test the full multicycle processor, simulate processor_tb.

// ====================================================
// ALU standalone testbench (optional, quick check)
// ====================================================
`timescale 1ns/1ps

module tb_ALU;

    reg  [31:0] A;
    reg  [31:0] B;
    reg  [3:0]  ALUop;

    wire [31:0] Result;

    ALU uut (
        .A(A),
        .B(B),
        .aluop(ALUop),
        .aluresult(Result)
    );

    task check;
        input [31:0] expected;
        begin
            #1;

            if(Result !== expected)
                $display("ERROR: ALUop=%b A=%h B=%h Expected=%h Got=%h",
                          ALUop,A,B,expected,Result);
            else
                $display("PASS : ALUop=%b Result=%h",
                          ALUop,Result);
        end
    endtask

    initial begin

        $display("========== ALU TEST START ==========");

        // ADD
        A=10; B=5; ALUop=4'b0000;
        check(15);

        // SUB
        A=10; B=5; ALUop=4'b0001;
        check(5);

        // AND
        A=32'hFFFF0000;
        B=32'h0F0F0F0F;
        ALUop=4'b0010;
        check(32'h0F0F0000);

        // OR
        A=32'h0F0F;
        B=32'h00FF;
        ALUop=4'b0011;
        check(32'h0FFF);

        // XOR
        A=32'hAAAA5555;
        B=32'hFFFF0000;
        ALUop=4'b0100;
        check(32'h55555555);

        // NOR
        A=32'h0000000F;
        B=32'h000000F0;
        ALUop=4'b0101;
        check(32'hFFFFFF00);

        // SLL
        A=32'd8;
        B=32'd2;
        ALUop=4'b0110;
        check(32'd32);

        // SRL
        A=32'd32;
        B=32'd2;
        ALUop=4'b0111;
        check(32'd8);

        // CLR
        A=32'hFFFFFFFF;
        B=32'hFFFFFFFF;
        ALUop=4'b1000;
        check(32'd0);

        $display("========== ALU TEST FINISHED ==========");
        $stop;

    end

endmodule