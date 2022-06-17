repo = "spritsail/docker-multiarch-publish"
architectures = ["amd64", "arm64"]

def main(ctx):
  builds = []
  depends_on = []

  for arch in architectures:
    key = "build-%s" % arch
    builds.append(step(key, arch))
    depends_on.append(key)
  builds.append(publish(depends_on))

  return builds

def step(key, arch):
  tmprepo = "drone/%s/${DRONE_BUILD_NUMBER}:%s" % (repo, arch)
  return {
    "kind": "pipeline",
    "name": key,
    "platform": {
      "os": "linux",
      "arch": arch,
    },
    "steps": [
      {
        "name": "build",
        "image": "spritsail/docker-build",
        "pull": "always",
        "settings": {
          "repo": tmprepo,
        },
      },
      {
        "name": "publish",
        "pull": "always",
        "image": "spritsail/docker-publish",
        "settings": {
          "from": tmprepo,
          "repo": tmprepo,
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
    "platform": {
      "os": "linux",
    },
    "steps": [
      {
        "name": "publish",
        "image": "registry.spritsail.io/drone/%s/${DRONE_BUILD_NUMBER}:${DRONE_STAGE_ARCH}" % repo,
        "pull": "always",
        "settings": {
          "src_template": "drone/%s/${DRONE_BUILD_NUMBER}:ARCH" % repo,
          "src_registry": {"from_secret": "registry_url"},
          "src_login": {"from_secret": "registry_login"},
          "src_username": {"from_secret": "registry_username"},
          "src_password": {"from_secret": "registry_password"},
          "dest_repo": repo,
          "dest_login": {"from_secret": "docker_login"},
        },
        "when": {
          "branch": ["master"],
          "event": ["push"],
        },
      },
    ],
    "image_pull_secrets": [
      "registryauthjson",
    ],
  }
