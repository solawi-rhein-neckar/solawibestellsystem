#!/usr/bin/perl
use strict;
use warnings;

#
# This is a minimal bridge between a javascript REST Client and a MySQL Database
#
# Features:
#
# Login: Expects table with name "Benutzer" and columns "ID", "Name", "Passwort", "Cookie" and Role_ID
# -- POST resql.pl/login
#   body {name: 'Admin', password: 'Qwerty123'}  # sic! table-column german, json englisch, because Table-Column-Names will be visible in Frontend, json will not
#
# --> will set a random sessionid cookie and write its value into Benutzer.Cookie column
#
# Basic access control:
#
# Users with Benutzer.Role_ID != 2 can read all Tables that have NOT 'Benutzer' in their name.
# They can read and update/insert rows of tables with 'Benutzer' in their name,
# if the row has a column 'Benutzer_ID' with value of the logged in users Benutzer.ID
#
# Users with Benutzer.Role_ID == 2 can do everything.
#
#
# - Query with
# -- GET resql.pl/TableName
# -- GET resql.pl/TableName/$id  # expects column with name ID
# -- GET resql.pl/TableName/ColumnName/$COLUMN_VALUE  # characters allowed for value: a-zA-Z0-9._-
# -- GET resql.pl/TableName/MY  # translated to WHERE Benutzer_ID = $loggedInUsersId
#
# - Update with
# -- POST resql.pl/TableName/$id # expects column with name ID
#  body  {col1: value1, col2: value2, ...}
#
# - Insert with
# -- POST resql.pl/TableName
#  body  {col1: value1, col2: value2, ...}
#

use CGI::Simple; # https://metacpan.org/pod/CGI::Simple  -  http header output and parsing
use CGI::Simple::Cookie;
use DBI;         # https://metacpan.org/pod/DBI          -  connect to sql database
use JSON;        # https://metacpan.org/pod/JSON         -  convert objects to json and vice versa

use CGI::Carp qw(warningsToBrowser fatalsToBrowser); # use only while debugging!!: displays (non-syntax) errors and warning in html


my $q = CGI::Simple->new;

# get database handle
my $dbh = DBI->connect("DBI:mysql:d02dbcf8", "d02dbcf8", "",  { RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => 1 });

if ( $q->request_method() =~ /^OPTIONS/ ) {
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "solawi.fairtrademap.de" : "null", "Access-Control-Allow-Methods" => "POST, GET, OPTIONS, DELETE", "Access-Control-Allow-Headers" => "content-type,x-requested-with", "Access-Control-Allow-Credentials" => "true"});
}


# user wants to login?
if ( $q->request_method() =~ /^POST$/ && $q->path_info =~ /^\/login\/?/ ) {

	my $sessionid = rand();
	my $body = decode_json($q->param( 'POSTDATA' ));
	my $stl = $dbh->prepare("UPDATE `Benutzer` SET `Cookie` = ? WHERE `Name` = ? and `Passwort` = ?");
	$stl->execute($sessionid, $body->{name}, $body->{password});
	my $cookie = CGI::Simple::Cookie->new( -name=>'sessionid', -value=>$sessionid );

	# print http header with cookies
	print $q->header( {cookie => [$cookie], "content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"} );
	print encode_json({result => $stl->rows()});
	$dbh->commit();

} elsif ( $q->path_info =~  /^[a-zA-Z0-9\/._ -]*$/) {
	# print http header
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});

	# user does not want to login -> check if logged in (sessionid cookie)
	my %cookies = CGI::Simple::Cookie->fetch;
	my $bc = $cookies{'sessionid'} ? $cookies{'sessionid'}->value : undef;
	my $stbc = $dbh->prepare("SELECT * FROM `Benutzer` WHERE `Cookie` = ?");
	$stbc->execute($bc);
	if ( my $user = $stbc->fetchrow_hashref ) { # is logged in: sessionid cookie verified

		if ( $q->request_method() =~ /^GET$/ ) {

			my $sth;

			if ( $q->path_info =~ /^\/([a-zA-Z]+)\/?(MY|OWN)?$/ ) {
				# regex matching with perl: will put capture group in implicit variables $1, $2, ...
				my $table = $1;
				my $myOwn = $2;

				if ( ($myOwn || $user->{Role_ID} != 2) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ?");
					$sth->execute($user->{ID});
				} elsif ( ($myOwn || $user->{Role_ID} != 2) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `Benutzer_ID` = ?");
					$sth->execute($user->{ID});
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table`");
					$sth->execute();
				}

			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $id = $2;

				if ( $user->{Role_ID} != 2 && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ? AND `ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( $user->{Role_ID} != 2 && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $user->{ID});
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ?");
					$sth->execute($id);
				}

			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $column = $2;
				my $id = $3;

				if ( $user->{Role_ID} != 2 && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( $user->{Role_ID} != 2 && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $user->{ID});
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ?");
					$sth->execute($id);
				}

			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $column = $2;
				my $id = $column == 'Benutzer_ID' && $3 == 'MY' ? $user->{ID} : $3;
				my $column2 = $4;
				my $id2 = $5;

				if ( $user->{Role_ID} != 2 && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `ID` = ?");
					$sth->execute($id, $id2, $user->{ID});
				} elsif ( $user->{Role_ID} != 2 && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $user->{ID});
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ?");
					$sth->execute($id, $id2);
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
					if ( (((! ($table =~ /^Benutzer$/)) || $user->{Role_ID} == 2) && $key =~ /^[a-zA-Z0-9_]+$/)
						 || $key =~ /^(Name|Passwort|Email|Korb_ID|)$/ ) {
						if ( (!($key =~ /^Passwort$/)) || length($value) > 3) {
							push(@keys, "`$key` = ?");
							push(@values, $value);
						} else {
							$reason = "password min length 4 chars";
						}
					}
				}
				my $keys = join(",", @keys);
				push(@values, $id);
				my $sql;
				if ( @keys.length > 0 && $user->{Role_ID} == 1 && $table =~ /^Benutzer$/ ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `ID` = ?";
					push(@values, $user->{ID});
				} elsif ( @keys.length > 0 && $user->{Role_ID} == 1 && $table =~ /.*Benutzer.*/ ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ?";
					push(@values, $user->{ID});
				} elsif ( $user->{Role_ID} == 2 ) {
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
				if ( $user->{Role_ID} == 2 || ($user->{Role_ID} == 1 && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) && $body->{Benutzer_ID} == $user->{ID}) ) {

					my @keys = ();
					my @placeholders = ();
					my @values = ();
					my $key;
					my $value;
					while (($key, $value) = each (%$body)) {
						if ( $key =~ /^[a-zA-Z0-9_]+$/ ) {
							push(@keys, "`$key`");
							push(@values, $value);
							push(@placeholders, "?");
						}
					}

					my $keys = join(",", @keys);
					my $placeholders = join(",", @placeholders);
					my $sql= "INSERT INTO `$table` ( $keys ) VALUES ( $placeholders )";
					eval {
						$sth = $dbh->prepare($sql);
						$sth->execute(@values);
						$dbh->commit();
						print encode_json({result => 1, type => "insert", query => $sql, params => [@values]});
					};
					if ($@) {
						print encode_json({result => 0, type => "update", reason => $@, query => $sql, params => [@values]});
					}

				} else {
					print encode_json({result => 0, reason => "no insert right for role " . $user->{Role_ID} . " on table $table"});
				}
			} else {
				print  encode_json({result => 0, reason => "unknown path " . $q->path_info});
			}

		} elsif ( $q->request_method() =~ /^DELETE$/ ) {
			my $sql;
			my @values;
			if ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9]+)$/ ) {
				my $table = $1;
				my $id = $2;

				if ( $user->{Role_ID} != 2 && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					@values = ($id, $user->{ID});
					$sql = "DELETE FROM `$table` WHERE `ID` = ? AND `Benutzer_ID` = ?";
				} elsif ( $user->{Role_ID} == 2 ) {
					@values = ($id);
					$sql = "DELETE FROM `$table` WHERE `ID` = ?";
				} else {
					print encode_json({result => 0, reason => "no delete right for role " . $user->{Role_ID} . " on table $table"});
				}
			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $column = $2;
				my $id = $column == 'Benutzer_ID' && $3 == 'MY' ? $user->{ID} : $3;
				my $column2 = $4;
				my $id2 = $5;

				if ( $user->{Role_ID} != 2 && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ?";
					@values = ($id, $id2, $user->{ID});
				} else {
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ?";
					@values = ($id, $id2);
				}
			} else {
				print  encode_json({result => 0, reason => "unknown path " . $q->path_info});
			}
			if ($sql) {
				eval {
					my $sth = $dbh->prepare($sql);
					$sth->execute(@values);
					$dbh->commit();
					print encode_json({result => 1, type => "delete", query => $sql, params => [@values]});
				};
				if ($@) {
					print encode_json({result => 0, type => "delete", reason => $@, query => $sql, params => [@values]});
				}
			}
		} else {
			print encode_json({result => 0, reason => "supported request methods: GET, POST, DELETE."});
		}

	} else {
		print encode_json({result => 0, reason => "not authenticated, pleases login."});
	}

} else {
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});
	print encode_json({result v 0, reason => "path contains forbidden characters"});
}


# close database handle
$dbh->disconnect


