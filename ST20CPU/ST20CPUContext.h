//
//  ST20CPUContext.h
//  ST20CPU
//
//  Created by Vincent Bénony on 09/04/2015.
//  Copyright (c) 2015 Cryptic Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hopper/CPUContext.h>
#import <Hopper/HPDisassembledFile.h>

@class ST20CPU;

@interface ST20CPUContext : NSObject<CPUContext>

- (instancetype)initWithFile:(NSObject<HPDisassembledFile> *)file andCPUDefinition:(ST20CPU *)cpu ;

@end
