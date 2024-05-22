#!/usr/bin/perl
package apkmirror;

use strict;
use warnings;
use JSON;
use Env;
use Exporter 'import';

our @EXPORT_OK = qw(apkmirror);

sub req {
    my ($url, $output) = @_;
    $output ||= '-';
    my $headers = join(' ',
        '--header="User-Agent: Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0"',
        '--header="Content-Type: application/octet-stream"',
        '--header="Accept-Language: en-US,en;q=0.9"',
        '--header="Connection: keep-alive"',
        '--header="Upgrade-Insecure-Requests: 1"',
        '--header="Cache-Control: max-age=0"',
        '--header="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"'
    );

    my $command = "wget $headers --keep-session-cookies --timeout=30 -nv -O $output \"$url\"";
    print "Executing command: $command\n"; # Debugging statement
    my $content = `$command`;
    return $content;
}

sub filter_lines {
    my ($pattern, $buffer_ref) = @_;
    my @result_buffer = ();
    my $last_target_index = -1;
    my $index = 0;
    my $collecting = 0;
    my @temp_buffer = ();

    for my $line (@$buffer_ref) {
        if ($line =~ /<a\s+class="accent_color"/) {
            $last_target_index = $index;
            $collecting = 1;
            @temp_buffer = ();
        }

        if ($collecting) {
            push(@temp_buffer, $line);
        }

        if ($line =~ /$pattern/) {
            if ($last_target_index != -1 && $collecting) {
                push @result_buffer, @temp_buffer;
                $collecting = 0;
            }
        }

        $index++;
    }

    @$buffer_ref = @result_buffer; 
    print "Filtered lines with pattern '$pattern'. Resulting lines: ", scalar(@result_buffer), "\n"; # Debugging statement
}

sub get_supported_version {
    my $pkg_name = shift;
    return unless defined $pkg_name;
    my $filename = 'patches.json';
    
    open(my $fh, '<', $filename) or die "Could not open file '$filename' $!";
    local $/; 
    my $json_text = <$fh>;
    close($fh);

    my $data = decode_json($json_text);
    my %versions;

    foreach my $patch (@{$data}) {
        my $compatible_packages = $patch->{'compatiblePackages'};
    
        if ($compatible_packages && ref($compatible_packages) eq 'ARRAY') {
            foreach my $package (@$compatible_packages) {
                if (
                    $package->{'name'} eq $pkg_name &&
                    $package->{'versions'} && ref($package->{'versions'}) eq 'ARRAY' && @{$package->{'versions'}}
                ) {
                    foreach my $version (@{$package->{'versions'}}) {
                        $versions{$version} = 1;
                    }
                }
            }
        }
    }
    my $version = (sort {$b cmp $a} keys %versions)[0];
    print "Found supported version for package '$pkg_name': $version\n"; # Debugging statement
    return $version;
}

sub apkmirror {
    my ($org, $name, $package, $arch, $dpi) = @_;
    $dpi ||= 'nodpi';

    my $version = $ENV{VERSION};

    if (!$version) {
        if (my $supported_version = get_supported_version($package)) {
            $version = $supported_version;
            $ENV{VERSION} = $version;
        } else {
            my $page = "https://www.apkmirror.com/uploads/?appcategory=$name";
            my $page_content = req($page);
            print "Fetched APKMirror page content for $name\n"; # Debugging statement

            my @lines = split /\n/, $page_content;

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
            $ENV{VERSION} = $version;
            print "Determined latest version: $version\n"; # Debugging statement
        }
    }

    my $url = "https://www.apkmirror.com/apk/$org/$name/$name-" . (join '-', split /\./, $version) . "-release";
    print "Fetching APK page URL: $url\n"; # Debugging statement
    my $apk_page_content = req($url);

    my @lines = split /\n/, $apk_page_content;

    if (defined $dpi) {
        filter_lines(qr/>\s*$dpi\s*</, \@lines);
    }
    if (defined $arch) {
        filter_lines(qr/>\s*$arch\s*</, \@lines);
    }
    filter_lines(qr/>\s*APK\s*</, \@lines);

    my $download_page_url;
    for my $line (@lines) {
        if ($line =~ /.*href="(.*[^"]*\/)"/) {
            $download_page_url = "https://www.apkmirror.com$1";
            last;
        }
    }
    
    print "Found download page URL: $download_page_url\n"; # Debugging statement
    my $download_page_content = req($download_page_url);

    @lines = split /\n/, $download_page_content;

    my $dl_apk_url;
    for my $line (@lines) {
        if ($line =~ /href="(.*key=[^"]*)"/) {
            $dl_apk_url = "https://www.apkmirror.com$1";
            last;
        }
    }

    print "Found download APK URL: $dl_apk_url\n"; # Debugging statement
    my $dl_apk_content = req($dl_apk_url);

    @lines = split /\n/, $dl_apk_content;

    my $final_url;
    for my $line (@lines) {
        if ($line =~ /href="(.*key=[^"]*)"/) {
            $final_url = "https://www.apkmirror.com$1";
            $final_url =~ s/amp;//g;
            unless ($final_url =~ /&forcebaseapk$/) {
                $final_url .= '&forcebaseapk';
            }
            last;
        }
    }

    print "Final download URL: $final_url\n"; # Debugging statement
    my $apk_filename = "$name-v$version.apk";
    print "Downloading APK to file: $apk_filename\n"; # Debugging statement
    req($final_url, $apk_filename);
}

1;
