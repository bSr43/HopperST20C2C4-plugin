//
//  ST20CPU.m
//  ST20CPU
//
//  Created by Vincent Bénony on 09/04/2015.
//  Copyright (c) 2015 Cryptic Apps. All rights reserved.
//

#import "ST20CPU.h"
#import "ST20CPUContext.h"
#import <Hopper/HPHopperServices.h>

@implementation ST20CPU {
    NSObject<HPHopperServices> *_services;
}

- (NSObject<HPHopperServices> *)services {
    return _services;
}

- (instancetype)initWithHopperServices:(NSObject<HPHopperServices> *)services {
    if (self = [super init]) {
        _services = services;
    }
    return self;
}

- (HopperUUID *)pluginUUID {
    return [_services UUIDWithString:@"442f7ea9-5761-458f-900a-6d991aec8108"];
}

- (HopperPluginType)pluginType {
    return Plugin_CPU;
}

- (NSString *)pluginName {
    return @"ST20-C2/C4";
}

- (NSString *)pluginDescription {
    return @"ST20-C2/C4 cpu plugin. Developped for the SSTIC 2015 challenge.";
}

- (NSString *)pluginAuthor {
    return @"Vincent Bénony";
}

- (NSString *)pluginCopyright {
    return @"©2015 - Cryptic Apps SARL";
}

- (NSString *)pluginVersion {
    return @"1.0.0";
}

/// Build a context for disassembling.
/// This method should be fast, because it'll be called very often.
- (NSObject<CPUContext> *)buildCPUContextForFile:(NSObject<HPDisassembledFile> *)file {
    return [[ST20CPUContext alloc] initWithFile:file andCPUDefinition:self];
}

/// Returns an array of NSString of CPU families handled by the plugin.
- (NSArray *)cpuFamilies {
    return @[@"ST20"];
}

/// Returns an array of NSString of CPU subfamilies handled by the plugin for a given CPU family.
- (NSArray *)cpuSubFamiliesForFamily:(NSString *)family {
    return @[@"C1"];
}

/// Returns 32 or 64, according to the family and subFamily arguments.
- (int)addressSpaceWidthInBitsForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    return 32;
}

/// Default endianess of the CPU.
- (CPUEndianess)endianess {
    return CPUEndianess_Little;
}

/// Usually, returns 1, but for the Intel processor, it'll return 2 because we have the Intel and the AT&T syntaxes.
- (NSUInteger)syntaxVariantCount {
    return 1;
}

/// The number of CPU modes. For instance, 2 for the ARM CPU family: ARM and Thumb modes.
- (NSUInteger)cpuModeCount {
    return 1;
}

- (NSArray *)syntaxVariantNames {
    return @[@"generic"];
}

- (NSArray *)cpuModeNames {
    return @[@"generic"];
}

- (NSUInteger)registerClassCount {
    return 1;
}

- (NSUInteger)registerCountForClass:(RegClass)reg_class {
    return 6;
}

- (NSString *)registerIndexToString:(int)reg ofClass:(RegClass)reg_class withBitSize:(int)size andPosition:(DisasmPosition)position {
    switch (reg) {
        case 0: return @"A"; break;
        case 1: return @"B"; break;
        case 2: return @"C"; break;
        case 3: return @"W"; break;
        case 4: return @"O"; break;
        case 5: return @"I"; break;
        default:
            break;
    }
    return nil;
}

- (NSString *)cpuRegisterStateMaskToString:(uint32_t)cpuState {
    return @"";
}

- (BOOL)registerIndexIsStackPointer:(uint32_t)reg ofClass:(RegClass)reg_class {
    return reg == 3;
}

- (BOOL)registerIndexIsFrameBasePointer:(uint32_t)reg ofClass:(RegClass)reg_class {
    return reg == 3;
}

- (BOOL)registerIndexIsProgramCounter:(uint32_t)reg {
    return reg == 5;
}

/// A weirdness of the Hopper internals. You'll usually simply need to return the "index" argument.
/// This is used by Hopper to handle the fact that operands in Intel and AT&T syntaxes are inverted.
- (NSUInteger)translateOperandIndex:(NSUInteger)index operandCount:(NSUInteger)count accordingToSyntax:(uint8_t)syntaxIndex {
    return index;
}

/// Returns a colorized string to be displayed.
/// HPHopperServices protocol provides a very simple colorizer, based on predicates.
- (NSAttributedString *)colorizeInstructionString:(NSAttributedString *)string {
    NSMutableAttributedString *s = [string mutableCopy];

    NSUInteger lastCharOfInstr = [string.string rangeOfString:@" "].location;
    if (lastCharOfInstr != NSNotFound) {
        NSUInteger lastSpace = lastCharOfInstr;
        while (isspace([string.string characterAtIndex:lastSpace])) lastSpace++;
        lastSpace--;
        [s addAttributes:_services.ASMNumberAttributes range:NSMakeRange(lastSpace + 1, string.length - lastSpace - 1)];
    }
    else {
        lastCharOfInstr = [string length];
    }

//    [s addAttributes:_services.ASMLanguageAttributes range:NSMakeRange(0, lastCharOfInstr)];

    return s;
}

/// Returns a array of bytes that represents a NOP instruction of a given size.
- (NSData *)nopWithSize:(NSUInteger)size andMode:(NSUInteger)cpuMode forFile:(NSObject<HPDisassembledFile> *)file {
    // Fill with "adc 0"
    NSMutableData *data = [NSMutableData dataWithCapacity:size];
    memset(data.mutableBytes, 0x80, size);
    return [NSData dataWithData:data];
}

/// Return YES if the plugin embed an assembler.
- (BOOL)canAssembleInstructionsForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    return NO;
}

/// Return YES if the plugin embed a decompiler.
/// Note: you cannot create a decompiler yet, because the main class (ASTNode) is not
/// publicly exposed yet.
- (BOOL)canDecompileProceduresForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    return NO;
}

@end
