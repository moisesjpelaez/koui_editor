package arm.tools;

class ThemeUtils {
    /**
     * Converts leading spaces to tabs in the theme text.
     * Theme files must use tabs for indentation, not spaces.
     */
    public static function normalizeIndentation(text: String): String {
        var lines: Array<String> = text.split("\n");
        var normalized: Array<String> = [];

        for (line in lines) {
            // Count leading spaces and convert to tabs
            var leadingSpaces = 0;
            for (i in 0...line.length) {
                if (line.charAt(i) == ' ') {
                    leadingSpaces++;
                } else {
                    break;
                }
            }

            // Convert groups of 4 spaces to tabs
            var tabs = Math.floor(leadingSpaces / 4);
            var remainingSpaces = leadingSpaces % 4;
            var content = line.substring(leadingSpaces);

            var normalizedLine = "";
            for (i in 0...tabs) {
                normalizedLine += "\t";
            }
            for (i in 0...remainingSpaces) {
                normalizedLine += " ";
            }
            normalizedLine += content;

            normalized.push(normalizedLine);
        }

        return normalized.join("\n");
    }

    public static function validateThemeSyntax(text: String): Null<String> {
        // Regex patterns from ThemeParser
        var regIndent: EReg = ~/^(\t*)(.*)$/i;
        var regEmpty: EReg = ~/^[ \t]*(\/\/.*)?$/i;
        var lineReg: EReg = ~/^([\w\-]+)(![\w\-]+)?( *> *([\w\-]+))? *: *(.*)$/i;
        var ruleReg: EReg = ~/^(\?)?([\w\-]+) *: *(.*)$/i;
        var rulesReg: EReg = ~/^@rules( )*:( )*$/i;
        var globalsReg: EReg = ~/^(@globals)( )*:( )*$/i;

        // Normalize line endings to \n only (remove \r)
        text = StringTools.replace(text, "\r\n", "\n");
        text = StringTools.replace(text, "\r", "\n");

        var lines: Array<String> = text.split("\n");
        var lineNum: Int = 0;
        var foundRules: Bool = false;
        var visitingRules: Bool = false;
        var visitingGlobals: Bool = false;

        for (line in lines) {
            lineNum++;

            // Skip empty lines and comments
            if (line == "" || regEmpty.match(line)) {
                continue;
            }

            // Check indentation format
            if (!regIndent.match(line)) {
                return 'Line ${lineNum}: Could not match indentation';
            }

            // Get line content without indentation
            var lineContent: String = regIndent.matched(2);

            // Check for spaces in indentation (only tabs allowed)
            if (lineContent.length > 0 && lineContent != StringTools.ltrim(lineContent)) {
                return 'Line ${lineNum}: Tabs must be used for indentation, not spaces';
            }

            var indentLevel: Int = regIndent.matched(1).length;

            // Check for @rules block
            if (!foundRules) {
                if (rulesReg.match(lineContent)) {
                    foundRules = true;
                    visitingRules = true;
                    continue;
                }
            }

            // Exit @rules or @globals blocks when returning to indent level 0
            if (indentLevel == 0) {
                if (visitingRules) visitingRules = false;
                if (visitingGlobals) visitingGlobals = false;
            }

            // Validate line structure
            if (visitingRules) {
                if (!ruleReg.match(lineContent)) {
                    return 'Line ${lineNum}: Invalid rule syntax';
                }
            } else {
                if (globalsReg.match(lineContent)) {
                    visitingGlobals = true;
                } else if (!lineReg.match(lineContent)) {
                    return 'Line ${lineNum}: Invalid property/selector syntax';
                }
            }
        }

        return null; // No errors found
    }
}