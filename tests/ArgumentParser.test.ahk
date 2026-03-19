#Requires AutoHotkey v2.0

#Requires AutoHotkey v2.0

#Include ./YUnit/Assert.ahk
#Include ./YUnit/Yunit.ahk
#Include ./YUnit/Stdout.ahk

#Include ../ArgumentParser.ahk
    #Include <Extensions\MapExtensions>

class ArgumentParserTests {

    class Basic {
        Parse_SimpleOption_ReturnsValue() {
            parser := ArgumentParser()
            parser.AddOption("output", {long: "output"})

            result := parser.Parse(["--output", "file.txt"])

            Assert.Equals("file.txt", result.output)
        }

        Parse_OptionWithEquals_ReturnsValue() {
            parser := ArgumentParser()
            parser.AddOption("output", {long: "output"})

            result := parser.Parse(["--output=file.txt"])

            Assert.Equals("file.txt", result.output)
        }

        Parse_ShortOption_ReturnsValue() {
            parser := ArgumentParser()
            parser.AddOption("output", {short: "o"})

            result := parser.Parse(["-o", "file.txt"])

            Assert.Equals("file.txt", result.output)
        }

        Parse_ShortOptionWithEquals_ReturnsValue() {
            parser := ArgumentParser()
            parser.AddOption("output", {short: "o"})

            result := parser.Parse(["-o=file.txt"])

            Assert.Equals("file.txt", result.output)
        }

        Parse_MultipleOptions_ReturnsAllValues() {
            parser := ArgumentParser()
            parser.AddOption("output", {long: "output"})
            parser.AddOption("input", {long: "input"})

            result := parser.Parse(["--output", "out.txt", "--input", "in.txt"])

            Assert.Equals("out.txt", result.output)
            Assert.Equals("in.txt", result.input)
        }
    }

    class Flags {
        AddFlag_DefaultValueIsFalse() {
            parser := ArgumentParser()
            parser.AddFlag("verbose", {long: "verbose"})

            result := parser.Parse([])

            Assert.Equals(false, result.verbose)
        }

        Parse_FlagPresent_ReturnsTrue() {
            parser := ArgumentParser()
            parser.AddFlag("verbose", {long: "verbose"})

            result := parser.Parse(["--verbose"])

            Assert.Equals(true, result.verbose)
        }

        Parse_FlagAbsent_ReturnsFalse() {
            parser := ArgumentParser()
            parser.AddFlag("verbose", {long: "verbose"})

            result := parser.Parse([])

            Assert.Equals(false, result.verbose)
        }

        Parse_ShortFlag_ReturnsTrue() {
            parser := ArgumentParser()
            parser.AddFlag("verbose", {short: "v"})

            result := parser.Parse(["-v"])

            Assert.Equals(true, result.verbose)
        }

        Parse_MultipleFlags_ReturnsAll() {
            parser := ArgumentParser()
            parser.AddFlag("verbose", {long: "verbose"})
            parser.AddFlag("debug", {long: "debug"})

            result := parser.Parse(["--verbose"])

            Assert.Equals(true, result.verbose)
            Assert.Equals(false, result.debug)
        }
    }

    class Positionals {
        Parse_SinglePositional_ReturnsValue() {
            parser := ArgumentParser()
            parser.AddPositional("input")

            result := parser.Parse(["file.txt"])

            Assert.Equals("file.txt", result.input)
        }

        Parse_MultiplePositionals_ReturnsInOrder() {
            parser := ArgumentParser()
            parser.AddPositional("input")
            parser.AddPositional("output")

            result := parser.Parse(["in.txt", "out.txt"])

            Assert.Equals("in.txt", result.input)
            Assert.Equals("out.txt", result.output)
        }

        Parse_PositionalsWithOptions_ParsesCorrectly() {
            parser := ArgumentParser()
            parser.AddOption("verbose", {long: "verbose"})
            parser.AddPositional("input")

            result := parser.Parse(["--verbose", "true", "file.txt"])

            Assert.Equals("true", result.verbose)
            Assert.Equals("file.txt", result.input)
        }

        Parse_MissingRequiredPositional_ThrowsError() {
            parser := ArgumentParser({exitOnError: false})
            parser.AddPositional("input", {required: true})

            Assert.Throws((*) => parser.Parse([]), ValueError)
        }

        Parse_OptionalPositional_AllowsMissing() {
            parser := ArgumentParser()
            parser.AddPositional("input", {required: false})

            result := parser.Parse([])

            Assert.Equals(result.HasOwnProp("input"), false)
        }
    }

    class Types {
        Parse_IntegerOption_ConvertsToInteger() {
            parser := ArgumentParser()
            parser.AddOption("count", {long: "count", type: "Integer"})

            result := parser.Parse(["--count", "42"])

            Assert.Equals(42, result["count"])
            Assert.IsType(result["count"], Integer)
        }

        Parse_FloatOption_ConvertsToFloat() {
            parser := ArgumentParser()
            parser.AddOption("ratio", {long: "ratio", type: "Float"})

            result := parser.Parse(["--ratio", "3.14"])

            Assert.Equals(3.14, result.ratio)
            Assert.IsType(result.ratio, Float)
        }

        Parse_InvalidInteger_ThrowsTypeError() {
            parser := ArgumentParser({exitOnError: false})
            parser.AddOption("count", {long: "count", type: "Integer"})

            Assert.Throws((*) => parser.Parse(["--count", "abc"]), TypeError)
        }

        Parse_InvalidFloat_ThrowsTypeError() {
            parser := ArgumentParser({exitOnError: false})
            parser.AddOption("ratio", {long: "ratio", type: "Float"})

            Assert.Throws((*) => parser.Parse(["--ratio", "abc"]), TypeError)
        }

        Parse_StringOption_ReturnsString() {
            parser := ArgumentParser()
            parser.AddOption("name", {long: "name", type: "String"})

            result := parser.Parse(["--name", "test"])

            Assert.Equals("test", result.name)
            Assert.IsType(result.name, String)
        }
    }

    class Validation {
        Parse_ChoiceValid_ReturnsValue() {
            parser := ArgumentParser()
            parser.AddOption("mode", {long: "mode", choices: ["debug", "release"]})

            result := parser.Parse(["--mode", "debug"])

            Assert.Equals("debug", result.mode)
        }

        Parse_ChoiceInvalid_ThrowsError() {
            parser := ArgumentParser({exitOnError: false})
            parser.AddOption("mode", {long: "mode", choices: ["debug", "release"]})

            Assert.Throws((*) => parser.Parse(["--mode", "invalid"]), ValueError)
        }

        Parse_CustomValidator_ValidValue_ReturnsValue() {
            parser := ArgumentParser()
            parser.AddOption("count", {long: "count", type: "Integer", validator: CustomValidator})

            result := parser.Parse(["--count", "5"])

            Assert.Equals(5, result["count"])

            CustomValidator(val) {
                if(val <= 0)
                    throw ValueError("Must be positive")
                return val
            }
        }

        Parse_CustomValidator_InvalidValue_ThrowsError() {
            parser := ArgumentParser({exitOnError: false})
            parser.AddOption("count", {long: "count", type: "Integer", validator: CustomValidator})

            Assert.Throws((*) => parser.Parse(["--count", "-5"]), ValueError)

            CustomValidator(val) {
                if(val <= 0)
                    throw ValueError("Must be positive")
                return val
            }
        }
    }

    class Lists {
        Parse_AppendAction_SingleValue_CreatesArray() {
            parser := ArgumentParser()
            parser.AddOption("include", {long: "include", action: "append"})

            result := parser.Parse(["--include", "file1.ahk"])

            Assert.ArraysEqual(["file1.ahk"], result.include)
        }

        Parse_AppendAction_MultipleValues_ReturnsArray() {
            parser := ArgumentParser()
            parser.AddOption("include", {long: "include", action: "append"})

            result := parser.Parse(["--include", "file1.ahk", "--include", "file2.ahk"])

            Assert.ArraysEqual(["file1.ahk", "file2.ahk"], result.include)
        }

        Parse_AppendAction_NoValues_ReturnsEmptyArray() {
            parser := ArgumentParser()
            parser.AddOption("include", {long: "include", action: "append"})

            result := parser.Parse([])

            Assert.ArraysEqual([], result.include)
        }
    }

    class Defaults {
        Parse_OptionNotProvided_ReturnsDefault() {
            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", default: "default.txt"})

            result := parser.Parse([])

            Assert.Equals("default.txt", result.output)
        }

        Parse_OptionProvided_OverridesDefault() {
            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", default: "default.txt"})

            result := parser.Parse(["--output", "custom.txt"])

            Assert.Equals("custom.txt", result.output)
        }

        Parse_EnvironmentVariable_FallsBack() {
            EnvSet("TEST_OUTPUT", "env_value.txt")

            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", envVar: "TEST_OUTPUT"})

            result := parser.Parse([])

            Assert.Equals("env_value.txt", result.output)

            ; Cleanup
            EnvSet("TEST_OUTPUT", "")
        }

        Parse_Precedence_CliOverridesEnv() {
            EnvSet("TEST_OUTPUT", "env_value.txt")

            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", envVar: "TEST_OUTPUT"})

            result := parser.Parse(["--output", "cli_value.txt"])

            Assert.Equals("cli_value.txt", result.output)

            ; Cleanup
            EnvSet("TEST_OUTPUT", "")
        }
    }

    class Errors {
        Parse_UnknownOption_Strict_ThrowsError() {
            parser := ArgumentParser({strict: true, exitOnError: false})

            Assert.Throws((*) => parser.Parse(["--unknown"]), ValueError)
        }

        Parse_UnknownOption_NonStrict_Ignores() {
            parser := ArgumentParser({strict: false})
            parser.AddOption("output", {long: "output"})

            result := parser.Parse(["--unknown", "--output", "file.txt"])

            Assert.Equals("file.txt", result.output)
        }

        Parse_MissingRequiredOption_ThrowsError() {
            parser := ArgumentParser({exitOnError: false})
            parser.AddOption("output", {long: "output", required: true})

            Assert.Throws((*) => parser.Parse([]), ValueError)
        }

        Parse_DuplicateDestination_ThrowsError() {
            parser := ArgumentParser()
            parser.AddOption("output", {long: "output"})

            Assert.Throws((*) => parser.AddOption("output", {long: "out"}), ValueError)
        }
    }

    class Help {
        GetHelp_GeneratesUsageLine() {
            parser := ArgumentParser({description: "Test parser"})
            parser.AddOption("output", {long: "output", help: "Output file"})

            help := parser.GetHelp()
            FileAppend(help "`n", "*")

            Assert.Equals(InStr(help, "Usage:") > 0, true)
            Assert.Equals(InStr(help, A_ScriptName) > 0, true)
        }

        GetHelp_ShowsAllArguments() {
            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", help: "Output file"})
            parser.AddFlag("verbose", {long: "verbose", short: "v", help: "Verbose mode"})

            help := parser.GetHelp()
            FileAppend(help "`n", "*")

            Assert.Equals(InStr(help, "--output") > 0, true)
            Assert.Equals(InStr(help, "--verbose") > 0, true)
            Assert.Equals(InStr(help, " -v") > 0, true)
            Assert.Equals(InStr(help, "Output file") > 0, true)
            Assert.Equals(InStr(help, "Verbose mode") > 0, true)
        }

        GetHelp_ShowsDefaults() {
            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", default: "out.txt", help: "Output file"})

            help := parser.GetHelp()
            FileAppend(help "`n", "*")

            Assert.Equals(InStr(help, "default: out.txt") > 0, true)
        }

        GetHelp_ShowsChoices() {
            parser := ArgumentParser()
            parser.AddOption("mode", {long: "mode", choices: ["debug", "release"], help: "Build mode"})

            help := parser.GetHelp()
            FileAppend(help "`n", "*")

            Assert.Equals(InStr(help, "choices:") > 0, true)
            Assert.Equals(InStr(help, "debug") > 0, true)
            Assert.Equals(InStr(help, "release") > 0, true)
        }

        GetHelp_ShowsPositionalArgs() {
            parser := ArgumentParser()
            parser.AddPositional("file", {long: "file", short: "f", help: "The file to process"})
            parser.AddPositional("operation", {long: "operation", choices: ["read", "write"], help: "The operation to perform"})

            help := parser.GetHelp()
            FileAppend(help "`n", "*")

            Assert.Equals(InStr(help, "file") > 0, true)
            Assert.Equals(InStr(help, "The file to process") > 0, true)
            Assert.Equals(InStr(help, "Positional Arguments:") > 0, true)

            Assert.Equals(InStr(help, "operation") > 0, true)
            Assert.Equals(InStr(help, "The operation to perform (choices: `"read`", `"write`")") > 0, true)
        }
    }

    class Integration {
        Parse_ComplexScenario_ParsesCorrectly() {
            parser := ArgumentParser({description: "Test script"})
            parser.AddFlag("verbose", {short: "v", long: "verbose", help: "Verbose output"})
            parser.AddOption("output", {short: "o", long: "output", default: "out.txt", help: "Output file"})
            parser.AddOption("count", {long: "count", type: "Integer", default: 1, help: "Iteration count"})
            parser.AddOption("mode", {long: "mode", choices: ["debug", "release"], default: "debug"})
            parser.AddPositional("input", {help: "Input file"})

            result := parser.Parse(["-v", "--output", "result.txt", "--count", "5", "--mode", "release", "input.ahk"])

            Assert.Equals(true, result.verbose)
            Assert.Equals("result.txt", result.output)
            Assert.Equals(5, result.count)
            Assert.Equals("release", result.mode)
            Assert.Equals("input.ahk", result.input)
        }

        Parse_EmptyArgs_UsesDefaults() {
            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", default: "default.txt"})
            parser.AddFlag("verbose", {long: "verbose"})

            result := parser.Parse([])

            Assert.Equals("default.txt", result.output)
            Assert.Equals(false, result.verbose)
        }
    }

    class ConfigLoading {
        LoadConfig_SimpleValues_LoadsSuccessfully() {
            ; Create temporary config file
            configPath := A_Temp "\argparse_test_simple_" A_TickCount "_" Random() ".ini"
            FileAppend("[ArgumentParser]`noutput = config_output.txt`ncount = 42`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("output", {long: "output"})
            parser.AddOption("count", {long: "count", type: "Integer"})
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals("config_output.txt", result["output"])
            Assert.Equals(42, result["count"])

            ; Cleanup
            FileDelete(configPath)
        }

        LoadConfig_ConfigUsedAsFallback_WhenNoCliArg() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`noutput = from_config.txt`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("output", {long: "output"})
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals("from_config.txt", result["output"])

            FileDelete(configPath)
        }

        LoadConfig_CliOverridesConfig_WhenBothProvided() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`noutput = from_config.txt`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("output", {long: "output"})
            parser.LoadConfig(configPath)

            result := parser.Parse(["--output", "from_cli.txt"])

            Assert.Equals("from_cli.txt", result.output)

            FileDelete(configPath)
        }

        LoadConfig_EnvOverridesConfig_WhenBothProvided() {
            EnvSet("TEST_CONFIG_OUTPUT", "from_env.txt")
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`noutput = from_config.txt`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", envVar: "TEST_CONFIG_OUTPUT"})
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals("from_env.txt", result.output)

            FileDelete(configPath)
            EnvSet("TEST_CONFIG_OUTPUT", "")
        }

        LoadConfig_IntegerType_ConvertsCorrectly() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`ncount = 99`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("count", {long: "count", type: "Integer"})
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals(99, result["count"])
            Assert.IsType(result["count"], Integer)

            FileDelete(configPath)
        }

        LoadConfig_FloatType_ConvertsCorrectly() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`nratio = 3.14159`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("ratio", {long: "ratio", type: "Float"})
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals(3.14159, result.ratio)
            Assert.IsType(result.ratio, Float)

            FileDelete(configPath)
        }

        LoadConfig_FlagValue_ParsesBoolean() {
            configPath := A_Temp "\argparse_test_flag_" A_TickCount "_" Random() ".ini"
            FileAppend("[ArgumentParser]`nverbose = 1`n", configPath)

            parser := ArgumentParser()
            parser.AddFlag("verbose", {long: "verbose"})
            parser.LoadConfig(configPath)

            
            result := parser.Parse([])

            ; In AHK, flags from config will be 1 (truthy)
            Assert.Equals(1, result.verbose)

            FileDelete(configPath)
        }

        LoadConfig_ChoicesValidation_ValidatesCorrectly() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`nmode = release`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("mode", {long: "mode", choices: ["debug", "release", "test"]})
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals("release", result.mode)

            FileDelete(configPath)
        }

        LoadConfig_ChoicesValidation_ThrowsOnInvalid() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`nmode = invalid`n", configPath)

            parser := ArgumentParser({exitOnError: false})
            parser.AddOption("mode", {long: "mode", choices: ["debug", "release"]})
            parser.LoadConfig(configPath)

            Assert.Throws((*) => parser.Parse([]), ValueError)

            FileDelete(configPath)
        }

        LoadConfig_CustomValidator_ValidatesCorrectly() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`nport = 8080`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("port", {
                long: "port",
                type: "Integer",
                validator: ValidatePort
            })
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals(8080, result.port)

            FileDelete(configPath)

            ValidatePort(val) {
                if (val < 1024 || val > 65535)
                    throw ValueError("Port must be between 1024 and 65535")
                return val
            }
        }

        LoadConfig_CustomValidator_ThrowsOnInvalid() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`nport = 80`n", configPath)

            parser := ArgumentParser({exitOnError: false})
            parser.AddOption("port", {
                long: "port",
                type: "Integer",
                validator: ValidatePort
            })
            parser.LoadConfig(configPath)

            Assert.Throws((*) => parser.Parse([]), ValueError)

            FileDelete(configPath)

            ValidatePort(val) {
                if (val < 1024 || val > 65535)
                    throw ValueError("Port must be between 1024 and 65535")
                return val
            }
        }

        LoadConfig_NonExistentFile_ThrowsError() {
            parser := ArgumentParser({exitOnError: false})

            Assert.Throws((*) => parser.LoadConfig("C:\nonexistent\config.ini"), ValueError)
        }

        LoadConfig_MultipleOptions_LoadsAll() {
            configPath := A_Temp "\argparse_test_multi_" A_TickCount "_" Random() ".ini"
            FileAppend("[ArgumentParser]`noutput = out.txt`ncount = 10`nmode = release`nverbose = 1`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("output", {long: "output"})
            parser.AddOption("count", {long: "count", type: "Integer"})
            parser.AddOption("mode", {long: "mode"})
            parser.AddFlag("verbose", {long: "verbose"})
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals("out.txt", result["output"])
            Assert.Equals(10, result["count"])
            Assert.Equals("release", result["mode"])
            Assert.Equals(1, result["verbose"])

            FileDelete(configPath)
        }

        LoadConfig_ConfigOverridesDefaults_WhenProvided() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`noutput = from_config.txt`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", default: "default.txt"})
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals("from_config.txt", result.output)

            FileDelete(configPath)
        }

        LoadConfig_DefaultsUsed_WhenConfigMissing() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`nother = value`n", configPath)

            parser := ArgumentParser()
            parser.AddOption("output", {long: "output", default: "default.txt"})
            parser.LoadConfig(configPath)

            result := parser.Parse([])

            Assert.Equals("default.txt", result.output)

            FileDelete(configPath)
        }

        LoadConfig_Precedence_CliEnvConfigDefault() {
            EnvSet("TEST_PRECEDENCE", "from_env.txt")
            configPath := A_Temp "\argparse_test_prec_" A_TickCount "_" Random() ".ini"
            FileAppend("[ArgumentParser]`noutput = from_config.txt`n", configPath)

            ; Test CLI > all
            parser := ArgumentParser()
            parser.AddOption("output", {
                long: "output",
                default: "default.txt",
                envVar: "TEST_PRECEDENCE"
            })
            parser.LoadConfig(configPath)
            result := parser.Parse(["--output", "from_cli.txt"])
            Assert.Equals("from_cli.txt", result.output)

            ; Test Env > Config > Default
            parser := ArgumentParser()
            parser.AddOption("output", {
                long: "output",
                default: "default.txt",
                envVar: "TEST_PRECEDENCE"
            })
            parser.LoadConfig(configPath)
            result := parser.Parse([])
            Assert.Equals("from_env.txt", result.output)

            ; Test Config > Default (without env)
            EnvSet("TEST_PRECEDENCE", "")
            parser := ArgumentParser()
            parser.AddOption("output", {
                long: "output",
                default: "default.txt",
                envVar: "TEST_PRECEDENCE"
            })
            parser.LoadConfig(configPath)
            result := parser.Parse([])
            Assert.Equals("from_config.txt", result.output)

            FileDelete(configPath)
        }

        LoadConfig_InvalidInteger_ThrowsTypeError() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`ncount = not_a_number`n", configPath)

            parser := ArgumentParser({exitOnError: false})
            parser.AddOption("count", {long: "count", type: "Integer"})
            parser.LoadConfig(configPath)

            Assert.Throws((*) => parser.Parse([]), TypeError)

            FileDelete(configPath)
        }

        LoadConfig_InvalidFloat_ThrowsTypeError() {
            configPath := A_Temp "\argparse_test_" A_TickCount ".ini"
            FileAppend("[ArgumentParser]`nratio = not_a_float`n", configPath)

            parser := ArgumentParser({exitOnError: false})
            parser.AddOption("ratio", {long: "ratio", type: "Float"})
            parser.LoadConfig(configPath)

            Assert.Throws((*) => parser.Parse([]), TypeError)

            FileDelete(configPath)
        }
    }
}

; Run tests if file is executed directly
if A_ScriptName == "Argparse.Test.ahk" {
    YUnit.Use(YUnitStdOut).Test(ArgumentParserTests)
}