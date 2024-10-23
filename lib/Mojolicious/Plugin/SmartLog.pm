package Mojolicious::Plugin::SmartLog;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Time::HiRes qw(time);

has level => undef;
has stderr => 0;

sub register ($self, $app, $conf) {
  # Note: logging to stdout/stderr will not get picked up by journald when run with hypnotoad
  # When using hypnotoad, you should log to a file and use journald to monitor the file
  $app->config->{log} ||= {};
  $self->stderr($ENV{MOJO_LOG_STDERR} || $conf->{stderr} || ($app->config->{log}{stderr} && $app->config->{log}{stderr} =~ /^\s*(1|y|yes|on|true)\s*$/i));
  $app->log->path($app->home->child('log', $app->mode . '.log')) if -d $app->home->child('log');
  $self->level($conf->{level} || $app->config->{log}{level});
  $app->log->level($self->level) if $self->level;
  $app->log->on(message => sub ($log, $level, @lines) {
    warn $log->format->(time, $level, @lines) ;
    # if ($log->path && $self->stderr) {
    #   warn ($conf->{log_time} || $app->config->{log}{log_time}) ? $log->format->(time, $level, @lines) : sprintf "[%s] %s\n", $level, join "\n", @lines;
    # }
    return if grep { /Error handling errors/ } @lines; # don't handle errors if there's an error handling errors
    return unless grep { /Raptor (Rainbow|Not Found) Shown/ } @lines; # only handle errors if there's a rainbow or not found shown
    # Handle raptor problems, such as sending a special alert or logging to a different file
    ...
  });
  $app->hook(before_render => sub ($c, $args) {
    return unless my $template = $args->{template};
    if ($template eq 'exception') { # Make sure we are rendering the exception template
      return unless my $e = $c->stash->{exception};
      return unless my $snapshot = $c->stash->{snapshot};
      $c->log->error(sprintf '[%s] [%s] Raptor Rainbow Shown: %s (%s#%s); (%d) %s', $args->{status}, $c->user||'-', $c->req->url, $snapshot->{controller}, $snapshot->{action}, $e->line->[0], $e);
    }
    elsif ($template eq 'not_found') { # Make sure we are rendering the not_found template
      $c->log->warn(sprintf '[%s] [%s] Raptor Not Found Shown: %s', $args->{status}, $c->user||'-', $c->req->url);
    }
  });
}

1;