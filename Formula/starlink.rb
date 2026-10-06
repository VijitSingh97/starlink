class Starlink < Formula
  desc "List Starlink router clients with table or JSON output"
  homepage "https://github.com/VijitSingh97/starlink"
  url "https://github.com/VijitSingh97/starlink/archive/refs/tags/v0.0.2.tar.gz"
  sha256 "d50af7eed5f8f58dbc5c4a20f3340312e7987d07a7eb9b5cb8efd220eacfe555"
  license "MIT"

  depends_on "go" => :build
  depends_on "jq"

  resource "grpcurl" do
    url "https://github.com/VijitSingh97/starlink/releases/download/v0.0.3/grpcurl_1.9.4-2_source.tar.gz"
    sha256 "430ffe07d2357028357f20e9d0b10e9d9c1e9717d58aae432bf653e55901cd66"
  end

  def install
    ENV["CGO_ENABLED"] = "0"
    ENV["GOTOOLCHAIN"] = "local"
    ENV["GOPROXY"] = "off"
    libexec.mkpath
    resource("grpcurl").stage do
      system "go", "build", "-mod=vendor", "-trimpath", "-buildvcs=false", "-ldflags", "-X main.version=v1.9.4",
             "-o", libexec/"grpcurl", "./cmd/grpcurl"
    end
    libexec.install "bin/starlink"
    (bin/"starlink").write_env_script libexec/"starlink", PATH: "#{libexec}:$PATH"
    bash_completion.install "completions/starlink.bash" => "starlink"
    zsh_completion.install "completions/_starlink"
  end

  test do
    assert_match "starlink #{version}", shell_output("#{bin}/starlink --version")
    assert_match "List Starlink router clients", shell_output("#{bin}/starlink --help")

    (testpath/"grpcurl").write <<~SH
      #!/bin/sh
      printf '%s\\n' '{"wifiGetStatus":{"clients":[{"name":"ten","ipAddress":"192.0.2.10"},{"name":"two","ipAddress":"192.0.2.2"}]}}'
    SH
    (testpath/"grpcurl").chmod 0755
    ENV.prepend_path "PATH", testpath
    assert_match "grpcurl v1.9.4", shell_output("#{libexec}/grpcurl -version 2>&1")
    clients = JSON.parse(shell_output("#{libexec}/starlink --json --sort ip --router 127.0.0.1:9000"))
    assert_equal ["192.0.2.2", "192.0.2.10"], clients.map { |client| client.fetch("ip") }
    assert_match "Router must be", shell_output("#{bin}/starlink --router invalid 2>&1", 1)
  end
end
