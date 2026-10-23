import QtQuick
import QtTest

import "../package/contents/ui/logic.js" as Logic

TestCase {
    name: "Logic"

    function test_overallState_data() {
        const folders = [{ id: "a", paused: false }, { id: "b", paused: false }];
        return [
            { tag: "offline", online: false, folders: folders, status: {}, expected: "offline" },
            { tag: "no folders", online: true, folders: [], status: {}, expected: "idle" },
            { tag: "status not loaded", online: true, folders: folders, status: {}, expected: "idle" },
            { tag: "all idle", online: true, folders: folders,
              status: { a: { state: "idle" }, b: { state: "idle" } }, expected: "idle" },
            { tag: "one syncing", online: true, folders: folders,
              status: { a: { state: "idle" }, b: { state: "syncing" } }, expected: "syncing" },
            { tag: "scanning", online: true, folders: folders,
              status: { a: { state: "scanning" } }, expected: "syncing" },
            { tag: "error wins", online: true, folders: folders,
              status: { a: { state: "syncing" }, b: { state: "error" } }, expected: "error" },
            { tag: "paused folder ignored", online: true,
              folders: [{ id: "a", paused: true }, { id: "b", paused: false }],
              status: { a: { state: "error" }, b: { state: "idle" } }, expected: "idle" },
        ];
    }

    function test_overallState(data) {
        compare(Logic.overallState(data.online, data.folders, data.status), data.expected);
    }

    function test_folderPercent() {
        compare(Logic.folderPercent(undefined), 100);
        compare(Logic.folderPercent({ globalBytes: 0, inSyncBytes: 0 }), 100);
        compare(Logic.folderPercent({ globalBytes: 200, inSyncBytes: 50 }), 25);
        compare(Logic.folderPercent({ globalBytes: 3, inSyncBytes: 2 }), 66);
    }

    function test_expandPath() {
        compare(Logic.expandPath("~", "/home/u"), "/home/u");
        compare(Logic.expandPath("~/Sync", "/home/u"), "/home/u/Sync");
        compare(Logic.expandPath("/data/~x", "/home/u"), "/data/~x");
        compare(Logic.expandPath("~other/x", "/home/u"), "~other/x");
    }

    function test_fileUrl() {
        compare(Logic.fileUrl("/data/music", "/home/u"), "file:///data/music");
        compare(Logic.fileUrl("~/My Docs", "/home/u"), "file:///home/u/My%20Docs");
        compare(Logic.fileUrl("/a/#b?c", "/home/u"), "file:///a/%23b%3Fc");
    }

    function test_shellQuote() {
        compare(Logic.shellQuote("abc"), "'abc'");
        compare(Logic.shellQuote("it's"), "'it'\\''s'");
        compare(Logic.shellQuote("$(rm -rf ~)"), "'$(rm -rf ~)'");
    }

    function test_curlCommand() {
        compare(Logic.curlCommand("http://127.0.0.1:8384", "KEY", "/rest/system/status"),
                "curl -skL --max-time 5 -H 'X-API-Key: KEY' 'http://127.0.0.1:8384/rest/system/status'");
        compare(Logic.curlCommand("http://h", "K", "/rest/db/scan", "POST"),
                "curl -skL --max-time 5 -X POST -H 'X-API-Key: K' 'http://h/rest/db/scan'");
    }

    function test_isAuthError() {
        verify(Logic.isAuthError("CSRF Error\n"));
        verify(Logic.isAuthError("Forbidden"));
        verify(!Logic.isAuthError(""));
        verify(!Logic.isAuthError(undefined));
    }

    function test_parseFolders() {
        const json = [
            { id: "abcd-1234", label: "Music", path: "/data/music", paused: false, type: "sendreceive" },
            { id: "efgh-5678", label: "", path: "~/notes", paused: true },
        ];
        compare(Logic.parseFolders(json), [
            { id: "abcd-1234", label: "Music", path: "/data/music", paused: false },
            { id: "efgh-5678", label: "efgh-5678", path: "~/notes", paused: true },
        ]);
    }

    function test_parseDevices() {
        const json = [
            { deviceID: "AAAAAAA-BBBBBBB", name: "laptop", paused: false },
            { deviceID: "CCCCCCC-DDDDDDD", name: "", paused: true },
        ];
        compare(Logic.parseDevices(json), [
            { deviceID: "AAAAAAA-BBBBBBB", name: "laptop", paused: false },
            { deviceID: "CCCCCCC-DDDDDDD", name: "CCCCCCC", paused: true },
        ]);
    }
}
