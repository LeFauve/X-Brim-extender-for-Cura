# X-Brim-extender-for-Cura
AWK script that allow to increase the brim of a Cura generated gcode file on the X axis.

This is a quick hack that allow adding a "half-brim" when you print a rectangular base object with one of the dimensions too large for adding a brim (i.e. you have a 200x200mm printbed and want to print a 199x60mm piece).

Cura won't let you add a brim bigger than 1 or 2 but printing something that big without warping without using a significant brim is quite impossible. The script will increase the brim width on the X axis only, which will help reducing printing issues.

**Here is how to use the script:**

 * First, position your piece on Cura along the Y axis (with free space around the X axis) and generate your gcode with a brim of 1 (should work with other values but I didn't test).
 * Save your gcode file in "mygcode.gcode" (or any other name, but you will have to change the next steps accordingly
 * Open a command prompt and execute this command: gawk -f brim.awk mygcode.gcode > mynewgcode.gcode
 
At this point I recommend opening your new gcode file in a gcode viewer to check that everything looks normal (note that for some reasons, Cura itself (version 15.04.5) is not able to display correctly the first layer in some cases... I used the online viewer http://gcode.ws instead).

If it looks correct, you can print it.

A few notes:

* You will need to install an Awk interpretter. I recommend the GNU one (GAwk) since it's the one I tested but any should do
* **You need at least 1 brim since the script works by finding and editing the existing brim**
* You may edit the first few lines to tweak some variables (especially "extrabrimskirts" which is the number of brim lines to add)
* There will be a 5mm gap in the brim in the middle of your piece, but I don't think that will be an issue
* This has been tested on Cura 15.04.5 and rely on some of the comments Cura adds into the GCode, so it will probably not work on other slicers without some significant changes
 
