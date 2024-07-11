#!/usr/bin/perl
use strict;
use warnings;
use FindBin; 
use Env;

use lib "$FindBin::Bin/utils";
use apkpure qw(apkpure);
use uptodown qw(uptodown);
use apkmirror qw(apkmirror);
use github_downloader qw(download_resources);

# Download Github releases assets 
download_resources("revanced");

uptodown(
    "youtube-music",
    "com.google.android.apps.youtube.music"
);
undef $ENV{VERSION};
