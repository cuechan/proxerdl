proxerdl
========
Small tool for downloading manga from [proxer.me](http://proxer.me).

Anime
======
Anime support was removed.

Proxer's server are allways running at their limits. To support proxer and spare proxer's bandwidth i removed the support for anime.

Manga
=====
All manga can be downloaded unless the fsk18 stuff... (this is going to be fixed soon).

Future goals
============
- zip manga to handy package
- converting to epub
- running proxerdl as online service
- secure windows compability
- rewrite in C

Requirements and limitations
============================
Perl is needed with following modules:
- [LWP](http://search.cpan.org/~ether/libwww-perl-6.15/lib/LWP.pm)
- [JSON](http://search.cpan.org/~makamaka/JSON-2.90/lib/JSON.pm)
- [Math::Round](http://search.cpan.org/~grommel/Math-Round-0.06/Round.pm)
- [HTTP::Cookies](http://search.cpan.org/~gaas/HTTP-Cookies-6.01/lib/HTTP/Cookies.pm)
- [Term::ReadKey](http://search.cpan.org/~jstowe/TermReadKey-2.33/ReadKey.pm)

(Some of them are core-modules)

You can use `cpan install <modulename>` to install a module. 

It was tested on Linux.
It also runs on windows with [strawberry perl](http://strawberryperl.com/).
Please note that the windows cmd has no colorfull output. Instead you will see some strange numbers and letters...
Dont get distracted by that...

###Installation

You can simply run the installation script
`./install.sh`.
It just copies `proxer-dl` to `/usr/bin/` and make it executable.

###Usage
This is obsolete. Will be updated soon
===

    Usage: proxerdl --link or --id [options...] destination

    --id            The id of the anime or link.
    --lang          Language preferences as comma separated list: gersub,engdub,....
    --hoster        Hoster preferences as comma separated list: proxerhd,clipfish,streamcloud.
    
    --prefix        prefix for filename: '--prefix S01E' -> 'S01E001.mp4'. Use it with --no-dir to add a season to existing.
    
    --note          Add the Anime to your proxer watchlist.
    --list          List the structure of the anime. No Downloading.
    --no-dir        Do not create a directory for the Anime.
    --proxer        ...
    destination     Specify the destination for the download. By default its your current directory/<anime>/.

Take a look at [the LICENSE file](https://github.com/cuechan/proxerdl/blob/master/LICENSE) to see the license.
