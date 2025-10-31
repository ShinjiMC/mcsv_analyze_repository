import { runSimulation2 } from "./analyze.service.js";

export async function simulateAnalysis(req, res) {
  try {
    const { commits, repoUrl, tagName } = req.body;
    if (!Array.isArray(commits) || commits.length === 0) {
      return res.status(400).json({
        error: "El body debe ser un array de commits no vacío.",
      });
    }
    if (!repoUrl) {
      return res.status(400).json({
        error: "El body debe contener un 'repoUrl'.",
      });
    }
    if (!tagName || typeof tagName !== "string") {
      return res.status(400).json({
        error: "El body debe contener un 'tagName' (string).",
      });
    }
    const simulationResult = await runSimulation2(commits, repoUrl, tagName);
    res.json(simulationResult);
  } catch (err) {
    console.error("Error en simulateAnalysis:", err.message);
    res.status(500).json({ error: err.message });
  }
}
