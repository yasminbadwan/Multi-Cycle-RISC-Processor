// ====================================================
// Register File
// ====================================================
// 16 registers (R0 to R15), each 32 bits wide.
// R0 is ALWAYS zero — writes to R0 are ignored.
//
// Reads  : combinational (instant, every cycle)
// Writes : synchronous  (happen on rising clock edge)
// ====================================================

`timescale 1ns/1ps

module Registers(
    input         clk,
    input         reset,    // active HIGH: resets all registers to 0
    input         RegWrite, // 1 = write BusW into register RW
    input  [3:0]  RA,       // address of register to read → BusA
    input  [3:0]  RB,       // address of register to read → BusB
    input  [3:0]  RW,       // address of register to write
    input  [31:0] BusW,     // data to write
    output [31:0] BusA,     // data read from register RA
    output [31:0] BusB      // data read from register RB
);
    reg [31:0] registers [0:15];
    integer i;

    // Combinational reads (always available, no clock needed)
    assign BusA = registers[RA];
    assign BusB = registers[RB];

    // Synchronous write + reset
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1)
                registers[i] <= 32'd0;      // clear all registers
        end
        else if (RegWrite && RW != 4'd0) begin
            registers[RW] <= BusW;          // R0 is never written (RW!=0 check)
        end
    end

endmodule

// NOTE: Full processor testbench is inside processor.v (module processor_tb).
// The code below is an optional standalone quick test for the register file only.

module Registers_tb;
    reg clk, reset, RegWrite;
    reg [3:0] RA, RB, RW;
    reg [31:0] BusW;
    wire [31:0] BusA, BusB;

    Registers uut (
        .clk(clk),
        .reset(reset),
        .RegWrite(RegWrite),
        .RA(RA),
        .RB(RB),
        .RW(RW),
        .BusW(BusW),
        .BusA(BusA),
        .BusB(BusB)
    );

    initial clk = 0;
    always #5 clk = ~clk;
  
//For wave
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, Registers_tb);

        
        reset = 1; RegWrite = 0;
        RA = 0; RB = 0;
        RW = 0; BusW = 0;
        #10;

        // Release reset
        reset = 0;
        #10;

        // Test 1: Write 100 to R1
        RegWrite = 1; RW = 4'd1; BusW = 32'd100;
        #10;
        RA = 4'd1;
        #1;
        $display("Test 1 - R1 = %0d ", BusA);

        // Test 2: Write 200 to R2
        RW = 4'd2; BusW = 32'd200;
        #10;
        RA = 4'd1; RB = 4'd2;
        #1;
        $display("Test 2 - R1=%0d R2=%0d ", BusA, BusB);

        // Test 3: R0 rule - attempt to write to R0
        RW = 4'd0; BusW = 32'd999;
        #10;
        RA = 4'd0;
        #1;
        $display("Test 3 - R0 = %0d ", BusA);

        // Test 4: Reset clears all registers
        reset = 1; #10; reset = 0;
        RA = 4'd1; RB = 4'd2;
        #1;
        $display("Test 4 - After reset: R1=%0d R2=%0d ", BusA, BusB);

        $finish;
    end
endmodule