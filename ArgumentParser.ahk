#Requires AutoHotkey v2.0

#Include <Extensions\Errors\ErrorExtensions>
#Include <Extensions\Errors\TypeErrorExtensions>
#Include <Extensions\Errors\ValueErrorExtensions>
#Include <Extensions\StringExtensions>

#Include ./ArgumentDefinition.ahk

/**
 * Fluent-style argument parser for AutoHotkey v2
 * Parse command-line arguments with flags, options, and positionals
 */
class ArgumentParser {
    _config := {description: "", strict: true, exitOnError: true}
    _definitions := Map()
    _positionals := []
    _configValues := Map()

    /**
     * Creates a new ArgumentParser
     * @param {Object} config Optional configuration
     *   - description: Script description for help text
     *   - strict: Throw error on unknown options (default: true)
     *   - exitOnError: Exit process on error (default: true)
     */
    __New(config := {}) {
        TypeError.ThrowIfNot(config, Object, -2)

        (config.HasOwnProp("description") && this._config.description := config.description)
        (config.HasOwnProp("strict") && this._config.strict := config.strict)
        (config.HasOwnProp("exitOnError") && this._config.exitOnError := config.exitOnError)
    }

    /**
     * Adds an option argument to the parser
     * @param {String} dest The property name in the result object
     * @param {Object} config Configuration object
     *   - short: Short option name (single char)
     *   - long: Long option name
     *   - type: "String", "Integer", or "Float" (default: "String")
     *   - choices: Array of valid values
     *   - validator: Custom validation function
     *   - envVar: Environment variable for fallback
     *   - default: Default value
     *   - action: "store" or "append" (default: "store")
     *   - help: Help text
     * @returns {ArgumentParser} this (for chaining)
     */
    AddOption(dest, config) {
        TypeError.ThrowIfNot(dest, String, -2)
        TypeError.ThrowIfNot(config, Object, -2)

        ; Validate that at least short or long is provided
        ValueError.ThrowIf(!config.HasOwnProp("short") && !config.HasOwnProp("long"),
            "Must provide 'short' or 'long' option name")

        ; Check for duplicate destination
        ValueError.ThrowIf(this._definitions.Has(dest), "Duplicate argument destination: '" dest "'")

        ; Options are not required by default (can be overridden in config)
        (config.HasOwnProp("required") || config.required := false)

        ; Create and store definition
        definition := ArgumentDefinition(dest, "option", config)
        this._definitions[dest] := definition

        return this
    }

    /**
     * Adds a boolean flag argument to the parser
     * @param {String} dest The property name in the result object
     * @param {Object} config Configuration object
     *   - short: Short flag name (single char)
     *   - long: Long flag name
     *   - action: "store_true" (default)
     *   - help: Help text
     * @returns {ArgumentParser} this (for chaining)
     */
    AddFlag(dest, config) {
        TypeError.ThrowIfNot(dest, String, -2)
        TypeError.ThrowIfNot(config, Object, -2)

        ; Validate that at least short or long is provided
        ValueError.ThrowIf(!config.HasOwnProp("short") && !config.HasOwnProp("long"),
            "Must provide 'short' or 'long' flag name", -2)

        ; Check for duplicate destination
        ValueError.ThrowIf(this._definitions.Has(dest),
            "Duplicate argument destination: '" dest "'", -2)

        (config.HasOwnProp("action") || config.action := "store_true")
        (config.HasOwnProp("required") || config.required := false)
        (config.HasOwnProp("default") || config.default := false)

        ; Create and store definition
        definition := ArgumentDefinition(dest, "flag", config)
        this._definitions[dest] := definition

        return this
    }

    /**
     * Adds a positional argument to the parser
     * @param {String} dest The property name in the result object
     * @param {Object} config Optional configuration object
     *   - type: "String", "Integer", or "Float" (default: "String")
     *   - choices: Array of valid values
     *   - validator: Custom validation function
     *   - required: Whether argument is required (default: true)
     *   - help: Help text
     * @returns {ArgumentParser} this (for chaining)
     */
    AddPositional(dest, config?) {
        TypeError.ThrowIfNot(dest, String, -2)

        config := config ?? {}
        TypeError.ThrowIfNot(config, Object, -2)

        ; Create and store definition
        definition := ArgumentDefinition(dest, "positional", config)
        this._positionals.Push(definition)

        return this
    }

    /**
     * Parses command-line arguments
     * @param {Array} args Array of strings to parse (default: A_Args)
     * @returns {Object} Parse result with named properties
     * @throws {ValueError} For parsing errors (unless exitOnError is true)
     * @throws {TypeError} For type conversion errors (unless exitOnError is true)
     */
    Parse(args := A_Args) {
        ; Wrap in try-catch to handle exitOnError
        try {
            return this._ParseInternal(args)
        }
        catch Error as err {
            if this._config.exitOnError {
                ; Display error and exit
                FileAppend("Error: " err.Message "`n", "*")
                ExitApp(1)
            }
            throw err
        }
    }

    /**
     * Internal parsing logic
     * @private
     */
    _ParseInternal(args := A_Args) {
        TypeError.ThrowIfNot(args, Array, -3)

        ; Check for help flag first
        for (arg in args) {
            if (arg == "--help" || arg == "-h") {
                ; Display help and exit (or return based on exitOnError)
                FileAppend(this.GetHelp(), "*")
                if (this._config.exitOnError)
                    ExitApp(0)
                return {}
            }
        }

        ; Initialize result object
        result := Map()

        ; __Get / __Set metafunctions allow .prop access
        result.DefineProp("__Get", { Call: (self, name, params) => self[name] })
        result.DefineProp("__Set", { Call: (self, name, params, value) => self[name] := value})
        
        positionalArgs := []

        ; Parse command-line arguments
        i := 1
        while (i <= args.Length) {
            arg := args[i]

            definition := ""

            ; Handle long options/flags: --name or --name=value or --name value
            if (SubStr(arg, 1, 2) == "--") {
                optionName := ""
                value := ""

                ; Extract name and value
                if (InStr(arg, "=")) {
                    ; --name=value format
                    parts := StrSplit(arg, "=", , 2)
                    optionName := SubStr(parts[1], 3)  ; Remove --
                    value := parts[2]
                    i++
                }
                else {
                    ; --name or --name value format
                    optionName := SubStr(arg, 3)  ; Remove --

                    ; Find definition to check if it's a flag
                    definition := this._FindDefinitionByLongName(optionName)

                    if (definition != "") {
                        if (definition.argType == "flag") {
                            ; Flag doesn't need a value
                            value := true
                            i++
                        }
                        else {
                            ; Option needs a value
                            if (i < args.Length) {
                                i++
                                value := args[i]
                                i++
                            }
                            else {
                                throw ValueError("Option '--" optionName "' requires a value", -2)
                            }
                        }
                    }
                    else {
                        ; Unknown option, will handle below
                        i++
                    }
                }

                ; Find definition if not found already
                definition := definition || this._FindDefinitionByLongName(optionName)

                if (definition == "") {
                    ValueError.ThrowIf(this._config.strict, "Unknown option: --" optionName, -4)
                    continue
                }

                ; Validate and store
                this._StoreValue(result, definition, definition.Validate(value))

            ; Handle short options/flags: -n or -n=value or -n value
            }
            else if ((arg[1] == "-" && StrLen(arg) >= 2 && arg[2] != "-")) {
                optionName := ""
                value := ""

                ; Extract name and value
                if InStr(arg, "=") {
                    ; -n=value format
                    parts := StrSplit(arg, "=", , 2)
                    optionName := SubStr(parts[1], 2)  ; Remove -
                    value := parts[2]
                    i++
                }
                else {
                    ; -n or -n value format
                    optionName := arg[2]  ; Get single char after -

                    ; Find definition to check if it's a flag
                    definition := this._FindDefinitionByShortName(optionName)

                    if (definition != "") {
                        if (definition.argType == "flag") {
                            ; Flag doesn't need a value
                            value := true
                            i++
                        }
                        else {
                            ; Option needs a value
                            if (i < args.Length) {
                                i++
                                value := args[i]
                                i++
                            }
                            else {
                                throw ValueError("Option '-" optionName "' requires a value", -2)
                            }
                        }
                    }
                    else {
                        ; Unknown option, will handle below
                        i++
                    }
                }

                ; Find definition if not found already
                definition := definition || this._FindDefinitionByShortName(optionName)

                if (definition == "") {
                    ValueError.ThrowIf(this._config.strict, "Unknown option: -" optionName, -4)
                    continue
                }

                ; Validate and store
                this._StoreValue(result, definition, definition.Validate(value))

            ; Handle positional arguments
            } else {
                positionalArgs.Push(arg)
                i++
            }
        }

        ; Parse positional arguments
        this._ParsePositionals(positionalArgs, result)

        ; Apply fallbacks in order of precedence (CLI > env > config > defaults)
        this._ApplyEnvironmentVariables(result)
        this._ApplyConfigValues(result)
        this._ApplyDefaults(result)

        ; Validate required arguments
        this._ValidateRequired(result)

        return result
    }

    /**
     * Loads default values from an INI config file
     * @param {String} iniPath Path to the INI file
     * @returns {ArgumentParser} this (for chaining)
     * @throws {ValueError} If file not found
     */
    LoadConfig(iniPath) {
        TypeError.ThrowIfNot(iniPath, String, -2)
        ValueError.ThrowIf(!FileExist(iniPath), "Config file not found: " iniPath, -2)

        ; Read all keys from [ArgumentParser] section
        section := IniRead(iniPath, "ArgumentParser")
        loop parse section, "`n" {
            line := Trim(A_LoopField)

            ; Skip empty lines and comments
            if (line == "" || SubStr(line, 1, 1) == ";" || SubStr(line, 1, 1) == "#")
                continue

            ; Parse key=value pairs
            parts := StrSplit(line, "=", , 2)
            this._configValues[Trim(parts[1])] := Trim(parts[2])
        }

        return this
    }

    /**
     * Generates help text showing usage and all arguments
     * @returns {String} The formatted help text
     */
    GetHelp() {
        help := ""

        ; Add description if provided
        (this._config.description && help .= this._config.description "`n`n")

        ; Build usage line
        help .= "Usage: " A_ScriptName " [OPTIONS]"

        ; Add positionals to usage
        for (definition in this._positionals) {
            help .= (definition.required ? " <" definition.name ">" : " [" definition.name "]")
        }

        help .= "`n"

        ; Add positional arguments section if any exist
        if (this._positionals.Length > 0) {
            help .= "`nPositional Arguments:`n"

            for (definition in this._positionals) {
                line := ("  " definition.name).RPad(20)

                line .= Format("{1}{2}{3}",
                    IsSpace(definition.helpText) ? "" : definition.helpText,
                    definition.type == "String" ? "" : " (type: " definition.type ")",
                    definition.choices.Length == 0 ? "" : " (choices: " QuotedList(definition.choices) ")"
                )

                help .= line "`n"
            }
        }

        ; Add options section
        help .= "`nOptions:`n"

        ; Add help option
        help .= "  -h, --help        Show this help message and exit`n"

        ; Add all defined options/flags
        for (dest, definition in this._definitions) {
            line := "  "

            names := []
            (definition.shortName && names.Push("-" definition.shortName))
            (definition.longName && names.Push("--" definition.longName))
            line .= ", ".Join(names*)

            ; Add value placeholder for options (not flags)
            (definition.argType == "option" && line .= " <value>")

            line := Format("{1}{2}{3}{4}{5}",
                line.length >= 20 ? (line "`n" " ".Repeat(20)) : line.RPad(20),
                definition.helpText,
                definition.defaultValue = "" ? "" : " (default: " definition.defaultValue ")",
                definition.type = "String" ? "" : " (type: " definition.type ")",
                definition.choices.Length == 0 ? "" : " (choices: " QuotedList(definition.choices) ")",
                definition.action != "append" ? "" : " (repeatable)"
            )

            help .= line "`n"
        }

        return help

        QuotedList(strs) {
            out := [], out.Length := strs.length
            for(str in strs)
                out[A_Index] := '"' str '"'
            return ", ".Join(out*)
        }
    }

    /**
     * Finds an argument definition by long name
     * @private
     * @param {String} longName The long option name to find
     * @returns {ArgumentDefinition} The definition, or an empty string if not found
     */
    _FindDefinitionByLongName(longName) {
        for (dest, definition in this._definitions) {
            if definition.longName == longName
                return definition
        }
        return ""
    }

    /**
     * Finds an argument definition by short name
     * @private
     * @param {String} shortName The short option name to find (single char)
     * @returns {ArgumentDefinition} The definition, or an empty stringf not found
     */
    _FindDefinitionByShortName(shortName) {
        for (dest, definition in this._definitions) {
            if definition.shortName == shortName
                return definition
        }
        return ""
    }

    /**
     * Parses positional arguments
     * @private
     * @param {Array} positionalArgs Array of positional argument values
     * @param {Object} result Result object to populate
     */
    _ParsePositionals(positionalArgs, result) {
        ; Match positional args to definitions by order
        for (index, definition in this._positionals) {
            if (index <= positionalArgs.Length) {
                ; Validate and store
                validatedValue := definition.Validate(positionalArgs[index])
                result[definition.name] := validatedValue
            }
            ; Missing required positionals will be handled in Phase 7
        }
    }

    /**
     * Stores a value in the result object according to the action type
     * @private
     * @param {Object} result Result object to populate
     * @param {ArgumentDefinition} definition The argument definition
     * @param {Any} value The validated value to store
     */
    _StoreValue(result, definition, value) {
        ; Handle different action types
        switch definition.action {
            case "append":
                ; Append to array - create if doesn't exist
                if !result.Has(definition.name)
                    result[definition.name] := []
                result[definition.name].Push(value)
            case "store_true":
                result[definition.name] := value
            default:
                result[definition.name] := value
        }
    }

    /**
     * Applies environment variable fallbacks for options not set via CLI
     * @private
     * @param {Object} result Result object to populate
     */
    _ApplyEnvironmentVariables(result) {
        for (dest, definition in this._definitions) {
            ; Skip if already set from CLI or no envVar defined
            if result.Has(dest) || definition.envVar == ""
                continue

            ; Try to get value from environment
            envValue := EnvGet(definition.envVar)
            if (envValue != "") {
                ; Validate and store
                validatedValue := definition.Validate(envValue)
                result[dest] := validatedValue
            }
        }
    }

    /**
     * Applies config file values for options not set via CLI or env vars
     * @private
     * @param {Object} result Result object to populate
     */
    _ApplyConfigValues(result) {
        for (dest, definition in this._definitions) {
            ; Skip if already set
            if result.Has(dest)
                continue

            ; Try to get value from config file
            if (this._configValues.Has(dest)) {
                configValue := this._configValues[dest]
                ; Validate and store
                validatedValue := definition.Validate(configValue)
                result[dest] := validatedValue
            }
        }
    }

    /**
     * Applies default values for options not set via any other means
     * @private
     * @param {Object} result Result object to populate
     */
    _ApplyDefaults(result) {
        for (dest, definition in this._definitions) {
            ; Skip if already set
            if (result.Has(dest))
                continue

            ; For append actions with no values, always create empty array
            if (definition.action == "append") {
                result[dest] := []
            }
            else if (definition.defaultValue != "") {
                ; Use default value (already validated during AddOption/AddFlag)
                result[dest] := definition.defaultValue
            }
        }

        ; Also handle positionals with defaults
        for (definition in this._positionals) {
            if (!result.Has(definition.name) && (definition.defaultValue != ""))
                result[definition.name] := definition.defaultValue
        }
    }

    /**
     * Validates that all required arguments are present
     * @private
     * @param {Object} result Result object to validate
     * @throws {ValueError} If required argument is missing
     */
    _ValidateRequired(result) {
        ; Check required options/flags
        for (dest, definition in this._definitions) {
            ValueError.ThrowIf(definition.required && !result.Has(dest),
                "Required " definition._GetOptionString() " not provided", -5)
        }

        ; Check required positionals
        for (definition in this._positionals) {
            ValueError.ThrowIf(definition.required && !result.Has(definition.name),
                "Required argument '" definition.name "' not provided", -5)
        }
    }
}