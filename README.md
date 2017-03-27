# ios-string-localizer
Tool for processing localization files for iOS. It reads and updates Objective C code and the `Strings` file to keep them in sync.

_Note: This tool has been developed for a company-internal project and might need some adjustments to be useful for the general public._

# Build
Use Xcode to build this project.

# Usage

    StringLocalizer [-o [-d dummylang]][-k][-v][-u][-m][-w] [-j base] -s StringsPath
                    [-c SwiftPath] -- InputPath(s)

    Options are as follows:
    -o  Output into files. This overwrites the strings-file and each given source file.
    -d  Write a copy of the strings file where each value is not the actual value, but 
        the key itself. Use a two-letter code as dummylang.
    -w  Write the output for strings-file and source files to the console.
    -k  Find similar keys that could possibly be merged.
    -v  Find duplicate values hat could possibly me merged.
    -u  Find keys that are unused in the code, but unused in strings-file. Only use this
        when you pass all the source files.
    -m  Find keys that are used in the code, but missing in the strings-file.
    -j  Join all the keys that share the specified base. This only works if all matching 
        keys have the same value. Base is used as the new key. Only effective if used with
        -w or -o. Can be used multiple times per invocation.
    -i  Interactively join keys. This will display one suggestion at a time and ask if and 
        how it should be merged.
    -s  The next argument will be the path to the strings file.
    -c  Write a Swift file with constants to the given path
    --  The next argument(s) will be source file(s).
