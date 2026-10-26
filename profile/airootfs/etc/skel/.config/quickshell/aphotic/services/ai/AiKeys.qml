pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// API keys for AI Chat providers that need them (Claude, Gemini, ChatGPT).
// Kept in a separate, chmod-600 file from ai-config.json / shell.json --
// see docs/COMMAND_CENTER.md §4 for why keys don't belong in general
// shell config. Ollama needs no key (LAN host, direct HTTP).
Singleton {
    id: root

    readonly property string keysPath: `${Quickshell.env("HOME")}/.config/aphotic/ai-keys.json`

    property string anthropicApiKey: Quickshell.env("ANTHROPIC_API_KEY") ?? ""
    property string geminiApiKey: Quickshell.env("GEMINI_API_KEY") ?? ""
    property string openaiApiKey: Quickshell.env("OPENAI_API_KEY") ?? ""

    readonly property bool hasAnthropicKey: root.anthropicApiKey.length > 0
    readonly property bool hasGeminiKey: root.geminiApiKey.length > 0
    readonly property bool hasOpenaiKey: root.openaiApiKey.length > 0

    property bool _loaded: false

    function _save(): void {
        if (!root._loaded)
            return;
        keysWriter.setText(JSON.stringify({
            anthropicApiKey: root.anthropicApiKey,
            geminiApiKey: root.geminiApiKey,
            openaiApiKey: root.openaiApiKey
        }, null, 2));
        chmodProc.running = true;
    }

    onAnthropicApiKeyChanged: root._save()
    onGeminiApiKeyChanged: root._save()
    onOpenaiApiKeyChanged: root._save()

    FileView {
        id: keysFile

        path: root.keysPath
        watchChanges: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (typeof data.anthropicApiKey === "string" && data.anthropicApiKey.length > 0)
                    root.anthropicApiKey = data.anthropicApiKey;
                else if (!root.anthropicApiKey)
                    root.anthropicApiKey = Quickshell.env("ANTHROPIC_API_KEY") ?? "";

                if (typeof data.geminiApiKey === "string" && data.geminiApiKey.length > 0)
                    root.geminiApiKey = data.geminiApiKey;
                else if (!root.geminiApiKey)
                    root.geminiApiKey = Quickshell.env("GEMINI_API_KEY") ?? "";

                if (typeof data.openaiApiKey === "string" && data.openaiApiKey.length > 0)
                    root.openaiApiKey = data.openaiApiKey;
                else if (!root.openaiApiKey)
                    root.openaiApiKey = Quickshell.env("OPENAI_API_KEY") ?? "";
            } catch (e) {
                // No keys file yet, or malformed -- fall back to environment.
                if (!root.anthropicApiKey)
                    root.anthropicApiKey = Quickshell.env("ANTHROPIC_API_KEY") ?? "";
                if (!root.geminiApiKey)
                    root.geminiApiKey = Quickshell.env("GEMINI_API_KEY") ?? "";
                if (!root.openaiApiKey)
                    root.openaiApiKey = Quickshell.env("OPENAI_API_KEY") ?? "";
            }
            root._loaded = true;
        }
        onLoadFailed: error => {
            if (!root.anthropicApiKey)
                root.anthropicApiKey = Quickshell.env("ANTHROPIC_API_KEY") ?? "";
            if (!root.geminiApiKey)
                root.geminiApiKey = Quickshell.env("GEMINI_API_KEY") ?? "";
            if (!root.openaiApiKey)
                root.openaiApiKey = Quickshell.env("OPENAI_API_KEY") ?? "";
            root._loaded = true;
        }
    }

    FileView {
        id: keysWriter

        path: root.keysPath
        printErrors: false
    }

    Process {
        id: chmodProc
        command: ["chmod", "600", root.keysPath]
    }

    Process {
        id: mkConfigDir
        command: ["mkdir", "-p", `${Quickshell.env("HOME")}/.config/aphotic`]
        onExited: keysFile.reload()
    }

    Component.onCompleted: mkConfigDir.running = true
}
