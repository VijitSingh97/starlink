class Starlink < Formula
  desc "List Starlink router clients with table or JSON output"
  homepage "https://github.com/VijitSingh97/starlink"
  url "https://github.com/VijitSingh97/starlink/archive/refs/tags/v0.0.2.tar.gz"
  sha256 "d50af7eed5f8f58dbc5c4a20f3340312e7987d07a7eb9b5cb8efd220eacfe555"
  license "MIT"

  depends_on "grpcurl"
  depends_on "jq"

  def install
    bin.install "bin/starlink"
    bash_completion.install "completions/starlink.bash" => "starlink"
    zsh_completion.install "completions/_starlink"
  end

  test do
    assert_match "starlink 0.0.2", shell_output("#{bin}/starlink --version")
    assert_match "List Starlink router clients", shell_output("#{bin}/starlink --help")

    (testpath/"grpcurl").write <<~SH
      #!/bin/sh
      printf '%s\\n' '{"wifiGetStatus":{"clients":[{"name":"ten","ipAddress":"192.0.2.10"},{"name":"two","ipAddress":"192.0.2.2"}]}}'
    SH
    (testpath/"grpcurl").chmod 0755
    ENV.prepend_path "PATH", testpath
    clients = JSON.parse(shell_output("#{bin}/starlink --json --sort ip --router 127.0.0.1:9000"))
    assert_equal ["192.0.2.2", "192.0.2.10"], clients.map { |client| client.fetch("ip") }
    assert_match "Router must be", shell_output("#{bin}/starlink --router invalid 2>&1", 1)
  end
end
