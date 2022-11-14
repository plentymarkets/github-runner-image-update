#! /bin/bash
# Usage: ./update_image_tag.sh <Repo to be updated> <Release tag> <Applciation Name> <Image Version>

ANNOTATION_PREFIX="auto-update"
CLUSTERS_REL_PAT="eks-clusters"

function clone_repo {
    repo_url="$1"
    dir_name="$2"

    git clone "$repo_url" "$dir_name"
}

REPO_URL="$1"
RELEASE_TAG="$2"
APP="$3"
APP_VERSION="$4"

clone_repo "$REPO_URL" "./manifests"

cd ./manifests
git checkout automation-test # Temporary, remove this

updated="false"

for i in $(ls ${CLUSTERS_REL_PAT})
do
    printf "\nProcessing cluster: ${i}\n"

    kust_path="${CLUSTERS_REL_PAT}/${i}/kustomization.yaml"
    if [[ ! -f "$kust_path" ]]; then
        echo "Error: Cannot find $kust_path"
        continue
    fi

    yq $kust_path > /dev/null
    if [ $? != 0 ]; then
        echo "Error: File $kust_path cannot be parsed"
        continue
    fi

    old_version=$(yq "(.images[] | select(.name == \"*/$APP\") | .newTag)" "${kust_path}")

    if [[ $(yq ".metadata.annotations.${ANNOTATION_PREFIX}/${APP}" ${kust_path}) == "${RELEASE_TAG}" ]]
    then 
        yq -i "(.images[] | select(.name == \"*/$APP\") | .newTag) = \"$APP_VERSION\"" "${kust_path}"

        new_version=$(yq "(.images[] | select(.name == \"*/$APP\") | .newTag)" "${kust_path}")

        if [[ "${old_version}" != "${new_version}" ]]; then
            echo "Updated version for ${APP} from ${old_version} to ${new_version}"
            updated="true"
        else
            echo "Same version was found: ${new_version}. Not updating"
        fi
    else
        echo "Not updated"
    fi

done 

if [[ "$updated" == "true" ]]; then
    echo "Somethhing was updated"

    git add .
    git commit -m "image-update-workflow: Updated app ${APP} for ${RELEASE_TAG} to version ${APP_VERSION}"

    git push
fi
