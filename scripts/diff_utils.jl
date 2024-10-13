# Define an enum for marking lines
@enum LineEditType ADD REMOVE NOCHANGE
@kwdef struct LineEdit{T <: AbstractString}
    content::T
    edit_type::LineEditType
end
edit_type(line::LineEdit) = line.edit_type
edit_type(line::AbstractString) = NOCHANGE
function edit_color(line::LineEdit)
    if edit_type(line) == ADD
        return :green
    elseif edit_type(line) == REMOVE
        return :red
    else
        return :normal
    end
end

function LineEdit(line::AbstractString)
    return LineEdit(line, edit_type(line))
end
@kwdef struct FileEdit
    path::String
    lines::Vector{<:LineEdit}
end

"""
    files_to_prompt(files::AbstractVector{<:AbstractString};
        start_tag = "<user_files>", end_tag = "</user_files>")

Packs the files into a prompt inside the `<user_files>` tags. Returns a String.
"""
function files_to_prompt(files::AbstractVector{<:AbstractString};
        start_tag = "<user_files>", end_tag = "</user_files>")
    @assert all(isfile, files) "All files must exist. Files not found: $(join([f for f in files if !isfile(f)], ", "))"
    ##
    io = IOBuffer()
    println(io, start_tag)
    for fn in files
        content = read(fn, String)
        println(io, """
        <file name=$fn>
        $content
        </file>""")
    end
    println(io, end_tag)
    return String(take!(io))
end
files_to_prompt(file::AbstractString) = files_to_prompt([file])
function files_to_prompt(::Nothing; kwargs...)
    return ""
end

"""
    extract_files_info(s::AbstractString)

Extracts the file names and content from the provided string in the `<file name=...></file>` tags.

Returns: A vector of tuples (`(file_name, content_lines)`), where `file_name` is the name of the file and `content_lines` is a vector of strings, each representing a line in the file.
"""
function extract_files_info(s::AbstractString)
    files_extracted = Tuple{AbstractString, AbstractString}[]

    # Regex to match all file blocks
    file_blocks = eachmatch(r"<file name=([^>]+)>(.*?)</file>"ms, s)
    for file_block in file_blocks
        file_name = file_block.captures[1]
        content = file_block.captures[2]
        # content_lines = filter(!isempty, split(content, '\n'))
        push!(files_extracted, (file_name, content))
    end

    return files_extracted
end

# Example usage
s = """
<file name=README.md>
- # LLMGuards [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://svilupp.github.io/LLMGuards.jl/stable/) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://svilupp.github.io/LLMGuards.jl/dev/) [![Build Status](https://github.com/svilupp/LLMGuards.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/svilupp/LLMGuards.jl/actions/workflows/CI.yml?query=branch%3Amain) [![Coverage](https://codecov.io/gh/svilupp/LLMGuards.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/svilupp/LLMGuards.jl) [![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
+ # LLMGuards.jl
</file>
<file name=Project.toml>
name = "LLMGuards"
uuid = "a3ab6dde-8459-47fb-86fc-4adc6e671050"
authors = ["J S <49557684+svilupp@users.noreply.github.com> and contributors"]
- version = "0.0.1-DEV"
+ version = "0.1.0"
</file>
"""
file_infos = extract_files_info(s)
# for (file_name, content_lines) in file_infos
#     println("File Name: ", file_name)
#     println("Content Lines: ", content_lines)
# end

"""
    detect_line_edit(line::AbstractString)

Detects the change/type in the provided line. 

Returns: LineEdit.
"""
function detect_line_edit(line::AbstractString)
    type = NOCHANGE
    if startswith(line, "+ ")
        line = replace(line, r"^\+ " => "")
        type = ADD
    elseif strip(line) == "+"
        line = ""
        type = ADD
    elseif strip(line) == "-"
        line = ""
        type = REMOVE
    elseif startswith(line, "- ")
        line = replace(line, r"^\- " => "")
        type = REMOVE
    end
    return LineEdit(line, type)
end

# Example usage
lines = [
    "+ Added line",
    "+",
    "- Removed line",
    " Unchanged line"
]

marked_lines = detect_line_edit.(lines)
# for (line, change_type) in marked_lines
#     println("Line: ", line, " Change Type: ", change_type)
# end

"""
    apply_line_changes(changes::AbstractVector{<:LineEdit})

Applies the changes to the provided lines as marked by the change type.

Returns a new vector of lines with the changes applied.
"""
function apply_line_edits(edited_lines::AbstractVector{<:LineEdit})
    new_lines = LineEdit[]

    for line in edited_lines
        if edit_type(line) == ADD || edit_type(line) == NOCHANGE
            push!(new_lines, line)
        elseif edit_type(line) == REMOVE
            continue  # Skip the line
        end
    end

    return new_lines
end

# Example usage
lines = [
    "+ Added line",
    "- Removed line",
    " Unchanged line"
]

marked_lines = detect_line_edit.(lines)
new_lines = apply_line_edits(marked_lines)
# println("New Lines: ", new_lines)

"""
    prune_line_edits(lines::AbstractVector{<:LineEdit})

Keep only the line edits that are necessary to anchor the merge.
"""
function prune_line_edits(lines::AbstractVector{<:LineEdit})
    ## To merge changes correctly, we only need one non-empty line edit before each change to anchor the merge
    pruned_lines = LineEdit[]

    last_change_index = 0
    for (i, line) in enumerate(lines)
        if edit_type(line) != NOCHANGE
            # If there's a change, add the previous unchanged line (if any) as an anchor
            if last_change_index < i - 1
                if !isempty(strip(lines[i - 1].content))
                    ## This is a good anchor (not empty)
                    push!(pruned_lines, lines[i - 1])
                else
                    ## This is a bad anchor (empty), try to find an earlier better anchor
                    # Scan back to find a non-empty line as an anchor
                    anchor_index = nothing
                    for k in (i - 2):-1:max(1, last_change_index + 1)
                        if !isempty(strip(lines[k].content))
                            anchor_index = k
                            break
                        end
                    end
                    if !isnothing(anchor_index)
                        # Append all lines from anchor up to the previous line
                        append!(pruned_lines, lines[anchor_index:(i - 1)])
                    else
                        ## No good anchor found, append at least the empty line
                        push!(pruned_lines, lines[i - 1])
                    end
                end
            end
            push!(pruned_lines, line)
            last_change_index = i
        end
    end

    return pruned_lines
end

"""
    merge_line_edits(orig_lines::AbstractVector{<:AbstractString},
        new_lines::AbstractVector{<:AbstractString})

Merges the changes from the `new_lines` into the `orig_lines`. Anchors the merge to the first line in `new_lines` to localize where to add the corresponding changes
"""
function merge_line_edits(orig_lines::AbstractVector{<:LineEdit},
        new_lines::AbstractVector{<:LineEdit})
    ## We need a healing mechanism if AI skips some lines, 
    ## we assume line order is maintained but some lines can be missing, so we iterate until we hit the first line in new_lines (=anchor)
    final_lines = LineEdit[]
    i, j = 1, 1
    while i <= length(new_lines) || j <= length(orig_lines)
        # If we've exhausted new_lines, add remaining orig_lines
        if i > length(new_lines)
            append!(final_lines, orig_lines[j:end])
            break
        end

        # If we've exhausted orig_lines, add remaining new_lines
        if j > length(orig_lines)
            append!(final_lines, new_lines[i:end])
            break
        end

        strip_target = strip(new_lines[i].content)
        strip_orig = strip(orig_lines[j].content)

        if strip_orig == strip_target
            # Matching lines, add from new_lines and advance both counters
            push!(final_lines, new_lines[i])
            i += 1
            j += 1
        elseif edit_type(new_lines[i]) == ADD
            # New line to be added, only advance new_lines counter
            push!(final_lines, new_lines[i])
            i += 1
        else
            # Mismatch and not ADD, keep orig line and only advance orig counter
            push!(final_lines, orig_lines[j])
            j += 1
        end
    end
    final_lines
end

s = "name = \"LLMGuards\"\nuuid = \"a3ab6dde-8459-47fb-86fc-4adc6e671050\"\nauthors = [\"J S <49557684+svilupp@users.noreply.github.com> and contributors\"]\nversion = \"0.0.1-DEV\"\n\n\n[deps]\nPromptingTools = \"670122d1-24a8-4d70-bfce-740807c42192\"\nSentencize = \"7dcf698f-69e3-471c-af7e-711815da818c\"\nStatistics = \"10745b16-79ce-11e8-11f9-7d13ad32a3b2\"\n"
s2 = "[deps]\nPromptingTools = \"670122d1-24a8-4d70-bfce-740807c42192\"\n+ new line added here!\nSentencize = \"7dcf698f-69e3-471c-af7e-711815da818c\"\n- Statistics = \"10745b16-79ce-11e8-11f9-7d13ad32a3b2\"\n"
orig_lines = LineEdit.(split(s, '\n'))
new_lines = detect_line_edit.(split(s2, '\n'))
pruned_lines = prune_line_edits(new_lines)
merged_lines = merge_line_edits(orig_lines, pruned_lines)
final_lines = apply_line_edits(merged_lines)

function FileEdit(path::AbstractString, new_text::AbstractString;
        verbose::Bool = true, prune::Bool = true)
    orig_lines = if isfile(path)
        LineEdit.(split(read(path, String), '\n'))
    else
        verbose && @info "File $path does not exist, will create a new file."
        LineEdit[]
    end
    new_lines = detect_line_edit.(split(new_text, '\n'))
    ## Decide whether to prune
    pruned_lines = prune ? prune_line_edits(new_lines) : new_lines
    merged_lines = merge_line_edits(orig_lines, pruned_lines)
    return FileEdit(path, merged_lines)
end
function Base.write(file_edit::FileEdit)
    (; path, lines) = file_edit
    final_lines = apply_line_edits(lines)
    open(path, "w") do io
        for line in final_lines
            write(io, line.content, "\n")
        end
    end
end
# write(FileEdit("mock.toml", s2))

"""
    apply_line_edits(file_edit::FileEdit)

Write the updated lines to the specific file path defined in `file_edit`.
"""
function apply_line_edits(file_edit::FileEdit)
    Base.write(file_edit)
end
# file_edit = FileEdit("mock.toml", s2);
# apply_line_edits(file_edit)

"""
    show_diff(io, file_edit::FileEdit)

Highlight the changed lines in the file in the provided IO stream.

# Markup Legend
- Add `+ ` for added lines and highlight in GREEN
- Remove `-` for removed lines and highlight in RED
- No change for lines "edit_type=NOCHANGE"

"""
function show_diff(io, file_edit::FileEdit)
    (; path, lines) = file_edit
    printstyled(io, "Diff Report\n", bold = true)
    printstyled(io, "File: $path\n", italic = true)
    print(io, "-"^20)
    for line in lines
        println(io)
        prefix = edit_type(line) == ADD ? "+ " : edit_type(line) == REMOVE ? "- " : ""
        printstyled(io, prefix * line.content, color = edit_color(line))
    end
    println(io, "-"^20)
    return nothing
end
show_diff(file_edit::FileEdit) = show_diff(stdout, file_edit)
;
file_edit = FileEdit("mock.toml", merged_lines)
show_diff(file_edit);
