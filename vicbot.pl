use strict;
no strict "subs";
use warnings;

use Config::Simple;
use FindBin qw( $RealBin );

use lib $RealBin;
use VicBot::Client;

my $cfg = new Config::Simple('config.ini');

my $vicbot = new VicBot::Client(
    $cfg->param("user.name"),
    $cfg->param("user.password"),
    $cfg->param("user.wiki")
);

$vicbot->run();
