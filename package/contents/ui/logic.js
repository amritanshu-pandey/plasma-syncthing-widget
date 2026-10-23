.pragma library

// Returns offline, error, syncing or idle
function overallState(online, folders, folderStatus) {
    if (!online) return "offline";
    const states = folders.filter(f => !f.paused).map(f => folderStatus[f.id]?.state ?? "");
    if (states.includes("error")) return "error";
    if (states.some(s => s !== "idle" && s !== "")) return "syncing";
    return "idle";
}

function folderPercent(status) {
    if (!status || !status.globalBytes) return 100;
    return Math.floor(100 * status.inSyncBytes / status.globalBytes);
}

function expandPath(path, home) {
    return path.replace(/^~(?=\/|$)/, home);
}

function fileUrl(path, home) {
    return "file://" + expandPath(path, home).split("/").map(encodeURIComponent).join("/");
}

function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

function curlCommand(baseUrl, apiKey, path, method) {
    return "curl -skL --max-time 5"
        + (method === "POST" ? " -X POST" : "")
        + " -H " + shellQuote("X-API-Key: " + apiKey)
        + " " + shellQuote(baseUrl + path);
}

function isAuthError(raw) {
    return /CSRF|Unauthorized|Forbidden/.test(raw || "");
}

function parseFolders(json) {
    return json.map(f => ({ id: f.id, label: f.label || f.id, path: f.path, paused: f.paused }));
}

function parseDevices(json) {
    return json.map(d => ({ deviceID: d.deviceID, name: d.name || d.deviceID.slice(0, 7), paused: d.paused }));
}
