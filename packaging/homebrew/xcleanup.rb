# Homebrew cask template.
#
# Lives in this repo for reference only. To distribute:
#   1. Create a repo named `homebrew-tap` under your GitHub account.
#   2. Copy this file to `Casks/xcleanup.rb` in that repo.
#   3. After each release, update `version` and `sha256`
#      (scripts/release.sh prints the sha).
#
# Users then install with:
#   brew install DevEverton/tap/xcleanup
cask "xcleanup" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE_SCRIPT"

  url "https://github.com/DevEverton/XCleanup/releases/download/v#{version}/XCleanup-#{version}.zip"
  name "XCleanup"
  desc "Menu bar app that monitors and cleans Xcode build artifacts"
  homepage "https://github.com/DevEverton/XCleanup"

  depends_on macos: ">= :sonoma"

  app "XCleanup.app"

  zap trash: [
    "~/Library/Preferences/EvertonCarneiro.XCleanup.plist",
  ]
end
