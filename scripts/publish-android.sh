#!/usr/bin/env bash

# Plugins base location
DIR=..

# Get the latest version of Capacitor
CAPACITOR_PACKAGE_JSON="https://raw.githubusercontent.com/ionic-team/capacitor/main/android/package.json"
CAPACITOR_VERSION=$(curl -s $CAPACITOR_PACKAGE_JSON | awk -F\" '/"version":/ {print $4}')

# Don't continue if there was a problem getting the latest version of Capacitor
if [[ $CAPACITOR_VERSION ]]; then
    printf %"s\n\n" "Attempting to publish new plugins with dependency on Capacitor Version $CAPACITOR_VERSION"
else
    printf %"s\n\n" "Error resolving latest Capacitor version from $CAPACITOR_PACKAGE_JSON"
    exit 1
fi

for f in "$DIR"/*; do
    if [ -d "$f" ]; then
        # Android dir path
        ANDROID_PATH=$f/android

        # Only try to publish if the directory contains a package.json and android package
        if test -f "$f/package.json" && test -d "$ANDROID_PATH"; then
            PLUGIN_VERSION=$(grep '"version": ' "$f"/package.json | awk '{print $2}' | tr -d '",')
            PLUGIN_NAME=$(grep '"name": ' "$f"/package.json | awk '{print $2}' | tr -d '",')
            PLUGIN_NAME=${PLUGIN_NAME#@capacitor/}
            LOG_OUTPUT=./tmp/$PLUGIN_NAME.txt

            # Make log dir if doesnt exist
            mkdir -p ./tmp

            printf %"s\n\n" "Attempting to build and publish plugin $PLUGIN_NAME for version $PLUGIN_VERSION"

            # Export ENV variables used by Gradle for the plugin
            export PLUGIN_NAME
            export PLUGIN_VERSION

            # Insert the Capacitor Core dependency version
            sed -i "s/%%CAPACITOR_VERSION%%/$CAPACITOR_VERSION/" $ANDROID_PATH/build.gradle

            cat $ANDROID_PATH/build.gradle

            # Build and publish
            "$ANDROID_PATH"/gradlew clean build publishAllPublicationsToGithubPackagesRepository -b "$ANDROID_PATH"/build.gradle -Pandroid.useAndroidX=true -Pandroid.enableJetifier=true > "$LOG_OUTPUT" 2>&1

            if grep --quiet "Conflict" "$LOG_OUTPUT"; then
                printf %"s\n\n" "Duplicate: a published plugin $PLUGIN_NAME exists for version $PLUGIN_VERSION, skipping."
            else
                if grep --quiet "BUILD SUCCESSFUL" "$LOG_OUTPUT"; then
                    printf %"s\n\n" "Success: $PLUGIN_NAME version $PLUGIN_VERSION published."
                else
                    printf %"s\n\n" "Error publishing $PLUGIN_NAME, check $LOG_OUTPUT for more info!"
                    cat $LOG_OUTPUT
                    exit 1
                fi
            fi
        else
            printf %"s\n\n" "$f has no package.json file or Android package, skipping..."
        fi
    fi
done
