module WGPUCanvas

export getCanvas
using WGPUNative
using WGPUCore
using WGPUCore: AbstractWGPUCanvas, AbstractWGPUCanvasContext
#using WGPUCore: WGPUTextureFormat, WGPUTextureUsage, WGPUSurface
using Preferences
using Libdl
using Libglvnd_jll

include("offscreen.jl")

if Sys.isapple()
    include("events.jl")
    include("metalglfw.jl")
elseif Sys.islinux()
    libEGL_path = ""
    try
    	libEGL_path = dlpath("libEGL")
    catch e
        @warn "System level libEGL library is not found !!!"
    end
	if libEGL_path !== ""
		set_preferences!(Libglvnd_jll, "libEGL_path" => libEGL_path)
	end
    include("events.jl")
    include("linuxglfw.jl")
elseif Sys.iswindows()
    include("events.jl")
    include("glfwWindows.jl")
end


function WGPUCore.getCanvas(s::Symbol)
    if s==:OFFSCREEN
        return defaultCanvas(OffscreenCanvas)
    elseif s==:GLFW
        if Sys.iswindows()
            return defaultCanvas(GLFWWinCanvas)
        elseif Sys.isapple()
            return defaultCanvas(GLFWMacCanvas)
        elseif Sys.islinux()
            return defaultCanvas(GLFWLinuxCanvas)
        end
    else
        @error "Couldn't create canvas"
    end
end


end # module WGPUCanvas
