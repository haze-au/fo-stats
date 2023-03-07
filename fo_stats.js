    function MakeVersusHover (strTable) {
        var table = document.getElementById(strTable);
    
        for (var j = 0, col; col = table.rows[0].cells[j]; j++) {
            let val = col.innerText;
            if (val === "1") { var pvpStart = j; break;  }
        }

        for (var i = 1, row; row = table.rows[i]; i++) {
            if (table.rows[i].cells[0].innerText === "Total:") { break; }
            var newText = '';
            for (var j = pvpStart, col; col = table.rows[i].cells[j]; j++) {
                if (table.rows[0].cells[j].innerText === "Classes") { break; }
                
                let pos = table.rows[0].cells[j].innerText;
                var opTeam  = table.rows[pos].cells[2].innerText;
                var opValue = table.rows[pos].cells[pvpStart + i - 1].innerText;
                
                if (pos == i) { var hoverClass = "Amber"; var hoverTitle = "Self-affliction" }
                else if (row.cells[2].innerText == opTeam) { var hoverClass = "Orange"; var hoverTitle = "Friendly fire";}
                else { var hoverClass = "Green"; var hoverTitle = "Head to Head"; }
                
                var div = document.createElement('div');
                div.innerHTML = col.innerText + '<span class="VersusHoverText' + hoverClass +'"><b>' + hoverTitle + '</b><br>' +
                                row.cells[1].innerText + ": " + col.innerText + "<br>"  +
                                table.rows[pos].cells[1].innerText + ': ' + opValue + '</span>';
                div.id = strTable +  '-' + j + pos;
                div.className = 'VersusHover';

                col.innerHTML = div.outerHTML;
            }
        }
    }