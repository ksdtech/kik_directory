kik_directory
=============

Parse a formatted Microsoft Word xml file and prepare for mail merge for 
the annual printed phone book published by our school foundation.

Steps:

1. Open .doc of family data from previous year's directory in MS Word.
2. Save As Word Xml document, like "dir_2012.xml"
3. Execute "ruby dir_parser.rb -f xml dir_2012.xml merge_2012.txt". If 
the input file has not been pre-processed to advance students to the
next grade level add "-b" option to the command.
4. Use the output file, "merge_2012.txt" as a data source for the 
output.docx Word template.

Notes:

* If there are exceptions during processing, correct the original Word 
document, re-save as "dir_2012.xml", and re-run until xml file is parsed 
without exceptions.
* If there are non-fatal errors printed on STDERR after processing, search
the original Word document, correct, re-save and re-run, or just correct
them in the mail merge document.



$ ./dir_parser.rb -b -f xml -o tab dir_2013.xml kik_data.txt

Add kik_student_numbers for any unmatched rows

$ ./merge_for_import.rb