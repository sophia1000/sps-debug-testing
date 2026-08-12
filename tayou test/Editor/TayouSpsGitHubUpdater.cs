using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Networking;

[InitializeOnLoad]
public static class TayouSpsGitHubUpdater {
    private const string Owner = "TayouVR";
    private const string Repository = "AmityEdits";
    private const string Branch = "sps2_features";
    private const string RemoteRoot = "Shaders/Selore/sps/";
    private const string ManifestName = ".tayou-sps-upstream.json";
    private const double AutomaticCheckHours = 6.0;

    private static UnityWebRequest request;
    private static Action<UnityWebRequest> requestCompleted;
    private static readonly List<RemoteFile> downloads = new List<RemoteFile>();
    private static int downloadIndex;
    private static string targetAssetRoot;
    private static string pendingTreeSha;
    private static bool busy;

    [Serializable]
    private sealed class GitTreeResponse {
        public string sha;
        public bool truncated;
        public GitTreeEntry[] tree;
    }

    [Serializable]
    private sealed class GitTreeEntry {
        public string path;
        public string type;
    }

    [Serializable]
    private sealed class UpstreamManifest {
        public string treeSha;
        public string branch;
        public string sourcePath;
        public string[] files;
    }

    private sealed class RemoteFile {
        public string relativePath;
        public byte[] data;
    }

    static TayouSpsGitHubUpdater() {
        EditorApplication.delayCall += AutomaticCheck;
    }

    [MenuItem("Tools/Tayou SPS/Check for Updates Now")]
    public static void CheckNow() {
        BeginCheck(true);
    }

    private static void AutomaticCheck() {
        if (Application.isBatchMode || EditorApplication.isCompiling) return;

        string key = "TayouSpsGitHubUpdater.LastCheck." + Application.dataPath.GetHashCode();
        long lastTicks;
        long.TryParse(EditorPrefs.GetString(key, "0"), out lastTicks);
        var lastCheck = new DateTime(Math.Max(lastTicks, DateTime.MinValue.Ticks), DateTimeKind.Utc);
        if ((DateTime.UtcNow - lastCheck).TotalHours < AutomaticCheckHours) return;

        EditorPrefs.SetString(key, DateTime.UtcNow.Ticks.ToString());
        BeginCheck(false);
    }

    private static void BeginCheck(bool userInitiated) {
        if (busy) {
            if (userInitiated) Debug.Log("Tayou SPS update check is already running.");
            return;
        }

        targetAssetRoot = FindTargetAssetRoot();
        if (string.IsNullOrEmpty(targetAssetRoot)) {
            Debug.LogError("Tayou SPS updater could not locate its Editor folder.");
            return;
        }

        busy = true;
        string treeUrl = string.Format(
            "https://api.github.com/repos/{0}/{1}/git/trees/{2}?recursive=1",
            Owner,
            Repository,
            Branch
        );
        BeginRequest(treeUrl, HandleTreeResponse);
    }

    private static string FindTargetAssetRoot() {
        foreach (string guid in AssetDatabase.FindAssets("TayouSpsGitHubUpdater t:MonoScript")) {
            string scriptPath = AssetDatabase.GUIDToAssetPath(guid).Replace('\\', '/');
            if (!scriptPath.EndsWith("/Editor/TayouSpsGitHubUpdater.cs", StringComparison.Ordinal)) continue;
            string packageRoot = Path.GetDirectoryName(Path.GetDirectoryName(scriptPath)).Replace('\\', '/');
            return packageRoot + "/sps";
        }
        return null;
    }

    private static void HandleTreeResponse(UnityWebRequest completedRequest) {
        if (!RequestSucceeded(completedRequest)) {
            Fail("GitHub tree request failed: " + completedRequest.error);
            return;
        }

        GitTreeResponse tree = JsonUtility.FromJson<GitTreeResponse>(completedRequest.downloadHandler.text);
        if (tree == null || tree.tree == null || tree.truncated) {
            Fail("GitHub returned an incomplete SPS file tree.");
            return;
        }

        string manifestPath = AssetPathToFullPath(targetAssetRoot + "/" + ManifestName);
        UpstreamManifest current = ReadManifest(manifestPath);
        if (current != null && current.treeSha == tree.sha) {
            Finish("Tayou SPS is already current at " + ShortSha(tree.sha) + ".");
            return;
        }

        downloads.Clear();
        foreach (GitTreeEntry entry in tree.tree) {
            if (entry.type != "blob" || !entry.path.StartsWith(RemoteRoot, StringComparison.Ordinal)) continue;
            string relativePath = entry.path.Substring(RemoteRoot.Length);
            if (string.IsNullOrEmpty(relativePath)) continue;
            downloads.Add(new RemoteFile { relativePath = relativePath });
        }

        downloads.Sort((a, b) => string.CompareOrdinal(a.relativePath, b.relativePath));
        if (downloads.Count == 0) {
            Fail("No files were found under " + RemoteRoot + " on GitHub.");
            return;
        }

        pendingTreeSha = tree.sha;
        downloadIndex = 0;
        DownloadNextFile();
    }

    private static void DownloadNextFile() {
        if (downloadIndex >= downloads.Count) {
            ApplyDownloads();
            return;
        }

        RemoteFile file = downloads[downloadIndex];
        string rawUrl = string.Format(
            "https://raw.githubusercontent.com/{0}/{1}/{2}/{3}{4}",
            Owner,
            Repository,
            Branch,
            RemoteRoot,
            EscapePath(file.relativePath)
        );
        BeginRequest(rawUrl, completedRequest => {
            if (!RequestSucceeded(completedRequest)) {
                Fail("Failed to download " + file.relativePath + ": " + completedRequest.error);
                return;
            }
            file.data = completedRequest.downloadHandler.data;
            downloadIndex++;
            DownloadNextFile();
        });
    }

    private static void ApplyDownloads() {
        string targetFullRoot = AssetPathToFullPath(targetAssetRoot);
        string manifestPath = Path.Combine(targetFullRoot, ManifestName);
        UpstreamManifest previous = ReadManifest(manifestPath);
        var newFiles = new HashSet<string>(downloads.Select(file => NormalizeRelativePath(file.relativePath)));

        AssetDatabase.StartAssetEditing();
        try {
            if (previous != null && previous.files != null) {
                foreach (string oldRelativePath in previous.files) {
                    string normalized = NormalizeRelativePath(oldRelativePath);
                    if (newFiles.Contains(normalized)) continue;
                    string stalePath = SafeDestination(targetFullRoot, normalized);
                    if (File.Exists(stalePath)) File.Delete(stalePath);
                }
            }

            foreach (RemoteFile file in downloads) {
                string destination = SafeDestination(targetFullRoot, file.relativePath);
                Directory.CreateDirectory(Path.GetDirectoryName(destination));
                File.WriteAllBytes(destination, file.data);
            }

            var manifest = new UpstreamManifest {
                treeSha = pendingTreeSha,
                branch = Branch,
                sourcePath = RemoteRoot.TrimEnd('/'),
                files = downloads.Select(file => NormalizeRelativePath(file.relativePath)).ToArray()
            };
            File.WriteAllText(manifestPath, JsonUtility.ToJson(manifest, true));
        } catch (Exception exception) {
            Fail("Could not apply Tayou SPS update: " + exception.Message);
            return;
        } finally {
            AssetDatabase.StopAssetEditing();
        }

        AssetDatabase.Refresh();
        Finish(string.Format("Updated Tayou SPS: {0} files at {1}.", downloads.Count, ShortSha(pendingTreeSha)));
    }

    private static string SafeDestination(string root, string relativePath) {
        string fullRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        string fullPath = Path.GetFullPath(Path.Combine(fullRoot, NormalizeRelativePath(relativePath)));
        if (!fullPath.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase)) {
            throw new InvalidOperationException("Unsafe upstream path: " + relativePath);
        }
        return fullPath;
    }

    private static string NormalizeRelativePath(string path) {
        return path.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar);
    }

    private static string EscapePath(string path) {
        return string.Join("/", path.Split('/').Select(Uri.EscapeDataString).ToArray());
    }

    private static string AssetPathToFullPath(string assetPath) {
        string projectRoot = Path.GetDirectoryName(Application.dataPath);
        return Path.GetFullPath(Path.Combine(projectRoot, assetPath));
    }

    private static UpstreamManifest ReadManifest(string path) {
        if (!File.Exists(path)) return null;
        try {
            return JsonUtility.FromJson<UpstreamManifest>(File.ReadAllText(path));
        } catch (Exception) {
            return null;
        }
    }

    private static string ShortSha(string sha) {
        return string.IsNullOrEmpty(sha) ? "unknown" : sha.Substring(0, Math.Min(8, sha.Length));
    }

    private static bool RequestSucceeded(UnityWebRequest completedRequest) {
        return completedRequest.result == UnityWebRequest.Result.Success;
    }

    private static void BeginRequest(string url, Action<UnityWebRequest> completed) {
        request = UnityWebRequest.Get(url);
        request.SetRequestHeader("User-Agent", "Unity-Tayou-SPS-Updater");
        requestCompleted = completed;
        request.SendWebRequest();
        EditorApplication.update -= PollRequest;
        EditorApplication.update += PollRequest;
    }

    private static void PollRequest() {
        if (request == null || !request.isDone) return;

        EditorApplication.update -= PollRequest;
        UnityWebRequest completedRequest = request;
        Action<UnityWebRequest> completed = requestCompleted;
        request = null;
        requestCompleted = null;
        try {
            completed(completedRequest);
        } finally {
            completedRequest.Dispose();
        }
    }

    private static void Fail(string message) {
        downloads.Clear();
        busy = false;
        Debug.LogWarning("Tayou SPS updater: " + message);
    }

    private static void Finish(string message) {
        downloads.Clear();
        busy = false;
        Debug.Log(message);
    }
}
