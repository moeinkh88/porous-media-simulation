using Random
using Plots

# Parameters
grid_size = 10
max_population = 88
max_steps = 100
initial_population = 5
show_animation = true

# Hole locations (zero-based indexing for Julia)
holes = Set([
    (4, 2), (4, 3), (5, 2), (5, 3),   # Block 1: rows 5-6, cols 3-4
    (1, 4), (1, 5),                   # Block 2: row 2, cols 5-6
    (4, 6), (4, 7), (5, 6), (5, 7),   # Block 3: rows 5-6, cols 7-8
    (8, 4), (8, 5)                    # Block 4: row 9, cols 5-6
])
# Set `holes = Set()` for no holes (homogeneous media)
holes = Set()

function is_valid(cell, grid, holes)
    i, j = cell
    return 1 <= i <= grid_size && 1 <= j <= grid_size && !( (i-1, j-1) in holes ) && grid[i, j] == 0
end

function get_neighbors(cell, grid, holes)
    i, j = cell
    candidates = [(i-1, j), (i+1, j), (i, j-1), (i, j+1)]
    [nb for nb in candidates if is_valid(nb, grid, holes)]
end

# Initialization
grid = zeros(Int, grid_size, grid_size)
positions = []

# Place initial population randomly (skip holes)
while length(positions) < initial_population
    i, j = rand(1:grid_size), rand(1:grid_size)
    if (i-1, j-1) ∉ holes && grid[i, j] == 0
        push!(positions, (i, j))
        grid[i, j] = 1
    end
end

pop_over_time = [length(positions)]
frames = Plots.Plot[]  # For animation

for step in 1:max_steps
    new_positions = copy(positions)
    newborns = []
    Random.shuffle!(new_positions)
    grid .= 0
    for pos in new_positions
        grid[pos...] = 1
    end

    for idx in 1:length(new_positions)
        i, j = new_positions[idx]
        dirs = [(i-1,j), (i+1,j), (i,j-1), (i,j+1)]
        shuffle!(dirs)
        moved = false
        for (ni, nj) in dirs
            if is_valid((ni, nj), grid, holes)
                # Check for crossing boundaries for reproduction
                crossed = ( (i==5 && ni==6) || (i==6 && ni==5) ||
                            (j==5 && nj==6) || (j==6 && nj==5) )
                # Move agent
                grid[i, j] = 0
                new_positions[idx] = (ni, nj)
                grid[ni, nj] = 1
                moved = true

                # Try reproduction if crossed
                if crossed && length(new_positions) + length(newborns) < max_population
                    # Find a free neighbor cell
                    nb_cells = get_neighbors((ni, nj), grid, holes)
                    if !isempty(nb_cells)
                        baby = rand(nb_cells)
                        push!(newborns, baby)
                        grid[baby...] = 1
                    end
                end
                break
            end
        end
        if !moved
            # Stay in place
            grid[i, j] = 1
        end
    end

    # Add newborns
    for baby in newborns
        push!(new_positions, baby)
    end
    positions = new_positions[1:min(length(new_positions), max_population)]
    pop_over_time = vcat(pop_over_time, length(positions))

    # For animation
    if show_animation
        p = heatmap(grid', c=:blues, title="Step $step (Pop=$(length(positions)))", yflip=true)
        push!(frames, p)
    end
end


# Animation
if show_animation
    anim = @animate for f in frames
        f
    end
    gif(anim, "population_sim.gif", fps=5)
end

# Plot population over time
plot(1:length(pop_over_time), pop_over_time, xlabel="Step", ylabel="Population", title="Population over Time")

