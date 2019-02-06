#!/usr/bin/perl
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings FATAL => 'all';

use constant OK         => 0;
use constant WARNING    => 1;
use constant CRITICAL   => 2;
use constant UNKNOWN    => 3;

# Service state
use constant INACTIVE => 0;
use constant ACTIVE   => 1;

my $pkg_nagios_available = 0;
my $pkg_monitoring_available = 0;

BEGIN {
    eval {
        require Monitoring::Plugin;
        require Monitoring::Plugin::Functions;
        $pkg_monitoring_available = 1;
    };
    if (!$pkg_monitoring_available) {
        eval {
            require Nagios::Plugin;
            require Nagios::Plugin::Functions;
            *Monitoring::Plugin:: = *Nagios::Plugin::;
            $pkg_nagios_available = 1;
        };
    }
    if (!$pkg_monitoring_available && !$pkg_nagios_available) {
        print("UNKNOWN - Unable to find module Monitoring::Plugin or Nagios::Plugin\n");
        exit UNKNOWN;
    }
}

my $mp = Monitoring::Plugin->new(
    shortname => "check_pid",
    usage     => ""
);

$mp->add_arg(
    spec     => 'pid_file|f=s',
    help     => 'PID file to use',
    required => 1
);

$mp->add_arg(
    spec     => 'missing_file_ok',
    help     => 'Don\' warn if pid file is missing'
);

$mp->getopts;

if ( defined $mp->opts->pid_file && !-f $mp->opts->pid_file) {
    if ($mp->opts->missing_file_ok) {
        wrap_exit(
            OK,
            sprintf('Missing PID file \'%s\' ignored by request', $mp->opts->pid_file)
        );
    } else {
        wrap_exit(
            WARNING,
            sprintf('PID file \'%s\' missing', $mp->opts->pid_file)
        );
    }
}

my $cmd = 'pgrep ';

$cmd .= sprintf('--pidfile %s ', $mp->opts->pid_file);
$cmd .= '--list-name';

my $output = `$cmd 2>&1`;
# See: perldoc perlvar
my $rc = $? >> 8;

if ($rc == 0) {
    wrap_exit(
        OK,
        sprintf("Process running\n%s", $output),
    );
} elsif ($rc == 1) {
    wrap_exit(
        CRITICAL,
        sprintf("No process found\n%s", $output),
    );
} else {
    wrap_exit(
        UNKNOWN,
        sprintf("Return code %d. Please check your command\n%s", $rc, $output)
    );
}


sub wrap_exit
{
    if($pkg_monitoring_available == 1) {
        $mp->plugin_exit( @_ );
    } else {
        $mp->nagios_exit( @_ );
    }
}
