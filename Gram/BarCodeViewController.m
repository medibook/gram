//
//  BarCodeViewController.m
//  Gram
//
//  Created by Yoshimura Kenya on 2012/08/22.
//  Copyright (c) 2012年 Yoshimura Kenya. All rights reserved.
//

#import "BarCodeViewController.h"
#import "ExportTypeViewController.h"
#import "GramContext.h"
#import "ZXBarcodeFormat.h"
#import "ZXBitMatrix.h"
#import "ZXImage.h"
#import "ZXMultiFormatWriter.h"
#import "ZXEncodeHints.h"
#import "UITabBarWithAdController.h"

@interface NSString (NSString_Extended)
- (NSString *)urlencode;
- (NSString *)matchWithPattern:(NSString *)pattern;
- (NSString *)matchWithPattern:(NSString *)pattern options:(NSInteger)options;
- (NSString *)matchWithPattern:(NSString *)pattern replace:(NSString *)replace;
- (NSString *)matchWithPattern:(NSString *)pattern replace:(NSString *)replace options:(NSInteger)options;
@end

@interface BarCodeViewController ()
{
    NSMutableArray *labels;
    NSMutableArray *values;
    NSString *branch;
    NSMutableArray *branches;
    NSIndexPath *lastIndexPath;
    CGRect frame;
    BOOL isRegenerate;
}

@end

@implementation BarCodeViewController
@synthesize phase = _phase;
@synthesize tableView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    frame = [self.tableView frame];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    
    [GramContext get]->exportModeFromHistory = nil;
    [GramContext get]->exportMode = nil;
    
    if (![_phase isEqualToString:@"history"])
    {
        [GramContext get]->generated = nil;
        if ([[GramContext get]->exportCondition isEqualToString:@"連絡先"] || [[GramContext get]->exportCondition isEqualToString:@"イベント"])
        {
            [self createCodeFromString:[self convertString:[GramContext get]->encodeString category:[GramContext get]->exportCondition format:[self getDefaultCondition:[GramContext get]->exportCondition]] codeFormat:kBarcodeFormatQRCode width:280 height:280];
            
            [self buildFromData:[GramContext get]->generated exportMode:[GramContext get]->exportMode];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    if (lastIndexPath != nil)
    {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:lastIndexPath];
        if ([_phase isEqualToString:@"history"])
        {
            cell.detailTextLabel.text = [GramContext get]->exportModeFromHistory;
        }
        else
        {
            cell.detailTextLabel.text = [GramContext get]->exportMode;
        }
        
        [self.tableView deselectRowAtIndexPath:lastIndexPath animated:YES];
    }
    
    if ([_phase isEqualToString:@"history"])
    {
        [self buildFromData:[GramContext get]->encodeFromHistory exportMode:[GramContext get]->exportModeFromHistory];
    }
    else if ([GramContext get]->exportMode == nil)
    {
        if ([GramContext get]->generated == nil)
        {
            [self createCodeFromString:[self convertString:[GramContext get]->encodeString category:[GramContext get]->exportCondition format:[self getDefaultCondition:[GramContext get]->exportCondition]] codeFormat:kBarcodeFormatQRCode width:280 height:280];
        }
        
        [self buildFromData:[GramContext get]->generated exportMode:[GramContext get]->exportMode];
    }
    else
    {
        [self buildFromData:[GramContext get]->generated exportMode:[GramContext get]->exportMode];
    }
    
    UITabBarWithAdController *tabBar = (UITabBarWithAdController *)self.tabBarController;
    tabBar.delegate = self;
    
    if (tabBar.bannerIsVisible)
    {
        [self.tableView setFrame:CGRectMake(frame.origin.x,
                                            frame.origin.y,
                                            frame.size.width,
                                            frame.size.height - 93 -  49)];
    }
    else
    {
        [self.tableView setFrame:CGRectMake(frame.origin.x,
                                            frame.origin.y,
                                            frame.size.width,
                                            frame.size.height - 93)];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    UITabBarWithAdController *tabBar = (UITabBarWithAdController *)self.tabBarController;
    if (tabBar.delegate != self)
    {
        tabBar.delegate = self;
        
        if (tabBar.bannerIsVisible)
        {
            [self.tableView setFrame:CGRectMake(frame.origin.x,
                                                frame.origin.y,
                                                frame.size.width,
                                                frame.size.height - 93 -  49)];
        }
        else
        {
            [self.tableView setFrame:CGRectMake(frame.origin.x,
                                                frame.origin.y,
                                                frame.size.width,
                                                frame.size.height - 93)];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    UITabBarWithAdController *tabBar = (UITabBarWithAdController *)self.tabBarController;
    if (tabBar.delegate == self)
    {
        tabBar.delegate = nil;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSString *)getDefaultCondition:(NSString *)condition
{
    if ([condition isEqualToString:@"場所"])
    {
        return @"WGS84";
    }
    else if ([condition isEqualToString:@"連絡先"])
    {
        return @"vCard";
    }
    else if ([condition isEqualToString:@"イベント"])
    {
        return @"iCalendar";
    }
    return @"標準";
}

- (NSString *)convertString:(NSString *)origin category:(NSString *)category format:(NSString *)format
{
    NSString *tmp = nil;
    NSString *string = [NSString stringWithFormat:@"%@", origin];
    if ([category isEqualToString:@"連絡先"])
    {
        if ([format isEqualToString:@"meCard"] || [format isEqualToString:@"docomo"])
        {
            tmp = [(NSString *)[string matchWithPattern:@"\nN:[^ \t\r\n　]+"] matchWithPattern:@"\nN:" replace:@""];
            NSArray *name = [tmp componentsSeparatedByString:@";"];
            NSArray *sound = [NSArray arrayWithObjects:[(NSString *)[string matchWithPattern:@"\nX-PHONETIC-LAST-NAME:[^ \t\r\n　]+"] matchWithPattern:@"\nX-PHONETIC-LAST-NAME:" replace:@""], [(NSString *)[string matchWithPattern:@"\nX-PHONETIC-FIRST-NAME:[^ \t\r\n　]+"] matchWithPattern:@"\nX-PHONETIC-FIRST-NAME:" replace:@""], nil];
            string = [[string matchWithPattern:@"\nitem[0-9]+.[^;]+\n" replace:@"\n"] matchWithPattern:@"\nitem[0-9]+." replace:@"\n"];
            //[HOME|WORK|PREF|VOICE|FAX|MSG|CELL|PAGER|BBS|MODEM|CAR|ISDN|VIDEO|PCS];
            NSMutableArray *emails = [NSMutableArray array];
            while ([string matchWithPattern:@"EMAIL;"]) {
                [emails addObject:[[string matchWithPattern:@"\nEMAIL;[^\t\r\n]+"] matchWithPattern:@"\nEMAIL.*:" replace:@""]];
                NSString *match = [string matchWithPattern:@"\nEMAIL;[^\t\r\n]+"];
                string = [string matchWithPattern:[NSString stringWithFormat:@"%@", match] replace:@"\n"];
            }
            NSMutableArray *tels = [NSMutableArray array];
            while ([string matchWithPattern:@"TEL;"]) {
                [tels addObject:[[string matchWithPattern:@"\nTEL;[^\t\r\n]+"] matchWithPattern:@"\nTEL.*:" replace:@""]];
                NSString *match = [string matchWithPattern:@"\nTEL;[^\t\r\n]+"];
                string = [string matchWithPattern:[NSString stringWithFormat:@"%@", match] replace:@"\n"];
            }
            tmp = [NSString stringWithFormat:@"MECARD:N:%@,%@;SOUND:%@,%@;", [name objectAtIndex:1], [name objectAtIndex:0], [sound objectAtIndex:0], [sound objectAtIndex:1]];
            for (NSString *tel in tels)
            {
                tmp = [NSString stringWithFormat:@"%@TEL:%@;", tmp, tel];
            }
            for (NSString *email in emails)
            {
                tmp = [NSString stringWithFormat:@"%@EMAIL:%@;", tmp, email];
            }
            tmp = [NSString stringWithFormat:@"%@;", tmp];
        }
        else if ([format isEqualToString:@"au/Softbank"])
        {
            tmp = [(NSString *)[string matchWithPattern:@"\nN:[^ \t\r\n　]+"] matchWithPattern:@"\nN:" replace:@""];
            NSArray *array = [tmp componentsSeparatedByString:@";"];
            NSString *name = [NSString stringWithFormat:@"%@ %@", [array objectAtIndex:0], [array objectAtIndex:1]];
            NSString *sound = [NSString stringWithFormat:@"%@ %@",
                               [(NSString *)[string matchWithPattern:@"\nX-PHONETIC-LAST-NAME:[^ \t\r\n　]+"] matchWithPattern:@"\nX-PHONETIC-LAST-NAME:" replace:@""], [(NSString *)[string matchWithPattern:@"\nX-PHONETIC-FIRST-NAME:[^ \t\r\n　]+"] matchWithPattern:@"\nX-PHONETIC-FIRST-NAME:" replace:@""]];
            tmp = [NSString stringWithFormat:@"MEMORY:\nNAME1:%@\nNAME2:%@", name, sound];
            string = [[string matchWithPattern:@"\nitem[0-9]+.[^;]+\n" replace:@"\n"] matchWithPattern:@"\nitem[0-9]+." replace:@"\n"];
            NSMutableArray *emails = [NSMutableArray array];
            while ([string matchWithPattern:@"EMAIL;"]) {
                [emails addObject:[[string matchWithPattern:@"\nEMAIL;[^\t\r\n]+"] matchWithPattern:@"\nEMAIL.*:" replace:@""]];
                NSString *match = [string matchWithPattern:@"\nEMAIL;[^\t\r\n]+"];
                string = [string matchWithPattern:[NSString stringWithFormat:@"%@", match] replace:@"\n"];
            }
            NSMutableArray *tels = [NSMutableArray array];
            while ([string matchWithPattern:@"TEL;"]) {
                [tels addObject:[[string matchWithPattern:@"\nTEL;[^\t\r\n]+"] matchWithPattern:@"\nTEL.*:" replace:@""]];
                NSString *match = [string matchWithPattern:@"\nTEL;[^\t\r\n]+"];
                string = [string matchWithPattern:[NSString stringWithFormat:@"%@", match] replace:@"\n"];
            }
            NSInteger index = 0;
            for (NSString *tel in tels)
            {
                tmp = [NSString stringWithFormat:@"%@\nTEL%d:%@", tmp, ++index, tel];
            }
            index = 0;
            for (NSString *email in emails)
            {
                tmp = [NSString stringWithFormat:@"%@\nMAIL%d:%@", tmp, ++index, email];
            }
        }
        else
        {
            tmp = [[string matchWithPattern:@"\nitem[0-9]+.[^;]+\n" replace:@"\n"] matchWithPattern:@"\nitem[0-9]+." replace:@"\n"];
        }
        return tmp;
    }
    else if ([category isEqualToString:@"イベント"])
    {
        return string;
    }
    else if ([category isEqualToString:@"電話番号"])
    {
        if ([format isEqualToString:@"au/Softbank"])
        {
            tmp = [string matchWithPattern:@"tel:" replace:@"TEL:"];
        }
        else if ([format isEqualToString:@"docomo"])
        {
            tmp = [string matchWithPattern:@"tel:" replace:@""];
        }
        else
        {
            return string;
        }
        return tmp;
    }
    else if ([category isEqualToString:@"Eメール"])
    {
        if ([format isEqualToString:@"au/Softbank"])
        {
            tmp = [string matchWithPattern:@"mailto:" replace:@"MAILTO:"];
            tmp = [tmp matchWithPattern:@"body:" replace:@"BODY:"];
            tmp = [tmp matchWithPattern:@"subject:" replace:@"SUBJECT:"];
        }
        else if ([format isEqualToString:@"docomo"])
        {
            tmp = [string matchWithPattern:@"mailto:" replace:@"MATMSG:TO:"];
            tmp = [tmp matchWithPattern:@"body:" replace:@";BODY:"];
            tmp = [tmp matchWithPattern:@"subject:" replace:@";SUB:"];
            tmp = [NSString stringWithFormat:@"%@;;", tmp];
        }
        else
        {
            return string;
        }
        return tmp;
    }
    else if ([category isEqualToString:@"場所"])
    {
        return string;
    }
    else if ([category isEqualToString:@"SMS"])
    {
        return string;
    }
    else if ([category isEqualToString:@"URL"])
    {
        return string;
    }
    else if ([category isEqualToString:@"テキスト"])
    {
        return string;
    }
    else if ([category isEqualToString:@"クリップボードの内容"])
    {
        return string;
    }
    else if ([category isEqualToString:@"Wi-Fiネットワーク"])
    {
        return string;
    }
    
    return nil;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [labels count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[labels objectAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"selectableCell"];
    
    cell.textLabel.text = [[labels objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    cell.detailTextLabel.text = [[values objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    return cell;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 320;
    }
    
    return tableView.sectionHeaderHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    lastIndexPath = indexPath;
    [self performSegueWithIdentifier:@"detailSegue" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if (_phase == nil)
    {
        _phase = @"generate";
    }
    
    NSString *current = [NSString stringWithFormat:@"%@->detail", _phase];
    if ([segue.identifier isEqualToString:@"detailSegue"])
    {
        NSLog(@"tether: %@ detailSegue", current);
        
        ExportTypeViewController *view = segue.destinationViewController;
        view.phase = current;
        view.label = branch;
        view.labels = [branches copy];
    }
}

#pragma mark - custom methods

- (void)buildFromData:(NSDictionary *)data exportMode:(NSString *)context
{
    isRegenerate = NO;
    self.navigationItem.title = @"コード";
    
    if ([self.tableView viewWithTag:1] != nil)
        [[self.tableView viewWithTag:1] removeFromSuperview];
    if ([self.tableView viewWithTag:2] != nil)
        [[self.tableView viewWithTag:2] removeFromSuperview];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 20, 280, 280)];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.tag = 1;
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(15, 300, 290, 50)];
    textView.font = [UIFont boldSystemFontOfSize:14.0f];
    textView.textColor = [UIColor blackColor];
    textView.backgroundColor = [UIColor clearColor];
    textView.editable = NO;
    textView.tag = 2;
    
    if (data != nil)
    {
        labels = [NSMutableArray arrayWithObjects:[NSMutableArray arrayWithObjects:@"エクスポート形式", nil], nil];
        values = [NSMutableArray arrayWithObjects:[NSMutableArray array], nil];
        NSLog(@"context %@", context);
        if (context == nil)
        {
            if ([[data objectForKey:@"category"] isEqualToString:@"場所"])
            {
                context = @"WGS84";
                branches = [NSMutableArray arrayWithObjects:[NSMutableArray arrayWithObjects:@"WGS84", nil], nil];
            }
            else if ([[data objectForKey:@"category"] isEqualToString:@"連絡先"])
            {
                context = @"vCard";
                branches = [NSMutableArray arrayWithObjects:[NSMutableArray arrayWithObjects:@"meCard", @"vCard", @"docomo", @"au/Softbank", nil], nil];
            }
            else if ([[data objectForKey:@"category"] isEqualToString:@"イベント"])
            {
                context = @"iCalendar";
                branches = [NSMutableArray arrayWithObjects:[NSMutableArray arrayWithObjects:@"iCalendar", nil], nil];
            }
            else
            {
                context = @"標準";
                if ([[data objectForKey:@"category"] isEqualToString:@"電話番号"] || [[data objectForKey:@"category"] isEqualToString:@"Eメール"])
                {
                    branches = [NSMutableArray arrayWithObjects:[NSMutableArray arrayWithObjects:@"標準", @"docomo", @"au/Softbank", nil], nil];
                }
                else if ([[data objectForKey:@"category"] isEqualToString:@"URL"])
                {
                    branches = [NSMutableArray arrayWithObjects:[NSMutableArray arrayWithObjects:@"標準", @"docomo", nil], nil];
                }
                else
                {
                    branches = [NSMutableArray arrayWithObjects:[NSMutableArray arrayWithObjects:@"標準", nil], nil];
                }
            }
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentDirectory = [paths objectAtIndex:0];
            NSURL *entryURL = [NSURL fileURLWithPath:[documentDirectory stringByAppendingPathComponent:[data objectForKey:@"image"]]];
            
            UIImage *image = [UIImage imageWithContentsOfFile:[entryURL path]];
            
            imageView.image = image;
        }
        else
        {
            isRegenerate = YES;
            NSLog(@"regenerate %@", [self convertString:[data objectForKey:@"text"] category:[data objectForKey:@"category"] format:context]);
            imageView.image = [self createCodeFromString:[self convertString:[data objectForKey:@"text"] category:[data objectForKey:@"category"] format:context] codeFormat:kBarcodeFormatQRCode width:280 height:280];
        }
        branch = context;
        [[values objectAtIndex:0] addObject:branch];
        
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat  = @"yyyy/MM/dd HH:mm";
        NSString *result = [data objectForKey:@"text"];
        NSDate *date = [data objectForKey:@"date"];
        textView.text = [NSString stringWithFormat:@"encode:\n%@", result];
        textView.text = [NSString stringWithFormat:@"%@\n\ninformation:\n%@", textView.text, [df stringFromDate:date]];
        
        if ([data objectForKey:@"location"] != nil)
        {
            CLLocation *location = [NSKeyedUnarchiver unarchiveObjectWithData:[data objectForKey:@"location"]];
            CLLocationCoordinate2D coordinate = location.coordinate;
            textView.text = [NSString stringWithFormat:@"%@\n%@", textView.text, [NSString stringWithFormat:@"%f, %f", coordinate.latitude, coordinate.longitude]];
        }
        
        if ([_phase isEqualToString:@"history"])
        {
            [GramContext get]->exportModeFromHistory = context;
        }
        else
        {
            [GramContext get]->exportMode = context;
        }
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:@"生成できません"
                              message:@"データ量超過のため、キャンセルされました"
                              delegate:self
                              cancelButtonTitle:@"キャンセル"
                              otherButtonTitles:nil];
        [alert show];
    }
    
    [self.tableView addSubview:imageView];
}

- (UIImage *)createCodeFromString:(NSString *)string codeFormat:(NSInteger)format width:(NSInteger)width height:(NSInteger)height
{
    if (string && ![string isEqualToString:@""])
    {
        NSLog(@"encode %@", string);
        ZXMultiFormatWriter *writer = [ZXMultiFormatWriter writer];
        ZXEncodeHints *hints = [ZXEncodeHints new];
        hints.encoding = NSUTF8StringEncoding;
        if (format == kBarcodeFormatQRCode)
        {
            NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
            NSString *level = [settings objectForKey:@"QR_ERROR_CORRECTION_LEVEL"];
            ZXErrorCorrectionLevel *errorCorrectionLevel = [ZXErrorCorrectionLevel errorCorrectionLevelM];
            if ([level isEqualToString:@"L"])
            {
                errorCorrectionLevel = [ZXErrorCorrectionLevel errorCorrectionLevelL];
            }
            else if ([level isEqualToString:@"Q"])
            {
                errorCorrectionLevel = [ZXErrorCorrectionLevel errorCorrectionLevelQ];
            }
            else if ([level isEqualToString:@"H"])
            {
                errorCorrectionLevel = [ZXErrorCorrectionLevel errorCorrectionLevelH];
            }
            
            hints.errorCorrectionLevel = errorCorrectionLevel;
        }
        
        NSError *err;
        ZXBitMatrix *result = [writer encode:string format:format width:width height:height hints:hints error:&err];
        //NSLog(@"string:%@, result:%@, err:%@", string, result, err);
        if (result)
        {
            UIImage *code = [UIImage imageWithCGImage:[ZXImage imageWithMatrix:result].cgimage];
            
            if (isRegenerate)
            {
                isRegenerate = NO;
                return code;
            }
            
            NSDate *date = [NSDate date];
            
            CLLocation *location = nil;
            NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
            if ([settings boolForKey:@"USE_LOCATION"])
            {
                if ([CLLocationManager locationServicesEnabled])
                {
                    if ([GramContext get]->location)
                    {
                        location = [GramContext get]->location;
                    }
                }
            }
            
            NSData *imageData = UIImagePNGRepresentation(code);
            NSString *name = [NSString stringWithFormat:@"%f", [date timeIntervalSinceReferenceDate]];
            [self save:imageData name:name];
            
            NSArray *keys = [NSArray arrayWithObjects:@"type", @"category", @"image", @"format", @"text", @"date", @"location", nil];
            NSArray *datas = [NSArray arrayWithObjects:@"encode", [GramContext get]->exportCondition, name, [NSNumber numberWithInt:format], string, date, [NSKeyedArchiver archivedDataWithRootObject:location], nil];
            [GramContext get]->generated = [NSDictionary dictionaryWithObjects:datas forKeys:keys];
            [[GramContext get]->history insertObject:[GramContext get]->generated atIndex:0];
            
            [settings setObject:[[GramContext get]->history copy] forKey:@"HISTORY"];
            [settings synchronize];
            
            return code;
        }
    }
    
    return nil;
}

- (void)save:(NSData *)image name:(NSString *)name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSString *path = [documentDirectory stringByAppendingPathComponent:name];
    [image writeToFile:path atomically:YES];
}


#pragma mark - action sheet delegate

- (IBAction)tapAction:(id)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:@""
                                  delegate:self
                                  cancelButtonTitle:@"キャンセル"
                                  destructiveButtonTitle:nil
                                  otherButtonTitles:@"画像を保存する", nil];
    [actionSheet showInView:self.tabBarController.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex)
    {
        default:
            break;
    }
}

#pragma mark - custom delegete

- (void)bannerIsInvisible
{
    NSLog(@"delegate bannerIsInvisible");
    [UIView beginAnimations:@"ad" context:nil];
    [self.tableView setFrame:CGRectMake(frame.origin.x,
                                        frame.origin.y,
                                        frame.size.width,
                                        frame.size.height - 93)];
    [UIView commitAnimations];
}

- (void)bannerIsVisible
{
    NSLog(@"delegate bannerIsVisible");
    [UIView beginAnimations:@"ad" context:nil];
    [self.tableView setFrame:CGRectMake(frame.origin.x,
                                        frame.origin.y,
                                        frame.size.width,
                                        frame.size.height - 93 - 49)];
    [UIView commitAnimations];
}

@end
