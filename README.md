

This script automates the process of generating a temporary certificate (valid for 12 hours) and securely uploading its associated certificate and private key directly to your GitHub Repository Secrets. Be aware that the script could be improved but its working 100%. 

**OTP Preparation:** It is highly recommended to prepare your One-Time Password (OTP) code in advance for the authentication step through the Cineca web interface that will open when the script is launched.

 If you encounter an error, try re-launching the script(tested multiple times but error or bugs can always happear D:).

1. **Make the script executable:**
   ```bash
   chmod +x automate_ssh_cert.sh
   ```

2. **Install dependencies:**
   - **Smallstep CLI**: Follow [installation guide](https://smallstep.com/docs/step-cli/installation/)
   - **GitHub CLI**: Follow [installation guide](https://cli.github.com/)
   - **expect** (optional, for automated passphrase input): `sudo apt install expect` or `brew install expect`

3. **Authenticate with GitHub:**
   ```bash
   gh auth login
   ```

4. **Run the script:**
   ```bash
   # With auto-generated passphrase
   ./automate_ssh_cert.sh user@example.com your-github-username your-repo-name

   # With custom passphrase
   ./automate_ssh_cert.sh user@example.com your-github-username your-repo-name "your-secure-passphrase"
