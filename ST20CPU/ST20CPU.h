//
//  ST20CPU.h
//  ST20CPU
//
//  Created by Vincent Bénony on 09/04/2015.
//  Copyright (c) 2015 Cryptic Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hopper/CPUDefinition.h>

@interface ST20CPU : NSObject<CPUDefinition>

- (NSObject<HPHopperServices> *)services;

@end
