# Microservicio Get and Analysis Repositorio

└─[$] <> curl -X POST http://localhost:4000/github/refs \
 -H "Content-Type: application/json" \
 -d '{"repoUrl": "https://github.com/kubernetes/kubernetes", "type": "tags"}'
{"type":"tags","refs":["v1.35.0-alpha.1","v1.35.0-alpha.0","v1.34.1","v1.34.0","v1.34.0-rc.2","v1.34.0-rc.1","v1.34.0-rc.0","v1.34.0-beta.0","v1.34.0-alpha.3","v1.34.0-alpha.2","v1.34.0-alpha.1","v1.34.0-alpha.0","v1.33.5","v1.33.4","v1.33.3","v1.33.2","v1.33.1","v1.33.0","v1.33.0-rc.1","v1.33.0-rc.0","v1.33.0-beta.0","v1.33.0-alpha.3","v1.33.0-alpha.2","v1.33.0-alpha.1","v1.33.0-alpha.0","v1.32.9","v1.32.8","v1.32.7","v1.32.6","v1.32.5","v1.32.4","v1.32.3","v1.32.2","v1.32.1","v1.32.0","v1.32.0-rc.2","v1.32.0-rc.1","v1.32.0-rc.0","v1.32.0-beta.0","v1.32.0-alpha.3","v1.32.0-alpha.2","v1.32.0-alpha.1","v1.32.0-alpha.0","v1.31.13","v1.31.12","v1.31.11","v1.31.10","v1.31.9","v1.31.8","v1.31.7","v1.31.6","v1.31.5","v1.31.4","v1.31.3","v1.31.2","v1.31.1","v1.31.0","v1.31.0-rc.1","v1.31.0-rc.0","v1.31.0-beta.0","v1.31.0-alpha.3","v1.31.0-alpha.2","v1.31.0-alpha.1","v1.31.0-alpha.0","v1.30.14","v1.30.13","v1.30.12","v1.30.11","v1.30.10","v1.30.9","v1.30.8","v1.30.7","v1.30.6","v1.30.5","v1.30.4","v1.30.3","v1.30.2","v1.30.1","v1.30.0","v1.30.0-rc.2","v1.30.0-rc.1","v1.30.0-rc.0","v1.30.0-beta.0","v1.30.0-alpha.3","v1.30.0-alpha.2","v1.30.0-alpha.1","v1.30.0-alpha.0","v1.29.15","v1.29.14","v1.29.13","v1.29.12","v1.29.11","v1.29.10","v1.29.9","v1.29.8","v1.29.7","v1.29.6","v1.29.5","v1.29.4","v1.29.3"]}%

└─[$] <> curl -X POST http://localhost:4000/github/refs \
 -H "Content-Type: application/json" \
 -d '{"repoUrl": "https://github.com/kubernetes/kubernetes", "type": "branches"}'
{"type":"branches","refs":["feature-rate-limiting","feature-serverside-apply","feature-workload-ga","master","release-0.4","release-0.5","release-0.6","release-0.7","release-0.8","release-0.9","release-0.10","release-0.12","release-0.13","release-0.14","release-0.15","release-0.16","release-0.17","release-0.18","release-0.19","release-0.20","release-0.21","release-1.0","release-1.1","release-1.2","release-1.3","release-1.4","release-1.5","release-1.6","release-1.6.3","release-1.7","release-1.8","release-1.9","release-1.10","release-1.11","release-1.12","release-1.13","release-1.14","release-1.15","release-1.16","release-1.17","release-1.18","release-1.19","release-1.20","release-1.21","release-1.22","release-1.23","release-1.24","release-1.25","release-1.26","release-1.27","release-1.28","release-1.29","release-1.30","release-1.31","release-1.32","release-1.33","release-1.34","revert-121614-decode-respect-timeout-context"]}

curl -X POST http://localhost:4000/github/linetime \
 -H "Content-Type: application/json" \
 -d '{
"repoUrl": "https://github.com/kubernetes/kubernetes",
"selectionType": "branch",
"selectionName": "master"
}' | jq

curl -X POST http://localhost:4000/github/list \
 -H "Content-Type: application/json" \
 -d '{
"repoUrl": "https://github.com/kubernetes/kubernetes",
"selectionName": "v1.34.1"
}' | jq

curl -X POST http://localhost:4000/github/mesh \
 -H "Content-Type: application/json" \
 -d '{"repoUrl":"https://github.com/kubernetes/kubernetes"}' | jq

curl -X POST http://localhost:4000/analyze/simulate \
 -H "Content-Type: application/json" \

    "repoUrl": "https://github.com/kubernetes/kubernetes",

-d @kubernetes_v1.34.1.json \
 | jq

curl -X POST http://localhost:4000/github/list \
 -H "Content-Type: application/json" \
 -d '{
"repoUrl": "https://github.com/kubernetes/kubernetes",
"selectionName": "v1.34.1"
}' | jq

jq -n \
 --arg repoUrl "https://github.com/kubernetes/kubernetes" \
 --slurpfile commits kubernetes_v1.34.1.json \
 '{$repoUrl, commits: $commits[0]}' | \
curl -X POST http://localhost:4000/analyze/simulate \
 -H "Content-Type: application/json" \
 -d @- \
 | jq

./churn.sh /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/kubernetes /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/1.31.4/churn.out 8c0988abb62c6e4fa13be86c56a38ed083978ecb

./coupling.sh /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/kubernetes /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/1.31.4/coupling.out

./cohesion.sh /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/kubernetes /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/1.31.4/cohesion.out

./complexity.sh /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/kubernetes /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/1.31.4/complexity.out

./lint.sh /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/kubernetes /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/1.31.4/lint.out

./coverage.sh /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/kubernetes /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/1.31.4/coverage.out

source ./setup_go.sh /home/shinji/Escritorio/Proyectos/.code-analysis-workspace/analysis_clones/kubernetes

grep -v " 0 0 0$" churn.out
