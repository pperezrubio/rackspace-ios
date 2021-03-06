//
//  LoadBalancerUsage.h
//  OpenStack
//
//  Created by Michael Mayo on 2/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface LoadBalancerUsage : NSObject <NSCoding> {
    NSString *identifier;
    double averageNumConnections;
    unsigned long long incomingTransfer;
    unsigned long long outgoingTransfer;
    NSInteger numVips;
    NSInteger numPolls;
    NSDate *startTime;
    NSDate *endTime;
}

@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, assign) double averageNumConnections;
@property (nonatomic, assign) unsigned long long incomingTransfer;
@property (nonatomic, assign) unsigned long long outgoingTransfer;
@property (nonatomic, assign) NSInteger numVips;
@property (nonatomic, assign) NSInteger numPolls;
@property (nonatomic, retain) NSDate *startTime;
@property (nonatomic, retain) NSDate *endTime;

+ (LoadBalancerUsage *)fromJSON:(NSDictionary *)dict;

@end
