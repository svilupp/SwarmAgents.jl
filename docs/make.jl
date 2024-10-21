using SwarmAgents
using Documenter

DocMeta.setdocmeta!(SwarmAgents, :DocTestSetup, :(using SwarmAgents); recursive = true)

makedocs(;
    modules = [SwarmAgents],
    authors = "J S <49557684+svilupp@users.noreply.github.com> and contributors",
    sitename = "SwarmAgents.jl",
    format = Documenter.HTML(;
        canonical = "https://svilupp.github.io/SwarmAgents.jl",
        edit_link = "main",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
        "API" => "api.md"
    ]
)

deploydocs(;
    repo = "github.com/svilupp/SwarmAgents.jl",
    devbranch = "main"
)
