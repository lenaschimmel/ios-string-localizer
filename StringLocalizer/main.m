//
//  main.m
//  StringLocalizer
//
//  Created by Lena Schimmel on 03.11.15.
//  Copyright © 2015 DeliveryHero. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Converter.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSMutableArray<NSString*> *args = [NSMutableArray array];
        for(NSInteger i = 0; i < argc; i++) {
            NSMutableString* string = [NSMutableString stringWithUTF8String:argv[i]];
            if([string characterAtIndex:0] == '"') {
                while([string characterAtIndex:string.length-1] != '"') {
                    [string appendString:@" "];
                    [string appendString:[NSString stringWithUTF8String:argv[1+i]]];
                    i++;
                };
                [args addObject:[string substringWithRange:NSMakeRange(1, string.length - 2)]];
            } else {
                [args addObject:string];
            }
        }
        
        NSInteger optionIndexWriteFlag = [args indexOfObject:@"-w"];
        NSInteger optionIndexKeysFlag = [args indexOfObject:@"-k"];
        NSInteger optionIndexValuesFlag = [args indexOfObject:@"-v"];
        NSInteger optionIndexStringsFile = [args indexOfObject:@"-s"] + 1;
        NSInteger optionIndexSwiftFlag = [args indexOfObject:@"-c"];
        NSInteger optionIndexSeparator = [args indexOfObject:@"--"];
        NSInteger optionIndexUnusedFlag = [args indexOfObject:@"-u"];
        NSInteger optionIndexMissingFlag = [args indexOfObject:@"-m"];
        
        if(args.count >= optionIndexStringsFile && optionIndexSeparator > optionIndexStringsFile && optionIndexSeparator != NSNotFound) {
            NSString* stringsFilePath =[args objectAtIndex:optionIndexStringsFile];
        
            Converter* converter = [[Converter alloc] initWithOptions:[args subarrayWithRange:NSMakeRange(1, args.count - 1)]];
            [converter readStringsFile:stringsFilePath];
            
            [converter convertAllFiles];
            
            [converter writeStringsFile:stringsFilePath];
            
            if(optionIndexSwiftFlag != NSNotFound) {
                NSString* swiftFilePath = [args objectAtIndex:optionIndexSwiftFlag + 1];
                [converter writeSwiftStringsFile:swiftFilePath];
            }
            
            if(optionIndexValuesFlag != NSNotFound) {
                [converter findDuplicateValues];
            }
            
            if(optionIndexKeysFlag != NSNotFound) {
                [converter findDuplicateKeys];
            }
            
            if(optionIndexMissingFlag != NSNotFound) {
                [converter findMissingKeys];
            }
            
            if(optionIndexUnusedFlag != NSNotFound) {
                [converter findUnusedKeys];
            }

        } else {
            output(@"Too few options. Syntax is:\n\nStringLocalizer [-o [-d dummylang]][-k][-v][-u][-m][-w] [-j base] -s StringsPath  [-c SwiftPath] -- InputPath(s)\n");
            output(@"\n");
            output(@"Options are as follows:\n");
            output(@"\t-o\tOutput into files. This overwrites the strings-file and each given source file.\n");
            output(@"\t-d\tWrite a copy of the strings file where each value is not the actual value, but the key itself. Use a two-letter code as dummylang.\n");
            output(@"\t-w\tWrite the output for strings-file and source files to the console.\n");
            output(@"\t-k\tFind similar keys that could possibly be merged.\n");
            output(@"\t-v\tFind duplicate values hat could possibly me merged.\n");
            output(@"\t-u\tFind keys that are unused in the code, but unused in strings-file. Only use this when you pass all the source files.\n");
            output(@"\t-m\tFind keys that are used in the code, but missing in the strings-file.\n");
            //output(@"\t-j\tJoin all the keys that share the specified base. This only works if all matching keys have the same value. Base is used as the new key. Only effective if used with -w or -o. Can be used multiple times per invocation.\n");
            output(@"\t-i\tInteractively join keys. This will display one suggestion at a time and ask if and how it should be merged.\n");
            output(@"\t-s\tThe next argument will be the path to the strings file.\n");
            output(@"\t-c\tWrite a Swift file with constants to the given path\n");
            output(@"\t--\tThe next argument(s) will be source file(s).\n");
        }
    }
    return 0;
}