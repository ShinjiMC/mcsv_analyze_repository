import fetch from "node-fetch";
import dotenv from "dotenv";
import fs from "fs";
import path from "path";
import os from "os";
import { spawn } from "child_process";
import { promisify } from "util";

dotenv.config();

const ANALYSIS_SCRIPTS = [
  // "churn_2.sh",
  // "cohesion.sh",
  // "complexity.sh",
  // "coupling.sh",
  // "lint_2.sh",
  // "coverage.sh",
  "halstead.sh",
];
const MAIN_DIR = process.cwd();
const WORKSPACE_DIR = path.join(MAIN_DIR, "..", ".code-analysis-workspace");
const RESULTS_DIR = path.join(WORKSPACE_DIR, "analysis_results");
const REPO_CLONES_DIR = path.join(WORKSPACE_DIR, "analysis_clones");

async function runCommand(command, options = {}) {
  console.log(`[SPAWN]: ${command}`);
  // spawn needs command and args separately.
  // 'bash -c command' allows passing the whole string.
  const args = ["-c", command];
  const process = spawn("bash", args, {
    ...options, // Pass options like cwd
    stdio: ["ignore", "pipe", "pipe"], // stdin, stdout, stderr
  });

  let stdoutData = "";
  let stderrData = "";

  // Listen for stdout data
  if (process.stdout) {
    process.stdout.on("data", (data) => {
      const output = data.toString().trim();
      if (output) {
        console.log(`[STDOUT]: ${output}`);
        stdoutData += output + "\n"; // Accumulate stdout
      }
    });
  }

  // Listen for stderr data
  if (process.stderr) {
    process.stderr.on("data", (data) => {
      const output = data.toString().trim();
      if (output) {
        console.warn(`[STDERR]: ${output}`);
        stderrData += output + "\n"; // Accumulate stderr
      }
    });
  }

  // Return a promise that resolves/rejects when the process finishes
  return new Promise((resolve, reject) => {
    process.on("close", (code) => {
      if (code === 0) {
        // Success
        resolve({ stdout: stdoutData.trim(), stderr: stderrData.trim() });
      } else {
        // Failure
        const error = new Error(
          `Command failed with exit code ${code}: ${command}\n${stderrData.trim()}`
        );
        error.stdout = stdoutData.trim();
        error.stderr = stderrData.trim();
        error.code = code;
        console.error(`[ERROR] Comando falló con código ${code}: ${command}`);
        reject(error);
      }
    });

    // Handle errors during process spawning itself
    process.on("error", (err) => {
      console.error(`[ERROR] Failed to start subprocess: ${command}`, err);
      reject(err);
    });
  });
}

export async function runSimulation(commits, repoUrl) {
  // 1. PROCESAR COMMITS (Primero)
  const commitMap = new Map(commits.map((c) => [c.sha, c]));
  const uniqueShas = [...new Set(commits.map((c) => c.sha))];
  const shasToProcess = [...uniqueShas].reverse();

  // 1. PREPARAR REPOSITORIO
  const repoName = repoUrl.match(/github\.com\/([^/]+)\/([^/.]+)/)[2];
  const repoDir = path.join(REPO_CLONES_DIR, repoName);

  if (!fs.existsSync(repoDir)) {
    console.log(`Inicializando repositorio parcial en ${repoDir}...`);
    fs.mkdirSync(repoDir, { recursive: true });
    await runCommand(`git init`, { cwd: repoDir });
    await runCommand(`git remote add origin ${repoUrl}`, { cwd: repoDir });
    await runCommand(
      `git config set remote.origin.partialCloneFilter blob:none`,
      { cwd: repoDir }
    );
  } else {
    console.log("Repositorio existente encontrado.");
  }

  // 3. FETCH ESPECÍFICO
  console.log(`Haciendo fetch de ${uniqueShas.length} commits específicos...`);
  try {
    await runCommand(
      `git fetch --filter=blob:none origin ${uniqueShas.join(" ")}`,
      { cwd: repoDir }
    );
  } catch (e) {
    console.error(
      "Error al hacer fetch de los commits específicos.",
      e.message
    );
    throw new Error("No se pudieron obtener los commits del remoto.");
  }

  console.log("Análisis en orden cronológico (antiguo -> nuevo)");
  console.log(`Total de commits únicos a procesar: ${shasToProcess.length}`);

  for (const sha of shasToProcess) {
    console.log("================================");
    console.log(`Procesando SHA: ${sha}`);
    // --- a. Crear directorio de salida para este SHA ---
    const currentResultsDir = path.join(RESULTS_DIR, sha);
    fs.mkdirSync(currentResultsDir, { recursive: true });
    console.log(`Resultados se guardarán en: ${currentResultsDir}`);

    try {
      await runCommand(`git checkout --force --quiet ${sha}`, { cwd: repoDir });
      console.log(`  (Checkout de ${sha}... OK)`);
    } catch (e) {
      console.log(`  (FALLO checkout de ${sha}: ${e.message})`);
      continue;
    }
    const setupGoScriptPath = path.join(MAIN_DIR, "setup_go.sh");
    const commit = commitMap.get(sha);
    const parent = commit.parentSha;
    for (const scriptName of ANALYSIS_SCRIPTS) {
      const analysisScriptPath = path.join(MAIN_DIR, scriptName);
      const outFileName = scriptName.replace(".sh", ".out");
      const outputFilePath = path.join(currentResultsDir, outFileName);

      console.log(`--- Ejecutando ${scriptName} ---`);

      const quote = (str) =>
        `"${str.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
      const setupGoCmdPart = `source ${quote(setupGoScriptPath)} ${quote(
        repoDir
      )}`;
      let analysisCmdPart;
      if (scriptName === "churn_2.sh") {
        const parentSha = parent || "";
        analysisCmdPart = `${quote(analysisScriptPath)} ${quote(
          repoDir
        )} ${quote(outputFilePath)} ${quote(parentSha)}`;
      } else {
        analysisCmdPart = `${quote(analysisScriptPath)} ${quote(
          repoDir
        )} ${quote(outputFilePath)}`;
      }
      const fullCommand = `${setupGoCmdPart} && ${analysisCmdPart}`;

      try {
        await runCommand(fullCommand);
        // await runCommand(fullCommand, { shell: "/bin/bash" });
      } catch (scriptError) {
        console.error(
          `FALLO al ejecutar ${scriptName} para el SHA ${sha}: ${scriptError.message}`
        );
      }
    }
    console.log(`--- Limpiando el repositorio (${sha}) ---`);
    try {
      // -f (force), -d (directorios), -x (archivos ignorados)
      await runCommand(`git clean -fdx`, { cwd: repoDir });
      console.log(`  (Limpieza completada)`);
    } catch (cleanError) {
      console.warn(
        `ADVERTENCIA: Falló la limpieza del repo: ${cleanError.message}`
      );
    }
  }

  console.log("================================");

  return {
    message: "Análisis completada.",
    order: "Cronológico (más antiguo a más nuevo)",
    processed_shas: shasToProcess,
    results_path: RESULTS_DIR,
  };
}

export async function runSimulation2(commits, repoUrl, tagName) {
  // 1. PROCESAR COMMITS
  // Ordenamos por fecha para encontrar el más antiguo y el más nuevo
  const sortedCommits = [...commits].sort(
    (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()
  );
  const oldestCommit = sortedCommits[0];
  const newestCommit = sortedCommits[sortedCommits.length - 1];

  // shasToProcess AHORA DEBE ESTAR EN ORDEN (antiguo -> nuevo)
  const shasToProcess = sortedCommits.map((c) => c.sha);
  const commitMap = new Map(commits.map((c) => [c.sha, c]));

  // --- (Calcular la ventana de tiempo para el fetch) ---
  const oldestCommitDate = new Date(oldestCommit.date);
  const fetchSinceDate = new Date(oldestCommitDate);
  // Retrocedemos 9 meses ANTES del commit más antiguo
  fetchSinceDate.setMonth(fetchSinceDate.getMonth() - 9);
  const fetchSinceISO = fetchSinceDate.toISOString();

  console.log(`Commit más antiguo: ${oldestCommit.sha} (${oldestCommit.date})`);
  console.log(`Commit más nuevo:   ${newestCommit.sha} (${newestCommit.date})`);
  console.log(`Se hará fetch del historial desde: ${fetchSinceISO}`);

  // 1. PREPARAR REPOSITORIO
  const repoName = repoUrl.match(/github\.com\/([^/]+)\/([^/.]+)/)[2];
  const repoDir = path.join(REPO_CLONES_DIR, repoName);

  if (!fs.existsSync(repoDir)) {
    console.log(`Inicializando repositorio en ${repoDir}...`);
    fs.mkdirSync(repoDir, { recursive: true });
    await runCommand(`git init`, { cwd: repoDir });
    await runCommand(`git remote add origin ${repoUrl}`, { cwd: repoDir });
  } else {
    console.log("Repositorio existente encontrado.");
  }
  console.log(`Haciendo fetch del historial para el tag ${tagName}...`);
  try {
    // ESTA ES LA LÍNEA QUE DEBES CAMBIAR:
    await runCommand(
      // ANTES:
      // `git fetch --shallow-since="${fetchSinceISO}" origin ${newestCommit.sha}`,

      // AHORA:
      `git fetch --shallow-since="${fetchSinceISO}" origin refs/tags/${tagName}`,

      { cwd: repoDir }
    );
  } catch (e) {
    console.error("Error al hacer fetch del historial del tag.", e.message);
    throw new Error("No se pudo obtener el historial del remoto.");
  }
  // try {
  //   // 1. Trae todo el historial de commits desde la fecha 'fetchSince'
  //   // 2. Trae solo los objetos necesarios para llegar al commit más nuevo
  //   await runCommand(
  //     `git fetch --shallow-since="${fetchSinceISO}" origin ${newestCommit.sha}`,
  //     { cwd: repoDir }
  //   );
  //   //
  //   // NOTA: Esto trae la *rama* que contiene newestCommit.sha.
  //   // Si newestCommit.sha es un tag como v1.34.1, puedes usar el tag:
  //   // `git fetch --shallow-since="${fetchSinceISO}" origin refs/tags/v1.34.1`
  // } catch (e) {
  //   console.error("Error al hacer fetch del historial.", e.message);
  //   throw new Error("No se pudo obtener el historial del remoto.");
  // }
  console.log("Análisis en orden cronológico (antiguo -> nuevo)");
  console.log(`Total de commits a procesar: ${shasToProcess.length}`);

  for (const sha of shasToProcess) {
    console.log("================================");
    console.log(`Procesando SHA: ${sha}`);
    // --- a. Crear directorio de salida para este SHA ---
    const currentResultsDir = path.join(RESULTS_DIR, sha);
    fs.mkdirSync(currentResultsDir, { recursive: true });
    console.log(`Resultados se guardarán en: ${currentResultsDir}`);

    try {
      await runCommand(`git checkout --force --quiet ${sha}`, { cwd: repoDir });
      console.log(`  (Checkout de ${sha}... OK)`);
    } catch (e) {
      console.log(`  (FALLO checkout de ${sha}: ${e.message})`);
      continue;
    }
    const setupGoScriptPath = path.join(MAIN_DIR, "setup_go.sh");
    for (const scriptName of ANALYSIS_SCRIPTS) {
      const analysisScriptPath = path.join(MAIN_DIR, scriptName);
      const outFileName = scriptName.replace(".sh", ".out");
      const outputFilePath = path.join(currentResultsDir, outFileName);

      console.log(`--- Ejecutando ${scriptName} ---`);

      const quote = (str) =>
        `"${str.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
      const setupGoCmdPart = `source ${quote(setupGoScriptPath)} ${quote(
        repoDir
      )}`;
      let analysisCmdPart;

      if (scriptName === "churn_2.sh") {
        analysisCmdPart = `${quote(analysisScriptPath)} ${quote(
          repoDir
        )} ${quote(outputFilePath)}`;
      } else {
        analysisCmdPart = `${quote(analysisScriptPath)} ${quote(
          repoDir
        )} ${quote(outputFilePath)}`;
      }
      const fullCommand = `${setupGoCmdPart} && ${analysisCmdPart}`;

      try {
        await runCommand(fullCommand);
        // await runCommand(fullCommand, { shell: "/bin/bash" });
      } catch (scriptError) {
        console.error(
          `FALLO al ejecutar ${scriptName} para el SHA ${sha}: ${scriptError.message}`
        );
      }
    }
    console.log(`--- Limpiando el repositorio (${sha}) ---`);
    try {
      // -f (force), -d (directorios), -x (archivos ignorados)
      await runCommand(`git clean -fdx`, { cwd: repoDir });
      console.log(`  (Limpieza completada)`);
    } catch (cleanError) {
      console.warn(
        `ADVERTENCIA: Falló la limpieza del repo: ${cleanError.message}`
      );
    }
  }

  console.log("================================");

  return {
    message: "Análisis completada.",
    order: "Cronológico (más antiguo a más nuevo)",
    processed_shas: shasToProcess,
    results_path: RESULTS_DIR,
  };
}
