//
//  RSLCoreDataWorkerTemplate.m
//  CoreData
//
//  Created by Oleksa Korin on 10/9/10.
//  Copyright 2010 RedShiftLab. All rights reserved.
//

#import "NSManagedObject+IDPExtensions.h"

#import "IDPCoreDataManager.h"

#import "NSManagedObjectContext+IDPExtensions.h"

@interface NSManagedObject (IDPExtensionsPrivate)

+ (NSManagedObjectContext *)context;
+ (id)createObjectWithValue:(id)value forKey:(id)key;

@end

@implementation NSManagedObject (IDPExtensions)

#pragma mark -
#pragma mark Private

+ (NSManagedObjectContext *)context {
	return [[IDPCoreDataManager sharedManager] managedObjectContext];
}

+ (id)createObjectWithValue:(id)value forKey:(id)key {
	id object = [self managedObject];
	[object setValue:value forKey:key];
	
	return object;
}

#pragma mark -
#pragma mark Class Methods

+ (NSArray *)fetchEntityWithSortDescriptors:(NSArray *)sortDescriptorsArray 
								  predicate:(NSPredicate *)predicate 
							  prefetchPaths:(NSArray *)prefetchPaths
{
	return [NSManagedObjectContext fetchEntity:NSStringFromClass([self class]) 
						   withSortDescriptors:sortDescriptorsArray 
									 predicate:predicate 
								 prefetchPaths:prefetchPaths];
}

+ (id)fetchOrCreateObjectUsingKey:(NSString *)key value:(id)value {
	return [self fetchOrCreateObjectUsingKey:key value:value prefetchPaths:nil];
}

+ (id)fetchOrCreateObjectUsingKey:(NSString *)key
							value:(id)value
					prefetchPaths:(NSArray *)prefetchPaths
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%@ = %@)", key, value];
	NSArray *fetchedObjects = [self fetchEntityWithSortDescriptors:nil
														 predicate:predicate
													 prefetchPaths:prefetchPaths];
	
	id object = nil;
	if (0 == [fetchedObjects count]) {
		object = [self managedObject];
		[object setValue:value forKey:key];
	} else {
		object = [fetchedObjects firstObject];
	}
	
	return object;
}

+ (NSArray *)fetchOrCreateObjectsUsingKey:(NSString *)key values:(id)values {
	return [self fetchOrCreateObjectsUsingKey:key values:values prefetchPaths:nil];
}

+ (NSArray *)fetchOrCreateObjectsUsingKey:(NSString *)key
								   values:(id)values
							prefetchPaths:(NSArray *)prefetchPaths
{
	NSArray *sortedValues = [values sortedArrayUsingSelector:@selector(compare:)];
	
	NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:key ascending:YES];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@ IN %@", key, sortedValues];
	
	NSArray *fetchedObjects = [self fetchEntityWithSortDescriptors:@[descriptor]
														 predicate:predicate
													 prefetchPaths:prefetchPaths];
	
	NSMutableArray *objects = [NSMutableArray array];
	if (0 == [fetchedObjects count]) {
		for (id value in sortedValues) {
			[objects addObject:[self createObjectWithValue:value forKey:key]];
		}
		
		return objects;
	}
	
	NSUInteger currentIndex = 0;
	for (id value in sortedValues) {
		id currentObject = fetchedObjects[currentIndex];
		
		if (![value isEqual:currentObject[key]]) {
			[objects addObject:[self createObjectWithValue:value forKey:key]];
		} else {
			++currentIndex;
			[objects addObject:currentObject];
		}
	}
	
	return objects;
}

+ (id)managedObject {
	return [NSManagedObjectContext managedObjectWithEntity:NSStringFromClass([self class])];
}

#pragma mark -
#pragma mark Public Methods

- (void)deleteManagedObject {
	[NSManagedObjectContext deleteManagedObject:self];
}

- (void)saveManagedObject {
	[NSManagedObjectContext saveManagedObjectContext];
}
								  
- (void)setCustomValue:(id)value forKey:(NSString *)key {
	[self willChangeValueForKey:key];
	[self setPrimitiveValue:value forKey:key];
	[self didChangeValueForKey:key];
}

- (id)customValueForKey:(NSString *)key {
	[self willAccessValueForKey:key];
	id result = [self primitiveValueForKey:key];
	[self didAccessValueForKey:key];
	
	return result;
}

- (void)addCustomValue:(id)value inMutableSetForKey:(NSString *)key {
	NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
	
    [self willChangeValueForKey:key
				withSetMutation:NSKeyValueUnionSetMutation
				   usingObjects:changedObjects];
    
	NSMutableSet *primitiveSet = [self primitiveValueForKey:key];
	[primitiveSet unionSet:changedObjects];
    
    [self didChangeValueForKey:key
			   withSetMutation:NSKeyValueUnionSetMutation
				  usingObjects:changedObjects];
	
    [changedObjects release];
}

- (void)removeCustomValue:(id)value inMutableSetForKey:(NSString *)key {
	NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
	
    [self willChangeValueForKey:key
				withSetMutation:NSKeyValueMinusSetMutation
				   usingObjects:changedObjects];
	
	NSMutableSet *primitiveSet = [self primitiveValueForKey:key];
	[primitiveSet minusSet:changedObjects];
    
	[self didChangeValueForKey:key
			   withSetMutation:NSKeyValueMinusSetMutation
				  usingObjects:changedObjects];
	
    [changedObjects release];	
}

- (void)addCustomValues:(NSSet *)values inMutableSetForKey:(NSString *)key {
    [self willChangeValueForKey:key
				withSetMutation:NSKeyValueUnionSetMutation
				   usingObjects:values];
	
	NSMutableSet *primitiveSet = [self primitiveValueForKey:key];
	[primitiveSet unionSet:values];
    
	[self didChangeValueForKey:key
			   withSetMutation:NSKeyValueUnionSetMutation
				  usingObjects:values];
}

- (void)removeCustomValues:(NSSet *)values inMutableSetForKey:(NSString *)key {
	[self willChangeValueForKey:key
				withSetMutation:NSKeyValueMinusSetMutation
				   usingObjects:values];
	
	NSMutableSet *primitiveSet = [self primitiveValueForKey:key];
	[primitiveSet minusSet:values];
    
	[self didChangeValueForKey:key
			   withSetMutation:NSKeyValueMinusSetMutation
				  usingObjects:values];
}

- (void)rollback {
	NSDictionary *changedValues = [self changedValues];
    NSDictionary *committedValues = [self committedValuesForKeys:[changedValues allKeys]];
	
	for (id key in changedValues) {
		[self setValue:[committedValues objectForKey:key]
				forKey:key];
	}
}

- (void)refresh {
    [self refreshWithMerge:YES];
}

- (void)refreshWithMerge:(BOOL)shouldMerge {
    [[[self class] context] refreshObject:self mergeChanges:shouldMerge];
}

- (void)addCustomValues:(NSOrderedSet *)values inMutableOrderedSetForKey:(NSString *)key {
	
	NSMutableOrderedSet *primitiveSet = [self primitiveValueForKey:key];
	[primitiveSet addObject:values];
    
}

- (void)addCustomValue:(id)value inMutableOrderedSetForKey:(NSString *)key {
    NSMutableOrderedSet *primitiveSet = [self primitiveValueForKey:key];
	[primitiveSet addObject:value];
}

@end
