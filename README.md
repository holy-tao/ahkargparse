# Argparse - Command-Line Argument Parser for AutoHotkey v2

A fluent-style argument parser for AutoHotkey v2, designed for CI/CD pipeline scripts and command-line tools. Parse flags, options, positional arguments, and lists with comprehensive type validation and helpful error messages.

## Features

- **Fluent Builder API**: Chainable methods for clean, readable code
- **POSIX-style syntax**: Support for `-v`, `--verbose`, `--output=file`, `--output file`
- **Type System**: String, Integer, Float with automatic conversion and validation
- **Advanced Validation**: Choice restrictions, custom validators, environment variable fallbacks
- **Help Generation**: Auto-generated `--help` text from argument definitions
- **Config File Support**: Load defaults from INI files
- **Environment Variable Fallback**: Load values from environmetn variables
- **Flexible Error Handling**: Configurable strictness and exit behavior
- **List Arguments**: Repeatable options with `action: "append"`

## Installation

Clone the repository into a library directory:
``` shell
git clone git@github.com:holy-tao/ahkargparse.git argparse
```

Include the library in your script:

```ahk
#Include <argparse/ArgumentParser>
```

### Dependencies

Argparse requires that my [extensions library](https://github.com/holy-tao/AhkExtensions) is available in a library directory for some error and string handling utilities.

## Table of Contents
- [Features](#features)
- [Installation](#installation)
  - [Dependencies](#dependencies)
- [Table of Contents](#table-of-contents)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [ArgumentParser Class](#argumentparser-class)
- [Value Precedence](#value-precedence)
- [Type Conversion](#type-conversion)
  - [String (default)](#string-default)
  - [Integer](#integer)
  - [Float](#float)
- [Validation](#validation)
  - [Choice Validation](#choice-validation)
  - [Custom Validators](#custom-validators)
- [Error Handling](#error-handling)
  - [Strict Mode](#strict-mode)
  - [Exit on Error](#exit-on-error)
  - [Required Arguments](#required-arguments)
- [Advanced Usage](#advanced-usage)
  - [List Arguments (Repeatable Options)](#list-arguments-repeatable-options)
  - [Combining Arguments](#combining-arguments)
  - [Environment Variables](#environment-variables)
  - [Config Files](#config-files)
- [Complete Example](#complete-example)
- [Limitations](#limitations)


## Quick Start

```ahk
#Requires AutoHotkey v2.0
#Include <Extensions/Argparse>

; Create parser
parser := ArgumentParser({
    description: "Process files for deployment",
    strict: true
})

; Define arguments
parser.AddFlag("verbose", {
    short: "v",
    long: "verbose",
    help: "Enable verbose output"
})

parser.AddOption("output", {
    short: "o",
    long: "output",
    default: "output.txt",
    help: "Output file path"
})

parser.AddPositional("input_file", {
    help: "Input file to process"
})

; Parse and use
result := parser.Parse(A_Args)

if result.verbose
    MsgBox("Processing " result.input_file " -> " result.output)
```

## API Reference

### ArgumentParser Class

#### Constructor

```ahk
parser := ArgumentParser(config?)
```

**Parameters:**
- `config` (Object, optional): Configuration object
  - `description` (String): Script description shown in help text
  - `strict` (Boolean): Throw error on unknown options (default: `true`)
  - `exitOnError` (Boolean): Exit process on parsing errors (default: `true`)

**Example:**
```ahk
parser := ArgumentParser({
    description: "My awesome script",
    strict: true,
    exitOnError: true
})
```

---

#### AddOption()

Add a named option that accepts a value.

```ahk
parser.AddOption(dest, config)
```

**Parameters:**
- `dest` (String): Property name in the result object
- `config` (Object): Configuration object
  - `short` (String): Short option name (single character)
  - `long` (String): Long option name
  - `type` (String): "String", "Integer", or "Float" (default: "String")
  - `choices` (Array): Array of valid values
  - `validator` (Func): Custom validation function
  - `envVar` (String): Environment variable name for fallback
  - `default` (Any): Default value if not provided
  - `action` (String): "store" or "append" (default: "store")
  - `required` (Boolean): Whether option is required (default: `false`)
  - `help` (String): Help text description

**Returns:** `this` (for chaining)

**Examples:**

Basic option:
```ahk
parser.AddOption("output", {
    short: "o",
    long: "output",
    help: "Output file path"
})
; Usage: script.ahk --output result.txt
; Usage: script.ahk -o result.txt
```

With type conversion:
```ahk
parser.AddOption("count", {
    long: "count",
    type: "Integer",
    default: 10,
    help: "Number of iterations"
})
; Usage: script.ahk --count 5
```

With choices:
```ahk
parser.AddOption("mode", {
    long: "mode",
    choices: ["debug", "release", "test"],
    default: "debug",
    help: "Build mode"
})
; Usage: script.ahk --mode release
```

With custom validator:
```ahk
parser.AddOption("port", {
    long: "port",
    type: "Integer",
    ; Using the Error.ThrowIf extension
    validator: (val) => (
        ValueError.ThrowIf((val >= 1024 && val <= 65535), "Port must be 1024-65535"),
        val)
    help: "Server port"
})
```

With environment variable fallback:
```ahk
parser.AddOption("api_key", {
    long: "api-key",
    envVar: "API_KEY",
    help: "API authentication key"
})
; Falls back to %API_KEY% environment variable if not provided
```

Repeatable option (list):
```ahk
parser.AddOption("include", {
    long: "include",
    action: "append",
    help: "Files to include (repeatable)"
})
; Usage: script.ahk --include file1.ahk --include file2.ahk
; Result: result.include = ["file1.ahk", "file2.ahk"]
```

---

#### AddFlag()

Add a boolean flag (no value required).

```ahk
parser.AddFlag(dest, config)
```

**Parameters:**
- `dest` (String): Property name in the result object
- `config` (Object): Configuration object
  - `short` (String): Short flag name (single character)
  - `long` (String): Long flag name
  - `action` (String): "store_true" (default)
  - `help` (String): Help text description

**Returns:** `this` (for chaining)

**Examples:**

```ahk
parser.AddFlag("verbose", {
    short: "v",
    long: "verbose",
    help: "Enable verbose logging"
})
; Usage: script.ahk --verbose
; Usage: script.ahk -v
; Result: result.verbose = true (if provided), false (if not)
```

Multiple flags:
```ahk
parser.AddFlag("debug", {long: "debug", help: "Enable debug mode"})
parser.AddFlag("force", {short: "f", long: "force", help: "Force operation"})
; Usage: script.ahk --debug -f
```

---

#### AddPositional()

Add a positional argument (position-dependent, no flag name).

```ahk
parser.AddPositional(dest, config?)
```

**Parameters:**
- `dest` (String): Property name in the result object
- `config` (Object, optional): Configuration object
  - `type` (String): "String", "Integer", or "Float" (default: "String")
  - `choices` (Array): Array of valid values
  - `validator` (Func): Custom validation function
  - `required` (Boolean): Whether argument is required (default: `true`)
  - `help` (String): Help text description

**Returns:** `this` (for chaining)

**Examples:**

```ahk
parser.AddPositional("input_file", {
    help: "Input file to process"
})
parser.AddPositional("output_file", {
    required: false,
    help: "Output file (optional)"
})
; Usage: script.ahk input.txt
; Usage: script.ahk input.txt output.txt
```

With type:
```ahk
parser.AddPositional("port", {
    type: "Integer",
    help: "Server port number"
})
; Usage: script.ahk 8080
```

---

#### Parse()

Parse command-line arguments and return result object.

```ahk
result := parser.Parse(args?)
```

**Parameters:**
- `args` (Array, optional): Array of strings to parse (default: `A_Args`)

**Returns:** Object with named properties for each defined argument

**Throws:**
- `ValueError`: For parsing errors (unless `exitOnError: true`)
- `TypeError`: For type conversion errors (unless `exitOnError: true`)

**Examples:**

Parse from command line:
```ahk
result := parser.Parse()  ; Uses A_Args
MsgBox("Output: " result.output)
```

Parse from custom array (useful for testing):
```ahk
result := parser.Parse(["--verbose", "-o", "test.txt", "input.ahk"])
```

---

#### LoadConfig()

Load default values from an INI configuration file.

```ahk
parser.LoadConfig(iniPath)
```

**Parameters:**
- `iniPath` (String): Path to INI file

**Returns:** `this` (for chaining)

**Throws:** `ValueError` if file not found

**INI Format:**
```ini
[ArgumentParser]
output = default_output.txt
verbose = true
count = 10
mode = debug
```

**Example:**
```ahk
parser.LoadConfig("config.ini")
result := parser.Parse()
; Values from config.ini used as defaults if not provided via CLI
```

---

#### GetHelp()

Generate formatted help text.

```ahk
helpText := parser.GetHelp()
```

**Returns:** String with formatted help text

**Example:**
```ahk
help := parser.GetHelp()
MsgBox(help)
```

**Sample Output:**
```
Process files for deployment

Usage: script.ahk [OPTIONS] <input_file> [output_file]

Positional Arguments:
  input_file          Input file to process
  output_file         Output file (optional)

Options:
  -h, --help          Show this help message and exit
  -v, --verbose       Enable verbose output (default: false)
  -o, --output <value> Output file path (default: output.txt)
  --count <value>     Number of iterations (type: Integer) (default: 10)
  --mode <value>      Build mode (choices: "debug", "release", "test") (default: debug)
  --include <value>   Files to include (repeatable)
```

---

## Value Precedence

When determining argument values, the parser follows this precedence order (highest to lowest):

1. **Command-line arguments** (highest priority)
2. **Environment variables** (via `envVar` config)
3. **Config file values** (via `LoadConfig()`)
4. **Default values** (via `default` config)

**Example:**
```ahk
parser.AddOption("output", {
    short: "o",
    long: "output",
    default: "default.txt",
    envVar: "BUILD_OUTPUT"
})

; Scenario 1: CLI provided
; Command: script.ahk --output cli.txt
; Result: result.output = "cli.txt"

; Scenario 2: ENV set, no CLI
; ENV: BUILD_OUTPUT=env.txt
; Command: script.ahk
; Result: result.output = "env.txt"

; Scenario 3: Config file loaded, no CLI or ENV
; config.ini: output = config.txt
; Command: script.ahk
; Result: result.output = "config.txt"

; Scenario 4: Only default
; Command: script.ahk
; Result: result.output = "default.txt"
```

---

## Type Conversion

Argparse automatically converts string arguments to the specified type.

### String (default)

No conversion, returns as-is.

```ahk
parser.AddOption("name", {long: "name", type: "String"})
result := parser.Parse(["--name", "hello"])
; result.name = "hello" (String)
```

### Integer

Converts to integer or throws `TypeError`.

```ahk
parser.AddOption("count", {long: "count", type: "Integer"})
result := parser.Parse(["--count", "42"])
; result.count = 42 (Integer)

result := parser.Parse(["--count", "abc"])
; Throws TypeError: "Option '--count' expects type Integer, but got 'abc'"
```

### Float

Converts to float or throws `TypeError`.

```ahk
parser.AddOption("ratio", {long: "ratio", type: "Float"})
result := parser.Parse(["--ratio", "3.14"])
; result.ratio = 3.14 (Float)
```

---

## Validation

### Choice Validation

Restrict values to a predefined list.

```ahk
parser.AddOption("mode", {
    long: "mode",
    choices: ["debug", "release", "test"],
    help: "Build mode"
})

result := parser.Parse(["--mode", "debug"])  ; OK
result := parser.Parse(["--mode", "production"])  ; Throws ValueError
; "Option '--mode' must be one of ["debug", "release", "test"], but got 'production'"
```

### Custom Validators

Provide a validation function that receives the converted value.

```ahk
parser.AddOption("port", {
    long: "port",
    type: "Integer",
    validator: ValidatePort,
    help: "Server port"
})

ValidatePort(val) {
    if (val < 1024 || val > 65535)
        throw ValueError("Port must be between 1024 and 65535")
    return val
}

result := parser.Parse(["--port", "8080"])  ; OK
result := parser.Parse(["--port", "80"])    ; Throws ValueError
```

**Validator Requirements:**
- Receives the already type-converted value
- Must return the value (can modify it)
- Throw `ValueError` for invalid values

---

## Error Handling

### Strict Mode

Control how unknown options are handled.

```ahk
; Strict mode (default) - throw error on unknown options
parser := ArgumentParser({strict: true})
result := parser.Parse(["--unknown"])
; Throws ValueError: "Unknown option: --unknown"

; Non-strict mode - ignore unknown options
parser := ArgumentParser({strict: false})
result := parser.Parse(["--unknown", "--output", "file.txt"])
; Ignores --unknown, continues parsing
; result.output = "file.txt"
```

### Exit on Error

Control whether errors exit the process or throw exceptions.

```ahk
; Exit on error (default) - shows error and exits with code 1
parser := ArgumentParser({exitOnError: true})
result := parser.Parse(["--count", "abc"])
; Displays error message and calls ExitApp(1)

; Throw on error - lets you handle exceptions
parser := ArgumentParser({exitOnError: false})
try {
    result := parser.Parse(["--count", "abc"])
} catch TypeError as err {
    MsgBox("Invalid input: " err.Message)
}
```

### Required Arguments

Mark arguments as required.

```ahk
parser.AddOption("api_key", {
    long: "api-key",
    required: true,
    help: "API key (required)"
})

result := parser.Parse([])
; Throws ValueError: "Required Option '--api-key' not provided"
```

**Note:** Options/flags are **not required** by default. Positionals **are required** by default.

---

## Advanced Usage

### List Arguments (Repeatable Options)

Use `action: "append"` to collect multiple values.

```ahk
parser.AddOption("include", {
    long: "include",
    short: "i",
    action: "append",
    help: "Files to include (repeatable)"
})

result := parser.Parse(["-i", "file1.ahk", "--include", "file2.ahk", "-i", "file3.ahk"])
; result.include = ["file1.ahk", "file2.ahk", "file3.ahk"]

result := parser.Parse([])
; result.include = [] (empty array if not provided)
```

### Combining Arguments

Mix flags, options, and positionals in any order.

```ahk
parser := ArgumentParser({description: "Build script"})
parser.AddFlag("verbose", {short: "v", long: "verbose"})
parser.AddFlag("force", {short: "f", long: "force"})
parser.AddOption("output", {short: "o", long: "output", default: "out.txt"})
parser.AddOption("threads", {long: "threads", type: "Integer", default: 4})
parser.AddPositional("input")

; All of these are valid:
result := parser.Parse(["-v", "-f", "--output", "result.txt", "--threads", "8", "input.ahk"])
result := parser.Parse(["input.ahk", "-vf", "-o", "result.txt", "--threads=8"])
result := parser.Parse(["--verbose", "input.ahk", "--force", "--output=result.txt"])

; Access results:
if result.verbose
    MsgBox("Verbose mode enabled")
if result.force
    MsgBox("Force mode enabled")
MsgBox("Input: " result.input "`nOutput: " result.output "`nThreads: " result.threads)
```

### Environment Variables

Automatically fall back to environment variables.

```ahk
parser.AddOption("api_key", {
    long: "api-key",
    envVar: "API_KEY",
    help: "API key (can use API_KEY env var)"
})

parser.AddOption("output_dir", {
    long: "output-dir",
    envVar: "BUILD_OUTPUT_DIR",
    default: "build/",
    help: "Output directory"
})

; If API_KEY=abc123 is set in environment:
result := parser.Parse([])
; result.api_key = "abc123" (from environment)

result := parser.Parse(["--api-key", "xyz789"])
; result.api_key = "xyz789" (CLI overrides environment)
```

### Config Files

Load defaults from INI files for complex scripts.

**config.ini:**
```ini
[ArgumentParser]
output = build/output.txt
threads = 8
verbose = true
mode = release
```

**Script:**
```ahk
parser := ArgumentParser()
parser.AddOption("output", {long: "output"})
parser.AddOption("threads", {long: "threads", type: "Integer"})
parser.AddFlag("verbose", {long: "verbose"})
parser.AddOption("mode", {long: "mode", choices: ["debug", "release"]})

parser.LoadConfig("config.ini")
result := parser.Parse([])

; result.output = "build/output.txt" (from config)
; result.threads = 8 (from config)
; result.verbose = true (from config)
; result.mode = "release" (from config)

; CLI arguments override config file:
result := parser.Parse(["--threads", "16"])
; result.threads = 16 (from CLI, overrides config)
```

---

## Complete Example

```ahk
#Requires AutoHotkey v2.0
#Include <Extensions/Argparse>

; Create parser
parser := ArgumentParser({
    description: "Deployment script for AHK projects",
    strict: true,
    exitOnError: true
})

; Global flags
parser.AddFlag("verbose", {
    short: "v",
    long: "verbose",
    help: "Enable verbose output"
})

parser.AddFlag("dry_run", {
    long: "dry-run",
    help: "Show what would be done without doing it"
})

; Configuration options
parser.AddOption("output_dir", {
    short: "o",
    long: "output",
    default: "dist/",
    envVar: "DEPLOY_OUTPUT",
    help: "Output directory for built files"
})

parser.AddOption("threads", {
    long: "threads",
    type: "Integer",
    default: 4,
    validator: (val) => (val > 0 && val <= 16) ? val : throw ValueError("Threads must be 1-16"),
    help: "Number of parallel threads"
})

parser.AddOption("mode", {
    long: "mode",
    choices: ["debug", "release"],
    default: "debug",
    help: "Build mode"
})

; Repeatable options
parser.AddOption("exclude", {
    long: "exclude",
    action: "append",
    help: "Patterns to exclude (repeatable)"
})

; Positional arguments
parser.AddPositional("project_dir", {
    help: "Project directory to deploy"
})

; Load config if exists
if FileExist("deploy.ini")
    parser.LoadConfig("deploy.ini")

; Parse arguments
result := parser.Parse()

; Use results
if result.verbose
    MsgBox("Verbose mode enabled")

if result.dry_run
    MsgBox("DRY RUN MODE - No changes will be made")

MsgBox("Deploying project: " result.project_dir "`n"
     . "Output: " result.output_dir "`n"
     . "Mode: " result.mode "`n"
     . "Threads: " result.threads "`n"
     . "Excludes: " (result.exclude.Length > 0 ? result.exclude.Length " patterns" : "none"))

; Perform deployment...
DeployProject(result)

DeployProject(config) {
    ; Your deployment logic here
}
```

**Usage Examples:**
```bash
# Basic usage
script.ahk C:\Projects\MyApp

# With flags and options
script.ahk -v --mode release --output build/ --threads 8 C:\Projects\MyApp

# Dry run with excludes
script.ahk --dry-run --exclude "*.tmp" --exclude "test/*" C:\Projects\MyApp

# Show help
script.ahk --help
```

---

## Limitations

1. **No combined short flags**: `-vxf` is not supported, use `-v -x -f` instead
2. **No subcommands**: Designed for single-command scripts (like `git commit` vs `git push`)
3. **POSIX-style only**: Windows-style `/option` syntax is not supported