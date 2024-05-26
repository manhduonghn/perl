#!/usr/bin/perl
package apkpure;

use strict;
use warnings;
use JSON;
use Env;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Headers;
use Exporter 'import';
use Log4perl;
use FindBin;
use File::Spec;

our @EXPORT_OK = qw(apkpure);

my $logger = Log4perl::$logger;

sub req {
    my ($url, $output) = @_;
    $output ||= '-';

    my $ua = LWP::UserAgent->new(
        agent => 'Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0',
        timeout => 30,
    );

    my $headers = HTTP::Headers->new(
        'Content-Type' => 'application/octet-stream',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Connection' => 'keep-alive',
        'Upgrade-Insecure-Requests' => '1',
        'Cache-Control' => 'max-age=0',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8'
    );

    my $request = HTTP::Request->new(GET => $url, $headers);
    my $response = $ua->request($request);

    if ($response->is_success) {
        my $size = length($response->decoded_content);
        my $final_url = $response->base; # Lấy URL phản hồi cuối cùng
        if ($output ne '-') {
            open(my $fh, '>', $output) or do {
                $logger->error("Could not open file '$output': $!");
                die "Could not open file '$output': $!";
            };
            print $fh $response->decoded_content;
            close($fh);
            $logger->info("URL:$final_url [$size/$size] -> \"$output\" [1]");
        } else {
            $logger->info("URL:$final_url [$size/$size] -> \"-\" [1]");
        }
        return $response->decoded_content;
    } else {
        $logger->error("HTTP GET error: " . $response->status_line);
        die "HTTP GET error: " . $response->status_line;
    }
}

sub get_supported_version {
    my $pkg_name = shift;
    return unless defined $pkg_name;
    my $filename = 'patches.json';

    open(my $fh, '<', $filename) or do {
        $logger->error("Could not open file '$filename': $!");
        die "Could not open file '$filename': $!";
    };
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
    return $version;
}

sub apkpure {
    my ($name, $package) = @_;

    my $version = $ENV{VERSION};

    if (!$version) {
        if (my $supported_version = get_supported_version($package)) {
            $version = $supported_version;
            $ENV{VERSION} = $version;
        } else {
            my $page = "https://apkpure.net/$name/$package/versions";
            my $page_content = req($page);
        
            my @lines = split /\n/, $page_content;

            for my $line (@lines) {
                if ($line =~ /"ver-top-down"(.*?)data-dt-version="(.*?)"/) {
                    $version = "$2";
                }
            $ENV{VERSION} = $version;
            }
        }
    }

    my $url = "https://apkpure.net/$name/$package/download/$version";
    my $download_page_content = req($url);

    my @lines = split /\n/, $download_page_content;

    my $download_url;
    for my $line (@lines) {
        if ($line =~ /.*href="(.*\/APK\/$package[^"]*)".*/) {
            $download_url = "$1";
            last;
        }
    }

    my $apk_filename = "$name-v$version.apk";
    req($download_url, $apk_filename);
}

1;
