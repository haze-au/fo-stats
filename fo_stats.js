function ConvertTimeToMins(strTime) {
    var minsec = strTime.split(':');

    if (minsec.length != 2) { return; }
    return Number(minsec[0]) + (Number(minsec[1]) / 60)
}

function MakeVersusHover(strTable) {
    var table = document.getElementById(strTable);
    for (var j = 0, col; col = table.rows[0].cells[j]; j++) {
        let val = col.innerText;
        if (val === "1") { var pvpStart = j; break; }
    }

    for (var i = 1, row; row = table.rows[i]; i++) {
        if (table.rows[i].cells[0].innerText.match("^Total:.*$")) { break; }
        var id = row.cells[0].innerText;
        var div = document.createElement('div');

        if (table.rows[0].cells[pvpStart + i - 1].innerText != "Classes") {
            div.innerHTML = id + '<span class="VersusHoverTextHeader">' + row.cells[1].innerText + '</span>';
            div.className = 'VersusHover';
            table.rows[0].cells[pvpStart + i - 1].innerHTML = div.outerHTML;
        }

        for (var j = pvpStart, col; col = table.rows[i].cells[j]; j++) {
            if (table.rows[0].cells[j].innerText === "Classes") {
                GetClassTime(strTable, id, col);
                break;
            }

            let pos = table.rows[0].cells[j].innerText;
            var opTeam = table.rows[pos].cells[2].innerText;
            var opValue = table.rows[pos].cells[pvpStart + i - 1].innerText;

            if (pos == i) { var hoverClass = "Amber"; var hoverTitle = "Self-affliction" }
            else if (row.cells[2].innerText == opTeam) { var hoverClass = "Orange"; var hoverTitle = "Friendly fire"; }
            else { var hoverClass = "Green"; var hoverTitle = "Head to Head"; }

            var div = document.createElement('div');
            div.innerHTML = col.innerText + '<span class="VersusHoverText' + hoverClass + '"><b>' + hoverTitle + '</b>' +
                '<table class="hideTable"><tr><td>' +
                row.cells[1].innerText + ":</td><td>" + col.innerText + "</td></tr><tr><td>" +
                table.rows[pos].cells[1].innerText + ':</td><td> ' + opValue + '</td></tr></table></span>';
            col.id = strTable + '-' + i + '-' + pos;
            div.className = 'VersusHover';

            col.innerHTML = div.outerHTML;
        }
    }

    HighlightMaxVersus(strTable);

}

function MakeSummaryHover(strTable) {
    var table = document.getElementById(strTable);
    for (var j = 0, col; col = table.rows[0].cells[j]; j++) {
        if (col.innerText === "Classes") { var classStart = j; break; }
    }

    for (var i = 1, row; row = table.rows[i]; i++) {
        if (row.cells[0].innerText.match("^Total:.*$")) { break; }
        GetClassTime(strTable, row.cells[0].innerText, row.cells[classStart]);
    }
}

function MakePerMinFragHover(strTable) {
    var table = document.getElementById(strTable).getElementsByTagName('tbody')[0];
    var header = document.getElementById(strTable).getElementsByTagName('thead')[0];

    if (strTable.match("^class.*$")) { var start = 4; }
    else { var start = 6; }

    for (var i = 0, row; row = table.rows[i]; i++) {
        var round = 1;
        for (var j = start, col; col = row.cells[j]; j++) {
            var txt = '';
            var strKD = col.innerText;
            if (strKD) {
                var arrKD = strKD.split('/');
                if (arrKD.length == 1 || arrKD[1] == 0) {
                    var kd = "&infin;";
                } else {
                    var kd = arrKD[0] / arrKD[1];
                    kd = Number.parseFloat(kd).toFixed(2);
                }
                var rank = arrKD[0] - arrKD[1];
                var team = row.cells[2].innerText;
                if (team.match("^.&.$") || team == '') { team = '0'; }

                txt = strKD +
                    '<span class="ClassHoverText' + team + '">' +
                    '<table class="hideTable"><tr><td><b>Rank:</b></td><td>' + rank + '</td></tr>' +
                    '<tr><td><b>K/D:</b></td><td>' + kd + '</td></tr>';

                if (header.rows[0].cells[1].innerText.match("^(Rnd|Round)[1-2]") &&
                    header.rows[1].cells[j].innerText.match("^Sco|Sold|Demo|Med|HwG|Pyro|Spy|Eng$")) {
                    var startRnd2 = 4 + header.rows[0].cells[1].colSpan;
                    if (j < startRnd2) { round = 1; }
                    else { round = 2; }
                    var time = GetClassTimeValue(i, round, header.rows[1].cells[j].innerText);
     
                    txt = txt + 
                        '<tr><td><b>KPM:</b></td><td>'  + Number.parseFloat((arrKD[0] / ConvertTimeToMins(time))).toFixed(2) +
                        '<tr><td><b>Time:</b></td><td>' + time +
                        '</td></tr>';
                }

                txt = txt + '</table></span>';

                var div = document.createElement('div');
                div.innerHTML = txt;
                div.className = "ClassHover";
                col.innerHTML = div.outerHTML;
            }
        }
    }
}

function GetClassTimeValue(id, round, playerclass) {
    var cTable = document.getElementById("classTime");
    var start = 4 + ((Number(round) - 1) * 10);

    for (var i = 2, row; row = cTable.rows[i]; i++) {
        if (row.cells[0].innerText == Number(id) + 1) {
            for (var j = start, col; col = cTable.rows[i].cells[j]; j++) {
                var tfClass = cTable.rows[1].cells[j].innerText;
                if (tfClass == 'K/D') { break; }
                if (tfClass == playerclass) { return col.innerText; }
            }
        }
    }
    return ''
}

function GetClassTime(strTable, id, classCol) {
    var cTable = document.getElementById("classTime");
    var team = cTable.rows[Number(id) + 1].cells[2].innerText;

    if ((strTable.match("^.*Attack$") && team.match("^1.*$")) || (strTable.match("^.*Defence$") && team.match("^2.*$"))) {
        var round = 1;
    } else if ((strTable.match("^.*Attack$") && team.match("^2.*$")) || (strTable.match("^.*Defence$") && team.match("^1.*$"))) {
        var round = 2;
    } else {
        var round = strTable.slice(-1);
    }

    var start = 4 + ((round - 1) * 10);
    if (round == 2) { start = start - 1; }
    let hoverText = "";
    let cStr = classCol.innerText;

    for (var i = 2, row; row = cTable.rows[i]; i++) {
        if (row.cells[0].innerText == id) {
            for (var j = start, col; col = cTable.rows[i].cells[j]; j++) {
                var tfClass = cTable.rows[1].cells[j].innerText;
                if (tfClass == 'K/D') { break; }
                if (col.innerText == "") { continue; }
                if (hoverText != "") { hoverText = hoverText + "<br>"; }
                hoverText = hoverText + "<b>" + tfClass + "</b>: " + col.innerText;
            }


            if (cTable.rows[i].cells[2].innerText.match("^(1|2)$")) {
                var hoverClass = cTable.rows[i].cells[2].innerText;
            } else {
                var hoverClass = "0";
            }

            var div = document.createElement('div');
            div.innerHTML = cStr + '<span class="ClassHoverText' + hoverClass + '">' + hoverText + '</span>';
            div.className = 'ClassHover';
            classCol.innerHTML = div.outerHTML;
        }

    }
}

function MakePlayerProfiles(strTable, kind) {
    var table = document.getElementById(strTable);
    var flagTable = document.getElementById("perMinFlag").getElementsByTagName('tbody')[0];

    for (var i = 0, row; row = table.getElementsByTagName('tbody')[0].rows[i]; i++) {
        let player = row.cells[0].innerText;
        let team = row.cells[2].innerText;
        if (team == '') { continue }

        var plusRound2 = 0;
        if (kind == 'both') {
            var round = 1;
            var plusRound2 = 2;
        } else if (kind == 'round') {
            var round = strTable.slice(-1);
        } else if ((kind == 'attack' && team.match("^1.*$")) || (kind == 'defence' && team.match("^2.*$"))) {
            var round = 1;
        } else if ((kind == 'attack' && team.match("^.*2$")) || (kind == 'defence' && team.match("^.*1$"))) {
            var round = 2;
        }

        var fragTable = document.getElementById("fragRound" + round).getElementsByTagName('tbody')[0];
        var damageTable = document.getElementById("damageRound" + round).getElementsByTagName('tbody')[0];
        var classTitle = "Classes:";

        for (var j = 0, row2; row2 = fragTable.rows[j]; j++) {

            if (row2.cells[0].innerText == player) {
                frags = Number(row2.cells[3].innerText);
                deaths = Number(row2.cells[4].innerText);
                tkills = Number(row2.cells[5].innerText);
                dmg = Number(damageTable.rows[j].cells[3].innerText);
                caps = Number(flagTable.rows[j].cells[3].innerText);
                stops = Number(flagTable.rows[j].cells[7].innerText);
                ftime = flagTable.rows[j].cells[6].innerText
                takes = Number(flagTable.rows[j].cells[4].innerText);
                cls = fragTable.rows[j].cells[fragTable.rows[j].cells.length - 1].innerText;
                break;
            }
        }

        if (plusRound2 > 0) {
            var fragTable = document.getElementById("fragRound2").getElementsByTagName('tbody')[0];
            var damageTable = document.getElementById("damageRound2").getElementsByTagName('tbody')[0];

            for (var j = 0, row2; row2 = fragTable.rows[j]; j++) {
                if (row2.cells[0].innerText == player) {
                    frags = frags + Number(row2.cells[3].innerText);
                    deaths = deaths + Number(row2.cells[4].innerText);
                    tkills = tkills + Number(row2.cells[5].innerText);
                    dmg = dmg + Number(damageTable.rows[j].cells[3].innerText);
                    cls = cls + '<br>' + fragTable.rows[j].cells[fragTable.rows[j].cells.length - 1].innerText;
                    classTitle = "Classes Rnd1:<br>Classes Rnd2:"
                    break;
                }
            }
        }


        var div = document.createElement('div');
        var cStr = row.cells[1].innerText;

        if (kind == 'both') {
            hoverTitle = 'Attack & Defence'
        } else if (kind == 'attack' || (round == 1 && team.match("^1.*$")) || (round == 2 && team.match("^.*2$"))) {
            hoverTitle = 'Attack'
        } else if (kind == 'defence' || (round == 1 && team.match("^2.*$")) || (round == 2 && team.match("^.*1$"))) {
            hoverTitle = 'Defence'
        }

        if (row2.cells[2].innerText.match("^(1|2)$")) {
            var hoverClass = row2.cells[2].innerText;
        } else {
            var hoverClass = "0";
        }

        var divTxt = cStr + '<span class="PlayerHoverText' + hoverClass + '"><table class="hideTable"><tr><td><b>' + hoverTitle + '</b></td></tr>';
        if (kind == 'attack' || kind == 'both' || hoverTitle == 'Attack') {
            divTxt = divTxt + '<tr><td><b>Caps/Takes:</b></td><td>' + caps + ' / ' + takes + '</td></tr>';
            divTxt = divTxt + '<tr><td><b>Flag Time:</b></td><td>' + ftime + '</td></tr>';
        }
        if (kind == 'defence' || kind == 'both' || hoverTitle == 'Defence') {
            divTxt = divTxt + '<tr><td><b>Flag stops:</b></td><td>' + stops + '</td></tr>';
        }
        divTxt = divTxt +
            '<tr><td><b>Kill/Death:</b></td><td>' + frags + ' / ' + deaths + '</td></tr>' +
            '<tr><td><b>Damage:</b></td><td>' + dmg + '</td></tr>' +
            '<tr><td><b>TKill:</b></td><td>' + tkills + '</td></tr>' +
            '<tr><td><b>' + classTitle + '</b></td><td>' + cls + '</td></tr>' +
            '</span>';

        div.innerHTML = divTxt;
        div.className = 'PlayerHover';
        row.cells[1].innerHTML = div.outerHTML;
    }
}

function MakeAwardPlayerProfile(strTable) {
    var table = document.getElementById(strTable);
    if (strTable == "awardDefence") {
        var copyTable = document.getElementById("summaryDefence").getElementsByTagName('tbody')[0];
    } else {
        var copyTable = document.getElementById("summaryAttack").getElementsByTagName('tbody')[0];
    }

    for (var i = 0, row; row = table.getElementsByTagName('tbody')[0].rows[i]; i++) {
        if (row.cells.length < 3) { continue; }
        let names = row.cells[1].innerText.split(',');
        let newInnerTxt = "";
        for (var j = 0, player; player = names[j]; j++) {
            for (var k = 0, row2; row2 = copyTable.rows[k].cells[1]; k++) {
                if (row2 == "") { continue; }
                if (row2.innerText == player.replace('*', '').trim()) {
                    if (newInnerTxt != "") { newInnerTxt = newInnerTxt + ", " }
                    var span = row2.getElementsByTagName('span')[0];
                    var div = document.createElement('div');
                    div.className = 'PlayerHover';
                    div.innerHTML = player + span.outerHTML;
                    newInnerTxt = newInnerTxt + div.outerHTML;
                    break;
                }
            }
        }

        if (newInnerTxt != "") { row.cells[1].innerHTML = newInnerTxt; }
    }
}

function MakeClassTimeHover(strTable) {

    var table = document.getElementById(strTable).getElementsByTagName('tbody')[0];
    var header = document.getElementById(strTable).getElementsByTagName('thead')[0];
    var ckTable = document.getElementById('classKills').getElementsByTagName('tbody')[0];
    
    var start = 4;

    for (var i = 0, row; row = table.rows[i]; i++) {
        for (var j = start, col; col = row.cells[j]; j++) {
            if (col.innerText == '' || header.rows[1].cells[j].innerText == 'K/D') { continue; }

            var txt = '';
            var ckValue = ckTable.rows[i].cells[j].innerText;

            if (ckValue != '') {
                strKD = ckValue.split('/');
            } else { continue; }
            var kills = Number(strKD[0]);
            var dth = Number(strKD[1]);

            if (strKD.length == 1 || dth == 0) {
                var kd = "&infin;";
            } else {
                var kd = kills / dth;
                kd = Number.parseFloat(kd).toFixed(2);
            }

            var rank = kills - dth;
            var team = row.cells[2].innerText;
            if (team.match("^.&.$") || team == '') { team = '0'; }
            var minsec = col.innerText.split(':');
            var mins = Number(minsec[0]) + (Number(minsec[1]) / 60);

            txt = col.innerText + 
                '<span class="ClassHoverText' + team + '">' +
                '<table class="hideTable"><tr><td><b>Kill/Dth:</b></td><td>' + kills + ' / ' + dth + '</td></tr>' +
                '<tr><td><b>KPM:</b></td><td>' + Number.parseFloat(kills / mins).toFixed(2) + '</td></tr>' +
                /*'<b>Death:</b> ' + dth + '<br>' +*/
                '<tr><td><b>Rank:</b></td><td>' + rank + '</td></tr>' +
                '<tr><td><b>K/D:</b></td><td>' + kd + '</td></tr></table></span>';

            var div = document.createElement('div');
            div.innerHTML = txt;
            div.className = "ClassHover";
            col.innerHTML = div.outerHTML;
        }
    }
}

function MakeH4PlayerProfile() {
    var elements = document.getElementsByTagName('h4');
    var copyTable = document.getElementById("perMinFragDeath").getElementsByTagName('tbody')[0];

    for (var i = 0, name; name = elements[i].innerText; i++) {
        let newInnerTxt = "";
        for (var k = 0, row2; row2 = copyTable.rows[k].cells[1]; k++) {
            if (row2.innerText == "") { continue; }
            if (row2.innerText == name) {
                if (newInnerTxt != "") { newInnerTxt = newInnerTxt + ", " }
                var span = row2.getElementsByTagName('span')[0];
                var div = document.createElement('div');
                div.className = 'PlayerHover';
                div.innerHTML = name + span.outerHTML;
                newInnerTxt = newInnerTxt + div.outerHTML;
                break;
            }
        }

        if (newInnerTxt != "") { elements[i].innerHTML = newInnerTxt; }
        if (!elements[i+1]) { break; }
    }
}

function InsertDailyStatsURL() {
    var folders = window.location.pathname.split('/');
    var location = '/' + folders[folders.length - 3] + '/' + folders[folders.length - 2];
    let fopath = window.location.pathname;
    fopath = fopath.substring(1).replace('.html', '');

    var txt = '<hr><b>Server</b> : ' + '<a href="' + location + '/?C=N;O=D;P=*.html">' + location + '</a> | ';
    txt = txt + '<b>Daily stats</b> : <a href="http://haze.fortressone.org/_daily/north-america/?C=N;O=D;P=*.html" target="_blank">North-America</a> / '
    txt = txt + '<a href="http://haze.fortressone.org/_daily/oceania/?C=N;O=D;P=*.html" target="_blank">Oceania</a> / '
    txt = txt + '<a href="http://haze.fortressone.org/_daily/europe/?C=N;O=D;P=*.html" target="_blank">Europe</a> / '
    txt = txt + '<a href="http://haze.fortressone.org/_daily/brasil/?C=N;O=D;P=*.html" target="_blank">Brasil</a> / '
    txt = txt + '<a href="http://haze.fortressone.org/_daily/international/?C=N;O=D;P=*.html" target="_blank">International</a> | '
    txt = txt + '<b>Demo</b> : <a href="http://fortressone-demos.s3-ap-southeast-2.amazonaws.com/' + fopath + '.mvd.gz" target="_blank">MVD</a> | '
    txt = txt + '<b>Archive</b> : <a href="http://fortressone-stats.s3-website-ap-southeast-2.amazonaws.com/' + fopath + '.json" target="_blank">JSON</a>'
    txt = txt + '<hr>'
    var anchor = document.getElementsByTagName('h1')[0].insertAdjacentHTML('afterEnd', txt);
}

function HighlightMaxVersus(strTable) {
    var table = document.getElementById(strTable).getElementsByTagName('tbody');
    var elements = table[0].getElementsByClassName("cellGreen");
    const values = [];
    let ids = [];
    for (i = 0; i < elements.length; i++) {
        if (strTable == "perMinFragDeath") {
            if (!elements[i].innerText.match("^[0-9]+\/[0-9]+")) { continue; }
            split = elements[i].innerText.split('/');
            values.push(Number(split[0] - split[1]));
        } else if (elements[i].innerText.match("^[0-9]+$")) {
            values.push(Number(elements[i].innerText));
        } else { continue; }
        ids.push(elements[i].id);
    }
    max = Math.max(...values);

    if (ids[0]) {
        for (i = 0; i < values.length; i++) {
            if (values[i] == max) {
                document.getElementById(ids[i]).classList.add("max");
            }
        }
    } else {
        for (i = 0; i < elements.length; i++) {
            if (values[i] == max) {
                elements[i].classList.add("max");
            }
        }
    }

}

function HighlightMax(strTable, column) {
    table = document.getElementById(strTable).getElementsByTagName('tbody')[0];
    elements = table.querySelectorAll('td:nth-child(' + column + ')');
    const values = [];

    for (i = 0; i < elements.length; i++) {
        if (elements[i].innerText.match("^[0-9]+(\.[0-9]+)?$")) {
            values.push(Number(elements[i].innerText.replace(':', '')));
        }
    }
    max = Math.max(...values);
    for (i = 0; i < elements.length; i++) {
        if (elements[i].innerText.replace(':', '') == max) {
            elements[i].classList.add("max");
        }
    }
}



function FO_Post() {
    var FOStatsVersion = document.getElementById('FOStatsVersion');
    if (!FOStatsVersion) { FOStatsVersion = 2.0; }
    else { FOStatsVersion = Number(FOStatsVersion.content);}

    new Tablesort(document.getElementById('summaryAttack'), { descending: true });
    new Tablesort(document.getElementById('summaryDefence'), { descending: true });
    new Tablesort(document.getElementById('fragRound1'), { descending: true });
    new Tablesort(document.getElementById('fragRound2'), { descending: true });
    new Tablesort(document.getElementById('damageRound1'), { descending: true });
    new Tablesort(document.getElementById('damageRound2'), { descending: true });
    new Tablesort(document.getElementById('perMinFragDeath'), { descending: true });
    new Tablesort(document.getElementById('perMinDamage'), { descending: true });
    new Tablesort(document.getElementById('perMinFlag'), { descending: true });
    new Tablesort(document.getElementById('classKills'), { descending: true });
    new Tablesort(document.getElementById('classTime'), { descending: true });
    InsertDailyStatsURL();
    MakeVersusHover("fragRound1");
    MakeVersusHover("fragRound2");
    MakeVersusHover("damageRound1");
    MakeVersusHover("damageRound2");
    MakeSummaryHover("summaryAttack");
    MakeSummaryHover("summaryDefence");
    MakePlayerProfiles("summaryAttack", 'attack');
    MakePlayerProfiles("summaryDefence", 'defence');
    MakePlayerProfiles("fragRound1", 'round');
    MakePlayerProfiles("fragRound2", 'round');
    MakePlayerProfiles("damageRound1", 'round');
    MakePlayerProfiles("damageRound2", 'round');
    MakePlayerProfiles("perMinFragDeath", 'both');
    MakePlayerProfiles("perMinDamage", 'both');
    MakePlayerProfiles("perMinFlag", 'both');
    MakePlayerProfiles("classKills", 'both');
    MakePlayerProfiles("classTime", 'both');
    MakeAwardPlayerProfile("awardDefence");
    MakeAwardPlayerProfile("awardAttack");
    MakePerMinFragHover("perMinFragDeath");
    MakePerMinFragHover("classKills");
    HighlightMax("summaryAttack", '4');
    HighlightMax("summaryAttack", '5');
    HighlightMax("summaryAttack", '6');
    HighlightMax("summaryAttack", '7');
    HighlightMax("summaryAttack", '9');
    HighlightMax("summaryAttack", '10');
    HighlightMax("summaryAttack", '11');
    HighlightMax("summaryAttack", '13');
    HighlightMax("summaryDefence", '4');
    HighlightMax("summaryDefence", '5');
    HighlightMax("summaryDefence", '6');
    HighlightMax("summaryDefence", '7');
    HighlightMax("summaryDefence", '9');
    HighlightMax("summaryDefence", '10');
    HighlightMax("summaryDefence", '11');
    HighlightMax("summaryDefence", '13');
    HighlightMaxVersus("perMinDamage");
    HighlightMaxVersus("perMinFragDeath");
    HighlightMax("perMinFlag", '4');
    HighlightMax("perMinFlag", '5');
    HighlightMax("perMinFlag", '6');
    HighlightMax("perMinFlag", '7');
    HighlightMax("perMinFlag", '8');
    if (FOStatsVersion >= 2.1) {
      MakeClassTimeHover('classTime');
    }
    MakeH4PlayerProfile();
}