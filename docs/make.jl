using WGPUCanvas
using Documenter

DocMeta.setdocmeta!(WGPUCanvas, :DocTestSetup, :(using WGPUCanvas); recursive=true)

makedocs(;
    modules=[WGPUCanvas],
    authors="arhik <arhik23@gmail.com>",
    repo="https://github.com/JuliaWGPU/WGPUCanvas.jl/blob/{commit}{path}#{line}",
    sitename="WGPUCanvas.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaWGPU.github.io/WGPUCanvas.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaWGPU/WGPUCanvas.jl",
    devbranch="main",
)
