var debug = false;
var setting,cache, api;
var updateManifestUrl = "";
var trayAvailable = false;
var isQuitting = false;

function getDefaultSettings() {
    return {
        host: "",
        username: "",
        token: "",
        min_tray: 0,
        start_minimized: 0,
        always_top: 0,
        use_only_token: 0,
        rounding_minutes: 0,
    };
}

Neutralino.init();

Neutralino.events.on("windowClose", onWindowClose);

let tray = {
    icon: '/resources/icons/logo.png',
    menuItems: [
      
      {id: "open", text: "Open"},
      {id: "min", text: "Minimize"},
      {text: "-"},
      {id: "quit", text: "Quit"}
    ]
  };

Neutralino.os.setTray(tray)
    .then(function() {
        trayAvailable = true;
    })
    .catch(function(error) {
        trayAvailable = false;
        if(debug) console.log('tray init failed', error);
    });

function quitApp() {
    if(isQuitting) return;

    isQuitting = true;

    Neutralino.app.exit(0).catch(function(error) {
        if(debug) console.log('app exit failed', error);
        Neutralino.app.killProcess().catch(function(killError) {
            if(debug) console.log('app kill failed', killError);
        });
    });
}

function onWindowClose() {

    if(isQuitting) {
        return;
    }

    const canMinimizeToTray = typeof(setting)!=="undefined"
        && typeof(setting.min_tray)!=="undefined"
        && setting.min_tray==1
        && trayAvailable;

    if(canMinimizeToTray)
    {
        if(debug) console.log('minimize to tray',setting)
        Neutralino.window.hide();
    }
    else
    {
        if(debug) console.log('exit app',setting)
        quitApp();
    }
    
}

//if(debug) console.log('port',NL_PORT,NL_TOKEN);

Neutralino.events.on("trayMenuItemClicked", onTrayMenuItemClicked);
function onTrayMenuItemClicked(event) {
    switch(event.detail.id) {
        case "open":
            Neutralino.window.show();
            break;
        case "min":
            Neutralino.window.minimize();
            
            break;
        case "quit":
            quitApp();
            break;
    }
}

Neutralino.events.on("ready", function(){
    checkUpdate();
});

/*
//prepare for extensions
Neutralino.events.on("createTimesheet", (evt) => {
    console.log(`Extension: ${evt.detail}`);
});
*/

async function loadSettings(){
    let settingJSON = "{}";

    try {
        settingJSON = await CodeTimerStorage.getSetting();
    }
    catch(error) {
        if(debug) console.log('loadSettings fallback', error);
    }

    setting = {
        ...getDefaultSettings(),
        ...JSON.parse(settingJSON)
    };
    return setting;
}

async function init(){
    setting = await loadSettings();
    await initCache()

    
    if(setting.always_top==1) Neutralino.window.setAlwaysOnTop(true);
    else Neutralino.window.setAlwaysOnTop(false);

    if(shouldStartMinimized()) {
        if(debug) console.log('start minimized to tray', setting);
        Neutralino.window.hide();
    }

    if(debug) console.log('inited',setting,cache)
}

function shouldStartMinimized(){
    const startupCheckedKey = "codetimerStartMinimizedChecked";
    if(sessionStorage.getItem(startupCheckedKey)=="1") return false;
    sessionStorage.setItem(startupCheckedKey, "1");

    if(!trayAvailable) return false;
    if(typeof(setting)==="undefined" || setting.start_minimized!=1) return false;

    const path = window.location.pathname;
    return path === "/" || path.endsWith("/index.html");
}

function openHomepage(){
    Neutralino.os.open(setting.host);
}

function openLoadingDialog(){
    $('#loadingModal').modal('show');
    if(debug) console.log('openLoadingDialog');
}

function closeLoadingDialog(){
    
    $('#loadingModal').modal('hide');
    if(debug) console.log('closeLoadingDialog');
}

function openDetail(){
    Neutralino.app.open({
        "url": "file:///"+NL_CWD+"/resources/detail.html"
    });
}

function isManagedPackageInstall(){
    const paths = [window.NL_PATH, window.NL_CWD];
    return paths.some((path) => typeof(path) === "string" && path.indexOf("/opt/codetimer") === 0);
}

async function checkUpdate(forceOpen=0){
    
    try {

        initUpdateBtn();
        if(localStorage.getItem("updateNotify")=="1" && forceOpen==0) return false;
        if(typeof(updateManifestUrl) !== "string" || updateManifestUrl.trim() == "") return false;

        const managedPackageInstall = isManagedPackageInstall();
        let manifest = await Neutralino.updater.checkForUpdates(updateManifestUrl);

        if(manifest.version != NL_APPVERSION) {

            let button = await Neutralino.os.showMessageBox('New version',
                            `New version of CodeTimer is available!

You are using ${NL_APPVERSION} and new version is ${manifest.version}.
${managedPackageInstall ? "Please install the latest Debian package to update this installation." : "Do you want to install update now?"}`,
                            managedPackageInstall ? 'OK' : 'YES_NO',
                            managedPackageInstall ? 'INFO' : 'QUESTION');

            
            localStorage.setItem("updateNotify", "1");
            initUpdateBtn();

            if(managedPackageInstall) return false;

            if(button == 'YES') {

                if(debug)  console.log('installing update');
                openLoadingDialog();

                await Neutralino.updater.install();
                await Neutralino.app.restartProcess();    
            }
            
        }
    } 
    catch(error) {
        if(debug) console.log('update check failed', error);
        await Neutralino.os.showMessageBox('Update failed',
                            `Update failed, please try again later.`,
                            'OK', 'ERROR');
        closeLoadingDialog();
    }

    
}

function initUpdateBtn(){
    if(localStorage.getItem("updateNotify")=="1")
    {
        $('.updateBtn').removeClass('d-none');
        $('.update-dot').show();
    }
}
