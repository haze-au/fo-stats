#!/usr/bin/env nodejs
const express = require("express");
const router = express.Router();
const controller = require("../include/controller");

let routes = (app) => {
  router.post("/upload/:path([a-z0-9]+/[a-z0-9]+)", controller.upload);
  router.post("/notify/:path(*[.]json)$", controller.notify);
  router.get("/notify/:path(*[.]json)$", controller.notify);
  router.get("/2v2-add/:path(*[.]json)$", controller.add2v2);
  router.get("/2v2-remove/:path(*[.]json)$", controller.rem2v2);
  router.get("/2v2-add/:path(*%5D)$", controller.add2v2);
  router.get("/2v2-remove/:path(*%5D)$", controller.rem2v2);
  app.use(router);
};

module.exports = routes;
