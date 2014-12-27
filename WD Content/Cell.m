//
//  Cell.m
//  WD Content
//
//  Created by Sergey Seitov on 29.11.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "Cell.h"

@implementation Cell

+ (NSString*)yearFromDate:(NSString*)text
{
	NSDateFormatter *inputFormatter = [[NSDateFormatter alloc] init];
	[inputFormatter setDateFormat:@"yyyy-MM-dd"];
	NSDate *date = [inputFormatter dateFromString:text];
	
	NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
	[outputFormatter setDateFormat:@"yyyy"];
	NSString* outText = [NSString stringWithFormat:@" (%@)", [outputFormatter stringFromDate:date]];
	
	return outText;
}

- (void)setInfo:(Node*)node
{
	_image.image = [node.info thumbnail] ? [UIImage imageWithData:node.info.thumbnail] : [UIImage imageWithData:node.image];
	if ([node.isFile boolValue]) {
		if ([node.info release_date]) {
			NSString* titleText =  [node.info title] ? node.info.title : node.name;
			NSString* year = [Cell yearFromDate:node.info.release_date];
			NSString* text = [titleText stringByAppendingString:year];
			
			NSMutableAttributedString *attString=[[NSMutableAttributedString alloc] initWithString:text];
			[attString addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:14]
							  range:NSMakeRange(0, titleText.length)];
			[attString addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-Bold" size:14]
							  range:NSMakeRange(titleText.length, year.length)];
			[attString addAttribute:NSForegroundColorAttributeName
							  value:[UIColor blackColor]
							  range:NSMakeRange(0, text.length)];
			_title.attributedText = attString;
		} else {
			_title.text = [node.info title] ? node.info.title : node.name;
		}
	} else {
		_title.text = node.name;
	}
}

@end
