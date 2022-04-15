//
//  MXLogger.m
//  Logger
//
//  Created by 董家祎 on 2022/3/1.
//

#import "MXLogger.h"
#include <MXLoggerCore/mxlogger.hpp>


@interface MXLogger()
{
    mx_logger *_logger;
  
}
@end

@implementation MXLogger
-(instancetype)init{
    if (self == [super init]) {
        _logger = new mx_logger("");
    }
    return self;
}

- (void)dealloc
{
    delete _logger;
}
@end
