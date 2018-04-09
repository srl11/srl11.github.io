# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "hello-world"
  spec.version       = "1.0.0"
  spec.authors       = ["xftony"]
  spec.email         = ["srl11@foxmail.com"]

  spec.summary       = %q{xftony's blog}
  spec.homepage      = "https://github.com/xftony"
  spec.license       = "wow"

  spec.metadata["plugin_type"] = "theme"

  spec.files         = `git ls-files -z`.split("\x0").select do |f|
    f.match(%r{^(assets|_(includes|layouts|sass)/|(LICENSE|README)((\.(txt|md|markdown)|$)))}i)
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.add_runtime_dependency "jekyll", "~> 3.4"
  spec.add_runtime_dependency "jekyll-gist", "~> 1.4"
  spec.add_runtime_dependency "jekyll-paginate", "~> 1.1"
  spec.add_runtime_dependency "jekyll-feed", "~> 0.6"
  spec.add_development_dependency "bundler", "~> 1.12"
end
