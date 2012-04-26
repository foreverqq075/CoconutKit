//
//  HLSProtocolProxy.m
//  CoconutKit
//
//  Created by Samuel Défago on 25.04.12.
//  Copyright (c) 2012 Hortis. All rights reserved.
//

#import "HLSProtocolProxy.h"

#import "HLSLogger.h"
#import "HLSRuntime.h"
#import "HLSZeroingWeakRef.h"

@interface HLSProtocolProxy ()

@property (nonatomic, retain) HLSZeroingWeakRef *targetZeroingWeakRef;

@end

@implementation HLSProtocolProxy

#pragma mark Class methods

+ (id)proxyWithTarget:(id)target protocol:(Protocol *)protocol
{
    return [[[self class] alloc] initWithTarget:target protocol:protocol];
}

#pragma mark Object creation and destruction

- (id)initWithTarget:(id)target protocol:(Protocol *)protocol
{
    if (! protocol) {
        HLSLoggerError(@"Cannot create a proxy to target %@ without a protocol", target);
        [self release];
        return nil;
    }
    
    if (target) {
        // Consider the official class identity, not the real one which could be discovered by using runtime
        // functions (-class can be faked by dynamic subclasses, e.g.)
        Class targetClass = [target class];
        if (! hls_class_conformsToProtocol(targetClass, protocol)) {
            HLSLoggerError(@"The class %@ must implement the protocol %s", targetClass, protocol_getName(protocol));
            [self release];
            return nil;
        }
    }
    
    self.targetZeroingWeakRef = [[[HLSZeroingWeakRef alloc] initWithObject:target] autorelease];
    _protocol = protocol;
    
    return self;
}

- (void)dealloc
{
    self.targetZeroingWeakRef = nil;
    
    [super dealloc];
}

#pragma mark Accessors and mutators

@synthesize targetZeroingWeakRef = _targetZeroingWeakRef;

#pragma mark Message forwarding

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{    
    return [self.targetZeroingWeakRef.object methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    // Search in required methods first (should be the most common case for protocols defining an interface
    // subset)
    SEL selector = [invocation selector];
    struct objc_method_description methodDescription = protocol_getMethodDescription(_protocol, selector, YES, YES);
    if (! methodDescription.name) {
        // Search in optional methods
        methodDescription = protocol_getMethodDescription(_protocol, selector, NO, YES);
        if (! methodDescription.name) {
            NSString *reason = [NSString stringWithFormat:@"[id<%s> %s]: unrecognized selector sent to proxy instance %p", protocol_getName(_protocol),
                                (char *)selector, self];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:nil];
            return;
        }
    }
    
    [invocation invokeWithTarget:self.targetZeroingWeakRef.object];
}

#pragma mark Description

- (NSString *)description
{
    // Must override NSProxy implementation, not forwarded automatically. Replace the target class name (if appearing in the description)
    // with the proxy object information
    id target = self.targetZeroingWeakRef.object;
    return [[target description] stringByReplacingOccurrencesOfString:[target className]
                                                           withString:[NSString stringWithFormat:@"id<%s>", protocol_getName(_protocol)]];
}

@end
