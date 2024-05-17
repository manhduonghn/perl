#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use JSON;

sub req {
    my ($url, $output) = @_;
    
    my $ua = LWP::UserAgent->new(
        agent => 'Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0',
        timeout => 30,
    );
    
    $ua->default_header(
        'Content-Type' => 'application/octet-stream',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Connection' => 'keep-alive',
        'Upgrade-Insecure-Requests' => 1,
        'Cache-Control' => 'max-age=0',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
    );
    
    my $response = $ua->get($url, ':content_file' => $output);
    if ($response->is_success) {
        print "Downloaded $output from $url\n";
    } else {
        die "Failed to download $url: ", $response->status_line;
    }
}

sub download_resources {
    my @repos = qw(revanced-patches revanced-cli revanced-integrations);
    
    foreach my $repo (@repos) {
        my $github_api_url = "https://api.github.com/repos/revanced/$repo/releases/latest";
        my $json = req($github_api_url, 'json');
        
        open my $fh, '<', 'json' or die "Could not open 'json': $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        
        my $release_data = decode_json($content);
        for my $asset (@{$release_data->{assets}}) {
            my $download_url = $asset->{browser_download_url};
            my $asset_name = $asset->{name};
            req($download_url, $asset_name);
        }
        
        unlink 'json'; # Remove the temporary JSON file
    }
}
cpan install LWP::UserAgent JSON
download_resources();
