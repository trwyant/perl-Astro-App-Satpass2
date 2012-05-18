package main;

# ex: set textwidth=72 :

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
appulsed
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
CLDR
CPAN
cpanminus
CPANPLUS
customizations
darwin
DateTime
DC
degreesdminutesmsecondss
del
designator
dualvars
ECI
eci
EDT
edt
edu
effector
effectors
elementnumber
ephemeris
ephemeristype
equivocated
EST
exportable
filename
firstderivative
formatter
formatter's
formatters
fr
FreeBSD
FreeDesktop
Gasparovic
gb
geocode
geocoded
geocoder
geocodes
geocoding
geoid
GMT
gmt
Goran
gory
harvard
hoc
INI
ini
init
initfile
instantiator
invocant
invocant's
ish
jan
JSON
jul
julian
kluged
lookup
lookups
ly
meananomaly
meanmotion
merchantability
mma
MSWin
noappulse
noquarter
NORAD
observability
oid
op
org
parsers
pc
periapsis
perigee
perltime
pm
POSIX
precessed
programmatically
pwd
quoter
radian
radians
rc
realtime
redirections
redistributions
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
Strasbourg's
subcommand
subcommands
subclasses
TIMEZONES
TLE
tle
tokenization
tokenized
tokenizing
TomTom
trampoline
tt
tz
uk
unexport
unexported
unlocalized
unordered
URI
username
USGS
UT
versa
VMS
warner
webcmd
WGS
whinge
wyant
YAML
zoneinfo
zulu
