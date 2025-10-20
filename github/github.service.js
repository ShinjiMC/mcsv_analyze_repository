import fetch from "node-fetch";
import dotenv from "dotenv";
import fs from "fs";
dotenv.config();

const GITHUB_API = "https://api.github.com/graphql";
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;

if (!GITHUB_TOKEN) {
  console.error("No se encontró GITHUB_TOKEN en variables de entorno.");
  process.exit(1);
}

function parseRepoUrl(repoUrl) {
  const match = repoUrl.match(/github\.com\/([^/]+)\/([^/.]+)/);
  if (!match) throw new Error("URL de repositorio no válida.");
  return { owner: match[1], repo: match[2] };
}

async function graphqlRequest(query, variables = {}) {
  const resp = await fetch(GITHUB_API, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      "User-Agent": "CommitMeshBot/1.1",
    },
    body: JSON.stringify({ query, variables }),
  });

  const data = await resp.json();
  if (!resp.ok || data.errors) {
    console.error(
      "GraphQL error:",
      JSON.stringify(data.errors || data, null, 2)
    );
    throw new Error("GraphQL query failed");
  }
  return data.data;
}

export async function buildCommitTag(repoUrl, tagName) {
  const { owner, repo } = parseRepoUrl(repoUrl);
  console.log(`Buscando commit base del tag ${tagName}...`);

  // 🔹 1. Obtener commit asociado al tag
  const rootQuery = `
  query($owner: String!, $repo: String!, $tag: String!) {
    repository(owner: $owner, name: $repo) {
      ref(qualifiedName: $tag) {
        target {
          ... on Commit {
            oid
            committedDate
            messageHeadline
          }
          ... on Tag {
            target {
              ... on Commit {
                oid
                committedDate
                messageHeadline
              }
            }
          }
        }
      }
    }
  }
`;

  const rootData = await graphqlRequest(rootQuery, {
    owner,
    repo,
    tag: tagName,
  });
  const rootTarget =
    rootData.repository?.ref?.target?.target ||
    rootData.repository?.ref?.target;
  const rootCommitSha = rootTarget?.oid;
  const rootDate = new Date(rootTarget?.committedDate);
  const rootMessage = rootTarget?.messageHeadline || tagName;

  if (!rootCommitSha)
    throw new Error(`No se pudo obtener el commit base de ${tagName}.`);

  // 🔹 2. Calcular fecha límite (5 meses antes)
  const since = new Date(rootDate);
  since.setMonth(since.getMonth() - 5);
  const sinceISO = since.toISOString();
  console.log(
    `Extrayendo commits desde ${sinceISO} (5 meses antes de ${rootDate.toISOString()})`
  );

  // 🔹 3. Consulta con paginación (ahora incluye messageHeadline)
  const commitsQuery = `
  query($owner: String!, $repo: String!, $sha: String!, $since: GitTimestamp!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      object(expression: $sha) {
        ... on Commit {
          history(since: $since, first: 100, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              oid
              committedDate
              messageHeadline
            }
          }
        }
      }
    }
  }
`;

  let hasNextPage = true;
  let endCursor = null;
  const allCommits = [];
  const MAX_COMMITS = 10;

  while (hasNextPage && allCommits.length < MAX_COMMITS) {
    const data = await graphqlRequest(commitsQuery, {
      owner,
      repo,
      sha: rootCommitSha,
      since: sinceISO,
      cursor: endCursor,
    });

    const history = data.repository?.object?.history;
    const nodes = history?.nodes || [];

    allCommits.push(...nodes);

    if (allCommits.length >= MAX_COMMITS) {
      console.log(`Límite alcanzado: ${MAX_COMMITS} commits.`);
      allCommits.splice(MAX_COMMITS);
      break;
    }

    hasNextPage = history?.pageInfo?.hasNextPage;
    endCursor = history?.pageInfo?.endCursor;

    console.log(`${allCommits.length} commits acumulados...`);
    if (!hasNextPage) break;
  }

  // 🔹 4. Construir malla con messageHeadline
  const results = allCommits.map((c, i) => ({
    sha: c.oid,
    parentSha: allCommits[i + 1]?.oid || null,
    childSha: allCommits[i - 1]?.oid || null,
    date: c.committedDate,
    name: c.messageHeadline || null,
  }));

  if (results.length > 0) {
    results[0].name = rootMessage || tagName;
  }

  console.log(
    `${
      results.length
    } commits obtenidos desde ${sinceISO} hasta ${rootDate.toISOString()}`
  );

  // 🔹 5. Guardar en archivo
  const outFile = `${repo}_${tagName.replace(/\//g, "_")}.json`;
  fs.writeFileSync(outFile, JSON.stringify(results, null, 2), "utf8");
  console.log(`Guardado en ${outFile}`);

  return results;
}
