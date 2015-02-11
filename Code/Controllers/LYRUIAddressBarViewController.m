//
//  LYRUIAddressBarController.m
//  
//
//  Created by Kevin Coleman on 10/27/14.
//
//

#import "LYRUIAddressBarViewController.h"
#import "LYRUIConstants.h"
#import "LYRUIAddressBarContainerView.h"

@interface LYRUIAddressBarViewController () <UITextViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) LYRUIAddressBarContainerView *view;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSArray *participants;
@property (nonatomic, getter=isPermanent) BOOL permanent;

@end

@implementation LYRUIAddressBarViewController

NSString *const LYRUIAddressBarAccessibilityLabel = @"Address Bar";
static NSString *const LSParticpantCellIdentifier = @"participantCellIdentifier";
static NSString *const LYRUIAddressBarParticipantAttributeName = @"LYRUIAddressBarParticipant";

- (void)loadView
{
    self.view = [LYRUIAddressBarContainerView new];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.accessibilityLabel = LYRUIAddressBarAccessibilityLabel;
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.addressBarView = [[LYRUIAddressBarView alloc] init];
    self.addressBarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.addressBarView.backgroundColor = LYRUIAddressBarGray();
    self.addressBarView.addressBarTextView.delegate = self;
    [self.addressBarView.addContactsButton addTarget:self action:@selector(contactButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.addressBarView];
   
    self.tableView = [[UITableView alloc] init];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:LSParticpantCellIdentifier];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.hidden = YES;
    [self.view addSubview:self.tableView];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.addressBarView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.addressBarView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.addressBarView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.addressBarView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(addressBarTextViewTapped:)];
    [self.addressBarView.addressBarTextView addGestureRecognizer:gestureRecognizer];
}

#pragma mark - Public Method Implementation

- (void)setPermanent
{
    if (self.isPermanent) return;
    self.permanent = YES;

    self.addressBarView.addressBarTextView.text = [self permanentStringForParticipants:self.selectedParticipants];
    self.addressBarView.addressBarTextView.textColor = LYRUIGrayColor();
    self.addressBarView.addressBarTextView.userInteractionEnabled = NO;
    self.addressBarView.addressBarTextView.editable = NO;
    [self sizeAddressBarView];
}

- (void)selectParticipant:(id<LYRUIParticipant>)participant
{
    if (!participant) return;

    NSMutableOrderedSet *participants = [NSMutableOrderedSet orderedSetWithOrderedSet:self.selectedParticipants];
    [participants addObject:participant];
    self.selectedParticipants = participants;
}

- (void)setSelectedParticipants:(NSOrderedSet *)selectedParticipants
{
    if (!selectedParticipants && !_selectedParticipants) return;
    if ([selectedParticipants isEqual:_selectedParticipants]) return;

    NSOrderedSet *existingParticipants = _selectedParticipants;

    _selectedParticipants = selectedParticipants;

    NSMutableOrderedSet *removedParticipants = [NSMutableOrderedSet orderedSetWithOrderedSet:existingParticipants];
    if (selectedParticipants) [removedParticipants minusOrderedSet:selectedParticipants];

    NSMutableOrderedSet *addedParticipants = [NSMutableOrderedSet orderedSetWithOrderedSet:selectedParticipants];
    if (existingParticipants) [addedParticipants minusOrderedSet:existingParticipants];

    if (self.isPermanent) {
        NSString *text = [self permanentStringForParticipants:selectedParticipants];
        self.addressBarView.addressBarTextView.text = text;
    } else {
        NSAttributedString *attributedText = [self attributedStringForParticipants:selectedParticipants];
        self.addressBarView.addressBarTextView.attributedText = attributedText;
    }
    [self sizeAddressBarView];

    if ([self.delegate respondsToSelector:@selector(addressBarViewController:didRemoveParticipant:)]) {
        for (id<LYRUIParticipant> removedParticipant in removedParticipants) {
            [self.delegate addressBarViewController:self didRemoveParticipant:removedParticipant];
        }
    }

    if ([self.delegate respondsToSelector:@selector(addressBarViewController:didSelectParticipant:)]) {
        for (id<LYRUIParticipant> addedParticipant in addedParticipants) {
            [self.delegate addressBarViewController:self didSelectParticipant:addedParticipant];
        }
    }

    [self searchEnded];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.participants.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell =[tableView dequeueReusableCellWithIdentifier:LSParticpantCellIdentifier];
    id<LYRUIParticipant> participant = self.participants[indexPath.row];
    cell.textLabel.text = participant.fullName;
    cell.textLabel.font = LYRUIMediumFont(14);
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<LYRUIParticipant> participant = self.participants[indexPath.row];
    [self selectParticipant:participant];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.addressBarView.addressBarTextView) return;
    if (CGSizeEqualToSize(scrollView.frame.size, scrollView.contentSize)) {
        scrollView.contentOffset = CGPointZero;
    }
}

#pragma mark - UITextViewDelegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    self.addressBarView.addContactsButton.hidden = NO;
    return YES;
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    self.addressBarView.addContactsButton.hidden = YES;
    return YES;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if (textView.typingAttributes[NSForegroundColorAttributeName]) {
        NSMutableDictionary *attributes = [textView.typingAttributes mutableCopy];
        attributes[NSForegroundColorAttributeName] = self.addressBarView.addressBarTextView.addressBarTextColor;
        textView.typingAttributes = attributes;
    }

    // If user is deleting...
    if ([text isEqualToString:@""]) {
        NSAttributedString *attributedString = textView.attributedText;
        // If range.length is 1, we need to select the participant
        if (range.length == 1) {
            NSRange effectiveRange;
            id<LYRUIParticipant> participant = [attributedString attribute:LYRUIAddressBarParticipantAttributeName atIndex:range.location longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, attributedString.length)];
            if (participant && effectiveRange.location + effectiveRange.length == range.location + range.length) {
                textView.selectedRange = effectiveRange;
                return NO;
            }
        }
    } else if ([text rangeOfString:@"\n"].location != NSNotFound) {
        return NO;
    }
    return YES;
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
    NSRange selectedRange = textView.selectedRange;
    NSRange acceptableRange = [self acceptableSelectedRange];
    if (!NSEqualRanges(acceptableRange, selectedRange)) {
        textView.selectedRange = acceptableRange;
    }

    // Workaround for automatic scrolling not occurring in some cases after text entry.
    [textView scrollRangeToVisible:textView.selectedRange];
}

- (void)textViewDidChange:(UITextView *)textView
{
    NSAttributedString *attributedString = textView.attributedText;
    NSOrderedSet *participants = [self participantsInAttributedString:attributedString];
    NSMutableOrderedSet *removedParticipants = [NSMutableOrderedSet orderedSetWithOrderedSet:self.selectedParticipants];
    [removedParticipants minusOrderedSet:participants];
    _selectedParticipants = participants;
    if ([self.delegate respondsToSelector:@selector(addressBarViewController:didRemoveParticipant:)]) {
        for (id<LYRUIParticipant> participant in removedParticipants) {
            [self.delegate addressBarViewController:self didRemoveParticipant:participant];
        }
    }

    [self sizeAddressBarView];
    NSString *enteredText = textView.text;
    NSString *searchText = [self textForSearchFromTextView:textView];
    // If no text, reset search bar
    if (searchText.length == 0) {
        [self searchEnded];
    } else {
        if (self.tableView.isHidden) {
            self.tableView.hidden = NO;
            if ([self.delegate respondsToSelector:@selector(addressBarViewControllerDidBeginSearching:)]) {
                [self.delegate addressBarViewControllerDidBeginSearching:self];
            }
        }
        if ([self.dataSource respondsToSelector:@selector(addressBarViewController:searchForParticipantsMatchingText:completion:)]) {
            [self.dataSource addressBarViewController:self searchForParticipantsMatchingText:searchText completion:^(NSArray *participants) {
                if (![enteredText isEqualToString:textView.text]) return;
                self.tableView.hidden = NO;
                self.participants = [self filteredParticipants:participants];
                [self.tableView reloadData];
                [self.tableView setContentOffset:CGPointZero animated:NO];
            }];
        }
    }
}

#pragma mark - Actions

- (void)addressBarTextViewTapped:(UITapGestureRecognizer *)recognizer
{
    // Make sure the addressTextView is first responder
    if (!self.addressBarView.addressBarTextView.isFirstResponder) {
        [self.addressBarView.addressBarTextView becomeFirstResponder];
    }
    
    // Calculate the tap index
    UITextView *textView = (UITextView *)recognizer.view;
    CGPoint tapPoint = [recognizer locationInView:textView];
    UITextPosition *tapTextPosition = [textView closestPositionToPoint:tapPoint];
    NSInteger tapIndex = [self.addressBarView.addressBarTextView offsetFromPosition:self.addressBarView.addressBarTextView.beginningOfDocument toPosition:tapTextPosition];
    NSAttributedString *attributedString = self.addressBarView.addressBarTextView.attributedText;
    if (tapIndex == 0) {
        textView.selectedRange = NSMakeRange(0, 0);
        return;
    }
    if (tapIndex == attributedString.length) {
        textView.selectedRange = NSMakeRange(attributedString.length, 0);
        return;
    }
    NSRange participantRange;
    id<LYRUIParticipant> participant = [attributedString attribute:LYRUIAddressBarParticipantAttributeName atIndex:tapIndex - 1 longestEffectiveRange:&participantRange inRange:NSMakeRange(0, attributedString.length)];
    if (participant) {
        textView.selectedRange = participantRange;
    } else {
        textView.selectedRange = NSMakeRange(tapIndex, 0);
    }
}

- (void)contactButtonTapped:(UIButton *)sender
{
    if ([self.delegate respondsToSelector:@selector(addressBarViewController:didTapAddContactsButton:)]) {
        [self.delegate addressBarViewController:self didTapAddContactsButton:sender];
    }
}

#pragma mark - Helpers

- (void)sizeAddressBarView
{
    [self.addressBarView.addressBarTextView setNeedsUpdateConstraints];
}

- (NSString *)textForSearchFromTextView:(UITextView *)textView
{
    NSAttributedString *attributedString = textView.attributedText;
    __block NSRange searchRange = NSMakeRange(NSNotFound, 0);
    [attributedString enumerateAttribute:LYRUIAddressBarParticipantAttributeName inRange:NSMakeRange(0, attributedString.length) options:0 usingBlock:^(id<LYRUIParticipant> participant, NSRange range, BOOL *stop) {
        if (participant) return;
        searchRange = range;
    }];
    if (searchRange.location == NSNotFound) return nil;
    NSAttributedString *attributedSearchString = [attributedString attributedSubstringFromRange:searchRange];
    NSString *searchString = attributedSearchString.string;
    NSString *trimmedSearchString = [searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return trimmedSearchString;
}

- (NSArray *)filteredParticipants:(NSArray *)participants
{
    NSMutableArray *prospectiveParticipants = [participants mutableCopy];
    [prospectiveParticipants removeObjectsInArray:self.selectedParticipants.array];
    return prospectiveParticipants;
}

- (void)searchEnded
{
    if (self.tableView.isHidden) return;
    if ([self.delegate respondsToSelector:@selector(addressBarViewControllerDidEndSearching:)]) {
        [self.delegate addressBarViewControllerDidEndSearching:self];
    }
    self.participants = nil;
    self.tableView.hidden = YES;
    [self.tableView reloadData];
}

- (NSOrderedSet *)participantsInAttributedString:(NSAttributedString *)attributedString
{
    NSMutableOrderedSet *participants = [NSMutableOrderedSet new];
    [attributedString enumerateAttribute:LYRUIAddressBarParticipantAttributeName inRange:NSMakeRange(0, attributedString.length) options:0 usingBlock:^(id<LYRUIParticipant> participant, NSRange range, BOOL *stop) {
        if (!participant) return;
        [participants addObject:participant];
    }];
    return participants;
}

- (NSString *)permanentStringForParticipants:(NSOrderedSet *)participants
{
    NSMutableArray *names = [NSMutableArray new];
    for (id<LYRUIParticipant> participant in participants) {
        NSString *name = participant.firstName;
        if (name.length == 0) continue;
        [names addObject:name];
    }
    NSString *string = [names componentsJoinedByString:@", "];
    return string;
}

- (NSAttributedString *)attributedStringForParticipants:(NSOrderedSet *)participants
{
    NSMutableAttributedString *attributedString = [NSMutableAttributedString new];
    for (id<LYRUIParticipant> participant in participants) {
        NSAttributedString *attributedParticipant = [self attributedStringForParticipant:participant];
        [attributedString appendAttributedString:attributedParticipant];
    }
    return attributedString;
}

- (NSAttributedString *)attributedStringForParticipant:(id<LYRUIParticipant>)participant
{
    LYRUIAddressBarTextView *textView = self.addressBarView.addressBarTextView;
    NSMutableAttributedString *attributedString = [NSMutableAttributedString new];

    NSAttributedString *attributedName = [[NSAttributedString alloc] initWithString:participant.fullName attributes:@{LYRUIAddressBarPartAttributeName: LYRUIAddressBarNamePart, LYRUIAddressBarPartAttributeName: LYRUIAddressBarNamePart, NSForegroundColorAttributeName: textView.addressBarHighlightColor}];
    [attributedString appendAttributedString:attributedName];

    NSAttributedString *attributedDelimiter = [[NSAttributedString alloc] initWithString:@", " attributes:@{LYRUIAddressBarPartAttributeName: LYRUIAddressBarDelimiterPart, NSForegroundColorAttributeName: [UIColor grayColor]}];
    [attributedString appendAttributedString:attributedDelimiter];

    [attributedString addAttributes:@{LYRUIAddressBarParticipantAttributeName: participant, NSFontAttributeName: textView.font, NSParagraphStyleAttributeName: textView.typingAttributes[NSParagraphStyleAttributeName]} range:NSMakeRange(0, attributedString.length)];

    return attributedString;
}

- (NSRange)acceptableSelectedRange
{
    NSRange selectedRange = self.addressBarView.addressBarTextView.selectedRange;
    NSAttributedString *attributedString = self.addressBarView.addressBarTextView.attributedText;
    if (selectedRange.length == 0) {
        if (selectedRange.location == 0) return selectedRange;
        if (selectedRange.location == attributedString.length) return selectedRange;
        NSRange participantRange;
        id<LYRUIParticipant> participant = [attributedString attribute:LYRUIAddressBarParticipantAttributeName atIndex:selectedRange.location longestEffectiveRange:&participantRange inRange:NSMakeRange(0, attributedString.length)];
        if (!participant) return selectedRange;
        if (selectedRange.location <= participantRange.location) return selectedRange;
        NSUInteger participantStartIndex = participantRange.location;
        NSUInteger participantEndIndex = participantRange.location + participantRange.length;
        BOOL closerToParticipantStart = selectedRange.location - participantStartIndex < participantEndIndex - selectedRange.location;
        if (closerToParticipantStart) {
            return NSMakeRange(participantStartIndex, 0);
        } else {
            return NSMakeRange(participantEndIndex, 0);
        }
    }

    __block NSRange adjustedRange = selectedRange;
    [attributedString enumerateAttribute:LYRUIAddressBarParticipantAttributeName inRange:NSMakeRange(0, attributedString.length) options:0 usingBlock:^(id<LYRUIParticipant> participant, NSRange range, BOOL *stop) {
        if (!participant) return;
        if (NSIntersectionRange(selectedRange, range).length == 0) return;
        adjustedRange = NSUnionRange(adjustedRange, range);
    }];

    return adjustedRange;
}

@end