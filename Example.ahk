#Requires AutoHotkey v2.0

#Include ./ArgumentParser.ahk

; Example script demonstrating Argparse usage
parser := ArgumentParser({
    description: "Example script showing Argparse features for CI/CD pipelines",
    strict: true,
    exitOnError: true
})

; Add a flag
parser.AddFlag("verbose", {
    short: "v",
    long: "verbose",
    help: "Enable verbose output"
})

; Add options with various features
parser.AddOption("output", {
    short: "o",
    long: "output",
    type: "String",
    default: "output.txt",
    envVar: "BUILD_OUTPUT",
    help: "Output file path"
})

parser.AddOption("count", {
    long: "count",
    type: "Integer",
    default: 1,
    help: "Number of iterations"
})

parser.AddOption("mode", {
    long: "mode",
    choices: ["debug", "release", "test"],
    default: "debug",
    help: "Build mode"
})

; Add repeatable option
parser.AddOption("include", {
    short: "i",
    long: "include",
    action: "append",
    help: "Files to include"
})

; Add positional argument
parser.AddPositional("input_file", {
    type: "String",
    help: "Input file to process"
})

; Parse arguments (uses A_Args by default, or pass an array for testing)
; Example command line:
; ArgparseExample.ahk -v --output result.txt --count 5 --mode release --include file1.ahk --include file2.ahk input.ahk

result := parser.Parse(["-h", "inputFile", "--mode", "baz", "--include", "otherfile.txt", "-i", "otherfile.ahk", "--verbose"])

; Use the parsed arguments
MsgBox("Parsed Arguments:`n`n"
     . "Verbose: " result.verbose "`n"
     . "Output: " result.output "`n"
     . "Count: " result.count "`n"
     . "Mode: " result.mode "`n"
     . "Input File: " result.input_file "`n"
     . "Includes: " (result.HasOwnProp("include") ? result.include.Length " file(s)" : "none"),
     "Argparse Example",
     "OK")