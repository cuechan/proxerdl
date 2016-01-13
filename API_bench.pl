#!/usr/bin/perl


use LWP;
use Time::HiRes qw(usleep);

my $LWP_useragent = "Proxerdl/dev_v0.01";

print "starting\n";
$sleep = 3500000;
while(dl('http://proxer.me/watch/53/12/engsub')) {
    $x++;
    print($x," \@ ", $sleep/1000000, "s OK\n");
    if($x == 24) {
        print("$sleep OK \n");
        $x = 0;
        $sleep -= 100000;
        print("next in 20s: $sleep\n");
        sleep(60);
    }
    usleep($sleep);
}

print($sleep/1000000, "s is limit\n");

sub dl {
    my $req;
    my $res;
    my $ua;
    my $site;
    my $dl_content;
    
    $ua = LWP::UserAgent->new;
    $ua->agent($LWP_useragent);
    $req = HTTP::Request->new(GET => $_[0]);
    $res = $ua->request($req);
    if ($res->is_success) {
        if ($res->content =~ m/captcha/i) {
            return undef;
        } else {
            return 1;
        }
    }else {
       return undef();
       exit;
    }
}
