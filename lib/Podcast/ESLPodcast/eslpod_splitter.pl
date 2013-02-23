#!/usr/bin/perl
use strict;
use warnings;
use feature qw/say/;
use LWP::UserAgent;
use File::Basename;
use XML::FeedPP;


my $source = 'http://feeds.feedburner.com/EnglishAsASecondLanguagePodcast?format=xml';
my $feed = XML::FeedPP->new($source);
# チャンネル要素操作系のメソッド
say "Title: ", $feed->title();
say "Date: ", $feed->pubDate();
say "Copyright:", $feed->copyright();
say "Link: ", $feed->link();
say "Language: ", $feed->language();
for my $item ($feed->get_item()) {
    # アイテム要素操作系のメソッド
    say "\tURL: ", $item->link();
    say "\tTitle: ", $item->title();
    say "\tguid: ", $item->guid();
    # say "\tDescription: ", $item->description; # 時間情報を含んでいる
    my $desc = $item->description;
    my $times = {'slow' => undef, 'explanation' => undef, 'fast' => undef};
    for (split(/[\n|\r\n]/, $desc)) {
        chomp;
        # say  $_;
        if (/Slow dialogue: (\d{1,2}:\d{1,2})(.*)$/) {
            $times->{slow} = $1;
        }
        if (/Explanations: (\d{1,2}:\d{1,2})(.*)$/) {
            $times->{explanation} = $1;
        }
        if (/Fast dialogue: (\d{1,2}:\d{1,2})(.*)$/) {
            $times->{fast} = $1;
        }
    }
#    use Data::Dumper;
#    print Dumper $times;

    my $uri = $item->guid();
    my $mp3_file = basename($uri);
    download_mp3(\$uri, \$mp3_file) or die "failed to download $mp3_file";
    split_mp3(\$mp3_file) or die "failed to split $mp3_file";
}

exit(0);

sub download_mp3
{
    my ($uri, $mp3_file) = @_;
    open(my $fh, '>', $$mp3_file) or die "$$mp3_file: $!";
    my $res = LWP::UserAgent->new->get(
        $$uri,
        ':content_cb' => sub {
            my ( $chunk, $res, $proto ) = @_;
            print $fh $chunk;
            my $size = tell $fh;
            if (my $total = $res->header('Content-Length')){
                printf "%d/%d (%f%%)\r", $size, $total, $size/$total*100;
            }else{
                printf "%d/Unknown bytes\r", $size;
            }
        }
    );
    close $fh;
    print "\n", $res->status_line, "\n";
    if ($res->is_success) {
        return 1;
    } else {
        unlink $$mp3_file;
        return 0;
    }
}

sub split_mp3
{
    die "どうsplitするか考え中";
}
