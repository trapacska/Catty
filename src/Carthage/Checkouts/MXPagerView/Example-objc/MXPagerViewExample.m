// MXPagerViewExample.m
//
// Copyright (c) 2017 Maxime Epain
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MXPagerViewExample.h"
#import <MXPagerView/MXPagerView.h>

#define SPANISH_WHITE [UIColor colorWithRed:0.996 green:0.992 blue:0.941 alpha:1] /*#fefdf0*/

@interface MXPagerViewExample () <MXPagerViewDelegate, MXPagerViewDataSource, UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet MXPagerView *pagerView;
@property (nonatomic, strong) UITableView   *tableView;
@property (nonatomic, strong) UIWebView     *webView;
@end

@implementation MXPagerViewExample

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Page 0";
    
    self.pagerView.gutterWidth = 20;
    
    //Register UITextView as page
    [self.pagerView registerClass:[UITextView class] forPageReuseIdentifier:@"TextPage"];
}

- (IBAction)previous:(id)sender {
    [self.pagerView showPageAtIndex:(self.pagerView.indexForSelectedPage - 1) animated:YES];
}

- (IBAction)next:(id)sender {
    [self.pagerView showPageAtIndex:(self.pagerView.indexForSelectedPage + 1) animated:YES];
}

#pragma mark Properties

- (UITableView *)tableView {
    if (!_tableView) {
        //Add a table page
        _tableView = [[UITableView alloc] init];
        _tableView.delegate = self;
        _tableView.dataSource = self;
    }
    return _tableView;
}

- (UIWebView *)webView {
    if (!_webView) {
        // Add a web page
        _webView = [[UIWebView alloc] init];
        NSURL *url = [NSURL URLWithString:@"http://www.aesop.com/"];
        NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        [_webView loadRequest:urlRequest];
    }
    return _webView;
}

#pragma mark <MXPagerViewDelegate>

- (void)pagerView:(nonnull MXPagerView *)pagerView didMoveToPage:(nonnull UIView *)page atIndex:(NSInteger)index {
    self.navigationItem.title = [NSString stringWithFormat:@"Page %li", index];
}

#pragma mark <MXPagerViewDataSource>

- (NSInteger)numberOfPagesInPagerView:(MXPagerView *)pagerView {
    return 10;
}

- (UIView *)pagerView:(MXPagerView *)pagerView viewForPageAtIndex:(NSInteger)index {
    if (index < 2) {
        return @[self.tableView, self.webView][index];
    }
    
    //Dequeue reusable page
    UITextView *page = [self.pagerView dequeueReusablePageWithIdentifier:@"TextPage"];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"LongText" ofType:@"txt"];
    page.text = [[NSString alloc] initWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    page.backgroundColor = SPANISH_WHITE;
    
    return page;
}

#pragma mark <UITableViewDelegate>

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger index = (indexPath.row % 2) + 1;
    [self.pagerView showPageAtIndex:index animated:YES];
}

#pragma mark <UITableViewDataSource>

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.textLabel.text = (indexPath.row % 2)? @"Text": @"Web";
    cell.backgroundColor = SPANISH_WHITE;
    
    return cell;
}

@end
