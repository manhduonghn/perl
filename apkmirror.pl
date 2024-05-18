#!/usr/bin/perl
use strict;
use warnings;
use File::Temp qw(tempfile);

sub req {
    my ($url, $output) = @_;
    my $headers = join(' ',
        '--header="User-Agent: Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0"',
        '--header="Content-Type: application/octet-stream"',
        '--header="Accept-Language: en-US,en;q=0.9"',
        '--header="Connection: keep-alive"',
        '--header="Upgrade-Insecure-Requests: 1"',
        '--header="Cache-Control: max-age=0"',
        '--header="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"'
    );

    my $command = "wget $headers --keep-session-cookies --timeout=30 -nv -O \"$output\" \"$url\"";
    system($command) == 0
        or die "Failed to execute $command: $?";
}

sub apkmirror {
    my $version = "19.11.43";  # Corrected missing semicolon
    my $url = "https://www.apkmirror.com/apk/google-inc/youtube/youtube-" . (join '-', split /\./, $version) . "-release";

    # Create a temporary file to store the output
    my ($fh, $tempfile) = tempfile();

    # Fetch the URL and store the output in the temporary file
    req($url, $tempfile);

    # Read the temporary file content
    open my $file, '<', $tempfile or die "Could not open file '$tempfile': $!";
    my $content = do { local $/; <$file> };
    close $file;
    
}

# Execute the apkmirror subroutine
apkmirror();
