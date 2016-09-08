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
ASCIIbetical
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
CUSTOMIZATIONS
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
findable
firstderivative
formatter
formatter's
formatters
Formatters
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
Geocoding
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
Instantiator
invocant
invocant's
ish
jan
JSON
jul
julian
kluged
localization
localizations
lookup
Lookup
lookups
ly
meananomaly
meanmotion
merchantability
mixin
mma
Molczan
MSWin
noappulse
noquarter
NORAD
observability
oid
OID
OIDs
op
org
parsers
pc
periapsis
perigee
perltime
pm
POSIX
pre
precessed
preprocessed
preprocessing
programmatically
pwd
Quicksat
quoter
radian
radians
rc
realtime
reblessed
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
Subclasses
TIMEZONES
TLE
tle
tokenization
Tokenization
tokenized
tokenizing
TOKENIZING
TomTom
trampoline
tt
tz
uk
unanchored
unblessed
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
wooly
Wyant
YAML
zoneinfo
zulu
