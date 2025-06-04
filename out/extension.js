"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
function activate(context) {
    const treeDataProvider = new class {
        getTreeItem(element) {
            return element;
        }
        getChildren() {
            return [
                new RunScriptItem()
            ];
        }
    };
    vscode.window.registerTreeDataProvider('runScriptView', treeDataProvider);
    let disposable = vscode.commands.registerCommand('runScript.runMyScript', () => {
        const scriptPath = path.join(context.extensionPath, 'script', 'run-config.ps1');
        const terminal = vscode.window.createTerminal("Run Org/Env Script");
        terminal.show();
        terminal.sendText(`powershell -ExecutionPolicy Bypass -File "${scriptPath}"`);
    });
    context.subscriptions.push(disposable);
}
class RunScriptItem extends vscode.TreeItem {
    constructor() {
        super("▶ Run Org/Env Script", vscode.TreeItemCollapsibleState.None);
        this.command = {
            command: "runScript.runMyScript",
            title: "Run Org/Env Script"
        };
        this.iconPath = new vscode.ThemeIcon("play");
    }
}
//# sourceMappingURL=extension.js.map