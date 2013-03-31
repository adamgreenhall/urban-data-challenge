use Rack::Static, :urls => ["/stylesheets", "/images"], :root => "web"
run Rack::Directory.new("public")

run lambda { |env|
  [
    200,
    {
      'Content-Type'  => 'text/html',
      'Cache-Control' => 'public, max-age=86400'
    },
    File.open('web/index.html', File::RDONLY)
  ]
}
