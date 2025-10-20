import { runSimulation } from "./analyze.service.js";

export async function simulateAnalysis(req, res) {
  try {
    const { commits, repoUrl } = req.body;
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
    const simulationResult = await runSimulation(commits, repoUrl);
    res.json(simulationResult);
  } catch (err) {
    console.error("Error en simulateAnalysis:", err.message);
    res.status(500).json({ error: err.message });
  }
}
