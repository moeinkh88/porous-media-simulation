using Random
using Plots

# -------------------------------
# Parameters
# -------------------------------

grid_size = 100           # Size of the grid (100x100)
block_scale = 10          # Scaling factor for enlarging blocks
initial_population = 1000  # Initial number of agents
max_steps = 1000           # Number of simulation steps
max_population = grid_size^2 - 12 * block_scale^2  # Total cells minus hole cells
show_animation = true      # Flag to control animation generation

# -------------------------------
# Define hole coordinates (1-based indexing)
# -------------------------------

holes = Set{Tuple{Int, Int}}()
for i in 50:59, j in 30:39; push!(holes, (i, j)); end  # Block 1
for i in 10:19, j in 50:59; push!(holes, (i, j)); end  # Block 2
for i in 50:59, j in 70:79; push!(holes, (i, j)); end  # Block 3
for i in 90:99, j in 50:59; push!(holes, (i, j)); end  # Block 4

# -------------------------------
# Type alias and helper functions
# -------------------------------

const Cell = Tuple{Int, Int}

# Check if a cell is a hole (1-based indexing)
function is_hole(cell::Cell)
    return cell in holes
end

# Check if a cell is valid (in bounds, not a hole, unoccupied)
function is_valid(cell::Cell, grid)
    i, j = cell
    return 1 <= i <= grid_size && 1 <= j <= grid_size &&
           !(cell in holes) && grid[i, j] == 0
end

# Get valid neighboring cells for reproduction (4‑way)
function get_neighbors(cell::Cell, grid)
    i, j = cell
    candidates = [(i-1, j), (i+1, j), (i, j-1), (i, j+1)]
    return [nb for nb in candidates if is_valid(nb, grid)]
end

# -------------------------------
# Initialize population
# -------------------------------

grid = zeros(Int, grid_size, grid_size)
positions = Cell[]
while length(positions) < initial_population
    cell = (rand(1:grid_size), rand(1:grid_size))
    if is_valid(cell, grid)
        push!(positions, cell)
        grid[cell...] = 1
    end
end

# -------------------------------
# Precompute jump directions
# -------------------------------

# All relative moves within a 2-unit radius (excluding staying in place)
jump_dirs = [(di, dj) for di in -2:2, dj in -2:2 if !(di == 0 && dj == 0)]

# -------------------------------
# Simulation loop
# -------------------------------

pop_over_time = [length(positions)]
frames = Plots.Plot[]

for step in 1:max_steps
    new_positions = copy(positions)
    newborns = Cell[]
    shuffle!(new_positions)
    grid .= 0
    for pos in new_positions
        grid[pos...] = 1
    end

    for idx in 1:length(new_positions)
        i, j = new_positions[idx]
        shuffle!(jump_dirs)
        moved = false
        for (di, dj) in jump_dirs
            ni, nj = i + di, j + dj
            if is_valid((ni, nj), grid)
                # Check reproduction boundary crossing (50 <-> 60)
                crossed = ((i == 50 && ni == 60) || (i == 60 && ni == 50) ||
                           (j == 50 && nj == 60) || (j == 60 && nj == 50))
                # Move agent
                grid[i, j] = 0
                new_positions[idx] = (ni, nj)
                grid[ni, nj] = 1
                moved = true
                # Reproduction
                if crossed && length(new_positions) + length(newborns) < max_population
                    neighbors = get_neighbors((ni, nj), grid)
                    if !isempty(neighbors)
                        baby = rand(neighbors)
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

    append!(new_positions, newborns)
    positions = new_positions[1:min(length(new_positions), max_population)]
    push!(pop_over_time, length(positions))

    # Visualization
    agent_x = [p[2] for p in positions]
    agent_y = [p[1] for p in positions]
    hole_x = [c[2] for c in holes]
    hole_y = [c[1] for c in holes]

    p = scatter(agent_x, agent_y,
                markersize=4, c=:blue,
                xlim=(0.5, grid_size+0.5), ylim=(0.5, grid_size+0.5),
                xlabel="Col", ylabel="Row",
                legend=false,
                title="Step $step (Pop=$(length(positions)))",
                size=(800,800))
    scatter!(hole_x, hole_y, markershape=:rect, c=:gray, markersize=18, alpha=0.5)
    push!(frames, p)
end

# -------------------------------
# Animation & population plot
# -------------------------------
if show_animation
    anim = @animate for f in frames
        plot(f)
    end
    gif(anim, "population_movement.gif", fps=6)
    display("image/gif", read("population_movement.gif"))
end
plot(1:length(pop_over_time), pop_over_time,
     xlabel="Step", ylabel="Population", title="Population over Time")
