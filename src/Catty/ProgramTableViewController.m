/**
 *  Copyright (C) 2010-2014 The Catrobat Team
 *  (http://developer.catrobat.org/credits)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Affero General Public License as
 *  published by the Free Software Foundation, either version 3 of the
 *  License, or (at your option) any later version.
 *
 *  An additional term exception under section 7 of the GNU Affero
 *  General Public License, version 3, is available at
 *  (http://developer.catrobat.org/license_additional_term)
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU Affero General Public License for more details.
 *
 *  You should have received a copy of the GNU Affero General Public License
 *  along with this program.  If not, see http://www.gnu.org/licenses/.
 */

#import "ProgramTableViewController.h"
#import "TableUtil.h"
#import "ObjectTableViewController.h"
#import "SegueDefines.h"
#import "Program.h"
#import "Look.h"
#import "Sound.h"
#import "Brick.h"
#import "ObjectTableViewController.h"
#import "CatrobatImageCell.h"
#import "DarkBlueGradientImageDetailCell.h"
#import "Util.h"
#import "UIDefines.h"
#import "ProgramDefines.h"
#import "ProgramLoadingInfo.h"
#import "Script.h"
#import "Brick.h"
#import "ActionSheetAlertViewTags.h"
#import "ScenePresenterViewController.h"
#import "FileManager.h"
#import "UIColor+CatrobatUIColorExtensions.h"
#import "UIImageView+CatrobatUIImageViewExtensions.h"
#import "ProgramUpdateDelegate.h"
#import "SensorHandler.h"
#import "CellTagDefines.h"
#import "AppDelegate.h"
#import "LanguageTranslationDefines.h"
#import "ProgramTableHeaderView.h"
#import "RuntimeImageCache.h"
#import "CatrobatActionSheet.h"
#import "DataTransferMessage.h"
#import "NSMutableArray+CustomExtensions.h"

// TODO: outsource...
#define kUserDetailsShowDetailsKey @"showDetails"
#define kUserDetailsShowDetailsObjectsKey @"detailsForObjects"

@interface ProgramTableViewController () <CatrobatActionSheetDelegate, UINavigationBarDelegate, SWTableViewCellDelegate>
@property (nonatomic) BOOL useDetailCells;
@end

@implementation ProgramTableViewController

#pragma mark - data helpers
static NSCharacterSet *blockedCharacterSet = nil;
- (NSCharacterSet*)blockedCharacterSet
{
    if (! blockedCharacterSet) {
        blockedCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:kTextFieldAllowedCharacters]
                               invertedSet];
    }
    return blockedCharacterSet;
}

#pragma mark - getter and setters
- (void)setProgram:(Program *)program
{
    [program setAsLastProgram];
    _program = program;
}

#pragma mark - initialization
- (void)initNavigationBar
{
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithTitle:kUIBarButtonItemTitleEdit
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(editAction:)];
    self.navigationItem.rightBarButtonItem = editButton;
}

#pragma mark - view events
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    [self.tableView reloadData];
    [self.navigationController setNavigationBarHidden:NO];
    [self.navigationController setToolbarHidden:NO];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.isNewProgram) {
        [self.program saveToDisk];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSDictionary *showDetails = [[NSUserDefaults standardUserDefaults] objectForKey:kUserDetailsShowDetailsKey];
    NSNumber *showDetailsObjectsValue = (NSNumber*)[showDetails objectForKey:kUserDetailsShowDetailsObjectsKey];
    self.useDetailCells = [showDetailsObjectsValue boolValue];
    [self initNavigationBar];
    [self.tableView registerClass:[ProgramTableHeaderView class] forHeaderFooterViewReuseIdentifier:@"Header"];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.editableSections = @[@(kObjectSectionIndex)];
    if (self.program.header.programName) {
        self.navigationItem.title = self.program.header.programName;
        self.title = self.program.header.programName;
    }
    [self setupToolBar];
}

#pragma mark - actions
- (void)addObjectAction:(id)sender
{
    [Util askUserForUniqueNameAndPerformAction:@selector(addObjectActionWithName:)
                                        target:self
                                   promptTitle:kUIAlertViewTitleAddObject
                                 promptMessage:[NSString stringWithFormat:@"%@:", kUIAlertViewMessageObjectName]
                                   promptValue:nil
                             promptPlaceholder:kUIAlertViewPlaceholderEnterObjectName
                                minInputLength:kMinNumOfObjectNameCharacters
                                maxInputLength:kMaxNumOfObjectNameCharacters
                           blockedCharacterSet:[self blockedCharacterSet]
                      invalidInputAlertMessage:kUIAlertViewMessageObjectNameAlreadyExists
                                 existingNames:[[self.program allObjectNames] mutableCopy]];
}

- (void)addObjectActionWithName:(NSString*)objectName
{
    [self showLoadingView];
    [self.program addObjectWithName:[Util uniqueName:objectName existingNames:[self.program allObjectNames]]];
    NSInteger numberOfRowsInLastSection = [self tableView:self.tableView numberOfRowsInSection:kObjectSectionIndex];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(numberOfRowsInLastSection - 1) inSection:kObjectSectionIndex];
    [self.tableView insertRowsAtIndexPaths:@[indexPath]
                          withRowAnimation:(([self.program numberOfNormalObjects] == 1) ? UITableViewRowAnimationFade : UITableViewRowAnimationBottom)];
}

- (void)renameProgramActionForProgramWithName:(NSString*)newProgramName
{
    if ([newProgramName isEqualToString:self.program.header.programName])
        return;

    [self showLoadingView];
    NSString *oldProgramName = self.program.header.programName;
    newProgramName = [Util uniqueName:newProgramName existingNames:[Program allProgramNames]];
    [self.program renameToProgramName:newProgramName];
    [self.delegate renameOldProgramName:oldProgramName toNewProgramName:self.program.header.programName];
    self.navigationItem.title = self.title = self.program.header.programName;
}

- (void)copyObjectActionWithSourceObject:(SpriteObject*)sourceObject
{
    [self showLoadingView];
    NSString *nameOfCopiedObject = [Util uniqueName:sourceObject.name existingNames:[self.program allObjectNames]];
    [self.program copyObject:sourceObject withNameForCopiedObject:nameOfCopiedObject];

    //    // create new cell
    //    NSInteger numberOfRowsInLastSection = [self tableView:self.tableView numberOfRowsInSection:kObjectSectionIndex];
    //    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(numberOfRowsInLastSection - 1) inSection:kObjectSectionIndex];
    //    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationBottom];
    // TODO: scroll to bottom or show notification to user!

    // TODO: issue #308 - deep copy for SpriteObjects
    // ####### WORKAROUND BEGIN: QUICK&DIRTY UGLY HACK !!!

    ProgramLoadingInfo *info = [[ProgramLoadingInfo alloc] init];
    info.basePath = [NSString stringWithFormat:@"%@%@/", [Program basePath], self.program.header.programName];
    info.visibleName = self.program.header.programName;
    self.program = [Program programWithLoadingInfo:info];
    [self.tableView reloadData];

    // ####### WORKAROUND END
}

- (void)renameObjectActionToName:(NSString*)newObjectName spriteObject:(SpriteObject*)spriteObject
{
    if ([newObjectName isEqualToString:spriteObject.name])
        return;

    [self showLoadingView];
    newObjectName = [Util uniqueName:newObjectName existingNames:[self.program allObjectNames]];
    [self.program renameObject:spriteObject toName:newObjectName];
    NSUInteger spriteObjectIndex = [self.program.objectList indexOfObject:spriteObject];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(spriteObjectIndex - kBackgroundObjects)
                                                inSection:kObjectSectionIndex];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)playSceneAction:(id)sender
{
    [self.navigationController setToolbarHidden:YES];
    [self performSegueWithIdentifier:kSegueToScene sender:sender];
}

- (void)editAction:(id)sender
{
    NSMutableArray *options = [NSMutableArray array];
    [options addObject:kUIActionSheetButtonTitleRename];
    if ([self.program numberOfNormalObjects]) {
        [options addObject:kUIActionSheetButtonTitleDeleteObjects];
    }
    if (self.useDetailCells) {
        [options addObject:kUIActionSheetButtonTitleHideDetails];
    } else {
        [options addObject:kUIActionSheetButtonTitleShowDetails];
    }
#if kIsFirstRelease // kIsFirstRelease
    CatrobatActionSheet *actionSheet = [Util actionSheetWithTitle:kUIAlertViewMessageFeatureComingSoon
                                                         delegate:self
                                           destructiveButtonTitle:kUIActionSheetButtonTitleDelete
                                                otherButtonTitles:options
                                                              tag:kEditProgramActionSheetTag
                                                             view:self.navigationController.view];
    // disable all buttons except delete + hide/show details + cancel button
    // (index of cancel button: ([actionSheet.buttons count] - 1))
    for (IBActionSheetButton *button in actionSheet.buttons) {
        if ((button.index != 0) && (button.index != ([actionSheet.buttons count] - 2))
            && (button.index != ([actionSheet.buttons count] - 1))) {
            button.enabled = NO;
            [actionSheet setButtonTextColor:[UIColor grayColor] forButtonAtIndex:button.index];
        }
    }
#else // kIsFirstRelease
    [Util actionSheetWithTitle:kUIActionSheetTitleEditProgram
                      delegate:self
        destructiveButtonTitle:kUIActionSheetButtonTitleDelete
             otherButtonTitles:options
                           tag:kEditProgramActionSheetTag
                          view:self.navigationController.view];
#endif // kIsFirstRelease
}

- (void)confirmDeleteSelectedObjectsAction:(id)sender
{
    NSArray *selectedRowsIndexPaths = [self.tableView indexPathsForSelectedRows];
    if (! [selectedRowsIndexPaths count]) {
        // nothing selected, nothing to delete...
        [super exitEditingMode];
        return;
    }
    [self deleteSelectedObjectsAction];
}

- (void)deleteSelectedObjectsAction
{
    [self showLoadingView];
    NSArray *selectedRowsIndexPaths = [self.tableView indexPathsForSelectedRows];
    NSMutableArray *objectsToRemove = [NSMutableArray arrayWithCapacity:[selectedRowsIndexPaths count]];
    for (NSIndexPath *selectedRowIndexPath in selectedRowsIndexPaths) {
        // sanity check
        if (selectedRowIndexPath.section != kObjectSectionIndex) {
            continue;
        }
        SpriteObject *object = (SpriteObject*)[self.program.objectList objectAtIndex:(kObjectSectionIndex + selectedRowIndexPath.row)];
        [objectsToRemove addObject:object];
    }
    [self.program removeObjects:objectsToRemove];
    [super exitEditingMode];
    [self.tableView deleteRowsAtIndexPaths:selectedRowsIndexPaths withRowAnimation:(([self.program numberOfNormalObjects] != 0) ? UITableViewRowAnimationTop : UITableViewRowAnimationFade)];
}

- (void)deleteObjectForIndexPath:(NSIndexPath*)indexPath
{
    [self showLoadingView];
    NSUInteger index = (kBackgroundObjects + indexPath.row);
    SpriteObject *object = (SpriteObject*)[self.program.objectList objectAtIndex:index];
    [self.program removeObject:object];
    [self.program saveToDisk];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:((indexPath.row != 0) ? UITableViewRowAnimationTop : UITableViewRowAnimationFade)];
}

- (void)deleteProgramAction
{
    [self.delegate removeProgram:self.program.header.programName];
    [self.program removeFromDisk];
    self.program = nil;
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kNumberOfSectionsInProgramTableViewController;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kBackgroundSectionIndex:
            return [self.program numberOfBackgroundObjects];
        case kObjectSectionIndex:
            return [self.program numberOfNormalObjects];
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = kImageCell;
    static NSString *DetailCellIdentifier = kDetailImageCell;
    UITableViewCell *cell = nil;
    if (! self.useDetailCells) {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:DetailCellIdentifier forIndexPath:indexPath];
    }

    if (! [cell conformsToProtocol:@protocol(CatrobatImageCell)] || ! [cell isKindOfClass:[CatrobatBaseCell class]]) {
        return cell;
    }

    CatrobatBaseCell<CatrobatImageCell> *imageCell = (CatrobatBaseCell<CatrobatImageCell>*)cell;
    NSInteger index = (kBackgroundSectionIndex + indexPath.section + indexPath.row);
    SpriteObject *object = [self.program.objectList objectAtIndex:index];
    imageCell.iconImageView.image = nil;
    [imageCell.iconImageView setBorder:[UIColor skyBlueColor] Width:kDefaultImageCellBorderWidth];
    if (indexPath.section == kObjectSectionIndex) {
        imageCell.rightUtilityButtons = @[[Util slideViewButtonMore], [Util slideViewButtonDelete]];
        imageCell.delegate = self;
    } else {
        imageCell.rightUtilityButtons = nil;
        imageCell.delegate = nil;
    }

    if (self.useDetailCells && [cell isKindOfClass:[DarkBlueGradientImageDetailCell class]]) {
        DarkBlueGradientImageDetailCell *detailCell = (DarkBlueGradientImageDetailCell*)imageCell;
        detailCell.topLeftDetailLabel.textColor = [UIColor whiteColor];
        detailCell.topLeftDetailLabel.text = [NSString stringWithFormat:@"%@: %lu", kUILabelTextScripts,
                                              (unsigned long)[object numberOfScripts]];
        detailCell.topRightDetailLabel.textColor = [UIColor whiteColor];
        detailCell.topRightDetailLabel.text = [NSString stringWithFormat:@"%@: %lu", kUILabelTextBricks,
                                               (unsigned long)[object numberOfTotalBricks]];
        detailCell.bottomLeftDetailLabel.textColor = [UIColor whiteColor];
        detailCell.bottomLeftDetailLabel.text = [NSString stringWithFormat:@"%@: %lu", kUILabelTextLooks,
                                                 (unsigned long)[object numberOfLooks]];
        detailCell.bottomRightDetailLabel.textColor = [UIColor whiteColor];
        detailCell.bottomRightDetailLabel.text = [NSString stringWithFormat:@"%@: %lu", kUILabelTextSounds,
                                                  (unsigned long)[object numberOfSounds]];
    }

    if (! [object.lookList count]) {
        imageCell.titleLabel.text = object.name;
        return imageCell;
    }

    imageCell.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    RuntimeImageCache *imageCache = [RuntimeImageCache sharedImageCache];
    NSString *previewImagePath = [object previewImagePath];
    NSString *imagePath = [object pathForLook:[object.lookList firstObject]];
    imageCell.iconImageView.image = nil;
    imageCell.indexPath = indexPath;

    UIImage *image = [imageCache cachedImageForPath:previewImagePath];
    if (! image) {
        [imageCache loadThumbnailImageFromDiskWithThumbnailPath:previewImagePath
                                                      imagePath:imagePath
                                             thumbnailFrameSize:CGSizeMake(kPreviewImageWidth, kPreviewImageHeight)
                                                   onCompletion:^(UIImage *image){
                                                       // check if cell still needed
                                                       if ([imageCell.indexPath isEqual:indexPath]) {
                                                           imageCell.iconImageView.image = image;
                                                           [imageCell setNeedsLayout];
                                                       }
                                                   }];
    } else {
        imageCell.iconImageView.image = image;
    }
    imageCell.titleLabel.text = object.name;
    return imageCell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [TableUtil getHeightForImageCell];
}

#pragma mark - Header View
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return 45.0;
        case 1:
            return 50.0;
        default:
            return 45.0;
    }
}

- (UIView*)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section
{
    ProgramTableHeaderView *headerView = (ProgramTableHeaderView*)[self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"Header"];
    
    if (section == 0) {
        headerView.textLabel.text = [kUILabelTextBackground uppercaseString];
    } else {
        headerView.textLabel.text = (([self.program numberOfNormalObjects] != 1)
                                                    ? [kUILabelTextObjectPlural uppercaseString]
                                                    : [kUILabelTextObjectSingular uppercaseString]);
    }
    return headerView;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
    static NSString *segueToObject = kSegueToObject;
    if (! self.editing) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if ([self shouldPerformSegueWithIdentifier:segueToObject sender:cell]) {
            [self performSegueWithIdentifier:segueToObject sender:cell];
        }
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    ProgramTableHeaderView *headerView = (ProgramTableHeaderView*)view;
    headerView.textLabel.textColor = UIColor.headerTextColor;
}

#pragma mark - segue handler
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Pass the selected object to the new view controller.
    static NSString *toObjectSegueID = kSegueToObject;
    static NSString *toSceneSegueID = kSegueToScene;

    UIViewController *destController = segue.destinationViewController;
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        UITableViewCell *cell = (UITableViewCell*) sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        if ([segue.identifier isEqualToString:toObjectSegueID]) {
            if ([destController isKindOfClass:[ObjectTableViewController class]]) {
                ObjectTableViewController *tvc = (ObjectTableViewController*) destController;
                if ([tvc respondsToSelector:@selector(setObject:)]) {
                    SpriteObject* object = [self.program.objectList objectAtIndex:(kBackgroundObjectIndex + indexPath.section + indexPath.row)];
                    [destController performSelector:@selector(setObject:) withObject:object];
                }
            }
        }
    } else if ([sender isKindOfClass:[UIBarButtonItem class]]) {
        if ([segue.identifier isEqualToString:toSceneSegueID]) {
            if ([destController isKindOfClass:[ScenePresenterViewController class]]) {
                ScenePresenterViewController* scvc = (ScenePresenterViewController*) destController;
                if ([scvc respondsToSelector:@selector(setProgram:)]) {
                    [scvc setController:(UITableViewController *)self];
                    [scvc performSelector:@selector(setProgram:) withObject:self.program];
                }
            }
        }
    }
}

#pragma mark - swipe delegates
- (void)swipeableTableViewCell:(SWTableViewCell *)cell didTriggerRightUtilityButtonWithIndex:(NSInteger)index
{
    [cell hideUtilityButtonsAnimated:YES];
    if (index == 0) {
        // More button was pressed
        NSArray *options = @[kUIActionSheetButtonTitleCopy, kUIActionSheetButtonTitleRename];
#if kIsFirstRelease // kIsFirstRelease
        CatrobatActionSheet *actionSheet = [Util actionSheetWithTitle:kUIAlertViewMessageFeatureComingSoon
                                                             delegate:self
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:options
                                                                  tag:kEditObjectActionSheetTag
                                                                 view:self.navigationController.view];
        // disable all buttons except cancel button (index of cancel button: ([actionSheet.buttons count] - 1))
        for (IBActionSheetButton *button in actionSheet.buttons) {
            if (button.index != ([actionSheet.buttons count] - 1)) {
                button.enabled = NO;
                [actionSheet setButtonTextColor:[UIColor grayColor] forButtonAtIndex:button.index];
            }
        }
#else // kIsFirstRelease
        CatrobatActionSheet *actionSheet = [Util actionSheetWithTitle:kUIActionSheetTitleEditObject
                                                             delegate:self
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:options
                                                                  tag:kEditObjectActionSheetTag
                                                                 view:self.navigationController.view];
#endif // kIsFirstRelease
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        NSInteger spriteObjectIndex = (kBackgroundSectionIndex + indexPath.section + indexPath.row);
        NSDictionary *payload = @{ kDTPayloadSpriteObject : [self.program.objectList objectAtIndex:spriteObjectIndex] };
        DataTransferMessage *message = [DataTransferMessage messageForActionType:kDTMActionEditObject
                                                                     withPayload:[payload mutableCopy]];
        actionSheet.dataTransferMessage = message;
    } else if (index == 1) {
        // Delete button was pressed
#if kIsFirstRelease // kIsFirstRelease
        [Util showComingSoonAlertView];
#else // kIsFirstRelease
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        [cell hideUtilityButtonsAnimated:YES];
        if (indexPath.section == kObjectSectionIndex) {
            [self performActionOnConfirmation:@selector(deleteObjectForIndexPath:)
                               canceledAction:nil
                                   withObject:indexPath
                                       target:self
                                 confirmTitle:kUIAlertViewTitleDeleteSingleObject
                               confirmMessage:kUIAlertViewMessageIrreversibleAction];
        }
#endif // kIsFirstRelease
    }
}

- (BOOL)swipeableTableViewCellShouldHideUtilityButtonsOnSwipe:(SWTableViewCell *)cell
{
    return YES;
}

#pragma mark - action sheet delegates
- (void)actionSheet:(CatrobatActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == kEditProgramActionSheetTag) {
        if (buttonIndex == 1) {
            // Rename program button
            NSMutableArray *unavailableNames = [[Program allProgramNames] mutableCopy];
            [unavailableNames removeString:self.program.header.programName];
            [Util askUserForUniqueNameAndPerformAction:@selector(renameProgramActionForProgramWithName:)
                                                target:self
                                           promptTitle:kUIAlertViewTitleRenameProgram
                                         promptMessage:[NSString stringWithFormat:@"%@:", kUIAlertViewMessageProgramName]
                                           promptValue:((! [self.program.header.programName isEqualToString:kGeneralNewDefaultProgramName])
                                                        ? self.program.header.programName : nil)
                                     promptPlaceholder:kUIAlertViewPlaceholderEnterProgramName
                                        minInputLength:kMinNumOfProgramNameCharacters
                                        maxInputLength:kMaxNumOfProgramNameCharacters
                                   blockedCharacterSet:[self blockedCharacterSet]
                              invalidInputAlertMessage:kUIAlertViewMessageProgramNameAlreadyExists
                                         existingNames:unavailableNames];
        } else if (buttonIndex == 2 && [self.program numberOfNormalObjects]) {
            // Delete objects button
            [self setupEditingToolBar];
            [super changeToEditingMode:actionSheet];
        } else if (buttonIndex == 3 || ((buttonIndex == 2) && (! [self.program numberOfNormalObjects]))) {
            // Show/Hide details button
            self.useDetailCells = (! self.useDetailCells);
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *showDetails = [defaults objectForKey:kUserDetailsShowDetailsKey];
            NSMutableDictionary *showDetailsMutable = nil;
            if (! showDetails) {
                showDetailsMutable = [NSMutableDictionary dictionary];
            } else {
                showDetailsMutable = [showDetails mutableCopy];
            }
            [showDetailsMutable setObject:[NSNumber numberWithBool:self.useDetailCells]
                                   forKey:kUserDetailsShowDetailsObjectsKey];
            [defaults setObject:showDetailsMutable forKey:kUserDetailsShowDetailsKey];
            [defaults synchronize];
            [self.tableView reloadData];
        } else if (buttonIndex == actionSheet.destructiveButtonIndex) {
            // Delete program button
            [self performActionOnConfirmation:@selector(deleteProgramAction)
                               canceledAction:nil
                                       target:self
                                 confirmTitle:kUIAlertViewTitleDeleteProgram
                               confirmMessage:kUIAlertViewMessageIrreversibleAction];
        }
    } else if (actionSheet.tag == kEditObjectActionSheetTag) {
        if (buttonIndex == 0) {
            // Copy object button
            NSDictionary *payload = (NSDictionary*)actionSheet.dataTransferMessage.payload;
            [self copyObjectActionWithSourceObject:(SpriteObject*)payload[kDTPayloadSpriteObject]];
        } else if (buttonIndex == 1) {
            // Rename object button
            NSDictionary *payload = (NSDictionary*)actionSheet.dataTransferMessage.payload;
            SpriteObject *spriteObject = (SpriteObject*)payload[kDTPayloadSpriteObject];
            NSMutableArray *unavailableNames = [[self.program allObjectNames] mutableCopy];
            [unavailableNames removeString:spriteObject.name];
            [Util askUserForUniqueNameAndPerformAction:@selector(renameObjectActionToName:spriteObject:)
                                                target:self
                                            withObject:spriteObject
                                           promptTitle:kUIAlertViewTitleRenameObject
                                         promptMessage:[NSString stringWithFormat:@"%@:", kUIAlertViewMessageObjectName]
                                           promptValue:spriteObject.name
                                     promptPlaceholder:kUIAlertViewPlaceholderEnterObjectName
                                        minInputLength:kMinNumOfObjectNameCharacters
                                        maxInputLength:kMaxNumOfObjectNameCharacters
                                   blockedCharacterSet:[self blockedCharacterSet]
                              invalidInputAlertMessage:kUIAlertViewMessageObjectNameAlreadyExists
                                         existingNames:unavailableNames];
        }
    }
}

#pragma mark - helpers
- (void)setupToolBar
{
    [super setupToolBar];
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                              target:nil
                                                                              action:nil];
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                         target:self
                                                                         action:@selector(addObjectAction:)];
#if kIsFirstRelease // kIsFirstRelease
    add.enabled = NO;
#endif // kIsFirstRelease
    UIBarButtonItem *play = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                          target:self
                                                                          action:@selector(playSceneAction:)];
    // XXX: workaround for tap area problem:
    // http://stackoverflow.com/questions/5113258/uitoolbar-unexpectedly-registers-taps-on-uibarbuttonitem-instances-even-when-tap
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"transparent1x1"]];
    UIBarButtonItem *invisibleButton = [[UIBarButtonItem alloc] initWithCustomView:imageView];
    self.toolbarItems = [NSArray arrayWithObjects:flexItem, invisibleButton, add, invisibleButton, flexItem,
                         flexItem, flexItem, invisibleButton, play, invisibleButton, flexItem, nil];
}

- (void)setupEditingToolBar
{
    [super setupEditingToolBar];
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                              target:nil
                                                                              action:nil];
    UIBarButtonItem *deleteButton = [[UIBarButtonItem alloc] initWithTitle:kUIBarButtonItemTitleDelete
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(confirmDeleteSelectedObjectsAction:)];
    // XXX: workaround for tap area problem:
    // http://stackoverflow.com/questions/5113258/uitoolbar-unexpectedly-registers-taps-on-uibarbuttonitem-instances-even-when-tap
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"transparent1x1"]];
    UIBarButtonItem *invisibleButton = [[UIBarButtonItem alloc] initWithCustomView:imageView];
    self.toolbarItems = [NSArray arrayWithObjects:self.selectAllRowsButtonItem, invisibleButton, flexItem,
                         invisibleButton, deleteButton, nil];
}

@end
