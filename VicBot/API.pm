##############################################################################
##############################################################################

package VicBot::API;

use strict;
use warnings;
use diagnostics;

use LWP::UserAgent;
use URI;
use JSON;
use Encode;

sub new{
  my $class = shift;
  my $self = {};
  
  #Create the URI
  $self->{'wiki'} = shift;
  $self->{'uri'} = URI->new("http://$self->{'wiki'}.wikia.com/api.php");
  
  #Set variables related to the connection
  my %headers = (
    'agent' => 'vicyorus/vicbot v.0.1',
    'cookie_jar' => {},
    'timeout' => 60
  );
  
  # Create the requests handler
  $self->{'ua'} = LWP::UserAgent->new( %headers );
  
  #Set a copy of the cookies, extremely useful for later requests
  $self->{'cookies'} = $self->{'ua'}->cookie_jar();
  
  bless($self, $class);
  return $self;  
}


sub login{
  # login: Logs the given user to the MediaWiki API
  # params:
  # $user (string): The user name
  # $password (string): The user's password
  
  my ($self, $user, $password) = @_;
  
  # Set the 
  my $settings = {
    'action' => 'login',
    'lgname' => $user,
    'lgpassword' => $password,
    'format' => 'json'
  };
  
  $self->{'uri'}->query_form($settings);

  my $response = $self->{'ua'}->post($self->{'uri'});
  my $data = decode_json( encode( "utf8", $response->decoded_content() ) );
  
  # Get the login token
  $settings->{'lgtoken'} = $data->{'login'}{'token'};
  $self->{'uri'}->query_form($settings);
  
  $response = $self->{'ua'}->post($self->{'uri'});

  $data = decode_json($response->decoded_content());

  if ($data->{'login'}{'result'} eq 'Success') {
    print "Logged in to wiki!\n";
  } else {
    die "An error occurred: $data->{'login'}{'result'}\n";
  }

}

sub logout{
}

sub tokens{
}

sub raw_page{
}

sub save_page{
}

1;
