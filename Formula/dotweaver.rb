class Dotweaver < Formula
  desc "Modern native macOS dotfiles manager with CLI"
  homepage "https://github.com/rausth/DotWeaver"
  url "https://github.com/rausth/DotWeaver/releases/download/v1.0.0/DotWeaver-macOS.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  head "https://github.com/rausth/DotWeaver.git", branch: "main"

  depends_on macos: :sequoia
  depends_on xcode: ["16.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/DotWeaver" => "dotweaver-gui"
    bin.install ".build/release/dotweaver" => "dotweaver"
  end

  test do
    assert_match "DotWeaver", shell_output("#{bin}/dotweaver --help")
  end
end
