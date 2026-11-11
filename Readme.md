<img src="images/icon.png" width="128" alt="Linkraptor icon">

# Linkraptor

Linkraptor catches every link you click and asks which browser (or Chrome profile) should open it. It's a small, native macOS app that lives in your menu bar.

![Linkraptor's picker with several browsers and Chrome profiles, next to the menu bar menu](images/linkraptor.png)

## It's just a fork

Linkraptor is a personal fork of [Browserino](https://github.com/AlexStrNik/Browserino) by Aleksandr Strizhnev, which was itself inspired by [Browserosaurus](https://github.com/will-stone/browserosaurus). All the credit for the app goes to them.

This fork fixes a few bugs I ran into with Browserino and adds features I wanted for myself. Everything after the fork was vibe-coded, so expect rough edges. Like Browserino, it's licensed under the GPL-3.0.

What it changes:

- Builds with the macOS 26 SDK.
- A picker redesigned for macOS 26: a Liquid Glass panel that sizes itself to the list, with bigger rows and number keys 1–9 to open them.
- A menu bar menu (the Rex dinosaur): open the link on your clipboard, or choose your primary browser.
- Chrome profiles: choose which profiles appear in the picker, give each a name, and open links straight into one.
- Private-browsing arguments are edited in a pop-up.
- A one-line installer and automatic updates.

# Install

Needs macOS 26.

### ⬇️ [Download Linkraptor.dmg](https://github.com/Matmac945/Linkraptor/releases/latest/download/Linkraptor.dmg)

That link always gets the newest version. You can also find it on the [Releases page](https://github.com/Matmac945/Linkraptor/releases/latest), under **Assets**: choose **Linkraptor.dmg**.

**1. Copy it to Applications.** Open the downloaded `Linkraptor.dmg`. In the window that appears, drag the **Linkraptor** icon onto the **Applications** folder. Then eject the disk (the eject button next to "Linkraptor" in the Finder sidebar).

**2. Open it the first time.** Open Linkraptor from your Applications folder. macOS will say *"Linkraptor" Not Opened* because the app isn't signed with a paid Apple certificate. It's safe: click **Done** (not Move to Trash).

**3. Allow it.** Open **System Settings → Privacy & Security** and scroll down to the **Security** section. Next to the "Linkraptor was blocked" message, click **Open Anyway**, then enter your Mac password. Linkraptor opens, and the dinosaur appears in your menu bar.

**4. Make it your default browser.** Open **System Settings → Desktop & Dock**, find **Default web browser**, and choose **Linkraptor**.

That's it. You only do steps 2 and 3 once. Linkraptor checks for updates every day and installs them on its own. To check right away, click the dinosaur in the menu bar and choose **Check for Updates…**.

<details>
<summary>Comfortable with Terminal? Install with one line instead</summary>

This skips steps 1–3 above. You still need step 4 afterwards.

```bash
curl -fsSL https://raw.githubusercontent.com/Matmac945/Linkraptor/main/scripts/install.sh | bash
```
</details>

# Releasing a new version (maintainers)

You'll need Xcode, the [GitHub CLI](https://cli.github.com) and the update-signing key in your Keychain. Commit your changes, then run:

```bash
scripts/release.sh 1.2.0
```

The script builds a universal app, packages `Linkraptor.dmg`, signs the update and publishes a GitHub Release. Everyone's copy picks it up within a day.

### The update-signing key

Updates are signed with a key stored in your macOS Keychain under the account `linkraptor`. Without it you can't ship updates, so back it up once:

```bash
scripts/signing-key.sh backup
```

That saves it to `.secrets/linkraptor-private-key.txt` inside the repo. The folder is gitignored, so it never gets committed. The file only lives on your Mac, so also keep a copy in a password manager.

**On a new Mac:** clone the repo, put the backup file back at that same path, then run:

```bash
scripts/signing-key.sh restore
```

Now `scripts/release.sh` works there too.

# Build from source

```bash
git clone https://github.com/Matmac945/Linkraptor.git
cd Linkraptor
xcodebuild -project Linkraptor.xcodeproj -scheme Linkraptor -configuration Release -derivedDataPath build build
codesign --force --deep --sign - build/Build/Products/Release/Linkraptor.app
ditto build/Build/Products/Release/Linkraptor.app /Applications/Linkraptor.app
```

# The original Browserino

To get the original app instead:

```bash
brew tap AlexStrNik/Browserino
brew install browserino --no-quarantine
```

If you want to support the original author, you can buy Browserino on [Gumroad](https://alexstrnik.gumroad.com/l/browserino).
