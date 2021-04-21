// Javascript skeleton.
// Edit and adapt to your needs.
// The documentation of the NeoLoad Javascript API
// is available in the appendix of the documentation.

// Get variable value from VariableManager
var date = context.variableManager.getValue("DateStart");
if (date==null) {
        context.fail("Variable 'date' not found");
}
var someDate = new Date(date);
var startDate=new Date(date);
var numberOfDaysToAdd = 10;
someDate.setDate(someDate.getDate() + numberOfDaysToAdd); 

//someDate.formatD

//startDate.format( "mmm dd, yyyy");
// Inject the computed value in a runtime variable
context.variableManager.setValue("EndDate",dateFormat(someDate,"mmm dd, yyyy"));
context.variableManager.setValue("DateStart",dateFormat(startDate, "mmm dd, yyyy"));