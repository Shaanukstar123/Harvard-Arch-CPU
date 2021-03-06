module MIPS5(
    input logic [31:0] data_in, 
    input logic [31:0] instr, 
    input logic clk, 
    input logic reset, 
    input logic clock_enable,
    
    output logic [31:0] reg_v0, 
    output logic [31:0] PC, //this might need to be changed to instr_address to meet the specs 
    output logic [31:0] data_address, 
    output logic [31:0] data_out, 
    output logic active, 
    output logic data_read,
    output logic data_write
    

    //DEBUGGING
    //output logic [5:0] OP, 
    //output logic [5:0] reg_addrw,
    //output logic[31:0] reg_write,
    //output logic[31:0] reg_t0, 
    //output logic [31:0] reg_t1,
);

    logic[5:0] OP; 
    logic[5:0] funct;
    logic[31:0] op_1, op_2, jump_address, PC_next, reg_write, out, HI, LO, HI_m, LO_m;
    logic[5:0] reg_addr1, reg_addr2, reg_addrw, shamt; //reg_addrw;
    logic[15:0] astart; 
    logic next_active; 
    logic reset_prev; 
    logic write_enable;
    logic shift; 
    logic[3:0] ALU_code;
    logic[2:0] funct_tail, OP_tail; 
    logic[2:0] subtype;
    logic R_type, I_type, J_type; 
    logic [3:0] PC_upper; 
    logic [25:0] target; 
    logic MSB;

    
     
    reg signed [31:0] HI_reg, LO_reg; 

//decoder
    typedef enum logic[5:0] {
        R = 6'b0,
        ADDIU = 6'b001001,
        ANDI = 6'b001100,
        SLTI = 6'b 001010,
        SLTIU= 6'b001011,
        SW = 6'b101011,
        LW = 6'b100011,
        XORI = 6'b001110,
        BEQ = 6'b000100,
        LUI = 6'b001111,
        ORI = 6'b001101,
        J = 6'b000010,
        JAL = 6'b000011, 
        B0 = 6'b000001, 
        BLEZ = 6'b000110,
        BGTZ = 6'b000111,
        BNE = 6'b000101
    } t_OP; 

    typedef enum logic[5:0]{
        JR = 6'b001000,
        ADDU = 6'b100001,
        AND = 6'b100100,
        SLT = 6'b101010,
        SLTU = 6'b101011,
        SUBU = 6'b100011,
        XOR = 6'b100110,
        SLL = 6'b0,
        SLLV = 6'b000100,
        SRA = 6'b000011,
        SRAV = 6'b000111,
        SRL = 6'b000010,
        SRLV = 6'b000110,
        DIV = 6'b011010,
        DIVU = 6'b011011,
        OR = 6'b100101,
        MULT = 6'b011000,
        MULTU = 6'b011001,
        JALR = 6'b001001,
        MTHI = 6'b010001,
        MTLO = 6'b010011,
        MFHI = 6'b010000,
        MFLO = 6'b010010
    } t_funct; 

    typedef enum logic[2:0]{
        Branch = 3'b0, //this has further separation when it's J type, because the second half of the word is the target 
        Imm = 3'b001,
        Load = 3'b100,
        Store = 3'b101
    } sub_t;


    typedef enum logic[4:0]{
        BLTZAL = 5'b10000,
        BLTZ = 5'b0,
        BGEZ = 5'b00001,
        BGEZAL = 5'b10001
    }B0_t; 

// Instruction decoding and control signals 
    assign OP = instr[31:26]; 
    assign funct = instr[5:0];
    assign shift = (funct[5:3] == 3'b0) ? 1 : 0; 
    assign funct_tail = funct[2:0]; 
    assign OP_tail = OP[2:0]; 
    assign subtype = instr[15:13];
    assign PC_upper = PC[31:28];
    assign target = instr[25:0]; 

    assign R_type = (OP == R) ? 1:0;
    assign J_type = (OP == JAL || OP == J) ? 1:0; 
    assign I_type = (!J_type && !R_type) ? 1:0; 

    assign astart = instr[15:0]; 


// ALU control definition 
    always_comb begin 

        if (OP==R) begin 
            if (shift) begin 
                ALU_code = {1'b1, funct_tail}; 
            end 
            else if (funct == MULTU) begin 
                ALU_code = 4'b1001;
            end 
            else if (funct == DIV) begin 
                ALU_code = 4'b1101; 
            end 
            else if (funct == DIVU) begin 
                ALU_code = 4'b1100; 
            end 
        end 

        else begin
            ALU_code = {1'b0, OP_tail}; 
        end 
    end 
            
        
    reg [31:0] reg_file [31:0]; // need to sign extend partial loads here or elsewhere? 


    assign reg_addr1 = instr[25:21]; 
    assign reg_addr2 = instr[20:16]; 
    assign reg_addrw = (OP == R) ? instr[15:11] : ((OP==B0 && (reg_addr2 == BGEZAL || reg_addr2 == BLTZAL)) || OP == JAL) ? 5'd31 : instr[20:16]; //which part of the instruction word determines the address to write depends on the type of instruction

    assign write_enable = 
    ((OP == R 
        && funct != JR 
        && funct != DIV && funct != DIVU 
        && funct != MFHI && funct != MFLO 
        && funct != MTHI && funct != MTLO 
        && funct != MULT && funct != MULTU)
    || subtype == Imm
    || subtype == Load
    || OP == JAL
    || (OP == B0 
        && (reg_addr2 == BGEZAL || reg_addr2 == BLTZAL))) ? 1 : 0; // these are all the occasions in which a register from the register file will have to be written 

// register file reading 
    assign op_1 = reg_file[reg_addr1]; 
    assign op_2 = (OP==R) ? reg_file[reg_addr2] : {16'b0, astart}; 
    assign shamt = instr[10:7];

    assign MSB = op_1[31];

    assign reg_v0 = reg_file[2]; 
   // assign reg_t1 = reg_file[9];  //DEBUGGING
   // assign reg_t0 = reg_file[8];   // DEBUGGING






// full load/store instructions
always_comb begin 
    data_read = reset ? 0 : (OP == LW) ? 1: 0; // this has to be added to make sure this two bits are paralised during reset (since there can't be anything coming out of RAM)
    data_write = reset ? 0: (OP == SW) ? 1: 0; // not sure if I can do this 
    data_address = (op_1 + astart); 
end 


// idk if these are needed 
// save the previous reset for the initialisation of instr_address
    always_ff@(negedge clk) begin 
        reset_prev <= reset;
    end 

    always_ff @(posedge clk) begin 
        active <= next_active; 
    end // this means that probably some of the asserts will be wrong 

/**/

//instantiate the ALU

//ops 
    always_comb begin
        case(OP)
        LW: reg_write = data_in; 
        SW: data_out = op_1;
        JAL: reg_write = PC+4; 
        B0: begin 
            if (reg_addr2 == BGEZAL || reg_addr2 == BLTZAL) begin 
                reg_write = PC +4;
            end 
        end 
        R: begin
            if (funct == JALR) begin 
                reg_write = PC + 4; 
            end 
            else if (funct == JR) begin 
            end 
            else if (funct == MFHI) begin 
                reg_write = HI_reg;
            end 
            else if (funct == MFLO) begin 
                reg_write = LO_reg; 
            end
            else begin 
                reg_write = out; //this will set it to out even when it's doing Multiplication or division but it should be fine because the write enable shouldn't be one (even though it0s not very elegant, see what to do about this)
            end 
        end 
        default: reg_write = out; //this heavily relies on the write enable being correct, should really address this in testing 
        endcase 
    end 

//HI/LO
always_ff @(posedge clk) begin 
    if(OP == R && (funct == MULT || funct == MULTU || funct == DIV || funct == DIVU)) begin // to this I will need to add the other hi and lo instructions (MFLO; MTLO and so on)
        HI_reg <= HI; 
        LO_reg <= LO; 
    end 
    else if (OP == R && funct == MTLO) begin 
        LO_reg <= op_1;
    end 
    else if (OP == R && funct == MTHI) begin 
        HI_reg <= op_1;
    end 
end




//save the register address as it will change as soon as the next instruction is brought up 




// PC counter  
// note i don't think that we need to update PC next on the negedge (it should be fine anyway)
    always_comb begin 

// reset vector                         Note: I'm assuming PC won't be reset to 0 but to the reset vector directly, check if this is right
        if (reset) begin 
            PC_next = 32'hBFC00000;
        end 
//R_type  
        else if (R_type) begin 
            case(funct)
            JR: PC_next = PC + op_1;
            JALR: begin 
                PC_next = PC + op_1; 
            end 
            default: PC_next = PC+4; 
            endcase
        end 
//J_type
        else if (J_type) begin 
            //case(OP)
            PC_next = {PC_upper, target, 2'b00}; 
            //JAL: PC_next = {PC_upper, target, 2'b00};          
            //default: PC_next = PC +4; 
           // endcase
        end 
//I_type 
        else if (I_type) begin 
            case(subtype)
            Branch: begin 
                //4 branches with equal opcode, they can be differentiated by looking at the bits in the places corresponding to reg_addr2 (rs)
                if (OP == B0) begin 
                    if(((reg_addr2 == BGEZ || reg_addr2 == BGEZAL) && !MSB) || ((reg_addr2 == BLTZ || reg_addr2 == BLTZAL) && MSB)) begin  //associate functions and conditions 
                        PC_next = PC + (astart * 4);
                        //I moved the saving of the register to the ops file 
                    end 
                    else begin 
                        PC_next = PC +4; 
                    end 
                end 
                // all other I_type branches 
                else if ( (OP == BEQ && op_1 == op_2) || (OP == BGTZ && op_1 > 0) || (OP == BLEZ && op_1 <= 0) || (OP == BNE && op_1 != op_2)) begin 
                    PC_next = PC + (astart * 4); 
                end
            end
            default: PC_next = PC +4; 
            endcase 
        end 
    end 
    
//ALU 



//sequential block to actually change the PC address (since instruction fetching is combinatorial the new address must be defined only when we actually want the new instruction ie at the beginning of a new cycle)
    always_ff @(posedge clk) begin 
        PC <= PC_next; 
    end 

    /* begin 
                if (reset == 0) begin
                    PC <= PC_next; 
                end 
                else begin 
                    PC <= 0; 
                end 
            end 
    */   
     // this is in case PC needs to be 0 when reset is high
    


//active control 
    always_comb begin
        next_active = reset ? 1: (PC == 0) ? 0: active;  // even though active should be high during reset we need to make sure that it only activates if reset is high for more than a cycle, see how to do that 
    end 


// in case active needs to be 0 during reset: 
 /*   if (reset) begin 
            next_active = 1; 
        end 
        else if (PC != 0) begin 
            next_active = active; 
        end 
        else begin 
            next_active = 0; 
        end */



//register file writing
// what is relevant here is what reg_write is (defined in the logic block)

    always_ff @(posedge clk)  begin
        //add clock enable statement 
        // add a condition so that, if reset is 1, reg_write is 0
        if (reset && clock_enable) begin  // same here, the fact that it needs to be high for a whole cycle must be enforced 
            int i; 
            for (i=0; i<32; i= i+1) begin 
                reg_file[i] <= 0; 
            end 
        end 
        
        if (write_enable && clock_enable) begin 
            reg_file[reg_addrw] <= reg_write; 
        end 
     
        // for the above example try reg_file[reg_addrw] = reg_file
        
    end 
    alu ALU(
        .op1(op_1), .op2(op_2), .shamt(shamt), .alu_control(ALU_code), .low(LO), .high(HI), .out(out)
    );
endmodule
