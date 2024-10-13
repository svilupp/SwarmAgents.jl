# Inspired by https://www.cursor.com/blog/instant-apply

using Pkg
using PromptingTools
const PT = PromptingTools
include("diff_utils.jl")

# # Set Up
# For large files, you do not need to repeat all lines if there are no changes at all.
tpl = PT.create_template(;
    system = """You are un unworldly AI assistant.

<task>
Your task is to {{task}}.
</task>

<instructions>
You are helping user create a new Julia package and create and/or update necessary files. 
Depending on the specific task, use the relevant information provided by the user fulfil your task. 
Where a detail is missing, make a guess informed by the user inputs but ensure it is consistent with the rest of the information.
If the provided file does not exist, create it. 
If the file does exist, provide a row-based difference view of the changes that need to be made.
Mark any changes with the unified diff format.
Mark any removed line with a minus (`- `) in front of the line.
Mark any added line with a plus (`+ `) in front of the new line.
Any edit to a line, is a removal followed by an addition. 
Mark any edited line with a minus (`- `) in front of the original line, followed by the new line with a plus (`+ `) in front of it.
Group larger changes into a blocks of removed and added lines to make it easier to review.
HOWEVER, if you add a NEW line, you must include at least one preceding line to understand the location of this change.
If there are several repeated lines, you must list ALL of them to ensure proper handling.
Return the updated file in tags <file name=\$file_name\$>\$file_content\$</file>, where \$file_name\$ is the name of the file and \$file_content\$ is the content of the file.
All rows in the file must be marked with a plus or minus if they are added, or removed respectively.
Do not make any unrelated changes to the file.
Do not omit large parts of the original content for no reason.
Produce a valid full rewrite of the entire original file without skipping any lines. Do not be lazy!
</instructions>

<examples>
<example id=1>
<task>
Your task is to update the provided Project.toml to version 0.1.0. 
Add compats for PromptingTools.jl to 0.40, Aqua to 0.7 and Test to 1. 
Remember that compat lines must be sorted alphabetically.
</task>

<user_files>
<file name=Project.toml>
name = "PackageABC"
uuid = "a3ab6ebc-8459-47fb-86fc-4adc6e671050"
authors = ["J S <49557684+svilupp@users.noreply.github.com> and contributors"]
- version = "0.0.1-DEV"
+ version = "0.1.0"

[deps]
PromptingTools = "670122d1-24a8-4d70-bfce-740807c42192"

[compat]
+ Aqua = "0.7"
+ PromptingTools = "0.40"
+ Test = "1"
julia = "1.10"

[extras]
Aqua = "4c88cf16-eb10-579e-8560-4a9242c79595"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[targets]
test = ["Aqua", "Test"]
</file>
<user_files>
</example>
</examples>

""", user = """
User provided the following information:
<user_info>
Package name: {{pkg_name}}
Purpose: {{purpose}}
</user_info>

{{user_files}}

Before you start, think through what are the common challenges people face when fulfilling this task. Enclose your thinking in <thinking></thinking> tags.
Then, generate the new/updated file in <file name=\$file_name\$>\$file_content\$</file> tags.
Ensure to mark any added or removed lines with a plus or minus, respectively.
Produce a valid full rewrite of the entire original file without skipping any lines. Do not be lazy!
""")

pkg_name = "Swarm.jl" # Base.current_project()
purpose = "Very opinionated translation of OpenAI's Swarm.jl. It uses PromptingTools.jl to support multiple LLM providers and tool calling."

# # Update README
task = """Update the provided README.md file with best in class information for what the package could be. 
Highlight that the package in experimental stage and under development (use strong warning at the top)."""
user_files = files_to_prompt(["README.md"])#, "examples/openai_example.jl"])

conv = aigenerate(tpl; pkg_name, purpose, user_files, task,
    model = "gpt4o", return_all = true)
conv |> PT.last_output

## Apply the changes
file_infos = extract_files_info(conv |> PT.last_output)

## Create the files
for (file_name, file_content) in file_infos
    @info "Working on $file_name"
    write(FileEdit(file_name, file_content))
end

# # Write CONTRIBUTING.md
task = """Write a CONTRIBUTING.md file with very barebone instructions to open Github Issues before opening a Pull Request. 
Highlight that the package in experimental stage and under development (use strong warning at the top), so it might be to early to contribute."""
user_files = files_to_prompt(nothing)

conv = aigenerate(tpl; pkg_name, purpose, user_files, task,
    model = "claudes", return_all = true)
conv |> PT.last_output |> println

## Apply the changes
file_infos = extract_files_info(conv |> PT.last_output)

## Create the files
for (file_name, file_content) in file_infos
    @info "Working on $file_name"
    write(FileEdit(file_name, file_content))
end

# # Update Compat bounds based on Manifest
manifest = let io = IOBuffer()
    Pkg.status(mode = Pkg.PKGMODE_MANIFEST, io = io)
    String(take!(io))
end
task = """Update Project.toml with the compat bounds for all explicitly mentioned packages (including extras and extensions).
Do not add any new packages. 
Only update the relevant compat bounds. 
Ensure that compat bounds are sorted alphabetically.

Current Manifest.toml of all packages uses:
<package manifest>
$manifest
</package manifest>
"""
user_files = files_to_prompt("Project.toml")

conv = aigenerate(tpl; pkg_name, purpose, user_files, task,
    model = "claudes", return_all = true)
conv |> PT.last_output |> println

## Apply the changes
file_infos = extract_files_info(conv |> PT.last_output)

## Create the files
for (file_name, file_content) in file_infos
    @info "Working on $file_name"
    write(FileEdit(file_name, file_content))
end

# # Migrate the package to a new Name and UUID
