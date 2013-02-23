#!/usr/bin/perl
use strict;
use warnings;
use MP3::Info;

my $file = shift || die $!;
my $tag = get_mp3tag($file) or die "No tag information";

use Data::Dumper;
print Dumper \$tag;
