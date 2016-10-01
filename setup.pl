use strict;

use Data::Dumper;

#
# This is just for my dev box. This is not needed in 'production'.
#
use lib '/home/wolf/proj/Yote/FixedRecordStore/lib';
use lib '/home/wolf/proj/Yote/LockServer/lib';
use lib '/home/wolf/proj/Yote/YoteBase/lib';
use lib '/home/wolf/proj/Yote/ServerYote/lib';
use lib '/home/wolf/proj/EPUC/lib';

print STDERR Data::Dumper->Dump(["HI THERE SETUP"]);
