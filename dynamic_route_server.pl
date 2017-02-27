#!/usr/bin/perl -w


use strict;
use warnings;
use Net::IP;

my $inter ;
my @LNSs ;
my $local_folder = "/tmp/LNS-routes";
my $mkdir = "/bin/mkdir";
if( scalar(@ARGV) > 1 ){
	$inter = $ARGV[0];
	@LNSs = @ARGV[1 .. $#ARGV];	
}
else{
    print "ERROR";
    exit();
}

if ( ! -e $local_folder ) {
        system $mkdir , "-p" , $local_folder
}

foreach my $LNS (@LNSs){
	my $LNS_file = $local_folder."/".$LNS ;
	if ( -e $LNS_file ) {
		my @routeIps =  getLNSIpsLinux($LNS,$inter);
		my @newIps = readFromFile($LNS_file);
		my @oldIps = getIps(\@routeIps);
		my @mustR = compareListIps(\@oldIps,\@newIps);
		my @mustA = compareListIps(\@newIps,\@oldIps);
		print "\nmust remove : ",  scalar (@mustR) , "\n" ;
		print @mustR  ;
		delRoute(\@mustR,$inter,$LNS) ;
		print "\nmust add : ", scalar (@mustA) , "\n" ;
		print @mustA ;
		addRoute(\@mustA,$inter,$LNS) ;
		
	}
}

sub getLNSIpsLinux {
	my ($LNS_ip ,$interface) = @_;
        return `/sbin/ip route | grep $LNS_ip | grep $interface`;
}
sub compareListIps {

	my ($ipsA ,$ipsB) = @_;
    my @ipsIn = @{$ipsA};
	my @ipsNotIn = @{$ipsB};
	return grep { ! ( $_ ~~ @ipsNotIn ) } @ipsIn;
}
sub addRoute {
	my ($ipsR , $interface , $ipaddress) = @_;
    my @ips = @{$ipsR};
	foreach my $ip (@ips){
		chomp ($ip) ;
		#print "ip route add $ip via $ipaddress dev $interface" ;
		`/sbin/ip route add $ip via $ipaddress dev $interface via $ipaddress 2>> $local_folder/errors-addRoute`;
	}	
}
sub delRoute {
    my ($ipsR , $interface , $ipaddress) = @_;
    my @ips = @{$ipsR};
    foreach my $ip (@ips){
		chomp ($ip) ;
        `/sbin/ip route del $ip via $ipaddress dev $interface via $ipaddress  2>> $local_folder/errors-delRoute`;
    }
}

sub getLocalIpsInt {
    my @argus = @_;
    my $interface = $argus[0];
	my $ipAddress = $argus[1];
	return `/sbin/ip route | grep $interface | grep $ipAddress`;
	 
}
sub getTunIpsLinux {
	my @argus = @_;
	my $hostIp = $argus[0];
	return `ssh root\@$hostIp "/sbin/ip route | grep tun"`;
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
                        if ( $ipaddress ne "0.0.0.0") {
                               push @Ips , "$ipaddress/$subnet\n" ;
                        }
                }
	}
	return map  { $_->[0] }
        sort { $a->[1] <=> $b->[1] }
        map  { [ $_, eval { Net::IP->new( $_ )->intip } ] }
        @Ips;
}
sub writeToFile{
	
	my ($ipsR , $filename) = @_;
	my @ips = @{$ipsR} ;
	open (my $fh, '>', $filename) or die ;
	my @sorted = map  { $_->[0] }
        	sort { $a->[1] <=> $b->[1] }
        	map  { [ $_, eval { Net::IP->new( $_ )->intip } ] }
        	@ips;
	print $fh @sorted ;
	close $fh;
	return "done\n";
}
sub readFromFile{
	my @argus = @_;
	my $filename = $argus[0];
	if ( ! -e $filename ) {
		open my $fh , '>>', $filename ;
		print $fh "" ; 		
	}
	open (my $fh, '<', $filename) or die ;
	return <$fh> ;
}
