package Log4perl;

use strict;
use warnings;
use Log::Log4perl;
use Log::Log4perl::Layout::PatternLayout;

our $VERSION = '1.00';

# Define a custom layout with colors
package CustomPatternLayout;
use base 'Log::Log4perl::Layout::PatternLayout';

sub render {
    my ($self, $message, $category, $priority, $caller_level) = @_;

    my $color = '';
    if ($priority eq 'DEBUG') {
        $color = "\e[1;34m";  # Blue
    } elsif ($priority eq 'INFO') {
        $color = "\e[1;32m";  # Green
    } elsif ($priority eq 'WARN') {
        $color = "\e[1;33m";  # Yellow
    } elsif ($priority eq 'ERROR') {
        $color = "\e[1;31m";  # Red
    } elsif ($priority eq 'FATAL') {
        $color = "\e[1;35m";  # Magenta
    }

    my $reset_color = "\e[0m";  # Reset color

    my $output = $self->SUPER::render($message, $category, $priority, $caller_level);
    return "$color$output$reset_color";
}

# Set up custom layout
my $layout = CustomPatternLayout->new('%d %p %m %n');

# Configure Log4perl
Log::Log4perl->init(\<<'LOGCONF');
log4perl.rootLogger=INFO, LOGFILE, Screen

log4perl.appender.LOGFILE=Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename=github_downloader.log
log4perl.appender.LOGFILE.mode=append
log4perl.appender.LOGFILE.layout=CustomPatternLayout
log4perl.appender.Screen=Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout=CustomPatternLayout
LOGCONF

# Get the logger
my $logger = Log::Log4perl->get_logger();

1;
