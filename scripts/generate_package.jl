# code
using PkgTemplates

tpl = Template(;
    user = "svilupp",
    dir = ".",
    julia = v"1.10",
    plugins = [
        License(; name = "MIT", path = nothing, destination = "LICENSE"),
        Codecov(),
        Tests(;
            project = false,
            aqua = true,
            aqua_kwargs = NamedTuple()
        ),
        Readme(;
            destination = "README.md",
            inline_badges = true
        ),
        GitHubActions(;
            destination = "CI.yml",
            linux = true,
            osx = false,
            windows = false,
            x64 = true,
            x86 = false,
            coverage = true,
            extra_versions = ["1.0", "1.9", "nightly"]
        ),
        CompatHelper(;
            destination = "CompatHelper.yml",
            cron = "0 0 1 * *"
        ),
        Documenter{GitHubActions}(;
            assets = String[],
            logo = Logo(),
            devbranch = nothing,
            edit_link = :devbranch,
            makedocs_kwargs = Dict{Symbol, Any}()
        ),
        Formatter(;
            style = "sciml"
        )])

## Generate Package
pkg_name = "Swarm"
generate(pkg_name, tpl)

## Move files one level higher
dir_repo = joinpath(@__DIR__, "..")
for src_path in readdir(joinpath(dir_repo, pkg_name); join = true)
    dst_path = joinpath(dir_repo, basename(src_path))
    mv(src_path, dst_path, force = true)
end
rm(joinpath(dir_repo, pkg_name); recursive = true, force = true)
