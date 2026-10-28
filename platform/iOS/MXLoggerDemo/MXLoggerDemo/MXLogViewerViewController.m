//
//  MXLogViewerViewController.m
//  MXLoggerDemo
//

#import "MXLogViewerViewController.h"
#import "MXDemoL10n.h"
#import "MXLogRecordCell.h"
#import <MXLogger/MXLogger.h>

@interface MXLogViewerViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>

@property (weak, nonatomic) IBOutlet UISegmentedControl *levelSegment;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *emptyLabel;
@property (weak, nonatomic) IBOutlet UIStackView *loadingView;
@property (weak, nonatomic) IBOutlet UILabel *loadingLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingIndicator;

@property (nonatomic, copy) NSArray<NSDictionary *> *allRecords;       // 解析出的全部日志
@property (nonatomic, copy) NSArray<NSDictionary *> *filteredRecords;  // 筛选后

@end

@implementation MXLogViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.fileName ?: MXDemoStr(@"viewer.title");
    [self.levelSegment setTitle:MXDemoStr(@"viewer.segment.all") forSegmentAtIndex:0];
    self.searchBar.placeholder = MXDemoStr(@"viewer.search.placeholder");
    self.emptyLabel.text = MXDemoStr(@"viewer.empty");
    self.loadingLabel.text = MXDemoStr(@"viewer.loading");

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 88;
    [self.tableView registerNib:[UINib nibWithNibName:@"MXLogRecordCell" bundle:nil]
         forCellReuseIdentifier:MXLogRecordCellReuseId];
    self.searchBar.delegate = self;

    [self loadRecords];
}

- (void)loadRecords {
    // 大文件解析可能耗时较长，解析期间展示 loading，解析放在后台线程避免卡 UI
    self.emptyLabel.hidden = YES;
    self.loadingView.hidden = NO;
    [self.loadingIndicator startAnimating];
    self.levelSegment.enabled = NO;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // 解析(解密) mmap 日志文件为字典数组
        // 字段: name / msg / tag / level / timestamp / is_main_thread / thread_id / error_code
        NSArray *records = [MXLogger selectWithDiskCacheFilePath:self.filePath
                                                        cryptKey:self.cryptKey
                                                              iv:self.iv];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allRecords = records;
            [self.loadingIndicator stopAnimating];
            self.loadingView.hidden = YES;
            self.levelSegment.enabled = YES;
            self.title = self.fileName
                ? [NSString stringWithFormat:@"%@ (%lu)", self.fileName, (unsigned long)records.count]
                : MXDemoStr(@"viewer.title");
            [self applyFilter];
        });
    });
}

#pragma mark - 筛选

- (void)applyFilter {
    NSInteger segment = self.levelSegment.selectedSegmentIndex;
    NSString *keyword = self.searchBar.text;

    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *record, NSDictionary *bindings) {
        if (segment > 0 && [record[@"level"] integerValue] != segment - 1) return NO;
        if (keyword.length > 0) {
            NSString *haystack = [NSString stringWithFormat:@"%@ %@ %@",
                                  record[@"msg"] ?: @"", record[@"name"] ?: @"", record[@"tag"] ?: @""];
            if ([haystack rangeOfString:keyword options:NSCaseInsensitiveSearch].location == NSNotFound) return NO;
        }
        return YES;
    }];
    self.filteredRecords = [self.allRecords filteredArrayUsingPredicate:predicate];
    self.emptyLabel.hidden = self.filteredRecords.count > 0;
    [self.tableView reloadData];
}

- (IBAction)segmentChanged:(id)sender {
    [self applyFilter];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applyFilter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.searchBar resignFirstResponder];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredRecords.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MXLogRecordCell *cell = [tableView dequeueReusableCellWithIdentifier:MXLogRecordCellReuseId forIndexPath:indexPath];
    [cell configureWithRecord:self.filteredRecords[indexPath.row]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // 长内容(如 JSON 日志)弹窗查看完整信息
    NSDictionary *record = self.filteredRecords[indexPath.row];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:record[@"name"] ?: MXDemoStr(@"viewer.title")
                                                                   message:record[@"msg"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:MXDemoStr(@"common.copy") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = record[@"msg"] ?: @"";
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:MXDemoStr(@"common.close") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
