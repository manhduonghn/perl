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

# Apkmirror 
apkmirror(
    "google-inc", 
    "youtube", 
    "com.google.android.youtube"
);
undef $ENV{VERSION};

# $ENV{VERSION} = "6.51.52";
apkmirror(
    "google-inc", 
    "youtube-music", 
    "com.google.android.apps.youtube.music", 
    "arm64-v8a"
);
undef $ENV{VERSION};

$ENV{VERSION} = "457.1.0.45.109";
apkmirror(
    "facebook-2", 
    "messenger",
    "",
    "arm64-v8a"
);
undef $ENV{VERSION};

# Apkpure 
apkpure(
    "youtube"
);
undef $ENV{VERSION};

# $ENV{VERSION} = "6.51.52";
apkpure(
    "youtube-music"
);
undef $ENV{VERSION};

# Uptodown
uptodown(
    "youtube",
    "com.google.android.youtube"
);
undef $ENV{VERSION};

#$ENV{VERSION} = "6.51.52";
uptodown(
    "youtube-music"
);
undef $ENV{VERSION};
