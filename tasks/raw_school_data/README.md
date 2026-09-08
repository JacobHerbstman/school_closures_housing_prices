# Raw school data

This task owns the five source CSVs used by Noah Liu's school-data cleaner.
The files are committed because they are small, fixed inputs received from the
coauthor. Run `make` from `code/` to verify that the complete input set is
present.

The five input filenames and their links are listed in `code/Makefile`.

The data-review audit also requests four public source PDFs through explicit
Make rules: the original CPS February list (preserved by ABC), the University
of Chicago Consortium's 2015 *School Closings in Chicago*, and CPS notices for
Fermi/South Shore and Garfield Park/Faraday. URLs are literal in the Makefile.
Downloads first write temporary files and publish only completed transfers.
These acquired PDFs are ignored by Git; the five supplied CSVs remain tracked.
