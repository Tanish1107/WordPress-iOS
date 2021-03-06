//
//  JetpackSettingsViewController.m
//  WordPress
//
//  Created by Eric Johnson on 8/24/12.
//  Copyright (c) 2012 WordPress. All rights reserved.
//

#import "JetpackSettingsViewController.h"
#import "Blog.h"
#import "SFHFKeychainUtils.h"
#import "WPWebViewController.h"
#import "ReachabilityUtils.h"

@interface JetpackSettingsViewController () <JetpackAuthUtilDelegate>

@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, strong) UITextField *usernameTextField;
@property (nonatomic, strong) UITextField *passwordTextField;
@property (nonatomic, strong) UITextField *lastTextField;
@property (nonatomic, retain) UITableViewTextFieldCell *usernameCell;
@property (nonatomic, retain) UITableViewTextFieldCell *passwordCell;
@property (nonatomic, strong) UITableViewActivityCell *verifyCredentialsActivityCell;
@property (nonatomic, strong) JetpackAuthUtil *jetpackAuthUtils;
@property (nonatomic, retain) NSString *footerText;
@property (nonatomic, retain) NSString *buttonText;

- (void)handleKeyboardDidShow:(NSNotification *)notification;
- (void)handleKeyboardWillHide:(NSNotification *)notification;
- (void)handleViewTapped;
- (void)configureTextField:(UITextField *)textField asPassword:(BOOL)asPassword;
- (void)testJetpack;
- (IBAction)cancel:(id)sender;
- (IBAction)save:(id)sender;

@end


@implementation JetpackSettingsViewController

@synthesize tableView;
@synthesize blog;
@synthesize username;
@synthesize password;
@synthesize usernameCell;
@synthesize passwordCell;
@synthesize usernameTextField;
@synthesize passwordTextField;
@synthesize lastTextField;
@synthesize verifyCredentialsActivityCell;
@synthesize footerText;
@synthesize buttonText;
@synthesize isCancellable;
@synthesize jetpackAuthUtils;
@synthesize delegate;

#define kCheckCredentials NSLocalizedString(@"Verify and Save Credentials", @"");
#define kCheckingCredentials NSLocalizedString(@"Verifing Credentials", @"");

#pragma mark -
#pragma mark LifeCycle Methods

- (void)dealloc {
    self.delegate = nil;
    
    [tableView release];
    [username release];
    [password release];
    [usernameCell release];
    [passwordCell release];
    [usernameTextField release];
    [passwordTextField release];
    [lastTextField release];
    [verifyCredentialsActivityCell release];
    jetpackAuthUtils.delegate = nil;
    [jetpackAuthUtils release];
    
    [super dealloc];
}


- (void)viewDidLoad {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"Jetpack Settings", @"");
    self.tableView.backgroundColor = [UIColor clearColor];
    if (IS_IPAD){
        self.tableView.backgroundView = nil;
        self.tableView.backgroundColor = [UIColor clearColor];
    }
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"welcome_bg_pattern.png"]];
    
    if (isCancellable) {
        UIBarButtonItem *barButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)] autorelease];
        self.navigationItem.leftBarButtonItem = barButton;
    }
    
    if (!blog || [blog isWPcom]) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Self-hosted Blog Required" message:@"A self-hosted blog was not specified when loading the settings screen." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alertView show];
        [alertView release];        
        return;
    }
            
    self.username = [JetpackAuthUtil getJetpackUsernameForBlog:blog];
    self.password = [JetpackAuthUtil getJetpackPasswordForBlog:blog];
        

    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", @"Save button to update Jetpack credentials") 
                                                                               style:UIBarButtonItemStyleDone 
                                                                              target:self 
                                                                              action:@selector(save:)] autorelease];

    self.footerText = kNeedJetpackLogIn;
	self.buttonText = kCheckCredentials;
    
    if (!IS_IPAD) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    }
    
    UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleViewTapped)];
    tgr.cancelsTouchesInView = NO;
    [tableView addGestureRecognizer:tgr];
    [tgr release];
}


- (void)viewDidUnload {
    [super viewDidUnload];
    
    self.tableView = nil;
    self.usernameCell = nil;
    self.passwordCell = nil;
    self.usernameTextField = nil;
    self.passwordTextField = nil;
    self.lastTextField = nil;
    self.verifyCredentialsActivityCell = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}


#pragma mark -
#pragma mark Instance Methods

- (void)configureTextField:(UITextField *)textField asPassword:(BOOL)asPassword {
    textField.keyboardType = UIKeyboardTypeDefault;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.delegate = self;   
    if (asPassword) {
        textField.secureTextEntry = YES;
    } else {
        textField.returnKeyType = UIReturnKeyNext;
    }
}


- (IBAction)cancel:(id)sender {
    if (isCancellable) {
        [self dismissModalViewControllerAnimated:YES];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }

    if (self.delegate){
        // If sender is not nil then the user tapped the cancel button.
        BOOL wascancelled = (sender != nil);
        [self.delegate controllerDidDismiss:self cancelled:wascancelled];
    }
}


- (IBAction)save:(id)sender {
    // Save without validating for the impatient folks.
    NSString *tmpUsername = usernameTextField.text;
    NSString *tmpPassword = passwordTextField.text;
    if (![username isEqualToString:tmpUsername] || ![tmpPassword isEqualToString:password]) {
        [JetpackAuthUtil setCredentialsForBlog:blog withUsername:tmpUsername andPassword:tmpPassword];
    }
    [self cancel:nil];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return 4;
}


- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 2;   // username, password
		default:
            return 1;   // test, install, more info
			break;
	}
	return 0;
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return 66.0f; // Enough room for 3 rows of text on the iphone in portrait orientation.
    }
    return 0.0f;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section < 1)
        return 44.0f;
    if (section == 2)
        return 60.0f;
    else
        return 0.0f;
}


- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return self.footerText;
    }
    return @"";
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"WordPress.com Credentials", @"");
    }
    return nil;
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 2) {
        NSString *labelText = labelText = NSLocalizedString(@"Need Jetpack? Tap below and search for 'Jetpack' to install it on your site.", @"");
        CGRect headerFrame = CGRectMake(0.0f, 0.0f, self.tableView.frame.size.width, 50.0f);
        UIView *footerView = [[[UIView alloc] initWithFrame:headerFrame] autorelease];
        footerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        CGFloat width = (IS_IPAD) ? 410.0f : 260.0f;
        CGFloat x = (headerFrame.size.width / 2.0f) - (width / 2.0f);
        
        UILabel *jetpackLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, 15.0f, width, 50.0f)];
        [jetpackLabel setBackgroundColor:[UIColor clearColor]];
        [jetpackLabel setTextColor:[UIColor colorWithRed:0.298039f green:0.337255f blue:0.423529f alpha:1.0f]];
        [jetpackLabel setShadowColor:[UIColor whiteColor]];
        [jetpackLabel setShadowOffset:CGSizeMake(0.0f, 1.0f)];
        [jetpackLabel setFont:[UIFont systemFontOfSize:15.0f]];
        [jetpackLabel setTextAlignment:UITextAlignmentCenter];
        [jetpackLabel setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
        
        CGSize maximumLabelSize = CGSizeMake(320.0f, 200.0f);
        CGSize labelSize = [labelText sizeWithFont:jetpackLabel.font constrainedToSize:maximumLabelSize lineBreakMode:jetpackLabel.lineBreakMode];
        
        CGRect newFrame = jetpackLabel.frame;
        newFrame.size.height = labelSize.height;
        jetpackLabel.frame = newFrame;
        [jetpackLabel setText:labelText];
        [jetpackLabel setNumberOfLines:0];
        [jetpackLabel sizeToFit];
        
        [footerView addSubview:jetpackLabel];
        [jetpackLabel release];
        
        return footerView;
    } else {
        return nil;
    }
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {    
    if (indexPath.section == 0) {
        if(indexPath.row == 0) {
            self.usernameCell = (UITableViewTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:@"usernameCell"];
            if (self.usernameCell == nil) {
                self.usernameCell = [[[UITableViewTextFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"usernameCell"] autorelease];
				self.usernameCell.textLabel.text = NSLocalizedString(@"Username", @"");
				usernameTextField = [self.usernameCell.textField retain];
				usernameTextField.placeholder = NSLocalizedString(@"WordPress.com username", @"");
                [self configureTextField:usernameTextField asPassword:NO];
                if (username != nil) 
                    usernameTextField.text = username;
			}
            return self.usernameCell;
        }
        else if(indexPath.row == 1) {
            self.passwordCell = (UITableViewTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:@"passwordCell"];
            if (self.passwordCell == nil) {
                self.passwordCell = [[[UITableViewTextFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"passwordCell"] autorelease];
				self.passwordCell.textLabel.text = NSLocalizedString(@"Password", @"");
				passwordTextField = [self.passwordCell.textField retain];
				passwordTextField.placeholder = NSLocalizedString(@"WordPress.com password", @"");
                [self configureTextField:passwordTextField asPassword:YES];
				if(password != nil)
					passwordTextField.text = password;
			}            
            return self.passwordCell;
        }
    } else if (indexPath.section == 1) {
        
        // Cell's reuse identifier is defined in its xib.
        UITableViewActivityCell *activityCell = (UITableViewActivityCell *)[tableView dequeueReusableCellWithIdentifier:@"CustomCell"];
        if (activityCell == nil) {
            NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"UITableViewActivityCell" owner:nil options:nil];
            for(id currentObject in topLevelObjects)
            {
                if([currentObject isKindOfClass:[UITableViewActivityCell class]])
                {
                    activityCell = (UITableViewActivityCell *)currentObject;
                    break;
                }
            }
        }
        if(isTesting) {
			[activityCell.spinner startAnimating];
			self.buttonText = kCheckingCredentials;
		}
		else {
			[activityCell.spinner stopAnimating];
            if (isTestSuccessful) {
                self.buttonText = NSLocalizedString(@"Credentials Verified", @"");
            } else {
                self.buttonText = kCheckCredentials;
            }
		}
		
		activityCell.textLabel.text = self.buttonText;
        if (isTesting) {
            activityCell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            activityCell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
        self.verifyCredentialsActivityCell = activityCell;
        
		return activityCell;
        
	} else if (indexPath.section == 2) {
        UITableViewActivityCell *activityCell = (UITableViewActivityCell *)[tableView dequeueReusableCellWithIdentifier:@"CustomCell"];
        if (activityCell == nil) {
            NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"UITableViewActivityCell" owner:nil options:nil];
            for(id currentObject in topLevelObjects)
            {
                if([currentObject isKindOfClass:[UITableViewActivityCell class]])
                {
                    activityCell = (UITableViewActivityCell *)currentObject;
                    break;
                }
            }
		}
		activityCell.textLabel.text = NSLocalizedString(@"Install Jetpack", @"");
        
		return activityCell;
    } else if (indexPath.section == 3) {
        UITableViewActivityCell *activityCell = (UITableViewActivityCell *)[tableView dequeueReusableCellWithIdentifier:@"CustomCell"];
        if (activityCell == nil) {
            NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"UITableViewActivityCell" owner:nil options:nil];
            for(id currentObject in topLevelObjects)
            {
                if([currentObject isKindOfClass:[UITableViewActivityCell class]])
                {
                    activityCell = (UITableViewActivityCell *)currentObject;
                    break;
                }
            }
		}
		activityCell.textLabel.text = NSLocalizedString(@"More Information", @"");
        
		return activityCell;
    }
    
    // We shouldn't reach this point, but return an empty cell just in case
    return [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"NoCell"] autorelease];
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tv cellForRowAtIndexPath:indexPath];
	if (indexPath.section == 0) {
        for(UIView *subview in cell.subviews) {
            if(subview.class == [UITextField class]) {
                [subview becomeFirstResponder];
                break;
            }
        }
	} 
    [tv deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.section) {
        case 0:
            
            break;
        case 1:
            if (isTesting) {
                break;
            }
            
            if([usernameTextField.text length] == 0) {
                self.footerText = NSLocalizedString(@"Username is required.", @"");
                self.buttonText = kCheckCredentials;
                [tv reloadData];
                
            } else if([passwordTextField.text length] == 0) {
                self.footerText = NSLocalizedString(@"Password is required.", @"");
                self.buttonText = kCheckCredentials;
                [tv reloadData];
                
            } else {
                
                if( ![ReachabilityUtils isInternetReachable] ) {
                    [ReachabilityUtils showAlertNoInternetConnection];
                    return;
                }
                
                if (lastTextField) {
                    [lastTextField resignFirstResponder];
                }
                self.footerText = NSLocalizedString(@"Checking credentials...", @"");
                self.buttonText = kCheckingCredentials;
                
                self.username = usernameTextField.text;
                self.password = passwordTextField.text;
                
                [NSThread sleepForTimeInterval:0.15];
                [tv reloadData];
                [self testJetpack];
                
            }
            break;
        case 2:
            if (blog) {
                NSString *jetpackURL = [blog.xmlrpc stringByReplacingOccurrencesOfString:@"xmlrpc.php" withString:@"wp-admin/plugin-install.php"];
                WPWebViewController *webViewController = nil;
                if ( IS_IPAD ) {
                    webViewController = [[[WPWebViewController alloc] initWithNibName:@"WPWebViewController-iPad" bundle:nil] autorelease];
                }
                else {
                    webViewController = [[[WPWebViewController alloc] initWithNibName:@"WPWebViewController" bundle:nil] autorelease];
                }
                [webViewController setUrl:[NSURL URLWithString:jetpackURL]];
                [webViewController setUsername:blog.username];
                [webViewController setPassword:[blog fetchPassword]];
                [webViewController setWpLoginURL:[NSURL URLWithString:blog.loginURL]];
                [self.navigationController pushViewController:webViewController animated:YES];
            } else {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"No Blog Yet" 
                                                                    message:NSLocalizedString(@"Please enter and save your blog's info before trying to install Jetpack.", @"") 
                                                                   delegate:nil 
                                                          cancelButtonTitle:@"OK" 
                                                          otherButtonTitles:nil, nil];
                [alertView show];
                [alertView release];
            }
            break;
        case 3:
        {
            WPWebViewController *webViewController = nil;
            if ( IS_IPAD ) {
                webViewController = [[[WPWebViewController alloc] initWithNibName:@"WPWebViewController-iPad" bundle:nil] autorelease];
            }
            else {
                webViewController = [[[WPWebViewController alloc] initWithNibName:@"WPWebViewController" bundle:nil] autorelease];
            }
            [webViewController setUrl:[NSURL URLWithString:@"http://ios.wordpress.org/faq/#faq_15"]];
//            [webViewController setUrl:[NSURL URLWithString:@"http://jetpack.me/about/"]];
            [self.navigationController pushViewController:webViewController animated:YES];
        }
            break; 
            
        default:
            break;
    }
}

#pragma mark -
#pragma mark UITextField methods

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.lastTextField = textField;
    
    if(isTestSuccessful && (textField == passwordTextField || textField == usernameTextField)){
        self.buttonText = kCheckCredentials
        isTestSuccessful = NO;
        verifyCredentialsActivityCell.textLabel.text = buttonText;
    }
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.returnKeyType == UIReturnKeyNext) {
        UITableViewCell *cell = (UITableViewCell *)[textField superview];
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        NSIndexPath *nextIndexPath = [NSIndexPath indexPathForRow:(indexPath.row + 1) inSection:indexPath.section];
        UITableViewCell *nextCell = [self.tableView cellForRowAtIndexPath:nextIndexPath];
        if (nextCell) {
            for (UIView *subview in [nextCell subviews]) {
                if ([subview isKindOfClass:[UITextField class]]) {
                    [subview becomeFirstResponder];
                    break;
                }
            }
        }
    }
	[textField resignFirstResponder];
	return NO;
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    UITableViewCell *cell = (UITableViewCell *)[textField superview];
    NSMutableString *result = [NSMutableString stringWithString:textField.text];
    [result replaceCharactersInRange:range withString:string];
    
    if ([result length] == 0) {
        cell.textLabel.textColor = WRONG_FIELD_COLOR;
    } else {
        cell.textLabel.textColor = GOOD_FIELD_COLOR;        
    }
    
    return YES;
}


#pragma mark -
#pragma mark Keyboard Related Methods

- (void)handleKeyboardDidShow:(NSNotification *)notification {
    CGRect rect = [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect frame = self.view.frame;
    if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
        frame.size.height -= rect.size.width;
    } else {
        frame.size.height -= rect.size.height;
    }
    self.view.frame = frame;
    
    CGPoint point = [tableView convertPoint:lastTextField.frame.origin fromView:lastTextField];
    if (!CGRectContainsPoint(frame, point)) {
        NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:point];
        [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}


- (void)handleKeyboardWillHide:(NSNotification *)notification {
    CGRect rect = [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect frame = self.view.frame;
    if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
        frame.size.height += rect.size.width;
    } else {
        frame.size.height += rect.size.height;
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        self.view.frame = frame;
    }];
}


- (void)handleViewTapped {
    [lastTextField resignFirstResponder];
}


#pragma mark -
#pragma mark Jetpack Related Methods

- (void)testJetpack {
    if (isTesting) return;
    
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    isTestSuccessful = NO;
    isTesting = YES;
    
    if (!jetpackAuthUtils) {
        self.jetpackAuthUtils = [[[JetpackAuthUtil alloc] init] autorelease];
        self.jetpackAuthUtils.delegate = self;
    }
    
    [jetpackAuthUtils validateCredentialsForBlog:blog withUsername:username andPassword:password];
}


#pragma mark -
#pragma mark JetpackUtilDelegate

- (void)jetpackAuthUtil:(JetpackAuthUtil *)util didValidateCredentailsForBlog:(Blog *)aBlog {
    // Yay! Show that we passed validation.
    isTesting = NO;
    isTestSuccessful = YES;
    self.footerText = kNeedJetpackLogIn;
    
    [tableView reloadData];
}


- (void)jetpackAuthUtil:(JetpackAuthUtil *)util noRecordForBlog:(Blog *)blog {
    isTesting = NO;
    
    self.footerText = NSLocalizedString(@"Unable to retrieve stats. Either the blog is not connected to Jetpack, or it's connected to a different account.", @"");
    [tableView reloadData];
}


- (void)jetpackAuthUtil:(JetpackAuthUtil *)util errorValidatingCredentials:(Blog *)blog withError:(NSString *)errorMessage {
    isTesting = NO;
    
    self.footerText = errorMessage;
    [tableView reloadData];
}


@end
