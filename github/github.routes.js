import express from "express";
import { getTagCommits } from "./github.controller.js";
const router = express.Router();

router.post("/list", getTagCommits);

export default router;
