#!/usr/bin/perl


# The MIT License (MIT)
# Copyright (c) 2016 paul maruhn
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.



use strict;
use warnings;
use Term::ANSIColor;
use Getopt::Long;
use Cwd;
use Data::Dumper;
use Time::HiRes qw(usleep);
use File::Fetch;
use Cwd;


my @chk_mod;

if(!eval {require LWP}) {
    push(@chk_mod, 'LWP');
}
if(!eval {require LWP::ConnCache}) {
    push(@chk_mod, 'LWP::ConnCache');
}
if(!eval {require LWP::ConnCache::MaxKeepAliveRequests}) {
    push(@chk_mod, 'LWP::ConnCache::MaxKeepAliveRequests');
}
if(!eval {require JSON}) {
    push(@chk_mod, 'JSON');
}
if(!eval {require HTTP::Cookies}) {
    push(@chk_mod, 'HTTP::Cookies');
}
if(!eval {require Term::ReadKey}) {
    push(@chk_mod, 'Term::ReadKey');
}
if(!eval {require Math::Round}) {
    push(@chk_mod, 'Math::Round');
}

if(@chk_mod) {
    foreach(@chk_mod) {
        print('Missing Module: ', $_, "\n");
    }
    ERROR('Some necessary modules are missing. Run \'cpan install <MODULE NAME>\'');
}
undef(@chk_mod);

Math::Round->import('nearest');
LWP->import;
JSON->import;
HTTP::Cookies->import;
Term::ReadKey->import;



########################
#####     TODO     #####
########################

# todo: more verbose output.
# todo: add more export possibilities. 

##########################
#####     CHECKS     #####
##########################

$|++; # turn that f*cking buffer off!

# todo is there an other solution that will work on windows
BEGIN {
    # make sure ctrl + c on passwd prompt doesnt 'mute' STDOUT
    $SIG{INT} = sub {
        print("\n** Script stopped.\n");
        exit(1);
    };
    sub ERR {
        print("!!! @_\n");
        
        exit();
    }
}







#############################
#####     VARIABLES     #####
#############################



my $LWP_useragent = "Proxer-dl/dev_v0.5";
my @wishlang_manga = ("de", "en");

my $timeout = 7;

my $fail_img;
open(FH, '<', 'lib/fail.png') or die $!;
while(my $x = <FH>) {
    $fail_img .= $x;
}


my $LWP = LWP::UserAgent->new();
$LWP->conn_cache(LWP::ConnCache::MaxKeepAliveRequests->new(
        total_capacity          => 5000,
        max_keep_alive_requests => 5000,
    )
);
$LWP->agent($LWP_useragent);
$LWP->timeout($timeout);
$LWP->cookie_jar({});



##########################
#####     Getopt     #####
##########################

my %opt;
GetOptions(\%opt,
    'help',
    'verbose',
    'debug',
    'lang=s',
    'extdl=s',
    'no-dir',
    'no-subdir'
);

$opt{manga} = shift @ARGV;

help() if $opt{help};


##### CHECK OPTs #####

if(!$opt{manga}) {
    ERR("Require link or id. Use --help.");
} else {
    if($opt{manga} =~ m/^\d*$/) {
        $opt{id} = $opt{manga};
    }
    else {
        ($opt{id}) =~ m/(\d+)/;
    }
}

unless($opt{lang}) {
    $opt{lang} = 'de';
}




#####################
#                   #
#     MAIN PROG     #
#                   #
#####################



# Get all info we need
my $manga_meta = get_info($opt{id});


INFO("Title: ", $manga_meta->{'title'});
foreach(@{$manga_meta->{'genre'}}) {
    INFO('Genre: ', $_);
}
INFO('Season: ', $manga_meta->{'season'});

my @chapters_raw;
for(my $i = 0; 1; $i++) {
    VERBOSE("Working on page $i");
    
    my $json_string = dl("https://proxer.me/info/$opt{id}/list?format=json&p=$i");
    
    unless($json_string) {
        ERR("There was an error while downloading");
    }
    
    my $data = eval {
        JSON::decode_json($json_string);
    } or ERR("proxer returned invalid Json");
    
    
    # check if this page contains episodes or if its the last++
    if(int(@{$data->{'data'}}) == 0) {
        last;
    }
    else {
        # push new entries from the api to the old episode array
        push(@chapters_raw, @{$data->{data}});
    }
}

# Check if the requested manga is really a manga

# merge the different language entries together
my $chapters;

foreach(@chapters_raw) {
    my $k = $_;
    my $k_no = $_->{no};
    my $k_typ = $_->{typ};
    
    $chapters->{int($k_no)}->{$k_typ} = $k;
}

# Preparing the download

my $dir= './';
if(!$opt{'no-dir'}) {
    $dir .= $manga_meta->{title}.'/';
    $dir =~ s/[\/\.]/_/g; # replace usupported chars
    unless(-d $dir) {
        mkdir($dir) or die $!;
    }
    chdir($dir) or die $!;
}


close(FH);

for(my $i = 0; 1; $i++) {
    my $k = $chapters->{$i}->{$opt{lang}};
    next unless($k);
    
    
    if(!$opt{'no-subdir'}) {
        my $folder = $k->{title};
        
        $folder =~ s/[\/\.]/_/g;
        mkdir($folder);
        chdir($folder)
    }
    
    my (($cdn), @pages) = get_pages("https://proxer.me/read/$opt{id}/$k->{no}/$k->{typ}/");
    
    INFO("downloading to ", getcwd(), "\n");
    foreach(@pages) {
        my $image_file = $$_[0];
        my $img_uri = $cdn.'//'.$image_file;
        my $buffer = dl($img_uri);
        unless($buffer) {
            $buffer = $fail_img;
        }
        my $filename = $k->{no}.'_'.$image_file;
        open(FH, '>>', $filename) or die "$filename: $!";
        print FH $buffer;
        close(FH);
    }
    
    chdir('..') unless $opt{'no-subdir'}
}

chdir('..') unless $opt{'no-dir'};



proxer();


exit(0);


###############################
#####     SUBROUTINES     #####
###############################


sub get_hoster {
    #todo extract streams
    
    my $buffer;
    my $link = $_[0];
    my @hoster;
    
    while(1) {
        $buffer = eval {
            dl($link);
        } or ERROR("Something went wrong while download");
        
        if($buffer =~ m/captcha/gi) {
            #todo display error message and solution
            print("*** Looks like proxer-ddos protection got us...\n");
            print("*** Go to -> $link <- and solve the CAPTCHA, then press enter.\n");
            getc STDIN;
            next;
        } else {
            last;
        }
        
    }
    
    $buffer =~ m/streams.*?=.*?(\[.+?\])/i;
    @hoster = @{JSON::decode_json($1)};
    
    return @hoster;
}

sub dl {
    my $res;
    my $tries = 0;
    
    
    VERBOSE("Download @_");
    
    while($tries < 5) {
        $tries++;
        $res = $LWP->get(@_);
        if ($res->is_success) {
            return $res->decoded_content;
            last;
        } else { 
            print("*** Download error. Waiting 15s\n");
            sleep(15);
            VERBOSE("*** Download wasnt successfull. Check your internet connection. Try again in 15s");
            next;
        }
    }
    VERBOSE("Download was not successfull after $tries tries.");
    return undef();
}

sub get_info {
    my $x = dl("http://proxer.me/info/$_[0]");
    
    if($x =~ m/<title>.*?error.*?404.*?<\/title/i) {
        ERROR("Anime not found");
    }
    
    if($x =~ m/logge dich ein/i) {
        print("** Need authentification to access this anime/manga\n");
        login() or ERROR("Authentification failed");
        
        # lets tweak some cookies...
        $$LWP->{'COOKIES'}->{'proxer.me'}->{'/'}->{'adult'} = [0, 1, undef, 1, undef, time() +1200];
        
        $x = dl("http://proxer.me/info/$_[0]");
    }
    
    $x =~ s/\n//g;
    $x =~ s/&ouml;/oe/g;
    $x =~ s/&uuml;/ue/g;
    $x =~ s/&auml;/ae/g;
    $x =~ s/&Ouml;/Oe/g;
    $x =~ s/&Uuml;/Ue/g;
    $x =~ s/&Auml;/Ae/g;
    
    my ($title) = $x =~ m/<td>.*?Original titel.*?<\/td><td>(.*?)<\/td>/im;
    
    $x =~ m/<td.*?>.*?genre.*?<\/td><td.*?>(.*?)<\/td>/im;
    my @genre = $1 =~ m/<a.*?>(.*?)<\/a>/mig;
    
    my ($desc) = $x =~ m/<b>Beschreibung:<\/b><br>(.*?)<\/td>/im;
    $desc =~ s/<.*br.*>/ /gi;
    
    $x =~ m/<tr.*?><td.*?><b>Season<\/b>.*?<\/td><td.*?>(.*?)<\/td><\/tr>/im;
    my $season = $1;
    $season =~ s/<.*?>//ig;
    
    my $image = "https://cdn.proxer.me/cover/$_[0].jpg";
    
    my $info = {
        'title' => $title,
        'genre' => [@genre],
        'desc' => $desc,
        'season' => $season,
        'cover' => $image,
    };
    
    return $info;
}


sub get_pages {
    my $buffer;
    my $link = $_[0];
    my $pages;
    my $serverurl;
    
    while(1) {
        $buffer = eval {
            dl($link);
        } or ERROR("Something went wrong while download");
        
        if($buffer =~ m/captcha/gi) {
            #todo display error message and solution
            print("*** Looks like proxer-ddos protection got us...\n");
            print("*** Go to -> $link <- and solve the CAPTCHA, then press enter.\r");
            getc STDIN;
            next;
        } else {
            last;
        }
    }
    
    $buffer =~ s/\n//g;
    $buffer =~ m/pages = (\[\[.*?\]\])/igm;
    
    $pages = eval{JSON::decode_json($1)};
    
    $buffer =~ m/serverurl = '\/\/(.*?)\/'/i;
    $serverurl = "http://$1";

    return $serverurl, @{$pages};
}


sub meta_list {
    my $j = shift;
    
    print("Not implemented yet\n");
    exit(0);
}




##########################################
#####     ERROR HANDLING AND HELP    #####
##########################################


sub help {
    print <<"EOF";
Downloads all episodes of a given anime.

Usage: proxerdl [options...] [id | link]

    --lang          Language preferences as comma separated list: gersub,engdub,....
    
    --no-dir        Do not create a directory for the Manga.
    --no-subdir     Do not create subdirectories for each chapter.
    

copyright Paul Maruhn (paulmaruhn\@gmail.com)
Released under MIT.
EOF

exit(0);
}

sub INFO {
    print("*** ");
    @_ = grep(!undef, @_);
    if($_[scalar(@_)-1] !~ m/[\r|\b]$/) {
        print(@_, "\n");
    } else {
        print(@_);
    }
}

sub VERBOSE {
    if($opt{verbose}) {
        print("### ");
        print(@_, "\n");
    }
}

sub ERROR {
    print("!!! ");
    print("@_\n");
    exit(1);
}

sub proxer {
    my @proxer;
    my @colors;
    
    @colors = qw( red  green  yellow  blue  magenta  cyan  white );
    
    @proxer = ('',
        '          #####               #####', 
        '           ###      VISIT      ### ',
        '            #                   #  ',
        ' ____  ____   _____  _______ ____    __  __ _____ ',
        '|  _ \|  _ \ / _ \ \/ / ____|  _ \  |  \/  | ____|',
        '| |_) | |_) | | | \  /|  _| | |_) | | |\/| |  _|  ',
        '|  __/|  _ <| |_| /  \| |___|  _ < _| |  | | |___ ',
        '|_|   |_| \_\\\___/_/\_\_____|_| \_(_)_|  |_|_____|',
    );
    
    foreach(@proxer) {
        print(color($colors[(rand(6))]));
        print($_, "\n");
        print(color('reset'));
        usleep(250*1000);
    }
    print 'Feel free to make a donation to proxer!';

    exit;
}
