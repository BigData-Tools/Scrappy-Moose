package Scrappy::Logger;

# load OO System
use Moose;

# load other libraries
use Carp;
use DateTime;
use DateTime::Format::SQLite;
use YAML::Syck;
$YAML::Syck::ImplicitTyping = 1;

has verbose => (is => 'rw', isa => 'Int', default => 0);

sub load {
    my $self = shift;
    my $file = shift;

    if ($file) {

        $self->{file} = $file;

        # load session file
        $self->{stash} = LoadFile($file)
          or croak("Log file $file does not exist or is not read/writable");
    }

    return $self->{stash};
}

sub timestamp {
    my $self = shift;
    my $date = shift;

    if ($date) {

        # $date =~ s/\_/ /g;
        return DateTime::Format::SQLite->parse_datetime($date)
          ;    # datetime object
    }
    else {
        $date =
          DateTime::Format::SQLite->format_datetime(DateTime->now);    # string

        # $date =~ s/ /_/g;
        return $date;
    }
}

sub info {
    return shift->event('info', @_);
}

sub warn {
    return shift->event('warn', @_);
}

sub error {
    return shift->event('error', @_);
}

sub event {
    my $self = shift;
    my $type = shift;
    my $note = shift;

    croak("Can't record an event without an event-type and notation")
      unless $type && $note;

    $self->{stash} = {} unless defined $self->{stash};

    $self->{stash}->{$type} = [] unless defined $self->{stash}->{$type};

    my $frame = $type eq 'info' || $type eq 'error' || $type eq 'warn' ? 1 : 0;
    my @trace = caller($frame);
    my $entry = scalar @{$self->{stash}->{$type}};
    my $time  = $self->timestamp;
    my $data  = {};
    $data = {
        '// package'  => $trace[0],
        '// filename' => $trace[1],
        '// line'     => $trace[2],
        '// occurred' => $time,
        '// notation' => $note,
      }
      if $self->verbose;

    $self->{stash}->{$type}->[$entry] = {eventlog => "[$time] [$type] $note"}
      unless defined $self->{stash}->{$type}->[$entry];

    $self->{stash}->{$type}->[$entry]->{metadata} = $data
      if scalar keys %{$data};

    if (@_ && $self->verbose) {
        my $stash = @_ > 1 ? {@_} : $_[0];
        if ($stash) {
            if (ref $stash eq 'HASH') {
                for (keys %{$stash}) {
                    $self->{stash}->{$type}->[$entry]->{metadata}->{$_} =
                      $stash->{$_};
                }
            }
        }
    }

    $self->write;
    return $self->{stash}->{$type}->[$entry];
}

sub write {
    my $self = shift;
    my $file = shift || $self->{file};

    $self->{file} = $file;

    if ($file) {

        # write session file
        DumpFile($file, $self->{stash})
          or
          croak("Session file $file does not exist or is not read/writable");
    }

    return $self->{stash};
}

1;
