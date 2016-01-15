#!/usr/bin/perl

use strict;
use warnings;
use LWP;
use HTML::TableExtract;
use JSON;
use Term::ANSIColor;
use Getopt::Long;
use Cwd;
use Data::Dumper;
use Time::HiRes qw( usleep clock );

########################
#####     TODO     #####
########################

# todo: more verbose output.
# todo: change output format ('SxxExx.mp4', 'xxx.mp4' '<name>-xxx.mp4').
# todo: add more export possibilities.

##########################
#####     CHECKS     #####
##########################

$|++;    # turn that f*cking buffer off!

# todo youtube-dl installed?

#############################
#####     VARIABLES     #####
#############################

my $LWP_useragent = "Proxerdl/dev_v0.01";
my @wishhost      = ( "proxer-stream", "clipfish-extern", "streamcloud" );
my @wishlang      = ( "gerdub", "gersub", "engsub", "engdub" );

my $opt_verbose;
my $opt_link;
my $opt_id;
my $opt_path;
my $opt_list;
my $opt_hoster;
my $opt_lang;
my $opt_out;
my $opt_nodir;

my @proxer_watch;
my $proxer_id;
my $proxer_json;
my $proxer_list;
my $proxer_lang;
my $proxer_page;

my $proxer_api;
my $proxer_watch_start;
my $proxer_watch_stop;
my $proxer_lang_avaivable;

my %meta;

my $file_path;

my $var;
my $json_var;
my $file_url;
my $hoster_url;
my $file_count = 0;
my @files;
my @episodes;

##########################
#####     Getopt     #####
##########################

GetOptions(
    'id=i'     => \$opt_id,
    'link=s'   => \$opt_link,
    'verbose'  => \$opt_verbose,
    'help'     => \&help,
    'proxer'   => \&proxer,
    'lang=s'   => \$opt_lang,
    'hoster=s' => \$opt_hoster,
    'list'     => \$opt_out,
    'no-dir'   => \$opt_nodir,
);

# parsing opts
if ( !$opt_id and !$opt_link ) {
    ERROR("Require link or id");
}

# get options
if ($opt_id) {
    $proxer_id = $opt_id;
}
else {
    if ( $opt_link !~ m/proxer\.me/ ) {
        ERROR("No valid proxer link: $opt_link");
        exit;
    }
    $opt_link =~ m/.*?proxer\.me\/.*?\/(\d+).*$/;
    $proxer_id = $1;
}

# get directory
if ( $ARGV[0] ) {
    if ( !-d $ARGV[0] ) {
        ERROR("Directory doesnt exist: $ARGV[0]");
        exit;
    }
    else {
        $file_path = $ARGV[0];
        VERBOSE("Path: $file_path");
    }
}
else {
    $file_path = getcwd();
    VERBOSE("No path given. Set to current location: $file_path");
}

if ($opt_lang) {
    @wishlang = split( ',', $opt_lang );
}

if ($opt_hoster) {
    @wishhost = split( ',', $opt_hoster );
}

#############################
#####     MAIN PROG     #####
#############################

#####     Get all info we need

%meta = get_info($proxer_id);

INFO( "Title: ", $meta{'title'} );
undef($var);
foreach ( @{ $meta{'genre'} } ) {
    $var .= "$_ ";
}
INFO("Genre: $var");
INFO( 'Season: ', $meta{'season'}[0], ' - ', $meta{'season'}[1] );

undef($var);
$proxer_page = 0;
while ( !$var ) {
    $proxer_page++;

    VERBOSE("Working on page $proxer_page");
    $proxer_api =
      dl("http://proxer.me/info/$proxer_id/list?format=json&p=$proxer_page");
    $proxer_api = eval {
        $json_var = JSON::decode_json($proxer_api);
        if ( $json_var->{'error'} ) {
            return undef();
        }
        return $json_var;
    } or ERROR("proxer returned invalid Json");

    # check if this page contains episodes or if its the last++
    if ( scalar( @{ $proxer_api->{'data'} } ) == 0 ) {
        $var = 1;
        last;
    }

    if ( !$proxer_json ) {
        $proxer_json = $proxer_api;
        next;
    }

# todo bugfix: value of $proxer_json->{'end'} not updated when when pushing entries to $proxer_json->{'data'}

    # push new entries from 'data' to the old 'data'
    foreach ( @{ $proxer_api->{'data'} } ) {
        push( @{ $proxer_json->{'data'} }, $_ );
    }
}

# prepare the array
# perl start array at 0, anime start normally at episode 1.
# We have to trick around a bit.
# first array entry (ARRAY[0]) stores global info about the anime.

$proxer_watch_start = $proxer_json->{'start'};
$proxer_watch_stop  = $proxer_json->{'end'};

print("$proxer_watch_start\n");
print("$proxer_watch_stop\n");
die;

$proxer_watch[0] = {
    'no'    => '0',
    'lang'  => $proxer_json->{'lang'},
    'title' => $meta{'title'},
    'genre' => [ $meta{'genre'} ],
};

# prepare your... array
foreach ( $proxer_watch_start .. $proxer_watch_stop ) {
    push(
        @proxer_watch,
        {
            'no'     => $_,
            'lang'   => [],
            'hoster' => [],
        }
    );
}

foreach ( @{ $proxer_json->{'data'} } ) {
    push(
        @{ $proxer_watch[ $_->{'no'} ]->{'hoster'} },
        split( ',', $_->{'types'} )
    );
    push( @{ $proxer_watch[ $_->{'no'} ]->{'lang'} }, $_->{'typ'} );
    $proxer_watch[ $_->{'no'} ]->{'no'} = $_->{'no'};
}

##### OUTPUTS #####

if ($opt_list) {
    anime_list(@proxer_watch);
    exit;
}

if ( !$opt_nodir ) {
    $file_path .= "/$meta{'title'}";
    if ( !-d $file_path ) {
        VERBOSE("Create directory: $file_path");
        mkdir("$file_path") or ERROR("Cant create folder: $!");
    }
}

open( FH, '>', "$file_path/$meta{'title'}.txt" )
  or ERROR("Cant open file for summary: $!");
print FH ("Title: $meta{'title'}\n");
print FH ("Genre: ");
foreach ( @{ $meta{'genre'} } ) {
    print FH ("$_ ");
}
print FH ("\n");
print FH ("Describtion: \n$meta{'desc'}\n");
close(FH);

foreach (@proxer_watch) {
    my $dl_lang;
    my $dl_host;
    my $dl_no;
    my $dl_wishlang;
    my $dl_wishhost;
    my @dl_avhoster;
    my $active;
    my $dl_link;

    $active = $_;

    if ( $_->{'no'} eq '0' ) {    # recognize the first entry
        next;
    }

    $dl_no = $_->{'no'};

    # select language
    foreach (@wishlang) {
        $dl_wishlang = $_;
        foreach ( @{ $active->{'lang'} } ) {
            if ( $dl_wishlang eq $_ ) {
                $dl_lang = $_;
                last;
            }
        }
        last if $dl_lang;
    }
    VERBOSE("Selected $dl_lang for $dl_no");

    @dl_avhoster =
      get_hoster("http://proxer.me/watch/$proxer_id/$dl_no/$dl_lang");
    foreach (@wishhost) {
        $dl_wishhost = $_;
        foreach (@dl_avhoster) {
            if ( $dl_wishhost eq $_->{'type'} ) {
                $dl_host = $_;
                last;
            }
        }
        last if $dl_host;
    }

    if ( !$dl_lang or !$dl_host ) {
        INFO("No suitable host or language found for $dl_no. Skip");
        sleep(3);
        next;
    }

    ##### DOWNLOAD #####

    $dl_link = gen_link($dl_host);

    INFO( $meta{'title'}, ":$dl_no\@$dl_host->{'name'}\n" );

    INFO("Downloading $dl_no");

    system("youtube-dl -q -o '$file_path/$dl_no.mp4' $dl_link");

    VERBOSE("Selected $dl_host for $dl_no");
    INFO("waiting...");
    sleep(3);
}

###############################
#####     SUBROUTINES     #####
###############################

sub get_hoster {

    #todo extract streams

    my $buffer;
    my $link = $_[0];
    my @hoster;

    while (1) {
        $buffer = eval { dl($link); }
          or ERROR("Something went wrong while download");

        if ( $buffer =~ m/captcha/gi ) {

            #todo display error message and solution
            print("*** Looks like proxer-ddos protection got us...\n");
            print(
"*** Go to -> $link <- and solve the CAPTCHA, then press enter.\n"
            );
            getc STDIN;
            next;
        }
        else {
            last;
        }
    }

    $buffer =~ m/streams.*?=.*?(\[.+?\])/i;
    @hoster = @{ JSON::decode_json($1) };

    return @hoster;
}

sub gen_link {
    my $url;
    my $code;

    $url  = $_[0]->{'replace'};
    $code = $_[0]->{'code'};

    $url =~ s/#/$code/g;
    $url =~ s/\\//g;

    return $url;
}

sub dl {
    my $req;
    my $res;
    my $ua;
    my $site;
    my $tries = 0;

    VERBOSE("Download $_[0]");

    while ( $tries < 3 ) {
        $tries++;
        $ua = LWP::UserAgent->new;
        $ua->agent($LWP_useragent);
        $req = HTTP::Request->new( GET => $_[0] );
        $res = $ua->request($req);
        if ( $res->is_success ) {
            return $res->content;
            last;
        }
        else {
            print(
                "Download error. Check your internet connection. waiting 10s\n"
            );
            VERBOSE("Download wasnt successfull. Try again in 10s");
            sleep(10);
            next;
        }
    }
    VERBOSE("Download was not successfull after $tries tries.");
    return undef();
}

sub get_info {
    my $x = dl("http://proxer.me/info/$_[0]");
    $x =~ s/\n//g;

    my ($title) = $x =~ m/<td>.*?Original titel.*?<\/td><td>(.*?)<\/td>/im;

    $x =~ m/<td.*?>.*?genre.*?<\/td><td.*?>(.*?)<\/td>/im;
    my @genre = $1 =~ m/<a.*?>(.*?)<\/a>/mig;

    my ($desc) = $x =~ m/<b>Beschreibung:<\/b><br>(.*?)<\/td>/im;
    $desc =~ s/<.*br.*>/ /gi;

    $x =~ m/<b>Season<\/b><\/td><td.*?>(.*?)<\/td>/im;
    my @season = $1 =~ m/>(\w+\W\d\d\d\d)</ig;
    if ( !$season[1] ) {
        $season[1] = '***';
    }

    my %info = (
        'title'  => $title,
        'genre'  => [@genre],
        'desc'   => $desc,
        'season' => [@season],
    );

    return %info;

}

sub anime_list {
    foreach (@proxer_watch) {
        if ( $_->{'no'} eq '0' ) {    # recognize the first 'info' entry
            print("$_->{'title'}\n");
            print("|---Available languages: \n");
            foreach ( @{ $_->{'lang'} } ) {
                print("|   |---$_\n");
            }
            print("|    \n");
            print("|---Genres: \n");
            foreach ( @{ $_->{'genre'} } ) {
                print("|   |---$_\n");
            }
            print("|\n");
            next;
        }

        elsif ( $_->{'no'} eq scalar(@proxer_watch) - 1 ) {
            print( "|", color('bold'), "---Episode $_->{'no'}\n",
                color('reset') );
            print( "    |", color('bold'), "---Languages: \n", color('reset') );
            foreach ( @{ $_->{'lang'} } ) {
                print("    |   |---$_\n");
            }
            print("    |\n");
            print( "    |", color('bold'), "---Hoster: \n", color('reset') );
            foreach ( @{ $_->{'hoster'} } ) {
                print("        |---$_\n");
            }
            print(" \n");
        }
        else {

            print( "|", color('bold'), "---Episode $_->{'no'}\n",
                color('reset') );
            print( "|   |", color('bold'), "---Languages: \n", color('reset') );
            foreach ( @{ $_->{'lang'} } ) {
                print("|   |   |---$_\n");
            }
            print("|   |\n");
            print( "|   |", color('bold'), "---Hoster: \n", color('reset') );
            foreach ( @{ $_->{'hoster'} } ) {
                print("|       |---$_\n");
            }
            print("|\n");
        }
    }
}

##########################################
#####     ERROR HANDLING AND HELP    #####
##########################################

sub help {
    print <<"EOF";
Downloads all episodes of a given anime.

Usage: proxerdl --link or --id [options...] destination

    --id            The id of the anime. e.g. proxer.me/info/<ID>#top.
    --link          The link to an anime on proxer. this can be the detail page or episodes overview.
    --lang          Language preferences as comma separated list: gersub,engdub,....
    --hoster        Hoster preferences as comma separated list: proxerhd,clipfish,streamcloud.
    
    
    --list          List the structure of the anime. No Downloading.
    --no-dir        Do not create a directory for the Anime.
    destination     Specify the destination for the download. By default its your current directory/<anime>/.
    

copyright Paul Maruhn (paulmaruhn\@gmail.com)
Released under GPL.
EOF

    exit;
}

sub INFO {
    print color('bold green');
    print("[INFO] ");
    print color('reset');
    print( @_, "\n" );
}

sub VERBOSE {
    if ($opt_verbose) {
        print color('bold yellow');
        print("[INFO] ");
        print color('reset');
        print( @_, "\n" );

        #exit;
    }
    else {
        #exit;
    }
}

sub ERROR {
    print color('bold red');
    print("[ERROR] ");
    print color('reset');
    print("@_\n");
    exit(1);
}

sub proxer {
    my @proxer;
    my @colors;

    @colors = qw( red  green  yellow  blue  magenta  cyan  white );

    @proxer = (
        '          #####               #####',
        '           ###      VISIT      ### ',
        '            #                   #  ',
        ' ____  ____   _____  _______ ____    __  __ _____ ',
        '|  _ \|  _ \ / _ \ \/ / ____|  _ \  |  \/  | ____|',
        '| |_) | |_) | | | \  /|  _| | |_) | | |\/| |  _|  ',
        '|  __/|  _ <| |_| /  \| |___|  _ < _| |  | | |___ ',
        '|_|   |_| \_\\\___/_/\_\_____|_| \_(_)_|  |_|_____|',
    );

    foreach (@proxer) {
        print( color( $colors[ ( rand(6) ) ] ) );
        print( $_, "\n" );
        print( color('reset') );
        usleep( 250 * 1000 );
    }
    exit;
}

