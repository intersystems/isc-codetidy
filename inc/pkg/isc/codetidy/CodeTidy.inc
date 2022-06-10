^INC^Save for Source Control^^~Format=IRIS.S~^UTF8
%RO
pkg.isc.codetidy.CodeTidy^INC^^^0
#define COSWhiteSpace 1
#define COSLabel 3
#define COSDots 4
#define COSObjectClass 5
#define COSString 6
#define COSComment 7
#define COSObjectdotoperator 8
#define COSSQL 9
#define COSFormatspecifier 10
#define COSFunction 11
#define COSGlobalvariable 12
#define COSIndirection 13
#define COSLocalvariable 14
#define COSMnemonic 15
#define COSName 16
#define COSNumber 17
#define COSOperator 18
#define COSRoutine 19
#define COSCommand 20
#define COSObjectinstancevar 21
#define COSObjectreferencevar 22
#define COSObjectmethod 23
#define COSObjectattribute 24
#define COSObjectThis 25
#define COSVBFormname 26
#define COSVBPropertyname 28
#define COSPattern 29
#define COSDocumentationcomment 33
#define COSObjectmember 37
#define COSStructuredvariable "1B"
#define COSSystemvariable "1C"
#define COSHTML "1D"
#define COSObjectproperty "1E"
#define COSObjectname "1F"
#define COSBrace "2A"
#define COSJavascript "2B"
#define COSObjectSuper "2D"
#define COSPreProcessorFunction "A"
#define COSPreProcessorCommand "B"
#define COSMacro "C"
#define COSDelimiter "D"
#define COSExtrinsicfunction "F"
.
#define CSSWhiteSpace 1
#define CSSIdentifier 3
#define CSSString 6
#define CSSName 7
#define CSSNumber 8
#define CSSHexcolor 9
#define CSSCSSDelimiter 10
#define CSSOtherDelimiter 11
#define CSSFunction 12
#define CSSOperator 13
#define CSSPercentage "A"
#define CSSMeasure "C"
#define CSSURI "D"
#define CSSCstyleComment "F"
.
#define HTMLWhiteSpace 1
#define HTMLComment 4
#define HTMLDelimiter 5
#define HTMLEscapeSequence 6
#define HTMLName 7
#define HTMLNumber 8
#define HTMLString "A"
#define HTMLTag "B"
#define HTMLText "C"
.
#define JAVASCRIPTWhiteSpace 1
#define JAVASCRIPTDelimiter 4
#define JAVASCRIPTString 5
#define JAVASCRIPTComment 6
#define JAVASCRIPTDecimalinteger 7
#define JAVASCRIPTFloatingpointnumber 9
#define JAVASCRIPTDefinitionkeyword 10
#define JAVASCRIPTStatementkeyword 11
#define JAVASCRIPTExpressionkeyword 13
#define JAVASCRIPTCSPextension 15
#define JAVASCRIPTRegexpdelimiter "A"
#define JAVASCRIPTRegexpbody "B"
#define JAVASCRIPTRegexpescapesequence "C"
#define JAVASCRIPTRegexpflags "D"
#define JAVASCRIPTIdentifier "E"
#define JAVASCRIPTOperator "F"
.
#define SQLWhiteSpace 1
#define SQLDelimiter 3
#define SQLString 4
#define SQLComment 5
#define SQLIntegernumber 6
#define SQLFloatingpointnumber 7
#define SQLIdentifier 8
#define SQLHostvariablename 9
#define SQLStatementkeyword 11
#define SQLQualifierkeyword 12
#define SQLExpressionkeyword 13
#define SQLHostextrinsicfunction "B"
#define SQLOperator "C"
#define SQLScalarfunctionname "D"
#define SQLODBCfunctionname "E"
#define SQLAggregatefunctionname "F"
.
#define sqlStorageClass "%Storage.SQL"
#define persistentStorageClass "%Storage.Persistent"
#define rawStringClass "%Library.RawString"
#define dictClassnameClass "%Dictionary.CacheClassname"
#define libDatabase "IRISLIB"
#define sysDatabase "IRISSYS"
#define exportAttribGenerator "IRIS"
#define exportAttribVersion "26"
#define langObjectScript "objectscript"
.
#define storageName(%s) $$$comClassKeyGet(%s,$$$cCLASSstoragestrategy)
///
#define isGUIDENABLED(%s) $$$comMemberKeyGet(%s,$$$cCLASSparameter,"GUIDENABLED",$$$cPARAMdefault)
///
#define isSQLSTORAGE(%s) (($$$storageName(%s)'="")&&($$$comMemberKeyGet(%s,$$$cCLASSstorage,$$$storageName(%s),$$$cSDEFtype)=$$$sqlStorageClass))
///
#define inheritABSTRACT $$$comClassKeyGet(%classname,$$$cCLASSabstract)&&('$$$isGUIDENABLED(%classname))
.
#; Returns if an object is a native IRIS JSON object or array
#define IsJSONObject(%object) ($isobject(%object) && (%object.%IsA("%DynamicAbstractObject")))