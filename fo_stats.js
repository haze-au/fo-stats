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
            div.innerHTML = id + '<span class="VersusHoverTextAmber">' + row.cells[1].innerText + '</span>';
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

            var hoverClass = cTable.rows[i].cells[2].innerText;
            var div = document.createElement('div');
            div.innerHTML = cStr + '<span class="ClassHoverText' + hoverClass + '">' + hoverText + '</span>';
            div.className = 'ClassHover';
            classCol.innerHTML = div.outerHTML;
        }

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
}