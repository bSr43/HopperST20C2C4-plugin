//
//  ST20CPUContext.m
//  ST20CPU
//
//  Created by Vincent Bénony on 09/04/2015.
//  Copyright (c) 2015 Cryptic Apps. All rights reserved.
//

#import "ST20CPUContext.h"
#import "ST20CPU.h"
#import <Hopper/HPBasicBlock.h>
#import <Hopper/DisasmStruct.h>
#import <Hopper/HPSegment.h>

@implementation ST20CPUContext {
    ST20CPU *_cpu;
    NSObject<HPDisassembledFile> *_file;
}

- (instancetype)initWithFile:(NSObject<HPDisassembledFile> *)file andCPUDefinition:(ST20CPU *)cpu {
    if (self = [super init]) {
        _cpu = cpu;
        _file = file;
    }
    return self;
}

- (NSObject<CPUDefinition> *)cpuDefinition {
    return _cpu;
}

- (void)initDisasmStructure:(DisasmStruct*)disasm withSyntaxIndex:(NSUInteger)syntaxIndex {
    disasm->instruction.mnemonic[0] = 0;
    disasm->instruction.addressValue = 0;
    disasm->instruction.branchType = DISASM_BRANCH_NONE;
    bzero(&disasm->prefix, sizeof(DisasmPrefix));
    for (int i=0; i<DISASM_MAX_OPERANDS; i++) {
        disasm->operand[0].type = DISASM_OPERAND_NO_OPERAND;
        disasm->operand[0].immediateValue = 0;
    }
}

////////////////////////////////////////////////////////////////////////////////
//
// Analysis
//
////////////////////////////////////////////////////////////////////////////////

/// Adjust address to the lowest possible address acceptable by the CPU. Example: M68000 instruction must be word aligned, so this method would clear bit 0.
- (Address)adjustCodeAddress:(Address)address {
    return address;
}

/// Returns a guessed CPU mode for a given address. Example, ARM processors knows that an instruction is in Thumb mode if bit 0 is 1.
- (uint8_t)cpuModeFromAddress:(Address)address {
    return 0;
}

/// Returns YES if we know that a given address forces the CPU to use a specific mode. Thumb mode of comment above.
- (BOOL)addressForcesACPUMode:(Address)address {
    return NO;
}

/// An heuristic to estimate the CPU mode at a given address, not based on the value of the
/// address itself (this is the purpose of the "cpuModeFromAddress:" method), but rather
/// by trying to disassemble a few instruction and see which mode seems to be the best guess.
- (uint8_t)estimateCPUModeAtVirtualAddress:(Address)address {
    return 0;
}

- (Address)nextAddressToTryIfInstructionFailedToDecodeAt:(Address)address forCPUMode:(uint8_t)mode {
    return address + 1;
}

/// Return 0 if the instruction at this address doesn't represent a NOP instruction (or any padding instruction), or the insturction length if any.
- (int)isNopAt:(Address)address {
    return [_file readUInt16AtVirtualAddress:address] == 0xF063;
}

- (BOOL)hasProcedurePrologAt:(Address)address {
    // If the instruction is "AJW", we have a prolog...
    uint8_t code;
    do {
        code = [_file readUInt8AtVirtualAddress:address++] & 0xF0;
    } while (code == 0x60 || code== 0x20);

    return (code == 0xB0);
}

/// Notify the plugin that an analysisbegan from an entry point.
/// This could be either a simple disassembling, or a procedure creation.
/// In the latter case, another method will be called to notify the plugin (see below).
- (void)analysisBeginsAt:(Address)entryPoint {

}

/// Notify the plugin that analysis has ended.
- (void)analysisEnded {

}

/// A Procedure object is about to be created.
- (void)procedureAnalysisBeginsForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {

}

/// The prolog of the created procedure is being analyzed.
/// Warning: this method is not called at the begining of the procedure creation, but once all basic blocks
/// have been created.
- (void)procedureAnalysisOfPrologForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {

}

- (void)procedureAnalysisEndedForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {

}

/// A new basic bloc is created
- (void)procedureAnalysisContinuesOnBasicBlock:(NSObject<HPBasicBlock> *)basicBlock {

}

/// This method may be called when the internal state of the disassembler should be reseted.
/// For instance, the ARM plugin maintains a state during the disassembly process to
/// track the state of IT blocks. When this method is called, this state is reseted.
- (void)resetDisassembler {
}

/// Disassemble a single instruction, filling the DisasmStruct structure.
/// Only a few fields are set by Hopper (mainly, the syntaxIndex, the "bytes" field and the virtualAddress of the instruction).
/// The CPU should fill as much information as possible.
- (int)disassembleSingleInstruction:(DisasmStruct *)disasm usingProcessorMode:(NSUInteger)mode {
    [self initDisasmStructure:disasm withSyntaxIndex:0];

    uint32_t iPtr = (uint32_t) disasm->virtualAddr;
    const uint8_t *ptr = disasm->bytes;

    uint32_t oReg = 0;

    BOOL inPfix = NO;
    disasm->instruction.mnemonic[0] = 0;

    while (disasm->instruction.mnemonic[0] == 0
        && iPtr - disasm->virtualAddr < 8) {

        uint8_t instr = *ptr++;
        uint8_t opcode = instr & 0xF0;
        uint8_t data = instr & 0x0F;
        iPtr++;

//        if (inPfix && opcode != 0x20 && opcode != 0x60 && opcode != 0xF0) return DISASM_UNKNOWN_OPCODE;

        oReg |= data;

        switch (opcode) {
            case 0x00:
                disasm->instruction.branchType = DISASM_BRANCH_JMP;
                disasm->instruction.addressValue = iPtr + oReg;
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = iPtr + oReg;
                strcpy(disasm->instruction.mnemonic, "j");
                break;

            case 0x10:
                strcpy(disasm->instruction.mnemonic, "ldlp");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0x20: // pfix
                inPfix = YES;
                oReg <<= 4;
                break;

            case 0x30:
                strcpy(disasm->instruction.mnemonic, "ldnl");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0x40:
                strcpy(disasm->instruction.mnemonic, "ldc");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0x50:
                strcpy(disasm->instruction.mnemonic, "ldnlp");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0x60:
                inPfix = YES;
                oReg = (~oReg) << 4;
                break;

            case 0x70:
                strcpy(disasm->instruction.mnemonic, "ldl");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0x80:
                strcpy(disasm->instruction.mnemonic, "adc");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0x90:
                disasm->instruction.branchType = DISASM_BRANCH_CALL;
                disasm->instruction.addressValue = iPtr + oReg;
                strcpy(disasm->instruction.mnemonic, "call");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = iPtr + oReg;
                break;

            case 0xA0:
                disasm->instruction.branchType = DISASM_BRANCH_JNE;
                disasm->instruction.addressValue = iPtr + oReg;
                strcpy(disasm->instruction.mnemonic, "cj");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = iPtr + oReg;
                break;

            case 0xB0:
                strcpy(disasm->instruction.mnemonic, "ajw");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0xC0:
                strcpy(disasm->instruction.mnemonic, "eqc");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0xD0:
                strcpy(disasm->instruction.mnemonic, "stl");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0xE0:
                strcpy(disasm->instruction.mnemonic, "stnl");
                disasm->operand[0].type = DISASM_OPERAND_CONSTANT_TYPE | DISASM_OPERAND_RELATIVE;
                disasm->operand[0].size = 32;
                disasm->operand[0].immediateValue = oReg;
                break;

            case 0xF0:
                switch (oReg) {
                    case 0x00:
                        strcpy(disasm->instruction.mnemonic, "rev");
                        break;
                    case 0x01:
                        strcpy(disasm->instruction.mnemonic, "lb");
                        break;
                    case 0x02:
                        strcpy(disasm->instruction.mnemonic, "bsub");
                        break;
                    case 0x03:
                        strcpy(disasm->instruction.mnemonic, "endp");
                        break;
                    case 0x04:
                        strcpy(disasm->instruction.mnemonic, "diff");
                        break;
                    case 0x05:
                        strcpy(disasm->instruction.mnemonic, "add");
                        break;
                    case 0x06:
                        disasm->instruction.branchType = DISASM_BRANCH_CALL;
                        strcpy(disasm->instruction.mnemonic, "gcall");
                        break;
                    case 0x07:
                        strcpy(disasm->instruction.mnemonic, "in");
                        break;
                    case 0x08:
                        strcpy(disasm->instruction.mnemonic, "prod");
                        break;
                    case 0x09:
                        strcpy(disasm->instruction.mnemonic, "gt");
                        break;
                    case 0x0a:
                        strcpy(disasm->instruction.mnemonic, "wsub");
                        break;
                    case 0x0b:
                        strcpy(disasm->instruction.mnemonic, "out");
                        break;
                    case 0x0c:
                        strcpy(disasm->instruction.mnemonic, "sub");
                        break;
                    case 0x0d:
                        strcpy(disasm->instruction.mnemonic, "startp");
                        break;
                    case 0x0e:
                        strcpy(disasm->instruction.mnemonic, "outbyte");
                        break;
                    case 0x0f:
                        strcpy(disasm->instruction.mnemonic, "outword");
                        break;
                    case 0x10:
                        strcpy(disasm->instruction.mnemonic, "seterr");
                        break;
                    case 0x12:
                        strcpy(disasm->instruction.mnemonic, "resetch");
                        break;
                    case 0x13:
                        strcpy(disasm->instruction.mnemonic, "csub0");
                        break;
                    case 0x15:
                        strcpy(disasm->instruction.mnemonic, "stopp");
                        break;
                    case 0x16:
                        strcpy(disasm->instruction.mnemonic, "ladd");
                        break;
                    case 0x17:
                        strcpy(disasm->instruction.mnemonic, "stlb");
                        break;
                    case 0x18:
                        strcpy(disasm->instruction.mnemonic, "sthf");
                        break;
                    case 0x19:
                        strcpy(disasm->instruction.mnemonic, "norm");
                        break;
                    case 0x1a:
                        strcpy(disasm->instruction.mnemonic, "ldiv");
                        break;
                    case 0x1b:
                        strcpy(disasm->instruction.mnemonic, "ldpi");
                        break;
                    case 0x1c:
                        strcpy(disasm->instruction.mnemonic, "stlf");
                        break;
                    case 0x1d:
                        strcpy(disasm->instruction.mnemonic, "xdble");
                        break;
                    case 0x1e:
                        strcpy(disasm->instruction.mnemonic, "ldpri");
                        break;
                    case 0x1f:
                        strcpy(disasm->instruction.mnemonic, "rem");
                        break;
                    case 0x20:
                        disasm->instruction.branchType = DISASM_BRANCH_RET;
                        strcpy(disasm->instruction.mnemonic, "ret");
                        break;
                    case 0x21:
                        strcpy(disasm->instruction.mnemonic, "lend");
                        break;
                    case 0x22:
                        strcpy(disasm->instruction.mnemonic, "ldtimer");
                        break;
                    case 0x29:
                        strcpy(disasm->instruction.mnemonic, "testerr");
                        break;
                    case 0x2a:
                        strcpy(disasm->instruction.mnemonic, "testpranal");
                        break;
                    case 0x2b:
                        strcpy(disasm->instruction.mnemonic, "tin");
                        break;
                    case 0x2c:
                        strcpy(disasm->instruction.mnemonic, "div");
                        break;
                    case 0x2e:
                        strcpy(disasm->instruction.mnemonic, "dist");
                        break;
                    case 0x2f:
                        strcpy(disasm->instruction.mnemonic, "disc");
                        break;
                    case 0x30:
                        strcpy(disasm->instruction.mnemonic, "diss");
                        break;
                    case 0x31:
                        strcpy(disasm->instruction.mnemonic, "lmul");
                        break;
                    case 0x32:
                        strcpy(disasm->instruction.mnemonic, "not");
                        break;
                    case 0x33:
                        strcpy(disasm->instruction.mnemonic, "xor");
                        break;
                    case 0x34:
                        strcpy(disasm->instruction.mnemonic, "bcnt");
                        break;
                    case 0x35:
                        strcpy(disasm->instruction.mnemonic, "lshr");
                        break;
                    case 0x36:
                        strcpy(disasm->instruction.mnemonic, "lshl");
                        break;
                    case 0x37:
                        strcpy(disasm->instruction.mnemonic, "lsum");
                        break;
                    case 0x38:
                        strcpy(disasm->instruction.mnemonic, "lsub");
                        break;
                    case 0x39:
                        strcpy(disasm->instruction.mnemonic, "runp");
                        break;
                    case 0x3a:
                        strcpy(disasm->instruction.mnemonic, "xword");
                        break;
                    case 0x3b:
                        strcpy(disasm->instruction.mnemonic, "sb");
                        break;
                    case 0x3c:
                        strcpy(disasm->instruction.mnemonic, "gajw");
                        break;
                    case 0x3d:
                        strcpy(disasm->instruction.mnemonic, "savel");
                        break;
                    case 0x3e:
                        strcpy(disasm->instruction.mnemonic, "saveh");
                        break;
                    case 0x3f:
                        strcpy(disasm->instruction.mnemonic, "wcnt");
                        break;
                    case 0x40:
                        strcpy(disasm->instruction.mnemonic, "shr");
                        break;
                    case 0x41:
                        strcpy(disasm->instruction.mnemonic, "shl");
                        break;
                    case 0x42:
                        strcpy(disasm->instruction.mnemonic, "mint");
                        break;
                    case 0x43:
                        strcpy(disasm->instruction.mnemonic, "alt");
                        break;
                    case 0x44:
                        strcpy(disasm->instruction.mnemonic, "altwt");
                        break;
                    case 0x45:
                        strcpy(disasm->instruction.mnemonic, "altend");
                        break;
                    case 0x46:
                        strcpy(disasm->instruction.mnemonic, "and");
                        break;
                    case 0x47:
                        strcpy(disasm->instruction.mnemonic, "enbt");
                        break;
                    case 0x48:
                        strcpy(disasm->instruction.mnemonic, "enbc");
                        break;
                    case 0x49:
                        strcpy(disasm->instruction.mnemonic, "enbs");
                        break;
                    case 0x4a:
                        strcpy(disasm->instruction.mnemonic, "move");
                        break;
                    case 0x4b:
                        strcpy(disasm->instruction.mnemonic, "or");
                        break;
                    case 0x4c:
                        strcpy(disasm->instruction.mnemonic, "csngl");
                        break;
                    case 0x4d:
                        strcpy(disasm->instruction.mnemonic, "ccnt1");
                        break;
                    case 0x4e:
                        strcpy(disasm->instruction.mnemonic, "talt");
                        break;
                    case 0x4f:
                        strcpy(disasm->instruction.mnemonic, "diff");
                        break;
                    case 0x50:
                        strcpy(disasm->instruction.mnemonic, "sthb");
                        break;
                    case 0x51:
                        strcpy(disasm->instruction.mnemonic, "taltwt");
                        break;
                    case 0x52:
                        strcpy(disasm->instruction.mnemonic, "sum");
                        break;
                    case 0x53:
                        strcpy(disasm->instruction.mnemonic, "mul");
                        break;
                    case 0x54:
                        strcpy(disasm->instruction.mnemonic, "sttimer");
                        break;
                    case 0x55:
                        strcpy(disasm->instruction.mnemonic, "stoperr");
                        break;
                    case 0x56:
                        strcpy(disasm->instruction.mnemonic, "cword");
                        break;
                    case 0x57:
                        strcpy(disasm->instruction.mnemonic, "clrhalterr");
                        break;
                    case 0x58:
                        strcpy(disasm->instruction.mnemonic, "sethalterr");
                        break;
                    case 0x59:
                        strcpy(disasm->instruction.mnemonic, "testhalterr");
                        break;
                    case 0x5a:
                        strcpy(disasm->instruction.mnemonic, "dup");
                        break;
                    case 0x5b:
                        strcpy(disasm->instruction.mnemonic, "move2dinit");
                        break;
                    case 0x5c:
                        strcpy(disasm->instruction.mnemonic, "move2dall");
                        break;
                    case 0x5d:
                        strcpy(disasm->instruction.mnemonic, "move2dnonzero");
                        break;
                    case 0x5e:
                        strcpy(disasm->instruction.mnemonic, "move2dzero");
                        break;
                    case 0x5f:
                        strcpy(disasm->instruction.mnemonic, "gtu");
                        break;
                    case 0x63:
                        strcpy(disasm->instruction.mnemonic, "unpacksn");
                        break;
                    case 0x64:
                        strcpy(disasm->instruction.mnemonic, "slmul");
                        break;
                    case 0x65:
                        strcpy(disasm->instruction.mnemonic, "sulmul");
                        break;
                    case 0x68:
                        strcpy(disasm->instruction.mnemonic, "satadd");
                        break;
                    case 0x69:
                        strcpy(disasm->instruction.mnemonic, "satsub");
                        break;
                    case 0x6a:
                        strcpy(disasm->instruction.mnemonic, "satmul");
                        break;
                    case 0x6c:
                        strcpy(disasm->instruction.mnemonic, "postnormsn");
                        break;
                    case 0x6d:
                        strcpy(disasm->instruction.mnemonic, "roundsn");
                        break;
                    case 0x6f:
                        strcpy(disasm->instruction.mnemonic, "sttraph");
                        break;
                    case 0x71:
                        strcpy(disasm->instruction.mnemonic, "ldinf");
                        break;
                    case 0x72:
                        strcpy(disasm->instruction.mnemonic, "fmul");
                        break;
                    case 0x73:
                        strcpy(disasm->instruction.mnemonic, "cflerr");
                        break;
                    case 0x74:
                        strcpy(disasm->instruction.mnemonic, "crcword");
                        break;
                    case 0x75:
                        strcpy(disasm->instruction.mnemonic, "crcbyte");
                        break;
                    case 0x76:
                        strcpy(disasm->instruction.mnemonic, "bitcnt");
                        break;
                    case 0x77:
                        strcpy(disasm->instruction.mnemonic, "bitrevword");
                        break;
                    case 0x78:
                        strcpy(disasm->instruction.mnemonic, "bitrevnbits");
                        break;
                    case 0x79:
                        strcpy(disasm->instruction.mnemonic, "pop");
                        break;
                    case 0x7e:
                        strcpy(disasm->instruction.mnemonic, "ldmemstartval");
                        break;
                    case 0x81:
                        strcpy(disasm->instruction.mnemonic, "wsubdb");
                        break;
                    case 0x9c:
                        strcpy(disasm->instruction.mnemonic, "fptesterr");
                        break;
                    case 0xb0:
                        strcpy(disasm->instruction.mnemonic, "settimeslice");
                        break;
                    case 0xb8:
                        strcpy(disasm->instruction.mnemonic, "xbword");
                        break;
                    case 0xb9:
                        strcpy(disasm->instruction.mnemonic, "lbx");
                        break;
                    case 0xba:
                        strcpy(disasm->instruction.mnemonic, "cb");
                        break;
                    case 0xbb:
                        strcpy(disasm->instruction.mnemonic, "cbu");
                        break;
                    case 0xc1:
                        strcpy(disasm->instruction.mnemonic, "ssub");
                        break;
                    case 0xc4:
                        strcpy(disasm->instruction.mnemonic, "intdis");
                        break;
                    case 0xc5:
                        strcpy(disasm->instruction.mnemonic, "intenb");
                        break;
                    case 0xc6:
                        strcpy(disasm->instruction.mnemonic, "ldtrapped");
                        break;
                    case 0xc7:
                        strcpy(disasm->instruction.mnemonic, "cir");
                        break;
                    case 0xc8:
                        strcpy(disasm->instruction.mnemonic, "ss");
                        break;
                    case 0xca:
                        strcpy(disasm->instruction.mnemonic, "ls");
                        break;
                    case 0xcb:
                        strcpy(disasm->instruction.mnemonic, "sttrapped");
                        break;
                    case 0xcc:
                        strcpy(disasm->instruction.mnemonic, "ciru");
                        break;
                    case 0xcd:
                        strcpy(disasm->instruction.mnemonic, "gintdis");
                        break;
                    case 0xce:
                        strcpy(disasm->instruction.mnemonic, "gintenb");
                        break;
                    case 0xf0:
                        strcpy(disasm->instruction.mnemonic, "devlb");
                        break;
                    case 0xf1:
                        strcpy(disasm->instruction.mnemonic, "devsb");
                        break;
                    case 0xf2:
                        strcpy(disasm->instruction.mnemonic, "devls");
                        break;
                    case 0xf3:
                        strcpy(disasm->instruction.mnemonic, "devss");
                        break;
                    case 0xf4:
                        strcpy(disasm->instruction.mnemonic, "devlw");
                        break;
                    case 0xfa:
                        strcpy(disasm->instruction.mnemonic, "cs");
                        break;
                    case 0xf5:
                        strcpy(disasm->instruction.mnemonic, "devsw");
                        break;
                    case 0xf8:
                        strcpy(disasm->instruction.mnemonic, "cs");
                        break;
                    case 0xf9:
                        strcpy(disasm->instruction.mnemonic, "xsword");
                        break;
                    case 0xfb:
                        strcpy(disasm->instruction.mnemonic, "csu");
                        break;

                    ////

                    case (uint32_t) 0xfffffff7c:
                        strcpy(disasm->instruction.mnemonic, "ldprodid");
                        break;
                    case (uint32_t) 0xfffffff7d:
                        strcpy(disasm->instruction.mnemonic, "reboot");
                        break;
                    case (uint32_t) 0xfffffffbc:
                        strcpy(disasm->instruction.mnemonic, "stclock");
                        break;
                    case (uint32_t) 0xfffffffbd:
                        strcpy(disasm->instruction.mnemonic, "ldclock");
                        break;
                    case (uint32_t) 0xfffffffbe:
                        strcpy(disasm->instruction.mnemonic, "clockdis");
                        break;
                    case (uint32_t) 0xfffffffbf:
                        strcpy(disasm->instruction.mnemonic, "clockenb");
                        break;
                    case (uint32_t) 0xfffffffc0:
                        strcpy(disasm->instruction.mnemonic, "nop");
                        break;
                    case (uint32_t) 0xfffffffd4:
                        strcpy(disasm->instruction.mnemonic, "devmove");
                        break;
                    case (uint32_t) 0xfffffffde:
                        strcpy(disasm->instruction.mnemonic, "restart");
                        break;
                    case (uint32_t) 0xfffffffdf:
                        strcpy(disasm->instruction.mnemonic, "causeerror");
                        break;
                    case (uint32_t) 0xfffffffef:
                        disasm->instruction.branchType = DISASM_BRANCH_RET;
                        strcpy(disasm->instruction.mnemonic, "iret");
                        break;
                    case (uint32_t) 0xffffffff0:
                        strcpy(disasm->instruction.mnemonic, "swapqueue");
                        break;
                    case (uint32_t) 0xffffffff1:
                        strcpy(disasm->instruction.mnemonic, "swaptimer");
                        break;
                    case (uint32_t) 0xffffffff2:
                        strcpy(disasm->instruction.mnemonic, "insertqueue");
                        break;
                    case (uint32_t) 0xffffffff3:
                        strcpy(disasm->instruction.mnemonic, "timeslice");
                        break;
                    case (uint32_t) 0xffffffff4:
                        strcpy(disasm->instruction.mnemonic, "signal");
                        break;
                    case (uint32_t) 0xffffffff5:
                        strcpy(disasm->instruction.mnemonic, "wait");
                        break;
                    case (uint32_t) 0xffffffff6:
                        strcpy(disasm->instruction.mnemonic, "trapdis");
                        break;
                    case (uint32_t) 0xffffffff7:
                        strcpy(disasm->instruction.mnemonic, "trapenb");
                        break;
                    case (uint32_t) 0xffffffffb:
                        disasm->instruction.branchType = DISASM_BRANCH_RET;
                        strcpy(disasm->instruction.mnemonic, "tret");
                        break;
                    case (uint32_t) 0xffffffffc:
                        strcpy(disasm->instruction.mnemonic, "ldshadow");
                        break;
                    case (uint32_t) 0xffffffffd:
                        strcpy(disasm->instruction.mnemonic, "stshadow");
                        break;

                    default:
                        return DISASM_UNKNOWN_OPCODE;
                }
            default:
                break;
        }
    }

    return (int) (iPtr - disasm->virtualAddr);
}

/// Returns whether or not an instruction may halt the processor (like the HLT Intel instruction).
- (BOOL)instructionHaltsExecutionFlow:(DisasmStruct *)disasm {
    return disasm->instruction.branchType == DISASM_BRANCH_RET;
}

/// These methods are called to let you update your internal plugin state during the analysis.
- (void)performProcedureAnalysis:(NSObject<HPProcedure> *)procedure basicBlock:(NSObject<HPBasicBlock> *)basicBlock disasm:(DisasmStruct *)disasm {

}

- (void)updateProcedureAnalysis:(DisasmStruct *)disasm {

}

/// Return YES if the provided DisasmStruct represents an instruction that cand directly reference a memory address.
/// Ususally, this methods returns YES. This is used by the ARM plugin to avoid false references on "MOVW" instruction
/// for instance.
- (BOOL)instructionCanBeUsedToExtractDirectMemoryReferences:(DisasmStruct *)disasmStruct {
    return NO;
}

/// Return YES if the instruction may be used to build a switch/case statement.
/// For instance, for the Intel processor, it returns YES for the "JMP reg" and the "JMP [xxx+reg*4]" instructions,
/// and for the Am processor, it returns YES for the "TBB" and "TBH" instructions.
- (BOOL)instructionMayBeASwitchStatement:(DisasmStruct *)disasmStruct {
    return NO;
}

/// If a branch instruction is found, Hopper calls this method to compute additional destinations of the instruction.
/// The "*next" value is already set to the address which follows the instruction if the jump does not occurs.
/// The "branches" array is filled by NSNumber objects. The values are the addresses where the instruction can jump. Only the
/// jumps that occur in the same procedure are put here (for instance, CALL instruction targets are not put in this array).
/// The "calledAddresses" array is filled by NSNumber objects of addresses that are the target of a "CALL like" instruction, ie
/// all the jumps which go outside of the procedure.
/// The "callSiteAddresses" contains NSNumber of the addresses of the "CALL" instructions.
/// The purpose of this method is to compute additional destinations.
/// Most of the time, Hopper already found the destinations, so there is no need to do more.
/// This is used by the Intel CPU plugin to compute the destinations of switch/case constructions when it found a "JMP register" instruction.
- (void)performBranchesAnalysis:(DisasmStruct *)disasm
           computingNextAddress:(Address *)next
                    andBranches:(NSMutableArray *)branches
                   forProcedure:(NSObject<HPProcedure> *)procedure
                     basicBlock:(NSObject<HPBasicBlock> *)basicBlock
                      ofSegment:(NSObject<HPSegment> *)segment
                calledAddresses:(NSMutableArray *)calledAddresses
                      callsites:(NSMutableArray *)callSitesAddresses {

}

/// If you need a specific analysis, this method will be called once the previous branch analysis is performed.
/// For instance, this is used by the ARM CPU plugin to set the type of the destination of an LDR instruction to
/// an int of the correct size.
- (void)performInstructionSpecificAnalysis:(DisasmStruct *)disasm forProcedure:(NSObject<HPProcedure> *)procedure inSegment:(NSObject<HPSegment> *)segment {

}

/// Returns the destination address if the function starting at the given address is a thunk (ie: a direct jump to another method)
/// Returns BAD_ADDRESS is the instruction is not a thunk.
- (Address)getThunkDestinationForInstructionAt:(Address)address {
    return BAD_ADDRESS;
}

////////////////////////////////////////////////////////////////////////////////
//
// Printing instruction
//
////////////////////////////////////////////////////////////////////////////////

/// The method should return a default name for a local variable at a given displacement on stack.
- (NSString *)defaultFormattedVariableNameForDisplacement:(int64_t)displacement inProcedure:(NSObject<HPProcedure> *)procedure {
    if (displacement < 0) {
        return [NSString stringWithFormat:@"l%zd", -displacement];
    }
    else {
        return [NSString stringWithFormat:@"a%zd", displacement];
    }
}

/// Returns YES if the displacement correcponds to an argument of the procedure.
- (BOOL)displacementIsAnArgument:(int64_t)displacement forProcedure:(NSObject<HPProcedure> *)procedure {
    return displacement > 0;
}

/// If the displacement is an access to a stack argument, returns the slot index.
- (NSUInteger)stackArgumentSlotForDisplacement:(int64_t)displacement inProcedure:(NSObject<HPProcedure> *)procedure {
    return displacement / 4;
}

/// Return a displacement for a stack slot index
- (int64_t)displacementForStackSlotIndex:(NSUInteger)slot inProcedure:(NSObject<HPProcedure> *)procedure {
    return slot * 4;
}

/// Build the complete instruction string in the DisasmStruct structure.
/// This is the string to be displayed in Hopper.
- (void)buildInstructionString:(DisasmStruct *)disasm forSegment:(NSObject<HPSegment> *)segment populatingInfo:(NSObject<HPFormattedInstructionInfo> *)formattedInstructionInfo {
    strcpy(disasm->completeInstructionString, disasm->instruction.mnemonic);
    if (disasm->operand[0].type != DISASM_OPERAND_NO_OPERAND) {
        const char *spaces = "                    ";
        strcat(disasm->completeInstructionString, spaces + strlen(disasm->instruction.mnemonic));
        char *str_ptr = disasm->completeInstructionString + strlen(disasm->completeInstructionString);
        ArgFormat fmt = [_file formatForArgument:0 atVirtualAddress:disasm->virtualAddr];
        int64_t val = disasm->operand[0].immediateValue;
        NSString *symbol = [_file nameForVirtualAddress:(Address) val];

        if (fmt == Format_Default) {
            if (symbol) {
                fmt = Format_Address;
            }
            else {
                if (val >= -100 && val <= 100) {
                    fmt = Format_Decimal;
                }
                else {
                    fmt = Format_Hexadecimal;
                }
            }
        }

        switch (fmt) {
            case Format_Address: {
                if (symbol) {
                    strcpy(str_ptr, [symbol UTF8String]);
                }
                else {
                    sprintf(str_ptr, "0x%llx", val);
                }
                break;
            }

            case Format_Decimal:
                sprintf(str_ptr, "%lld", val);
                break;

            case Format_Hexadecimal:
            default:
                sprintf(str_ptr, "0x%llx", val);
                break;
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
//
// Decompiler
//
////////////////////////////////////////////////////////////////////////////////

- (BOOL)canDecompileProcedure:(NSObject<HPProcedure> *)procedure {
    return NO;
}

/// Return the address of the first instruction of the procedure, after its prolog.
- (Address)skipHeader:(NSObject<HPBasicBlock> *)basicBlock ofProcedure:(NSObject<HPProcedure> *)procedure {
    return basicBlock.from;
}

/// Return the address of the last instruction of the procedure, before its epilog.
- (Address)skipFooter:(NSObject<HPBasicBlock> *)basicBlock ofProcedure:(NSObject<HPProcedure> *)procedure {
    return basicBlock.to;
}

/// Returns an AST representation of an operand of an instruction.
/// Note: ASTNode is not publicly exposed yet. You cannot write a decompiler at the moment.
- (ASTNode *)rawDecodeArgumentIndex:(int)argIndex ofDisasm:(DisasmStruct *)disasm ignoringWriteMode:(BOOL)ignoreWrite usingDecompiler:(Decompiler *)decompiler {
    return nil;
}

/// Decompile an assembly instruction.
/// Note: ASTNode is not publicly exposed yet. You cannot write a decompiler at the moment.
- (ASTNode *)decompileInstructionAtAddress:(Address)a
                                    disasm:(DisasmStruct)d
                                 addNode_p:(BOOL *)addNode_p
                           usingDecompiler:(Decompiler *)decompiler {
    return nil;
}

////////////////////////////////////////////////////////////////////////////////
//
// Assembler
//
////////////////////////////////////////////////////////////////////////////////

- (NSData *)assembleRawInstruction:(NSString *)instr atAddress:(Address)addr forFile:(NSObject<HPDisassembledFile> *)file withCPUMode:(uint8_t)cpuMode usingSyntaxVariant:(NSUInteger)syntax error:(NSError **)error {
    return nil;
}


@end
