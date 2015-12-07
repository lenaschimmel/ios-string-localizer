//
//  Converter.m
//  StringLocalizer
//
//  Created by Lena Schimmel on 03.11.15.
//  Copyright © 2015 DeliveryHero. All rights reserved.
//

#import "Converter.h"

@interface Converter ()
@property NSMutableDictionary* commentEntries;
@property NSMutableDictionary* entries;
@property NSMutableDictionary* prefixMeanings;
@property NSMutableSet* usedKeys;
@property NSArray<NSString *> * options;
@property NSInputStream* inputStream;
@end


@implementation Converter

-(instancetype)initWithOptions:(NSArray<NSString *> *)options {
    self = [super init];
    if(self) {
        self.commentEntries = [NSMutableDictionary dictionary];
        self.entries = [NSMutableDictionary dictionary];
        self.prefixMeanings = [NSMutableDictionary dictionary];
        self.usedKeys = [NSMutableSet set];
        self.options = options.copy;
        //self.inputStream = [NSInputStream inputStreamWithFileAtPath:@"/dev/stdin"];
        //[self.inputStream open];
    }
    return self;
}

-(void)convertAllFiles {
    NSInteger optionIndexSeparator = [self.options indexOfObject:@"--"];
    for(NSInteger i = optionIndexSeparator + 1; i < self.options.count; i++) {
        [self convertFile:[self.options objectAtIndex:i]];
    }
}

-(void)convertFile:(NSString *)filePath {
    if(filePath.length < 10) {
        output(@"Suspicious file name: '%@'\n", filePath);
        return;
    }
    
    NSString* fileName = [filePath lastPathComponent];
    NSString* prefix = [self stringByKeepingUpperCaseLetters:[fileName substringToIndex:fileName.length - 2]];
    
    [self.prefixMeanings setObject:fileName forKey:prefix];
    
    NSString* fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    
    NSArray* lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    NSError *error = NULL;
    NSRegularExpression *regexNeedsLocalization = [NSRegularExpression
                                                   regularExpressionWithPattern:@"NEEDS_LOCALIZATION\\h*\\(@\"(.*?[^\\\\])\", @\"(.*?[^\\\\])\", (.*?[^\\\\])\\)"
                                                   options:NSRegularExpressionCaseInsensitive
                                                   error:&error];
    
    NSRegularExpression *regexHasLocalization = [NSRegularExpression
                                                   regularExpressionWithPattern:@"NSLocalizedString\\(@\"(.*?[^\\\\])\".*?\\)"
                                                   options:NSRegularExpressionCaseInsensitive
                                                   error:&error];
    
    //output(@"%@\n", fileName);
    
    NSMutableString* newSourceFile =[NSMutableString string];
    BOOL firstLine = YES;
    for (NSString* line in lines) {
        if(!firstLine) {
            [newSourceFile appendString:@"\n"];
        }
        firstLine = NO;
        
        NSMutableString* newLine =[NSMutableString string];
        NSInteger lastMatchedIndex = 0;
        NSInteger* lastMatchedIndexPointer = &lastMatchedIndex;
        
        [regexNeedsLocalization enumerateMatchesInString:line options:0 range:NSMakeRange(0, line.length) usingBlock:
         ^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
             NSString* rawKey = [line substringWithRange:[result rangeAtIndex:1]];
             if(rawKey.length > 0) {
                 NSString* key = [NSString stringWithFormat:@"%@_%@", prefix, rawKey];
                 NSString* value = [line substringWithRange:[result rangeAtIndex:2]];
                 NSString* comment = [line substringWithRange:[result rangeAtIndex:3]];
                 [newLine appendString:[line substringWithRange:NSMakeRange((*lastMatchedIndexPointer), [result rangeAtIndex:0].location - (*lastMatchedIndexPointer))]];
                 [newLine appendFormat:@"NSLocalizedString(@\"%@\", nil)", key];
                 
                 
                 NSString* oldValue = [self.entries objectForKey:key];
                 if(oldValue && ![oldValue isEqualToString:value]) {
                     output(@"\n\nRedefinition of '%@' from '%@' to '%@'!\n\nAborting! Will output the current state of the strings file.\n", key, value, oldValue);
                     
                     NSInteger optionIndexStringsFile = [self.options indexOfObject:@"-s"] + 1;
                     NSString* stringsFilePath = [self.options objectAtIndex:optionIndexStringsFile];
                     
                     [self writeStringsFile:stringsFilePath];
                     exit(255);
                 }
                 [self.entries setObject:value forKey:key];
                 if(comment.length > 0 && ![comment isEqualToString:@"nil"] && ![comment isEqualToString:@"@\"\""]) {
                     [self.commentEntries setObject:[comment substringWithRange:NSMakeRange(2, comment.length - 3)] forKey:key];
                 }
             } else {
                 [newLine appendString:[line substringWithRange:NSMakeRange((*lastMatchedIndexPointer), [result rangeAtIndex:0].location - (*lastMatchedIndexPointer))]];
                 [newLine appendString:[line substringWithRange:[result rangeAtIndex:0]]];
             }
             *lastMatchedIndexPointer = [result rangeAtIndex:0].location + [result rangeAtIndex:0].length;
         }];

        [regexHasLocalization enumerateMatchesInString:line options:0 range:NSMakeRange(0, line.length) usingBlock:
         ^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
             NSString* key = [line substringWithRange:[result rangeAtIndex:1]];
             [self.usedKeys addObject:key];
         }];

        
        [newLine appendFormat:@"%@",[line substringWithRange:NSMakeRange(lastMatchedIndex, line.length - lastMatchedIndex)]];
        [newSourceFile appendString:newLine];
    }
    
    if([self.options containsObject:@"-o"]) {
        [newSourceFile writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    if([self.options containsObject:@"-l"]) {
        output(@"Implementation file:\n%@\n", newSourceFile);
    }
}

-(NSString*) stringByKeepingUpperCaseLetters:(NSString*)input {
    NSMutableString* ret = [NSMutableString string];
    for(NSInteger i = 0; i < input.length; i++) {
        unichar c = [input characterAtIndex:i];
        if(c >= 'A' && c <= 'Z') {
            [ret appendString:[input substringWithRange:NSMakeRange(i, 1)]];
        }
    }
    return ret;
}

-(NSString*) prefixUntilUnderscore:(NSString*)string {
    if([string rangeOfString:@"_"].location != NSNotFound) {
        return [string substringToIndex:[string rangeOfString:@"_"].location];
    }
    return @"";
}

-(void) writeStringsFile:(NSString*)stringsFilePath {
    NSError *error = NULL;
    
    NSMutableString* newStringsFile = [NSMutableString string];
    NSMutableString* newStringsDummyFile = [NSMutableString string];
    
    NSArray* sortedKeys = [self.entries.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString*  _Nonnull string1, NSString*  _Nonnull string2) {

        NSString* prefix1 = [self prefixUntilUnderscore:string1];
        NSString* prefix2 = [self prefixUntilUnderscore:string2];
       
        
        if(prefix2.length && !prefix1.length) {
            return NSOrderedAscending;
        }
        if(prefix1.length && !prefix2.length) {
            return NSOrderedDescending;
        }
        
        if([self stringContainsLowerCaseLetters:prefix1] && ![self stringContainsLowerCaseLetters:prefix2]) {
            return NSOrderedAscending;
        }
        if(![self stringContainsLowerCaseLetters:prefix1] && [self stringContainsLowerCaseLetters:prefix2]) {
            return NSOrderedDescending;
        }
        return [string1 compare:string2];
    }];
    
    NSString* lastPrefix = @"";
    for (NSString* key in sortedKeys) {
        NSString* value = [self.entries valueForKey:key];
        NSString* prefix =  [self prefixUntilUnderscore:key];
        if(![prefix isEqualToString:lastPrefix]) {
            if([self stringContainsLowerCaseLetters:prefix]) {
                [newStringsFile appendFormat:@"\n\n// %@\n", prefix];
                [newStringsDummyFile appendFormat:@"\n\n// %@\n", prefix];
            } else {
                NSString* prefixMeaning = [self.prefixMeanings objectForKey:prefix];
                if(!prefixMeaning) {
                    prefixMeaning = @"<something unknow>";
                }
                [newStringsFile appendFormat:@"\n\n// %@, short for %@\n", prefix, prefixMeaning];
                [newStringsDummyFile appendFormat:@"\n\n// %@, short for %@\n", prefix, prefixMeaning];
            }
            lastPrefix = prefix;
        }
        NSString* comment = [self.commentEntries valueForKey:key];
        if(comment) {
            [newStringsFile appendFormat:@"\n/*%@*/\n", comment];
            [newStringsDummyFile appendFormat:@"\n/*%@*/\n", comment];
        }
        [newStringsFile appendFormat:@"\"%@\" = \"%@\";\n", key, value];
        [newStringsDummyFile appendFormat:@"\"%@\" = \"%@\";\n", key, key];
    }
    
    if([self.options containsObject:@"-o"]) {
        [newStringsFile writeToFile:stringsFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if([self.options containsObject:@"-d"]) {
            NSInteger optionIndexDummy = [self.options indexOfObject:@"-d"];
            NSString* dummyLang = [self.options objectAtIndex:optionIndexDummy + 1];
            [newStringsDummyFile writeToFile:[stringsFilePath stringByReplacingOccurrencesOfString:@"de.lproj" withString:[NSString stringWithFormat:@"%@.lproj", dummyLang]] atomically:YES encoding:NSUTF8StringEncoding error:&error];
        }
    }
    if([self.options containsObject:@"-l"]) {
        output(@"Strings:\n%@\n", newStringsFile);
    }
}

-(void) readStringsFile:(NSString*)stringsFilePath {
    NSString* fileContents = [NSString stringWithContentsOfFile:stringsFilePath encoding:NSUTF8StringEncoding error:nil];
    
    NSArray* lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    NSError *error = NULL;
    NSRegularExpression *regexAssign = [NSRegularExpression
                                        regularExpressionWithPattern:@"\"(.*?[^\\\\])\".*?\"(.*?[^\\\\])\"" //@"\"(.*?)\"\\h*=\\h*\"(.*?)\";"
                                        options:NSRegularExpressionCaseInsensitive
                                        error:&error];
    
    NSRegularExpression *regexKeyComment = [NSRegularExpression
                                            regularExpressionWithPattern:@"/\\*(.*)\\*/"
                                            options:NSRegularExpressionCaseInsensitive
                                            error:&error];
    
    NSRegularExpression *regexSpecialComment = [NSRegularExpression
                                                regularExpressionWithPattern:@"// (.*?), short for (.*)"
                                                options:NSRegularExpressionCaseInsensitive
                                                error:&error];
    __block NSString* comment;
    
    for (NSString* line in lines) {
        [regexAssign enumerateMatchesInString:line options:0 range:NSMakeRange(0, line.length) usingBlock:
         ^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
             NSString* key = [line substringWithRange:[result rangeAtIndex:1]];
             NSString* value = [line substringWithRange:[result rangeAtIndex:2]];
             [self.entries setObject:value forKey:key];
             if(comment) {
                 [self.commentEntries setObject:comment forKey:key];
             }
         }];
        
        comment = nil;
        [regexKeyComment enumerateMatchesInString:line options:0 range:NSMakeRange(0, line.length) usingBlock:
         ^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
             comment = [line substringWithRange:[result rangeAtIndex:1]];
         }];
        
        [regexSpecialComment enumerateMatchesInString:line options:0 range:NSMakeRange(0, line.length) usingBlock:
         ^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
             NSString* key = [line substringWithRange:[result rangeAtIndex:1]];
             NSString* value = [line substringWithRange:[result rangeAtIndex:2]];
             [self.prefixMeanings setObject:value forKey:key];
         }];
    }
}

-(void)findDuplicateKeys {
    NSInteger countKeys = 0;
    NSInteger countValues = 0;
    
    NSArray* keys = [self.entries allKeys];
    NSMutableSet* baseKeys = [NSMutableSet set];
    
    for (NSString* key in keys) {
        [baseKeys addObject:[self reduceStringToBase:key]];
    }
        
    for (NSString* baseKey in baseKeys) {
        NSInteger count = 0;
        NSInteger maxLen = 0;
        for (NSString* key2 in keys) {
            if([baseKey isEqualToString:[self reduceStringToBase:key2]]) {
                count++;
                maxLen = MAX(maxLen, key2.length);
            }
        }
        if(count > 1) {
            //output(@"\n%ldx %@\n", count, baseKey);
            output(@"\n%40s:\n", baseKey.UTF8String);
            //output(@"\n");
            
            countKeys++;
            countValues += (count - 1);
            
            for (NSString* key2 in keys) {
                if([baseKey isEqualToString:[self reduceStringToBase:key2]]) {
                    output(@"%40s = '%@'\n", key2.UTF8String, [self.entries objectForKey:key2]);
                }
            }
        }
    }
    
    NSInteger totalValues = self.entries.count;
    
    output(@"\n\n%d keys have duplicates.\n", countKeys);
    output(@"%d values could be deleted at max. This would result in %.2f%% saving.\n\n", countValues, (countValues * 100.0f / totalValues));
}

-(void)findMissingKeys {
    NSMutableSet* possiblyMissingKeys = self.usedKeys.mutableCopy;
    for (NSString* key in self.entries) {
        [possiblyMissingKeys removeObject:key];
    }
    if(possiblyMissingKeys.count > 0) {
        output(@"\n\nThe following keys are used in the code but not defined in the strings file:\n");
        for (NSString* key in possiblyMissingKeys) {
            output(@"%@\n", key);
        }
    }
}

-(void)findUnusedKeys {
    NSMutableArray* possiblyUnusedKeys = self.entries.allKeys.mutableCopy;
    for (NSString* key in self.usedKeys) {
        [possiblyUnusedKeys removeObject:key];
    }
    if(possiblyUnusedKeys.count > 0) {
        output(@"\n\nThe following keys are defined in the strings file but not used in the code:\n");
        for (NSString* key in possiblyUnusedKeys) {
            output(@"%@\n", key);
        }
    }
}

-(void)findDuplicateValues {
    NSInteger countValues = 0;
    
    NSArray* keys = [self.entries allKeys];
    NSArray* values = [self.entries allValues];
    for (NSString* value in values) {
        NSInteger count = 0;
        for (NSString* key in keys) {
            if([[self.entries valueForKey:key] isEqualToString:value]) {
                count++;
            }
        }
        if(count > 1) {
            countValues += (count - 1);
            if([self.options indexOfObject:@"-v"] != NSNotFound) {
                output(@"\n%@\n", value);
            }
            if([self.options indexOfObject:@"-i"] != NSNotFound) {
                output(@"\nDo you want to merge the following keys which all map to the value '%@'?\n", value);
            }
            
            NSString* newKey = nil;
            
            //output(@"Value is used in %ld places: %@\n", count, value);
            for (NSString* key in keys) {
                if([[self.entries valueForKey:key] isEqualToString:value]) {
                    newKey = [self reduceStringToBase:key];
                    if([self.options indexOfObject:@"-v"] != NSNotFound || [self.options indexOfObject:@"-i"] != NSNotFound) {
                        output(@"\t%@\n", key);
                    }
                }
            }
            
            if([self.options indexOfObject:@"-i"] != NSNotFound) {
                if([self binaryInput]) {
                    output(@"Do you want to use %@ as the new key?\n", newKey);
                    if(![self binaryInput]) {
                        output(@"What else?\n");
                        newKey = [self input];
                    }
                    [self joinAllKeysWithValue:value intoKey:newKey];
                    NSInteger optionIndexStringsFile = [self.options indexOfObject:@"-s"] + 1;
                    NSString* stringsFilePath = [self.options objectAtIndex:optionIndexStringsFile];
                    [self writeStringsFile:stringsFilePath];
                }
            }
        }
    }
    
    NSInteger totalValues = self.entries.count;
    
    output(@"\n\n%d values could be deleted at max. This would result in %.2f%% saving.\n\n", countValues, (countValues * 100.0f / totalValues));
}

-(void) joinAllKeysWithValue:(NSString*)replacementValue intoKey:(NSString*)newKey {
    NSInteger optionIndexSeparator = [self.options indexOfObject:@"--"];
    for(NSInteger i = optionIndexSeparator + 1; i < self.options.count; i++) {
        NSString* filePath = [self.options objectAtIndex:i];
        NSString* fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        NSArray* lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        
        NSError *error = NULL;
        
        NSRegularExpression *regexHasLocalization = [NSRegularExpression
                                                     regularExpressionWithPattern:@"NSLocalizedString\\(@\"(.*?[^\\\\])\"(.*?\\))"
                                                     options:NSRegularExpressionCaseInsensitive
                                                     error:&error];
        
        NSMutableString* newSourceFile =[NSMutableString string];
        BOOL firstLine = YES;
        for (NSString* line in lines) {
            if(!firstLine) {
                [newSourceFile appendString:@"\n"];
            }
            firstLine = NO;
            
            NSMutableString* newLine =[NSMutableString string];
            NSInteger lastMatchedIndex = 0;
            NSInteger* lastMatchedIndexPointer = &lastMatchedIndex;
            
            [regexHasLocalization enumerateMatchesInString:line options:0 range:NSMakeRange(0, line.length) usingBlock:
             ^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                 NSString* oldKey = [line substringWithRange:[result rangeAtIndex:1]];
                 NSString* restOfMethodCall = [line substringWithRange:[result rangeAtIndex:2]];
                 NSString* value = [self.entries valueForKey:oldKey];
                 if([replacementValue isEqualToString:value]) {
                     [newLine appendString:[line substringWithRange:NSMakeRange((*lastMatchedIndexPointer), [result rangeAtIndex:0].location - (*lastMatchedIndexPointer))]];
                     [newLine appendFormat:@"NSLocalizedString(@\"%@\"%@", newKey, restOfMethodCall];
                     *lastMatchedIndexPointer = [result rangeAtIndex:0].location + [result rangeAtIndex:0].length;
                 }
             }];
            [newLine appendFormat:@"%@",[line substringWithRange:NSMakeRange(lastMatchedIndex, line.length - lastMatchedIndex)]];
            [newSourceFile appendString:newLine];
        }
        
        if([self.options containsObject:@"-o"]) {
            [newSourceFile writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        }
        if([self.options containsObject:@"-l"]) {
            output(@"Implementation file:\n%@\n", newSourceFile);
        }
    }
    NSMutableArray* oldKeys = [NSMutableArray array];
    for (NSString* key in self.entries.allKeys) {
        NSString* value = [self.entries valueForKey:key];
        if([value isEqualToString:replacementValue]) {
            [oldKeys addObject:key];
        }
    }
    [self.entries removeObjectsForKeys:oldKeys];
    [self.entries setObject:replacementValue forKey:newKey];
}

-(NSString*) input {
    NSMutableData* data = [NSMutableData data];
    uint8_t oneByte;
    do {
        //NSInteger actuallyRead = [self.inputStream read: &oneByte maxLength: 1];
        //if (actuallyRead == 1) {
        oneByte = getchar();
        //output(@"Read 1 byte: %d.", oneByte);
            if(oneByte == '\n') {
                break;
            }
            [data appendBytes: &oneByte length: 1];
        //} else {
        //    output(@"Read 0 bytes.");
        //}
    } while (YES);
    
    return [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
}

-(BOOL) binaryInput {
    NSString* answer = nil;
    while (true) {
        answer = [self input];
        if([answer isEqualToString:@"y"]) {
            return YES;
        }
        if([answer isEqualToString:@"n"]) {
            return NO;
        }
        output(@"Please enter 'y' or 'n'.");
    }
}

-(BOOL) key:(NSString*)key1 isSimilarTo:(NSString*) key2 {
    NSString* baseKey1 = [self reduceStringToBase:key1];
    NSString* baseKey2 = [self reduceStringToBase:key2];
    return [baseKey1 isEqualToString:baseKey2];
}

-(NSString*) reduceStringToBase:(NSString*)key {
    NSArray* kindParts = @[@"Title", @"Message", @"Action", @"Placeholder"];
    //NSArray* contextParts = @[@"Formal", @"Informal", @"Short", @"Long"];
    NSMutableArray* parts = [key componentsSeparatedByString:@"_"].mutableCopy;
    
    [parts removeObjectsInArray:kindParts];
    //[parts removeObjectsInArray:contextParts];
    
    if([parts.firstObject rangeOfCharacterFromSet:[NSCharacterSet lowercaseLetterCharacterSet]].location == NSNotFound) {
        [parts removeObjectAtIndex:0];
    }
    
    return [parts componentsJoinedByString:@"_"];
}

-(BOOL) stringContainsLowerCaseLetters:(NSString *)string {
    return [string rangeOfCharacterFromSet:[NSCharacterSet lowercaseLetterCharacterSet]].location != NSNotFound;
}

void output(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *formattedString = [[NSString alloc] initWithFormat: format
                                                       arguments: args];
    va_end(args);
    [[NSFileHandle fileHandleWithStandardOutput]
     writeData: [formattedString dataUsingEncoding: NSNEXTSTEPStringEncoding]];
}

@end
