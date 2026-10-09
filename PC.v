// ====================================================
// Program Counter (PC)
// ====================================================
// Holds the address of the current instruction.
// - Updates to nextpc when pcupdate = 1
// - Resets to 0 when reset goes LOW (active-LOW reset)
// ====================================================

`timescale 1ns/1ps

module PC(
    input         clk,       // clock
    input         reset,     // active-LOW reset: when 0 → PC = 0
    input         pcupdate,  // when 1 → PC takes new value on next edge
    input  [31:0] nextpc,    // the new value for PC
    output reg [31:0] pc     // current PC value
);
    always @(posedge clk or negedge reset) begin
        if (!reset)       pc <= 32'd0;    // reset: go to address 0
        else if (pcupdate) pc <= nextpc;  // update: move to next address
    end
endmodule