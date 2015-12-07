//
//  Converter.h
//  StringLocalizer
//
//  Created by Lena Schimmel on 03.11.15.
//  Copyright © 2015 DeliveryHero. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Converter : NSObject


-(instancetype)initWithOptions:(NSArray<NSString *> *)options;

-(void) convertFile:(NSString*)filePath;

-(void) readStringsFile:(NSString*)stringsFilePath;
-(void) writeStringsFile:(NSString*)stringsFilePath;

-(void)findMissingKeys;
-(void)findUnusedKeys;

-(void) findDuplicateKeys;
-(void) findDuplicateValues;

-(BOOL) binaryInput;

-(void) convertAllFiles;

@end

void output(NSString *format, ...);