//
//  LPDiffingAlgorithm.m
//  Leonspok
//
//  Created by Игорь Савельев on 11/04/2017.
//  Copyright © 2017 Leonspok. All rights reserved.
//

#import "LPDiffingAlgorithm.h"

@interface LPSymbolTableItem : NSObject
@property (nonatomic) NSUInteger nc;
@property (nonatomic) NSUInteger oc;
@property (nonatomic) NSInteger olno;

@end

@implementation LPSymbolTableItem

- (id)init {
	self = [super init];
	if (self) {
		self.nc = 0;
		self.oc = 0;
		self.olno = NSNotFound;
	}
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"nc=%ld;oc=%ld;olno=%ld", (long)self.nc, (long)self.oc, (long)self.olno];
}

@end

@implementation LPChangeItem
@end
@implementation LPMoveItem
@end
@implementation LPRemoveItem
@end
@implementation LPInsertItem
@end

@interface LPDiffingAlgorithm()
@property (nonatomic, strong) NSArray<NSObject *> *oldItems;
@property (nonatomic, strong) NSArray<NSObject *> *updatedItems;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, LPSymbolTableItem *> *table;
@property (nonatomic, strong) NSMutableArray *na;
@property (nonatomic, strong) NSMutableArray *oa;

@property (nonatomic, strong, readwrite) NSArray<LPRemoveItem *> *removeItems;
@property (nonatomic, strong, readwrite) NSArray<LPMoveItem *> *moveItems;
@property (nonatomic, strong, readwrite) NSArray<LPInsertItem *> *insertItems;

@end

@implementation LPDiffingAlgorithm {
	NSArray *nna;
	NSArray *ooa;
}

- (instancetype)initWithOldItems:(NSArray<NSObject *> *)oldItems updatedItems:(NSArray<NSObject *> *)updatedItems {
	self = [super init];
	if (self) {
		self.oldItems = oldItems;
		self.updatedItems = updatedItems;
	}
	return self;
}

- (void)run {
	self.table = [NSMutableDictionary dictionary];
	self.na = [NSMutableArray array];
	self.oa = [NSMutableArray array];
	[self firstPass];
	[self secondPass];
	[self thirdPass];
	nna = [self.na copy];
	ooa = [self.oa copy];
	[self finalPass];
}

- (void)firstPass {
	for (NSUInteger i = 0; i < self.updatedItems.count; i++) {
		LPSymbolTableItem *item = self.table[@(self.updatedItems[i].hash)];
		if (!item) {
			item = [LPSymbolTableItem new];
			[self.table setObject:item forKey:@(self.updatedItems[i].hash)];
		}
		if (i >= self.na.count) {
			[self.na addObject:item];
		}
		item.nc++;
	}
}

- (void)secondPass {
	for (NSUInteger i = 0; i < self.oldItems.count; i++) {
		LPSymbolTableItem *item = self.table[@(self.oldItems[i].hash)];
		if (!item) {
			item = [LPSymbolTableItem new];
			[self.table setObject:item forKey:@(self.oldItems[i].hash)];
		}
		if (i >= self.oa.count) {
			[self.oa addObject:item];
		}
		item.oc++;
		item.olno = i;
	}
}

- (void)thirdPass {
	for (NSUInteger i = 0; i < self.na.count; i++) {
		if (![self.na[i] isKindOfClass:LPSymbolTableItem.class]) {
			continue;
		}
		LPSymbolTableItem *naI = self.na[i];
		if (naI.oc == 1 && naI.nc == 1) {
			NSInteger olno = naI.olno;
			self.na[i] = @(olno);
			self.oa[olno] = @(i);
		}
	}
}

- (void)finalPass {
	NSMutableArray *removes = [NSMutableArray array];
	for (NSUInteger i = 0; i < self.oa.count; i++) {
		if (![self.oa[i] isKindOfClass:LPSymbolTableItem.class]) {
			continue;
		}
		LPSymbolTableItem *item = self.oa[i];
		if (item.nc == 0) {
			LPRemoveItem *removeItem = [[LPRemoveItem alloc] init];
			removeItem.item = [self.oldItems objectAtIndex:i];
			removeItem.index = i;
			[removes addObject:removeItem];
		}
	}
	
	NSMutableArray *moves = [NSMutableArray array];
	NSMutableArray *inserts = [NSMutableArray array];
	for (NSUInteger i = 0; i < self.na.count; i++) {
		if ([self.na[i] isKindOfClass:NSNumber.class]) {
			NSNumber *number = self.na[i];
			if ([number unsignedIntegerValue] == i) {
				continue;
			}
			LPMoveItem *moveItem = [[LPMoveItem alloc] init];
			moveItem.item = self.updatedItems[i];
			moveItem.fromIndex = [number unsignedIntegerValue];
			moveItem.toIndex = i;
			[moves addObject:moveItem];
		} else if ([self.na[i] isKindOfClass:LPSymbolTableItem.class]) {
			LPSymbolTableItem *item = self.na[i];
			if (item.oc == 1 && item.nc == 1 && item.olno != NSNotFound) {
				LPMoveItem *moveItem = [[LPMoveItem alloc] init];
				moveItem.item = self.updatedItems[i];
				moveItem.fromIndex = (NSUInteger)item.olno;
				moveItem.toIndex = i;
				[moves addObject:moveItem];
			} else {
				LPInsertItem *insertItem = [[LPInsertItem alloc] init];
				insertItem.item = self.updatedItems[i];
				insertItem.index = i;
				[inserts addObject:insertItem];
			}
		}
	}
	
	self.removeItems = [removes sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"index" ascending:NO]]];
	self.moveItems = [moves sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"fromIndex" ascending:NO]]];
	self.insertItems = inserts;
}

@end
