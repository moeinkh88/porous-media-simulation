using Random
using Plots

# -------------------------------
# Parameters
# -------------------------------

grid_size = 10           # Size of the grid (10x10)
max_population = 88      # Maximum population (100 total cells minus 12 holes)
max_steps = 50          # Number of simulation steps
initial_population = 10  # Initial number of agents
show_animation = true    # Flag to control animation generation

# -------------------------------
# Define hole coordinates (zero-based indexing)
# -------------------------------

# Set of coordinates representing obstacles (holes) in the grid
holes = Set([
    (4, 2), (4, 3), (5, 2), (5, 3),   # Block 1: rows 5-6, cols 3-4
    (1, 4), (1, 5),                   # Block 2: row 2, cols 5-6
    (4, 6), (4, 7), (5, 6), (5, 7),   # Block 3: rows 5-6, cols 7-8
    (8, 4), (8, 5)                    # Block 4: row 9, cols 5-6
])

# -------------------------------
# Helper Functions
# -------------------------------

# Check if a cell is a hole
function is_hole(cell)
    i, j = cell
    return (i-1, j-1) in holes
end

# Check if a cell is within bounds, not a hole, and unoccupied
function is_valid(cell, grid, holes)
    i, j = cell
    return 1 <= i <= grid_size && 1 <= j <= grid_size &&
           !((i-1, j-1) in holes) && grid[i, j] == 0
end

# Get valid neighboring cells (up, down, left, right)
function get_neighbors(cell, grid, holes)
    i, j = cell
    candidates = [(i-1, j), (i+1, j), (i, j-1), (i, j+1)]
    return [nb for nb in candidates if is_valid(nb, grid, holes)]
end

# -------------------------------
# Initialize Population
# -------------------------------

# Create a grid initialized with zeros
grid = zeros(Int, grid_size, grid_size)
positions = []  # List to store positions of agents

# Randomly place initial agents on the grid, avoiding holes and occupied cells
while length(positions) < initial_population
    i, j = rand(1:grid_size), rand(1:grid_size)
    if (i-1, j-1) ∉ holes && grid[i, j] == 0
        push!(positions, (i, j))
        grid[i, j] = 1
    end
end

# -------------------------------
# Simulation Loop
# -------------------------------

pop_over_time = [length(positions)]  # Track population over time
frames = Plots.Plot[]                # Store frames for animation

for step in 1:max_steps
    new_positions = copy(positions)  # Copy current positions
    newborns = []                    # List to store new agents
    Random.shuffle!(new_positions)   # Shuffle agents to randomize movement order
    grid .= 0                        # Reset grid

    # Update grid with current agent positions
    for pos in new_positions
        grid[pos...] = 1
    end

    # Iterate over each agent to attempt movement and reproduction
    for idx in 1:length(new_positions)
        i, j = new_positions[idx]
        dirs = [(i-1,j), (i+1,j), (i,j-1), (i,j+1)]  # Possible movement directions
        shuffle!(dirs)  # Randomize movement directions
        moved = false

        for (ni, nj) in dirs
            if is_valid((ni, nj), grid, holes)
                # Check if movement crosses from row/column 5 to 6 or vice versa
                crossed = ((i==5 && ni==6) || (i==6 && ni==5) ||
                           (j==5 && nj==6) || (j==6 && nj==5))

                # Move agent
                grid[i, j] = 0
                new_positions[idx] = (ni, nj)
                grid[ni, nj] = 1
                moved = true

                # Attempt reproduction if crossed and population limit not reached
                if crossed && length(new_positions) + length(newborns) < max_population
                    nb_cells = get_neighbors((ni, nj), grid, holes)
                    if !isempty(nb_cells)
                        baby = rand(nb_cells)
                        push!(newborns, baby)
                        grid[baby...] = 1
                    end
                end
                break  # Exit loop after successful move
            end
        end

        # If agent didn't move, keep it in place
        if !moved
            grid[i, j] = 1
        end
    end

    # Add newborn agents to the population
    for baby in newborns
        push!(new_positions, baby)
    end

    # Update positions, ensuring population does not exceed max_population
    positions = new_positions[1:min(length(new_positions), max_population)]
    pop_over_time = vcat(pop_over_time, length(positions))  # Record population size

    # -------------------------------
    # Visualization for Animation
    # -------------------------------

    # Extract x and y coordinates for agents and holes
    agent_x = [p[2] for p in positions]
    agent_y = [p[1] for p in positions]
    hole_x = [j+1 for (i, j) in holes]
    hole_y = [i+1 for (i, j) in holes]

    # Create scatter plot for current step
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

    # Save current frame
    push!(frames, p)
end

# -------------------------------
# Generate and Display Animation
# -------------------------------

if show_animation
    # Create animation from frames
    anim = @animate for f in frames
        plot(f)
    end

    # Save animation as GIF
    gif(anim, "population_movement.gif", fps=6)
    # Display GIF inline (useful in Jupyter or Pluto notebooks)
    display("image/gif", read("population_movement.gif"))
end

# -------------------------------
# Plot Population Over Time
# -------------------------------

# Plot the population size at each simulation step
plot(1:length(pop_over_time), pop_over_time,
     xlabel="Step", ylabel="Population", title="Population over Time")

