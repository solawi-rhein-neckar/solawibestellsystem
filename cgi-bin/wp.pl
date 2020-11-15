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

	my $encPass = $row2->{user_pass};
	my $ppr = Authen::Passphrase::PHPass->from_crypt($encPass);

	if ($ppr->match($body->{password})) {
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

} elsif ( $q->path_info =~  /^[a-zA-Z0-9\/._ -]*$/) {
	# print http header
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});

	# user does not want to login -> check if logged in (sessionid cookie)
	my %cookies = CGI::Simple::Cookie->fetch;
	my $bc = $cookies{'sessionid'} ? $cookies{'sessionid'}->value : undef;
	my $stbc = $dbh->prepare("SELECT * FROM `Benutzer` WHERE `Cookie` = ?");
	$stbc->execute($bc);
	if ( my $user = $stbc->fetchrow_hashref ) { # is logged in: sessionid cookie verified

		if ( $q->path_info =~ /^\/syncUsers$/ ) {
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
					$sthUsr->execute($row->{ID}, $row->{first_name} . " " . $row->{last_name});
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
					$sthMit->execute($row->{ID}, $row->{first_name} . " " . $row->{last_name});
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
							push(@$wrongDepot, {ID => $row->{ID}, name => $row->{first_name} . " " . $row->{last_name}, depot => $row->{Depot}, bestellDepot => $usr->{Depot}, bestellName => $usr->{Name}, bestellMitName => $usr->{MitName}});
						}
						if (uc($usr->{Name}) ne uc($row->{first_name} . " " . $row->{last_name}) && uc($usr->{MitName}) ne uc($row->{first_name} . " " . $row->{last_name})) {
							push(@$wrongName, {ID => $row->{ID}, name => $row->{first_name} . " " . $row->{last_name}, mitName=>$row->{MitMitgliedvon}, depot => $row->{Depot}, bestellName => $usr->{Name}, bestellMitName => $usr->{MitName}});
						}
					}
					if ($rowCount > 0) {
						if ($rowCount > 1) {
							push(@$duplicated, {ID => $row->{ID}, name => $row->{first_name} . " " . $row->{last_name}, depot => $row->{Depot}});
						}
					} elsif ($row->{role} eq "member") {
						push(@$missingMember, {ID => $row->{ID}, name => $row->{first_name} . " " . $row->{last_name}, mitName=>$row->{MitMitgliedvon}, depot => $row->{Depot}});
					} else {
						push(@$missingOther, {ID => $row->{ID}, name => $row->{first_name} . " " . $row->{last_name}, mitName=>$row->{MitMitgliedvon}, depot => $row->{Depot}});
					}
				}

				print encode_json({result => 1, reason => "sync successfull.", countUsr => $countUsr, countMit => $countMit, countUsrX => $countUsrX, countMitX => $countMitX, wrongDepot => $wrongDepot, wrongName => $wrongName, missingOther => $missingOther, missingMember => $missingMember, duplicated => $duplicated});
			} else {
				print encode_json({result => 0, reason => "unknown failure"});
			}

		} elsif ( $q->request_method() =~ /^GET$/ ) {
			my $sth;
			if ( $q->path_info =~ /^\/([a-zA-Z]+)\/?(MY|OWN)?$/ ) {
				# regex matching with perl: will put capture group in implicit variables $1, $2, ...
				my $table = $1;
				my $myOwn = $2;

				if ( ($myOwn || $user->{Role_ID} <= 1) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ?");
					$sth->execute($user->{ID});
				} elsif ( ($myOwn || $user->{Role_ID} <= 1) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `Benutzer_ID` = ?");
					$sth->execute($user->{ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($user->{Depot_ID});
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table`");
					$sth->execute();
				}

			} else {

				print encode_json({result => 0, reason => "unknown path " . $q->path_info});
				# string concat in perl: . (dot operator). Operator + would try to interpret as some number and calc math. sum
			}

			#output query results
			if ($sth) {
				my $results = [];
				while ( my $row = $sth->fetchrow_hashref ) {
					if ($row->{Passwort}) {
						$row->{Passwort} = '***';
					}
					if ($row->{Cookie}) {
						$row->{Cookie} = '*****';
					}
					push(@$results, $row);
				}
				print encode_json($results);
			}

		} elsif ( $q->request_method() =~ /^POST$/ ) {
			my $cur_week = POSIX::strftime("%G.%V", gmtime time);
			my $body = decode_json($q->param( 'POSTDATA' ));
			my $sth;

			if ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9]+)$/ ) {  # ID supplied -> UPDATE
				my $table = $1;
				my $id = $2;

				my @keys = ();
				my @values = ();
				my $key;
				my $value;
				my $reason;
				while (($key, $value) = each (%$body)) {
					if ( $key =~ /^[a-zA-Z0-9_]+$/ && (! ($key =~ /^(ErstellZeitpunkt|AenderZeitpunkt|AenderBenutzer_ID)$/ )) ) {

						if ( $user->{Role_ID} <= 1 && ($key =~ /^Woche$/ || $key =~ /^StartWoche$/ || $key =~ /^EndWoche$/) && $value < $cur_week ) {
							$reason = "Woche muss in Zukunft liegen (>= $cur_week )!";
						} elsif ( ($key =~ /^Passwort$/) && length($value) < 4) {
							$reason = "password min length 4 chars";
						} elsif ( $user->{Role_ID} <= 1 && $table =~ /^Benutzer$/ &&  (! ($key =~ /^(Name|Passwort|Email|Depot_ID|)$/)) ) {
							$reason = "Benutzer darf nur eigenes Passwort und Depot aendern!";
						} else {
							push(@keys, "`$key` = ?");
							push(@values, $value);
						}
					}
				}
				push(@keys, "`AenderBenutzer_ID` = ?");
				push(@values, $user->{ID});
				push(@keys, "`AenderZeitpunkt` = NOW()");
				my $keys = join(",", @keys);
				push(@values, $id);
				my $sql;
				if ($reason) {
					print encode_json({result => 0, reason => $reason || ("no update right for role " . $user->{Role_ID} . " on table $table")});
				} elsif ( @keys.length > 0 && $user->{Role_ID} <= 1 && $table =~ /^Benutzer$/ ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `ID` = ?";
					push(@values, $user->{ID});
				} elsif ( @keys.length > 0 && $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ ) {
					push(@values, $user->{ID});
					push(@values, $cur_week);
					if (@keys.length == 3 && $keys[0] =~ /^`(EndWoche|Kommentar)` = .$/ && $keys[1] =~ /^`AenderBenutzer_ID` = .$/ && $keys[2] =~ /^`AenderZeitpunkt` = NOW..$/) {
						$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ? AND `EndWoche` >= ?";
					} else {
						$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
						push(@values, $cur_week);
					}
				} elsif ( @keys.length > 0 && $user->{Role_ID} <= 1 && $table =~ /.*Benutzer.*/ ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					push(@values, $user->{ID});
					push(@values, $cur_week);
				} elsif ( $user->{Role_ID} == 2 || ($user->{Role_ID} == 3 && $table =~ /.*Benutzer.*/) || ($user->{Role_ID} == 0 && ( ! ( $table =~ /.*Benutzer.*/) ))    ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ?";
				} else {
					print encode_json({result => 0, reason => $reason || ("no update right for role " . $user->{Role_ID} . " on table $table")});
				}
				if ($sql) {
					eval {
						$sth = $dbh->prepare($sql);
						$sth->execute(@values);
						$dbh->commit();
						print encode_json({result => 1, type => "update", query => $sql, params => [@values]});
					};
					if ($@) {
						print encode_json({result => 0, type => "update", reason => $@, query => $sql, params => [@values]});
					}
				}
			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/?$/ ) { # NO ID yet -> INSERT
				my $table = $1;
				if ( $user->{Role_ID} == 2
					|| ( $user->{Role_ID} == 3 && $table =~ /.*Benutzer.*/)
					|| ( $user->{Role_ID} == 0 && ( ! ( $table =~ /.*Benutzer.*/) )  )
					|| ( $user->{Role_ID} <= 1 && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) && $body->{Benutzer_ID} == $user->{ID} )  ) {

					my @keys = ();
					my @placeholders = ();
					my @values = ();
					my $key;
					my $value;
					my $reason;
					my $onDuplicateKeyUpdate;
					while (($key, $value) = each (%$body)) {
						if ( $key =~ /^[a-zA-Z0-9_]+$/ && (! ($key =~ /^(ErstellZeitpunkt|AenderZeitpunkt|AenderBenutzer_ID)$/ )) ) {
							if ( $key =~ /^onDuplicateKeyUpdate$/ ) {
								if ($value =~ /^[a-zA-Z0-9_]+$/) {
									$onDuplicateKeyUpdate = $value;
								}
							} elsif ( ($user->{Role_ID} == 1 || ($user->{Role_ID} == 0 && $table =~ /.*Benutzer.*/))
								 && ($key =~ /^Woche$/ || $key =~ /^StartWoche$/ || $key =~ /^EndWoche$/) && $value < $cur_week ) {
								$reason = "Woche muss in Zukunft liegen (>= $cur_week )!";
							} else {
								push(@keys, "`$key`");
								push(@values, $value);
								push(@placeholders, "?");
							}
						}
					}
					push(@keys, "`AenderBenutzer_ID`");
					push(@values, $user->{ID});
					push(@placeholders, "?");

					if ($reason) {
						print encode_json({result => 0, reason => $reason || ("no insert right for role " . $user->{Role_ID} . " on table $table")});
					} else {
						my $keys = join(",", @keys);
						my $placeholders = join(",", @placeholders);
						my $sql= "INSERT INTO `$table` ( $keys ) VALUES ( $placeholders )";
						if ( $onDuplicateKeyUpdate ) {
							$sql = $sql . " ON DUPLICATE KEY UPDATE `$onDuplicateKeyUpdate` = ? ";
							push(@values, $body->{$onDuplicateKeyUpdate});
						}
						eval {
							$sth = $dbh->prepare($sql);
							$sth->execute(@values);
							$dbh->commit();
							print encode_json({result => 1, type => "insert", query => $sql, params => [@values], id => $sth->{'mysql_insertid'}});
						};
						if ($@) {
							print encode_json({result => 0, type => "insert", reason => $@, query => $sql, params => [@values]});
						}
					}

				} else {
					print encode_json({result => 0, reason => "no insert right for role " . $user->{Role_ID} . " on table $table"});
				}
			} else {
				print  encode_json({result => 0, reason => "unknown path " . $q->path_info});
			}

		} else {
			print encode_json({result => 0, reason => "supported request methods: GET, POST, DELETE."});
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


