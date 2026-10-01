# Issue tracker: GitHub

Issues e specs deste repo vivem como GitHub issues em **dihcruz1/adr-std**.
Use o CLI `gh` para todas as operações.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use heredoc para bodies multiline.
- **Read an issue**: `gh issue view <number> --comments`, filtrando comentários com `jq` e labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` com `--label` e `--state` conforme necessário.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

O repo é inferido de `git remote -v`; o `gh` faz isso automaticamente dentro de um clone.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## When a skill says "publish to the issue tracker"

Crie um GitHub issue.

## When a skill says "fetch the relevant ticket"

Execute `gh issue view <number> --comments`.

## Wayfinding operations

Usadas pelo `/wayfinder`. O **map** é uma issue única com **child** issues como tickets.

- **Map**: issue com label `wayfinder:map`. `gh issue create --label wayfinder:map`.
- **Child ticket**: issue vinculada ao map como sub-issue do GitHub. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`).
- **Blocking**: dependências nativas do GitHub. `gh api --method POST repos/dihcruz1/adr-std/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`.
- **Frontier query**: `gh issue list --state open` com sub-issues do map, descartando os com blockers abertos ou assignee.
- **Claim**: `gh issue edit <n> --add-assignee @me`.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, então `gh issue close <n>`.
