using Random
using Plots

# -------------------------------
# Parameters
# -------------------------------

grid_size = 30
block_size = 2                  # Each block is block_size × block_size
initial_population = 10
max_steps = 300
r = 0.3

Random.seed!(1234)  # <--- Set your seed here (any integer)

# Define block (obstacle) positions (top-left corners)
block_positions = [
    (5, 5),
    (20, 5),
    (10, 20),
    (22, 22),
    (15, 15),
    (25, 25),
    (2, 20),
    (20, 2),
    (10, 10),
    (5, 15),
    (15, 5),
    (25, 10),
    (2, 2),
    (20, 20),
    (10, 5),
    (5, 10),
    (15, 15),
    (25, 5),
    (2, 10),
    (20, 15),
    (10, 2),
    (5, 2),
    (15, 20),
    (25, 20),
    (2, 5),
    (20, 10),
    (10, 25),
    (5, 25),
    (15, 2)
    ]

# Generate all blocked cells as a Set
blocked = Set{Tuple{Int,Int}}()
for (bx, by) in block_positions
    for dx in 0:block_size-1, dy in 0:block_size-1
        if 1 <= bx+dx <= grid_size && 1 <= by+dy <= grid_size
            push!(blocked, (bx+dx, by+dy))
        end
    end
end

# Adjust carrying capacity to available (non-blocked) cells
carrying_capacity = grid_size^2 - length(blocked)

# --- Agent Definition ---
mutable struct Agent
    x::Int
    y::Int
end

const directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]

# Initialize empty grid, marking obstacles
function empty_grid(L, blocked)
    grid = falses(L, L)
    for (x, y) in blocked
        grid[x, y] = true
    end
    return grid
end

# Place agents in free (non-blocked, non-occupied) cells
function place_agents!(agents, grid, N, blocked)
    free = [(i, j) for i in 1:grid_size, j in 1:grid_size if !grid[i, j]]
    shuffle!(free)
    for n in 1:N
        (x, y) = free[n]
        push!(agents, Agent(x, y))
        grid[x, y] = true
    end
end

# Return list of free neighboring cells (not occupied, not blocked)
function free_neighbors(agent, grid, blocked)
    neighbors = Agent[]
    for (dx, dy) in directions
        nx, ny = agent.x + dx, agent.y + dy
        if 1 ≤ nx ≤ grid_size && 1 ≤ ny ≤ grid_size && !grid[nx, ny] && !( (nx, ny) in blocked)
            push!(neighbors, Agent(nx, ny))
        end
    end
    return neighbors
end

function move_agent!(agent, grid, blocked)
    candidates = free_neighbors(agent, grid, blocked)
    if !isempty(candidates)
        grid[agent.x, agent.y] = false
        chosen = rand(candidates)
        agent.x, agent.y = chosen.x, chosen.y
        grid[agent.x, agent.y] = true
    end
end

# Check if agent has a neighbor within radius (potential mate)
function has_mate(agent, agents, radius)
    for other in agents
        if other !== agent
            dist = abs(agent.x - other.x) + abs(agent.y - other.y)
            if dist ≤ radius
                return true
            end
        end
    end
    return false
end

# Count agents near a position (excluding self)
function count_neighbors(agent, agents, radius)
    count = 0
    for other in agents
        if other !== agent
            dist = abs(agent.x - other.x) + abs(agent.y - other.y) # Manhattan distance
            if dist ≤ radius
                count += 1
            end
        end
    end
    return count
end

function reproduce_sexual!(agent, agents, grid, blocked, p_birth, all_agents, radius, alpha)
    if has_mate(agent, all_agents, radius)
        n_local = count_neighbors(agent, all_agents, radius)
        p_local = p_birth * exp(-alpha * n_local)
        candidates = free_neighbors(agent, grid, blocked)
        if !isempty(candidates) && rand() < p_local
            chosen = rand(candidates)
            push!(agents, Agent(chosen.x, chosen.y))
            grid[chosen.x, chosen.y] = true
        end
    end
end


# --- Plotting with Obstacles ---
function plot_agents(agents, step, pop_hist, blocked)
    x = [a.x for a in agents]
    y = [a.y for a in agents]
    # Plot obstacles as red squares
    xb = [i for (i, j) in blocked]
    yb = [j for (i, j) in blocked]
    plt = scatter(x, y; xlims=(1, grid_size), ylims=(1, grid_size), title="Step $step - Population: $(length(agents))", 
                  markersize=7, legend=false, aspect_ratio=:equal, c=:blue, grid=false)
    if !isempty(xb)
        scatter!(xb, yb; markercolor=:red, markersize=10, alpha=0.4, markerstrokewidth=0)
    end
    return plt
end

# --- Main simulation ---
function simulate_with_obstacles()
    agents = Agent[]
    grid = empty_grid(grid_size, blocked)
    place_agents!(agents, grid, initial_population, blocked)
    pop_hist = Int[]
    anim = @animate for step in 1:max_steps
        # Move agents
        for agent in shuffle(agents)
            move_agent!(agent, grid, blocked)
        end
        # Reproduce
        N = length(agents)
        p_birth = r * (1 - N / carrying_capacity)
        new_agents = Agent[]
        radius = 1   # mating/neighborhood radius
        alpha = 0.5

        for agent in agents
            reproduce_sexual!(agent, new_agents, grid, blocked, p_birth, agents, radius, alpha)
        end

        append!(agents, new_agents)
        push!(pop_hist, length(agents))
        plot_agents(agents, step, pop_hist, blocked)
    end
    return pop_hist, anim
end

# --- Run simulation ---
pop_hist, anim = simulate_with_obstacles()

# --- Save gif ---
gif(anim, "logistic_population_with_blocks.gif", fps=10)

# --- Plot population curve ---
plot(1:length(pop_hist), pop_hist, xlabel="Step", ylabel="Population", 
    label="Population", lw=2, legend=true, 
    title="Population Dynamics (With Obstacles)")
