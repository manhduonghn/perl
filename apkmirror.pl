#!/usr/bin/perl
use strict;
use warnings;
use JSON;
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

# Function to filter lines based on pattern and buffer size
sub filter_lines {
    my ($pattern, $size, $buffer_ref) = @_;
    my @temp_buffer;
    for my $line (@$buffer_ref) {
        push @temp_buffer, $line;
        if ($line =~ /$pattern/) {
            @$buffer_ref = @temp_buffer[-$size..-1] if @temp_buffer > $size;
            return;
        }
    }
}

sub get_supported_version {
    my $pkg_name = shift;
    my $filename = 'patches.json';
    
    open(my $fh, '<', $filename) or die "Could not open file '$filename' $!";
    local $/;  # Slurp mode
    my $json_text = <$fh>;
    close($fh);

    my $data = decode_json($json_text);
    
    # Initialize an empty set to hold versions
    my %versions;

    # Iterate over each patch in the JSON data
    foreach my $patch (@{$data}) {
        my $compatible_packages = $patch->{'compatiblePackages'};
    
        # Check if compatiblePackages is a non-empty list
        if ($compatible_packages && ref($compatible_packages) eq 'ARRAY') {
            # Iterate over each package in compatiblePackages
            foreach my $package (@$compatible_packages) {
                # Check if package name and versions list is not empty
                if (
                    $package->{'name'} eq $pkg_name &&
                    $package->{'versions'} && ref($package->{'versions'}) eq 'ARRAY' && @{$package->{'versions'}}
                ) {
                    # Add versions to the set
                    foreach my $version (@{$package->{'versions'}}) {
                        $versions{$version} = 1;
                    }
                }
            }
        }
    }

    # Sort versions in reverse order and get the latest version
    my $version = (sort {$b cmp $a} keys %versions)[0];

    return $version;
}

sub apkmirror {
    my ($org, $name, $package, $arch, $dpi) = @_;
    $dpi ||= 'nodpi';
    $arch ||= 'universal';

    # Create a temporary file to store the output
    my ($fh, $tempfile) = tempfile();

    my $version;

    if (my $supported_version = get_supported_version($package)) {
        $version = $supported_version;
    } else {
        my $page = "https://www.apkmirror.com/uploads/?appcategory=$name";
        req($page, $tempfile);

        # Read the temporary file content line by line
        open my $file_handle, '<', $tempfile or die "Could not open file '$tempfile': $!";
        my @lines = <$file_handle>;
        close $file_handle;

        my $count = 0;
        my @versions;
        for my $line (@lines) {
            if ($line =~ /fontBlack(.*?)>(.*?)<\/a>/) {
                my $version = $2;
                push @versions, $version if $count <= 20 && $line !~ /alpha|beta/i;
                $count++;
            }
        }

        @versions = map { s/^\D+//; $_ } @versions;
        @versions = sort { version->parse($b) <=> version->parse($a) } @versions;

        $version = $versions[0];

        unlink $tempfile;
    }

    my $url = "https://www.apkmirror.com/apk/$org/$name/$name-" . (join '-', split /\./, $version) . "-release";

    # Fetch the URL and store the output in the temporary file
    req($url, $tempfile);

    # Read the temporary file content line by line
    open $fh, '<', $tempfile or die "Could not open file '$tempfile': $!";
    my @lines = <$fh>;
    close $fh;

    # Step 1: Filter by dpi
    filter_lines(qr/>\s*$dpi\s*</, 16, \@lines);

    # Step 2: Filter by arch
    filter_lines(qr/>\s*$arch\s*</, 14, \@lines);

    # Step 3: Filter by APK
    filter_lines(qr/>\s*APK\s*</, 6, \@lines);

    # Extract the download page URL
    my $download_page_url;
    my $i = 0;
    for my $line (@lines) {
        if ($line =~ /.*href="(.*[^"]*)".*/ && ++$i == 1) {
            $download_page_url = "https://www.apkmirror.com$1";
            last;
        }
    }

    unlink $tempfile;
    
    # Fetch the download page and store the output in the temporary file
    req($download_page_url, $tempfile);

    # Read the temporary file content again
    open $fh, '<', $tempfile or die "Could not open file '$tempfile': $!";
    @lines = <$fh>;
    close $fh;

    # Extract final APK download URL from the content
    my $dl_apk_url;
    for my $line (@lines) {
        if ($line =~ /href="([^"]*key=[^"]*)"/) {
            $dl_apk_url = "https://www.apkmirror.com$1";
            last;
        }
    }

    unlink $tempfile;
    
    req($dl_apk_url, $tempfile);

    # Read the temporary file content again
    open $fh, '<', $tempfile or die "Could not open file '$tempfile': $!";
    @lines = <$fh>;
    close $fh;

    # Extract final APK download URL from the content
    my $final_url;
    for my $line (@lines) {
        if ($line =~ /href="([^"]*key=[^"]*)"/) {
            $final_url = "https://www.apkmirror.com$1";
            $final_url =~ s/amp;//g;
            last;
        }
    }

    unlink $tempfile;
    
    # Final download
    my $apk_filename = "$name-v$version.apk";
    req($final_url, $apk_filename);
}

# Execute the apkmirror subroutine
apkmirror('google-inc', 'youtube-music', 'com.google.android.apps.youtube.music', 'arm64-v8a');
