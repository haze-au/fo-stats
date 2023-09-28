#!/usr/bin/env nodejs
const express = require("express");
const router = express.Router();
const controller = require("../include/controller");

let routes = (app) => {
  router.post("/upload/:path([a-z0-9]+/[a-z0-9]+)", controller.upload);
  router.post("/notify/:path(\*/\*/\*.json)", controller.notify);
  router.get("/notify/:path(\*/\*/\*.json)", controller.notify);
  app.use(router);
};

module.exports = routes;
