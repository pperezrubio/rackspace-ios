//
//  LBNodeViewController.m
//  OpenStack
//
//  Created by Mike Mayo on 6/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "LBNodeViewController.h"
#import "LoadBalancerNode.h"
#import "LoadBalancer.h"
#import "UIViewController+Conveniences.h"
#import "RSTextFieldCell.h"
#import "UIColor+MoreColors.h"
#import "OpenStackAccount.h"
#import "AccountManager.h"
#import "APICallback.h"
#import "LoadBalancerViewController.h"

#define kConditionSection 0
#define kEnabled 0
#define kDraining 1
#define kDisabled 2

#define kRemoveNode 1

@implementation LBNodeViewController

@synthesize node, loadBalancer, account, lbViewController, lbIndexPath;

- (id)initWithNode:(LoadBalancerNode *)n loadBalancer:(LoadBalancer *)lb account:(OpenStackAccount *)a {
    self = [self initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.node = n;
        self.loadBalancer = lb;
        self.account = a;
    }
    return self;
}

- (void)dealloc {
    [node release];
    [loadBalancer release];
    [account release];
    [spinners release];
    [lbIndexPath release];
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = self.node.address;
    
    NSMutableArray *s = [[NSMutableArray alloc] initWithCapacity:3];
    for (int i = 0; i < 3; i++) {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        spinner.hidesWhenStopped = YES;
        [s addObject:spinner];
        [spinner release];
    }
    spinners = [[NSArray alloc] initWithArray:s];
    [s release];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self addDoneButton];
    }
    
    editable = YES;
    
    // if there is only one enabled node on the load balancer, it can't be
    // edited or deleted
    if ([self.loadBalancer.nodes count] == 1) {
        editable = NO;
    } else {
        NSInteger enabledCount = 0;
        for (LoadBalancerNode *n in self.loadBalancer.nodes) {
            if ([n.condition isEqualToString:@"ENABLED"]) {
                enabledCount++;
            }
        }
        
        if (enabledCount <= 1 && [self.node.condition isEqualToString:@"ENABLED"]) {
            editable = NO;
        }
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) || (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == kConditionSection) {
        return 3;
    } else {
        return 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == kConditionSection) {
        if (editable) {
            return @"Draining nodes are disabled after all current connections are completed.";
        } else {
            return @"There must be at least one enabled node for this load balancer.";
        }
    } else {
        return @"";
    }
}

- (UITableViewCell *)removeNodeCell {
    static NSString *CellIdentifier = @"RemoveNodeCell";    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.textLabel.textColor = editable ? [UIColor value1DetailTextLabelColor] : [UIColor lightGrayColor];
        cell.textLabel.text = @"Remove Node";
        cell.selectionStyle = editable ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
        
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kRemoveNode) {
        return [self removeNodeCell];
    } else {
        static NSString *CellIdentifier = @"Cell";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];            
        }
        
        cell.selectionStyle = editable ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
        
        switch (indexPath.row) {
            case kEnabled:
                cell.textLabel.text = @"Enabled";
                cell.textLabel.textColor = [UIColor blackColor];
                break;
            case kDraining:
                cell.textLabel.text = @"Draining";
                cell.textLabel.textColor = editable ? [UIColor blackColor] : [UIColor lightGrayColor];
                break;
            case kDisabled:
                cell.textLabel.text = @"Disabled";
                cell.textLabel.textColor = editable ? [UIColor blackColor] : [UIColor lightGrayColor];
                break;
            default:
                break;
        }
        
        if ([self.node.condition isEqualToString:[cell.textLabel.text uppercaseString]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.accessoryView = nil;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.accessoryView = [spinners objectAtIndex:indexPath.row];
        }
        
        return cell;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editable) {
        if (indexPath.section == kConditionSection) {
            
            if ([self.loadBalancer shouldBePolled]) {
                [self alert:nil message:@"This node can not be changed until the load balancer is in an active state."];                
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            } else {
                NSString *oldCondition = [NSString stringWithString:self.node.condition];
                
                switch (indexPath.row) {
                    case kEnabled:
                        self.node.condition = @"ENABLED";
                        break;
                    case kDraining:
                        self.node.condition = @"DRAINING";
                        break;
                    case kDisabled:
                        self.node.condition = @"DISABLED";
                        break;
                    default:
                        break;
                }
                
                // make the API call
                NSString *endpoint = [self.account loadBalancerEndpointForRegion:self.loadBalancer.region];
                [[spinners objectAtIndex:indexPath.row] startAnimating];
                APICallback *callback = [self.account.manager updateLBNode:self.node loadBalancer:self.loadBalancer endpoint:endpoint];
                
                [callback success:^(OpenStackRequest *request) {
                    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                    [NSTimer scheduledTimerWithTimeInterval:0.35 target:self.tableView selector:@selector(reloadData) userInfo:nil repeats:NO];
                } failure:^(OpenStackRequest *request) {
                    self.node.condition = oldCondition;
                    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                    [NSTimer scheduledTimerWithTimeInterval:0.35 target:self.tableView selector:@selector(reloadData) userInfo:nil repeats:NO];
                    [self alert:@"There was a problem changing the condition of this node." request:request];
                }];        
            }
            
        } else {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Are you sure you want to remove this node from the load balancer?" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:nil];
            sheet.delegate = self;
            [sheet showInView:self.view];
            [sheet release];
        }
    }
}

#pragma mark - Action Sheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        NSString *endpoint = [self.account loadBalancerEndpointForRegion:self.loadBalancer.region];
        APICallback *callback = [self.account.manager deleteLBNode:self.node loadBalancer:self.loadBalancer endpoint:endpoint];
        [callback success:^(OpenStackRequest *request) {
            [self.navigationController popViewControllerAnimated:YES];
        } failure:^(OpenStackRequest *request) {
            [self alert:@"There was a problem removing this node." request:request];
        }];
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:kRemoveNode];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Button Handlers

- (void)doneButtonPressed:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
    [self.lbViewController.tableView deselectRowAtIndexPath:self.lbIndexPath animated:YES];
}

@end
