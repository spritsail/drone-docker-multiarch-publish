name = "multiarch-publish"
repo = "spritsail/docker-multiarch-publish"
architectures = ["amd64", "arm64"]

def main(ctx):
  builds = []
  depends_on = []

  for arch in architectures:
    builds.append(step(arch))
    depends_on.append("%s-%s" % (name, arch))
  builds.append(publish(depends_on))

  return builds

def step(arch):
  return {
    "kind": "pipeline",
    "name": "%s-%s" % (name, arch),
    "platform": {
      "os": "linux",
      "arch": arch,
    },
    "steps": [
      {
        "name": "build",
        "image": "spritsail/docker-build",
        "pull": "always",
      },
      {
        "name": "publish",
        "pull": "always",
        "image": "spritsail/docker-publish",
        "settings": {
          "repo": "%s:%s" % (repo, arch),
          "registry": {"from_secret": "docker_registry"},
          "username": {"from_secret": "docker_username"},
          "password": {"from_secret": "docker_password"},
        },
        "when": {
          "branch": ["master"],
          "event": ["push"],
        },
      },
    ]
  }

def publish(depends_on):
  return {
    "kind": "pipeline",
    "name": "publish-manifest",
    "depends_on": depends_on,
    "steps": [
      {
        "name": "publish",
        "image": "spritsail/docker-multiarch-publish",
        "pull": "always",
        "settings": {
          "src_template": "%s:ARCH" % repo,
          "src_registry": {"from_secret": "docker_registry"},
          "dest_repo": repo,
          "dest_username": {"from_secret": "docker_username"},
          "dest_password": {"from_secret": "docker_password"},
          "insecure": "true",
        },
        "when": {
          "branch": ["master"],
          "event": ["push"],
        },
      },
    ]
  }
