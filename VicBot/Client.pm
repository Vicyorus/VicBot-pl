##############################################################################
##############################################################################

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
use threads;

#Chat-related modules
use VicBot::API;

#Module-related variables
our $VERSION = 0.0.21;
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

  #Initialize the headers
  my %headers = (
    'agent' => 'vicyorus/vicbot v.0.0.2',
    'cookie_jar' => $self->{'api'}->{'cookies'},
    'timeout' => 20
  );
  
  # Create the requests opener
  $self->{'opener'} = LWP::UserAgent->new( %headers );

  #Set the settings hash
  $self->{'settings'} = wiki_info($self);

  # Create the chat url
  $self->{'chat_url'} = "http://$self->{'settings'}{'host'}/socket.io/";

  # Set the chat url's POST content
  $self->{'request_data'} = {
    'name'=> $self->{'username'},
    'key'=> $self->{'settings'}{'chatkey'},
    'roomId'=> $self->{'settings'}{'room'},
    'serverId'=> $self->{'settings'}{'server'},
    'EIO'=> 3,
    'transport'=> 'polling'
  };
  
  #Set the SID and the ping interval
  ($self->{'request_data'}{'sid'}, $self->{'interval'}) = set_sid($self);
  
  bless($self, $class);
  return $self;
  
}


sub get{
  # get: Makes a GET request to the chat server
  # params: None
  
  my ($self) = @_;
  
  # Get the current time, as the server asks for it
  my $time = time;

  # Create the 't' key, which is composed of the current time
  # plus the count of requests the bot has done
  $self->{'request_data'}{'time_cachebuster'} = "$time-$t";

  # TODO: Can we put this on the declaration of the chat url?
  my $uri = URI->new( $self->{'chat_url'} );
  $uri->query_form( $self->{'request_data'} );
  
  # Make the actual request
  my $response = $self->{'opener'}->get($uri);

  # Check if the request was successful, else report the error and exit
  if ( $response->is_success() ) {
  
    # Since the request is succesful, we increment the number of requests done
    $t += 1;
    return $response->decoded_content();
  
  } else {
    warn "An error occurred: $@";
    exit(1)
  }

}


sub post{
  # post: Makes a POST request to the chat server.
  # params:
  # $body (hash/string): The message to send to the server
  my ($self, $body) = @_;
  
  # Documented on the get subroutine 
  my $time = time;
  $self->{'request_data'}{'time_cachebuster'} = "$time-$t";
  
  
  $body = message_format($body);
  # Same TODO as in the get function
  my $uri = URI->new( $self->{'chat_url'} );
  $uri->query_form( $self->{'request_data'} );
  
  # Make the request
  my $response = $self->{'opener'}->post($uri, 'Content' => $body);

  # Check if the request was succesful
  if ( $response->is_success() ) {
    $t += 1;
    return $response->decoded_content();
    
  } else {
    warn "An error occurred: $@";
    exit(1);
  }
  
}


sub wiki_info{
  # wiki_info: Gets the information needed to connect to the chat server
  # params: None
  
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
  # set_sid: Gets the SID needed to connect to chat.
  # params: None
  
  my ($self) = @_;
  
  # GETting the chat server without the SID makes the server gives us the SID
  my $data = get($self);

  # Data has to match, otherwise something fucked up
  if ($data =~ s/({.*})//){
    $data = decode_json( encode( "utf8", $1 ) );
    
    # Return the SID and the ping interval
    return $data->{'sid'}, $data->{'pingInterval'} / 1000;
  }
  
}


sub run {
  # run: Initiates the main loop of the bot.
  # params: None
  
  my ($self) = @_;
  
  # We create the ping thread, which has to be running or we get disconnected
  my $ping_thr = threads->create('ping', $self);
  $ping_thr->detach();
  
  while (1){
    # At the moment it's doing nothing
    get($self);
  }
}


sub ping {
  # ping: Pings the chat to keep the connection alive
  # params: None
  
  my ($self) = @_;
  
  while (1) {
    post($self, "2");
    sleep $self->{'interval'};
  }

}

sub message_format {
  my ($message) = @_;
  return length($message). ":$message";
}

1;