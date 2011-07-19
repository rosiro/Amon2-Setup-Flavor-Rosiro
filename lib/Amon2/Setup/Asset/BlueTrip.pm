package Amon2::Setup::Asset::BlueTrip;
use strict;
use warnings;
use File::Spec::Functions;

my ($vol, $dir, $file) = File::Spec->splitpath($INC{"Amon2/Setup/Asset/BlueTrip.pm"});

sub bluetrip_path {
    return catdir($dir, "bluetrip");
}

1;
