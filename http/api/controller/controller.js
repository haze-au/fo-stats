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
    console.log(req.url);
    if (req.url.match("^.+/(staging|quad|scrim|tourney)/.+[.]json$") ) {
        //url = decodeURIComponent(req.url.slice(1));
        url = req.params.path;
        exec('pwsh /var/www/html/_FoDownloader.ps1 -FilterPath ' + url + ' -LimitDays 7  -DailyBatch > /var/www/html/.notify.log');
        res.status(200).send({ message: "Processing: " + url });
    } else { res.status(400).send({ message: "Invalid path" + url }); }
};

module.exports = {
  upload,
  notify
};
