//
//  SMBFile.h
//  WD Content TV
//
//  Created by Сергей Сейтов on 13.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <bdsm/smb_stat.h>

@interface SMBFile : NSObject

@property (retain, nonatomic, readonly) NSString* name;     // The name of the file
@property (retain, nonatomic, readonly) NSString* extension;     // The extension of the file
@property (nonatomic, readonly) NSString *filePath;         // The filepath of this file, excluding the share name.
@property (nonatomic, readonly) bool directory;             // Whether this file is a directory or not
@property (nonatomic, readonly) uint64_t fileSize;          // The file size, in bytes of this folder (0 if it's a folder)
@property (nonatomic, readonly) uint64_t allocationSize;    // The allocation size (ie how big it will be on disk) of this file
@property (nonatomic, readonly) NSDate *creationTime;       // The date and time that this file was created
@property (nonatomic, readonly) NSDate *accessTime;         // The date when this file was last accessed.
@property (nonatomic, readonly) NSDate *writeTime;          // The date when this file was last written to.
@property (nonatomic, readonly) NSDate *modificationTime;   // The date when this file was last modified.

- (instancetype)initWithShareName:(NSString*)name;
- (instancetype)initWithStat:(smb_stat)stat parentDirectoryPath:(NSString *)path;
- (bool)isValidFileType;

@end
