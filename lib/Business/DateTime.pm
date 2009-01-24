package Business::DateTime;

use strict;
use warnings;
use base 'Class::Accessor';
use DateTime;
use Params::Validate;
use Carp;
use version;

our $VERSION = "0.0.4";

###########################################################################
# See POD for details
###########################################################################

sub new {
    my $class = shift;
    my ($arg_ref) = @_;

    Params::Validate::validate(
        @_,
        {   business_day_start_time => 1,
            business_day_end_time   => 1,
            business_days_of_week   => 1,
            holidays                => 0,
            start_date              => 0,
            formatter               => 0,
        }
    );

    # If no days of week are passed into business_day_of_week, croak
    croak 'no business_days_of_week specified'
        if not @{ $arg_ref->{business_days_of_week} };

    # TODO: Figure out a way to handle business start and end times
    #       that don't fall exactly on the hour. Ex: 8:30am

    # We don't expect the user to pass in start_date but they can.

    my $self = {
        business_day_start_time => $arg_ref->{business_day_start_time},
        business_day_end_time   => $arg_ref->{business_day_end_time},
        business_days_of_week   => $arg_ref->{business_days_of_week},
        holidays                => $arg_ref->{holidays},
        formatter               => $arg_ref->{formatter},
    };


    # Create accessors
    Business::DateTime->mk_ro_accessors(
        qw{ holidays
            business_days_of_week business_day_start_time
            business_day_end_time current_date }
    );

    Business::DateTime->mk_accessors(qw{ formatter });

    # Currently don't allow updates to holidays or business_days_of_week.
    # (and some other attributes of this object. look at mk_ro_accessors line)
    #
    # User must create a new object. The code below could be factored
    # out to allow for dymanic updates of these object attributes.
    #
    # TODO: Need a mechanism to update holidays and business_days_of_week
    #       after object has been created. Accessors exist but don't
    #       update our data structure. Accessors are read only for now.

    # Create an lookup structure of non-business days of week
    my %business_days_of_week
        = map { $_ => 1 } @{ $self->{business_days_of_week} };

    # Get all the non-business days.
    my @non_business_days
        = grep { not exists $business_days_of_week{$_} } ( 1 .. 7 );

    # Convert the array to a hash
    my %non_business_days = map { $_ => 1 } @non_business_days;

    # Store non business days of week
    $self->{_non_business_days_of_week} = \%non_business_days;

    # Create a lookup strucuture of holidays
    my %holidays = map { $_->strftime('%Y%m%d') => 1 } @{ $self->{holidays} };
    $self->{_holidays} = \%holidays;

    # Create object and handle inheritance properly.
    my $self_obj = bless $self, ref $class || $class;

    if ( defined $arg_ref->{start_date} ) {

        # If the user passed in a start_date, set it.
        $self_obj->start_date( $arg_ref->{start_date} );
    }

    return $self_obj;
}

##############################################################################
# Usage      : $self->_set_to_nearest_business_date_time();
# Purpose    : Update the current_date to the nearest business
#            :   date and time in the future within business hours.
# Parameters : None.
# Returns    : Nothing.
# Comments   : PRIVATE METHOD
##############################################################################

sub _set_to_nearest_business_date_time {
    my ($self) = @_;

    if ( $self->_is_non_business_day() ) {

        # current_date is not a business day.
        # Go to the nearest business day/hour in the future
        # Set the hour to the beginning of the business day
        # and add one day. The add_days method will make sure
        # we end up on a business day.
        # Reset minutes and seconds to 0.
        $self->current_date()->set_hour( $self->business_day_start_time() );
        $self->current_date()->set_minute(0);
        $self->current_date()->set_second(0);
        $self->add_days(1);
    }

    while ( $self->_is_non_business_hour() ) {

        # We are outside of business hours, but on a business day
        # Add an hour until we are at a business hour.
        # Reset minutes and seconds to 0
        $self->current_date()->set_minute(0);
        $self->current_date()->set_second(0);
        $self->add_hours(1);
    }

    return;
}

##############################################################################
# Usage      : $self->is_non_business_day();
# Purpose    : Determine if the current day is not a business day.
# Parameters : None.
# Returns    : 1 if yes, undef if no.
# Comments   : PRIVATE METHOD
##############################################################################

sub _is_non_business_day {
    my ($self) = @_;

    if (exists $self->{_non_business_days_of_week}
        ->{ $self->current_date()->day_of_week() }
        or exists $self->{_holidays}->{ $self->strftime('%Y%m%d') } )
    {

        # We are on a non-business day
        return 1;
    }

    return;
}

##############################################################################
# Usage      : $self->is_non_business_hour();
# Purpose    : Determine if the current hour is outside of business hours.
# Parameters : None.
# Returns    : 1 if yes, undef if no.
# Comments   : PRIVATE METHOD
##############################################################################

sub _is_non_business_hour {
    my ($self) = @_;

    if (   $self->current_date()->hour() < $self->business_day_start_time()
        or $self->current_date()->hour() > $self->business_day_end_time() )
    {

        # We are before or after business hours.
        return 1;
    }

    return;
}

###########################################################################
# See POD for details
###########################################################################

sub start_date {
    my ( $self, $start_date ) = @_;

    # TODO: Handle a start_date outside of business hours. Is this
    #       necessary?

    if ( defined $start_date ) {

        croak 'start_date is not a DateTime object'
            if not $start_date->isa('DateTime');

        # Make copies so the user cannot affect our object data.
        $self->{start_date} = $start_date->clone();

        # Update the current_date to the start_date.
        # current_date is a cursor to tell us where we are when performing
        # the date math and will hold the resulting datetime when we are done.
        $self->{current_date} = $start_date->clone();

        # Get the current_date to a business day within business hours.
        $self->_set_to_nearest_business_date_time();
    }

    return $self->{start_date};
}

###########################################################################
# See POD for details
###########################################################################

sub add {
    my $self = shift;
    my ($arg_ref) = @_;

    Params::Validate::validate(
        @_,
        {   days    => 0,
            hours   => 0,
            minutes => 0,
            seconds => 0,
        }
    );

    for my $unit ( keys %$arg_ref ) {

        my $method_name = q{add_} . $unit;

        # Add the specified number of units
        $self->$method_name( $arg_ref->{$unit} );
    }

    return $self->current_date()->clone();
}

###########################################################################
# See POD for details
###########################################################################

sub add_seconds {
    my ( $self, $seconds_to_add ) = @_;

    # Need a start date.
    croak 'start_date not defined' if not defined $self->start_date();

    # If we don't have any seconds to add, just return.
    return $self->current_date()->clone()
        if ( not defined $seconds_to_add or $seconds_to_add < 1 );

    # TODO: How do we handle partials? Don't for now:
    $seconds_to_add = int $seconds_to_add;

    # Determine if there are any minutes to add.
    # Don't want any partial minutes since those are seconds that we
    # will handle in this method.
    my $minutes_to_add = int $seconds_to_add / 60;

    if ( $minutes_to_add > 0 ) {

        # There are minutes to add, so add them.
        $self->add_minutes($minutes_to_add);

        # Determine the number of seconds left to add.
        $seconds_to_add = $seconds_to_add % 60;
    }

    # Add any seconds that remain
    $self->current_date()->add( seconds => $seconds_to_add );

    return $self->current_date()->clone();
}

###########################################################################
# See POD for details
###########################################################################

sub add_minutes {
    my ( $self, $minutes_to_add ) = @_;

    # Need a start date.
    croak 'start_date not defined' if not defined $self->start_date();

    # If we don't have any minutes to add, just return.
    return $self->current_date()->clone()
        if ( not defined $minutes_to_add or $minutes_to_add < 1 );

    # TODO: How do we handle partials? Don't for now:
    $minutes_to_add = int $minutes_to_add;

    # Determine if there are any hours we can add. Don't want partial
    # hours because those are minutes we should add in this method.
    my $hours_to_add = int $minutes_to_add / 60;

    if ( $hours_to_add > 0 ) {

        # There are hours to add, so add them.
        $self->add_hours($hours_to_add);

        # Determine how many more minutes we need to add.
        $minutes_to_add = $minutes_to_add % 60;
    }

    # Add any minutes.
    $self->current_date()->add( minutes => $minutes_to_add );

    return $self->current_date()->clone();
}

###########################################################################
# See POD for details
###########################################################################

sub add_hours {
    my ( $self, $hours_to_add ) = @_;

    # Need a start date. Must call object hash to prevent deep recursion.
    croak 'start_date not defined' if not defined $self->{start_date};

    # If we don't have any hours to add, just return.
    return $self->current_date()->clone()
        if ( not defined $hours_to_add or $hours_to_add < 1 );

    # TODO: How should we handle partial hours passed in. ex: 1.5
    # only handle whole integers for now.
    $hours_to_add = int $hours_to_add;

    my $current_hour      = $self->current_date()->hour();
    my $hours_left_in_day = $self->business_day_end_time() - $current_hour;

    my $day_length_in_hours
        = $self->business_day_end_time() - $self->business_day_start_time();

    # Are there any days we can add? Don't want partial days because
    # those are hours we should add in this method.
    my $days_to_add = int $hours_to_add / $day_length_in_hours;

    if ( $days_to_add > 0 ) {

        # There are days to add, so add them.
        $self->add_days($days_to_add);

        # Determine how many more hours we need to add.
        $hours_to_add = $hours_to_add % $day_length_in_hours;
    }

    # Add any remaining hours.

    while ( $hours_to_add > 0 ) {

        if ( $hours_to_add <= $hours_left_in_day ) {

            # There are enough hours in the day to add these.
            $self->current_date()->add( hours => $hours_to_add );

            if ( $self->current_date()->hour()
                == $self->business_day_end_time() )
            {

                # We are at the end of the business day.
                # Set us to the beginning of the next business day.
                $self->add_days(1);
                $self->current_date()
                    ->set_hour( $self->business_day_start_time() );
            }

            # Nore more hours to add. Could have also set $hours_to_add = 0
            return $self->current_date()->clone();
        }    # end of if
        else {

            # There aren't enough hours in the current day to add these
            # but the number of hours to add is less than one day.
            # Add them one hour at a time and if we fall outside
            # business hours, add a day and set the current hour to the
            # first hour of the next day and keep adding until we are out
            # of hours.
            while ($hours_to_add) {

                # Add an hour.
                $self->current_date()->add( hours => 1 );
                $hours_to_add--;

                if ( $self->current_date()->hour()
                    >= $self->business_day_end_time() )
                {

                    $self->add_days(1);
                    $self->current_date()
                        ->set_hour( $self->business_day_start_time() );
                }
            }

            # No more hours to add. Could remove this line.
            return $self->current_date()->clone();
        }    # End of else

    }    # end of while loop

    return $self->{current_date}->clone();
}

###########################################################################
# See POD for details
###########################################################################

sub add_days {
    my ( $self, $days_to_add ) = @_;

    # Need a start date.
    croak 'start_date not defined' if not defined $self->start_date();

    # If we don't have any days to add, just return.
    return $self->current_date()->clone()
        if ( not defined $days_to_add or $days_to_add < 1 );

    # TODO: Should we take partial days??
    # No for now:
    $days_to_add = int $days_to_add;

    while ( $days_to_add > 0 ) {

        # Add a day and see if we are on a non-business-day. If so, push
        # us to the next business day.
        $self->current_date()->add( days => 1 );
        $days_to_add--;

        while ( $self->_is_non_business_day() ) {

            # We are on a non-business-day, so push us along until we are
            # on a business day. Non-business days could be weekends or
            # holidays.
            $self->current_date()->add( days => 1 );
        }

    }

    # Return a new copy, not a reference to the copy in the object
    return $self->current_date()->clone();
}

###########################################################################
# See POD for details
###########################################################################

sub strftime {
    my ( $self, $format_string ) = @_;

    if ( not defined $format_string ) {

        # User did not pass a format string.
        if ( defined $self->formatter() ) {

            # We have a formatter defined so use it.
            $self->current_date()->set_formatter( $self->formatter() );
            return $self->current_date()->strftime();
        }
        else {

            # Use the default format string (for display)
            $format_string = '%m/%d/%Y %I:%M:%S%p';
        }
    }

    return $self->current_date()->strftime($format_string);
}

1;

=pod

=head1 NAME

Business::DateTime

=head1 DESCRIPTION

A module for business datetime addition.

=head1 SYNOPSIS

 # Create any holidays as DateTime objects.
 my $fake_holiday = DateTime->new(
     year      => 2008,
     month     => 3,
     day       => 6,
     time_zone => 'America/New_York',
 );

 # Create the BusinessDateTime object
 my $biz_datetime = Business::DateTime->new({
     business_day_start_time => 9,  # 24-hour time start of business day
     business_day_end_time   => 17, # 24-hour time end of business day
     business_days_of_week   => [qw( 1 2 3 4 5 )], # Business days of week
     holidays                => [ $fake_holiday ], # Arrayref of holidays
 });

 # Create the start_date
 my $start_date = DateTime->new(
     year      => 2008,
     month     => 3,
     day       => 2,
     hour      => 9,
     minute    => 0,
     second    => 0,
     time_zone => 'America/New_York',
 );

 # Set the start_date
 $biz_datetime->start_date($start_date);

 # Add 2 business days and 5 business hours.
 $biz_datetime->add({ 
     hours => 5,
     days  => 2,
 });

 # Display the current date in mm/dd/yyyy hh:mm:ssam/pm format
 print $biz_datetime->strftime();

=head1 METHODS

All 'add' methods MUST be given a positive value!

=head2 new()

 Usage      : $biz_datetime->new({..});
 Purpose    : Create a new BusinessDateTime object.
 Parameters : Hashref to pass in:
            :   business_day_start_time: 24-hour start of business day
                                         (required)

            :   business_day_end_time:   24-hour end of business day
                                         (required)

            :   business_days_of_week:   arrayref of business days of week.
                                         Must contain at least 1 day.
                                         1 = Monday ... 7 = Sunday
                                         (required)

            :   holidays:                arrayref of DateTime objects that
                                         represent holidays. (optional)

            :   start_date               a DateTime object as our starting
                                         point. (optional)
                                         If outside of business hours
                                         the date used will be the
                                         first hour of the next business
                                         day. BE SURE TO SET TIMEZONE IN
                                         DATETIME OBJECT IF NECESSARY.
          
            :   formatter                a DateTime::Format::* object/class
                                         (optional)

 Returns    : A new BusinessDateTime object.
 Throws     : Croaks when required or invalid params passed.

=head2 start_date()

 Usage      : $biz_datetime->start_date();
 Purpose    : Set the start_date
 Parameters : A DateTime object. (optional)
 Returns    : The start_date if set, otherwise undef.
 Throws     : Croaks when invalid params passed.
 Comments   : If the start_date is outside of business hours
            :   the date used will be the first hour of the
            :   next business day.
            : Setting the start_date will update the current_date
            :   also.
            : BE SURE TO SET TIMEZONE IN DATETIME OBJECT IF NECESSARY

=head2 business_day_start_time()

 Usage      : $biz_datetime->business_day_start_time();
 Purpose    : Get the start time of each business day.
 Parameters : None.
 Returns    : The start time of each business day.
 Comments   : Does not allow for setting! Must create a new object.

=head2 business_day_end_time()

 Usage      : $biz_datetime->business_day_end_time();
 Purpose    : Get the end time of each business day.
 Parameters : None.
 Returns    : The end time of each business day.
 Comments   : Does not allow for setting! Must create a new object.

=head2 current_date()

 Usage      : $biz_datetime->current_date();
 Purpose    : Get the current date and time.
 Parameters : None.
 Returns    : A DateTime object that represents the current position
            :   of the BusinessDateTime object.
 Comments   : Does not allow for setting!

=head2 holidays()

 Usage      : $biz_datetime->holidays();
 Purpose    : Get the list of holidays.
 Parameters : None.
 Returns    : An arrayref of DateTime objects.
 Comments   : Does not allow for setting! Must create a new object.

=head2 business_days_of_week()

 Usage      : $biz_datetime->business_days_of_week();
 Purpose    : Get the list of business days of the week.
 Parameters : None.
 Returns    : An arrayref of days of the week.
            :   1 = Monday .. 7 = Sunday
 Comments   : Does not allow for setting! Must create a new object.

=head2 formatter()

 Usage      : $biz_datetime->formatter();
 Purpose    : Get/set the formatter for this object.
 Parameters : None.
 Returns    : The DateTime::Format::.* object/class if set, otherwise undef.
 Comments   : Is eventually passed to the DateTime object when strftime()
            :   is called.

=head2 add()

 Usage      : $biz_datetime->add({..});
 Purpose    : Add business date/time units to the current date/time.
 Parameters : Hashref to pass in: (all are optional)
            :   days    => number od days to add,
            :   hours   => number of hours to add,
            :   minutes => number of minutes to add,
            :   seconds => number of seconds to add,
 Returns    : A DateTime object representing the resulting business
            :   date and time.

=head2 add_days()

 Usage      : $biz_datetime->add_days();
 Purpose    : Add business days to the current date/time.
 Parameters : An integer number of days.
 Returns    : A DateTime object representing the resulting business
            :   date and time.

=head2 add_hours()

 Usage      : $biz_datetime->add_hours();
 Purpose    : Add business hours to the current date/time.
 Parameters : An integer number of hours.
 Returns    : A DateTime object representing the resulting business
            :   date and time.

=head2 add_minutes()

 Usage      : $biz_datetime->add_minutes();
 Purpose    : Add business minutes to the current date/time.
 Parameters : An integer number of minutes.
 Returns    : A DateTime object representing the resulting business
            :   date and time.

=head2 add_seconds()

 Usage      : $biz_datetime->add_seconds();
 Purpose    : Add business seconds to the current date/time.
 Parameters : An integer number of seconds.
 Returns    : A DateTime object representing the resulting business
            :   date and time.

=head2 strftime()

 Usage      : $biz_datetime->strftime();
 Purpose    : Get the stringified date/time.
 Parameters : A formatting string. (optional)
            :   see strftime() Specifiers in perldoc DateTime
 Returns    : The DateTime as a string formatted using the formatting
            :   string.
            : If no formatting string is passed in, the DateTime string
            :   will be formatted using the formatter passed to the 
            :   constructor for formatter() method.
            : If no formatter has been specified either, the default
            :   formatting string will be applied which will display
            :   in the following format:
            :       mm/dd/yyyy hh:mm:ss[AM/PM]

=head1 AUTHOR

STOCKS (stocks@cpan.org)

=head1 DATE

2/28/2008

=cut
