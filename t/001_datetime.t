#! /usr/local/bin/perl

use strict;
use warnings;

## Dump a hashref the was passed to die or croak
#use Data::Dumper;
#$SIG{__DIE__} = sub { warn Dumper (\$@); };

TestClass::Business::DateTime->runtests();
###########################################################################
package TestClass::Business::DateTime;

use strict;
use warnings;
use base qw(Test::Class);
use DateTime;
use Test::More;
use Test::Exception;

sub startup : Test( startup => 3 ) {
    my ($self) = @_;

    use_ok('Business::DateTime');

    my $fake_holiday = DateTime->new(
        year      => 2008,
        month     => 3,
        day       => 6,
        time_zone => 'America/New_York',
    );

    my $biz_datetime;
    lives_ok {
        $biz_datetime = Business::DateTime->new(
            {   business_day_start_time => 9,
                business_day_end_time   => 17,
                business_days_of_week   => [qw( 1 2 3 4 5 )],
                holidays                => [$fake_holiday],
            }
        );
    }
    'new Business::DateTime object created w/o start_date';

    my $start_date = DateTime->new(
        year      => 2008,
        month     => 2,
        day       => 25,
        hour      => 9,
        time_zone => 'America/New_York',
    );

    my $biz_datetime_start;
    lives_ok {
        $biz_datetime_start = Business::DateTime->new(
            {   business_day_start_time => 9,
                business_day_end_time   => 17,
                business_days_of_week   => [qw( 1 2 3 4 5 )],
                holidays                => [$fake_holiday],
                start_date              => $start_date,
            }
        );
    }
    'new Business::DateTime object created w/ start_date';

    $self->{biz_datetime}       = $biz_datetime;
    $self->{biz_datetime_start} = $biz_datetime_start;

    return;
}

sub start_date : Test(6) {
    my $self = shift;

    my $start_date = DateTime->new(
        year      => 2008,
        month     => 2,
        day       => 25,
        hour      => 9,
        time_zone => 'America/New_York',
    );

    $self->{biz_datetime}->start_date($start_date);

    is( $self->{biz_datetime}->start_date(),
        $start_date, 'start_date has been set correctly' );

    is( $self->{biz_datetime}->current_date(),
        $self->{biz_datetime}->start_date(),
        'current_date is the same as start_date when w/in business hours'
    );

    $start_date = DateTime->new(
        year      => 2008,
        month     => 2,
        day       => 25,
        hour      => 19,
        time_zone => 'America/New_York',
    );

    $self->{biz_datetime}->start_date($start_date);

    isnt(
        $self->{biz_datetime}->current_date(),
        $self->{biz_datetime}->start_date(),
        'current_date differs from start_date because start outside biz hrs'
    );

    ok( $self->{biz_datetime}->start_date()->strftime('%Y%m%d')
            < $self->{biz_datetime}->strftime('%Y%m%d'),
        'start_date is before current_date because start was outsize biz hrs'
    );

    is( $self->{biz_datetime}->strftime(),
        '02/26/2008 09:00:00AM',
        'current_date updated correctly because start outsize biz hrs'
    );

    $start_date = DateTime->new(
        year      => 2008,
        month     => 2,
        day       => 29,
        hour      => 19,
        time_zone => 'America/New_York',
    );

    $self->{biz_datetime}->start_date($start_date);

    is( $self->{biz_datetime}->strftime(),
        '03/03/2008 09:00:00AM',
        q{current_date updated correctly because start outsize biz hrs }
            . q{(over weekend)}
    );

    return;
}

sub add : Test(1) {
    my ($self) = @_;

    my $start_date = DateTime->new(
        year      => 2008,
        month     => 2,
        day       => 25,
        hour      => 9,
        time_zone => 'America/New_York',
    );

    $self->{biz_datetime}->start_date($start_date);

    $self->{biz_datetime}->add(
        {   hours   => 1,
            days    => 1,
            minutes => 5,
            seconds => 5,
        }
    );

    is( $self->{biz_datetime}->strftime(),
        '02/26/2008 10:05:05AM',
        'correctly added 1 day, 1 hour, 5 minutes, 5 seconds in business'
    );

    return;
}

sub add_days : Test(5) {
    my $self = shift;

    # start_date is a Monday.
    my $start_date = DateTime->new(
        year      => 2008,
        month     => 2,
        day       => 25,
        hour      => 9,
        time_zone => 'America/New_York',
    );

    lives_ok {
        $self->{biz_datetime}->add_days(0);
    }
    'able to pass 0 to add_days';

    lives_ok {
        $self->{biz_datetime}->add_days();
    }
    'able to pass no value to add_days';

    lives_ok {
        $self->{biz_datetime_start}->add_days(3);
    }
    'able to add days to a start_date passed into the constructor';

    $self->{biz_datetime}->start_date($start_date);

    $self->{biz_datetime}->add_days(1);

    # Make sure the end_date is a Tuesday since we only added one day.
    is( $self->{biz_datetime}->strftime(),
        '02/26/2008 09:00:00AM',
        'correctly added 1 business day'
    );

    $self->{biz_datetime}->add_days(7);

    is( $self->{biz_datetime}->strftime(),
        '03/07/2008 09:00:00AM',
        'correctly added 7 business days over a holiday'
    );

    return;
}

sub add_hours : Test(6) {
    my $self = shift;

    # start_date is a Monday.
    my $start_date = DateTime->new(
        year      => 2008,
        month     => 2,
        day       => 25,
        hour      => 9,
        time_zone => 'America/New_York',
    );

    lives_ok {
        $self->{biz_datetime}->add_hours(0);
    }
    'able to pass 0 to add_hours';

    lives_ok {
        $self->{biz_datetime}->add_hours();
    }
    'able to pass no value to add_hours';

    lives_ok {
        $self->{biz_datetime_start}->add_hours(3);
    }
    'able to add hours to a start_date passed into the constructor';

    $self->{biz_datetime}->start_date($start_date);

    # 3 days in hours
    $self->{biz_datetime}->add_hours(24);

    is( $self->{biz_datetime}->strftime(),
        '02/28/2008 09:00:00AM',
        'correctly added 24 business hours'
    );

    # Add 3 days in hours over a weekend
    $self->{biz_datetime}->add_hours(24);

    is( $self->{biz_datetime}->strftime(),
        '03/04/2008 09:00:00AM',
        'correctly added 24 business hours over a weekend'
    );

    # Add 1.5 days in hours
    $self->{biz_datetime}->add_hours(12);

    is( $self->{biz_datetime}->strftime(),
        '03/05/2008 01:00:00PM',
        'correctly added 12 business hours'
    );

    return;
}

sub add_minutes : Test(5) {
    my ($self) = shift;

    my $start_date = DateTime->new(
        year      => 2008,
        month     => 2,
        day       => 28,
        hour      => 9,
        time_zone => 'America/New_York',
    );

    lives_ok {
        $self->{biz_datetime}->add_minutes(0);
    }
    'able to pass 0 to add_minutes';

    lives_ok {
        $self->{biz_datetime}->add_minutes();
    }
    'able to pass no value to add_minutes';

    lives_ok {
        $self->{biz_datetime_start}->add_minutes(3);
    }
    'able to add minutes to a start_date passed into the constructor';

    $self->{biz_datetime}->start_date($start_date);

    # Add 8 hours in minutes. Should take us to 9am on the next day.
    $self->{biz_datetime}->add_minutes(480);

    is( $self->{biz_datetime}->strftime(),
        '02/29/2008 09:00:00AM',
        'correctly added 480 business minutes'
    );

    # Add 1.5 days in minutes over a weekend. Should take us to 1PM on the
    # next business day.
    $self->{biz_datetime}->add_minutes(720);

    is( $self->{biz_datetime}->strftime(),
        '03/03/2008 01:00:00PM',
        'correctly added 720 business minutes over a weekend'
    );

    return;
}

sub add_seconds : Test(5) {
    my ($self) = @_;

    my $start_date = DateTime->new(
        year      => 2008,
        month     => 2,
        day       => 28,
        hour      => 9,
        time_zone => 'America/New_York',
    );

    lives_ok {
        $self->{biz_datetime}->add_seconds(0);
    }
    'able to pass 0 to add_seconds';

    lives_ok {
        $self->{biz_datetime}->add_seconds();
    }
    'able to pass no value to add_seconds';

    lives_ok {
        $self->{biz_datetime_start}->add_seconds(3);
    }
    'able to add seconds to a start_date passed into the constructor';

    $self->{biz_datetime}->start_date($start_date);

    # Add 2.5 minutes in seconds
    $self->{biz_datetime}->add_seconds(150);

    is( $self->{biz_datetime}->strftime(),
        '02/28/2008 09:02:30AM',
        'correctly added 150 business seconds'
    );

    # Reset to the original start_date
    $self->{biz_datetime}->start_date($start_date);

    # Add 2.5 business days in seconds over a weekend
    $self->{biz_datetime}->add_seconds(72000);

    is( $self->{biz_datetime}->strftime(),
        '03/03/2008 01:00:00PM',
        'correctly added 86400 business seconds over a weekend'
    );

    return;
}

1;

=pod

=head1 NAME

TestClass::Business::DateTime

=head1 DESCRIPTION

Tests for TestClass::Business::DateTime module.

=head1 DATE

2/27/2008

=head1 AUTHOR

STOCKS (stocks@cpan.org)

=cut
