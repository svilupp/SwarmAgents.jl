using Swarm
using Documenter

DocMeta.setdocmeta!(Swarm, :DocTestSetup, :(using Swarm); recursive = true)

makedocs(;
    modules = [Swarm],
    authors = "J S <49557684+svilupp@users.noreply.github.com> and contributors",
    sitename = "Swarm.jl",
    format = Documenter.HTML(;
        canonical = "https://svilupp.github.io/Swarm.jl",
        edit_link = "main",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
        "API" => "api.md"
    ]
)

deploydocs(;
    repo = "github.com/svilupp/Swarm.jl",
    devbranch = "main"
)
