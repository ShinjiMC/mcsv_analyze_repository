import express from "express";
import cors from "cors";
import githubRoutes from "./github/github.routes.js";
import analyzeRoutes from "./analyze/analyze.routes.js";

const app = express();
app.use(express.json());
const corsOptions = {
  origin: "http://localhost:8080",
  optionsSuccessStatus: 200,
};
app.use(cors(corsOptions));
app.use("/github", githubRoutes);
app.use("/analyze", analyzeRoutes);

app.listen(4000, () => console.log("API GitHub corriendo en puerto 4000"));
