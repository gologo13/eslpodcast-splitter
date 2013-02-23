#!/usr/bin/perl
use strict;
use warnings;
use MP3::Tag;

my $file = shift || die $!;
my $mp3 = MP3::Tag->new($file);

my ($title, $track, $artist, $album, $comment, $year, $genre) = $mp3->autoinfo();
use Data::Dumper;
print Dumper \$mp3->autoinfo();



#my $id3v2 = $mp3->{ID3v2} if exists $mp3->{ID3v2};
#print Dumper $id3v2;
