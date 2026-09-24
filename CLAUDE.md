# PCA Flutter Operator

Tercen Flutter web app built using the 3-phase skill system.

## Skills

Skills are in `.claude/skills/`. Full documentation: `.claude/skills/README.md`

### Phase workflow

| Phase | Skill | Input | Output |
| ----- | ----- | ----- | ------ |
| 1 | `.claude/skills/skills/phase-1-functional-spec.md` | User requirements, screenshots, existing code | Functional spec markdown |
| 2 | `.claude/skills/skills/phase-2-mock-build.md` | Functional spec + `.claude/skills/skeleton/` | Running Flutter app with mock data |
| 3 | `.claude/skills/skills/phase-3-tercen-integration.md` | Working mock app + taskId | Deployed app in Tercen |

### Rules

- **One skill per session.** Do not load multiple phase skills in the same session.
- Phase 1 output (functional spec) bridges to Phase 2.
- Phase 2 output (working mock app) bridges to Phase 3.
- Do NOT modify the skeleton structure. Copy it, rename it, replace placeholders.
- Skills are READ-ONLY during app builds. Log gaps in `_local/skill-feedback.md`.

## Project structure

```
pca_flutter_operator/
├── .claude/
│   ├── settings.local.json
│   └── skills/              <- tercen-flutter-skills repo
│       ├── README.md
│       ├── skills/          <- phase skill documents
│       ├── skeleton/        <- runnable Flutter app template
│       ├── _feedback/
│       └── reviews/
├── _local/
│   └── Example Data/
└── CLAUDE.md                <- this file
```

## Critical gotchas

- Hot reload does NOT work for Flutter web. Always stop and restart.
- Build with `flutter build web --wasm`
- `build/web/` must be committed (Tercen serves from it)
- index.html line 17 must stay commented: `<!--<base href="$FLUTTER_BASE_HREF"> -->`
- Never use manual HTTP calls — always use `sci_tercen_client` (CORS)
- Plan mode required for all non-trivial features

## Scale PCA demo dataset

To demonstrate the visible effect of the Scale PCA toggle, show the user
`lib/implementations/services/mock_data_service_scale_demo.dart`.
Swap it in as the mock service in `lib/di/service_locator.dart` temporarily.
Without scaling: BatchX/Y/Z/W variables (±100 scale) dominate PC1, groups not separated.
With scaling: GeneA-D variables (~5 scale) dominate, three groups (A/B/C) separate cleanly.
**Revert to the original `MockDataService` after the demo.**

## Reference projects

- `C:\Users\Work\Documents\GitHub\mean_and_cv_flutter_operator` — working Type 1 app
- `C:\Users\Work\Documents\GitHub\pamsoft_grid_flutter_operator` — working Type 1 app
- `C:\Users\Work\Documents\GitHub\ps12_image_overview_flutter_operator` — working Type 1 app
