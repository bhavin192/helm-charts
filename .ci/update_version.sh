#!/bin/bash

set -o errexit -o pipefail

# version_gt compares the given two versions.
# It returns 0 exit code if the version1 is greater than version2.
# https://web.archive.org/web/20191003081436/http://ask.xmodulo.com/compare-two-version-numbers.html
function version_gt() {
  test "$(echo -e "$1\n$2" | sort -V | head -n 1)" != "$1"
}


if [[ $# -ne 1 ]]; then
  echo "No arguments supplied. Please provide the release version" 1>&2
  echo "Terminating the script execution." 1>&2
  exit 1
fi

release_version="$1"
# Version mentioned in Charts.yaml
current_version="$(grep -r "^version" "stable/yugabyte/Chart.yaml" | awk '{ print $2 }')"
if ! version_gt "${release_version}" "${current_version}" ; then
  echo "Release version is either older or equal to the current version: '${release_version}' <= '${current_version}'" 1>&2
  exit 1
fi

# Find Docker image tag respective to YugabyteDB release version
docker_image_tag_regex=[0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+-b[0-9]\+
docker_image_tag="$(python3 ".ci/find_docker_tag.py" "-r" "${release_version}")"
if [[ "${docker_image_tag}" =~ ${docker_image_tag_regex} ]]; then
  echo "Latest Docker image tag for '${release_version}': '${docker_image_tag}'."
else
  echo "Failed to parse the Docker image tag: '${docker_image_tag}'" 1>&2
  exit 1
fi

# Following parameters will be updated in the below-mentioned files:
#  1. ./stable/yugabyte/Chart.yaml	 -   version, appVersion
#  2. ./stable/yugabyte/values.yaml	 -   tag
#  3. ./stable/yugaware/Chart.yaml	 -   version, appVersion
#  4. ./stable/yugaware/values.yaml	 -   tag
#  5. ./stable/yugabyte/app-readme.md	 -   *.*.*.*-b*

files_to_update_version=("stable/yugabyte/Chart.yaml" "stable/yugaware/Chart.yaml")
files_to_update_tag=("stable/yugabyte/values.yaml" "stable/yugaware/values.yaml")
chart_release_version="$(echo "${release_version}" | grep -o '[0-9]\+.[0-9]\+.[0-9]\+')"

# Update appVersion and version in Chart.yaml
for file in "${files_to_update_version[@]}"; do
  echo "Updating file: '${file}' with version: '${chart_release_version}', appVersion: '${docker_image_tag}'"
  sed -i "s/^version: .*/version: ${chart_release_version}/g" "${file}"
  sed -i "s/^appVersion: .*/appVersion: ${docker_image_tag}/g" "${file}"
done

# Update tag in values.yaml
for file in "${files_to_update_tag[@]}"; do
  echo "Updating file: '${file}' with tag: '${docker_image_tag}'"
  sed -i "s/^  tag: .*/  tag: ${docker_image_tag}/g" "${file}"
done

# Update version number in stable/yugabyte/app-readme.md
echo "Updating file: 'stable/yugabyte/app-readme.md' with version: '${docker_image_tag}'"
sed -i "s/[0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+-b[0-9]\+/${docker_image_tag}/g" "stable/yugabyte/app-readme.md"
