import { buildCommitTag, getRefs, getCommitHistory } from "./github.service.js";

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

export async function getAvailableRefs(req, res) {
  try {
    const { repoUrl } = req.body;
    if (!repoUrl) return res.status(400).json({ error: "Falta repoUrl." });
    const refs = await getRefs(repoUrl);
    res.json(refs);
  } catch (err) {
    console.error("Error en getAvailableRefs:", err.message);
    res.status(500).json({ error: err.message });
  }
}

export async function fetchCommitHistory(req, res) {
  try {
    const { repoUrl, selectionType, selectionName } = req.body;
    if (!repoUrl || !selectionType || !selectionName)
      return res
        .status(400)
        .json({ error: "Faltan repoUrl, selectionType o selectionName." });
    const fullRefName = `refs/${selectionType}/${selectionName}`;
    const commits = await getCommitHistory(repoUrl, fullRefName);
    res.json({ commits });
  } catch (err) {
    console.error("Error en fetchCommitHistory:", err.message);
    res.status(500).json({ error: err.message });
  }
}
