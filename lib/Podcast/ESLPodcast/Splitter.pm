package Podcast::ESLPodcast::Splitter;

use warnings;
use strict;
use Carp;

use LWP::UserAgent;
use File::Basename;
use XML::FeedPP;
use MP3::Splitter;
use Data::Dumper;
use Time::Piece;
use List::MoreUtils qw(any all);

use version; our $VERSION = qv('0.0.1');

use constant FEEDURI => 'http://feeds.feedburner.com/EnglishAsASecondLanguagePodcast?format=xml';

# constructor
sub new {
    my ($class, @args) = @_;
    my %args = ref $args[0] eq 'HASH' ? %{$args[0]} : @args;
    my $self = { %args };
    $self->{n} ||= 5;
    bless $self, $class;
}

# fetch a feed information for the ESLPodcast
sub fetch_feed {
    my $feed = XML::FeedPP->new(FEEDURI);
    printf STDERR "===============FEED INFO================\n";
    printf STDERR "Title: %s\n", $feed->title;
    printf STDERR "Date: %s\n", $feed->pubDate;
    printf STDERR "Copyright: %s\n", $feed->copyright;
    printf STDERR "Link: %s\n", $feed->link;
    printf STDERR "Language: %s\n", $feed->language;
    printf STDERR "========================================\n";
    return $feed;
}

sub run {
    my $self = shift;
    my $feed = fetch_feed();
    my $num_mp3s = 0;
    for my $item ($feed->get_item()) {
        if ($item->title =~ /English Cafe/) {
            printf STDERR "Skip: %s\n", $item->title;
            next;
        }
        last if ($num_mp3s > $self->{n});

        printf STDERR "\tURL: %s\n\tTitle: %s\n\tguid: %s\n\tDescription: %s\n", 
            $item->link, $item->title, $item->guid, ""; # $item->description;

        my $durations = extract_durations($item->description);
        next if (!$durations);

        my $uri = $item->guid();
        my $mp3_file = basename($uri);
        if (!download_mp3(\$uri, \$mp3_file)) {
            printf STDERR "download failure: %s\n", $mp3_file;
            next;
        }
        if (split_mp3(\$mp3_file, $durations)) {
            printf STDERR "split failure: %s\n", $mp3_file;
        }

        ++$num_mp3s;
    }
    printf STDERR "DONE!";
}

# extract durations for each dialog
sub extract_durations {
    my ($desc) = @_;

    # find started at
    my $started_at = {slow => undef, explanation => undef, fast => undef};
    for (split(/[\n|\r\n]/, $desc)) {
        chomp;
        if (/Slow (dialog|dialogue):\s*(\d+:\d+)/) {
            $started_at->{slow} = $2;
        }
        if (/Explanations:\s*(\d+:\d+)/) {
            $started_at->{explanation} = $1;
        }
        if (/Fast (dialog|dialogue):\s*(\d+:\d+)/) {
            $started_at->{fast} = $2;
        }
    }
    # print Dumper($started_at);
    if (!(all {defined($_)} values %$started_at)) {
        printf STDERR "something wrong in this feed\n";
        return 0;
    }

    # find durations
    my $durations = {slow=>undef, explanation=>undef, fast=>undef};
    $durations->{slow} = [
        $started_at->{slow},
        find_duration($started_at->{explanation},$started_at->{slow})
    ];
    $durations->{explanation} = [
        $started_at->{explanation},
        find_duration($started_at->{fast},$started_at->{explanation})
    ];
    $durations->{fast} = [
        $started_at->{fast},
        "=INF"
    ];
    return $durations;
}

# find a duration
sub find_duration {
    my ($from, $to) = @_;
    my $t1 = Time::Piece->strptime($from, "%M:%S");
    my $t2 = Time::Piece->strptime($to,   "%M:%S");
    my $diff = $t2 - $t1;
    return $diff->seconds;
}

# split a mp3 file into three files
sub split_mp3 {
    my ($mp3_file, $durations) = @_;
    mp3split($$mp3_file, {verbose => 1}, 
        $durations->{start}, $durations->{explanation},$durations->{fast});
    return 1;
}

# download a mp3 file
sub download_mp3 {
    my ($uri, $mp3_file) = @_;
    open(my $fh, '>', $$mp3_file) or die "$$mp3_file: $!";
    my $res = LWP::UserAgent->new->get(
        $$uri,
        ':content_cb' => sub {
            my ($chunk, $res, $proto) = @_;
            print $fh $chunk;
            my $size = tell $fh;
            if (my $total = $res->header('Content-Length')) {
                printf "%d/%d (%f%%)\r", $size, $total, $size/$total*100;
            } else {
                printf "%d/Unknown bytes\r", $size;
            }
        }
    );
    close $fh;
    print "\n", $res->status_line, "\n";
    unlink $$mp3_file if (!$res->is_success);
    return $res->is_success;
}

# Module implementation here


1; # Magic true value required at end of module
__END__

=head1 NAME

Podcast::ESLPodcast::Splitter - Split ESLPodcast into fast, slow and explanation dialogs.


=head1 VERSION

This document describes Podcast::ESLPodcast::Splitter version 0.0.1


=head1 SYNOPSIS

    use Podcast::ESLPodcast::Splitter;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Podcast::ESLPodcast::Splitter requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-podcast-eslpodcast-splitter@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Yohei Yamaguchi  C<< <joker13meister@gmail.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2013, Yohei Yamaguchi C<< <joker13meister@gmail.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
