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

if(!eval {require LWP}) {
    ERROR("LWP is not installed. Run \'cpan install LWP\' to install.");
}
if(!eval {require JSON}) {
    ERROR("JSON is not installed. Run \'cpan install JSON\' to install.");
}
if(!eval {require HTTP::Cookies}) {
    ERROR("HTTP::Cookies is not installed. Run \'cpan install HTTP::Cookies\' to install.");
}
if(!eval {require Term::ReadKey}) {
    ERROR("Term::ReadKey is not installed. Run \'cpan install Term::ReadKey\' to install.");
}
if(!eval {require Math::Round}) {
    ERROR("Math::Round is not installed. Run \'cpan install Math::Round\' to install.");
}

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
# todo: download cover image

##########################
#####     CHECKS     #####
##########################

$|++; # turn that f*cking buffer off!

# todo is there an other solution that will work on windows
BEGIN {
    # make sure ctrl + c on passwd prompt doesnt 'mute' STDOUT
    
    $SIG{INT} = sub {
        print("\n** Script stopped.\n");
        exit(0);
        
    }
}

#############################
#####     VARIABLES     #####
#############################



my $LWP_useragent = "Proxerdl/dev_v0.01";
my @wishhost = ("proxer-stream", "streamcloud", "streamcloud2", "clipfish-extern");
my @wishlang_anime = ("gerdub", "gersub", "engsub", "engdub");
my @wishlang_manga = ("de", "en");

my $opt_verbose;
my $opt_id;
my $opt_path;
my $opt_list;
my $opt_hoster;
my $opt_lang;
my $opt_out;
my $opt_nodir;
my $opt_prefix;
my $opt_note;

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

my %dl_sum;

my $file_path;

my $var;
my $json_var;
my $file_url;
my $hoster_url;
my $file_count = 0;
my @files;
my @episodes;

# cookies...
my $ua_cookies = HTTP::Cookies->new(
    #file => './cookies',
    autosave => 1,
);
my $ua = LWP::UserAgent->new;
$ua->agent($LWP_useragent);
$ua->timeout(5);
$ua->cookie_jar($ua_cookies);


##########################
#####     Getopt     #####
##########################

GetOptions(
    'id=i' => \$opt_id,
    'verbose' => \$opt_verbose,
    'help' => \&help,
    'proxer' => \&proxer,
    'lang=s' => \$opt_lang,
    'hoster=s' => \$opt_hoster,
    'list' => \$opt_list,
    'no-dir' => \$opt_nodir,
    'prefix=s' => \$opt_prefix,
    'note' => \$opt_note,
);

# parsing opts
if(!$opt_id) {
    ERROR("Require link or id. Use --help.");
} else {
    if($opt_id =~ m/\D/ig) {
        if($opt_link !~ m/proxer\.me/) {
            ERROR("No valid proxer link: $opt_link");
        } else {
            $opt_link =~ m/.*?proxer\.me\/.*?\/(\d+).*$/;
            $proxer_id = $1;
        }
    } else {
        $proxer_id = $opt_id;
    }
}

{
    
}

# get directory
if($ARGV[0]) {
    if(!-d $ARGV[0]) {
        ERROR("Directory doesnt exist: $ARGV[0]");
        exit;
    }else {
        $file_path = $ARGV[0];
        VERBOSE("Path: $file_path");
    }
} else {
    $file_path = getcwd();
    VERBOSE("No path given. Set to current location: $file_path");
}

if($opt_lang) {
    @wishlang_anime = split(',', $opt_lang);
    @wishlang_manga = split(',', $opt_lang);
}

if($opt_hoster) {
    @wishhost = split(',', $opt_hoster);
}





#############################
#####     MAIN PROG     #####
#############################


# memorize the time
$dl_sum{'time'}{'start'} = time();


# Get all info we need
%meta = get_info($proxer_id);
$meta{'time'} = localtime();

INFO("Title: ", $meta{'title'});
undef($var);
foreach(@{$meta{'genre'}}) {
    INFO('Genre: ', $_);
}
INFO('Season: ', $meta{'season'});


undef($var);
$proxer_page = 0;
while(!$var) {
    $proxer_page++;
    
    VERBOSE("Working on page $proxer_page");
    $proxer_api = dl("http://proxer.me/info/$proxer_id/list?format=json&p=$proxer_page");
    $proxer_api = eval {
        $json_var = JSON::decode_json($proxer_api);
        if ($json_var->{'error'}) {
            return undef();
        }
        return $json_var;
    } or ERROR("proxer returned invalid Json");
    
    if(!$proxer_json) {
        $proxer_json = $proxer_api;
        next;
    }
    
    # check if this page contains episodes or if its the last++
    if (scalar(@{$proxer_api->{'data'}}) == 0) {
        $var = 1;
        last;
    }
    
    # push new entries from the api to the old episode array
    foreach(@{$proxer_api->{'data'}}) {
        push(@{$proxer_json->{'data'}}, $_);
        $proxer_json->{'end'} = $_->{'no'};
    }
}


# prepare the array
# perl start array at 0, anime start normally at episode 1.
# We have to trick around a bit.
# first array entry (ARRAY[0]) stores global info about the anime.




$proxer_watch_start = $proxer_json->{'start'};
$proxer_watch_stop = $proxer_json->{'end'};

$proxer_watch[0] = {
    'kat' => $proxer_json->{'kat'},
    'no' => '0', 
    'lang' => $proxer_json->{'lang'},
    'title' => $meta{'title'},
    'genre' => [$meta{'genre'}],
};



# prepare your... array

# merge the different language entris together
if($proxer_json->{'kat'} eq 'anime') {    
    foreach(@{$proxer_json->{'data'}}) {
        push(@{$proxer_watch[$_->{'no'}]->{'hoster'}}, split(',', $_->{'types'}));
        push(@{$proxer_watch[$_->{'no'}]->{'lang'}}, $_->{'typ'});
        $proxer_watch[$_->{'no'}]->{'no'} = $_->{'no'};
    }
}
elsif($proxer_json->{'kat'} eq 'manga') {
    foreach(@{$proxer_json->{'data'}}) {
        $proxer_watch[$_->{'no'}]{'title'} = $_->{'title'};
        push(@{$proxer_watch[$_->{'no'}]->{'lang'}}, $_->{'typ'});
        $proxer_watch[$_->{'no'}]->{'no'} = $_->{'no'};
    }
} else {
    ERROR("Something is wrong with proxers JSON. Isnt an anime neither a manga.");
}

# removing undefined entries in @proxer_watch
@proxer_watch = grep(defined($_), @proxer_watch);
$meta{'elements'} = scalar(@proxer_watch) -1;
INFO("Episodes: ", $meta{'elements'});


if($opt_list) {
    meta_list(@proxer_watch);
    exit;
}

if(!$opt_nodir) {
    $var = $meta{'title'};
    $var =~ s/\//\\/g;
    $var =~ s/^\.//;
    
    $file_path .= '/'.$var.'/';
    if(!-d $file_path) {
        VERBOSE("Create directory: $file_path");
        mkdir("$file_path") or ERROR("Cant create folder: $!");
    }
}


if($opt_note) {
    print("** Add Anime to watchlist\n");
    if(login()) {
        $ua->post("http://proxer.me/info/$proxer_id?format=json&json=note", {
                'checkPost' => 1,
            }
        );
    } else {
        print("** Cant add to watchlist\n");
    }
}

###################
##### SUMMARY #####
###################

# Create a summary file
open(FH, '>', "$file_path/$meta{'title'}.txt") or ERROR("Cant create file: $!");
select(FH);
print($meta{'time'}, "\n");
print("Title: $meta{'title'}\n");
print("Episodes/Chapters: $meta{'elements'}\n");
print("Genres: "); 
foreach(@{$meta{'genre'}}) {
    print("$_ ");
}
print("\n");
print("Describtion: \n$meta{'desc'}\n");
select(STDOUT);
close(FH) or ERROR("Cant close file: $!");

# Download cover image
$var = dl($meta{'cover'});
if($var) {
    open(FH, '>', $file_path.'cover.jpg') or ERROR("Cant create file: $!");
    print FH $var;
    close(FH) or ERROR("Cant create file: $!");
}


###########################
##### START DOWNLOADS #####
###########################


if($proxer_watch[0]->{'kat'} eq 'anime') {
    dl_anime(@proxer_watch);
}
elsif($proxer_watch[0]->{'kat'} eq 'manga') {
    dl_manga(@proxer_watch);
}
else {
    ERROR("Something went wrong");
}

################
##### POST #####
################


$dl_sum{'time'}{'end'} = time();
$dl_sum{'time'}{'all'} = $dl_sum{'time'}{'end'} - $dl_sum{'time'}{'start'};

$dl_sum{'data'} /= 10**6;

$dl_sum{'bndwth'} = $dl_sum{'data'} / $dl_sum{'time'};
$dl_sum{'bndwth'} = $dl_sum{'bndwth'};

$dl_sum{'data'} = nearest(0.001, $dl_sum{'data'});


INFO("SUMMARY:");
INFO("Error:       ", $dl_sum{'err'}) if $dl_sum{'err'};
INFO("Skipped:     ", $dl_sum{'skipped'}) if $dl_sum{'skipped'};
INFO("Time:        ", $dl_sum{'time'}{'all'}, "s") if $dl_sum{'time'}{'all'};
INFO("Data:        ", $dl_sum{'data'}, "MB") if $dl_sum{'data'};
INFO("Bandwidth:   ", $dl_sum{'bndwth'}, "MB/s");
INFO("");
INFO("Download complete");

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
    my $site;
    my $tries = 0;
    
    
    VERBOSE("Download @_");
    
    while($tries < 3) {
        $tries++;
        $res = $ua->get(@_);
        if ($res->is_success) {
            $dl_sum{'data'} += length($res->content);
            return $res->content;
            last;
        } else { 
            print("** Download error. Waiting 10s\n");
            VERBOSE("** Download wasnt successfull. Check your internet connection. Try again in 10s");
            sleep(10);
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
        $ua_cookies->{'COOKIES'}->{'proxer.me'}->{'/'}->{'adult'} = [0, 1, undef, 1, undef, time() +1200];
        
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
    
    my %info = (
        'title' => $title,
        'genre' => [@genre],
        'desc' => $desc,
        'season' => $season,
        'cover' => $image,
    );
    
    return %info;
}


sub dl_anime {
    my $skipped = 0;
    foreach(@_) {
        my $dl_lang;
        my $dl_host;
        my $dl_no;
        my $dl_wishlang;
        my $dl_wishhost;
        my @dl_avhoster;
        my $active;
        my $dl_link;
        
        $active = $_;
        
        if ($active->{'no'} eq '0') { # recognize the first entry
            next;
        }
        
        # select language
        
        print("** Start download: ", $active->{'no'}, "\n");
        foreach(@wishlang_anime) {
            $dl_wishlang = $_;
            foreach(@{$active->{'lang'}}) {
                if($dl_wishlang eq $_) {
                    $dl_lang = $_;
                    last;
                }
            }
            last if $dl_lang;
        }
        VERBOSE("Selected $dl_lang for $active->{'no'}");
        
        @dl_avhoster = get_hoster("http://proxer.me/watch/$proxer_id/$active->{'no'}/$dl_lang");
        foreach(@wishhost) {
            $dl_wishhost = $_;
            foreach(@dl_avhoster) {
                if($dl_wishhost eq $_->{'type'}) {
                    $dl_host = $_;
                    last;
                }
            }
            last if $dl_host;
        }
        
        if(!$dl_lang or !$dl_host) {
            INFO("No suitable host or language found for $active->{'no'}. Skip");
            $dl_sum{'skipped'}++;
            sleep(5);
            next;
        }
        
        $dl_link = $dl_host->{'replace'};
        # Some hotfix stuff:
        if($dl_link !~ m/#/) {
            $dl_link = $dl_host->{'code'};
        } else {
            $dl_link =~ s/#/$dl_host->{'code'}/;
        }
        
        
        ##### DOWNLOAD #####
        
        # Generate fancy filenames
        my $file_name = $active->{'no'};
        $var = length($meta{'elements'}) - length($active->{'no'});
        foreach(1 .. $var) {
            $file_name = "0$file_name";
        }
        if($opt_prefix) {
            $file_name = $opt_prefix.$file_name;
        }
        $file_name .= '.mp4';
        
        # Check if file was already downloaded
        if(-e $file_path.'/'.$file_name) {
            $dl_sum{'skipped'}++;
            sleep(5);
            next;
        }
        
        
        
        
        my $link = video_link($dl_link);
        if(!$link) {
            $dl_sum{'err'}++;
            sleep(5);
            next;
        }
        
        
        $ua->show_progress(1);
        my $buffer = $ua->get($link);
        $ua->show_progress(undef);
        
        
        $dl_sum{'data'} += length($buffer->decoded_content);
        
        if($buffer->status_line !~ m/200/) {
            $dl_sum{'err'}++;
            sleep(5);
            next;
        }


        
        open(FH, '>', $file_path.'/'.$file_name) or ERROR("Cant write file: $!");
        print FH $buffer->decoded_content;
        close(FH);
        
        VERBOSE("waiting...");
    }
}

sub video_link {
    my $site_link = $_[0];
    
    if($site_link =~ m/stream\.proxer\.me/i) {
        my $ua = LWP::UserAgent->new();
        $ua->agent($LWP_useragent);
        $ua->cookie_jar({});
        
        my $buffer = $ua->get($site_link);
        $dl_sum{'data'} += length($buffer->decoded_content);
        if($buffer->is_error) {
            return undef();
        } else {
            $buffer = $buffer->content;
        }
        my ($file_link) = $buffer =~ m/"(http:\/\/.*\.mp4)"/i;
        
        return $file_link;
    }
    elsif($site_link =~ m/streamcloud\.eu/i) {
        # streamcloud downloader
        # post data to streamcloud:
        # op =>
        # usr_login => 
        # id =>
        # fname =>
        # referer =>
        # hash =>
        # imhuman =>
        
        
        my $buffer = $ua->get($site_link);
        $dl_sum{'data'} += length($buffer->decoded_content);
        if($buffer->is_error) {
            return undef();
        } else {
            $buffer = $buffer->content;
        }
        
        my %params;
        
        # crapcode:
        $buffer =~ m/name="op".*?value="(.*?)"/i;
        $params{'op'} = $1;
        $buffer =~ m/name="usr_login".*?value="(.*?)"/i;
        $params{'usr_login'} = $1;
        $buffer =~ m/name="id".*?value="(.*?)"/i;
        $params{'id'} = $1;
        $buffer =~ m/name="fname".*?value="(.*?)"/i;
        $params{'fname'} = $1;
        #$buffer =~ m/name="referer".*?value="(.*?)"/i;
        $params{'referer'} = 'http://proxer.me'; # $1;
        $buffer =~ m/name="hash".*?value="(.*?)"/i;
        $params{'hash'} = $1;
        $buffer =~ m/name="imhuman".*?value="(.*?)"/i;
        $params{'imhuman'} = $1;
        
        #print Dumper(%params);
        
        sleep(11);
        $buffer = $ua->post($site_link, 
            {
                'op' => $params{'op'},
                'usr_login' => $params{'usr_login'},
                'id' => $params{'id'},
                'fname' => $params{'fname'},
                'referer' => $params{'referer'},
                'hash' => $params{'hash'},
                'imhuman' => $params{'imhuman'},    
            }
        );
        if($buffer->is_error) {
            return undef();
        }
        
        my ($file_link) = $buffer->content =~ m/"(.*?\.mp4)"/i;
        
        return $file_link;
    }
    elsif($site_link =~ m/clipfish\.de/i) {
        # clipfish downloader
        
        
        $site_link =~ m/clipfish\.de\/.*?video\/(\d*)/i;
        my $id = $1;
        
        my $buffer = $ua->get('http://www.clipfish.de/devapi/id/'.$id.'?format=json');
        $dl_sum{'data'} += length($buffer->decoded_content);
        if($buffer->is_error) {
            return undef();
        } else {
            $buffer = $buffer->content;
        }
        
        $buffer = JSON::decode_json($buffer) or return undef;
        
        $buffer = $buffer->{'items'}[0]->{'media_thumbnail'};
        my ($md5) = ($buffer =~ m/\/([a-z0-9]{32})\//); # match on md5
        my ($pre) = ($md5 =~ m/([a-z0-9]{2}$)/);
        
        return 'http://video.clipfish.de/media/'.$pre.'/'.$md5.'.mp4';
    } else {
        return undef;
    }
        
        
}

sub dl_manga {
    INFO("Start downloading");
    foreach(@proxer_watch) {
        my $dl_lang;
        my $dl_wishlang;
        my $active;
        my $dl_link;
        my @dl_pages;
        my $dl_server;
        my $page_buffer;
        
        $active = $_;
        
        INFO($meta{'title'}, ": $active->{'no'}");
        
        if ($_->{'no'} eq '0') { # recognize the first entry
            next;
        }
        
            # select language
        foreach(@wishlang_manga) {
            $dl_wishlang = $_;
            foreach(@{$active->{'lang'}}) {
                if($dl_wishlang eq $_) {
                    $dl_lang = $_;
                    last;
                }
            }
            last if $dl_lang;
        }
        
        if(!$dl_lang) {
            INFO("No suitable language found for $active->{'no'}. Skip");
            sleep(3);
            next;
        }
        VERBOSE("Selected $dl_lang for $active->{'no'}.");
        
        
        ($dl_server, @dl_pages) = get_pages("http://proxer.me/read/$proxer_id/$active->{'no'}/$dl_lang");
        
        
        ##### DOWNLOAD #####
        
        # Download all pages
        foreach(@dl_pages) {
            if(!-e "$file_path/$active->{'no'}_$_->[0]") {
                $page_buffer = dl("$dl_server/$_->[0]");
                #$page_buffer = "IMAGE";
                open(FILE, '>', "$file_path/$active->{'no'}_$_->[0]");
                print FILE ($page_buffer);
                close(FILE);
            } else {
                next;
            }
        }
        
        # chillout for the ddos protection;
        sleep(3);
    }
}

sub get_pages {
    #todo extract streams
    
    my $buffer;
    my $link = $_[0];
    my @pages;
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
    
    @pages = @{JSON::decode_json("$1")};
    
    $buffer =~ m/serverurl = '\/\/(.*?)\/'/i;
    $serverurl = "http://$1";

    return $serverurl, @pages;
}


sub meta_list {
    foreach(@proxer_watch) {        
        if($_->{'no'} eq '0') { # recognize the first 'info' entry
            print("$_->{'title'}\n");
            print("|---Available languages: \n");
            foreach(@{$_->{'lang'}}) {
                print("|   |---$_\n");
            }
            print("|    \n");
            print("|---Genres: \n");
            foreach(@{$_->{'genre'}}) {
                print("|   |---$_\n");
            }
            print("|\n");
            next;
        }
        
        elsif($_->{'no'} eq scalar(@proxer_watch)-1) {
            print("|", color('bold'), "---Episode $_->{'no'}\n", color('reset'));
            print("    |", color('bold'), "---Languages: \n", color('reset'));
            foreach(@{$_->{'lang'}}) {
            print("    |   |---$_\n");}
            print("    |\n");
            print("    |", color('bold'), "---Hoster: \n", color('reset'));
            foreach(@{$_->{'hoster'}}) {
            print("        |---$_\n");}
            print(" \n");
        }else {
            
            print("|", color('bold'), "---Episode $_->{'no'}\n", color('reset'));
            print("|   |", color('bold'), "---Languages: \n", color('reset'));
            foreach(@{$_->{'lang'}}) {
            print("|   |   |---$_\n");}
            print("|   |\n");
            print("|   |", color('bold'), "---Hoster: \n", color('reset'));
            foreach(@{$_->{'hoster'}}) {
            print("|       |---$_\n");}
            print("|\n");
        }
    }
}

sub login {
    my $tries = 0;
    
    while($tries < 3) {
        $tries++;
        
        print("** Username: ");
        my $username = <STDIN>;
        chomp($username);
        print("** Password: ");
        ReadMode('noecho');
        my $passwd = <STDIN>;
        ReadMode('normal');
        print("\n");
        chomp($passwd);
        
        
        my $login = $ua->post('https://proxer.me/login?format=json&action=login',
            {
                username => $username,
                password => $passwd,
            }
        );
        $dl_sum{'data'} += length($login->decoded_content);
        
        if($login->is_error) {
            print("** Cant connect with proxer: ", $login->status_line, "\n");
            next;
        }
        $login = eval {return JSON::decode_json($login->decoded_content);};
        if(!$login) {
            print("** Something went wrong: No valid JSON\n");
            next;
        }
        
        if($login->{'error'} ne 0) {
            print('** Auth failed: ', $login->{'message'}, "\n");
            next;
        }
        print("** Login successfull\n");
        return 1;
        last;
    }
    print("** Authentification failed\n");
    return undef;
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
    
    --prefix        prefix for filename: '--prefix S01E' -> 'S01E001.mp4'. Use it with --no-dir to add a season to existing.
    
    --note          Add the Anime to your proxer watchlist.
    --list          List the structure of the anime. No Downloading.
    --no-dir        Do not create a directory for the Anime.
    --proxer        ...
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
    @_ = grep(!undef, @_);
    if($_[scalar(@_)-1] !~ m/[\r|\b]$/) {
        print(@_, "\n");
    } else {
        print(@_);
    }
}

sub VERBOSE {
    if($opt_verbose) {
        print color('bold yellow');
        print("[INFO] ");
        print color('reset');
        print(@_, "\n");
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
    
    foreach(@proxer) {
        print(color($colors[(rand(6))]));
        print($_, "\n");
        print(color('reset'));
        usleep(250*1000);
    }
    exit;
}

