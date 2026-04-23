# Pre-fill Files

Pre-fill files let someone set up this system for another person by pre-loading org context. Claude detects them during onboarding and uses them instead of asking questions.

## How to Use

1. Create a `.md` file in the project root (not in this `examples/` folder)
2. Name it after the person (e.g., `alex-chen.md`)
3. Fill in their org details using the format below
4. When the recipient opens Claude Code, Claude reads the pre-fill and confirms: "I have you as Alex Chen, VP Solutions Engineering, with 6 direct reports..."

## Format

```markdown
# Pre-fill: [Person Name]

## Identity
- **Name:** [Full name]
- **Title:** [Title]
- **Company:** [Company]
- **Org name:** [What their org is called]
- **Location:** [City, State]
- **Timezone:** [e.g., Eastern]

## Reporting Chain
- **Reports to:** [Boss name] ([Boss title])
- **Skip-level:** [Skip name] ([Skip title])

## Direct Reports
| Name | Title | Team/Product | Location |
|------|-------|-------------|----------|
| [Name] | [Title] | [Team] | [Location] |

## Product Lines
- [Product/service 1]
- [Product/service 2]

## Scope
- **Team size:** [Total ICs + managers]
- **Scope variant:** VP (30+ people) | Director (10-20 people)

## Notes for Claude
- [Any context about their work style, priorities, or setup preferences]
```

## Examples

- `sample-vp.md` — Fictional VP with 6 directs, 45 people, multiple product lines
- `sample-director.md` — Fictional Director with 4 directs, 15 people, single product line
