#!/usr/bin/perl
use Log::Log4perl::Layout::PatternLayout;

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

# Assign layout to appenders
log4perl.appender.LOGFILE.layout=$layout
log4perl.appender.Screen.layout=$layout
