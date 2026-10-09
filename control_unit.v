// ============================================================
// control_unit.v  -  REFERENCE / UNUSED
// ============================================================
// NOTE: The processor uses module "C" (in C.v) as its control unit.
//       This file is kept in the compilation list but module
//       "control_unit" is NOT instantiated anywhere.
//       You can ignore this file.
//
// This is an older combinational-output style control unit.
// The active one (C.v) uses a cleaner always @(*) style.
// ============================================================

`timescale 1ns/1ps

// Empty placeholder so the file compiles without errors.
module control_unit(
    input  wire       clk,
    input  wire       rst,
    input  wire [5:0] Opcode,
    input  wire       Zero,
    output wire [1:0] PCSrc,
    output wire [1:0] RegDst,
    output wire       RegWr,
    output wire       ExtOp,
    output wire       ALUSrc,
    output wire [3:0] ALUOp,
    output wire       MemRd,
    output wire       MemWr,
    output wire [1:0] WBData,
    output wire       IRWrite,
    output wire       AWrite,
    output wire       BWrite,
    output wire       ALUOutWrite,
    output wire       MDRWrite,
    output reg  [2:0] State
);
    // All outputs tied to 0 - this module is not used.
    // The real control unit is module C in C.v.
    assign PCSrc       = 2'b00;
    assign RegDst      = 2'b00;
    assign RegWr       = 1'b0;
    assign ExtOp       = 1'b0;
    assign ALUSrc      = 1'b0;
    assign ALUOp       = 4'd0;
    assign MemRd       = 1'b0;
    assign MemWr       = 1'b0;
    assign WBData      = 2'b00;
    assign IRWrite     = 1'b0;
    assign AWrite      = 1'b0;
    assign BWrite      = 1'b0;
    assign ALUOutWrite = 1'b0;
    assign MDRWrite    = 1'b0;

    always @(posedge clk or posedge rst) begin
        if (rst) State <= 3'd0;
        else     State <= 3'd0;
    end

endmodule
