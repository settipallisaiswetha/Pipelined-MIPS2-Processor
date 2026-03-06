# Pipelined-MIPS2-Processor
# 32-bit Pipelined MIPS Processor

## Overview

This project implements a **32-bit pipelined MIPS processor** designed using **Hardware Description Language (Verilog)**.
The architecture follows a simplified **5-stage pipeline** and is simulated using **Xilinx Vivado**.

## Pipeline Stages

* Instruction Fetch (IF)
* Instruction Decode (ID)
* Execute (EX)
* Memory Access (MEM)
* Write Back (WB)

Pipeline registers used: **IF/ID, ID/EX, EX/MEM, MEM/WB**

## Project Files

* `top_mips32.v` – Top module connecting all components
* `alu.v` – Arithmetic Logic Unit
* `regfile.v` – 32-register file
* `control_unit.v` – Generates control signals
* `instr_memory.v` – Instruction memory
* `data_memory.v` – Data memory

## Features

* 32-bit datapath
* Basic MIPS instruction support (R-type, LW, SW, BEQ)
* Modular design

## Tools Used

* Hardware Description Language (Verilog)
* Xilinx Vivado Simulator
