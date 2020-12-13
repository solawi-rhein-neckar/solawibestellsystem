#!/usr/bin/perl
use strict;
use warnings;

#
# This is a minimal bridge between a javascript REST Client and a Wordpress Database
#
# https://www.perlmonks.org/?node_id=944272
#

use CGI::Simple; # https://metacpan.org/pod/CGI::Simple  -  http header output and parsing
use CGI::Simple::Cookie;
use DBI;         # https://metacpan.org/pod/DBI          -  connect to sql database
use JSON;        # https://metacpan.org/pod/JSON         -  convert objects to json and vice versa
use Time::Local;
use POSIX qw(strftime);
use Encode;

use CGI::Carp qw(warningsToBrowser fatalsToBrowser); # use only while debugging!!: displays (non-syntax) errors and warning in html

use Authen::Passphrase::PHPass;

my $q = CGI::Simple->new;

# get database handle
my $dbh2 = DBI->connect("DBI:mysql:database=db208674_220;host=127.0.0.3", "db208674_220", "",  { RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => ($q->request_method() =~ /^POST$/) });
my $dbh = DBI->connect("DBI:mysql:database=db208674_361;host=127.0.0.3", "db208674_361", "",  { RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => ($q->request_method() =~ /^POST$/) });

if ( $q->request_method() =~ /^OPTIONS/ ) {
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Methods" => "POST, GET, OPTIONS, DELETE", "Access-Control-Allow-Headers" => "content-type,x-requested-with", "Access-Control-Allow-Credentials" => "true"});
}


# user wants to login?
if ( $q->request_method() =~ /^POST$/ && $q->path_info =~ /^\/login\/?/ ) {

	my $sessionid = rand();
	my $body = decode_json($q->param( 'POSTDATA' ));

	my $stl2 = $dbh2->prepare("SELECT * FROM `wp_users` WHERE `user_login` = ? OR `user_email` = ?");
	$stl2->execute($body->{name}, $body->{name});
	my $row2 = $stl2->fetchrow_hashref;

	if ($row2 && $row2->{user_pass}) {
		my $encPass = $row2->{user_pass};
		my $ppr = Authen::Passphrase::PHPass->from_crypt($encPass);

		if ($ppr->match(Encode::encode("utf-8",$body->{password}))) {
			my $stl = $dbh->prepare("UPDATE `Benutzer` SET `Cookie` = ? WHERE `wpID` = ? or `wpMitID` = ?");
			my $rows = $stl->execute($sessionid, $row2->{ID}, $row2->{ID});
			my $cookie = CGI::Simple::Cookie->new( -name=>'sessionid', -value=>$sessionid );

			# print http header with cookies
			print $q->header( {cookie => [$cookie], "content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"} );
			print encode_json({result => "success", match => $rows, user => $row2->{user_login}});
			$dbh->commit();
		} else {
			# print http header
			print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});
			print encode_json({result => "wrong pw", match => -1});
		}
	} else {
		# print http header
		print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});
		print encode_json({result => "wrong pw", match => -1});
	}

} elsif ($q->path_info =~  /^[a-zA-Z0-9\/._ -]*$/) {
	# print http header
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});

	# user does not want to login -> check if logged in (sessionid cookie)
	my %cookies = CGI::Simple::Cookie->fetch;
	my $bc = $cookies{'sessionid'} ? $cookies{'sessionid'}->value : undef;
	my $stbc = $dbh->prepare("SELECT * FROM `Benutzer` WHERE `Cookie` = ?");
	$stbc->execute($bc);
	if ( my $user = $stbc->fetchrow_hashref ) { # is logged in: sessionid cookie verified
		if ($user->{Role_ID} >= 4 && $q->request_method() =~ /^GET$/ ) {

			if ( $q->path_info =~ /^\/syncUsers$/ ) {

				my $cols = ["Depot","first_name","last_name","role","session_tokens","Beruf","Beruf_10","Beruf_10_11","MitMitgliedvon","Mitarbeit-bei","Strasse","account_status","wp_user_level","description"];
				my $query = "";
				foreach my $col (@$cols) {
					$query = $query . ", MAX(IF(meta_key = '$col', meta_value, NULL)) AS `$col`";
				}
				$dbh2->prepare("CREATE OR REPLACE VIEW `PivotUsersView` AS SELECT wp_users.* $query FROM wp_users join wp_usermeta on wp_users.ID = wp_usermeta.user_id GROUP BY wp_users.id; ")->execute();


				$dbh2->prepare("DROP PROCEDURE IF EXISTS `PivotUsers`")->execute();
				$dbh2->prepare("CREATE PROCEDURE `PivotUsers`()
	READS SQL DATA
	SQL SECURITY INVOKER
	BEGIN
	SET SESSION group_concat_max_len = 32000;
	SET \@query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('MAX(IF(meta_key = ''', meta_key, ''', meta_value, NULL)) AS `', meta_key, '`' ))  FROM wp_usermeta ORDER BY meta_key);
	SET \@query = CONCAT('SELECT wp_users.*, ', \@query, ' FROM wp_users join wp_usermeta on wp_users.ID = wp_usermeta.user_id GROUP BY wp_users.id');
	PREPARE stt FROM \@query;
	EXECUTE stt;
	DEALLOCATE PREPARE stt;
	END")->execute();
				my $sth = $dbh2->prepare("CALL PivotUsers();");
				$sth->execute();
				if ($sth) {
					my $results = [];
					my $countUsr = 0;
					my $countMit = 0;
					my $countUsrX = 0;
					my $countMitX = 0;
					my $missingOther = [];
					my $missingMember = [];
					my $wrongDepot = [];
					my $wrongName = [];
					my $duplicated = [];
					while ( my $row = $sth->fetchrow_hashref ) {

						my $sthUsr = $dbh->prepare("UPDATE Benutzer SET wpID = ? WHERE wpID is null AND Name = ?");
						$sthUsr->execute($row->{ID}, $row->{display_name});
						$countUsr += $sthUsr->rows();
						$dbh->commit();

						my $sthMit = $dbh->prepare("UPDATE Benutzer SET wpMitID = ? WHERE wpMitID is null AND Name = ?");
						$sthMit->execute($row->{ID}, $row->{MitMitgliedvon});
						$countMit += $sthMit->rows();
						$dbh->commit();

						push(@$results, $row);
					}
					foreach my $row (@$results) {
						my $sthUsr = $dbh->prepare("UPDATE Benutzer SET wpID = ? WHERE wpID is null AND MitName = ?");
						$sthUsr->execute($row->{ID}, $row->{MitMitgliedvon});
						$countUsrX += $sthUsr->rows();
						$dbh->commit();

						my $sthMit = $dbh->prepare("UPDATE Benutzer SET wpMitID = ? WHERE wpMitID is null AND MitName = ?");
						$sthMit->execute($row->{ID}, $row->{display_name});
						$countMitX += $sthMit->rows();
						$dbh->commit();

					}

					foreach my $row (@$results) {
						my $sthUsr = $dbh->prepare("SELECT Benutzer.*, Depot.wpName as Depot FROM Benutzer JOIN Depot on Benutzer.Depot_ID = Depot.ID WHERE Benutzer.wpID = ? OR Benutzer.wpMitID = ?");
						$sthUsr->execute($row->{ID}, $row->{ID});
						my $rowCount = 0;
						while ( my $usr = $sthUsr->fetchrow_hashref ) {
							$rowCount = $rowCount + 1;
							if ($usr->{Depot} ne $row->{Depot} && (! ($row->{Depot} eq 'Hofteam' && $usr->{Depot} eq 'Selbstabholer')) ) {
								push(@$wrongDepot, {ID => $row->{ID}, name => $row->{display_name}, depot => $row->{Depot}, bestellDepot => $usr->{Depot}, bestellName => $usr->{Name}, bestellMitName => $usr->{MitName}});
							}
							if (uc($usr->{Name}) ne uc($row->{display_name}) && uc($usr->{MitName}) ne uc($row->{display_name})) {
								push(@$wrongName, {ID => $row->{ID}, name => $row->{display_name}, mitName=>$row->{MitMitgliedvon}, depot => $row->{Depot}, bestellName => $usr->{Name}, bestellMitName => $usr->{MitName}});
							}
						}
						if ($rowCount > 0) {
							if ($rowCount > 1) {
								push(@$duplicated, {ID => $row->{ID}, name => $row->{display_name}, depot => $row->{Depot}});
							}
						} elsif ($row->{role} eq "member") {
							push(@$missingMember, {ID => $row->{ID}, name => $row->{display_name}, mitName=>$row->{MitMitgliedvon}, depot => $row->{Depot}});
						} else {
							push(@$missingOther, {ID => $row->{ID}, name => $row->{display_name}, mitName=>$row->{MitMitgliedvon}, depot => $row->{Depot}});
						}
					}

					print encode_json({result => 1, reason => "sync successfull.", countUsr => $countUsr, countMit => $countMit, countUsrX => $countUsrX, countMitX => $countMitX, wrongDepot => $wrongDepot, wrongName => $wrongName, missingOther => $missingOther, missingMember => $missingMember, duplicated => $duplicated});
				} else {
					print encode_json({result => 0, reason => "unknown failure"});
				}

			} elsif ($q->path_info =~ /^\/$/ ) {
				my $sth = $dbh2->prepare("SELECT * FROM PivotUsersView");
				$sth->execute();
				#output query results
				if ($sth) {
					my $results = [];
					while ( my $row = $sth->fetchrow_hashref ) {
						if ($row->{user_password}) {
							$row->{user_password} = '***';
						}
						push(@$results, $row);
					}
					print encode_json($results);
				}
			} else {
				print encode_json({result => 0, reason => "unknown path or no access right " . $q->path_info});
				# string concat in perl: . (dot operator). Operator + would try to interpret as some number and calc math. sum
			}
		} elsif ($user->{Role_ID} >= 4 &&  $q->request_method() =~ /^POST$/ ) {
			my $cur_week = POSIX::strftime("%G.%V", gmtime time);
			my $body = decode_json($q->param( 'POSTDATA' ));
			my $sth;

			if ($user->{Role_ID} >= 4 &&  $q->path_info =~ /^\/user_meta\/([a-zA-Z0-9]+)$/ ) {  # ID supplied -> UPDATE
				my $id = $1;
				my $key; my $value; my $sql;
				$sth = $dbh->prepare("SELECT wpID FROM Benutzer WHERE ID = ?");
				$sth->execute($id);
				my $row = $sth && $sth->fetchrow_hashref;
				my $wpUser_id = $row && $row->{wpID};
				if ($wpUser_id) {
					while (($key, $value) = each (%$body)) {
						if ( $key =~ /^[a-zA-Z0-9_-]+$/ ) {
							eval {
								$sql = "UPDATE wp_usermeta SET meta_value = ? WHERE user_id = ? and meta_key = ?";
								$sth = $dbh2->prepare($sql);
								my $rows = $sth->execute($value, $wpUser_id, $key);
								if ($rows < 1) {
									$sql = "INSERT INTO wp_usermeta (meta_value, user_id, meta_key) VALUES (?, ?, ?)";
									$dbh2->prepare($sql);
									$sth->execute($value, $wpUser_id, $key);
								}
								$dbh2->commit();
								print encode_json({result => 1, type => "update", rows=>$rows, query => $sql, params => [$value,$wpUser_id,$key], user_id => $id});
							};
							if ($@) {
								print encode_json({result => 0, type => "update", reason => $@, query => $sql, params => [$value,$wpUser_id,$key], user_id => $id});
							}
						}
					}
				} else {
					print encode_json({result => 0, reason => "no wpID found for user", user_id => $id});
				}

			} else {
				print  encode_json({result => 0, reason => "unknown path " . $q->path_info});
			}

		} else {
			print encode_json({result => 0, reason => "supported request methods: GET, POST, DELETE. Wrong method or no access right."});
		}

	} else {
		print encode_json({result => 0, reason => "not authenticated, please login."});
	}

} else {
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});
	print encode_json({result => 0, reason => "path contains forbidden characters"});
}


# close database handle
$dbh->disconnect


