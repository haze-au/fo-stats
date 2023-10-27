const { exec } = require("child_process");
const uploadFile = require("./upload");
global.HttpDir   = '/var/www/html/';
global.LogDir    = '/var/www/html/';
global.UploadDir = '/var/www/html/.upload/';

function logRequest (req,file,param) {
    var fs = require('fs');
    const d = new Date();
    fs.readFile(file,function (err,data){
      if (err) { console.log(err); }
      if (data.length > 60000) {
        txt2 = removeLastLine(data.toString())
      } else { txt2 = data.toString(); }
      
      fs.writeFile(file,d.toISOString() + '\t| ' + req.ip + '\t| ' + param + '\n' + txt2,function (err2){
        if (err2) { console.log(err2); }
      });
    });
}

function removeLastLine (data) {
  if(data.lastIndexOf("\n") > 0) {
    return data.substring(0, x.lastIndexOf("\n"));
  } else {
    return data;
  }
}

function removeLines (data, lines = []) {
    return data
        .split('\n')
        .filter((val, idx) => lines.indexOf(idx) === -1)
        .join('\n');
}


const upload = async (req, res) => {  
  try {
    await uploadFile(req, res);

    if (req.file == undefined) {
      return res.status(400).send({ message: "Please upload a file!" });
    }

    var fs = require('fs');
    if ( fs.existsSync(HttpDir + req.params.path + "/" + req.file.originalname) || 
         fs.existsSync(HttpDir + req.params.path + "/" + req.file.originalname.replace('[.]json$','.html')) ) {
      fs.unlinkSync(UploadDir + req.file.originalname);
      return res.status(400).send({ message: "File already exists: " + req.params.path + "/" + req.file.originalname, });
    } else {
      fs.rename(UploadDir + req.file.originalname, HttpDir + req.params.path + "/" + req.file.originalname);
    }

    logRequest(req,LogDir + '.upload2.log',req.params.path + "/" + req.file.originalname);

    res.status(200).send({
      message: "Uploaded the file successfully: " + req.params.path + "/" + req.file.originalname,
    });

    exec('pwsh ' + HttpDir + '_FoDownloader.ps1 -OutFolder ' + HttpDir + ' -LocalFile ' + req.params.path + '/' + req.file.originalname + ' -LimitDays 90  -NewOnlyBatch > ' + LogDir + '.upload.log');
    logRequest(req,LogDir + '.upload2.log',req.params.path + "/" + req.file.originalname);
  } catch (err) {
    res.status(500).send({
      message: `Could not upload the file: ${req.file.originalname}. ${err}`,
    });
  }
};


const notify = (req, res) => {
    url = req.params.path;

    if ( url.match("^.+/(staging|quad|scrim|tourney)/.+[.]json$") ) {
        logRequest(req,LogDir + '.notify2.log',url);
        exec('pwsh ' + HttpDir +  '_FoDownloader.ps1 -FilterPath ' + url + ' -LimitMins 30 -NewOnlyBatch >> ' + LogDir + '.notify.log');
        logRequest(req,LogDir + '.notify2.log',url);
        res.status(200).send({ message: "Processing: " + url, });
    } else { res.status(400).send({ message: "Invalid path: " + url, }); }
};


const add2v2 = (req, res) => {
  url = req.params.path;
  if (url.match("^.+/.+/.+\]$")) { url = url + '_blue_vs_red_stats.json'; }
  if (url.match("^.+/.+/.+[.]json$")) {
    var fs = require('fs');

    var excluded = false;
    fs.readFile(HttpDir + '.2v2_tourney_exclude.txt',function (err,data){
      if (err) { console.log(err); }

      urlre = url.replace(/(\[|\])/g,'\\$1');
      urlre = '(^|\n)' + urlre + '(\n|$)';
      re = new RegExp(urlre,'g');

      if (data.toString().match(re)) { excluded = true; }
      if (excluded == true) {
        var txt = data.toString();
        txt = txt.replace(re,'$1');
        fs.writeFile(HttpDir + '.2v2_tourney_exclude.txt',txt,function (err2){
          if (err2) { console.log(err2); }
          console.log(url + ' has been removed from ' + HttpDir + '.2v2_tourney_exclude.txt');
        });
      }
    });

    exec('pwsh ' + HttpDir + 'FO_stats_join-json.ps1 -FilterPath ' + HttpDir +  url + ' -StartOffsetDays 365 -PlayerCount \'^4$\' -OutFile ' + HttpDir + '2v2_tourney_stats.json');
    res.status(200).send({ message: "Adding " + url });
  } else { res.status(400).send({ message: "Invalid path: " + url }); }
}


const rem2v2 = (req, res) => {
  url = req.params.path;

  if (url.match("^.+/.+/.+\]$")) { url = url + '_blue_vs_red_stats.json'; }

  if (url.match("^.+/.+/.+[.]json$")) {
    var fs = require('fs');
    var excluded = false;
    fs.readFile(HttpDir + '.2v2_tourney_exclude.txt',function (err,data){
      if (err) { console.log(err); }
      urlre = url.replace(/(\[|\])/g,'\\$1');
      urlre = '(^|\n)' + urlre + '(\n|$)';
      re = new RegExp(urlre,'g');
      if (data.toString().match(re)) { excluded = true; }
      if (excluded == false) {
        fs.writeFile(HttpDir + '.2v2_tourney_exclude.txt',data.toString() + '\n' + url,function (err2){
        if (err2) { console.log(err2); }
        console.log(url + ' has been added to ' + HttpDir + '.2v2_tourney_exclude.txt');
      });
      }
    });

    exec('pwsh ' + HttpDir + 'FO_stats_join-json.ps1 -RemoveMatch ' + HttpDir + url + ' -FromJson ' + HttpDir + '2v2_tourney_stats.json > ' + LogDir + '.2v2-remove.log');
    res.status(200).send({ message: "Removing " + url});
  } else { res.status(400).send({ message: "Invalid path: " + url }); }
}


module.exports = {
  upload,
  notify,
  add2v2,
  rem2v2
};
