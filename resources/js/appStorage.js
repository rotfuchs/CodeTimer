const CodeTimerStorage = (() => {
    const appDirName = "codetimer";
    let pathsPromise = null;

    function joinPath(basePath, name) {
        return `${basePath.replace(/\/$/, "")}/${name}`;
    }

    async function ensureDirectory(path) {
        try {
            await Neutralino.filesystem.createDirectory(path);
        }
        catch(error) {
            if(debug) console.log("ensureDirectory fallback", path, error);
        }
    }

    async function getPaths() {
        if(pathsPromise) return pathsPromise;

        pathsPromise = (async () => {
            const configBase = await Neutralino.os.getPath("config");
            const cacheBase = await Neutralino.os.getPath("cache");
            const configDir = joinPath(configBase, appDirName);
            const cacheDir = joinPath(cacheBase, appDirName);

            await ensureDirectory(configDir);
            await ensureDirectory(cacheDir);

            return {
                setting: joinPath(configDir, "settings.json"),
                cache: joinPath(cacheDir, "cache.json"),
            };
        })();

        return pathsPromise;
    }

    async function lockDownFile(path) {
        try {
            await Neutralino.filesystem.setPermissions(path, {}, 0o600);
        }
        catch(error) {
            if(debug) console.log("setPermissions fallback", path, error);
        }
    }

    async function readFileOrMigrate(path, legacyKey) {
        try {
            return await Neutralino.filesystem.readFile(path);
        }
        catch(error) {
            if(debug) console.log("readFile fallback", path, error);
        }

        const legacyData = await Neutralino.storage.getData(legacyKey);
        await Neutralino.filesystem.writeFile(path, legacyData);
        await lockDownFile(path);
        return legacyData;
    }

    async function writeFile(path, data) {
        await Neutralino.filesystem.writeFile(path, data);
        await lockDownFile(path);
    }

    return {
        async getSetting() {
            const paths = await getPaths();
            return readFileOrMigrate(paths.setting, "setting");
        },

        async setSetting(data) {
            const paths = await getPaths();
            await writeFile(paths.setting, data);
        },

        async getCache() {
            const paths = await getPaths();
            return readFileOrMigrate(paths.cache, "cache");
        },

        async setCache(data) {
            const paths = await getPaths();
            await writeFile(paths.cache, data);
        },
    };
})();
