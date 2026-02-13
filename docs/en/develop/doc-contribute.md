# Documentation Contribution Guide

## Online Editing

To edit documents online, click `Edit this page online` at the bottom left of the online document. The browser will jump to the repository file location. At this point, click the `Edit` button in the upper right corner, modify the content, preview the effect, and click `Submit changes` to submit after confirming it is correct.

After submission, it will be reviewed and merged into the main repository. Generally, after the main repository is merged, the online document will be automatically updated. If it is not updated, please manually refresh the page, or wait a few minutes after submission before refreshing.

## Local Editing

Documents can be directly submitted as PRs to the `master` branch without creating feature branches.

Before submitting code, please ensure that you have completed the global Git configuration locally
```
git config --global user.name Your Git username
git config --global user.email Your submission email, must be consistent with the code platform account email
```

1. **Fork the project**: Click Fork in the upper right corner to your own repository  
2. **Clone the repository**: `git clone`  
3. **Edit documents**: Find the files that need to be modified in the `docs` directory and edit them using Markdown syntax (refer to [Markdown Syntax](https://www.markdownguide.org/basic-syntax))
4. **Commit changes**: `git commit -m "Describe your document changes"`  
5. **Push the branch**: `git push origin master`

After submission, on your forked repository page, click the `Pull Request` button to create a PR.

## Local Preview of Konado Documents
Konado documents are built based on [VitePress](https://vitepress.dev/). To ensure that document modifications meet expectations, it is recommended to preview and verify them locally before submitting code.

### Prerequisite: Install Node.js
VitePress relies on the Node.js environment to run, so you need to first install Node.js that meets the version requirements:
1. **Version requirements**: It is recommended to install Node.js 18.x or higher (LTS long-term support version is best, with better compatibility).
2. **Download and install**:
   - Visit the official Node.js download address: [https://nodejs.org/](https://nodejs.org/)
   - Select the corresponding installation package according to the operating system (Windows/macOS/Linux) and complete the installation according to the wizard (for Windows, it is recommended to check the "Add to PATH" option).
3. **Verify installation**:
   Open the terminal (Command Prompt/PowerShell for Windows, Terminal for macOS/Linux), and execute the following commands to verify whether Node.js and npm (Node.js built-in package manager) are installed successfully:
   ```shell
   # Check Node.js version
   node -v
   # Check npm version
   npm -v
   ```
   If clear version numbers (such as `v20.10.0`, `10.2.3`) are output, the installation is successful.

> Optional optimization: If npm downloads dependencies slowly, you can configure a domestic mirror to improve speed:
> ```shell
> npm config set registry https://registry.npmmirror.com
> ```

### Install Project Dependencies
Enter the root directory of the Konado project and execute the following command to install the dependencies required for document preview:
```shell
npm install
```
Wait for the command to execute. If there are no errors in the terminal, the dependencies are installed successfully.

### Start Local Preview Service
After the dependencies are installed, execute the following command to start the VitePress development service:
```shell
npm run docs:dev
```

### Access Preview Documents
After the command is executed successfully, the terminal will output information similar to the following:
```shell
vitepress v1.6.4

➜  Local:   http://localhost:5173/konado/
➜  Network: use --host to expose
➜  press h to show help
```
Open the browser and visit the `Local` address in the output information (default: `http://localhost:5173/konado/`) to view the local documents.

### Additional Notes
1. Real-time refresh: After modifying the document content, there is no need to restart the service. The browser will automatically refresh the page to display the modified effect in real time;
2. Port exception: If the `localhost:5173` port is occupied, VitePress will automatically switch to an available port (such as 5174). Please refer to the actual address output by the terminal;
3. LAN access: If you need to preview documents on other devices in the LAN (such as mobile phones, another computer), you can execute the `npm run docs:dev -- --host` command, and the terminal will output a network-accessible IP address;
4. Stop the server: Press `Ctrl + C` in the terminal to stop the local preview service.
