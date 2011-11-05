package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use Astro::App::Satpass2::Test::App;

require_ok 'Astro::App::Satpass2::FormatTime';

can_ok 'Astro::App::Satpass2::FormatTime' => 'new';

can_ok 'Astro::App::Satpass2::FormatTime' => 'attribute_names';

can_ok 'Astro::App::Satpass2::FormatTime' => 'copy';

can_ok 'Astro::App::Satpass2::FormatTime' => 'gmt';

can_ok 'Astro::App::Satpass2::FormatTime' => 'format_datetime_width';

can_ok 'Astro::App::Satpass2::FormatTime' => 'tz';

class 'Astro::App::Satpass2::FormatTime';

method 'new', INSTANTIATE, 'Instantiate Astro::App::Satpass2::FormatTime';

method gmt => 1, TRUE, 'Turn on gmt';

method 'gmt', 1, 'Confirm gmt is on';

method format_datetime_width => '', 0, 'Width of null template';

method format_datetime_width => 'foo', 3,
    'Width of constant template';

method format_datetime_width => 'foo%%bar', 7,
    'Width of template with literal percent';

done_testing;

1;

# ex: set textwidth=72 :
