class Starlink < Formula
  desc "List Starlink router clients with table or JSON output"
  homepage "https://github.com/VijitSingh97/starlink"
  url "https://github.com/VijitSingh97/starlink/archive/refs/tags/v0.0.1.tar.gz"
  sha256 "a455d8b02863ac7c471e2ae46df437aa276b7743c32aaaaed1ebd04ee3755fde"
  license "MIT"

  depends_on "grpcurl"
  depends_on "jq"

  def install
    bin.install "bin/starlink"
    bash_completion.install "completions/starlink.bash" => "starlink"
    zsh_completion.install "completions/_starlink"
  end

  test do
    assert_match "starlink 0.0.1", shell_output("#{bin}/starlink --version")
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
