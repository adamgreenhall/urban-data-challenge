use Rack::Static, :urls => ["/styles", "/img", "/javascript", "/data"], :root => "web/public"
run Rack::Directory.new("web/public")

run lambda { |env|
  path = env["REQUEST_PATH"] || "/index.html"
  if path == "/"
    path = "/index.html"
  end

  [
    200,
    {
      'Content-Type'  => 'text/html',
      'Cache-Control' => 'public, max-age=86400'
    },
    File.open("web/public#{path}", File::RDONLY)
  ]
}
