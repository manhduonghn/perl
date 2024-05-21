#!/usr/bin/perl
use strict;
use warnings;
use FindBin; 

use lib "$FindBin::Bin/utils";
use apkpure qw(apkpure);
use uptodown qw(uptodown);
use apkmirror qw(apkmirror);
use github_downloader qw(download_resources);

# Download Github releases assets 
download_resources();

# Apkmirror 
apkmirror(
    "google-inc", 
    "youtube", 
    "com.google.android.youtube"
);

apkmirror(
    "google-inc", 
    "youtube-music", 
    "com.google.android.apps.youtube.music", 
    "arm64-v8a"
);

# Apkpure 
apkpure(
    "youtube",
    "com.google.android.youtube"
);

apkpure(
    "youtube-music",
    "com.google.android.apps.youtube.music"
);

# Uptodown
uptodown(
    "youtube",
    "com.google.android.youtube"
);

uptodown(
    "youtube-music",
    "com.google.android.apps.youtube.music"
);
