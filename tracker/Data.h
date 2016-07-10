//
//  Data.h
//  tracker
//
//  Created by Griffin on 6/8/16.
//  Copyright © 2016 griff.zone. All rights reserved.
//

#import <JSONModel/JSONModel.h>
#import "Event.h"


Event *eventNamed(NSSet<Event *> *events, NSString *eventName);


////////////////////////////////////////////////////////////////////////////////////////////////////
@interface Data : JSONModel

@property (nonatomic, strong) NSMutableArray<Event> *events;

- (void)addEvent:(Event *)event;
- (void)replaceEvent:(Event *)oldEvent withEvent:(Event *)newEvent;
- (void)removeEvent:(Event *)event;
- (void)sortEvents;

- (NSSet<Event *> *)activeStates;
- (NSDictionary<NSString *, Event *> *)lastReadings;
- (NSSet<NSString *> *)recentOccurrences;


@end
