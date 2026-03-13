var debug = false;
var setting,cache, api;

function getDefaultSettings() {
    return {
        host: "",
        username: "",
        token: "",
        min_tray: 0,
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
Neutralino.os.setTray(tray);


function onWindowClose() {

    if(typeof(setting)!=="undefined" && typeof(setting.min_tray)!=="undefined" && setting.min_tray==1)
    {
        if(debug) console.log('minimize to tray',setting)
        Neutralino.window.hide();
        //Neutralino.window.minimize();
    }
    else
    {
        if(debug) console.log('exit app',setting)
        Neutralino.app.exit();
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
            Neutralino.app.exit();
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
        settingJSON = await Neutralino.storage.getData('setting');
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

    if(debug) console.log('inited',setting,cache)
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

async function checkUpdate(forceOpen=0){
    
    try {

        initUpdateBtn();
        if(localStorage.getItem("updateNotify")=="1" && forceOpen==0) return false;

        let url = "https://www.owly.sk/apps/CodeTimer/update/manifest.json";
        let manifest = await Neutralino.updater.checkForUpdates(url);

        if(manifest.version != NL_APPVERSION) {

            let button = await Neutralino.os.showMessageBox('New version',
                            `New version of CodeTimer is available!

You are using ${NL_APPVERSION} and new version is ${manifest.version}.
Do you want to install update now?`,
                            'YES_NO', 'QUESTION');

            
            localStorage.setItem("updateNotify", "1");
            initUpdateBtn();


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