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

sub download_resources {
    my @repos = qw(revanced-patches revanced-cli revanced-integrations);

    foreach my $repo (@repos) {
        my $github_api_url = "https://api.github.com/repos/revanced/$repo/releases/latest";
        my ($fh, $tempfile) = tempfile();

        req($github_api_url, $tempfile);

        open my $json_fh, '<', $tempfile or die "Could not open temporary file: $!";
        my $content = do { local $/; <$json_fh> };
        close $json_fh;

        my $release_data = decode_json($content);
        for my $asset (@{$release_data->{assets}}) {
            my $asset_name = $asset->{name};
            
            # Skip files with .asc extension
            next if $asset_name =~ /\.asc$/;

            my $download_url = $asset->{browser_download_url};
            req($download_url, $asset_name);
        }

        unlink $tempfile; # Remove the temporary JSON file
    }
}

download_resources();

#!/usr/bin/perl
use strict;
use warnings;
use JSON;

# Function to get the latest supported version of a package
sub get_supported_version {
    my ($pkg_name, $json_text) = @_;
    my $package_name = shift or die "Usage: $0 <package>\n";
    my $json_text = do { local $/; <STDIN> };


    # Decode the JSON data
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
    my $latest_version = (sort {$b cmp $a} keys %versions)[0];

    return $latest_version;
}

my $latest_supported_version = get_supported_version('com.google.android.youtube', 'patches.json');
print "$latest_supported_version\n" if $latest_supported_version;
