/**
 *  Copyright (C) 2010-2015 The Catrobat Team
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
#import <UIKit/UIKit.h>

@interface BrickSelectionView : UIView
@property (strong, nonatomic) UICollectionView *brickCollectionView;
@property (strong, nonatomic) UILabel *textLabel;
@property (assign, nonatomic) CGFloat yOffset;
@property (strong, nonatomic) UIColor *tintColor;

- (void)showWithView:(UIView *)view fromViewController:(UIViewController *)viewController completion:(void(^)())completionBlock;
- (void)dismissView:(UIViewController *)fromViewController withView:(UIView *)view fastDismiss:(BOOL)fastDimiss completion:(void(^)())completionBlock;
- (BOOL)active;

@end
