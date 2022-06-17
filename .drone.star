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
          "registry": {"from_secret": "registry_url"},
          "login": {"from_secret": "registry_login"},
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
          "src_registry": {"from_secret": "registry_url"},
          "src_login": {"from_secret": "registry_login"},
          "src_username": {"from_secret": "registry_username"},
          "src_password": {"from_secret": "registry_password"},
          "dest_repo": repo,
          "dest_login": {"from_secret": "docker_login"},
          "insecure": "true",
        },
        "when": {
          "branch": ["master"],
          "event": ["push"],
        },
      },
    ]
  }
