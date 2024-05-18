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

sub get_supported_version {
    my $pkg_name = shift;
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
    return $version;
}

sub apkpure {
    my ($name, $package) = @_;

    my ($fh, $tempfile) = tempfile();
    my $version;
    my $url = "https://apkpure.net/$name/$package/download/$version";

    if (my $supported_version = get_supported_version($package)) {
        $version = $supported_version;
    } else {
        req($url, $tempfile);

        open my $file_handle, '<', $tempfile or die "Could not open file '$tempfile': $!";
        my @lines = <$file_handle>;
        close $file_handle;

        my @version;
        my $i = 0;
        for my $line (@lines) {
            if ($line =~ /.*/data-dt-version="(.*?)"/ && ++$i == 1) {
                $version = $1;
                last;
            }
        }
       # unlink $tempfile;
    }
    
    req($url, $tempfile);

    open $fh, '<', $tempfile or die "Could not open file '$tempfile': $!";
    my @lines = <$fh>;
    close $fh;    
    
    my $final_url;
    my $i = 0;
    for my $line (@lines) {
        if ($line =~ /.*href="(.*\/APK\/$package[^"]*)".*/ && ++$i == 1) {
            $final_url = "$1";
            last;
        }
    }
    # unlink $tempfile;
    
    my $apk_filename = "$name-v$version.apk";
    req($final_url, $apk_filename);
}

apkpure('youtube-music', 'com.google.android.apps.youtube.music');
