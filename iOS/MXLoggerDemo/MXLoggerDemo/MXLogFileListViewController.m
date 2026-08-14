//
//  MXLogFileListViewController.m
//  MXLoggerDemo
//

#import "MXLogFileListViewController.h"
#import "MXLogFileCell.h"
#import "MXLogViewerViewController.h"
#import <MXLogger/MXLogger.h>

@interface MXLogFileListViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UILabel *summaryLabel;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *emptyLabel;

@property (nonatomic, copy) NSArray<NSDictionary *> *files;

@end

@implementation MXLogFileListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"日志文件";

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    [self.tableView registerNib:[UINib nibWithNibName:@"MXLogFileCell" bundle:nil]
         forCellReuseIdentifier:MXLogFileCellReuseId];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadFiles];
}

- (void)reloadFiles {
    // logFiles 返回: name / size / create_timestamp / last_timestamp
    NSArray<NSDictionary *> *files = [self.logger logFiles];

    // 按最后更新时间倒序，最新的文件排在最上面
    self.files = [files sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        double ta = [[a[@"last_timestamp"] description] doubleValue];
        double tb = [[b[@"last_timestamp"] description] doubleValue];
        if (ta == tb) return NSOrderedSame;
        return ta < tb ? NSOrderedDescending : NSOrderedAscending;
    }];

    unsigned long long totalSize = 0;
    for (NSDictionary *file in self.files) {
        totalSize += (unsigned long long)[[file[@"size"] description] longLongValue];
    }
    self.summaryLabel.text = [NSString stringWithFormat:@"共 %lu 个文件 · 总大小 %@",
                              (unsigned long)self.files.count, [self byteText:totalSize]];
    self.emptyLabel.hidden = self.files.count > 0;
    [self.tableView reloadData];
}

- (NSString *)byteText:(unsigned long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%llu B", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    return [NSString stringWithFormat:@"%.2f MB", bytes / 1024.0 / 1024.0];
}

- (NSString *)dateText:(id)timestamp {
    NSTimeInterval interval = [[timestamp description] doubleValue];
    if (interval <= 0) return timestamp ?: @"-";
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"MM-dd HH:mm:ss";
    });
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:interval]];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MXLogFileCell *cell = [tableView dequeueReusableCellWithIdentifier:MXLogFileCellReuseId forIndexPath:indexPath];
    NSDictionary *file = self.files[indexPath.row];
    NSString *dates = [NSString stringWithFormat:@"创建 %@ · 更新 %@",
                       [self dateText:file[@"create_timestamp"]],
                       [self dateText:file[@"last_timestamp"]]];
    [cell configureWithName:[file[@"name"] description]
                      dates:dates
                       size:[self byteText:(unsigned long long)[[file[@"size"] description] longLongValue]]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *file = self.files[indexPath.row];

    MXLogViewerViewController *viewer = [[MXLogViewerViewController alloc] initWithNibName:@"MXLogViewerViewController" bundle:nil];
    viewer.filePath = [self.logger.diskCachePath stringByAppendingString:file[@"name"] ?: @""];
    viewer.fileName = file[@"name"];
    viewer.cryptKey = self.cryptKey;
    viewer.iv = self.iv;
    [self.navigationController pushViewController:viewer animated:YES];
}

@end
