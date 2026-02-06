function strctOut = xtractParsFrmPDF(strctIn)

%% Process input par struct
pdfFileStr=strctIn.pdfFileStr;
pdfStrctIn=strctIn.pdfStrctIn;

%% Build and evalute command to extract  parameters
pdfCmd=strcat(pdfFileStr,"(pdfStrctIn);");
strctOut = eval(pdfCmd);

end