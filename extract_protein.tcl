#################### Inputs ####################
# 0 --> psf file of the system to remove hydrogens and extract only the protein
# 1 --> pdb location to be saved

mol new [lindex $argv 0] type pdb
[atomselect top "protein and noh"] writepdb [lindex $argv 1]
quit
