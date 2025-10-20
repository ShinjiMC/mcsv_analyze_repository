import { buildCommitTag } from "./github.service.js";

export async function getTagCommits(req, res) {
  try {
    const { repoUrl, selectionName } = req.body;
    if (!repoUrl || !selectionName)
      return res.status(400).json({ error: "Faltan repoUrl o selectionName." });

    const mesh = await buildCommitTag(repoUrl, selectionName);
    res.json(mesh);
  } catch (err) {
    console.error("Error en getTagMesh:", err.message);
    res.status(500).json({ error: err.message });
  }
}
