const { exec } = require("child_process");
const uploadFile = require("../include/upload");

const upload = async (req, res) => {
  try {
    await uploadFile(req, res);

    if (req.file == undefined) {
      return res.status(400).send({ message: "Please upload a file!" });
    }

    res.status(200).send({
      message: "Uploaded the file successfully: " + req.params.path + "/" + req.file.originalname,
    });
    //exec('pwsh /var/www/html/FO_stats_v2.ps1 -StatFile /var/www/html/' + req.params.path + "/" + req.file.originalname +  ' > /var/www/html/.upload.log');
    exec('pwsh /var/www/html/_FoDownloader.ps1 -OutFolder /var/www/html/ -LocalFile ' + req.params.path + '/' + req.file.originalname + ' -LimitDays 90  -DailyBatch > /var/www/html/.upload.log');
  } catch (err) {
    res.status(500).send({
      message: `Could not upload the file: ${req.file.originalname}. ${err}`,
    });
  }
};

const notify = (req, res) => {
    url = req.params.path;

    if (url.match("^.+/(staging|quad|scrim|tourney)/.+[.]json$") ) {
        exec('pwsh /var/www/html/_FoDownloader.ps1 -FilterPath ' + url + ' -LimitDays 7  -DailyBatch > /var/www/html/.notify.log');
        res.status(200).send({ message: "Processing: " + url, });
    } else { res.status(400).send({ message: "Invalid path: " + url, }); }
};

const add2v2 = (req, res) => {
  url = req.params.path;
  if (url.match("^.+/.+/.+\]$")) { url = url + '_blue_vs_red_stats.json'; }
  if (url.match("^.+/.+/.+[.]json$")) {
    var fs = require('fs');

    var excluded = false;
    fs.readFile('/var/www/html/.2v2_tourney_exclude.txt',function (err,data){
      if (err) { console.log(err); }

      urlre = url.replace(/(\[|\])/g,'\\$1');
      urlre = '(^|\n)' + urlre + '(\n|$)';
      re = new RegExp(urlre,'g');

      if (data.toString().match(re)) { excluded = true; }
      if (excluded == true) {
        var txt = data.toString();
        txt = txt.replace(re,'$1');
        fs.writeFile('/var/www/html/.2v2_tourney_exclude.txt',txt,function (err2){
          if (err2) { console.log(err2); }
          console.log(url + ' has been removed from /var/www/html/.2v2_tourney_exclude.txt');
        });
      }
    });

    exec('pwsh /var/www/html/FO_stats_join-json.ps1 -FilterPath /var/www/html/' + url + ' -StartOffsetDays 365 -PlayerCount \'^4$\' -OutFile /var/www/html/2v2_tourney_stats.json');
    res.status(200).send({ message: "Adding " + url });
  } else { res.status(400).send({ message: "Invalid path: " + url }); }
}

const rem2v2 = (req, res) => {
  url = req.params.path;

  if (url.match("^.+/.+/.+\]$")) { url = url + '_blue_vs_red_stats.json'; }

  if (url.match("^.+/.+/.+[.]json$")) {
    var fs = require('fs');
    var excluded = false;
    fs.readFile('/var/www/html/.2v2_tourney_exclude.txt',function (err,data){
      if (err) { console.log(err); }
      urlre = url.replace(/(\[|\])/g,'\\$1');
      urlre = '(^|\n)' + urlre + '(\n|$)';
      re = new RegExp(urlre,'g');
      if (data.toString().match(re)) { excluded = true; }
      if (excluded == false) {
        fs.writeFile('/var/www/html/.2v2_tourney_exclude.txt',data.toString() + '\n' + url,function (err2){
        if (err2) { console.log(err2); }
        console.log(url + ' has been added to /var/www/html/.2v2_tourney_exclude.txt');
      });
      }
    });

    exec('pwsh /var/www/html/FO_stats_join-json.ps1 -RemoveMatch /var/www/html/' + url + ' -FromJson /var/www/html/2v2_tourney_stats.json > /var/www/html/.2v2-remove.log');
    res.status(200).send({ message: "Removing " + url});
  } else { res.status(400).send({ message: "Invalid path: " + url }); }
}


module.exports = {
  upload,
  notify,
  add2v2,
  rem2v2
};
