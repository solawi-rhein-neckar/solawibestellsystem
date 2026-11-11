/*
 * Anmeldung per Mail-Link über die Website (Webteam, 11.11.2026).
 *
 * Wer auf www.solawi-rhein-neckar.org/anmelden/ angemeldet ist, kommt ohne Passwort und ohne zweite Mail ins Bestellsystem:
 * POST /cgi-bin/wp.php/login/web übernimmt die Anmeldung der Website (cgi-bin/SolawiSitzung.pm). Jedes Gerät hat seine eigene
 * Sitzung. Abmelden meldet dieses Gerät im Bestellsystem und auf der Website ab.
 *
 * Eigene Anfrage statt postAjax: postAjax ruft den Rückruf nur bei Status 200 auf, hier muss es auch bei Fehlern weitergehen.
 */
var solawiAnmeldung = (function () {
	var MERKER = 'solawiAnmeldungUebernommen';

	function senden(pfad, fertig) {
		var xhr = new XMLHttpRequest();
		xhr.open('POST', 'https://' + (document.location.host || 'www.solawi-rhein-neckar.org') + pfad);
		xhr.withCredentials = true;
		xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
		xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
		xhr.onreadystatechange = function () {
			if (xhr.readyState !== 4) {
				return;
			}
			var ergebnis = null;
			try {
				ergebnis = JSON.parse(xhr.responseText);
			} catch (e) {
				ergebnis = null;
			}
			fertig(xhr.status === 200 ? ergebnis : null);
		};
		xhr.send('{}');
	}

	// Gerade erst übernommen und trotzdem nicht angemeldet? Dann nicht noch einmal neu laden (keine Schleife).
	function geradeErst() {
		try {
			return Date.now() - (Number(window.sessionStorage.getItem(MERKER)) || 0) < 30000;
		} catch (e) {
			return false;
		}
	}
	function merken() {
		try {
			window.sessionStorage.setItem(MERKER, String(Date.now()));
		} catch (e) {
			// ohne sessionStorage geht es auch
		}
	}

	function seite() {
		var name = (document.location.pathname.match(/([a-z0-9-]+\.htm)$/) || [])[1];
		return 'bestellung/' + (name || '');
	}

	return {
		// Nicht angemeldet: erst die Anmeldung der Website übernehmen, sonst sonst() aufrufen (Login-Formular zeigen)
		versuchen: function (sonst) {
			if (geradeErst()) {
				sonst();
				return;
			}
			senden('/cgi-bin/wp.php/login/web', function (r) {
				if (r && r.result === 'success') {
					merken();
					document.location.reload();
					return;
				}
				var hinweis = document.getElementById('anmeldungMehrdeutig');
				if (r && r.result === 'mehrdeutig' && hinweis) {
					hinweis.style.display = 'block';
				}
				sonst();
			});
		},

		// Anmeldeseite der Website; danach geht es auf diese Seite des Bestellsystems zurück
		link: function () {
			return '/anmelden/?ziel=' + seite();
		},

		// Abmelden auf diesem Gerät (Bestellsystem und Website), dann danach()
		abmelden: function (danach) {
			senden('/cgi-bin/wp.php/logout', function () {
				document.cookie = 'sessionid=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;'; // alte Sitzung aus dem Passwort-Login
				danach();
			});
		}
	};
})();
