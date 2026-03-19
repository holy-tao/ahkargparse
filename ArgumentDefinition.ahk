#Requires AutoHotkey v2.0

#Include <Extensions\Errors\ErrorExtensions>

/**
 * Helper class to store argument definition configuration
 * @private
 */
class ArgumentDefinition {
    helpText := ""          ; help description

    __New(name, argType, config := {}) {
        this.name := name
        this.argType := argType

        ; Set properties from config
        this.shortName := config.HasOwnProp("short") ? config.short : ""
        this.longName := config.HasOwnProp("long") ? config.long : ""
        this.type := config.HasOwnProp("type") ? config.type : "String"
        this.choices := config.HasOwnProp("choices") ? config.choices : []
        this.validator := config.HasOwnProp("validator") ? config.validator : ""
        this.envVar := config.HasOwnProp("envVar") ? config.envVar : ""
        this.defaultValue := config.HasOwnProp("default") ? config.default : ""
        this.required := config.HasOwnProp("required") ? config.required : true
        this.action := config.HasOwnProp("action") ? config.action : "store"
        this.helpText := config.HasOwnProp("help") ? config.help : ""
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
        convertedValue := this.validator ? this._ValidateCustom(convertedValue) : convertedValue

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
        switch this.type {
            ; String type - return as-is
            case "String":
                return value
            case "Integer":
                TypeError.ThrowIf(!IsInteger(value) , this._GetOptionString() " expects type Integer, but got '" value "'", -5)
                 return Integer(value)
            case "Float":
                TypeError.ThrowIf(!IsFloat(value), this._GetOptionString() " expects type Float, but got '" value "'", -5)
                return Float(value)
            default:
                throw Error("Unknown argument definition type", , this.type)
        }
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
            throw ValueError(this._GetOptionString() " must be one of [" choiceList "], but got '" value "'", -4, value)
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
            err := ValueError(this._GetOptionString() " failed validation: " cause.Message, -4, value)
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