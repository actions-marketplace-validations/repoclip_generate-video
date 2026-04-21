# RepoClip Generate Video Action

Generate a promotional video for your GitHub repository with AI-powered narration, visuals, and music using [RepoClip](https://repoclip.io).

## Usage

```yaml
name: Generate Demo Video
on:
  release:
    types: [published]

jobs:
  video:
    runs-on: ubuntu-latest
    steps:
      - uses: TwistTheoryGames/generate-video@v1
        id: video
        with:
          api-key: ${{ secrets.REPOCLIP_API_KEY }}
          mode: image
          prompt: "Highlight the new features in this release"

      - name: Add video to release
        if: steps.video.outputs.status == 'completed'
        uses: actions/github-script@v7
        with:
          script: |
            const body = context.payload.release.body || '';
            github.rest.repos.updateRelease({
              owner: context.repo.owner,
              repo: context.repo.repo,
              release_id: context.payload.release.id,
              body: body + '\n\n---\n[Watch demo video](${{ steps.video.outputs.share-url }})'
            });
```

## Setup

1. Sign up at [repoclip.io](https://repoclip.io)
2. Go to **Dashboard > Settings** and generate an API key
3. Add the key as a repository secret named `REPOCLIP_API_KEY`

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `api-key` | Yes | — | RepoClip API key |
| `github-url` | No | Current repo | Target repository URL |
| `mode` | No | `image` | `image`, `video_short`, or `video_long` |
| `prompt` | No | — | Custom instructions (max 500 chars) |
| `aspect-ratio` | No | `16:9` | `16:9`, `9:16`, or `1:1` |
| `visual-style` | No | `tech` | `tech`, `realistic`, `minimal`, `vibrant` |
| `bgm` | No | `false` | Enable background music (+20 credits) |
| `poll-interval` | No | `30` | Seconds between status checks |
| `timeout` | No | `1200` | Max wait time in seconds |

## Outputs

| Name | Description |
|------|-------------|
| `project-id` | UUID of the created project |
| `video-url` | URL of the completed video |
| `thumbnail-url` | URL of the video thumbnail |
| `share-url` | Public share page URL |
| `status` | `completed` or `failed` |

## Credit Costs

| Mode | Credits |
|------|---------|
| Image | 10 |
| Video Short | 40 |
| Video Long | 300 |
| BGM addon | +20 |

Buy credits at [repoclip.io/pricing](https://repoclip.io/pricing) or get a one-time Credit Pack ($5 / 40 credits).

## License

MIT
