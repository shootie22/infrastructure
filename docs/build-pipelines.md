# Build Pipelines

This is a simple explanation of how your container build pipelines work.

The cleanest example is [`pinga`](../../pinga/.gitea/workflows/build-and-push-container-image.yaml). It shows the basic pattern clearly:

1. CI starts on a push, tag, or manual run.
2. The workflow decides what image name and tags to use.
3. It logs in to the container registry.
4. It prepares Docker `buildx` for multi-architecture builds.
5. It builds the image and pushes it to the registry.

In short: source code goes in, CI builds a Docker image, and the image is uploaded to your container registry.

## The Main Example: `pinga`

The workflow starts with its triggers:

```yaml
on:
  push:
    branches:
      - main
      - master
    tags:
      - "*"
  workflow_dispatch:
```

What this means:

- A normal push to `main` or `master` can publish an image.
- A Git tag can publish a versioned image.
- `workflow_dispatch` lets you run it manually from the CI UI.

Why it is done this way:

- Branch pushes are convenient for keeping `latest` up to date.
- Tag pushes are useful for real releases like `v1.2.3`.
- Manual runs are useful when you want to retry or publish without making a fake commit.

An alternative:

- You could publish only on tags. That is stricter and more release-oriented, but slower for day-to-day iteration because every published image would require a tag.

### Step 1: Check Out The Repository

```yaml
- name: Checkout
  uses: https://gitea.com/actions/checkout@v4
```

This pulls the repository contents into the CI runner so Docker has files to build from.

Why use an action here:

- It is the standard, simple way to get the repo into the runner.
- It avoids manually scripting `git clone` in most cases.

An alternative:

- Manual `git fetch` and `git checkout`.
- That gives more control, but it is more verbose and easier to get wrong.

### Step 2: Compute Image Metadata

This is the most important "glue" step in the pipeline:

```yaml
- name: Compute image metadata
  id: meta
  run: |
    registry="${{ gitea.server_url }}"
    registry="${registry#https://}"
    image="${registry}/${{ gitea.repository }}"

    ref="${{ gitea.ref }}"
    commit="${{ gitea.sha }}"
    short_commit="$(printf '%s' "$commit" | cut -c1-7)"
    version="dev-${short_commit}"

    case "$ref" in
      refs/heads/main|refs/heads/master)
        tags="${image}:latest"
        ;;
      refs/tags/*)
        tag="${ref#refs/tags/}"
        version="$tag"
        tags="${image}:${tag},${image}:latest"
        ;;
    esac
```

What this does:

- It figures out the registry hostname from the CI environment.
- It builds the full image name, for example `git.radunenu.com/radu/pinga`.
- It looks at the Git ref that triggered the workflow.
- If the trigger was a branch push, it uses `latest`.
- If the trigger was a Git tag, it uses both the version tag and `latest`.

Simple example:

- Push to `main` -> image tag becomes `git.radunenu.com/radu/pinga:latest`
- Push tag `v1.4.0` -> image tags become `git.radunenu.com/radu/pinga:v1.4.0` and `git.radunenu.com/radu/pinga:latest`

Why this is useful:

- The workflow becomes reusable and does not hardcode release values.
- The image tag matches the Git event that produced it.
- Release images are traceable to a commit and version.

An alternative:

- Hardcode a single tag like `latest` and always push that.
- That is simpler, but worse for traceability because you lose clear versioned images.

### Step 3: Log In To The Container Registry

```yaml
- name: Log in to container registry
  env:
    REGISTRY: ${{ steps.meta.outputs.registry }}
    CONTAINER_USER: ${{ secrets.CONTAINER_USER }}
    CONTAINER_PASSWORD: ${{ secrets.CONTAINER_PASSWORD }}
  run: |
    printf '%s' "$CONTAINER_PASSWORD" | docker login "$REGISTRY" -u "$CONTAINER_USER" --password-stdin
```

What this does:

- It authenticates Docker to your registry before pushing.

Why it is done this way:

- CI should use secrets, not hardcoded credentials.
- `--password-stdin` is safer than putting the password directly on the command line.
- The registry name comes from the earlier metadata step, so the workflow stays portable.

An alternative:

- Use a dedicated Docker login action.
- That can be cleaner, but a plain `docker login` command is transparent and easy to debug.

### Step 4: Prepare `buildx` For Multi-Arch Builds

```yaml
- name: Configure buildx for multi-arch
  run: |
    docker run --privileged --rm tonistiigi/binfmt --install all
    docker buildx rm pinga-multiarch >/dev/null 2>&1 || true
    docker buildx create --name pinga-multiarch --use
    docker buildx inspect --bootstrap
```

What this does:

- Installs emulation support for other CPU architectures.
- Creates a temporary `buildx` builder.
- Boots that builder so it is ready to build for more than one platform.

Why it is done this way:

- A normal `docker build` is usually only for the runner's native architecture.
- `buildx` is the usual Docker way to build a single image manifest for several platforms.
- That matters when you deploy to mixed hardware like `amd64`, `arm64`, and sometimes `arm/v7`.

An alternative:

- Use plain `docker build` and publish only `linux/amd64`.
- That is simpler and faster, but it will not work on ARM hosts without a separate build.

### Step 5: Build And Push The Image

```yaml
- name: Build and push image
  env:
    TAGS: ${{ steps.meta.outputs.tags }}
    PLATFORMS: linux/amd64,linux/arm64,linux/arm/v7
  run: |
    docker buildx build \
      --platform "$PLATFORMS" \
      --build-arg "VERSION=${VERSION}" \
      --build-arg "COMMIT=${COMMIT}" \
      --build-arg "BUILD_DATE=${BUILD_DATE}" \
      "$@" \
      --push \
      .
```

What this does:

- Builds the image from the local `Dockerfile`.
- Builds it for multiple architectures.
- Adds metadata into the build with `VERSION`, `COMMIT`, and `BUILD_DATE`.
- Pushes the finished image directly to the registry.

Why `buildx build --push` is used:

- Multi-arch publishing usually happens directly through `buildx`.
- The final result is not just one image, but a manifest that points to per-architecture images.

Why the build args are useful:

- The running container can expose version info.
- You can trace a pushed image back to the exact commit.
- Debugging production becomes easier.

An alternative:

- Build locally first with `docker build`, then push with `docker push`.
- That works well for a simple single-arch image, but it is not the usual pattern for multi-arch output.

## Are There Tests In This Pipeline?

In `pinga`, not really.

There is no explicit test job and no smoke-test step in this workflow. The pipeline is mainly a publish pipeline:

- it checks out code
- prepares tags
- builds the container
- pushes it

So the main validation is: "does the image build successfully?"

That is enough for a small, straightforward service if the Docker build itself already fails on broken code. It is not full runtime validation.

## How Other Repos Differ

The overall shape stays the same, but some repos add more safety or more release logic.

### `radunenu.com`: Same Pattern, More Safety

[`radunenu.com`](../../radunenu.com/.gitea/workflows/build-and-push-container-image.yaml) uses the same basic pipeline, but adds a smoke test before publishing.

Example:

```yaml
- name: Build and smoke-test container
  run: |
    docker build -t "${SMOKE_CONTAINER_NAME}:local" .
    docker run -d --name "$SMOKE_CONTAINER_NAME" "${SMOKE_CONTAINER_NAME}:local"
    ./docker/smoke-routes.sh "$SMOKE_CONTAINER_NAME"
```

Why add this:

- A container can build successfully but still fail at runtime.
- A smoke test catches obvious startup and routing problems before the image is published.

Why not every repo does this:

- It makes the workflow longer.
- It adds maintenance cost.
- Small services may prefer a simpler pipeline.

It also builds a second image, `snapshot-poller`, in the same workflow. That is useful when one repo ships more than one container artifact.

### `picshare`: Same Idea, More "Action-Based"

[`picshare`](../../picshare/.gitea/workflows/publish-container.yaml) does the same job using more ready-made Docker actions:

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3

- name: Set up Buildx
  uses: docker/setup-buildx-action@v3
```

Why do it this way:

- It is shorter.
- The Docker setup logic is mostly outsourced to maintained actions.

Why `pinga` might still be preferable as a teaching example:

- `pinga` is more explicit.
- You can see exactly what happens instead of hiding it behind actions.
- That makes it easier to learn from.

### `matrix-webhook-bot`: Release Logic First, Container Second

[`matrix-webhook-bot`](../../matrix-webhook-bot/.gitea/workflows/container.yml) first computes the next version tag and can create that Git tag through the Gitea API before building the image.

That means its pipeline is not just "build container now." It is closer to:

1. decide release version
2. create or reuse a Git tag
3. build container for that release
4. push the image

Why do this:

- It ties image publishing tightly to release versioning.
- It reduces manual release steps.

Why it is more complex:

- It needs tag-management logic.
- It needs API access to create tags.
- It is more than a straightforward container publish job.

## Why The Pipelines Look Like This

The current structure makes sense for your setup:

- The pipelines publish from CI so releases do not depend on one developer's laptop.
- Tags and commit metadata make images traceable.
- `buildx` is used because some services may need to run on different CPU architectures.
- Secrets are injected by CI so credentials stay out of the repo.
- Simpler repos use a lean publish-only workflow.
- More important or more complex repos add smoke tests before pushing.

If you wanted a different style, the main alternatives would be:

- Tag-only publishing for stricter release control
- single-architecture builds for a simpler and faster pipeline
- separate test and publish jobs, where publish depends on tests
- more use of canned setup actions instead of explicit shell commands

The current approach is a pragmatic middle ground: simple enough to maintain, but structured enough to publish reproducible container images from CI.
