//
//  LogListViewController.h
//  MXLoggerDemo
//
//  Created by 董家祎 on 2022/6/24.
//

#import <UIKit/UIKit.h>
#import <MXLogger/MXLogger.h>
NS_ASSUME_NONNULL_BEGIN

@interface LogListViewController : UIViewController
@property(nonatomic,strong)MXLogger * mxlogger;
@property(nonatomic,strong) NSString * cryptKey;
@property(nonatomic,strong)NSString * iv;
@end

NS_ASSUME_NONNULL_END
