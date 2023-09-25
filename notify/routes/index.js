#!/usr/bin/env nodejs
const express = require("express");
const router = express.Router();
const controller = require("../controller");

let routes = (app) => {
  router.post("/upload", controller.upload);
  router.get("/notify", controller.notify);
  app.use(router);
};

module.exports = routes;