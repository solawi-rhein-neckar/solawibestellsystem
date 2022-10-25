#!/usr/bin/perl
use strict;
use warnings;

use LWP::UserAgent;
use CGI::Simple; # https://metacpan.org/pod/CGI::Simple  -  http header output and parsing
use CGI::Simple::Cookie;
use DBI;         # https://metacpan.org/pod/DBI          -  connect to sql database
use JSON;        # https://metacpan.org/pod/JSON         -  convert objects to json and vice versa

use CGI::Carp qw(warningsToBrowser fatalsToBrowser); # use only while debugging!!: displays (non-syntax) errors and warning in html


my $q = CGI::Simple->new;

# get database handle
my $dbh = DBI->connect("DBI:mysql:database=db208674_361;host=mysql", "db208674_361", "",  { RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => 1 });

if ( $q->request_method() =~ /^OPTIONS/ ) {
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "https://www.solawi-rhein-neckar.org" : "null", "Access-Control-Allow-Methods" => "POST, GET, OPTIONS, DELETE", "Access-Control-Allow-Headers" => "content-type,x-requested-with", "Access-Control-Allow-Credentials" => "true"});
}


# user wants to login?
if ( $q->request_method() =~ /^POST$/ ) {

	my $sessionid = rand();
	my $body = decode_json($q->param( 'POSTDATA' ));

	my $ua = LWP::UserAgent->new();
	$ua->cookie_jar({ });
	my $response = $ua->get( 'https://www.solawi-rhein-neckar.org/intern/login');
	my $nonce;
	if ($response->content =~ /_wpnonce[^>]*value=\"([^\"]*)\"/) {
		$nonce = $1;
	}

	push @{ $ua->requests_redirectable }, 'POST';
	$response = $ua->post( 'https://www.solawi-rhein-neckar.org/intern/login/?redirect_to=https://www.solawi-rhein-neckar.org/intern/account', { 'username-73'=> $body->{name}, 'user_password-73' => $body->{password}, 'form_id' => 73, 'timestamp' => time(), '_wpnonce' => $nonce, 'redirect_to' => 'https://www.solawi-rhein-neckar.org/intern/account' } );
	my $first;
	if ($response->content =~ /first_name[^>]*value=\"([^\"]*)\"/) {
		$first = $1;
	}
	my $last;
	if ($response->content =~ /last_name[^>]*value=\"([^\"]*)\"/) {
		$last = $1;
	}
	my $user;
	if ($response->content =~ /user_login[^>]*value=\"([^\"]*)\"/) {
		$user = $1;
	}
    my $rows = -1;
	if ($user && ($first || $last)) {
		my $stl = $dbh->prepare("UPDATE `Benutzer` SET `Cookie` = ? WHERE (Name is not null and TRIM(Name) <> '' AND Name = ?) OR (MitName is not null AND TRIM(MitName) <> '' AND MitName = ?)");
		$rows = $stl->execute($sessionid, $first . ' ' . $last, $first . ' ' . $last);
#		my $stl = $dbh->prepare("INSERT INTO `Benutzer` (`Name`, `Cookie`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `Cookie` = ?");
#		$stl->execute($first . ' ' . $last, $sessionid, $sessionid);
	}
	my $cookie = CGI::Simple::Cookie->new( -name=>'sessionid', -value=>$sessionid );

	# print http header with cookies
	print $q->header( {cookie => [$cookie], "content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "https://www.solawi-rhein-neckar.org" : "null", "Access-Control-Allow-Credentials" => "true"} );
	print encode_json({result => $response->status_line, match => $rows, first => $first, last => $last, user => $user, nonce => $nonce,
		#text => $response->content,
	location => $response->header('Location') || '-', time => time()});
	$dbh->commit();

}
