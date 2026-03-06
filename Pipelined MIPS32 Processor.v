// ===========================
// File: top_mips32.v
// ===========================

module top_mips32 (
    input clk,
    input reset
);

    // Program Counter
    reg [31:0] PC;

    // Pipeline Registers
    reg [31:0] IF_ID_IR, IF_ID_PC;
    reg [31:0] ID_EX_PC, ID_EX_A, ID_EX_B, ID_EX_IMM;
    reg [4:0] ID_EX_RS, ID_EX_RT, ID_EX_RD;
    reg [5:0] ID_EX_OPCODE, ID_EX_FUNCT;
    reg       ID_EX_REGDST, ID_EX_MEMREAD, ID_EX_MEMWRITE, ID_EX_REGWRITE, ID_EX_MEMTOREG;
    reg [2:0] ID_EX_ALUOP;

    reg [31:0] EX_MEM_ALUOUT, EX_MEM_B;
    reg [4:0]  EX_MEM_RD;
    reg        EX_MEM_MEMREAD, EX_MEM_MEMWRITE, EX_MEM_REGWRITE, EX_MEM_MEMTOREG;

  reg [31:0] MEM_WB_ALUOUT, MEM_WB_MEMDATA;
    reg [4:0]  MEM_WB_RD;
    reg        MEM_WB_REGWRITE, MEM_WB_MEMTOREG;

    // Data Wires
    wire [31:0] instr;
    wire [31:0] reg_read1, reg_read2, alu_result, mem_read_data;
    wire [31:0] sign_ext_imm;
    wire [4:0]  write_reg;

    // Control Wires
    wire reg_dst, mem_read, mem_write, alu_src, mem_to_reg, reg_write;
    wire [2:0] alu_op;

    // Fetch instruction
    instr_memory imem (.addr(PC[9:2]), .instr(instr));

    // Register file
    regfile rf (
        .clk(clk),
        .we(MEM_WB_REGWRITE),
        .ra1(IF_ID_IR[25:21]),
        .ra2(IF_ID_IR[20:16]),
        .wa(MEM_WB_RD),
        .wd(write_reg),
        .rd1(reg_read1),
        .rd2(reg_read2)
    );

  // Control unit
    control_unit cu (
        .opcode(IF_ID_IR[31:26]),
        .reg_dst(reg_dst),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .reg_write(reg_write),
        .alu_op(alu_op)
    );

    // ALU
    alu alu_core (
        .a(ID_EX_A),
        .b(ID_EX_B),
        .alu_control(ID_EX_ALUOP),
        .result(alu_result)
    );

    // Data memory
    data_memory dmem (
        .clk(clk),
        .addr(EX_MEM_ALUOUT),
        .wd(EX_MEM_B),
        .we(EX_MEM_MEMWRITE),
        .re(EX_MEM_MEMREAD),
        .rd(mem_read_data)
    );

  // Sign-extension
    assign sign_ext_imm = {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};

    // Writeback mux
    assign write_reg = (MEM_WB_MEMTOREG) ? MEM_WB_MEMDATA : MEM_WB_ALUOUT;

    // Program Counter Update
    always @(posedge clk or posedge reset) begin
        if (reset) PC <= 0;
        else PC <= PC + 4;
    end

    // IF/ID Pipeline Register
    always @(posedge clk) begin
        IF_ID_PC <= PC;
        IF_ID_IR <= instr;
    end

   // ID/EX Pipeline Register
    always @(posedge clk) begin
        ID_EX_PC <= IF_ID_PC;
        ID_EX_A <= reg_read1;
        ID_EX_B <= reg_read2;
        ID_EX_IMM <= sign_ext_imm;
        ID_EX_RS <= IF_ID_IR[25:21];
        ID_EX_RT <= IF_ID_IR[20:16];
        ID_EX_RD <= IF_ID_IR[15:11];
        ID_EX_OPCODE <= IF_ID_IR[31:26];
        ID_EX_FUNCT <= IF_ID_IR[5:0];
        ID_EX_REGDST <= reg_dst;
        ID_EX_MEMREAD <= mem_read;
        ID_EX_MEMWRITE <= mem_write;
        ID_EX_ALUOP <= alu_op;
        ID_EX_REGWRITE <= reg_write;
        ID_EX_MEMTOREG <= mem_to_reg;
    end

  // EX/MEM Pipeline Register
    always @(posedge clk) begin
        EX_MEM_ALUOUT <= alu_result;
        EX_MEM_B <= ID_EX_B;
        EX_MEM_RD <= (ID_EX_REGDST) ? ID_EX_RD : ID_EX_RT;
        EX_MEM_MEMREAD <= ID_EX_MEMREAD;
        EX_MEM_MEMWRITE <= ID_EX_MEMWRITE;
        EX_MEM_REGWRITE <= ID_EX_REGWRITE;
        EX_MEM_MEMTOREG <= ID_EX_MEMTOREG;
    end

    // MEM/WB Pipeline Register
    always @(posedge clk) begin
        MEM_WB_ALUOUT <= EX_MEM_ALUOUT;
        MEM_WB_MEMDATA <= mem_read_data;
        MEM_WB_RD <= EX_MEM_RD;
        MEM_WB_REGWRITE <= EX_MEM_REGWRITE;
        MEM_WB_MEMTOREG <= EX_MEM_MEMTOREG;
    end

endmodule


// ===========================
// File: alu.v
// ===========================

module alu (
    input [31:0] a,
    input [31:0] b,
    input [2:0] alu_control,
    output reg [31:0] result
);
    always @(*) begin
        case (alu_control)
            3'b000: result = a + b; // ADD
            3'b001: result = a - b; // SUB
            3'b010: result = a & b; // AND
            3'b011: result = a | b; // OR
            default: result = 32'b0;
        endcase
    end
endmodule


// ===========================
// File: regfile.v
// ===========================

module regfile (
    input clk,
    input we,
    input [4:0] ra1,
    input [4:0] ra2,
    input [4:0] wa,
    input [31:0] wd,
    output [31:0] rd1,
    output [31:0] rd2
);
    reg [31:0] regs[0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;
    end

    always @(posedge clk) begin
        if (we && wa != 5'b00000)
            regs[wa] <= wd;
    end

    assign rd1 = (ra1 == 5'b00000) ? 32'b0 : regs[ra1];
    assign rd2 = (ra2 == 5'b00000) ? 32'b0 : regs[ra2];
endmodule

// ===========================
// File: control_unit.v
// ===========================

module control_unit (
    input [5:0] opcode,
    output reg reg_dst,
    output reg mem_read,
    output reg mem_write,
    output reg alu_src,
    output reg mem_to_reg,
    output reg reg_write,
    output reg [2:0] alu_op
);
    always @(*) begin
        case (opcode)
            6'b000000: begin // R-type
                reg_dst = 1;
                alu_src = 0;
                mem_to_reg = 0;
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                alu_op = 3'b000;
            end
            6'b100011: begin // LW
                reg_dst = 0;
                alu_src = 1;
                mem_to_reg = 1;
                reg_write = 1;
                mem_read = 1;
                mem_write = 0;
                alu_op = 3'b000;
            end
            6'b101011: begin // SW
                alu_src = 1;
                mem_write = 1;
                reg_write = 0;
                mem_read = 0;
                reg_dst = 0;
                mem_to_reg = 0;
                alu_op = 3'b000;
            end
            6'b000100: begin // BEQ
                alu_src = 0;
                reg_write = 0;
                mem_read = 0;
                mem_write = 0;
                reg_dst = 0;
                mem_to_reg = 0;
                alu_op = 3'b001;
            end
            default: begin
                reg_dst = 0;
                alu_src = 0;
                mem_to_reg = 0;
                reg_write = 0;
                mem_read = 0;
                mem_write = 0;
                alu_op = 3'b000;
            end
        endcase
    end
endmodule


// ===========================
// File: instr_memory.v
// ===========================

module instr_memory (
    input [7:0] addr,
    output [31:0] instr
);
    reg [31:0] rom[0:255];
    initial $readmemh("instructions.mem", rom);
    assign instr = rom[addr];
endmodule


// ===========================
// File: data_memory.v
// ===========================

module data_memory (
    input clk,
    input [31:0] addr,
    input [31:0] wd,
    input we,
    input re,
    output [31:0] rd
);
    reg [31:0] ram[0:255];

    always @(posedge clk) begin
        if (we) ram[addr[9:2]] <= wd;
    end

    assign rd = (re) ? ram[addr[9:2]] : 32'b0;
endmodule
