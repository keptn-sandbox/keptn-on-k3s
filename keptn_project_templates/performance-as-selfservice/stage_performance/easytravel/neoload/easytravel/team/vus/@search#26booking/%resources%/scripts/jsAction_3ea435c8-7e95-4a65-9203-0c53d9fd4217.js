// Javascript skeleton.
// Edit and adapt to your needs.
// The documentation of the NeoLoad Javascript API
// is available in the appendix of the documentation.

// Get variable value from VariableManager
var myVar = context.variableManager.getValue("Fil_cities.City");
if (myVar==null) {
        context.fail("Variable 'myVar' not found");
}

// Do some computation using the methods
// you defined in the JS Library
CreateKeyWordTable(myVar,"JS_DEST");
