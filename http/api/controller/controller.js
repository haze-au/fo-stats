const uploadFile = require("../incl/upload");

const upload = async (req, res) => {  
  try {
    await uploadFile(req, res);

    if (req.file == undefined) {
      return res.status(400).send({ message: "Please upload a file!" });
    }

    res.status(200).send({
      message: "Uploaded the file successfully: " + req.file.originalname,
    });
  } catch (err) {
    res.status(500).send({
      message: `Could not upload the file: ${req.file.originalname}. ${err}`,
    });
  }
};

const notify = (req, res) => {
    if (request.url.match("^.+/(staging|quad|scrim|tourney)/.+[.]json$") ) {
        url = decodeURIComponent(request.url.slice(1));
        exec('pwsh /var/www/html/_FoDownloader.ps1 -FilterPath ' + url + ' -LimitMins 45  -DailyBatch > /var/www/html/.notify.log');
        res.status(200).send({ message: url });
    } else { res.status(400).send({ message: "Invalid path" }); }
};

module.exports = {
  upload,
  notify
};