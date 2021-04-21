﻿function CreateKeyWordTable(StrKeyword,StrNeoLoadVariableName)
{
     var StrNeoLoadValue="";
     var j;
     for(i=2;i<=StrKeyword.length;i++)
    {
           j=i-1;
           StrNeoLoadValue=StrKeyword.substring(0,i);
           context.variableManager.setValue(StrNeoLoadVariableName+"_"+j,escape(StrNeoLoadValue));
    }
    context.variableManager.setValue(StrNeoLoadVariableName+"_matchNr",j);	 

}