//
//  SMBFile.m
//  WD Content TV
//
//  Created by Сергей Сейтов on 13.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import "SMBFile.h"

@implementation SMBFile

- (instancetype)initWithShareName:(NSString*)name {

    self = [super init];
    if (self != nil) {
        _name = name;
        _fileSize = 0;
        _allocationSize = 0;
        _directory = true;
        _filePath = [NSString stringWithFormat:@"//%@/", name];
    }
    return self;
}

- (instancetype)initWithStat:(smb_stat)stat parentDirectoryPath:(NSString *)path
{
    if (stat == NULL)
        return nil;
    
    if (self = [self init]) {
        const char *name = smb_stat_name(stat);
        _name = [[NSString alloc] initWithBytes:name length:strlen(name) encoding:NSUTF8StringEncoding];
        _fileSize = smb_stat_get(stat, SMB_STAT_SIZE);
        _allocationSize = smb_stat_get(stat, SMB_STAT_ALLOC_SIZE);
        _directory = (smb_stat_get(stat, SMB_STAT_ISDIR) != 0);
		if (!_directory)
			_extension = _name.pathExtension;
        uint64_t modificationTimestamp = smb_stat_get(stat, SMB_STAT_MTIME);
        uint64_t creationTimestamp = smb_stat_get(stat, SMB_STAT_CTIME);
        uint64_t accessTimestamp = smb_stat_get(stat, SMB_STAT_ATIME);
        uint64_t writeTimestamp = smb_stat_get(stat, SMB_STAT_WTIME);
        
        _modificationTime = [self dateFromLDAPTimeStamp:modificationTimestamp];
        _creationTime = [self dateFromLDAPTimeStamp:creationTimestamp];
        _accessTime = [self dateFromLDAPTimeStamp:accessTimestamp];
        _writeTime = [self dateFromLDAPTimeStamp:writeTimestamp];
        
        _filePath = [path stringByAppendingPathComponent:_name];
    }
    
    return self;
}

//SO Answer by Dave DeLong - http://stackoverflow.com/a/11978614/599344
- (NSDate *)dateFromLDAPTimeStamp:(uint64_t)timestamp
{
    NSDateComponents *base = [[NSDateComponents alloc] init];
    [base setDay:1];
    [base setMonth:1];
    [base setYear:1601];
    [base setEra:1]; // AD
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate *baseDate = [gregorian dateFromComponents:base];
    
    NSTimeInterval newTimestamp = timestamp / 10000000.0f;
    NSDate *finalDate = [baseDate dateByAddingTimeInterval:newTimestamp];
    
    return finalDate;
}

- (bool)isValidFileType {
	if (_directory) {
		return true;
	} else {
		NSArray* movieExtensions = @[@"mkv", @"avi", @"iso", @"ts", @"mov", @"m4v", @"mpg", @"mpeg", @"wmv", @"mp4"];
		return [movieExtensions containsObject:_extension];
	}
}

@end
