#!/bin/bash
#set -o nounset -o errexit -o pipefail
 
DOMINO_SAS_CONFIG_DIR="${DOMINO_WORKING_DIR}/sasconfig"
DOMINO_SASSTUDIO_AUTOEXEC_FILE="${DOMINO_SAS_CONFIG_DIR}/sasstudio-autoexec.sas"
DOMINO_SAS_SNIPPETS_DIR="${DOMINO_SAS_CONFIG_DIR}/snippets"
DOMINO_SAS_TASKS_DIR="${DOMINO_SAS_CONFIG_DIR}/tasks"
DOMINO_SAS_PREFERENCES_DIR="${DOMINO_SAS_CONFIG_DIR}/preferences"
DOMINO_SAS_KEYBOARDSHORTCUTS_DIR="${DOMINO_SAS_CONFIG_DIR}/keyboardShortcuts"
DOMINO_SAS_STATE_DIR="${DOMINO_SAS_CONFIG_DIR}/state"
DOMINO_GIT_REPOS_PATH=/repos
DOMINO_DATASETS_PATH=/domino/datasets
SAS_STUDIO_CONFIG_FILE=/opt/sas/viya/config/etc/sasstudio/default/init_usermods.properties
SAS_AUTOEXEC_DIR="$HOME/.sasstudio5"
SAS_STUDIO_AUTOEXEC_FILE="${SAS_AUTOEXEC_DIR}/.autoexec.sas"
SAS_SHORTCUTS_DIR="$HOME/.sasstudio5"
SAS_SHORTCUTS_FILE="${SAS_SHORTCUTS_DIR}/shortcuts.xml"
SAS_SNIPPETS_DIR="$HOME/.sasstudio5/mySnippets"
SAS_TASKS_DIR="$HOME/.sasstudio5/myTasks"
SAS_PREFERENCES_DIR="$HOME/.sasstudio5/preferences"
SAS_KEYBOARDSHORTCUTS_DIR="$HOME/.sasstudio5/keyboardShortcuts"
SAS_STATE_DIR="$HOME/.sasstudio5/state"
 
[[ -z $SAS_LOGS_TO_DISK ]] && SAS_LOGS_TO_DISK=true
 
# Prevent SAS Entrypoint script from starting Apache proxy server
APACHE_CONF=/etc/httpd/conf/httpd.conf
APACHE_PORT=8880
sudo sed -iE "s#Listen 80#Listen $APACHE_PORT#g" $APACHE_CONF
 
# Define how we will launch SAS Viya
export SAS_LOGS_TO_DISK=true
function start_viya { sudo SAS_LOGS_TO_DISK=$SAS_LOGS_TO_DISK su --session-command '/opt/sas/viya/home/bin/entrypoint &' root; until $(curl --output /dev/null --silent --head --fail http://localhost:7080/SASStudio); do sleep 3; done; sudo /usr/sbin/nginx -c /var/opt/workspaces/sasds/nginx.conf; echo -e '\n\nStarted reverse proxy server...\n\n'; while true; do :; done; }
 
# Set up Domino project to preserve SAS configuration files
mkdir -p "$DOMINO_SAS_CONFIG_DIR" "$DOMINO_SAS_SNIPPETS_DIR" "$DOMINO_SAS_TASKS_DIR" "$DOMINO_SAS_PREFERENCES_DIR" "$DOMINO_SAS_KEYBOARDSHORTCUTS_DIR" "$DOMINO_SAS_STATE_DIR"
 
# Hack to ensure autoexec.sas can live in the Domino project folder.
# This is needed to properly tie in autoexec.sas with SAS Studio
mkdir -p "$SAS_AUTOEXEC_DIR"
rm -rf "$SAS_STUDIO_AUTOEXEC_FILE"
ln -s "$DOMINO_SASSTUDIO_AUTOEXEC_FILE" "$SAS_STUDIO_AUTOEXEC_FILE"
 
# Hack to ensure SAS Studio "My Snippets" are preserved with the Domino project files
rm -rf "$SAS_SNIPPETS_DIR"
ln -s "$DOMINO_SAS_SNIPPETS_DIR" "$SAS_SNIPPETS_DIR"
 
# Hack to ensure SAS Studio "My Tasks" are preserved with the Domino project files
rm -rf "$SAS_TASKS_DIR"
ln -s "$DOMINO_SAS_TASKS_DIR" "$SAS_TASKS_DIR"
 
# Hack to ensure SAS Studio Preferences are preserved with the Domino project files
[[ ! -d "$DOMINO_SAS_STATE_DIR" && -d "$SAS_STATE_DIR" ]] && cp -r "${SAS_STATE_DIR}/*" "${DOMINO_SAS_STATE_DIR}/"
rm -rf "$SAS_STATE_DIR"
ln -s "$DOMINO_SAS_STATE_DIR" "$SAS_STATE_DIR"
 
# Hack to ensure SAS Studio state is preserved with the Domino project files
[[ ! -d "$DOMINO_SAS_PREFERENCES_DIR" && -d "$SAS_PREFERENCES_DIR" ]] && cp -r "${SAS_PREFERENCES_DIR}/*" "${DOMINO_SAS_PREFERENCES_DIR}/"
rm -rf "$SAS_PREFERENCES_DIR"
ln -s "$DOMINO_SAS_PREFERENCES_DIR" "$SAS_PREFERENCES_DIR"
 
# Hack to ensure SAS Studio Keyboard Shortcuts are preserved with the Domino project files
rm -rf "$SAS_KEYBOARDSHORTCUTS_DIR"
ln -s "$DOMINO_SAS_KEYBOARDSHORTCUTS_DIR" "$SAS_KEYBOARDSHORTCUTS_DIR"
 
# Configure SAS Studio folder shortcuts to show Domino Git repos and Datasets folders
SHORTCUTS_DOMINO_GIT_REPOS=""
if [ -d "$DOMINO_GIT_REPOS_PATH" ]; then
    SHORTCUTS_DOMINO_GIT_REPOS="  <Shortcut type=\"disk\" name=\"Git Repos\" dir=\"$DOMINO_GIT_REPOS_PATH\" />"
fi
 
SHORTCUTS_DOMINO_DATASETS=""
if [ -d "$DOMINO_DATASETS_PATH" ]; then
    SHORTCUTS_DOMINO_DATASETS="  <Shortcut type=\"disk\" name=\"Domino Datasets\" dir=\"$DOMINO_DATASETS_PATH\" />"
fi
 
SHORTCUTS_DOMINO_IMPORTS=""
for DOMINO_IMPORT in `printenv | grep -e 'DOMINO_.*_WORKING_DIR' | tr '=' ' ' | awk '{print $1}'`; do
    DOMINO_IMPORT_DIR=${!DOMINO_IMPORT}
    DOMIMO_IMPORT_NAME=`echo "Import $DOMINO_IMPORT_DIR" | sed 's#/mnt/##g'`
    SHORTCUTS_DOMINO_IMPORTS="  <Shortcut type=\"disk\" name=\"$DOMIMO_IMPORT_NAME\" dir=\"$DOMINO_IMPORT_DIR\" />"
done
 
SHORTCUTS_HOME="  <Shortcut type=\"disk\" name=\"Home\" dir=\"$HOME\" />"
SHORTCUTS_TMP="  <Shortcut type=\"disk\" name=\"Temp\" dir=\"/tmp\" />"
 
SAS_SHORTCUTS="""<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<Shortcuts>
$SHORTCUTS_DOMINO_GIT_REPOS
$SHORTCUTS_DOMINO_DATASETS
$SHORTCUTS_DOMINO_IMPORTS
$SHORTCUTS_HOME
$SHORTCUTS_TMP
</Shortcuts>"""
mkdir -p $SAS_SHORTCUTS_DIR
echo $SAS_SHORTCUTS > $SAS_SHORTCUTS_FILE
 
 
# Configure SAS Studio options for Domino
SAS_CONFIG_UPDATES="""
sas.studio.basicUser=domino
sas.studio.basicPassword=domino
sas.studio.fileNavigationRoot=CUSTOM
sas.studio.fileNavigationCustomRootPath=${DOMINO_WORKING_DIR}
sas.studio.globalShortcutsPath=${SAS_SHORTCUTS_FILE}
"""
sudo sh -c "echo '$SAS_CONFIG_UPDATES' > $SAS_STUDIO_CONFIG_FILE"

# Reverse proxy configuration
if [[ -z $REVERSE_PROXY_PORT ]]; then
    REVERSE_PROXY_PORT=8888
fi
 
# Reverse Proxy Server
yum install nginx -y
sed -iE "s#8888#$REVERSE_PROXY_PORT#g" /var/opt/workspaces/sasds/nginx.conf
sed -iE "s#function start_viya .*#function start_viya { sudo SAS_LOGS_TO_DISK=\$SAS_LOGS_TO_DISK su --session-command '/opt/sas/viya/home/bin/entrypoint \&' root; until \$(curl --output /dev/null --silent --head --fail http://localhost:7080/SASStudio); do sleep 3; done; sudo /usr/sbin/nginx -c /var/opt/workspaces/sasds/nginx.conf; echo -e '\\\n\\\nStarted reverse proxy server...\\\n\\\n'; while true; do :; done; }#g" /var/opt/workspaces/sasds/start

# This actually starts the SAS Studio workspace
start_viya