using Random
using Distributions
using LinearAlgebra
using Plots

using Random, LinearAlgebra

# Parameters
N0 = 10                    # Initial population
K = 200                    # Carrying capacity
domain_size = 100.0               # Size of the square domain
steps = 500                # Number of time steps
dt = 1.0                   # Time step duration
step_size = 2.0            # Max move per step
repro_dist = 1.0           # Distance threshold for reproduction

# Hole parameters
num_holes = 10
hole_radius = 10.0

# Generate holes (as [(x, y, r), ...])
function generate_holes(num_holes, size, radius)
    holes = []
    while length(holes) < num_holes
        x, y = rand()*domain_size, rand()*domain_size
        # Avoid overlapping holes by checking distance from existing
        if all(sqrt((hx-x)^2 + (hy-y)^2) > 2radius for (hx, hy, radius) in holes)
            push!(holes, (x, y, radius))
        end
    end
    return holes
end

holes = generate_holes(num_holes, domain_size, hole_radius)

# Initialize population (positions)
function init_population(N, domain_size, holes)
    positions = zeros(Float64, 2, N)
    for i in 1:N
        while true
            x, y = rand()*domain_size, rand()*domain_size
            # Check not in any hole
            if all(sqrt((hx-x)^2 + (hy-y)^2) > hr for (hx, hy, hr) in holes)
                positions[:, i] = [x, y]
                break
            end
        end
    end
    return positions
end

positions = init_population(N0, domain_size, holes)
pop_over_time = [N0]

# Main simulation loop
for t in 1:steps
    N = size(positions, 2)
    new_positions = copy(positions)
    # Movement
    for i in 1:N
        θ = rand() * 2π
        dx = step_size * cos(θ)
        dy = step_size * sin(θ)
        x_new = positions[1, i] + dx
        y_new = positions[2, i] + dy
        # Periodic boundary conditions
        x_new = mod(x_new, domain_size)
        y_new = mod(y_new, domain_size)
        # Check for holes
        in_hole = any(sqrt((hx-x_new)^2 + (hy-y_new)^2) < hr for (hx, hy, hr) in holes)
        if !in_hole
            new_positions[:, i] = [x_new, y_new]
        end
    end
    positions = new_positions

    # Reproduction
    new_borns = []
    for i in 1:N-1
        for j in i+1:N
            # If close enough and carrying capacity not reached
            if norm(positions[:,i] - positions[:,j]) < repro_dist && size(positions,2)+length(new_borns) < K
                # Place new born at random near parents
                angle = rand() * 2π
                dist = rand() * 1.5  # max newborn distance from parent
                parent = rand() < 0.5 ? i : j
                x_new = positions[1, parent] + dist*cos(angle)
                y_new = positions[2, parent] + dist*sin(angle)
                # Periodic boundary
                x_new = mod(x_new, domain_size)
                y_new = mod(y_new, domain_size)
                # Not inside a hole
                if all(sqrt((hx-x_new)^2 + (hy-y_new)^2) > hr for (hx, hy, hr) in holes)
                    push!(new_borns, [x_new, y_new])
                end
            end
        end
    end
    # Add new borns
    if !isempty(new_borns)
        positions = hcat(positions, hcat(new_borns...) )
    end

    push!(pop_over_time, size(positions,2))
end

# Plot results
using Plots
plot(0:length(pop_over_time)-1, pop_over_time, xlabel="Time", ylabel="Population", title="Population Growth in Porous Media")

# Optional: to remove holes, just set num_holes=0, or pass holes=[] in init_population etc.


# Initialize positions (2 x N matrix)
positions = [rand()*domain_size for _ in 1:N0, _ in 1:2]'
all_positions = Vector{Matrix{Float64}}()

for t in 1:steps
    for i in 1:size(positions, 2)
        θ = rand() * 2π
        dx = step_size * cos(θ)
        dy = step_size * sin(θ)
        x_new = mod(positions[1, i] + dx, domain_size)
        y_new = mod(positions[2, i] + dy, domain_size)
        # Prevent moving into a hole
        in_hole = any(sqrt((hx - x_new)^2 + (hy - y_new)^2) < hr for (hx, hy, hr) in holes)
        if !in_hole
            positions[:, i] = [x_new, y_new]
        end
    end
    push!(all_positions, copy(positions))
end

function plot_population(positions, holes, domain_size; t=0)
    scatter(positions[1, :], positions[2, :], 
        xlim=(0, domain_size), ylim=(0, domain_size), 
        markersize=6, legend=false, 
        xlabel="x", ylabel="y", title="t = $t")
    for (hx, hy, hr) in holes
        θ = range(0, 2π; length=50)
        plot!(hx .+ hr*cos.(θ), hy .+ hr*sin.(θ), seriestype=:shape, c=:gray, lw=1, fillalpha=0.2)
    end
end

anim = @animate for (t, pos) in enumerate(all_positions)
    plot_population(pos, holes, domain_size, t=t)
end
gif(anim, "random_walk_with_holes.gif", fps=10)
