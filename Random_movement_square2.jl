using Random
using Plots

# Parameters
grid_size = 10
max_population = 88
max_steps = 100
initial_population = 10
show_animation = true

# Define hole coordinates (zero-based)
holes = Set([
    (4, 2), (4, 3), (5, 2), (5, 3),   # Block 1: rows 5-6, cols 3-4
    (1, 4), (1, 5),                   # Block 2: row 2, cols 5-6
    (4, 6), (4, 7), (5, 6), (5, 7),   # Block 3: rows 5-6, cols 7-8
    (8, 4), (8, 5)                    # Block 4: row 9, cols 5-6
])

function is_hole(cell)
    i, j = cell
    return (i-1, j-1) in holes
end

function is_valid(cell, grid, holes)
    i, j = cell
    return 1 <= i <= grid_size && 1 <= j <= grid_size && !( (i-1, j-1) in holes ) && grid[i, j] == 0
end

function get_neighbors(cell, grid, holes)
    i, j = cell
    candidates = [(i-1, j), (i+1, j), (i, j-1), (i, j+1)]
    [nb for nb in candidates if is_valid(nb, grid, holes)]
end

# Initialize population
grid = zeros(Int, grid_size, grid_size)
positions = []

while length(positions) < initial_population
    i, j = rand(1:grid_size), rand(1:grid_size)
    if (i-1, j-1) ∉ holes && grid[i, j] == 0
        push!(positions, (i, j))
        grid[i, j] = 1
    end
end

pop_over_time = [length(positions)]
frames = Plots.Plot[]

# In the main simulation loop, after creating each frame:

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
                crossed = ( (i==5 && ni==6) || (i==6 && ni==5) ||
                            (j==5 && nj==6) || (j==6 && nj==5) )
                # Move agent
                grid[i, j] = 0
                new_positions[idx] = (ni, nj)
                grid[ni, nj] = 1
                moved = true

                # Try reproduction if crossed
                if crossed && length(new_positions) + length(newborns) < max_population
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
            grid[i, j] = 1
        end
    end

    for baby in newborns
        push!(new_positions, baby)
    end
    positions = new_positions[1:min(length(new_positions), max_population)]
    pop_over_time = vcat(pop_over_time, length(positions))

    # Animation: plot the actual positions as moving dots
    agent_x = [p[2] for p in positions]
    agent_y = [p[1] for p in positions]
    hole_x = [j+1 for (i, j) in holes]
    hole_y = [i+1 for (i, j) in holes]

    p = scatter(
        agent_x, agent_y,
        label="Agents", markersize=8, c=:blue,
        xlim=(0.5,grid_size+0.5), ylim=(0.5,grid_size+0.5),
        xlabel="Column", ylabel="Row",
        legend=false,
        title="Step $step (Pop=$(length(positions)))",
        size=(500, 500),
        markerstrokewidth=0
    )
    # Overlay holes as gray squares
    scatter!(hole_x, hole_y, markershape=:rect, c=:gray, label="", markersize=18, alpha=0.5)

    push!(frames, p)
end

# Save animation
if show_animation
    anim = @animate for f in frames
        f
    end
    gif(anim, "population_movement.gif", fps=6)
end

display("image/gif", read("population_movement.gif"))


# Plot population curve
plot(1:length(pop_over_time), pop_over_time, xlabel="Step", ylabel="Population", title="Population over Time")
