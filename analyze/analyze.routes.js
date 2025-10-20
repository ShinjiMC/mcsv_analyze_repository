import express from "express";
import { simulateAnalysis } from "./analyze.controller.js";
const router = express.Router();

router.post("/simulate", simulateAnalysis);

export default router;
