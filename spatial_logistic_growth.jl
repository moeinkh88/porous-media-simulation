using Random
using Plots

# --- Parameters ---
grid_size = 30           # Side length of the square grid
initial_population = 10  # Start with 10 agents
max_steps = 100          # Number of time steps
carrying_capacity = grid_size^2
r = 0.1                  # Intrinsic growth rate

# --- State ---
mutable struct Agent
    x::Int
    y::Int
end

# Functions for movement (up, down, left, right)
const directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]

# Initialize empty grid
function empty_grid(L)
    falses(L, L)
end

# Place agents randomly on grid
function place_agents!(agents, grid, N)
    free = [(i, j) for i in 1:grid_size, j in 1:grid_size]
    shuffle!(free)
    for n in 1:N
        (x, y) = free[n]
        push!(agents, Agent(x, y))
        grid[x, y] = true
    end
end

# Check available neighbors
function free_neighbors(agent, grid)
    neighbors = Agent[]
    for (dx, dy) in directions
        nx, ny = agent.x + dx, agent.y + dy
        if 1 ≤ nx ≤ grid_size && 1 ≤ ny ≤ grid_size && !grid[nx, ny]
            push!(neighbors, Agent(nx, ny))
        end
    end
    return neighbors
end

# Agent tries to move
function move_agent!(agent, grid)
    candidates = free_neighbors(agent, grid)
    if !isempty(candidates)
        grid[agent.x, agent.y] = false
        chosen = rand(candidates)
        agent.x, agent.y = chosen.x, chosen.y
        grid[agent.x, agent.y] = true
    end
end

# Try to reproduce
function reproduce!(agent, agents, grid, p_birth)
    candidates = free_neighbors(agent, grid)
    if !isempty(candidates) && rand() < p_birth
        chosen = rand(candidates)
        push!(agents, Agent(chosen.x, chosen.y))
        grid[chosen.x, chosen.y] = true
    end
end

# Visualization helper
function plot_agents(agents, step, pop_hist)
    x = [a.x for a in agents]
    y = [a.y for a in agents]
    plt = scatter(x, y; xlims=(1, grid_size), ylims=(1, grid_size), 
        title="Step $step - Population: $(length(agents))", 
        markersize=7, legend=false, aspect_ratio=:equal, c=:blue)
    return plt
end

# --- Main simulation ---
function simulate()
    agents = Agent[]
    grid = empty_grid(grid_size)
    place_agents!(agents, grid, initial_population)
    pop_hist = Int[]
    anim = @animate for step in 1:max_steps
        # Movement
        for agent in shuffle(agents)
            move_agent!(agent, grid)
        end
        # Reproduction (logistic prob)
        N = length(agents)
        p_birth = r * (1 - N / carrying_capacity)
        new_agents = Agent[]
        for agent in agents
            reproduce!(agent, new_agents, grid, p_birth)
        end
        append!(agents, new_agents)
        push!(pop_hist, length(agents))
        plot_agents(agents, step, pop_hist)
    end
    return pop_hist, anim
end

# Run the simulation!
pop_hist, anim = simulate()

# Save gif (requires ffmpeg)
gif(anim, "logistic_population.gif", fps=10)

# Plot population dynamics
plot(1:length(pop_hist), pop_hist, xlabel="Step", ylabel="Population", label="Population", lw=2, legend=true, title="Population Dynamics (Logistic Growth)")
