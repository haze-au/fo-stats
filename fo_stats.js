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
            div.innerHTML = col.innerText + '<span class="VersusHoverText' + hoverClass + '"><b>' + hoverTitle + '</b><br>' +
                row.cells[1].innerText + ": " + col.innerText + "<br>" +
                table.rows[pos].cells[1].innerText + ': ' + opValue + '</span>';
            div.id = strTable + '-' + j + pos;
            div.className = 'VersusHover';

            col.innerHTML = div.outerHTML;
        }
    }

}

function MakeSummaryHover(strTable) {
    var table = document.getElementById(strTable);
    for (var j = 0, col; col = table.rows[0].cells[j]; j++) {
        if (col.innerText === "Classes") { var classStart = j; break; }
    }

    for (var i = 1, row; row = table.rows[i]; i++) {
        if (row.cells[0].innerText.match("^Total:.*$")) { break; }
        GetClassTime(strTable, i, row.cells[classStart]);
    }
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

function FO_Post() {
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
}
