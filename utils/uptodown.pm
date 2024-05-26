#!/usr/bin/perl
package uptodown;

use strict;
use warnings;
use JSON;
use Env;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Headers;
use POSIX qw(strftime);
use Exporter 'import';
use Log::Log4perl;

our @EXPORT_OK = qw(uptodown);

# Initialize Log4perl
Log::Log4perl->init(\<<'LOGCONF');
log4perl.rootLogger = DEBUG, LOGFILE, SCREEN

log4perl.appender.LOGFILE = Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename = uptodown.log
log4perl.appender.LOGFILE.mode = append
log4perl.appender.LOGFILE.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.LOGFILE.layout.ConversionPattern = %d %p %m %n

log4perl.appender.SCREEN = Log::Log4perl::Appender::Screen
log4perl.appender.SCREEN.stderr = 1
log4perl.appender.SCREEN.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.SCREEN.layout.ConversionPattern = %d %p %m %n
LOGCONF

# Get the logger
my $logger = Log::Log4perl->get_logger();

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

    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
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
            $logger->info("$timestamp URL:$final_url [$size/$size] -> \"$output\" [1]");
        } else {
            $logger->info("$timestamp URL:$final_url [$size/$size] -> \"-\" [1]");
        }
        return $response->decoded_content;
    } else {
        $logger->error("HTTP GET error: " . $response->status_line);
        die "HTTP GET error: " . $response->status_line;
    }
}

sub filter_lines {
    my ($pattern, $buffer_ref) = @_;
    my @result_buffer = ();
    my $last_target_index = -1;
    my $index = 0;
    my $collecting = 0;
    my @temp_buffer = ();

    for my $line (@$buffer_ref) {
        if ($line =~ /<div\s+data-url/) {
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

sub uptodown {
    my ($name, $package) = @_;

    my $version = $ENV{VERSION};

    if (!$version) {
        if (my $supported_version = get_supported_version($package)) {
            $version = $supported_version;
            $ENV{VERSION} = $version;
        } else {
            my $page = "https://$name.en.uptodown.com/android/versions";
            my $page_content = eval { req($page) };
            if ($@) {
                $logger->error("Failed to get page content: $@");
                die "Failed to get page content: $@";
            }

            my @lines = split /\n/, $page_content;

            for my $line (@lines) {
                if ($line =~ /.*class="version">(.*?)<\/div>/) {
                    $version = "$1";
                    last;
                }
            }
            $ENV{VERSION} = $version;
        }
    }

    my $url = "https://$name.en.uptodown.com/android/versions";
    my $download_page_content = eval { req($url) };
    if ($@) {
        $logger->error("Failed to get download page content: $@");
        die "Failed to get download page content: $@";
    }

    my @lines = split /\n/, $download_page_content;

    filter_lines(qr/>\s*$version\s*<\/span>/, \@lines);
