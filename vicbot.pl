use strict;
no strict "subs";
use warnings;
use FindBin qw( $RealBin );
use lib $RealBin;
use VicBot::Client;

my $vicbot = new VicBot::Client(
    'username',
    'password',
    'community'
);

$vicbot->run();
