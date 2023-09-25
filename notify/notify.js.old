#!/usr/bin/env nodejs
const { exec } = require("child_process");
var http = require('http');
http.createServer(function (request, response) {
   response.writeHead(200, {'Content-Type': 'text/plain'});
   if (request.url.match("^.+/(staging|quad|scrim|tourney)/.+[.]json$") ) {
     url = decodeURIComponent(request.url.slice(1));
     response.end(url);
     exec('pwsh /var/www/html/_FoDownloader.ps1 -FilterPath ' + url + ' -LimitMins 45  -DailyBatch > /var/www/html/.notify.log');
   } else { response.end(''); }
}).listen(8080);
console.log('Server running at http://127.0.0.1:8080/');
