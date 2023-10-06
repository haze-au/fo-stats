function linkify(inputText) {
      var replacedText, replacePattern1, replacePattern2, replacePattern3;
      replacePattern1 = /((([-A-z0-9]+\/){2})([A-Za-z0-9-_\[\]]+))/gim;
      replacedText = inputText.replace(replacePattern1, '<a href="/$2">$2</a></td><td><a href="/$1_blue_vs_red.html" target="_blank">$4</a>');
      replacedText = replacedText.replace(/Match<\/th>/gim, 'Server</th><th>Match</th>');
      return replacedText;
}

function linkify2(tbody) {
      for (var i = 0, row; row = tbody.rows[i]; i++) {
        row.cells[0].innerHTML = '<a href="/' + row.cells[0].innerText + '" target="_blank">' + row.cells[0].innerText + '</a>';
        row.cells[1].innerHTML = '<a href="/' + row.cells[0].innerText + row.cells[1].innerText + '_blue_vs_red.html" target="_blank">' + row.cells[1].innerHTML + '</a>';
      }
      return tbody.innerHTML;
}


function fo_daily_post () {
    var FOJoinJsonVersion = document.getElementById('FOJoinJsonVersion');
    if (!FOJoinJsonVersion) { FOJoinJsonVersion = 1.0; }
    else { FOJoinJsonVersion = Number(FOJoinJsonVersion.content);}

   if (FOJoinJsonVersion > 1.0) { 
     var table = document.getElementById('MatchLog'); 
     if (table.getElementsByTagName('thead')[0].rows[0].cells[0].innerText == 'Server') {
       var tbody = table.getElementsByTagName('tbody')[0];
       tbody.innerHTML = linkify2(tbody); 
     }
   } else { 
     document.body.innerHTML = linkify(document.body.innerHTML); 
   }

   new Tablesort(document.getElementById('MatchLog'), { descending: true });
   new Tablesort(document.getElementById('AttackSummary'), { descending: true });
   new Tablesort(document.getElementById('DefenceSummary'), { descending: true });
   new Tablesort(document.getElementById('ClassKillsAttack'), { descending: true });
   new Tablesort(document.getElementById('ClassKillsDefence'), { descending: true });
   new Tablesort(document.getElementById('ClassTimeAttack'), { descending: true });
   new Tablesort(document.getElementById('ClassTimeDefence'), { descending: true });
}