kik_directory
=============

Parse a formatted Microsoft Word xml file and prepare for mail merge for 
the annual printed phone book published by our school foundation.

Steps:

1. Open .doc of family data from previous year's directory in MS Word.
2. Save As Word Xml document, like "dir_2012.xml"
3. Execute "ruby dir_parser.rb dir_2012.xml merge_2012.txt".
4. Use the output file, "merge_2012.txt" as a data source for the 

4. If there are exceptions during processing, correct the original Word 
document, re-save as "dir_2012.xml", and re-run until xml file is parsed 
withou exceptions.
5. If there are non-fatal errors printed on STDERR after processing, search
the original Word document, correct, re-save and re-run, or just correct
them in the mail merge document.

