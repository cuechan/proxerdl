#proxerdl
Small tool for downloading an anime and manga from [proxer.me](http://proxer.me).

###Anime:

~~For Anime you need [youtube-dl](https://rg3.github.io/youtube-dl/) installed on your system.~~
Youtube-dl is not necessary anymore. 

###Manga

Mangas can be downloaded without additional software.

###Requrements and limitations

At the moment we only can download anime from proxerHD, clipfish and streamcloud for sure.
Maybe i'am going to add some other hosters. Not sure yet.

Perl is needed with following modules:
- [LWP](http://search.cpan.org/~ether/libwww-perl-6.15/lib/LWP.pm)
- [JSON](http://search.cpan.org/~makamaka/JSON-2.90/lib/JSON.pm)

It was only tested on Linux. Im not sure if it runs on Windows.
All in all this software is usable. But its still a bit buggy.

###Installation

You can simply run the installation script.
`./install.sh`
It just copies `proxer-dl` to `/usr/bin/` and make it executable.

###Usage
Type `proxer-dl --help`.

Take a look at [the LICENSE file](https://github.com/cuechan/proxerdl/blob/master/LICENSE) to see the license.
