#!/usr/bin/perl
package github_downloader;

use strict;
use warnings;
use JSON;
use Exporter 'import';
use LWP::UserAgent;
use HTTP::Request;
use Log::Log4perl;
use File::Spec;

# Export the download_resources function
our @EXPORT_OK = qw(download_resources);

# Construct the path to the configuration file
my $config_path = File::Spec->catfile('utils', 'log4perl.conf');

# Initialize Log::Log4perl using the external configuration file
Log::Log4perl->init($config_path);
my $logger = Log::Log4perl->get_logger();

# Subroutine to perform an HTTP GET request and handle the response
sub req {
    my ($url, $output) = @_;
    $output ||= '-';

    # Create a user agent object
    my $ua = LWP::UserAgent->new(
        agent => 'Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0',
        timeout => 30,
    );

    # Create an HTTP GET request
    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request);

    if ($response->is_success) {
        my $size = length($response->decoded_content);
        my $final_url = $response->base;
        if ($output ne '-') {
            open(my $fh, '>', $output) or do {
                $logger->error("Could not open file '$output': $!");
                die "Could not open file '$output': $!";
            };
            print $fh $response->decoded_content;
            close($fh);
            $logger->info("$URL:$final_url [$size/$size] -> \"$output\" [1]");
        } else {
            $logger->info("$URL:$final_url [$size/$size] -> \"-\" [1]");
        }
        return $response->decoded_content;
    } else {
        $logger->error("HTTP GET error: " . $response->status_line);
        die "HTTP GET error: " . $response->status_line;
    }
}

# Subroutine to download resources from specified GitHub repositories
sub download_resources {
    my @repos = qw(revanced-patches revanced-cli revanced-integrations);

    foreach my $repo (@repos) {
        my $github_api_url = "https://api.github.com/repos/inotia00/$repo/releases/latest";

        my $content = req($github_api_url);
        if ($@) {
            $logger->error("Failed to get release data for $repo: $@");
            next;
        }
        my $release_data = decode_json($content);
        if ($@) {
            $logger->error("Failed to parse JSON for $repo: $@");
            next;
        }

        for my $asset (@{$release_data->{assets}}) {
            my $asset_name = $asset->{name};

            # Skip files with .asc extension
            next if $asset_name =~ /\.asc$/;

            my $download_url = $asset->{browser_download_url};
            req($download_url, $asset_name);
            if ($@) {
                $logger->error("Failed to download $asset_name from $repo: $@");
            }
        }
    }
}

1;
