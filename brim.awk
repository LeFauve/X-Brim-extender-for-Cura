BEGIN {
	# Configuration
  extrabrimskirts = 12; # number of skirts to add to the brim MUST be even (i.e. if your original gcode has a brim of 1, using 14 will give you a brim of 15) 
  brimskip = 0.52; # distance between two brim's skirts
  minDY = 10; # minimal Y distance for which we will enhance the brim's width
  brimgap = 5; # hole in the middle of each enhanced brim (should be at least 2*brimskip)

  # init stuff
	ng=0; # nb of G commands in the brim
	ns=0; # nb of skirts
}

/^G0/ {
	last_G0 = $0;
}

/;TYPE:SKIRT/ {
	mode=1;
	parse_G(last_G0);
	print;
	next;
}

mode && /;TYPE:WALL-INNER/ {
	mode=0;
	# analyse skirts
	minminX = 999999; # you shouldn't use this if your printbed is that big :o)
	outerskirt = -1;
	de2 = 0;
	d2 = 0;
	e=0;
	for(i=0;i<ng;++i) {
	    if(allG[i,"G"]=="0") { // New skirt
            if(i>0) { // Store the last processed skirt
              allS[ns,"minX"] = minX;
              allS[ns,"maxX"] = maxX;
              allS[ns,"start"] = start;
              if(minX<minminX) {
              	minminX = minX
              	outerskirt = ns;
              }
              ++ns;
            }
            start = i;
	    	minX = maxX = x = allG[i,"X"]*1;
	    	y=allG[i,"Y"]*1;
	    }
	    else {
	    	lx = x;
	    	ly = y;
	    	le = e;
			if(allG[i,"X"]~/^[0-9]+([.][0-9]+)?$/) x = allG[i,"X"]*1;
			if(allG[i,"Y"]~/^[0-9]+([.][0-9]+)?$/) y = allG[i,"Y"]*1;
			e = allG[i,"E"]*1;

			if(x<minX) minX = x;
			if(x>maxX) maxX = x;

			dx = abs(x-lx);
			dy = abs(y-ly);
			de = e-le;
			dxy = sqrt(dx*dx+dy*dy);

			if(de>0) { // Skip retractation
				d2 += dxy;
				de2 += de;
			}
		}
	}

	es = de2/d2;

    l("Extraction speed for brim: " es);
    l("Outer skirt is number " outerskirt+1 " of " ns);

    start = allS[outerskirt,"start"];
    minX = allS[outerskirt,"minX"];
    maxX = allS[outerskirt,"maxX"];
    e = 0;
    for(i=1;i<start;++i) print allG[i,"raw"];
    if(start!=0) { # Special case because the first skirt's G0 is always issued before we enter the skirt section
    	print allG[start,"raw"];
    	e = allG[start-1,"E"];
    }
    print ";START modified skirt (e=" e ")";
    x = allG[start,"X"];
    y = allG[start,"Y"];

    for(i=start+1; allG[i,"G"]==1;++i) {
        if(allG[i,"retractation"]!=0 ) { # This is a retractation command
        	print "G92 E" allG[i,"retractation"];
        	print allG[i,"raw"];
        	retracted = 1;
        }
        else { 
	    	lx = x;
	    	ly = y;
	    	if(allG[i,"X"]~/^[0-9]+([.][0-9]+)?$/) x = allG[i,"X"]*1;
			if(allG[i,"Y"]~/^[0-9]+([.][0-9]+)?$/) y = allG[i,"Y"]*1;
	        f = (allG[i,"F"]~/^[0-9]+([.][0-9]+)?$/)?" F" allG[i,"F"]:"";

			dx = abs(x-lx);
			dy = abs(y-ly);
			dxy = sqrt(dx*dx+dy*dy);

			if(x==lx && x==minX && dy>minDY) { # left vertical edge
				e = edge(-1, x, ly, y, e, f);
			}
			else if(x==lx && x==maxX && dy>minDY) { # right vertical edge
				e = edge(1, x, ly, y, e, f);
			}
			else { # other edges
				e += dxy*es;
				print "G1" f " X" x " Y" y " E" e; 
			}
		}
    }
    if(!retracted) print "G92 E" allG[i-1,"E"];
    print ";END modified skirt";
    // Finish other skirts
    for(;i<ng;++i) print allG[i,"raw"];
}

mode { 
	parse_G($0);
    #print ; 
    next;
}

# default rule;
{
	print;
}

func parse_G(g) {
	split(g,args," ");
	allG[ng,"raw"] = g;
	for(i=1;i<=length(args);++i) {
		allG[ng,substr(args[i],1,1)] = substr(args[i],2);
	}
	if(g~/ E[0-9]+([.][0-9]+)?/) {
	    if(lastE>allG[ng,"E"]) allG[ng,"retractation"] = lastE;
	    lastE = allG[ng,"E"];
	}
	++ng;
}

func abs(x) {
	return x<0?-x:x;
}

func l(x) {
	print x  > "/dev/stderr";
}

func edge(d,x,y1,y2,e,f) {
	print ";START" ((d==-1)?"LEFT":"RIGHT") " EDGE (" (extrabrimskirts+1) " skirts)";
	ym1 = y1 + (y2-y1)/2 - ((y1<y2)?0.5:-0.5)*brimgap;
	ym2 = y1 + (y2-y1)/2 + ((y1<y2)?0.5:-0.5)*brimgap;
	dev = abs(ym1-y1)*es;
	deh = brimskip*es;

	for(j=0;j<extrabrimskirts;j+=2) {
      e += dev;
	  	print "G1" f " X" x+j*d*brimskip " Y" ym1 " E" e;
	  	f = "";
	  	e += deh;
	  	print "G1 X" x+(j+1)*d*brimskip " Y" ym1 " E" e;
		  e += dev;
	  	print "G1 X" x+(j+1)*d*brimskip " Y" y1 " E" e;
	  	e += deh;
	  	print "G1 X" x+(j+2)*d*brimskip " Y" y1 " E" e;
	}

	e += dev + es*brimgap; # Extra move

	for(j=extrabrimskirts;j>0;j-=2) {
	    e += dev;
	  	print "G1 X" x+j*d*brimskip " Y" y2 " E" e;
	  	e += deh;
	  	print "G1 X" x+(j-1)*d*brimskip " Y" y2 " E" e;
	  	e += dev;
	  	print "G1 X" x+(j-1)*d*brimskip " Y" ym2 " E" e;
	  	e += deh;
	  	print "G1 X" x+(j-2)*d*brimskip " Y" ym2 " E" e;
	}

  e += dev;
	print "G1 X" x " Y" y2 " E" e;
	print ";END" ((d==-1)?"LEFT":"RIGHT") " EDGE (e=" e ")";
	return e;
}
