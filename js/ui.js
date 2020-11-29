if (location.protocol && !location.protocol.match(/https/) && location.host.match(/solawi.fairtrademap.de/)) {
	location.replace('https://bestellung.solawi.fairtrademap.de' +  location.pathname);
} else if (location.protocol && !location.protocol.match(/https/) && location.host.match(/solawi-rhein-neckar.org/)) {
	location.replace('https://www.solawi-rhein-neckar.org' +  location.pathname);
}

var SBS = SolawiBestellSystem();

function initUser(initTablesFunction) {
	//check login status
	getAjax('Benutzer/OWN',
	        function(userResponse) {
	            if (userResponse.length > 0 && userResponse[0]) {
	                SBS.user = userResponse[0];
	                document.getElementById('logoutbtn').innerText = 'Logout ' + SBS.user.Name;
	                changeWeek(0);
	                if (SBS.user.Role_ID < 3) {
	                    setContent('warning',
	                            'Du bist als BENUTZER ANGEMELDET und siehst NUR DEINE BESTELLUNGEN / darfst nicht bearbeiten. Bitte abmelden (logout) und ALS ADMIN ANMELDEN.');
	                }
	                initTablesFunction();
	            } else {
	                show('loginform');
	                hide('logoutbtn');
	                hide('tableContainer');
	            }
	        });

	SBS.fillCache('Modul');
	SBS.fillCache('Role');
	SBS.fillCache('Depot');
	SBS.fillCache('Produkt');
	SBS.fillCache('Benutzer');
	SBS.fillCache('wp');
}

function onSuccessfulLogin(result,path){
	if (!(!result || !result.user || !result.match || result.match == '0E0')){
		window.setTimeout(function(){document.location.reload();},333);
	} else if (result && result.user) {
		setContent('missingUser', result.user);
		show('userMissing');
		document.getElementById('missingUserEmail').href='mailto:ag-bestellsystem@solawi-rhein-neckar.org?subject=Solawi+Bestellsystem+fehlender+Benutzer+'+result.user;
	} else {
		show('loginError');
	}
}


function onClickLoginBtn() {
	event.preventDefault();
	postAjax('/cgi-bin/wp.pl/login', {
		name : document.getElementById('inpName').value,
		password : document.getElementById('inpPass').value
	}, onSuccessfulLogin);
	return false;
}

function onClickLogoutBtn() {
	document.cookie = 'sessionid=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
	show('loginform');
	hide('logoutbtn');
	hide('tableContainer');
}

document.write('<div id="blockui_post" \
		style="position: fixed; top: 0; left: 0; bottom: 100%; right: 100%; width: 100%; height: 100%; text-align: center; padding-top: 30%; z-index: 250; background-color: rgba(0, 0, 0, 0.3); display: none;"> \
		<span style="display: inline-block; padding: 30px; background-color: #FFF; border: 1px solid black;"> \
			SENDE DATEN... \
		</span> \
	</div> \
	<div id="blockui_get" \
		style="position: fixed; top: 0; left: 0; bottom: 100%; right: 100%; width: 100%; height: 100%; text-align: center; padding-top: 30%; z-index: 240; background-color: rgba(0, 0, 0, 0.3); display: none;"> \
		<span style="display: inline-block; padding: 30px; background-color: #FFF; border: 1px solid black;"> \
			EMPFANGE DATEN - BITTE WARTEN.... \
		</span> \
	</div> \
	<div id="blockui_edit" \
		style="position: fixed; top: 0; left: 0; bottom: 100%; right: 100%; width: 100%; height: 100%; text-align: center; z-index: 240; background-color: rgba(0, 0, 0, 0.3); display: none;"> \
		<div \
			style="display: inline-block; padding: 5px; margin: 10px; border: 1px solid black; background-color: #FFF;"> \
			<div id="editError" style="color: red; font-weight: bold;"></div> \
			<div id="editor" style="padding: 5px;"></div> \
		</div> \
	</div> \
	<div id="blockui_edit2" \
		style="position: fixed; top: 0; left: 0; bottom: 100%; right: 100%; width: 100%; height: 100%; text-align: center; z-index: 230; background-color: rgba(0, 0, 0, 0.3); display: none;"> \
		<div \
			style="display: inline-block; width: 90%; padding: 5px; margin: 10px; border: 1px solid black; background-color: #FFF;"> \
			<div id="editError2" style="color: red; font-weight: bold;"></div> \
			<div id="editor2" style="padding: 5px;"></div> \
		</div> \
	</div> \  \
  \
	<div id="logoutfrombg" \
		style="box-shadow: 0em 0em 1em 1em rgba(222, 222, 222, 0.7); background: rgba(222, 222, 222, 0.7); position: fixed; height: 6em; width: 19em; z-index: 8888; right: 1px; top: 0; font-size: 12px;"> \
	</div> \
	<div id="logoutform" \
		style="position: fixed; right: 1px; top: 0; font-size: 12px; width: 20em; height: 7em; text-align: center; z-index: 9999;"> \
		Woche: \
		<button onclick="changeWeek(-1)" style="padding:0 3px;height:1.5em;">&lt;&lt;</button> \
		<span id="selectedWeek0" style="font-weight: bold; background-color: rgba(222, 222, 222);">00</span> \
		<button onclick="changeWeek(+1)" style="padding:0 3px;height:1.5em;">&gt;&gt;</button> \
		<button id="logoutbtn" style="height:1.5em;" \
			onclick="onClickLogoutBtn();">Logout</button> \
		<div id="messages" \
			style="height: 3.5em; overflow: hidden; position: absolute; bottom: 0; width: 20em;"> \
		</div> \
	</div> \
 \
	<div id="loginform" style="display: none"> \
		LOGIN: \
		<form method="post" action="/cgi-bin/wp.pl/login"> \
			Name: <input type="text" id="inpName" name="name" placeholder="name" /> \
			Password: <input type="password" id="inpPass" name="password" /> \
			<input type="submit" value="Login" \
				onclick="onClickLoginBtn();" /> \
			<div id="loginError" style="display: none; color: red; font-weight: bold; padding-top: 20px;"> \
				Falscher Benutzername oder Falsches Passwort! Bitte mit den \
				Login-Daten des \
					<a href="https://www.solawi-rhein-neckar.org/intern/login/?redirect_to=https%3A%2F%2Fwww.solawi-rhein-neckar.org%2Fintern%2F"> \
						Mitgliederbereichs \
					</a> \
				anmelden! \
			</div> \
			<div id="userMissing" \
				style="display: none; color: red; font-weight: bold; padding-top: 20px;"> \
				Login erfolgreich, aber Benutzer mit Name <span id="missingUser" style="color: orange;"></span> \
				wurde im Bestellsystem nicht gefunden. \
				<br /> \
				Bitte Mail an Depotverwalter und \
					<a  id="missingUserEmail" \
						href="mailto:ag-bestellsystem@solawi-rhein-neckar.org?subject=Solawi+Bestellsystem+fehlender+Benutzer+"> \
						ag-bestellsystem@solawi-rhein-neckar.org \
					</a> \
				schreiben. \
			</div> \
		</form> \
		<br /> \
		<br /> \
		<a style="padding-left: 20px;" href="index.htm">Zurück zur Startseite</a><br /> \
	</div> \
  \
	<div id="warning" style="color: red"></div> \
');