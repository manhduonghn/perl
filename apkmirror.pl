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
    print "Executing command: $command\n";
    system($command) == 0
        or die "Failed to execute $command: $?";
}

# Function to filter lines based on pattern and buffer size
sub filter_lines {
    my ($pattern, $size, $buffer_ref) = @_;
    print "Filtering lines with pattern: $pattern\n";
    my @temp_buffer;
    for my $line (@$buffer_ref) {
        push @temp_buffer, $line;
        if ($line =~ /$pattern/) {
            # print "Pattern matched: $line\n";
            @$buffer_ref = @temp_buffer[-$size..-1] if @temp_buffer > $size;
            print "Buffer after filtering: ", join("", @$buffer_ref), "\n";
            return;
        }
    }
}

sub apkmirror {
    my $version = "19.11.43";  # Corrected missing semicolon
    my $url = "https://www.apkmirror.com/apk/google-inc/youtube/youtube-" . (join '-', split /\./, $version) . "-release";
    # print "URL: $url\n";

    # Create a temporary file to store the output
    my ($fh, $tempfile) = tempfile();
    # print "Temporary file created: $tempfile\n";

    # Fetch the URL and store the output in the temporary file
    req($url, $tempfile);

    # Read the temporary file content line by line
    open my $file, '<', $tempfile or die "Could not open file '$tempfile': $!";
    my @lines = <$file>;
    close $file;
    # print "File content read: ", join("", @lines), "\n";

    # Step 1: Filter by dpi
    filter_lines(qr/>\s*nodpi\s*</, 16, \@lines);

    # Step 2: Filter by arch
    filter_lines(qr/>\s*universal\s*</, 14, \@lines);

    # Step 3: Filter by APK
    filter_lines(qr/>\s*APK\s*</, 6, \@lines);

    # Extract the download page URL
    my $download_page_url;
    my $i = 0;
    for my $line (@lines) {
        if ($line =~ /.*href="(.*apk-[^"]*)".*/ && ++$i == 1) {
            $download_page_url = "https://www.apkmirror.com$1";
            print "Download page URL found: $download_page_url\n";
            last;
        }
    }

    # Check if the URL was found and print it
    if (defined $download_page_url) {
        print "Final download page URL: $download_page_url\n";
    } else {
        print "Download page URL not found.\n";
    }
}

# Execute the apkmirror subroutine
apkmirror();
