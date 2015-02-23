//
//  ConditionLock.h
//  WD Content
//
//  Created by Sergey Seitov on 24.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#ifndef WD_Content_ConditionLock_h
#define WD_Content_ConditionLock_h

#import <Foundation/Foundation.h>

class ConditionLock {
private:
	NSCondition *_condition;
public:
	ConditionLock(NSCondition* condition)
	{
		_condition = condition;
		[_condition lock];
	}
	~ConditionLock()
	{
		[_condition unlock];
	}
};

#endif
