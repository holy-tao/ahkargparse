#Requires AutoHotkey v2.0

/**
 * Helper class to store argument definition configuration
 * @private
 */
class ArgumentDefinition {
    name := ""              ; destination property name
    shortName := ""         ; single char: "v"
    longName := ""          ; word: "verbose"
    type := "String"        ; String, Integer, Float
    choices := []           ; valid values (empty = any)
    validator := ""         ; custom validation function
    envVar := ""            ; environment variable name
    defaultValue := ""      ; default value
    required := true        ; required flag
    action := "store"       ; store, store_true, append
    helpText := ""          ; help description
    argType := ""           ; option, flag, positional

    __New(name, argType, config := {}) {
        this.name := name
        this.argType := argType

        ; Set properties from config
        if config.HasOwnProp("short")
            this.shortName := config.short
        if config.HasOwnProp("long")
            this.longName := config.long
        if config.HasOwnProp("type")
            this.type := config.type
        if config.HasOwnProp("choices")
            this.choices := config.choices
        if config.HasOwnProp("validator")
            this.validator := config.validator
        if config.HasOwnProp("envVar")
            this.envVar := config.envVar
        if config.HasOwnProp("default")
            this.defaultValue := config.default
        if config.HasOwnProp("required")
            this.required := config.required
        if config.HasOwnProp("action")
            this.action := config.action
        if config.HasOwnProp("help")
            this.helpText := config.help
    }
   
    /**
     * Validates and converts a value according to this argument's configuration
     * @param {Any} value The value to validate
     * @returns {Any} The validated and converted value
     * @throws {TypeError} If type conversion fails
     * @throws {ValueError} If validation fails
     */
    Validate(value) {
        ; Step 1: Type conversion
        convertedValue := this._ConvertType(value)

        ; Step 2: Choice validation
        if (this.choices.Length > 0)
            this._ValidateChoices(convertedValue)

        ; Step 3: Custom validation
        if HasMethod(this.validator)
            convertedValue := this._ValidateCustom(convertedValue)

        return convertedValue
    }

    /**
     * Converts value to the specified type
     * @private
     * @param {Any} value The value to convert
     * @returns {Any} The converted value
     * @throws {TypeError} If conversion fails
     */
    _ConvertType(value) {
        ; String type - return as-is
        if (this.type == "String")
            return value

        ; Integer type
        if (this.type == "Integer") {
            try {
                return Integer(value)
            }
            catch Error as cause{
                optionStr := this._GetOptionString()
                err := TypeError(optionStr " expects type Integer, but got '" value "'", -4, value)
                err.Inner := cause
                throw err
            }
        }

        ; Float type
        if this.type == "Float" {
            try {
                return Float(value)
            }
            catch Error as cause{
                optionStr := this._GetOptionString()
                err := TypeError(optionStr " expects type Float, but got '" value "'", -4, value)
                err.Inner := cause
                throw err
            }
        }

        ; Unknown type - should not happen
        return value
    }

    /**
     * Validates that value is one of the allowed choices
     * @private
     * @param {Any} value The value to validate
     * @throws {ValueError} If value is not in choices
     */
    _ValidateChoices(value) {
        ; Check if value is in choices array
        found := false
        for choice in this.choices {
            if choice == value {
                found := true
                break
            }
        }

        if !found {
            ; Build error message with available choices
            choiceStrs := []
            for choice in this.choices
                choiceStrs.Push('"' choice '"')

            choiceList := ", ".Join(choiceStrs*)
            optionStr := this._GetOptionString()
            throw ValueError(optionStr " must be one of [" choiceList "], but got '" value "'", -4, value)
        }
    }

    /**
     * Calls custom validator function
     * @private
     * @param {Any} value The value to validate
     * @returns {Any} The value returned by validator (may be modified)
     * @throws {ValueError} If validator throws or returns error
     */
    _ValidateCustom(value) {
        try {
            return this.validator.Call(value)
        }
        catch Error as cause {
            ; Re-throw with better context if validator didn't provide good error
            optionStr := this._GetOptionString()
            err := ValueError(optionStr " failed validation: " cause.Message, -4, value)
            err.Inner := cause
            throw err
        }
    }

    /**
     * Gets a string representation of this argument for error messages
     * @private
     * @returns {String} The argument string (e.g., "Option '--output'", "Argument 'input_file'")
     */
    _GetOptionString() {
        if this.argType == "positional"
            return "Argument '" this.name "'"

        ; For options/flags, prefer long name
        if this.longName != ""
            return (this.argType == "flag" ? "Flag" : "Option") " '--" this.longName "'"

        if this.shortName != ""
            return (this.argType == "flag" ? "Flag" : "Option") " '-" this.shortName "'"

        return "Argument '" this.name "'"
    }
}