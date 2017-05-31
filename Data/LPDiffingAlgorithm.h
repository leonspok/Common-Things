//
//  LPDiffingAlgorithm.h
//  Leonspok
//
//  Created by Игорь Савельев on 11/04/2017.
//  Copyright © 2017 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LPChangeItem<__covariant ObjectType:NSObject*> : NSObject

@property (nonatomic, strong) ObjectType item;

@end

@interface LPRemoveItem : LPChangeItem

@property (nonatomic) NSUInteger index;

@end

@interface LPMoveItem : LPChangeItem

@property (nonatomic) NSUInteger fromIndex;
@property (nonatomic) NSUInteger toIndex;

@end

@interface LPInsertItem : LPChangeItem

@property (nonatomic) NSUInteger index;

@end

@interface LPDiffingAlgorithm<__covariant ObjectType:NSObject *> : NSObject

@property (nonatomic, strong, readonly) NSArray<LPRemoveItem *> *removeItems;
@property (nonatomic, strong, readonly) NSArray<LPMoveItem *> *moveItems;
@property (nonatomic, strong, readonly) NSArray<LPInsertItem *> *insertItems;

- (instancetype)initWithOldItems:(NSArray<ObjectType> *)oldItems updatedItems:(NSArray<ObjectType> *)updatedItems;

- (void)run;

@end
