// ====================================================
// Instruction Decoder
// ====================================================
// Splits a 32-bit instruction into its named fields.
//
// Instruction formats:
//
//   R-Type:  [31:26] opcode | [25:22] rd | [21:18] rs | [17:14] rt | [13:0] unused
//   I-Type:  [31:26] opcode | [25:22] rd | [21:18] rs | [17:0] immediate (18 bits)
//   J-Type:  [31:26] opcode | [25:0] offset (26 bits)
//
// Notes:
//   - rd = destination register
//   - rs = first source register
//   - rt = second source register (R-type) or upper bits of immediate (I-type)
//   - offset contains the full 26-bit J-type target
// ====================================================

`timescale 1ns/1ps

module instruction_decoder(
    input  wire [31:0] instruction,
    output wire [5:0]  opcode,
    output wire [3:0]  rd,
    output wire [3:0]  rs,
    output wire [3:0]  rt,
    output wire [17:0] immediate,  // used for I-type ALU and memory offset
    output wire [25:0] offset      // used for J-type jump target
);
    assign opcode    = instruction[31:26];
    assign rd        = instruction[25:22];
    assign rs        = instruction[21:18];
    assign rt        = instruction[17:14];
    assign immediate = instruction[17:0];
    assign offset    = instruction[25:0];
endmodule