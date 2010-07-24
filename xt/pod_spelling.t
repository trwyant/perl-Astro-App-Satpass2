package main;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::Spelling;
	Test::Spelling->import();
	1;
    } or do {
	print "1..0 # skip Test::Spelling not available.\n";
	exit;
    };
}

add_stopwords (<DATA>);

all_pod_files_spelling_ok ();

1;

__DATA__
apoapsis
appulse
appulses
argumentofperigee
ascendingnode
Astro
astro
au
autoheight
azel
backdate
bstardrag
ca
celestrak
CPAN
CPANPLUS
darwin
DateTime
DC
degreesdminutesmsecondss
del
dualvars
ECI
eci
EDT
edt
edu
elementnumber
ephemeristype
EST
firstderivative
fmtr
fr
gasparovic
geocode
geocoder
geocoding
geoid
GMT
gmt
goran
gory
harvard
INI
ini
init
initfile
instantiator
ish
jan
JSON
jul
julian
kluged
ly
meananomaly
meanmotion
mma
MSWin
NORAD
observability
OID
op
pc
periapsis
perigee
perltime
pm
programmatically
rc
realtime
reportable
revolutionsatepoch
rightascension
SATPASS
satpass
SATPASSINI
sdp
secondderivative
semimajor
semiminor
sgp
shdw
SIMBAD
simbad
spacetrack
STDERR
STDIN
STDOUT
stdout
strasbg
TIMEZONES
TLE
tle
tokenization
tokenized
tokenizing
trampoline
tz
uk
username
USGS
UT
webcmd
WGS
wyant
YAML
zoneinfo
zulu
