function linkify(inputText) {
      var replacedText, replacePattern1, replacePattern2, replacePattern3;
      replacePattern1 = /(([-A-z0-9]+\/){2}[-_0-9A-z]+)/gim;
      replacedText = inputText.replace(replacePattern1, '<a href="/$1_blue_vs_red.html" target="_blank">$1</a>');
      return replacedText;
}

function fo_daily_post () {
   document.body.innerHTML = linkify(document.body.innerHTML);
   new Tablesort(document.getElementById('MatchLog'), { descending: true });
   new Tablesort(document.getElementById('AttackSummary'), { descending: true });
   new Tablesort(document.getElementById('DefenceSummary'), { descending: true });
   new Tablesort(document.getElementById('ClassKillsAttack'), { descending: true });
   new Tablesort(document.getElementById('ClassKillsDefence'), { descending: true });
   new Tablesort(document.getElementById('ClassTimeAttack'), { descending: true });
   new Tablesort(document.getElementById('ClassTimeDefence'), { descending: true });
}
