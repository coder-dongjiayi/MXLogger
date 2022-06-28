//
//  LogListViewController.m
//  MXLoggerDemo
//
//  Created by 董家祎 on 2022/6/24.
//

#import "LogListViewController.h"

@interface LogListViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic,strong)NSArray * dataSource;
@end

@implementation LogListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"mxloggertablecell"];
    
    /// demo 演示只读取时间最靠近的文件
    NSArray * array =   [MXLogger selectLogfilesWithDirectory:self.dirPath];

    NSString * path = [NSString stringWithFormat:@"%@%@",self.dirPath,array.firstObject[@"name"]];

 
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
       
        NSArray * result =  [MXLogger selectWithDiskCacheFilePath:path cryptKey:self.cryptKey iv:self.iv];
        self.dataSource = result;
        
    
        
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });

    });
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return  self.dataSource.count;
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 100;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"mxloggertablecell" forIndexPath:indexPath];
    NSDictionary *obj = self.dataSource[indexPath.row];
    NSString * msg = obj[@"msg"];
    NSString * tm = obj[@"timestamp"];
    NSString * tag = obj[@"tag"];
    NSString * name = obj[@"name"];
    NSString * level = obj[@"level"];
    NSString *  is_main = obj[@"is_main_thread"];
    NSString * threadId = obj[@"thread_id"];
    NSString * content = [NSString stringWithFormat:@"[%@] msg:%@,tag:%@,level:%@ thread_id=%@ is_main=%@ tm:%@,",name,msg,tag,level,threadId,is_main,tm];
    cell.textLabel.text = content;
    cell.textLabel.numberOfLines = 0;
    return cell;
}




@end
