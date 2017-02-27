#!/usr/bin/perl -w


#use strict;
use warnings;
use Net::IP;
use Net::SCP;
use File::Remote;

my $server_ip ;
my $file ;
my $ssh ; 
my $test ;
my $mkdir ;
my $local_folder ;
my $remote_folder ;
my $local_file ; 
my $remote_file ;
my $remote ;


$server_ip	=	'x.x.x.x';
$file		=	'y.y.y.y';
$ssh  = "/usr/bin/ssh";
$test = "/usr/bin/test";
$mkdir = "/bin/mkdir";
$local_folder = "/tmp/LNS-routes";
$remote_folder = "/tmp/LNS-routes";
$local_file = $local_folder."/".$file;
$remote_file = $remote_folder."/".$file;
$remote = new File::Remote;	

my @tunIps = getTunIpsLinux();
my @ips = getIps(\@tunIps);
writeIps();
sendIps($server_ip);


sub writeIps {
	if ( ! -e $local_folder ){
		system $mkdir , "-p" , $local_folder
	}
	$remote->writefile($local_file, @ips);

}
sub sendIps {
	my ($server_ip) = @_;
	system $ssh, $server_ip, $test, "-e", $remote_folder;
	my $rc = $? >> 8;
	if ($rc) {
	    system $ssh, $server_ip, "/bin/mkdir", "-p", $remote_folder;
	}
	$scp = Net::SCP->new( { 
    		"host"=>$server_ip, 
    		"user"=>"root" 
	} );
	$scp->scp($local_file, $server_ip.":".$remote_file);
}
sub getTunIpsLinux {
        return `/sbin/ip route | grep tun`;
}
sub getIps {
        my ($tunIpsR) = @_;
        my @tunIps = @{$tunIpsR};
        my $ipaddress  ;
        my $subnet ;
        my $re='((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(?![\\d])';
        my $reRange='((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(?![\\d])(\\/)(\\d+)';
        my @Ips ;
        for(my $i=0;$i<scalar(@tunIps);$i++)
        {
                chomp($tunIps[$i]);
                if ( $tunIps[$i] =~  m/$re/is){
                        $ipaddress=$1;
                        push @Ips , "$ipaddress\n" ;
                }
                if ($tunIps[$i] =~  m/$reRange/is){
                        $ipaddress=$1;
                        $subnet=$3;
                        if ( ( $ipaddress ne "0.0.0.0") and
                                ( substr($ipaddress, 0, 2) ne "10") and (
                                ( substr($ipaddress, 0, 10) eq "94.141.209") ||
                                ( substr($ipaddress, 0, 10) eq "94.141.208") ))
                        {
                               push @Ips , "$ipaddress/$subnet\n" ;
                        }
                }
        }
        return map  { $_->[0] }
        sort { $a->[1] <=> $b->[1] }
        map  { [ $_, eval { Net::IP->new( $_ )->intip } ] }
        @Ips;
}

