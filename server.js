import express from "express";
import githubRoutes from "./github/github.routes.js";
import analyzeRoutes from "./analyze/analyze.routes.js";

const app = express();
app.use(express.json());
app.use("/github", githubRoutes);
app.use("/analyze", analyzeRoutes);

app.listen(4000, () => console.log("API GitHub corriendo en puerto 4000"));
