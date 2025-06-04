import * as vscode from 'vscode';
import * as cp from 'child_process';
import * as path from 'path';

export function activate(context: vscode.ExtensionContext) {
  const treeDataProvider = new class implements vscode.TreeDataProvider<vscode.TreeItem> {
    getTreeItem(element: vscode.TreeItem): vscode.TreeItem {
      return element;
    }
    getChildren(): vscode.ProviderResult<vscode.TreeItem[]> {
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
