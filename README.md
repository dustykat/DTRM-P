# DTRM-Python
DTRM-Python

This is a python implementation of the original Digital Terrain Runoff Model circa 2006.  
The original program was a FORTRAN-77 code; herein directly translated with some meaningful corections to run in a Jupyter Notebook (or could be run as a monolithic Python program.  

The python script is modified to be compatable with GIS generated watershed descriptions to simplyify workflow (historically the code used DSAA files, clipped and converted into useable ASCII elevation files using SURFER)

The tools were developed on a Raspberry Pi computer where they work, but are terribly slow.  For any production work a faster architecture should be employed (even old Xeon CPUs are faster).

This is largely a research code, but probably adaptable to practical uses.
