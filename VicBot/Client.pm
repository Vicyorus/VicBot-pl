#!/usr/bin/perl
package VicBot::Client;
use warnings;
use strict;
use diagnostics;

#Useful to handle unicode input (json) and output (print)
binmode STDOUT, ":utf8";
use Encode;

#Modules used around the Client
use JSON;
use LWP::UserAgent;
use POSIX qw(strftime);
use Switch;
use FindBin;
use Data::Dumper;
use String::Escape qw(printable);

#Chat-related modules
use VicBot::API;

#Module-related variables
our $VERSION = 0.0.1;
our @ISA = qw();
our @EXPORT = qw();
our @EXPORT_OK = qw();

#This is used around the Client to keep the bot running
my $running = 1;

#Number of times the bot has made a request to the server
my $t = 0;


sub new{

  my $class = shift;
  my $self = {};

  #Initialize the information about the bot
  $self->{'username'} = shift;
  $self->{'password'} = shift;
  $self->{'wiki'} = shift;

  #Create a new API instance
  $self->{'api'} = VicBot::API->new($self->{'wiki'});

  #Login to the API
  $self->{'api'}->login( $self->{'username'}, $self->{'password'} );

  #Initialize information related to connections
  my %headers = (
    'agent' => 'vicyorus/vicbot v.0.0.2',
    'cookie_jar' => $self->{'api'}->{'cookies'},
    'timeout' => 20
  );

  $self->{'opener'} = LWP::UserAgent->new( %headers );

  #Set the settings hash
  $self->{'settings'} = wiki_info($self);

  $self->{'chat_url'} = "http://$self->{'settings'}{'host'}/socket.io/";

  $self->{'request_data'} = {
    'name'=> $self->{'username'},
    'key'=> $self->{'settings'}{'chatkey'},
    'roomId'=> $self->{'settings'}{'room'},
    'serverId'=> $self->{'settings'}{'server'},
    'EIO'=> 2,
    'transport'=> 'polling'
  };
  
  #Set the XHR key
  ($self->{'request_data'}{'sid'}, $self->{'interval'}) = set_sid($self);
  
  bless($self, $class);
  return $self;
}


sub get{
  my ($self) = @_;
  my $time = time;

  $self->{'request_data'}{'time_cachebuster'} = "$time-$t";

  my $uri = URI->new( $self->{'chat_url'} );
  $uri->query_form( $self->{'request_data'} );

  my $response = $self->{'opener'}->get($uri);

  print $response->status_line . "\n";
  if ( $response->is_success() ) {
    $t += 1;
    return $response->decoded_content();
  } else {
    warn "An error occurred: $@";
    exit(1)
  }
}


sub post{
  my ($self, $body) = @_;
  my $time = time;

  if ($body eq "2") {
    $body = int_to_encode(length $body) . $body;
  }
  
  # ERROR:
  # This, in theory, should print \00\01\ff2, which is defined as the "ping message",
  # however, it seems to be malformed in some way, which is the error I can't find.
  print printable($body) . "\n";
 
  # Set the time
  $self->{'request_data'}{'time_cachebuster'} = "$time-$t";

  my $uri = URI->new( $self->{'chat_url'} );
  $uri->query_form( $self->{'request_data'} );
  
  print Dumper($self->{'request_data'}) . "\n";
  my $response = $self->{'opener'}->post($uri, 'Content' => $body);

  print $response->status_line . "\n";
  if ( $response->is_success() ) {
    $t += 1;
    print $response->decoded_content() . "\n";
  } else {
    warn "An error occurred: $@";
    exit(1)
  }
}


sub wiki_info{
  my ($self) = @_;
  
  #No need for a URI since this is just used once and the parameters haven't changed
  my $url = "http://$self->{'wiki'}.wikia.com/wikia.php?controller=Chat&format=json";

  my $response = $self->{'opener'}->get($url);
  
  #Decodes and creates the 'settings' hash
  #This hash will be used to form the URL to make the actual connection to the chat
  my $data = decode_json( encode( "utf8", $response->decoded_content() ) );
  
  my $settings = {
    'chatkey' => $data->{'chatkey'},
    'server'=> $data->{'nodeInstance'},
    'host' => $data->{'nodeHostname'},
    'room' => $data->{'roomId'}
  };
  
  return $settings;
}


sub set_sid {

  my ($self) = @_;
  my $data = get($self);

  # Data has to match, otherwise something fucked up
  if ($data =~ s/({.*})//){
    $data = decode_json( encode( "utf8", $1 ) );
    return $data->{'sid'}, $data->{'pingInterval'} / 1000;
  }
}


sub run {
  my ($self) = @_;
  while (1){
    post($self, "2");
    #get($self);
    #sleep $self->{'interval'};
  }
}

sub int_to_encode {
  
  # This function returns a string starting with char 00, followed
  # by the encoded digits of the length of the message we're going to send,
  # and ending with char FF. Required because Wikia likes to fuck things up.
  # An example would be "\00\01\ff" for a message whose length is 1.
  
  my ($len) = @_;
  
  my $final = '';
  
  foreach my $num (split //, "$len"){
    $final .= chr($num);
  }
  
  return '\00'. $final . '\ff';
  
}


1;